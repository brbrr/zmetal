//! periph_check: a self-checking image for the HAL's peripherals: UART TX
//! and inversion, I2C speed and gaps, PWM, ADC, GPIO initial level, the
//! cycle-counter `delay_us`, the watchdog, RTC backup registers and reset
//! cause. Each check writes its verdict into `report`.
//!
//! Reading the result: the user LED is solid when no check failed, and
//! blinks at 2 Hz when at least one did. For the detail read `report` with
//! a debugger (`Check`: `.pass`, `.fail`, `.not_run`; the `u32`/`u16`
//! fields are the measurements behind the verdicts, 0 when not measured).
//! A `.fail` anywhere makes the LED blink. `.not_run` is no failure: the I2C
//! checks stay `.not_run` on a bare Seed.
//!
//! Wiring (bare Seed): jumper D13 to D14 (Seed pins 14 and 15), the USART1
//! TX and RX lines, and D23 to D24 (Seed pins 30 and 31), a GPIO output
//! into an ADC1 input. D16 (the PWM output) stays unconnected.
//!
//! The I2C checks need pull-ups and a slave on I2C1 (D11 SCL, D12 SDA): run
//! them with the Seed on the v1 board, MCP23017 at 0x21. On a bare Seed the
//! first probe times out and they stay `.not_run`.
//!
//! The watchdog check lets the watchdog reset the board once: a passing run
//! boots twice, runs the other checks on both boots, and shows the LED a
//! few seconds after the first boot (2 s of feeding the watchdog, about
//! 0.25 s to its reset, then the other checks once more). It keeps its
//! phase in RTC backup register 0 across that reset.
//!
//! Run the bare-Seed check from a cold power-up with the debug probe
//! unplugged, and read the LED: an attached debugger enables the trace
//! block (DEMCR.TRCENA) and can hide a cycle-counter problem in `delay_us`.
//! Read `report` afterwards with the probe, if need be.
//!
//! Build: `zig build periph_check -Doptimize=safe`.
const std = @import("std");
const microzig = @import("microzig");
const zmetal = @import("zmetal");
const hal = zmetal.hal;

comptime {
    _ = microzig.export_startup();
}
pub const panic = microzig.panic;
pub const std_options = microzig.std_options(.{});

// SysTick, fault and USART1 handlers come from hal.default_interrupts.
pub const microzig_options: microzig.Options = .{};

pub const Check = enum(u8) { not_run, pass, fail };

/// The verdicts and measurements, in declaration order (an `extern struct`:
/// offsets stay put). First the `Check`s of the UART and I2C checks and the
/// watchdog, one byte each; the cause of this boot's reset (one byte); the
/// `u32` measurements (microseconds unless noted; 0 when not measured) and
/// this boot's raw reset flags (RCC_RSR); then `backup_holds` and the later
/// `Check`s; last the two `u16` ADC readings. A new `u32` goes after the
/// last `u32`, a new `Check` after the last `Check`, a new `u16` at the end.
pub const Report = extern struct {
    uart_loopback: Check = .not_run,
    uart_idle_low: Check = .not_run,
    i2c_speed: Check = .not_run,
    i2c_after_recovery: Check = .not_run,
    i2c_gap: Check = .not_run,
    i2c_bus_free: Check = .not_run,
    watchdog: Check = .not_run,
    reset_cause: hal.reset.Cause = .unknown,
    i2c_fast_us: u32 = 0,
    i2c_slow_us: u32 = 0,
    i2c_gap_us: u32 = 0,
    i2c_bus_free_us: u32 = 0,
    reset_flags: u32 = 0,
    /// The PWM frequency measured, in Hz.
    pwm_hz: u32 = 0,
    /// The share of samples high at duty 16384, in permille.
    pwm_duty_permille: u32 = 0,
    /// The time `clock.delay_us(1000)` took, see `checkDelay`.
    delay_us_measured: u32 = 0,
    backup_holds: Check = .not_run,
    /// D16 as a 100 kHz PWM output, see `checkPwm`.
    pwm: Check = .not_run,
    /// D24 read through the jumper from D23, high then low, see `checkAdc`.
    adc: Check = .not_run,
    /// D23's initial level, see `checkAdc`.
    gpio_initial: Check = .not_run,
    /// `clock.delay_us` timed on SysTick, see `checkDelay`.
    delay: Check = .not_run,
    /// The two ADC readings (raw counts, 16 bit; 0 when not read): D24 with
    /// D23 high, then with D23 low.
    adc_high_raw: u16 = 0,
    adc_low_raw: u16 = 0,
};

