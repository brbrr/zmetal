//! QUADSPI driver for the Daisy Seed's IS25LP064A NOR flash (8 MB @ 0x9000_0000).
//!
//! Single-line (1-1-1) indirect commands for read/program/erase, plus a
//! memory-mapped read mode. Ported from libdaisy's `src/per/qspi.cpp`.

const microzig = @import("microzig");
const gpio = @import("gpio.zig");

const chip = microzig.chip;
const regs = chip.peripherals.QUADSPI;
const rcc = chip.peripherals.RCC;

pub const Error = error{Timeout};

/// QUADSPI_CLK = kernel clock / (PRESCALER + 1). Kernel clock is D1HCLK.
const PRESCALER: u8 = 1;
/// Backstop for all status polls so a wedged peripheral can't hang the caller.
const POLL_LIMIT: u32 = 1_000_000;
/// Dummy cycles for FAST_READ (0x0B): required for turnaround margin at this
/// board's QSPI clock — a 0-dummy read (0x03) missamples above ~50 MHz.
const READ_DUMMY: u5 = 8;
/// Status-register value written at init: block-protect BP0-3 = 0 (else
/// program/erase are silently ignored), SRWD = 0, QE = 1 (disables WP#/HOLD#).
const SR_DEFAULT: u8 = 0x40;

/// IS25LP064A opcodes (subset used here).
const Op = enum(u8) {
    reset_enable = 0x66,
    reset = 0x99,
    write_enable = 0x06,
    read_status = 0x05,
    write_status = 0x01,
    read_id = 0x9F,
    fast_read = 0x0B,
    page_program = 0x02,
    sector_erase = 0xD7,
};

/// Debugger-inspectable self-test results (see `selfTest`).
pub var st_id: u32 = 0; // JEDEC ID (IS25LP064A = 0x009D_6017)
pub var st_ok: u32 = 0; // 1 = indirect erase/write/read-back passed + ID matched
pub var st_mm_ok: u32 = 0; // 1 = memory-mapped read-back passed

comptime {
    // ReleaseSafe would dead-strip these write-only globals; pin them as named
    // symbols so they survive and are readable over SWD.
    @export(&st_id, .{ .name = "qspi_st_id" });
    @export(&st_ok, .{ .name = "qspi_st_ok" });
    @export(&st_mm_ok, .{ .name = "qspi_st_mm_ok" });
}

// --- Low-level command engine ------------------------------------------------

/// The CCR fields this driver varies; the rest are always 0. Instruction is
/// always single-line; an address, when present, is single-line 24-bit. Written
/// whole (not RMW) so a prior command leaves no stale bits.
const Ccr = struct {
    op: Op,
    admode: u2 = 0, // 0 = none, 1 = single-line address
    dmode: u2 = 0, // 0 = none, 1 = single-line data
    fmode: u2 = 0, // 0 = indirect write, 1 = indirect read, 3 = memory-mapped
    dcyc: u5 = 0,
};

fn setCcr(c: Ccr) void {
    regs.CCR.write(.{
        .INSTRUCTION = @intFromEnum(c.op),
        .IMODE = 0b01,
        .ADMODE = c.admode,
        .ADSIZE = 0b10, // 24-bit (ignored when ADMODE = 0)
        .ABMODE = 0,
        .ABSIZE = 0,
        .DCYC = c.dcyc,
        .DMODE = c.dmode,
        .FMODE = c.fmode,
        .SIOO = 0,
        .FRCM = 0,
        .DHHC = 0,
        .DDRM = 0,
    });
}

/// Data phase of a command: none, read into a buffer, or write from one.
const Data = union(enum) {
    none,
    read: []u8,
    write: []const u8,
};

/// Byte-wide view of the FIFO data register. The QUADSPI FIFO consumes exactly
/// one transfer byte per byte-access to DR (RM0433), which handles arbitrary
/// lengths without 32-bit pack/unpack. microzig's mmio has no sub-word accessor,
/// so this is a raw byte pointer to the register.
const dr: *volatile u8 = @ptrFromInt(@intFromPtr(&regs.DR));

/// Spin until `ready(regs.SR.read())` is true, bounded by POLL_LIMIT.
fn poll(comptime ready: anytype) Error!void {
    var spins: u32 = 0;
    while (!ready(regs.SR.read())) : (spins += 1) {
        if (spins >= POLL_LIMIT) return error.Timeout;
    }
}

fn waitNotBusy() Error!void {
    return poll(struct {
        fn f(s: anytype) bool {
            return s.BUSY == 0;
        }
    }.f);
}

