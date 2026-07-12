//! Four rotary encoders on a dedicated MCP23017 I2C GPIO expander (address 0x20).
//!
//! Each encoder uses three expander pins — quadrature A/B plus a push switch —
//! per the WoopyOne v0.1 layout. `poll()` reads all 16 inputs in one I2C
//! transaction and advances each encoder's decoder (`hid/encoder.zig`).
//!
//! Usage:
//! ```zig
//! var encoders: Encoders = undefined;
//! try encoders.init(i2c_dev.i2c_device());
//! // periodically (a few ms):
//! try encoders.poll();
//! const e0 = encoders.get(0); // .inc / .pressed / .just_pressed ...
//! ```

const std = @import("std");
const microzig = @import("microzig");
const mcp23017 = @import("../drivers/mcp23017.zig");
const encoder = @import("encoder.zig");

const drivers = microzig.drivers;
pub const I2C_Device = drivers.base.I2C_Device;
const MCP23017 = mcp23017.MCP23017;

pub const Update = encoder.Update;

pub const NUM_ENCODERS = 4;

/// I2C address of the encoder expander (the keyboard uses a separate one at 0x21).
const MCP_I2C_ADDRESS: u8 = 0x20;

const EncPins = struct { a: u8, b: u8, sw: u8 };

/// WoopyOne v0.1 pin map. Expander pins 0-7 are Port A, 8-15 are Port B.
const enc_pins = [NUM_ENCODERS]EncPins{
    .{ .a = 10, .b = 9, .sw = 11 }, // ENC 0
    .{ .a = 13, .b = 12, .sw = 14 }, // ENC 1
    .{ .a = 2, .b = 1, .sw = 3 }, // ENC 2
    .{ .a = 5, .b = 4, .sw = 6 }, // ENC 3
};

pub const Encoders = struct {
    const Self = @This();

    mcp: MCP23017,
    decoders: [NUM_ENCODERS]encoder.Encoder,
    last: [NUM_ENCODERS]Update,

    /// Initialize in place (see `keyboard.Keyboard.init` for the same rationale:
    /// the MCP holds a copy of the I2C interface, and callers keep `Encoders` at
    /// a stable address).
    pub fn init(self: *Self, i2c_dev: I2C_Device) !void {
        self.mcp = try MCP23017.init(i2c_dev, MCP_I2C_ADDRESS);
        // All 16 pins are inputs; MCP23017.init already enabled the pull-ups.
        try self.mcp.setPortMode(.A, 0xFF);
        try self.mcp.setPortMode(.B, 0xFF);

        for (&self.decoders) |*d| d.* = encoder.Encoder.init();
        for (&self.last) |*u| u.* = .{};
    }

    /// Read all 16 expander inputs in one transaction and advance every encoder.
    pub fn poll(self: *Self) !void {
        // In the MCP's byte (non-sequential) mode a 2-byte read from GPIOA
        // returns [GPIOA, GPIOB] — the whole 16-bit input port.
        const ports = self.mcp.readRegisterPair(.GPIOA) catch return error.I2CError;
        for (&self.decoders, 0..) |*d, i| {
            const p = enc_pins[i];
            self.last[i] = d.step(pinBit(ports, p.a), pinBit(ports, p.b), pinBit(ports, p.sw));
        }
    }

    /// Latest decoded state for encoder `i` (from the most recent `poll`).
    pub fn get(self: *const Self, i: usize) Update {
        return self.last[i];
    }

    /// Extract expander pin `pin` (0-15) from a [Port A, Port B] byte pair.
    fn pinBit(ports: [2]u8, pin: u8) u1 {
        const port = ports[pin / 8];
        return @intCast((port >> @intCast(pin % 8)) & 1);
    }
};