pub var report: Report = .{}; // read it with a debugger

// Exported, so the optimizer keeps `report` whole, under its own name
// (unexported, it was split into one global per field and partly removed).
comptime {
    @export(&report, .{ .name = "report" });
}

var seed: zmetal.Seed = .{};

pub fn main() !void {
    // Before anything else: this boot's reset flags and cause, then the
    // flags cleared, so the next boot sees only its own. For information:
    // the watchdog check's verdict does not depend on them.
    report.reset_flags = hal.reset.rawFlags();
    report.reset_cause = hal.reset.cause();
    hal.reset.clearFlags();

    try seed.init(.{ .sdram = false, .qspi = false });

    checkDelay(); // first: it needs no wiring
    checkUart();
    checkI2c();
    checkPwm();
    checkAdc();
    checkWatchdog(); // last: on its first run it resets the board

    // A failed watchdog check can leave the watchdog running, and nothing
    // stops it: the blink loop keeps it fed, so a late watchdog reset
    // cannot wipe the failure shown. On the solid path it never runs (the
    // check started it only on a boot that ends in a reset or `.fail`).
    if (anyFail()) {
        while (true) {
            seed.toggleLed();
            delayFeeding(250); // 2 Hz: on 250 ms, off 250 ms
        }
    }
    seed.setLed(true);
    while (true) microzig.cpu.wfi();
}

fn verdict(ok: bool) Check {
    return if (ok) .pass else .fail;
}

fn anyFail() bool {
    inline for (@typeInfo(Report).@"struct".field_names) |name| {
        // Nested, so the comparison is not analysed for the u32 fields.
        if (@FieldType(Report, name) == Check) {
            if (@field(report, name) == .fail) return true;
        }
    }
    return false;
}

/// `delay`: `clock.delay_us` timed with `hal.time.nowUs`, which counts
/// SysTick, not the cycle counter `delay_us` waits on. Passes when both
/// hold:
/// - `delay_us(1000)` takes 1000 to 1100 us (`delay_us_measured`);
/// - twenty `delay_us(10)` in a row, timed as one, take 200 to 300 us.
/// Too short means `delay_us` returned before its time; too long, that it
/// waits far beyond it (the cycle counter not running, say). It cannot see
/// a wrong `SystemCoreClock`: SysTick's reload is computed from the same
/// value, so a wrong clock scales `nowUs` and `delay_us` alike and the
/// check still passes. Needs no wiring.
fn checkDelay() void {
    const one_ms = timedDelays(1, 1000);
    report.delay_us_measured = @intCast(@min(one_ms, std.math.maxInt(u32)));
    const twenty = timedDelays(20, 10);
    report.delay = verdict(one_ms >= 1000 and one_ms <= 1100 and
        twenty >= 200 and twenty <= 300);
}

/// The time `count` calls of `clock.delay_us(us)` in a row take, in
/// microseconds, on `hal.time.nowUs`. Out of line, so the two measurements
/// share one copy of `nowUs` and the calls are not unrolled.
noinline fn timedDelays(count: u32, us: u32) u64 {
    const start = hal.time.nowUs();
    for (0..count) |_| hal.clock.delay_us(us);
    return hal.time.nowUs() - start;
}

const Uart = hal.usart.UartStream(.USART1);

/// The count a failed `write` or `read` stands for. UartStream's `write` and
/// `read` never fail (their error sets come from the generic stream
/// contract); should one, this count matches no expected value, so the
/// check fails.
const stream_error: usize = std.math.maxInt(usize);

/// A MIDI note-on: status 0x90, key 0x3C, velocity 0x40.
const note_on = [_]u8{ 0x90, 0x3C, 0x40 };

/// Byte i is i & 0x7F, so no byte is 0x90, `note_on`'s status byte. Queued
/// into the empty transmit ring (256 bytes, 255 usable) it leaves 2 bytes
/// free, one fewer than `note_on` needs.
const block: [253]u8 = blk: {
    var b: [253]u8 = undefined;
    for (&b, 0..) |*x, i| x.* = @intCast(i & 0x7F);
    break :blk b;
};
var block_back: [block.len]u8 = undefined;

