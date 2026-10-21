//! Rotary encoders on an MCP23017 I2C GPIO expander.
//!
//! Each encoder uses three expander pins — quadrature A/B plus a push switch —
//! given by `EncodersConfig.pins` (expander pin 0..15; 0-7 = Port A, 8-15 =
//! Port B). `poll()` reads all 16 inputs in one I2C transaction and advances
//! each encoder's decoder (`hid/encoder.zig`).
//!
//! Usage:
//! ```zig
//! const Encoders = zmetal.hid.encoders.McpEncoders(.{ .address = 0x20, .pins = &my_pins });
//! var encoders: Encoders = undefined; // must not move after init
//! try encoders.init(i2c.i2c_device());
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
pub const Check = @import("keyboard.zig").Check;

/// Expander pins (0..15) of one encoder.
pub const EncPins = struct { a: u4, b: u4, sw: u4 };

pub const EncodersConfig = struct {
    /// 7-bit I2C address of the expander.
    address: u7,
    pins: []const EncPins,
};

pub fn McpEncoders(comptime cfg: EncodersConfig) type {
    const NUM_ENCODERS = cfg.pins.len;
    const enc_pins = cfg.pins[0..NUM_ENCODERS].*;

    return struct {
        const Self = @This();

        pub const count = NUM_ENCODERS;

        mcp: MCP23017,
        decoders: [NUM_ENCODERS]encoder.Encoder,
        last: [NUM_ENCODERS]Update,

        /// Initialize in place (see `keyboard.Keyboard.init` for the same rationale:
        /// the MCP holds a copy of the I2C interface, and callers keep `Encoders` at
        /// a stable address).
        /// All 16 pins are inputs with pull-ups.
        pub const setup: mcp23017.Setup = .{};

        pub fn init(self: *Self, i2c_dev: I2C_Device) !void {
            self.mcp = try MCP23017.initWith(i2c_dev, cfg.address, setup);

            for (&self.decoders) |*d| d.* = encoder.Encoder.init();
            for (&self.last) |*u| u.* = .{};
        }

        /// Read all 16 expander inputs in one transaction and advance every encoder.
        pub fn poll(self: *Self) !void {
            // In the MCP's byte (non-sequential) mode a 2-byte read from GPIOA
            // returns [GPIOA, GPIOB] — the whole 16-bit input port.
            const ports = try self.mcp.readRegisterPair(.GPIOA);
            for (&self.decoders, 0..) |*d, i| {
                const p = enc_pins[i];
                self.last[i] = d.step(pinBit(ports, p.a), pinBit(ports, p.b), pinBit(ports, p.sw));
            }
        }

        /// Reads the expander's configuration back and, if the chip lost
        /// it, writes it again (see `keyboard.check`).
        pub fn check(self: *Self) mcp23017.Error!Check {
            const rb = try self.mcp.readback();
            if (rb.matches(setup)) return .{ .readback = rb, .repaired = false };
            try self.mcp.configure(setup);
            return .{ .readback = rb, .repaired = true };
        }

        /// Latest decoded state for encoder `i` (from the most recent `poll`).
        pub fn get(self: *const Self, i: usize) Update {
            return self.last[i];
        }

        /// Extract expander pin `pin` (0-15) from a [Port A, Port B] byte pair.
        fn pinBit(ports: [2]u8, pin: u4) u1 {
            const port = ports[pin / 8];
            return @intCast((port >> @intCast(pin % 8)) & 1);
        }
    };
}
