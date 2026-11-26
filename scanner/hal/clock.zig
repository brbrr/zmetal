//! The scanner's clocks: HSI48 undivided as the system clock (48 MHz, no
//! crystal on the board), and SysTick at 8 kHz for the scan tick.
//!
//! Flash latency, RM0490 4.3.2 Table 14 (docs.dirba.io mirror): 0 wait
//! states up to 24 MHz, 1 up to 48 MHz; to raise HCLK, set LATENCY first and
//! read it back until it holds, then change the clock. ST says the same in
//! stm32c0xx_hal_rcc.c (stm32c0xx-hal-driver 50844c4): the table at lines
//! 172-184, "the number of CPU wait states must be adjusted before any
//! eventual update on the HSI48 clock division factor" at lines 167-168, and
//! HAL_RCC_ClockConfig's order at lines 660-677. ST's 48 MHz example for
//! this chip (STM32CubeC0 3554bc3, Projects/NUCLEO-C031C6/Examples_LL/I2C/
//! I2C_TwoBoards_MasterRx_SlaveTx_IT_Init/Src/main.c, SystemClock_Config)
//! does exactly this: LATENCY_1, then HSIDIV /1, HSI as SYSCLK, AHB and
//! APB /1.

const microzig = @import("microzig");
const chip = microzig.chip;
const cpu = microzig.cpu;

const RCC = chip.peripherals.RCC;
const FLASH = chip.peripherals.FLASH;
const systick = cpu.peripherals.systick;
const scb = cpu.peripherals.scb;

pub const hclk_hz = 48_000_000;
pub const tick_hz = 8_000;
/// SysTick counts per tick: 6000 at 48 MHz.
pub const tick_counts = hclk_hz / tick_hz;

/// FLASH_ACR.LATENCY (bits 2:0), RCC_CR.HSIDIV (bits 13:11).
const acr_latency: u32 = 0b111;
const one_wait_state: u32 = 1;
const cr_hsidiv: u32 = 0b111 << 11;

/// From the reset clock `start.normalise` leaves (HSISYS = HSI48 / 4,
/// HSISYS selected, AHB and APB /1, latency 0) to 48 MHz: one flash wait
/// state first, read back until it holds, then HSIDIV /1. SYSCLK, HCLK and
/// PCLK are then 48 MHz; I2C1 is clocked from PCLK (RCC_CCIPR reset value).
pub fn init() void {
    FLASH.ACR.raw = (FLASH.ACR.raw & ~acr_latency) | one_wait_state;
    while (FLASH.ACR.raw & acr_latency != one_wait_state) {}
    RCC.CR.raw = RCC.CR.raw & ~cr_hsidiv;
}

/// SysTick priority, system-handler priority register 3 bits 31:24. The
/// SysTick and I2C1 interrupts share one priority, so neither preempts the
/// other (main.zig relies on it).
pub const priority: u8 = 0x80;

/// The 8 kHz tick: SysTick from the processor clock, interrupt on.
pub fn startTick() void {
    const shpr3 = &scb.SHPR[2]; // word access only on the Cortex-M0+
    shpr3.* = (shpr3.* & 0x00FF_FFFF) | (@as(u32, priority) << 24);
    systick.LOAD.raw = tick_counts - 1;
    systick.VAL.raw = 0;
    systick.CTRL.raw = 0b111; // ENABLE, TICKINT, CLKSOURCE = processor clock
}

/// Busy-waits `cycles` processor cycles (below one tick), measured on the
/// running SysTick counter, so flash wait states do not change it. For the
/// matrix's settle time inside the tick interrupt; calls nothing.
pub fn waitCycles(cycles: u32) void {
    const begin = systick.VAL.raw;
    while (true) {
        const now = systick.VAL.raw;
        // The counter runs down from tick_counts - 1 and wraps.
        const elapsed = if (now <= begin) begin - now else begin + tick_counts - now;
        if (elapsed >= cycles) return;
    }
}
