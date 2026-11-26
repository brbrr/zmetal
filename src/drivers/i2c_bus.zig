//! The HAL's I2C device as the `Bus` the std-only drivers (bq25628, max17048)
//! are generic over, and the one mapping from bus errors to `Nack`,
//! `Timeout` and `BusError`.
//!
//! The bus the BQ25628 is on (the MAX17048's too, on the v3 board): create
//! it with `min_start_gap_us = 90` and talk to both chips at 100 kHz, as
//! the bus's speed or a `target(.I2C_100KHZ)`. The charger asks for 90 µs
//! between any two STARTs on its bus at every speed, and at 400 kHz also
//! for a repeated-START set-up time of 68 µs or more, which the HAL cannot
//! lengthen (see `hal.i2c.Config`); both drivers read with a repeated START
//! (`writeThenRead`) ([POWER] §1.1).
//!
//! This file imports microzig, so it is not host-tested.

const std = @import("std");
const microzig = @import("microzig");

/// I2C Device interface type from microzig
pub const I2C_Device = microzig.drivers.base.I2C_Device;

const i2c_bus = @This();

/// A bus fault keeps its kind: a chip that does not answer (`Nack`), a bus
/// that does not move (`Timeout`), a bus fault (`BusError`).
pub const Error = error{ Nack, Timeout, BusError, I2CError };

/// NoAcknowledge, DeviceNotPresent -> Nack; Timeout -> Timeout; UnknownAbort -> BusError; anything else -> I2CError.
pub fn mapError(e: I2C_Device.InterfaceError) Error {
    return switch (e) {
        error.NoAcknowledge, error.DeviceNotPresent => Error.Nack,
        error.Timeout => Error.Timeout,
        error.UnknownAbort => Error.BusError,
        else => Error.I2CError,
    };
}

/// The bus as the std-only drivers see it.
pub const I2cBus = struct {
    dev: I2C_Device,

    pub const Error = i2c_bus.Error;

    pub fn write(self: I2cBus, address: u7, bytes: []const u8) i2c_bus.Error!void {
        self.dev.write(@enumFromInt(address), bytes) catch |e| return mapError(e);
    }

    pub fn writeThenRead(self: I2cBus, address: u7, tx: []const u8, rx: []u8) i2c_bus.Error!void {
        self.dev.write_then_read(@enumFromInt(address), tx, rx) catch |e| return mapError(e);
    }

    /// A plain read: START, address, data, STOP (no register pointer first).
    /// A short read is an `I2CError`. An empty `rx` returns at once, without
    /// an error: nothing is read and the chip is not addressed, so it is no
    /// probe.
    pub fn read(self: I2cBus, address: u7, rx: []u8) i2c_bus.Error!void {
        if (rx.len == 0) return;
        const n = self.dev.read(@enumFromInt(address), rx) catch |e| return mapError(e);
        if (n != rx.len) return i2c_bus.Error.I2CError;
    }
};

// Zig analyses only what something references. `power_check` calls `write`
// and `writeThenRead`; nothing calls `read` yet, and this keeps all three
// compiled for the target.
comptime {
    _ = &I2cBus.write;
    _ = &I2cBus.writeThenRead;
    _ = &I2cBus.read;
}

comptime {
    std.debug.assert(mapError(error.NoAcknowledge) == Error.Nack);
    std.debug.assert(mapError(error.DeviceNotPresent) == Error.Nack);
    std.debug.assert(mapError(error.Timeout) == Error.Timeout);
    std.debug.assert(mapError(error.UnknownAbort) == Error.BusError);
    std.debug.assert(mapError(error.Unsupported) == Error.I2CError);
}