/// Issue one indirect command: instruction (+ optional 24-bit address, dummy
/// cycles, and single-line data phase). Unifies WREN/reset/status/read/program.
fn transfer(op: Op, addr: ?u32, dcyc: u5, data: Data) Error!void {
    try waitNotBusy();

    const len: usize = switch (data) {
        .none => 0,
        inline .read, .write => |b| b.len,
    };
    if (len > 0) regs.DLR.write(.{ .DL = @intCast(len - 1) }); // byte count - 1

    setCcr(.{
        .op = op,
        .admode = if (addr != null) 0b01 else 0,
        .dmode = if (len > 0) 0b01 else 0,
        .fmode = switch (data) {
            .read => 0b01,
            else => 0b00,
        },
        .dcyc = dcyc,
    });

    // Writing AR (with address) or reading CCR (without) dispatches the command.
    if (addr) |a| regs.AR.write(.{ .ADDRESS = a }) else _ = regs.CCR.read();

    switch (data) {
        .none => try waitNotBusy(),
        .read => |b| {
            for (b) |*byte| {
                try poll(struct {
                    fn f(s: anytype) bool {
                        return s.FLEVEL != 0;
                    }
                }.f);
                byte.* = dr.*;
            }
            try waitTcf();
        },
        .write => |b| {
            for (b) |byte| {
                try poll(struct {
                    fn f(s: anytype) bool {
                        return s.FTF != 0;
                    }
                }.f);
                dr.* = byte;
            }
            try waitTcf();
        },
    }
}

fn waitTcf() Error!void {
    try poll(struct {
        fn f(s: anytype) bool {
            return s.TCF != 0;
        }
    }.f);
    regs.FCR.write(.{ .CTEF = 0, .CTCF = 1, .CSMF = 0, .CTOF = 0 }); // W1C
}

// --- Status helpers ----------------------------------------------------------

fn readStatus() Error!u8 {
    var byte: [1]u8 = undefined;
    try transfer(.read_status, null, 0, .{ .read = &byte });
    return byte[0];
}

/// WREN, then poll until the write-enable latch (SR bit 1) is set.
fn writeEnable() Error!void {
    try transfer(.write_enable, null, 0, .none);
    var spins: u32 = 0;
    while ((try readStatus()) & 0x02 == 0) : (spins += 1) {
        if (spins >= POLL_LIMIT) return error.Timeout;
    }
}

/// Poll until WIP (SR bit 0) clears — after program/erase.
fn waitWip() Error!void {
    var spins: u32 = 0;
    while ((try readStatus()) & 0x01 != 0) : (spins += 1) {
        if (spins >= POLL_LIMIT) return error.Timeout;
    }
}

/// SysTick-independent busy-wait, for the flash's reset-recovery time.
fn spin(count: u32) void {
    var i: u32 = 0;
    while (i < count) : (i += 1) asm volatile ("" ::: .{ .memory = true });
}

// --- Public API --------------------------------------------------------------

/// Bring up QUADSPI + the flash chip. Usable via read/write/eraseSector after.
pub fn init() Error!void {
    rcc.AHB3ENR.modify(.{ .QUADSPIEN = 1 });
    _ = rcc.AHB3ENR.read(); // RCC settle readback
    configurePins();

    regs.CR.write_raw(0); // disable + clear (safe after a warm reset)
    // FSIZE = log2(8 MiB) - 1 = 22; CSHT = 1 (2 cycles CS-high, 0-indexed).
    regs.DCR.write(.{ .CKMODE = 0, .CSHT = 1, .FSIZE = 22 });
    regs.CR.modify(.{ .PRESCALER = PRESCALER, .EN = 1 });

    // Reset the flash to a known state, then clear block-protect + set QE so
    // program/erase aren't silently blocked (WP#/HOLD# are held high as GPIO).
    try transfer(.reset_enable, null, 0, .none);
    try transfer(.reset, null, 0, .none);
    spin(20_000); // tRST recovery

    try writeEnable();
    try transfer(.write_status, null, 0, .{ .write = &[_]u8{SR_DEFAULT} });
    try waitWip();
}

/// JEDEC ID, packed MSB-first (manufacturer in bits [23:16]).
fn readId() Error!u32 {
    var buf: [3]u8 = undefined;
    try transfer(.read_id, null, 0, .{ .read = &buf });
    return (@as(u32, buf[0]) << 16) | (@as(u32, buf[1]) << 8) | buf[2];
}