/// USART1 on D13 (TX) / D14 (RX), AF7, at the MIDI rate with both lines
/// inverted.
///
/// `uart_idle_low`: 2 ms after init D13 reads low, the inverted idle level.
/// With the jumper fitted D14's pull-down also holds the line low, so this
/// catches a TX that drives high (inversion missing); a floating TX is
/// caught by the loopback.
///
/// `uart_loopback`, all of:
/// - `note_on` is queued whole and comes back over the jumper within 10 ms;
/// - with interrupts off, so the transmit interrupt cannot drain the ring,
///   `block` is queued whole and then `note_on` is refused (0 queued). Both
///   results come from the ring's state at run time;
/// - with interrupts on again exactly `block` comes back within 200 ms
///   (253 bytes take about 81 ms), and nothing in the next 5 ms: a refused
///   `note_on` left no fragment in the ring;
/// - the receiver counts no overrun, line error or dropped byte.
/// Without the jumper the RX pin's pull-down holds the inverted line idle,
/// nothing arrives, and `uart_loopback` fails by timeout.
fn checkUart() void {
    const uart = Uart.init(.{
        .baud_rate = 31250,
        .tx = .{ .pin = zmetal.pins.D13, .af = .af7 },
        .rx = .{ .pin = zmetal.pins.D14, .af = .af7 },
        .invert_tx = true,
        .invert_rx = true,
    });

    zmetal.time.delayMs(2);
    report.uart_idle_low = verdict(!hal.Gpio.handle(zmetal.pins.D13).read());

    var note_back: [note_on.len]u8 = undefined;
    const note_queued = uart.write(&note_on) catch stream_error;
    const echoed = note_queued == note_on.len and
        readFor(uart, &note_back, 10_000) == note_on.len and
        std.mem.eql(u8, &note_back, &note_on);

    microzig.interrupt.disable_interrupts();
    const block_queued = uart.write(&block) catch stream_error;
    const late_queued = uart.write(&note_on) catch stream_error;
    microzig.interrupt.enable_interrupts();
    const block_echoed = block_queued == block.len and late_queued == 0 and
        readFor(uart, &block_back, 200_000) == block.len and
        std.mem.eql(u8, &block_back, &block);
    var extra: [1]u8 = undefined;
    const nothing_after = readFor(uart, &extra, 5_000) == 0;

    const s = Uart.rxStats();
    const clean = s.overruns == 0 and s.line_errors == 0 and s.dropped == 0;

    report.uart_loopback = verdict(echoed and block_echoed and nothing_after and clean);
}

/// Read into `buf` until it is full or `timeout_us` has passed. Returns the
/// bytes read, or `stream_error`.
fn readFor(uart: Uart, buf: []u8, timeout_us: u64) usize {
    var n: usize = 0;
    const start = zmetal.time.nowUs();
    while (n < buf.len and zmetal.time.nowUs() - start < timeout_us) {
        n += uart.read(buf[n..]) catch return stream_error;
    }
    return n;
}

const I2cDevice = microzig.drivers.base.I2C_Device;

/// The MCP23017 on the v1 board.
const expander: hal.i2c.Address = @enumFromInt(0x21);

/// I2C1 at 400 kHz with the BQ25628's gaps: 90 us START to START, 68 us
/// STOP to START. At file scope, as the target keeps a pointer to it.
var bus: hal.i2c.I2C_Device = undefined;
/// The same bus at 100 kHz.
var slow: hal.i2c.Target = undefined;

