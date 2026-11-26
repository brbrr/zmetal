//! I2C1 as the target at `panel_proto.address`, interrupt-driven, with clock
//! stretching on: each bus event goes to a `panel_link.Link`, which knows
//! what to answer and when a write is a command.
//!
//! Sequences from RM0490 25.4.8 (docs.dirba.io mirror): target
//! initialisation (Figure 228), target transmitter with the first byte
//! flushed at the address match (Figures 229 and 231: "ADDR ISR: check
//! ADDCODE and DIR, set TXE, set ADDRCF"; the byte written at the last TXIS
//! before the master's NACK is not sent), target receiver (Figure 232).
//!
//! I2C_TIMINGR for I2CCLK = PCLK = 48 MHz, Fast-mode 400 kHz: RM0490
//! 25.4.10 Table 115, "Timing settings for f_I2CCLK of 48 MHz", Fm column:
//! PRESC 0x5, SCLL 0x9, SCLH 0x3, SDADEL 0x3, SCLDEL 0x3 = 0x5033_0309.
//! A target uses only PRESC, SDADEL and SCLDEL (SCLL and SCLH time a
//! controller's clock); the table's 500 ns data set-up time covers the
//! I2C-bus maximum rise time of 300 ns (Table 110). The table was read
//! through a third-party mirror of the RM, not ST's PDF. ST's CubeMX value
//! for the same clock, 0x0090273D (STM32CubeC0 3554bc3, NUCLEO-C031C6
//! I2C_TwoBoards_MasterRx_SlaveTx_IT_Init/Src/main.c lines 40-45), assumes a
//! 100 ns rise time; it was not chosen because the bus's real rise time is
//! not known before the board exists.

const microzig = @import("microzig");
const panel = @import("panel");
const pins = @import("pins.zig");

const proto = panel.panel_proto;
const Link = panel.panel_link.Link;

const chip = microzig.chip;
const RCC = chip.peripherals.RCC;
const I2C1 = chip.peripherals.I2C1;
const nvic = microzig.cpu.peripherals.nvic;

pub const timingr: u32 = 0x5033_0309;

/// I2C_ISR bits (generated definitions, i2c_v2).
const isr = struct {
    const txe: u32 = 1 << 0;
    const txis: u32 = 1 << 1;
    const rxne: u32 = 1 << 2;
    const addr: u32 = 1 << 3;
    const nackf: u32 = 1 << 4;
    const stopf: u32 = 1 << 5;
    const berr: u32 = 1 << 8;
    const arlo: u32 = 1 << 9;
    const ovr: u32 = 1 << 10;
    const dir_read: u32 = 1 << 16;
};
/// I2C_ICR bits.
const icr = struct {
    const addrcf: u32 = 1 << 3;
    const nackcf: u32 = 1 << 4;
    const stopcf: u32 = 1 << 5;
    const errors: u32 = (1 << 8) | (1 << 9) | (1 << 10); // BERRCF, ARLOCF, OVRCF
};
/// I2C_CR1: PE, TXIE, RXIE, ADDRIE, NACKIE, STOPIE, ERRIE; NOSTRETCH 0
/// (stretching on), filters at reset (analog on, digital off), SBC 0.
const cr1_on: u32 = 0b1011_1111;
/// I2C_OAR1: OA1 (7-bit, in bits 7:1) and OA1EN (bit 15).
const oar1_address: u32 = @as(u32, proto.address) << 1;
const oar1_en: u32 = 1 << 15;

/// RCC_APBENR1.I2C1EN (bit 21).
const apbenr1_i2c1en: u32 = 1 << 21;
/// I2C1's NVIC line (generated: I2C1 = 23).
const irq = 23;

/// Configures and enables the target at `proto.address`, with the I2C1
/// interrupt at `priority` (the NVIC's top two bits on the Cortex-M0+).
/// I2C1 was reset by `start.normalise`; I2CCLK is PCLK (RCC_CCIPR reset value).
pub fn init(priority: u8) void {
    RCC.APBENR1.raw = RCC.APBENR1.raw | apbenr1_i2c1en;
    _ = RCC.APBENR1.raw;
    pins.initI2c();

    // RM0490 Figures 225 and 228: PE 0, filters, timing, NOSTRETCH, PE 1;
    // OA1EN cleared, then the address with OA1EN, then the interrupts.
    I2C1.CR1.raw = 0;
    I2C1.TIMINGR.raw = timingr;
    I2C1.OAR1.raw = 0;
    I2C1.OAR2.raw = 0;
    I2C1.OAR1.raw = oar1_address;
    I2C1.OAR1.raw = oar1_address | oar1_en;
    I2C1.CR1.raw = cr1_on;

    // IPR5 holds lines 20..23; line 23 is bits 31:24. Word access only on
    // the Cortex-M0+.
    const ipr5: *volatile u32 = @ptrFromInt(0xE000_E400 + 4 * (irq / 4));
    ipr5.* = (ipr5.* & ~(@as(u32, 0xFF) << 24)) | (@as(u32, priority) << 24);
    nvic.ICPR = 1 << irq;
    nvic.ISER = 1 << irq;
}

/// Turns the target off (PE 0 releases SCL and SDA), so nothing on the bus
/// is held while the bootloader is entered.
pub fn stop() void {
    nvic.ICER = 1 << irq;
    I2C1.CR1.raw = 0;
}

/// The I2C1 interrupt: passes every pending event to `link`, in bus order
/// (the last byte of a write before its STOP, a STOP before the next
/// address), and returns the command a STOP completed, if any. `frameNow`
/// gives the state to snapshot at a read's address match.
pub fn service(link: *Link, comptime frameNow: fn () proto.Frame) ?proto.Command {
    var command: ?proto.Command = null;
    const flags = I2C1.ISR.raw;

    if (flags & isr.rxne != 0) link.onByte(@truncate(I2C1.RXDR.raw));
    if (flags & isr.stopf != 0) {
        I2C1.ICR.raw = icr.stopcf;
        command = link.onStop();
    }
    if (flags & isr.addr != 0) {
        const reading = flags & isr.dir_read != 0;
        // Flush a byte left in TXDR by the previous read, so the first
        // byte sent is this frame's (TXIS follows once ADDR is cleared).
        if (reading) I2C1.ISR.raw = isr.txe;
        link.onAddress(reading, frameNow());
        I2C1.ICR.raw = icr.addrcf;
    }
    // Read again: TXIS rises when ADDR is cleared, and stays up until TXDR
    // is written.
    if (I2C1.ISR.raw & isr.txis != 0) I2C1.TXDR.raw = link.nextByte();
    if (flags & isr.nackf != 0) I2C1.ICR.raw = icr.nackcf; // the end of a read
    if (flags & (isr.berr | isr.arlo | isr.ovr) != 0) I2C1.ICR.raw = icr.errors;
    return command;
}
