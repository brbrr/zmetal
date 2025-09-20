const std = @import("std");

const microzig = @import("microzig");
const cpu = microzig.cpu;
const chip = microzig.chip;

const chip_peri = chip.peripherals;
const RCC = chip_peri.RCC;
const time = microzig.drivers.time;

const daisy = @import("hal/STM32H750/daisy.zig");
pub const hal = @import("hal/STM32H750/hal.zig");

const led = hal.gpio.Pin.init("C", "7", .{});
const btn = hal.gpio.Pin.init("G", "9", .{
    .mode = .Input,
});
const tx = hal.gpio.Pin.init("B", "6", .{
    .mode = .{ .Alternate = .af7 },
    .otype = .PushPull,
    .speed = .VeryHighSpeed,
    .pull = .Floating,
});
const rx = hal.gpio.Pin.init("B", "7", .{
    .mode = .{ .Alternate = .af7 },
    .otype = .PushPull,
    .speed = .VeryHighSpeed,
    .pull = .PullUp,
});

const uart = hal.uart.instance.num(0);

var data: [1]u8 = .{0};

pub fn uart_main() !void {
    led.configure();
    btn.configure();
    led.toggle();

    tx.configure();
    rx.configure();

    uart.apply(.{});

    hal.uart.init_logger(uart);
    std.log.debug("Test logger", .{});

    while (true) {
        cpu.wfi();
        if (btn.read() == .Low) {
            led.toggle();
        }

        // Read one byte, timeout disabled
        uart.read_blocking(&data, null) catch {
            // You need to clear UART errors before making a new transaction
            uart.clear_errors();
            std.log.debug("Got some errors :[", .{});
            continue;
        };

        //tries to write one byte with 100ms timeout
        uart.write_blocking(&data, time.Duration.from_ms(100)) catch {
            std.log.debug("Got some errors :[", .{});
            uart.clear_errors();
        };
        // Toggle the led every time we think we've received a character so we
        // know something is going on.
        led.toggle();
    }
}
