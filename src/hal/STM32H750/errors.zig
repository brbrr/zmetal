//! Error handling and panic utilities for STM32H750

const std = @import("std");

/// Custom panic handler for embedded environment
/// Logs the panic message and enters an infinite loop
pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    std.log.err("PANIC: {s}", .{message});
    @breakpoint();
    hang();
}

/// Generic error handler that enters debug mode
pub fn error_handler() noreturn {
    @breakpoint();
    hang();
}

/// Hang the system in an infinite loop
pub inline fn hang() noreturn {
    while (true) {
        asm volatile ("wfi");
    }
}

/// Busy-wait delay using NOP instructions
/// Note: This is cycle-based and will vary with CPU frequency
/// For precise timing, use a hardware timer instead
pub fn delay(cycles: u32) void {
    var i: u32 = 0;
    while (i < cycles) : (i += 1) {
        asm volatile ("nop");
    }
}
