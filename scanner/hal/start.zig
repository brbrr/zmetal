//! The scanner's start: its vector table and reset path (S0), the reset
//! state it puts back (S1), the strap check (S2) and the "flash is empty"
//! flag (S3) of "Never unflashable" in the panel scanner plan.
//!
//! microzig's start-up is not used (the firmware never calls
//! `microzig.export_startup()`): its flash vector table binds `Reset` to
//! `startup_logic._start` itself, not through a symbol a firmware could
//! override, and that is a C function that runs on whatever stack pointer
//! it is entered with. The image is started two ways: by a reset, which
//! loads the stack pointer from the vector table, and by the ROM
//! bootloader's Go, which AN4221 only promises jumps to the word after the
//! address given. So the reset path here loads the stack pointer itself,
//! before anything else.
//!
//! Register values: ST's RM0490 (read through the docs.dirba.io mirror; the
//! ST PDF was unreachable), ST's stm32c031xx.h and the C0 HAL
//! (github.com/STMicroelectronics/stm32c0xx-hal-driver), as named at each use.

const microzig = @import("microzig");
const chip = microzig.chip;
const cpu = microzig.cpu;

const RCC = chip.peripherals.RCC;
const FLASH = chip.peripherals.FLASH;
const pins = @import("pins.zig");
const scb = cpu.peripherals.scb;
const nvic = cpu.peripherals.nvic;
const systick = cpu.peripherals.systick;

/// The image's start, where VTOR points (also in a trial, whose first 8
/// bytes are erased: the reset entries are not used after a reset).
pub const flash_base: u32 = 0x0800_0000;

// ============================================================================
// S0: vector table and reset path

/// The end of SRAM, from scanner/scanner.ld: the initial stack pointer.
const estack = @extern(*const anyopaque, .{ .name = "_estack" });

/// Puts the vector table at the start of flash (section `.vectors`,
/// scanner/scanner.ld) with the reset path below, `sys_tick` and `i2c1` as
/// the two interrupts the firmware uses, and `fault` for NMI and HardFault.
/// Every other entry is microzig's `unhandled`, which panics.
pub fn exportVectorTable(
    comptime sys_tick: fn () callconv(.c) void,
    comptime i2c1: fn () callconv(.c) void,
    comptime fault: fn () callconv(.c) void,
) void {
    const vectors = struct {
        const table: chip.VectorTable = .{
            .initial_stack_pointer = estack,
            .Reset = .{ .naked = &reset },
            .NMI = .{ .c = &fault },
            .HardFault = .{ .c = &fault },
            .SysTick = .{ .c = &sys_tick },
            .I2C1 = .{ .c = &i2c1 },
        };
    };
    @export(&vectors.table, .{ .name = "vector_table", .section = ".vectors", .linkage = .strong });
    @export(&reset, .{ .name = "_start", .linkage = .strong });
}

/// The reset vector (S0). Naked, so the compiler adds nothing before it.
/// First it masks interrupts, so nothing the bootloader left pending runs
/// through the bootloader's vectors on our stack. Then it loads the stack
/// pointer with `_estack`, the value of the image's own first vector (a
/// literal, not a read of 0x0800_0000: in a trial those bytes are erased),
/// and makes thread mode use it (CONTROL = 0: MSP, privileged). Then, still
/// before `.data` and `.bss` are touched, VTOR = 0x0800_0000 and MPU_CTRL =
/// 0 (`normalise` writes both again): a fault in the copies then goes to
/// this image's handler, and an MPU the bootloader left on cannot fault
/// them. Both are plain stores of constants through registers: no stack,
/// no RAM. Then `.data` and `.bss` and main.
fn reset() callconv(.naked) void {
    asm volatile (
        \\cpsid i
        \\ldr r0, =_estack
        \\msr msp, r0
        \\movs r0, #0
        \\msr control, r0
        \\isb
        \\ldr r1, =0xE000ED08 @ VTOR
        \\ldr r0, =0x08000000
        \\str r0, [r1]
        \\ldr r1, =0xE000ED94 @ MPU_CTRL
        \\movs r0, #0
        \\str r0, [r1]
        \\dsb
        \\isb
        \\bl scanner_start
        \\.ltorg
    );
}

