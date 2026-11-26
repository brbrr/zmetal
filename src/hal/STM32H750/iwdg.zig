//! IWDG1, the independent watchdog: it resets the chip unless `feed` is
//! called before its timeout runs out. It counts on the LSI, so it keeps
//! running when the core clocks stop or fail.
//!
//! The LSI is not trimmed, so its rate is only roughly 32 kHz and the real
//! timeout may be shorter than the one asked for: feed at no more than half
//! the timeout.
//!
//! Once started, only a reset stops the watchdog. Every wait that is not
//! fed ends in a watchdog reset, the fault handlers' (fault.zig) and the
//! panic handler's endless loops included; a fault's `last_fault` snapshot
//! is then lost with the reset, unless a debugger halts the core first (with
//! `freeze_on_debug` the watchdog stops counting while the core is halted).
const microzig = @import("microzig");
const chip = microzig.chip;
const IWDG1 = chip.peripherals.IWDG1;
const DBGMCU = chip.peripherals.DBGMCU;
const clock = @import("clock.zig");
const iwdg_math = @import("iwdg_math.zig");

pub const Config = struct {
    /// The least time, in milliseconds, from one `feed` to the reset:
    /// 1 to 32768 (at the nominal LSI rate; see the file comment).
    timeout_ms: u32,
    /// Stop the watchdog's counter while a debugger halts the core
    /// (DBGMCU_APB4FZR1.DBG_IWDG1), so a breakpoint does not reset the chip.
    freeze_on_debug: bool = true,
};

/// The most time `start` waits for the new prescaler and reload to reach
/// the counter (RM0433: a few LSI cycles). Shorter than the about 512 ms
/// the watchdog runs with meanwhile (its reset values: divide by 4, reload
/// 4095), so the wait cannot let it fire.
const update_timeout_ms = 100;

/// Start the watchdog with `config.timeout_ms` (a timeout it cannot meet is
/// a compile error). Once started only a reset stops it; calling `start`
/// again sets the new timeout.
///
/// The order follows RM0433 and ST's HAL: start (which turns the LSI on),
/// unlock PR and RLR, write them, wait until the counter has taken them,
/// then reload. Until that reload the counter runs with the timeout it had,
/// so the first reload already uses the new one. The wait is bounded by
/// `update_timeout_ms` on the millisecond tick, so call `start` once the
/// tick runs (after `Seed.init`, with interrupts on); should the wait time
/// out, it carries on (the watchdog is already running) and reloads anyway.
pub fn start(comptime config: Config) void {
    const setting = comptime iwdg_math.settingFor(config.timeout_ms) catch |e| @compileError(@errorName(e));

    if (config.freeze_on_debug) DBGMCU.APB4FZR1.modify_one("IWDG1", 1);

    IWDG1.KR.write(.{ .KEY = .Start });
    IWDG1.KR.write(.{ .KEY = .Enable });
    IWDG1.PR.write(.{ .PR = @enumFromInt(setting.prescaler) });
    IWDG1.RLR.write(.{ .RL = setting.reload });

    const t0 = clock.get_tick();
    while (updatePending() and clock.elapsed_ms(t0) < update_timeout_ms) {}

    IWDG1.KR.write(.{ .KEY = .Reset });
}

/// Reload the counter: the next reset is a full timeout away.
pub fn feed() void {
    IWDG1.KR.write(.{ .KEY = .Reset });
}

/// The prescaler, reload or window value written last has not reached the
/// counter yet.
fn updatePending() bool {
    const sr = IWDG1.SR.read();
    return sr.PVU != 0 or sr.RVU != 0 or sr.WVU != 0;
}
