//! power_check: a self-checking image for the v3 board's power chips, the
//! BQ25628 charger and the MAX17048 fuel gauge, both on I2C1 (D11 SCL, D12
//! SDA, 100 kHz, 90 us between STARTs for the charger). It finds the charger
//! (at 0x6A, then at 0x6B), applies the board's boot configuration, reads
//! status and one ADC conversion, then configures and reads the gauge, and
//! compares the charger's VBAT with the gauge's cell voltage.
//!
//! It needs the v3 board with a cell connected; USB is optional (without it
//! `vbus_present` is false and `vbus_mv` is near 0).
//!
//! Run it only with a cell rated for what it leaves in the charger, the
//! board's boot configuration (`board_config`): a charge current (ICHG) of
//! 1480 mA up to a charge voltage (VREG) of 4200 mV; the input limited to
//! 900 mA (IINDPM) and by the ILIM pin, which stays in force (about 0.93 A
//! on the v3 board, [POWER] §3 row 15); and, as at the chip's power-on,
//! termination at 20 mA, pre-charge at 30 mA, the 14.5 h fast-charge
//! timer, the 120 °C thermal limit and the temperature sensor on. The I2C
//! watchdog is off, so all of it stays after the image stops and across a
//! power-off of the board, for as long as the cell stays connected: only
//! a power-on reset of the charger, a ship-mode or shutdown exit or a
//! register reset brings its power-on values back ([POWER] §1.6; whether
//! plugging USB in with the cell connected is such a reset is not known,
//! §1.12 item 8). IINDPM alone goes back to 3.2 A each time USB is
//! unplugged; the ILIM pin still limits the input then.
//!
//! Reading the result: the user LED is solid when no check failed and blinks
//! at 2 Hz when at least one did. For the detail read `report` with a
//! debugger (`Check`: `.pass`, `.fail`, `.not_run`; the measurements are 0
//! when not read). A check that could not run because an earlier one failed
//! stays `.not_run`.
//!
//! Build: `zig build power_check -Doptimize=safe`.
const std = @import("std");
const microzig = @import("microzig");
const zmetal = @import("zmetal");
const hal = zmetal.hal;
const bq25628 = zmetal.drivers.bq25628;
const max17048 = zmetal.drivers.max17048;
const I2cBus = zmetal.drivers.i2c_bus.I2cBus;

comptime {
    _ = microzig.export_startup();
}
pub const panic = microzig.panic;
pub const std_options = microzig.std_options(.{});

// SysTick, fault and USART1 handlers come from hal.default_interrupts.
pub const microzig_options: microzig.Options = .{};

pub const Check = enum(u8) { not_run, pass, fail };

/// The verdicts and measurements (an `extern struct`: offsets stay put, 22
/// bytes, 2-byte aligned, no padding). Offsets: `vbat_mv` 0, `vbus_mv` 2,
/// `gauge_mv` 4, `ibus_ma` 6 (the 2-byte fields); then one byte each:
/// `charger_address` 8 (0 = no answer), `charger_status_raw` 9..11 (REG0x1D,
/// 0x1E, 0x1F), `charger_part` 12, `charger_config` 13,
/// `charger_measurement` 14, `gauge_part` 15, `gauge` 16, `agree` 17,
/// `vbus_present` 18, `gauge_was_reset` 19, `gauge_soc` 20 (percent) and
/// `reserved` 21, always 0 (keeps the size even). A new byte field takes
/// the place of `reserved`; a new 2-byte field goes before `charger_address`
/// and shifts the offsets above, which this comment then needs updating for.
pub const Report = extern struct {
    /// The charger's VBAT, VBUS (mV) and IBUS (mA) from one conversion.
    vbat_mv: u16 = 0,
    vbus_mv: u16 = 0,
    /// The gauge's cell voltage, mV.
    gauge_mv: u16 = 0,
    ibus_ma: i16 = 0,
    charger_address: u8 = 0,
    charger_status_raw: [3]u8 = .{ 0, 0, 0 },
    /// REG0x38 names a BQ25628.
    charger_part: Check = .not_run,
    /// `configure` passed its read-back and the WATCHDOG field reads
    /// `.disabled` afterwards.
    charger_config: Check = .not_run,
    /// The ADC started and a conversion finished within 300 ms.
    charger_measurement: Check = .not_run,
    /// VERSION names a MAX17048.
    gauge_part: Check = .not_run,
    /// `configure` and `read` worked.
    gauge: Check = .not_run,
    /// The charger's VBAT and the gauge's cell voltage are within 100 mV.
    agree: Check = .not_run,
    vbus_present: bool = false,
    /// The gauge reported STATUS.RI (lost its settings) on `configure`.
    gauge_was_reset: bool = false,
    gauge_soc: u8 = 0,
    reserved: u8 = 0,
};

comptime {
    std.debug.assert(@sizeOf(Report) == 22 and @offsetOf(Report, "reserved") == 21);
}

pub var report: Report = .{}; // read it with a debugger

// Exported, so the optimizer keeps `report` whole, under its own name.
comptime {
    @export(&report, .{ .name = "report" });
}

