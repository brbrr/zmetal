//! On-device Cortex-M7 fault decoder.
//!
//! Naked exception handlers capture the hardware-stacked exception frame
//! (the SP active at fault time, chosen via EXC_RETURN bit 2), then a C
//! reporter prints the fault-status registers + the faulting PC over the
//! standard `std.log` UART logger. Wire these into `microzig_options`:
//!
//!     .HardFault      = .{ .naked = fault.hard_fault },
//!     .MemManageFault = .{ .naked = fault.mem_manage_fault },
//!     .BusFault       = .{ .naked = fault.bus_fault },
//!     .UsageFault     = .{ .naked = fault.usage_fault },
//!
//! Note: on an *imprecise* BusFault (CFSR bit10 IMPRECISERR set, BFARVALID
//! clear) the stacked PC is only approximate and BFAR is invalid — the
//! offending buffered store already retired. ABFSR still tells you the bus
//! (bit1 DTCM, bit2 AHBP, bit3 AXIM) and AXIMTYPE[10:8] (2=SLVERR, 3=DECERR).

const std = @import("std");

/// Decoded fault snapshot. On any fault the handler fills this in and halts,
/// so with the debugger attached you just read one symbol:  `p fault.last_fault`
/// (or in your IDE's watch/expressions view). No UART needed.
pub const FaultInfo = extern struct {
    magic: u32, // 0xFA017000 once written (proves it was populated)
    kind: u32, // 0 HardFault, 1 MemManage, 2 BusFault, 3 UsageFault
    cfsr: u32,
    hfsr: u32,
    mmfar: u32,
    bfar: u32,
    abfsr: u32,
    // Decoded convenience flags
    bfar_valid: u32,
    precise: u32, // precise BusFault -> pc/bfar exact
    imprecise: u32, // imprecise (buffered store) -> pc approximate, bfar invalid
    aximtype: u32, // 2 = SLVERR, 3 = DECERR (unmapped/wild)
    // Stacked exception frame (true faulting context)
    r0: u32,
    r1: u32,
    r2: u32,
    r3: u32,
    r12: u32,
    lr: u32,
    pc: u32,
    xpsr: u32,
};

pub var last_fault: FaultInfo = std.mem.zeroes(FaultInfo);
pub var fault_count: u32 = 0;

comptime {
    // Force the naked trampolines to be semantically analyzed even before they
    // are wired into microzig_options, so asm errors surface at build time.
    _ = &hard_fault;
    _ = &mem_manage_fault;
    _ = &bus_fault;
    _ = &usage_fault;
}

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

fn reg(comptime addr: u32) u32 {
    return @as(*volatile u32, @ptrFromInt(addr)).*;
}

/// Called from the naked trampolines: r0 = stacked frame, r1 = kind index.
/// Fills `last_fault` and halts (breakpoint), so it's readable via the debugger.
export fn fault_report(frame: *const StackFrame, kind: u32) callconv(.c) void {
    // Block all further interrupts/faults so we don't recurse and clobber the
    // first snapshot. (No @breakpoint here: with no debugger attached a BKPT
    // escalates to HardFault and re-enters this handler.)
    asm volatile ("cpsid i");

    const cfsr = reg(0xE000ED28);
    const bfsr = (cfsr >> 8) & 0xFF; // BusFault status byte
    const abfsr = reg(0xE000EFA8);

    // Only capture the FIRST fault; ignore any later nested ones.
    if (fault_count != 0) {
        fault_count +%= 1;
        while (true) {}
    }
    fault_count = 1;

    // Write through a volatile pointer so the optimizer can't dead-store-
    // eliminate the snapshot (nothing in firmware *reads* last_fault; it's
    // only read by the debugger).
    const out: *volatile FaultInfo = &last_fault;
    out.* = .{
        .magic = 0xFA017000,
        .kind = kind,
        .cfsr = cfsr,
        .hfsr = reg(0xE000ED2C),
        .mmfar = reg(0xE000ED34),
        .bfar = reg(0xE000ED38),
        .abfsr = abfsr,
        .bfar_valid = @intFromBool((bfsr & 0x80) != 0),
        .precise = @intFromBool((bfsr & 0x02) != 0),
        .imprecise = @intFromBool((bfsr & 0x04) != 0),
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

    // `last_fault` now holds the decoded snapshot. Spin (no BKPT, so this does
    // not recurse when no debugger is attached). Halt here from the debugger and
    // read `fault.last_fault`.
    while (true) {
        asm volatile ("wfi");
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