/// Read `dst.len` bytes from `addr` (indirect mode; any length).
pub fn read(addr: u32, dst: []u8) Error!void {
    var off: usize = 0;
    while (off < dst.len) {
        const chunk = @min(dst.len - off, 256);
        try transfer(.fast_read, addr + @as(u32, @intCast(off)), READ_DUMMY, .{ .read = dst[off..][0..chunk] });
        off += chunk;
    }
}

/// Program up to 256 bytes within a single page (no page-boundary crossing).
pub fn writePage(addr: u32, data: []const u8) Error!void {
    try writeEnable();
    try transfer(.page_program, addr, 0, .{ .write = data });
    try waitWip();
}

/// Program `data`, splitting across 256-byte page boundaries.
pub fn write(addr: u32, data: []const u8) Error!void {
    const PAGE: u32 = 256;
    var off: usize = 0;
    var cur = addr;
    while (off < data.len) {
        const room = PAGE - (cur & (PAGE - 1));
        const chunk = @min(data.len - off, room);
        try writePage(cur, data[off..][0..chunk]);
        cur +%= @intCast(chunk);
        off += chunk;
    }
}

/// Erase the 4 KB sector containing `addr`.
pub fn eraseSector(addr: u32) Error!void {
    const SECTOR: u32 = 4096;
    try writeEnable();
    try transfer(.sector_erase, addr & ~(SECTOR - 1), 0, .none);
    try waitWip();
}

/// Abort an in-progress operation and leave memory-mapped mode. The peripheral
/// self-clears CR.ABORT when done.
fn abort() void {
    regs.CR.modify(.{ .ABORT = 1 });
    var spins: u32 = 0;
    while (regs.CR.read().ABORT != 0) : (spins += 1) {
        if (spins >= POLL_LIMIT) return;
    }
}

/// Switch to memory-mapped mode: flash is then readable directly at `BASE + addr`
/// until the next indirect command. Aborts first to flush residual FIFO/transfer
/// state (otherwise the first mapped AHB read faults on a wedged controller).
pub fn enableMemoryMapped() Error!void {
    abort();
    try waitNotBusy();
    setCcr(.{ .op = .fast_read, .admode = 0b01, .dmode = 0b01, .fmode = 0b11, .dcyc = READ_DUMMY });
}

// --- Pins --------------------------------------------------------------------

/// NCS/CLK/IO0/IO1 as QUADSPI AF; IO2/IO3 (WP#/HOLD#) as GPIO driven HIGH, since
/// this single-line driver never uses them as data lines and they must stay
/// deasserted.
fn configurePins() void {
    gpio.configureAlternates(&.{
        .{ .port = "G", .num = "6", .af = .af10 }, // NCS
        .{ .port = "F", .num = "10", .af = .af9 }, // CLK
        .{ .port = "F", .num = "8", .af = .af10 }, // IO0
        .{ .port = "F", .num = "9", .af = .af10 }, // IO1
    });

    // IO3 = PF6, IO2 = PF7 (WP#/HOLD#): GPIO output driven HIGH — this
    // single-line driver never uses them as data lines.
    const high = struct {
        fn f(comptime num: []const u8) void {
            const p = comptime gpio.Pin.init("F", num, .{ .mode = .output, .speed = .VeryHighSpeed });
            p.configure();
            p.write(.High);
        }
    }.f;
    high("6");
    high("7");
}

// --- Self-test (debug; not run at boot) --------------------------------------

/// Erase/write/read-back a scratch sector via both indirect and memory-mapped
/// reads. Records results in `st_id`/`st_ok`/`st_mm_ok`.
pub fn selfTest() void {
    const BASE: usize = 0x9000_0000;
    const PAGE: u32 = 256;

    init() catch return;
    st_id = readId() catch 0;

    const scratch: u32 = 0x0010_0000; // 1 MB in, away from anything else
    var buf: [PAGE]u8 = undefined;
    for (&buf, 0..) |*b, i| b.* = @truncate(i *% 7 + 1);

    eraseSector(scratch) catch return;
    writePage(scratch, &buf) catch return;
    read(scratch, &buf) catch return;

    var ok = st_id == 0x009D_6017;
    for (buf, 0..) |b, i| ok = ok and b == @as(u8, @truncate(i *% 7 + 1));
    st_ok = @intFromBool(ok);

    // Same bytes via the memory-mapped path.
    enableMemoryMapped() catch return;
    const mm: [*]const volatile u8 = @ptrFromInt(BASE + scratch);
    var mm_ok = true;
    for (0..PAGE) |i| mm_ok = mm_ok and mm[i] == @as(u8, @truncate(i *% 7 + 1));
    st_mm_ok = @intFromBool(mm_ok);
}
