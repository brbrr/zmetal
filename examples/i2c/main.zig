//! I2C example: read an AHT30 temperature/humidity sensor on I2C1
//! (PB8 = SCL / D11, PB9 = SDA / D12, 400 kHz)
//! through the HAL's microzig `I2C_Device` interface and microzig's AHT30 driver.
//!
//! Build: `zig build i2c -Doptimize=safe`. The latest reading is kept in
//! `temperature_c` / `relative_humidity` (inspect it over SWD); the user LED (PC7) toggles once per sample.
const microzig = @import("microzig");
const zmetal = @import("zmetal");
const hal = zmetal.hal;
const AHT30 = microzig.drivers.sensor.AHT30;

comptime {
    _ = microzig.export_startup();
}
pub const panic = microzig.panic;
pub const std_options = microzig.std_options(.{});

var seed: zmetal.Seed = .{};
var i2c: hal.i2c.I2C_Device = undefined;

/// Most recent sensor sample (debugger-visible).
pub var temperature_c: f32 = 0;
pub var relative_humidity: f32 = 0;
/// When the last sample was taken (µs since boot).
pub var last_sample_us: u64 = 0;
/// Core/bus clocks after board init (debugger-visible).
pub var clocks: zmetal.hal.clock.Frequencies = undefined;

pub fn main() !void {
    try seed.init(.{ .sdram = false, .qspi = false });
    i2c = try hal.i2c.I2C_Device.init(.I2C1, .{ .speed = .I2C_400KHZ });

    clocks = hal.clock.frequencies();

    const addr: hal.i2c.Address = @enumFromInt(0x38);
    const sensor = try AHT30.init(i2c.i2c_device(), addr);
    hal.clock.delay_ms(5); // AHT30: >= 5 ms after power-up/init

    // AHT30 calibrate/init command (0xBE 0x08 0x00; harmless if already
    // calibrated). Register + data go out as one transaction via writev.
    try i2c.write_register(addr, 0xBE, &.{ 0x08, 0x00 });
    hal.clock.delay_ms(10);

    while (true) {
        try sensor.update_readings();
        hal.clock.delay_ms(80); // AHT30: measurement takes ~80 ms
        if (sensor.read_data()) |r| {
            temperature_c = r.temperature_c;
            relative_humidity = r.relative_humidity;
        } else |_| {} // busy / CRC mismatch: keep the last sample
        seed.toggleLed();
        last_sample_us = zmetal.time.nowUs();
        hal.clock.delay_ms(1000); // >= 1 s cycle for best precision
    }
}
