//! The cause of the last reset (pure, host-tested): decoded from the RCC
//! reset status register (RCC_RSR, RM0433). Used by reset.zig.
const std = @import("std");

/// What reset the chip last. `u8`-tagged, so it can sit in an extern struct.
pub const Cause = enum(u8) { power_on, brown_out, pin, software, watchdog, window_watchdog, low_power, unknown };

// RCC_RSR flag bits (RM0433). RMVF (bit 16) and the CPU, D1 and D2 flags
// (17, 19, 20) name no cause of their own.
const borrstf = 1 << 21;
const pinrstf = 1 << 22;
const porrstf = 1 << 23;
const sftrstf = 1 << 24;
const iwdg1rstf = 1 << 26;
const wwdg1rstf = 1 << 28;
const lpwrrstf = 1 << 30;

/// The cause behind the flags in `rsr`, a raw RCC_RSR value.
///
/// One reset sets several flags: a power-on sets POR, BOR and PIN; a
/// watchdog, window watchdog, software or low-power reset also drives NRST
/// and so sets PIN; a brown-out sets BOR and PIN. The flags also add up over
/// resets until they are cleared. So the first set flag in this order
/// names the cause: low power, window watchdog, watchdog, software,
/// power-on, brown-out, pin. No flag at all is `unknown`.
pub fn decode(rsr: u32) Cause {
    if (rsr & lpwrrstf != 0) return .low_power;
    if (rsr & wwdg1rstf != 0) return .window_watchdog;
    if (rsr & iwdg1rstf != 0) return .watchdog;
    if (rsr & sftrstf != 0) return .software;
    if (rsr & porrstf != 0) return .power_on;
    if (rsr & borrstf != 0) return .brown_out;
    if (rsr & pinrstf != 0) return .pin;
    return .unknown;
}

const cpu_d1_d2 = (1 << 17) | (1 << 19) | (1 << 20);
test "power-on sets POR, BOR and PIN together" {
    try std.testing.expectEqual(Cause.power_on, decode((1 << 23) | (1 << 21) | (1 << 22) | cpu_d1_d2));
}
test "a watchdog reset also sets PIN and is still a watchdog reset" {
    try std.testing.expectEqual(Cause.watchdog, decode((1 << 26) | (1 << 22) | cpu_d1_d2));
}
test "software, brown-out, pin, window watchdog, low power" {
    try std.testing.expectEqual(Cause.software, decode((1 << 24) | (1 << 22) | cpu_d1_d2));
    try std.testing.expectEqual(Cause.brown_out, decode((1 << 21) | (1 << 22) | cpu_d1_d2));
    try std.testing.expectEqual(Cause.pin, decode((1 << 22) | cpu_d1_d2));
    try std.testing.expectEqual(Cause.window_watchdog, decode((1 << 28) | (1 << 22)));
    try std.testing.expectEqual(Cause.low_power, decode((1 << 30) | (1 << 22)));
}
test "no flag" {
    try std.testing.expectEqual(Cause.unknown, decode(0));
    try std.testing.expectEqual(Cause.unknown, decode(1 << 16)); // RMVF alone
}
