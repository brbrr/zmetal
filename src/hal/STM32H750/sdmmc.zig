//! SDMMC1 + SD-card block driver for STM32H750 (sdmmc_v2 peripheral).
//!
//! Hand-rolled register-level driver. The identification and IDMA transfer
//! sequences follow ST's SD driver; `readBlock`/`writeBlock` transfer
//! 512-byte blocks via the peripheral's internal DMA (IDMA). SDHC/SDXC only.

const std = @import("std");
const microzig = @import("microzig");
const chip = microzig.chip;
const clock = @import("clock.zig");
const gpio = @import("gpio.zig");
const cache = @import("cache.zig");
const daisy = @import("daisy.zig");

const regs = chip.peripherals.SDMMC1;
const rcc = chip.peripherals.RCC;

/// SDMMC1 kernel clock (SDMMCSEL = PLL2R), read from the computed clock tree —
/// the same mechanism SAI/SPI use. Rounded to the nearest MHz to shed the f32
/// noise in the tree's value (PLL outputs are MHz-granular): 200000976 -> 200MHz.
const KERNEL_CLK_HZ: u32 = @intFromFloat(@round(@as(f64, daisy.clock_outputs.DIVR2output) / 1_000_000.0) * 1_000_000.0);

/// SDMMC_CK = KERNEL_CLK / (2 * CLKDIV). Choose the smallest divider whose bus
/// clock does not exceed `target_hz` (ceil-divide so we never overshoot).
fn clkdivFor(comptime target_hz: u32) u10 {
    return @intCast((KERNEL_CLK_HZ + 2 * target_hz - 1) / (2 * target_hz));
}
const CLKDIV_INIT: u10 = clkdivFor(400_000); // <= 400 kHz identification clock
const CLKDIV_XFER: u10 = clkdivFor(25_000_000); // <= 25 MHz transfer clock

/// ICR mask that clears all static command+data status flags (CMSIS
/// SDMMC_STATIC_FLAGS).
const STATIC_FLAGS: u32 = 0x1FE0_0FFF;

/// Backstop spin count for status polls, so a wedged peripheral can't hang the
/// caller (the hardware CTIMEOUT flag is the normal card-absent signal).
const POLL_LIMIT: u32 = 1_000_000;

pub const Error = error{
    CmdTimeout,
    CmdCrcFail,
    CardUnresponsive,
    UnsupportedCard,
    PollTimeout,
    DataTimeout,
    DataCrcFail,
    DataError,
    OutOfRange,
};

pub const CardType = enum { sdsc, sdhc };

pub const CardInfo = struct {
    card_type: CardType = .sdhc,
    rca: u16 = 0,
    block_count: u32 = 0, // number of 512-byte logical blocks
    cid: [4]u32 = .{ 0, 0, 0, 0 },
    csd: [4]u32 = .{ 0, 0, 0, 0 },
};

/// Filled in by `init()`; read via `cardInfo()` / `blockCount()`.
var card: CardInfo = .{};

/// Card description from the last successful `init()`.
pub fn cardInfo() CardInfo {
    return card;
}

/// Card capacity in 512-byte logical blocks (0 until `init()` succeeds).
pub fn blockCount() u32 {
    return card.block_count;
}

const Resp = enum {
    none, // no response (CMD0)
    short, // R1/R6/R7 — CRC checked
    short_no_crc, // R3 (OCR) — has no CRC, CCRCFAIL is expected/ignored
    long, // R2 (CID/CSD)
};

fn clearFlags() void {
    regs.ICR.write_raw(STATIC_FLAGS);
}

/// Issue a command via the CPSM and wait for its response.
fn sendCmd(index: u6, arg: u32, resp: Resp) Error!void {
    clearFlags();
    regs.ARGR.write_raw(arg);

    const waitresp: u32 = switch (resp) {
        .none => 0,
        .short, .short_no_crc => 1,
        .long => 3,
    };
    // CMDINDEX[5:0] | WAITRESP[9:8] | CPSMEN(bit12)
    regs.CMDR.write_raw(@as(u32, index) | (waitresp << 8) | (1 << 12));

    var spins: u32 = 0;
    if (resp == .none) {
        while (regs.STAR.read().CMDSENT == 0) {
            spins += 1;
            if (spins >= POLL_LIMIT) return Error.PollTimeout;
        }
        clearFlags();
        return;
    }

    while (true) {
        const s = regs.STAR.read();
        if (s.CTIMEOUT == 1) {
            clearFlags();
            return Error.CmdTimeout;
        }
        if (s.CCRCFAIL == 1) {
            clearFlags();
            // R3 carries no CRC (CRC field is all 1s) — CCRCFAIL means the
            // response arrived, which is success for that type.
            if (resp == .short_no_crc) return;
            return Error.CmdCrcFail;
        }
        if (s.CMDREND == 1) {
            clearFlags();
            return;
        }
        spins += 1;
        if (spins >= POLL_LIMIT) return Error.PollTimeout;
    }
}