/// Runs on the stack `reset` set: `.data` (with the RAM code) and `.bss`,
/// then main.
fn start() callconv(.c) noreturn {
    microzig.utilities.initialize_system_memories(.all);
    @import("root").main();
}

comptime {
    @export(&start, .{ .name = "scanner_start" });
}

// ============================================================================
// S1: what the bootloader may have left behind, back to its reset state

/// The RCC reset values, RM0490 section 6.4 (power-on values where the RM
/// gives two).
const rcc_reset = struct {
    /// RCC_CR, RM0490 6.4.1: HSIDIV /4 (bits 13:11 = 010), HSIRDY, HSION,
    /// HSIKERDIV /3 (bits 7:5 = 010). HSIRDY is read-only; writing it is
    /// ignored. HSEON and HSEBYP 0.
    const cr: u32 = 0x0000_1540;
    /// RCC_ICSCR, RM0490 6.4.2: 0x0000_40XX, HSITRIM = 64 in bits 14:8;
    /// HSICAL (7:0) is read-only. ST's LL_RCC_DeInit writes the same trim.
    const icscr: u32 = 0x0000_4000;
    /// RCC_CFGR, RM0490 6.4.3: HSISYS as SYSCLK, HPRE and PPRE /1, no MCO.
    const cfgr: u32 = 0;
    /// RCC_CICR: every defined clear bit (LSIRDYC 0, LSERDYC 1, HSIRDYC 3,
    /// HSERDYC 4, CSSC 8, LSECSSC 9), generated definitions.
    const cicr_all: u32 = 0x0000_031B;
    /// RCC_IOPENR (generated: GPIOENR), RM0490 6.4.12.
    const iopenr: u32 = 0;
    /// RCC_AHBENR, RM0490 6.4.13: FLASHEN (bit 8) only. The flash clock is
    /// what this code runs from: it stays on.
    const ahbenr: u32 = 0x0000_0100;
    /// RCC_APBENR1 and RCC_APBENR2, RM0490 6.4.14 and 6.4.15.
    const apbenr1: u32 = 0;
    const apbenr2: u32 = 0;
    /// RCC_CCIPR, RM0490 6.4.20: I2C1 clocked from PCLK.
    const ccipr: u32 = 0;
};

/// The peripherals pulsed through their RCC resets: the three GPIO ports
/// and I2C1 this firmware uses, and SYSCFG and PWR, whose registers act on
/// those pins (SYSCFG_CFGR1: PA11/PA12 remap, FM+ drive on PB6..PB9;
/// PWR_PUCRx/PDCRx with CR3.APC: pulls). Never FLASHRST (AHBRSTR bit 8):
/// the flash interface is what this code runs from. ST's own HAL_DeInit
/// (stm32c0xx_hal.c lines 176-196) resets every peripheral this way from
/// running code.
const pulsed = struct {
    /// RCC_IOPRSTR: GPIOARST 0, GPIOBRST 1, GPIOCRST 2 (stm32c031xx.h).
    const ioprstr: u32 = 0b111;
    /// RCC_APBRSTR1: I2C1RST 21, PWRRST 28 (stm32c031xx.h).
    const apbrstr1: u32 = (1 << 21) | (1 << 28);
    /// RCC_APBRSTR2: SYSCFGRST 0 (stm32c031xx.h).
    const apbrstr2: u32 = 1 << 0;
};

/// RCC_CR.HSERDY (bit 17), RCC_CFGR.SWS (bits 5:3), FLASH_ACR.LATENCY (2:0).
const cr_hserdy: u32 = 1 << 17;
const cfgr_sws: u32 = 0b111 << 3;
const acr_latency: u32 = 0b111;

/// MPU_CTRL, which microzig does not map for this chip (its generated
/// properties leave has_mpu unknown). The C031 has an MPU: __MPU_PRESENT 1
/// in stm32c031xx.h; 0 is its reset value (off).
const mpu_ctrl: *volatile u32 = @ptrFromInt(0xE000_ED94);
const icsr_pendstclr: u32 = 1 << 25;
const icsr_pendsvclr: u32 = 1 << 27;

