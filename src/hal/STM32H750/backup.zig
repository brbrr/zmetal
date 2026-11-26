//! The RTC backup registers (RTC_BKP0R..RTC_BKP31R): 32 words in the backup
//! domain, for a few values that must outlive a reset.
//!
//! They keep their value across a system reset: the reset pin, a software
//! reset, a watchdog reset. They are cleared when the
//! backup domain loses power (VDD and VBAT both gone; with VBAT held up they
//! outlive a power cycle as well), by a backup-domain reset
//! (RCC_BDCR.BDRST), and by a tamper detection when one is enabled.
//!
//! The Daisy bootloader keeps its own data (its boot info) in the backup
//! SRAM at 0x38800000, not in these registers; this module does not touch
//! the backup SRAM.
const std = @import("std");
const microzig = @import("microzig");
const chip = microzig.chip;
const RTC = chip.peripherals.RTC;
const RCC = chip.peripherals.RCC;
const PWR = chip.peripherals.PWR;
const clock = @import("clock.zig");

/// How many backup registers the chip has (32 on the H750).
const count =@typeInfo(@FieldType(chip.types.peripherals.rtc_v2h7.RTC, "BKPR")).array.len;

/// The most time `enable` waits for the write protection to lift
/// (ST's RCC_DBP_TIMEOUT_VALUE).
const dbp_timeout_ms = 100;

/// Makes the backup registers readable and writable. Call once before
/// `read`/`write`.
///
/// Sets PWR_CR1.DBP (lifts the backup domain's write protection; reset by
/// every system reset) and waits until it reads back set, as ST's HAL does,
/// bounded by `dbp_timeout_ms` on the millisecond tick (so call it once the
/// tick runs: after `Seed.init`, with interrupts on). Then turns on the
/// RTC's APB clock (RCC_APB4ENR.RTCAPBEN), through which the registers are
/// reached. The RTC itself is not started.
pub fn enable() void {
    PWR.CR1.modify_one("DBP", 1);
    const t0 = clock.get_tick();
    while (PWR.CR1.read().DBP == 0 and clock.elapsed_ms(t0) < dbp_timeout_ms) {}

    RCC.APB4ENR.modify_one("RTCAPBEN", 1);
    _ = RCC.APB4ENR.read(); // ST: read back after a peripheral clock enable
}

/// The value in backup register `index`.
pub fn read(comptime index: u5) u32 {
    return register(index).raw;
}

/// Store `value` in backup register `index`.
pub fn write(comptime index: u5, value: u32) void {
    register(index).raw = value;
}

fn register(comptime index: u5) @TypeOf(&RTC.BKPR[0]) {
    if (index >= count) @compileError(std.fmt.comptimePrint("backup register {d} does not exist: the chip has {d}", .{ index, count }));
    return &RTC.BKPR[index];
}