fn resp1() u32 {
    return regs.RESPR[0].read().CARDSTATUS;
}

fn readResp4() [4]u32 {
    return .{
        regs.RESPR[0].read().CARDSTATUS,
        regs.RESPR[1].read().CARDSTATUS,
        regs.RESPR[2].read().CARDSTATUS,
        regs.RESPR[3].read().CARDSTATUS,
    };
}

/// Compute the logical block count from a CSD v2 (SDHC/SDXC).
fn parseCsdV2() void {
    const c_size = ((card.csd[1] & 0x0000_003F) << 16) | ((card.csd[2] & 0xFFFF_0000) >> 16);
    card.block_count = (c_size + 1) * 1024;
}

/// Bring up SDMMC1 and identify the inserted SD card (SDHC assumed). On success,
/// `card` describes the card and the bus is in 4-bit mode at the transfer clock.
pub fn init() Error!void {
    card = .{};

    // --- Clock + pins ---
    rcc.D1CCIPR.modify(.{ .SDMMCSEL = .PLL2_R });
    rcc.AHB3ENR.modify(.{ .SDMMC1EN = 1 });
    _ = rcc.AHB3ENR.read(); // RCC settle readback
    configurePins();

    // --- Peripheral: 400 kHz, 1-bit, power on ---
    regs.CLKCR.write_raw(@as(u32, CLKDIV_INIT)); // CLKDIV, WIDBUS=1-bit, rest 0
    regs.POWER.modify(.{ .PWRCTRL = 0b11 }); // power on
    clock.delay_ms(2); // >= 74 SD-clock cycles (~185us at 400kHz)

    // --- Identification ---
    try sendCmd(0, 0, .none); // CMD0 GO_IDLE_STATE
    try sendCmd(8, 0x1AA, .short); // CMD8 SEND_IF_COND (SDHC/v2 required)

    // ACMD41 loop (CMD55 then ACMD41) until the OCR busy bit clears.
    var ocr: u32 = 0;
    var tries: u32 = 0;
    while (tries < 0xFFFF) : (tries += 1) {
        try sendCmd(55, 0, .short); // APP_CMD, RCA=0 during identification
        try sendCmd(41, 0xC110_0000, .short_no_crc); // ACMD41: HCS | voltage | S18R
        ocr = resp1();
        if (ocr & 0x8000_0000 != 0) break; // power-up done
    }
    if (ocr & 0x8000_0000 == 0) return Error.CardUnresponsive;
    card.card_type = if (ocr & 0x4000_0000 != 0) .sdhc else .sdsc; // CCS
    if (card.card_type != .sdhc) return Error.UnsupportedCard;

    try sendCmd(2, 0, .long); // CMD2 ALL_SEND_CID
    card.cid = readResp4();

    try sendCmd(3, 0, .short); // CMD3 SEND_RELATIVE_ADDR
    card.rca = @intCast(resp1() >> 16);

    try sendCmd(9, @as(u32, card.rca) << 16, .long); // CMD9 SEND_CSD
    card.csd = readResp4();
    parseCsdV2();

    try sendCmd(7, @as(u32, card.rca) << 16, .short); // CMD7 SELECT_CARD
    try sendCmd(16, 512, .short); // CMD16 SET_BLOCKLEN

    // --- Switch to 4-bit bus + transfer clock ---
    try sendCmd(55, @as(u32, card.rca) << 16, .short); // APP_CMD with RCA
    try sendCmd(6, 2, .short); // ACMD6 SET_BUS_WIDTH = 4-bit
    regs.CLKCR.write_raw(@as(u32, CLKDIV_XFER) | (@as(u32, 1) << 14)); // CLKDIV + WIDBUS=4-bit
}

// === Block I/O (IDMA) ============================================
//
// The caller's buffer may be in DTCM (not DMA-reachable) and SDMMC1's IDMA is a
// D1-domain master that also can't reach D2 SRAM, so transfers go through a
// bounce buffer in AXI SRAM (D1, `.axi_sram`), then are memcpy'd to/from the
// caller. AXI SRAM is cacheable, so readBlock/writeBlock do cache maintenance
// around the DMA. 32-byte aligned for the cache-by-address ops.
var bounce: [512]u8 align(32) linksection(".axi_sram") = undefined;

fn dataCleanup() void {
    regs.DLENR.write_raw(0);
    regs.DCTRL.write_raw(0);
    regs.IDMACTRLR.write_raw(0);
}