/// S1: puts back what the bootloader's Go may leave behind, so the image
/// starts the same way from Go and from a reset: VTOR at this image, MPU
/// off, SCR at its reset value, SysTick off, every NVIC line disabled and
/// not pending, the clock tree at its reset values (HSISYS = HSI48 / 4 =
/// 12 MHz, flash latency 0), the peripheral clocks at their reset values,
/// the used peripherals pulsed through their resets. Runs with interrupts
/// masked (`reset`).
pub fn normalise() void {
    scb.VTOR = flash_base;
    mpu_ctrl.* = 0;
    // SCR reset value 0 (ARMv6-M): a SLEEPONEXIT the bootloader left set
    // would put the core to sleep on every return from SysTick or I2C1,
    // and the main loop, which runs the bootloader command, would never run.
    scb.SCR.raw = 0;
    asm volatile ("dsb\nisb" ::: .{ .memory = true });

    systick.CTRL.raw = 0;
    scb.ICSR.raw = icsr_pendstclr | icsr_pendsvclr;
    nvic.ICER = 0xFFFF_FFFF;
    nvic.ICPR = 0xFFFF_FFFF;

    // Clock tree. The ROM's HCLK is not known (CFGR = 0 alone could take
    // HSI48 / 1 with HPRE / 2 to 48 MHz), so first one wait state, which
    // holds for any HCLK up to 48 MHz (RM0490 Table 14; ST adjusts wait
    // states before touching HSIDIV, stm32c0xx_hal_rcc.c lines 167-168),
    // read back until it holds. Then RM0490 4.3.2 "Decreasing HCLK
    // frequency": HSISYS as SYSCLK and the prescalers, wait for SWS, the
    // HSI divider, and the latency for 12 MHz last. HSI48 is on: the ROM
    // runs from it.
    FLASH.ACR.raw = (FLASH.ACR.raw & ~acr_latency) | 1;
    while (FLASH.ACR.raw & acr_latency != 1) {}
    RCC.CFGR.raw = rcc_reset.cfgr;
    while (RCC.CFGR.raw & cfgr_sws != 0) {}
    // HSEON off, then HSEBYP (writable once HSE is off), as LL_RCC_DeInit.
    RCC.CR.raw = rcc_reset.cr;
    while (RCC.CR.raw & cr_hserdy != 0) {}
    RCC.CR.raw = rcc_reset.cr;
    RCC.ICSCR.raw = rcc_reset.icscr;
    RCC.CIER.raw = 0;
    RCC.CICR.raw = rcc_reset.cicr_all;
    RCC.CCIPR.raw = rcc_reset.ccipr;
    // LATENCY 0 (RM0490 Table 14: up to 24 MHz), every other bit kept,
    // EMPTY above all (S3 decides about it).
    FLASH.ACR.raw = FLASH.ACR.raw & ~acr_latency;
    while (FLASH.ACR.raw & acr_latency != 0) {}

    // Resets first, while whatever clocks the bootloader left are still on
    // (ST's LL *_DeInit functions pulse without enabling the clock too).
    RCC.GPIORSTR.raw = pulsed.ioprstr;
    RCC.APBRSTR1.raw = pulsed.apbrstr1;
    RCC.APBRSTR2.raw = pulsed.apbrstr2;
    RCC.GPIORSTR.raw = 0;
    RCC.APBRSTR1.raw = 0;
    RCC.APBRSTR2.raw = 0;

    RCC.GPIOENR.raw = rcc_reset.iopenr;
    RCC.AHBENR.raw = rcc_reset.ahbenr;
    RCC.APBENR1.raw = rcc_reset.apbenr1;
    RCC.APBENR2.raw = rcc_reset.apbenr2;
}

// ============================================================================
// S2: the strap