/// The board's boot configuration, with the ILIM pin in force: the example
/// knows nothing about the USB source, so the hardware limit stays.
const board_config: bq25628.Config = .{
    .charge_current_ma = 1480,
    .charge_voltage_mv = 4200,
    .input_current_ma = 900,
    .input_voltage_mv = 4400,
    .input_voltage_tracks_battery = false,
    .watchdog = .disabled,
    .use_ilim_pin = true,
    .light_load_pfm = false,
    .vbus_ovp = .v6_3,
    .batfet_actions_with_vbus = true,
};

const Charger = bq25628.Bq25628(I2cBus);
const Gauge = max17048.Max17048(I2cBus);

/// At file scope, as the device keeps a pointer to it.
var i2c: hal.i2c.I2C_Device = undefined;
var seed: zmetal.Seed = .{};

pub fn main() !void {
    try seed.init(.{ .sdram = false, .qspi = false });

    i2c = hal.i2c.I2C_Device.init(.I2C1, .{
        .speed = .I2C_100KHZ,
        .min_start_gap_us = 90,
    }) catch {
        report.charger_part = .fail;
        report.gauge_part = .fail;
        return blink();
    };
    const bus: I2cBus = .{ .dev = i2c.i2c_device() };

    checkCharger(bus);
    checkGauge(bus);
    checkAgree();

    if (anyFail()) blink();
    seed.setLed(true);
    while (true) microzig.cpu.wfi();
}

fn blink() noreturn {
    while (true) {
        seed.toggleLed();
        zmetal.time.delayMs(250); // 2 Hz: on 250 ms, off 250 ms
    }
}

fn verdict(ok: bool) Check {
    return if (ok) .pass else .fail;
}

fn anyFail() bool {
    inline for (@typeInfo(Report).@"struct".field_names) |name| {
        if (@FieldType(Report, name) == Check) {
            if (@field(report, name) == .fail) return true;
        }
    }
    return false;
}

/// `charger_address`, `charger_part`: `init` at 0x6A, then at 0x6B. The
/// address that answered goes into `charger_address`; a chip that answers
/// but is not a BQ25628 gives `charger_part = .fail`. No answer at either:
/// `charger_part = .fail`, address 0.
///
/// `charger_config`: `configure(board_config)`, then `kickWatchdog` (harmless
/// with the watchdog off; it compiles the function for the target), then
/// `watchdog()` must read `.disabled`. `charger_status_raw` is REG0x1D..0x1F
/// read through the bus; `vbus_present` comes from `status()`.
///
/// `charger_measurement`: `startMeasurement` (false = `.fail`), then
/// `readMeasurement` every 5 ms for up to 300 ms.
fn checkCharger(bus: I2cBus) void {
    const addresses = [_]u7{ bq25628.default_address, 0x6B };
    var found: ?Charger = null;
    for (addresses) |address| {
        if (Charger.init(bus, address)) |dev| {
            found = dev;
            report.charger_address = address;
            report.charger_part = .pass;
            break;
        } else |err| {
            if (err == error.WrongPart) { // it answered, but it is another part
                report.charger_address = address;
                report.charger_part = .fail;
                return;
            }
        }
    }
    const dev = found orelse {
        report.charger_part = .fail;
        return;
    };

    report.charger_config = verdict(configured(dev));

    var raw: [3]u8 = undefined;
    if (bus.writeThenRead(dev.address, &.{bq25628.reg.status_0}, &raw)) {
        report.charger_status_raw = raw;
    } else |_| {}
    if (dev.status()) |s| {
        report.vbus_present = s.vbus_present;
    } else |_| {}

    report.charger_measurement = verdict(measured(dev));
}

fn configured(dev: Charger) bool {
    dev.configure(board_config) catch return false;
    dev.kickWatchdog() catch return false;
    const wd = dev.watchdog() catch return false;
    return wd == .disabled;
}

fn measured(dev: Charger) bool {
    const started = dev.startMeasurement() catch return false;
    if (!started) return false;
    const start = zmetal.time.nowMs();
    while (zmetal.time.nowMs() -% start <= 300) {
        zmetal.time.delayMs(5);
        const m = (dev.readMeasurement() catch return false) orelse continue;
        report.vbat_mv = m.vbat_mv;
        report.vbus_mv = m.vbus_mv;
        report.ibus_ma = m.ibus_ma;
        return true;
    }
    return false;
}

/// `gauge_part`: `init` at 0x36. `gauge`: `configure(.{ .reset_voltage_mv =
/// 2480 })`, a 1 s wait when it reported a reset (the first SOC needs about
/// 1 s), then `read`.
fn checkGauge(bus: I2cBus) void {
    const dev = Gauge.init(bus, max17048.default_address) catch {
        report.gauge_part = .fail;
        return;
    };
    report.gauge_part = .pass;

    const was_reset = dev.configure(.{ .reset_voltage_mv = 2480 }) catch {
        report.gauge = .fail;
        return;
    };
    report.gauge_was_reset = was_reset;
    if (was_reset) zmetal.time.delayMs(1000);

    const r = dev.read() catch {
        report.gauge = .fail;
        return;
    };
    report.gauge_mv = r.cell_mv;
    report.gauge_soc = r.soc_percent;
    report.gauge = .pass;
}

/// `agree`: the charger's VBAT and the gauge's cell voltage within 100 mV.
/// `.not_run` unless both were read.
fn checkAgree() void {
    if (report.charger_measurement != .pass or report.gauge != .pass) return;
    const diff = @abs(@as(i32, report.vbat_mv) - @as(i32, report.gauge_mv));
    report.agree = verdict(diff <= 100);
}
