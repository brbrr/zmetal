//! On-device Cortex-M7 fault decoder + asynchronous-fault resume.
//!
//! Naked exception handlers capture the hardware-stacked exception frame and
//! tail-call `fault_report`, which does one of two things:
//!
//!   * **Resume** harmless asynchronous BusFaults. With D-cache on, Cortex-M7
//!     speculative reads raise async AXIM bus errors that are simply discarded;
//!     the pre-BUSFAULTENA microzig ignored them implicitly. We replicate that.
//!   * **Capture + halt** for every real fault: fill `last_fault` and busy-spin,
//!     so the snapshot is readable over SWD (`p fault.last_fault`) with no UART.
//!
//! See docs/dcache-dma-fault-investigation.md for the full history.
//!
//! Wire into microzig_options:
//!     .HardFault      = .{ .naked = fault.hard_fault },
//!     .MemManageFault = .{ .naked = fault.mem_manage_fault },
//!     .BusFault       = .{ .naked = fault.bus_fault },
//!     .UsageFault     = .{ .naked = fault.usage_fault },

const std = @import("std");
const microzig = @import("microzig");

/// Cortex-M7 System Control Block — CFSR / HFSR / BFAR / MMAR / SHCSR live here.
const scb = microzig.cpu.peripherals.scb;
/// Decoded CFSR type (`.MMFSR` / `.BFSR` / `.UFSR`), for passing around typed.
const Cfsr = @TypeOf(scb.CFSR.read());

/// Cortex-M7 Auxiliary Bus Fault Status Register (0xE000EFA8): records the bus
/// of an asynchronous fault — bit1 DTCM, bit2 AHBP, bit3 AXIM, and AXIMTYPE[10:8]
/// (2 = SLVERR, 3 = DECERR). microzig doesn't model it, so reach it directly.
const abfsr_reg: *volatile u32 = @ptrFromInt(0xE000EFA8);

/// `kind` values the naked trampolines pass in r1.
const KIND_HARD_FAULT: u32 = 0;
const KIND_MEM_MANAGE: u32 = 1;
const KIND_BUS_FAULT: u32 = 2;
const KIND_USAGE_FAULT: u32 = 3;

/// Safety cap on consecutive async resumes — far above a normal startup burst
/// (tens). Past it we stop resuming so a genuine fault storm gets captured.
const MAX_RESUMES: u32 = 4096;

/// Written to `last_fault.magic` once populated, so the debugger can tell a real
/// snapshot from zeroed .bss.
const FAULT_MAGIC: u32 = 0xFA017000;

/// Decoded fault snapshot. Read one symbol over the debugger: `p fault.last_fault`.
pub const FaultInfo = extern struct {
    magic: u32,
    kind: u32,
    cfsr: u32,
    hfsr: u32,
    mmfar: u32,
    bfar: u32,
    abfsr: u32,
    // Decoded convenience flags
    bfar_valid: u32,
    precise: u32,
    imprecise: u32,
    aximtype: u32, // 2 = SLVERR, 3 = DECERR
    // Stacked exception frame (the faulting context)
    r0: u32,
    r1: u32,
    r2: u32,
    r3: u32,
    r12: u32,
    lr: u32,
    pc: u32,
    xpsr: u32,
};

/// Snapshot of the first fatal fault (or the first resumed async fault).
pub var last_fault: FaultInfo = std.mem.zeroes(FaultInfo);
/// Nonzero once a fatal (non-resumable) fault has been captured (then we spin).
pub var fault_count: u32 = 0;
/// Count of harmless asynchronous BusFaults resumed — mostly the startup burst.
pub var imprecise_resumes: u32 = 0;

const StackFrame = extern struct {
    r0: u32,
    r1: u32,
    r2: u32,
    r3: u32,
    r12: u32,
    lr: u32,
    pc: u32,
    xpsr: u32,
};

comptime {
    // Force the naked trampolines to be analyzed (asm errors surface at build
    // time) even before they are wired into microzig_options.
    _ = &hard_fault;
    _ = &mem_manage_fault;
    _ = &bus_fault;
    _ = &usage_fault;
}

/// A harmless asynchronous BusFault from Cortex-M7 speculation (D-cache on). Both
/// forms have no precise cause and no fault address:
///   * imprecise — BFSR.IMPRECISERR set: a live discarded speculative AXIM read.
///   * no-cause  — BFSR and ABFSR both clear: a fault that tail-chained into this
///     handler after a prior resume already write-1-cleared the status, before
///     its cause re-latched. This burst race is what made the cold-boot hang
///     intermittent (it fails an IMPRECISERR-only test).
/// Real faults — a precise data error, a valid BFAR, or a HardFault escalation —
/// are never treated as harmless.
fn is_harmless_async_bus_fault(cfsr: Cfsr, abfsr: u32) bool {
    if (scb.HFSR.read().FORCED != 0) return false;
    if (cfsr.BFSR.busfault_address_register_valid) return false;
    if (cfsr.BFSR.precice_data_bus_error) return false;

    const bfsr_byte: u8 = @truncate(@as(u32, @bitCast(cfsr)) >> 8);
    const no_cause = bfsr_byte == 0 and abfsr == 0;
    return cfsr.BFSR.imprecice_data_bus_error or no_cause;
}