/// `i2c_fast_us`, `i2c_slow_us`: one 16-byte read from the expander through
/// `bus.i2c_device()` (400 kHz, about 400 us) and through the 100 kHz target
/// (about 1500 us). `i2c_speed` passes when both reads work and the slow
/// one takes more than 2.5 times as long: the clocks differ by 4, and the
/// fixed overhead of a transfer lowers the measured ratio.
///
/// `i2c_after_recovery`: after `bus.recoverBus()`, which puts the bus's own
/// TIMINGR back, a read through the slow target passes the same comparison
/// (the target switches the speed again).
///
/// `i2c_gap`: the START gap alone, over a repeated START. `i2c_gap_us` is
/// the time of one `write_then_read` through the bus: register 0x00
/// written, then 1 byte read after a repeated START. The bus-free time does
/// not apply before a repeated START, so only the START gap can lengthen
/// it. At 400 kHz the START, address and register bytes take about 45 us;
/// the bus is then held (SCL low) until 90 us after the START; the repeated
/// START, address, data byte and STOP take about 45 us more. That is about
/// 135-140 us with the gap and about 95 us without; it passes at 120 us or
/// more.
///
/// `i2c_bus_free`: the bus-free time alone. One 16-byte read through the
/// bus and, right after it, one zero-length probe are timed together;
/// `i2c_bus_free_us` is that time less `i2c_fast_us` (the same read alone).
/// The read takes about 400 us, so the START gap has run out when the
/// probe starts, and only the bus-free time can hold the probe's START
/// back: about 68 + 25 = 93 us with it and about 30 us without; it passes
/// at 80 us or more.
///
/// Each timed part starts 1 ms after the transfer before it, so a gap left
/// over from that transfer is not in its time.
fn checkI2c() void {
    bus = hal.i2c.I2C_Device.init(.I2C1, .{
        .speed = .I2C_400KHZ,
        .min_start_gap_us = 90,
        .min_bus_free_us = 68,
    }) catch {
        report.i2c_speed = .fail;
        return;
    };
    slow = bus.target(.I2C_100KHZ);
    const fast_dev = bus.i2c_device();
    const slow_dev = slow.i2c_device();

    // No pull-ups and no slave (a bare Seed): the probe times out.
    fast_dev.write(expander, &.{}) catch |err| if (err == error.Timeout) return;

    const fast_us = timedRead(fast_dev);
    const slow_us = timedRead(slow_dev);
    report.i2c_fast_us = fast_us orelse 0;
    report.i2c_slow_us = slow_us orelse 0;
    report.i2c_speed = verdict(slower(slow_us, fast_us));

    _ = bus.recoverBus();
    report.i2c_after_recovery = verdict(slower(timedRead(slow_dev), fast_us));

    const gap_us = timedRestart(fast_dev);
    report.i2c_gap_us = gap_us orelse 0;
    report.i2c_gap = verdict(atLeast(gap_us, 120));

    const bus_free_us = minus(timedReadThenProbe(fast_dev), fast_us);
    report.i2c_bus_free_us = bus_free_us orelse 0;
    report.i2c_bus_free = verdict(atLeast(bus_free_us, 80));
}

/// The time of one `write_then_read` through `dev`: register 0x00 of the
/// expander written, then 1 byte read after a repeated START; 1 ms after
/// the transfer before it. Null when it fails.
fn timedRestart(dev: I2cDevice) ?u32 {
    zmetal.time.delayMs(1);
    var value: [1]u8 = undefined;
    const start = zmetal.time.nowUs();
    dev.write_then_read(expander, &[_]u8{0x00}, &value) catch return null;
    return @intCast(zmetal.time.nowUs() - start);
}

/// The time of one 16-byte read from the expander through `dev` and a
/// zero-length probe right after it, 1 ms after the transfer before them.
/// Null when either fails.
fn timedReadThenProbe(dev: I2cDevice) ?u32 {
    zmetal.time.delayMs(1);
    var buf: [16]u8 = undefined;
    const start = zmetal.time.nowUs();
    const n = dev.read(expander, &buf) catch return null;
    if (!probe(dev)) return null;
    const took = zmetal.time.nowUs() - start;
    if (n != buf.len) return null;
    return @intCast(took);
}

/// `total_us` less `part_us`, saturating at 0; null when either is null.
fn minus(total_us: ?u32, part_us: ?u32) ?u32 {
    return (total_us orelse return null) -| (part_us orelse return null);
}

/// `us` was measured and is at least `min_us`.
fn atLeast(us: ?u32, min_us: u32) bool {
    const t = us orelse return false;
    return t >= min_us;
}

/// The time of one 16-byte read from the expander through `dev`, in
/// microseconds, 1 ms after the transfer before it; null when it fails.
fn timedRead(dev: I2cDevice) ?u32 {
    zmetal.time.delayMs(1);
    var buf: [16]u8 = undefined;
    const start = zmetal.time.nowUs();
    const n = dev.read(expander, &buf) catch return null;
    const took = zmetal.time.nowUs() - start;
    if (n != buf.len) return null;
    return @intCast(took);
}

/// Both reads worked, and `slow_us` is more than 2.5 times `fast_us`.
fn slower(slow_us: ?u32, fast_us: ?u32) bool {
    const s = slow_us orelse return false;
    const f = fast_us orelse return false;
    return 2 * @as(u64, s) > 5 * @as(u64, f);
}