/// The INT line, from the pin table (PB8), so the table's comptime guards
/// (no SWD pin, no pin twice) cover the strap too.
const strap = pins.int;
/// SysTick at the 12 MHz of `normalise`: 12000 counts per millisecond.
const reset_hclk_hz = 12_000_000;
/// 10 samples, 1 ms apart. The Daisy's side (`strap_hold_ms` in
/// src/hid/panel_update.zig): it holds INT low through a 10 ms NRST pulse
/// and for 50 ms after NRST is released. This chip leaves reset about 3 to
/// 7 ms after the release (the board's 100 nF on NRST, charged by this
/// chip's own pull-up; an estimate), and the tenth sample comes about 9 ms
/// after that, so the check ends about 12 to 16 ms into the 50 ms: a margin
/// of about three times. The numbers are not shared constants: a change on
/// either side needs the comment on both.
const strap_samples = 10;

/// S2, right after `normalise`, with only the INT pin's port clocked
/// (GPIOB): true when INT reads low on every one of 10 samples 1 ms apart:
/// the Daisy holds it low through a reset to ask for the bootloader. The
/// first high sample ends the check. Leaves SysTick off.
///
/// INT is read as an input with the pin's own pull-up on (PUPDR 01, about
/// 40 kOhm), not on the board's 10 kOhm alone: a board whose pull-up is
/// missing or open, or a line that is not connected, then reads high, no
/// strap, instead of floating low and making every image erase itself at
/// every start. The Daisy's open-drain low still wins against both pulls
/// in parallel. `pins.init` later makes INT an open-drain output with no
/// pull, as before.
pub fn strapHeld() bool {
    RCC.GPIOENR.raw = strap.port.clockBit(); // that port's clock only
    _ = RCC.GPIOENR.raw; // two cycles before the port answers (RM0490 6.2)
    const port = strap.port.regs();
    const field_mask: u32 = 0b11 << (2 * @as(u5, strap.num));
    const pull_up: u32 = 0b01 << (2 * @as(u5, strap.num));
    port.PUPDR.raw = (port.PUPDR.raw & ~field_mask) | pull_up; // the pin's own pull-up
    port.MODER.raw = port.MODER.raw & ~field_mask; // input

    systick.LOAD.raw = reset_hclk_hz / 1000 - 1;
    systick.VAL.raw = 0;
    systick.CTRL.raw = 0b101; // ENABLE, CLKSOURCE = processor clock, no interrupt

    var held = true;
    for (0..strap_samples) |i| {
        if (port.IDR.raw & (@as(u32, 1) << strap.num) != 0) {
            held = false;
            break;
        }
        if (i + 1 < strap_samples) {
            while (systick.CTRL.raw & (1 << 16) == 0) {} // COUNTFLAG: 1 ms
        }
    }
    systick.CTRL.raw = 0;
    return held;
}

// ============================================================================
// S3: the "flash is empty" flag

/// FLASH_ACR.EMPTY (bit 16; PROGEMPTY in stm32c031xx.h line 2287).
const acr_empty: u32 = 1 << 16;
const erased_word: u32 = 0xFFFF_FFFF;

/// True when the first flash word is programmed: a committed image, started
/// by a reset or a Go to 0x0800_0000. False in a trial, whose first 8 bytes
/// are still erased.
pub fn committed() bool {
    const first: *const volatile u32 = @ptrFromInt(flash_base);
    return first.* != erased_word;
}

/// S3 for a committed image: clears FLASH_ACR.EMPTY, so a later NRST pulse
/// starts this image and not the bootloader (the flag is otherwise only
/// re-read at power-on, RM0490 4.7.1). A read-modify-write that keeps
/// LATENCY and every other bit.
pub fn clearEmptyFlag() void {
    FLASH.ACR.raw = FLASH.ACR.raw & ~acr_empty;
}

/// S3 for a trial (rule amended 2026-11-26): sets FLASH_ACR.EMPTY, the
/// truthful value with the first word erased. The bootloader may have
/// cleared it while it programmed or at Go; set, any reset during the
/// trial (the Daisy's strap entry, or a lock-up and NRST) starts the ROM
/// and not this half-written image. A read-modify-write that keeps LATENCY
/// and every other bit.
pub fn setEmptyFlag() void {
    FLASH.ACR.raw = FLASH.ACR.raw | acr_empty;
}