fn capture(frame: *const StackFrame, kind: u32, cfsr: Cfsr, abfsr: u32) void {
    // Volatile write so the optimizer can't drop the store (nothing in firmware
    // reads `last_fault`; only the debugger does).
    const out: *volatile FaultInfo = &last_fault;
    out.* = .{
        .magic = FAULT_MAGIC,
        .kind = kind,
        .cfsr = @bitCast(cfsr),
        .hfsr = scb.HFSR.raw,
        .mmfar = scb.MMAR,
        .bfar = scb.BFAR,
        .abfsr = abfsr,
        .bfar_valid = @intFromBool(cfsr.BFSR.busfault_address_register_valid),
        .precise = @intFromBool(cfsr.BFSR.precice_data_bus_error),
        .imprecise = @intFromBool(cfsr.BFSR.imprecice_data_bus_error),
        .aximtype = (abfsr >> 8) & 0x7,
        .r0 = frame.r0,
        .r1 = frame.r1,
        .r2 = frame.r2,
        .r3 = frame.r3,
        .r12 = frame.r12,
        .lr = frame.lr,
        .pc = frame.pc,
        .xpsr = frame.xpsr,
    };
}

/// Called from the naked trampolines: `frame` = stacked exception frame,
/// `kind` = KIND_* index.
export fn fault_report(frame: *const StackFrame, kind: u32) callconv(.c) void {
    // Block further interrupts/faults so a nested fault can't clobber the snapshot.
    // (No @breakpoint: with no debugger attached a BKPT would escalate to HardFault
    // and re-enter here.)
    asm volatile ("cpsid i");

    const cfsr = scb.CFSR.read();
    const abfsr = abfsr_reg.*;

    if (kind == KIND_BUS_FAULT and is_harmless_async_bus_fault(cfsr, abfsr)) {
        imprecise_resumes +%= 1;
        if (imprecise_resumes <= MAX_RESUMES) {
            if (imprecise_resumes == 1) capture(frame, kind, cfsr, abfsr);
            // Write-1-to-clear the sticky BusFault status + ABFSR, then return.
            // (For the no-cause form these are already 0, so this is a no-op.)
            scb.CFSR.raw = @bitCast(cfsr);
            abfsr_reg.* = abfsr;
            asm volatile ("dsb");
            asm volatile ("cpsie i");
            return; // EXC_RETURN via the naked trampoline resumes execution
        }
        // Cap exceeded: fall through and capture it as fatal.
    }

    // Fatal fault: capture the first, ignore any nested ones, and busy-spin.
    // A tight loop (NOT wfi) keeps the AHB-AP alive so the ST-Link can always
    // halt here and read `last_fault`.
    if (fault_count == 0) capture(frame, kind, cfsr, abfsr);
    fault_count +%= 1;
    while (true) {
        asm volatile ("nop");
    }
}

// Naked trampolines: pick MSP/PSP via EXC_RETURN bit 2, load the kind index,
// tail-call fault_report(frame, kind).
pub fn hard_fault() callconv(.naked) void {
    asm volatile (
        \\ tst lr, #4
        \\ ite eq
        \\ mrseq r0, msp
        \\ mrsne r0, psp
        \\ movs r1, #0
        \\ b fault_report
    );
}

pub fn mem_manage_fault() callconv(.naked) void {
    asm volatile (
        \\ tst lr, #4
        \\ ite eq
        \\ mrseq r0, msp
        \\ mrsne r0, psp
        \\ movs r1, #1
        \\ b fault_report
    );
}

pub fn bus_fault() callconv(.naked) void {
    asm volatile (
        \\ tst lr, #4
        \\ ite eq
        \\ mrseq r0, msp
        \\ mrsne r0, psp
        \\ movs r1, #2
        \\ b fault_report
    );
}

pub fn usage_fault() callconv(.naked) void {
    asm volatile (
        \\ tst lr, #4
        \\ ite eq
        \\ mrseq r0, msp
        \\ mrsne r0, psp
        \\ movs r1, #3
        \\ b fault_report
    );
}

pub fn hw_handler() callconv(.c) void {
    @breakpoint();
    @panic("HardFault");
}
pub fn nmi_handler() callconv(.c) void {
    @breakpoint();
    @panic("NMI");
}
fn mem_manage_fault_handler() callconv(.c) void {
    @breakpoint();
    @panic("MemManageFault");
}
fn bus_fault_handler() callconv(.c) void {
    @breakpoint();
    @panic("BusFault");
}
fn usage_fault_handler() callconv(.c) void {
    @breakpoint();
    @panic("UsageFault");
}
pub fn sv_call_handler() callconv(.c) void {
    @breakpoint();
    @panic("SVCall");
}