/// A zero-length write to the expander; true when it is acknowledged.
fn probe(dev: I2cDevice) bool {
    dev.write(expander, &.{}) catch return false;
    return true;
}

const PwmOut = hal.pwm.Pwm(.TIM2, .ch4);

/// `pwm`: D16 (PA3, TIM2 channel 4 on AF1) as a 100 kHz PWM output, read
/// back through D16's own input register, which follows the pin in
/// alternate-function mode too: no jumper, leave D16 unconnected. Passes
/// when all of these hold:
/// - duty 0 (where `init` leaves it): 100 000 samples, all low;
/// - duty 65535: 100 000 samples, all high;
/// - duty 16384: of 200 000 samples, `pwm_duty_permille` = highs * 1000 /
///   samples is 250 +- 30;
/// - the same duty: `pwm_hz` = rising edges in 10 ms * 100 is
///   100 000 +- 2 %.
/// A duty takes effect at the next period boundary, so each is given
/// 100 us (10 periods) before sampling. The pin is left at duty 0.
fn checkPwm() void {
    const out = PwmOut.init(.{
        .pin = .{ .pin = zmetal.pins.D16, .af = .af1 },
        .frequency_hz = 100_000,
    });
    const in = hal.Gpio.handle(zmetal.pins.D16);

    zmetal.time.delayUs(100);
    const off = highs(in, 100_000) == 0;
    setDutyAndWait(out, 65535);
    const on = highs(in, 100_000) == 100_000;
    setDutyAndWait(out, 16384);
    const permille = highs(in, 200_000) * 1000 / 200_000;
    const hz = risingEdges(in, 10_000) * 100;
    out.setDuty(0);

    report.pwm_duty_permille = permille;
    report.pwm_hz = hz;
    report.pwm = verdict(off and on and
        permille >= 220 and permille <= 280 and
        hz >= 98_000 and hz <= 102_000);
}

fn setDutyAndWait(out: PwmOut, duty: u16) void {
    out.setDuty(duty);
    zmetal.time.delayUs(100);
}

/// How many of `samples` reads of `pin` are high. Each read is a volatile
/// load of the input register, so none is optimised away.
fn highs(pin: hal.Gpio, samples: u32) u32 {
    var n: u32 = 0;
    for (0..samples) |_| n += @intFromBool(pin.read());
    return n;
}

/// Rising edges on `pin` in `window_us`, timed with `nowUs`. One pass (a
/// read and a `nowUs`) takes well under the 2.5 us high time at duty
/// 16384, so no edge is missed, and the window ends at most one pass late.
fn risingEdges(pin: hal.Gpio, window_us: u64) u32 {
    var edges: u32 = 0;
    var last = pin.read();
    const start = zmetal.time.nowUs();
    while (zmetal.time.nowUs() - start < window_us) {
        const level = pin.read();
        edges += @intFromBool(level and !last);
        last = level;
    }
    return edges;
}

/// D24 (ADC1 input 17) read through the jumper from D23, a GPIO output;
/// each reading the mean of 8 conversions at the longest sample time.
///
/// `gpio_initial`: D23 is set up as an output with `.initial = .high` and
/// read before any `write` call; it passes above 60000, the pin having come
/// up high by `initial` alone.
///
/// `adc`: that reading above 60000, and below 2000 once D23 is driven low.
/// A `Timeout` fails it. Without the jumper D24 floats, and the two
/// readings do not both pass.
fn checkAdc() void {
    report.adc = verdict(adcHighThenLow() catch false);
}

/// The two readings of `checkAdc` into `report`; true when both are right.
fn adcHighThenLow() hal.adc.Error!bool {
    try hal.adc.init();
    const in = hal.adc.Input.init(zmetal.pins.D24, .cycles_810_5);
    const drive = hal.Gpio.init(zmetal.pins.D23, .{ .mode = .output, .initial = .high });
    report.adc_high_raw = try in.readAveraged(8);
    report.gpio_initial = verdict(report.adc_high_raw > 60000);
    drive.write(false);
    report.adc_low_raw = try in.readAveraged(8);
    return report.adc_high_raw > 60000 and report.adc_low_raw < 2000;
}

/// Set once `checkWatchdog` has started the watchdog. Nothing stops it
/// again, so from then on `delayFeeding` keeps it fed.
var watchdog_started = false;

