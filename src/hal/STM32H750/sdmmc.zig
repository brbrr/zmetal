//! SDMMC1 + SD-card block driver for STM32H750 (sdmmc_v2 peripheral).
//!
//! Ported from the libdaisy / ST HAL reference (stm32h7xx_hal_sd.c,
//! stm32h7xx_ll_sdmmc.c, libdaisy src/per/sdmmc.cpp). Phase 1 = clock/pins +
//! peripheral init + SD identification (CMD0..CMD7, ACMD6 4-bit); block read/
//! write via the peripheral's internal DMA (IDMA) is layered on in Phase 2.
//!
//! Bring-up aids (temporary): `init_stage` advances step-by-step and `card`
//! fills in as identification proceeds, so progress is inspectable over SWD even
//! if a later step fails.

const std = @import("std");
const microzig = @import("microzig");
const chip = microzig.chip;
const clock = @import("clock.zig");
const gpio = @import("gpio.zig");

const regs = chip.peripherals.SDMMC1;
const rcc = chip.peripherals.RCC;

/// SDMMC kernel clock = PLL2R, 200 MHz on the daisy clock config.
/// SDMMC_CK = KERNEL_CLK / (2 * CLKDIV).
const KERNEL_CLK_HZ: u32 = 200_000_000;
const CLKDIV_INIT: u10 = 250; // -> 400 kHz identification clock
const CLKDIV_XFER: u10 = 4; //   -> 25 MHz transfer clock

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
};

pub const CardType = enum { sdsc, sdhc };

pub const CardInfo = struct {
    card_type: CardType = .sdhc,
    rca: u16 = 0,
    block_count: u32 = 0, // number of 512-byte logical blocks
    cid: [4]u32 = .{ 0, 0, 0, 0 },
    csd: [4]u32 = .{ 0, 0, 0, 0 },
};

/// Populated as identification proceeds; readable over the debugger.
pub var card: CardInfo = .{};
/// Advances step-by-step during init (bring-up aid).
pub var init_stage: u32 = 0;

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
    init_stage = 0;
    card = .{};

    // --- Clock + pins ---
    rcc.D1CCIPR.modify(.{ .SDMMCSEL = .PLL2_R });
    rcc.AHB3ENR.modify(.{ .SDMMC1EN = 1 });
    _ = rcc.AHB3ENR.read(); // RCC settle readback
    configurePins();
    init_stage = 1;

    // --- Peripheral: 400 kHz, 1-bit, power on ---
    regs.CLKCR.write_raw(@as(u32, CLKDIV_INIT)); // CLKDIV, WIDBUS=1-bit, rest 0
    regs.POWER.modify(.{ .PWRCTRL = 0b11 }); // power on
    clock.delay_ms(2); // >= 74 SD-clock cycles (~185us at 400kHz)
    init_stage = 2;

    // --- Identification ---
    try sendCmd(0, 0, .none); // CMD0 GO_IDLE_STATE
    init_stage = 3;

    try sendCmd(8, 0x1AA, .short); // CMD8 SEND_IF_COND (SDHC/v2 required)
    init_stage = 4;

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
    init_stage = 5;

    try sendCmd(2, 0, .long); // CMD2 ALL_SEND_CID
    card.cid = readResp4();
    init_stage = 6;

    try sendCmd(3, 0, .short); // CMD3 SEND_RELATIVE_ADDR
    card.rca = @intCast(resp1() >> 16);
    init_stage = 7;

    try sendCmd(9, @as(u32, card.rca) << 16, .long); // CMD9 SEND_CSD
    card.csd = readResp4();
    parseCsdV2();
    init_stage = 8;

    try sendCmd(7, @as(u32, card.rca) << 16, .short); // CMD7 SELECT_CARD
    try sendCmd(16, 512, .short); // CMD16 SET_BLOCKLEN
    init_stage = 9;

    // --- Switch to 4-bit bus + transfer clock ---
    try sendCmd(55, @as(u32, card.rca) << 16, .short); // APP_CMD with RCA
    try sendCmd(6, 2, .short); // ACMD6 SET_BUS_WIDTH = 4-bit
    regs.CLKCR.write_raw(@as(u32, CLKDIV_XFER) | (@as(u32, 1) << 14)); // CLKDIV + WIDBUS=4-bit
    init_stage = 10;
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
