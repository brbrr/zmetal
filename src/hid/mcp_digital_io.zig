//! Digital_IO wrapper for MCP23017 I2C GPIO expander pins
//!
//! This module provides a Digital_IO interface implementation for individual
//! MCP23017 pins, allowing them to be used with microzig's Keyboard_Matrix driver.

const std = @import("std");
const microzig = @import("microzig");
const mcp23017 = @import("../drivers/mcp23017.zig");

const Digital_IO = microzig.drivers.base.Digital_IO;
const MCP23017 = mcp23017.MCP23017;

/// A single pin on the MCP23017, compatible with Digital_IO interface
pub const McpPin = struct {
    mcp: *MCP23017,
    pin: u8, // 0-15

    pub fn init(mcp: *MCP23017, pin: u8) McpPin {
        return McpPin{
            .mcp = mcp,
            .pin = pin,
        };
    }

    /// Get the Digital_IO interface for this pin
    pub fn digital_io(self: *McpPin) Digital_IO {
        return Digital_IO{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    fn set_direction(ctx: *anyopaque, dir: Digital_IO.Direction) Digital_IO.SetDirError!void {
        const self: *McpPin = @ptrCast(@alignCast(ctx));
        const mode: mcp23017.PinMode = switch (dir) {
            .input => .InputPullup,
            .output => .Output,
        };
        self.mcp.setPinMode(self.pin, mode) catch return error.IoError;
    }

    fn set_bias(ctx: *anyopaque, bias: ?Digital_IO.State) Digital_IO.SetBiasError!void {
        const self: *McpPin = @ptrCast(@alignCast(ctx));
        if (bias) |b| {
            const enabled = (b == .high);
            self.mcp.setPinPullup(self.pin, enabled) catch return error.IoError;
        }
    }

    fn write(ctx: *anyopaque, state: Digital_IO.State) Digital_IO.WriteError!void {
        const self: *McpPin = @ptrCast(@alignCast(ctx));
        const high = (state == .high);
        self.mcp.writePin(self.pin, high) catch return error.IoError;
    }

    fn read(ctx: *anyopaque) Digital_IO.ReadError!Digital_IO.State {
        const self: *McpPin = @ptrCast(@alignCast(ctx));
        const high = self.mcp.readPin(self.pin) catch return error.IoError;
        return if (high) .high else .low;
    }

    const vtable = Digital_IO.VTable{
        .set_direction_fn = set_direction,
        .set_bias_fn = set_bias,
        .write_fn = write,
        .read_fn = read,
    };
};