/// How often a started watchdog is fed: a fifth of its 250 ms timeout,
/// well under the half `hal.iwdg` asks for.
const feed_period_ms = 50;

/// Where the watchdog check is, kept in RTC backup register
/// `phase_register`, which outlives a system reset (`hal.backup`), so the
/// boot after a reset knows in which phase the reset came. `idle` is 0,
/// which is also what a backup domain that lost power holds; `feeding` and
/// `unfed` are arbitrary values nothing else is likely to leave there.
const Phase = enum(u32) {
    idle = 0,
    feeding = 0x5744_4644, // "WDFD"
    unfed = 0x5744_5546, // "WDUF"
    _,
};
const phase_register = 0;

fn phase() Phase {
    return @enumFromInt(hal.backup.read(phase_register));
}

fn setPhase(p: Phase) void {
    hal.backup.write(phase_register, @intFromEnum(p));
}

/// `watchdog`: the watchdog does not reset the board while it is fed, and
/// does once it is not. The verdict comes from the phase the previous boot
/// left in the backup register, not from the reset flags (they cannot tell
/// where in the check a reset came, and something else may clear them):
///
/// - `unfed`: the previous boot was reset after it had stopped feeding the
///   watchdog and before its 1 s wait ran out (at its end the phase goes
///   back to `idle`). With `feeding` never seen, the board also survived
///   the 2 s of feeding. So the watchdog held off while fed and fired once
///   not fed: `.pass`. The phase goes back to `idle`; the watchdog is not
///   started.
/// - `feeding`: the previous boot was reset while it fed the watchdog every
///   50 ms: a reset `feed` should have prevented (a broken feed, a timeout
///   far shorter than asked, a fault handler's endless loop), or one by the
///   button or the debugger during those 2 s (`report.reset_cause` tells
///   which). `.fail`. The phase goes back to `idle`; the watchdog is not
///   started.
/// - anything else (`idle`: a power-on, or a finished check before this
///   reset): the phase set to `feeding` and read back. Only when it reads
///   back `feeding` (`backup_holds = .pass`) is the watchdog started with a
///   250 ms timeout and fed every 50 ms for 2 s, then the phase set to
///   `unfed` and the watchdog no longer fed. It should reset the board
///   about 250 ms later, and the next boot decides. Still running 1 s
///   later, the watchdog never fired: `.fail`, the phase back to `idle`
///   (and the watchdog stays fed, see `main`).
///
/// The read-back is there because the verdict rests on the backup
/// register: were the watchdog started while the register does not hold
/// the phase, every boot would read `idle`, start the watchdog again and be
/// reset by it, endlessly. So a phase that does not read back is
/// `backup_holds = .fail` and `watchdog = .fail`, with the watchdog never
/// started. The read-back proves only that the write took effect in this
/// boot, not that it survives the reset; the `unfed` branch on the next
/// boot shows that. (`backup_holds` stays `.not_run` on the boots that take
/// the `unfed` or `feeding` branch.)
///
/// So a run resets the board once and leaves the phase `idle`; any later
/// reset runs the check again, whatever the reset flags say.
fn checkWatchdog() void {
    hal.backup.enable();
    switch (phase()) {
        .unfed => {
            report.watchdog = .pass;
            setPhase(.idle);
            return;
        },
        .feeding => {
            report.watchdog = .fail;
            setPhase(.idle);
            return;
        },
        else => {},
    }

    setPhase(.feeding);
    if (phase() != .feeding) {
        report.backup_holds = .fail;
        report.watchdog = .fail;
        return;
    }
    report.backup_holds = .pass;
    hal.iwdg.start(.{ .timeout_ms = 250 });
    watchdog_started = true;
    delayFeeding(2000);

    setPhase(.unfed);
    zmetal.time.delayMs(1000); // not fed: the watchdog resets the board here
    report.watchdog = .fail;
    setPhase(.idle);
}

/// Wait at least `ms` milliseconds, feeding a started watchdog every
/// `feed_period_ms`.
fn delayFeeding(ms: u32) void {
    const start = zmetal.time.nowMs();
    while (zmetal.time.nowMs() -% start < ms) {
        feedIfStarted();
        zmetal.time.delayMs(feed_period_ms);
    }
}

/// Feed the watchdog if `checkWatchdog` has started it.
fn feedIfStarted() void {
    if (watchdog_started) hal.iwdg.feed();
}