/// Run one 512-byte data transfer for `cmd_index` (CMD17 read / CMD24 write)
/// via IDMA into/out of `bounce`. `dctrl` selects direction (DTDIR).
fn transferBlock(cmd_index: u6, sector: u32, dctrl: u32) Error!void {
    clearFlags();
    regs.DCTRL.write_raw(0);
    regs.DTIMER.write_raw(0xFFFF_FFFF);
    regs.DLENR.write_raw(512);
    regs.IDMABASE0R.write_raw(@intFromPtr(&bounce));
    regs.IDMACTRLR.write_raw(1); // IDMAEN, single buffer
    regs.DCTRL.write_raw(dctrl);
    regs.ARGR.write_raw(sector); // SDHC: block index (no *512)
    // short response, CPSMEN, CMDTRANS (data transfer command)
    regs.CMDR.write_raw(@as(u32, cmd_index) | (1 << 8) | (1 << 12) | (1 << 6));

    var spins: u32 = 0;
    while (true) {
        const s = regs.STAR.read();
        if (s.CTIMEOUT == 1) {
            dataCleanup();
            clearFlags();
            return Error.CmdTimeout;
        }
        if (s.DTIMEOUT == 1) {
            dataCleanup();
            clearFlags();
            return Error.DataTimeout;
        }
        if (s.DCRCFAIL == 1) {
            dataCleanup();
            clearFlags();
            return Error.DataCrcFail;
        }
        if (s.RXOVERR == 1 or s.TXUNDERR == 1) {
            dataCleanup();
            clearFlags();
            return Error.DataError;
        }
        if (s.DATAEND == 1) break;
        spins += 1;
        if (spins >= POLL_LIMIT) {
            dataCleanup();
            clearFlags();
            return Error.PollTimeout;
        }
    }
    dataCleanup();
    clearFlags();
}

/// Poll CMD13 until the card returns to the TRANSFER (ready) state.
fn waitCardReady() Error!void {
    var spins: u32 = 0;
    while (true) {
        try sendCmd(13, @as(u32, card.rca) << 16, .short);
        const state = (resp1() >> 9) & 0xF; // CURRENT_STATE
        if (state == 4) return; // TRAN
        spins += 1;
        if (spins >= POLL_LIMIT) return Error.PollTimeout;
    }
}

/// Read one 512-byte block at `sector` (block index) into `dst`.
pub fn readBlock(sector: u32, dst: *[512]u8) Error!void {
    if (sector >= card.block_count) return Error.OutOfRange;
    // Clean so no stale dirty lines linger over the DMA target, run the DMA,
    // then invalidate so the CPU reads the freshly-DMA'd data (not cache).
    cache.clean_dcache_by_addr(@intFromPtr(&bounce), 512);
    try transferBlock(17, sector, (9 << 4) | (1 << 1)); // DBLOCKSIZE=512, DTDIR=read
    cache.invalidate_dcache_by_addr(@intFromPtr(&bounce), 512);
    @memcpy(dst, &bounce);
}

/// Write one 512-byte block `src` to `sector` (block index).
pub fn writeBlock(sector: u32, src: *const [512]u8) Error!void {
    if (sector >= card.block_count) return Error.OutOfRange;
    @memcpy(&bounce, src);
    // Clean so the IDMA reads the just-written data from RAM, not stale cache.
    cache.clean_dcache_by_addr(@intFromPtr(&bounce), 512);
    try transferBlock(24, sector, (9 << 4)); // DBLOCKSIZE=512, DTDIR=write
    try waitCardReady(); // wait out card programming before returning
}

fn configurePins() void {
    // SDMMC1: PC8=D0, PC9=D1, PC10=D2, PC11=D3, PC12=CK, PD2=CMD — all AF12.
    // Data/CMD lines carry pull-ups; CK is a push-pull output (no pull).
    inline for (.{ "8", "9", "10", "11" }) |p| {
        (comptime gpio.Pin.init("C", p, .{
            .mode = .{ .alternate = .af12 },
            .otype = .PushPull,
            .speed = .VeryHighSpeed,
            .pull = .PullUp,
        })).configure();
    }
    (comptime gpio.Pin.init("C", "12", .{
        .mode = .{ .alternate = .af12 },
        .otype = .PushPull,
        .speed = .VeryHighSpeed,
        .pull = .Floating,
    })).configure(); // CK
    (comptime gpio.Pin.init("D", "2", .{
        .mode = .{ .alternate = .af12 },
        .otype = .PushPull,
        .speed = .VeryHighSpeed,
        .pull = .PullUp,
    })).configure(); // CMD
}
