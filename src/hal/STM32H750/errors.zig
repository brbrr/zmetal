const std = @import("std");
const Pin = @import("gpio.zig").Pin;

const led = Pin.init("C", "7");

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    std.log.err("panic: {s}", .{message});
    led.configure();
    led.toggle();
    // @breakpoint();
    while (true) {
        led.toggle();
        delay(100_000);
    }
}

pub fn error_handler() void {
    led.configure();
    while (true) {
        led.toggle();
        delay(10_000);
        @breakpoint();
    }
}

fn delay(wait: u32) void {
    var i: u32 = 0;
    while (i < wait) {
        asm volatile ("nop");
        i += 1;
    }
}
