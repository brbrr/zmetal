//! I2C driver for STM32H750, wrapping microzig's `i2c_v2` with Daisy-specific
//! pin/timing config and a robust register-level transfer path (see
//! `i2c_device` for why the built-in blocking loops are bypassed).
//!
//! Usage: `var dev = try I2C_Device.init(.I2C1, .{}); dev.apply();` then
//! `dev.i2c_device()` for the microzig driver interface.

const std = @import("std");
const microzig = @import("microzig");
const chip = microzig.chip;
const drivers = microzig.drivers;

// Import STM32 common I2C implementation
const stm32_common = @import("stm32_common");
const i2c_v2 = stm32_common.i2c_v2;
const enums = stm32_common.enums;

// Import HAL modules
const rcc = @import("rcc.zig");
const gpio = @import("gpio.zig");
const pins = @import("pins.zig");
const clock = @import("clock.zig");

/// Re-export I2C_Device types from microzig
pub const Address = drivers.base.I2C_Device.Address;
pub const Error = drivers.base.I2C_Device.Error;
pub const InterfaceError = drivers.base.I2C_Device.InterfaceError;

/// I2C peripheral selection
pub const Peripheral = enum {
    I2C1,
    I2C2,
    I2C3,
    I2C4,

    fn to_i2c_type(self: Peripheral) enums.I2C_Type {
        return switch (self) {
            .I2C1 => .I2C1,
            .I2C2 => .I2C2,
            .I2C3 => .I2C3,
            .I2C4 => .I2C4,
        };
    }

    fn to_rcc_peripheral(self: Peripheral) rcc.RccPeriferals {
        return switch (self) {
            .I2C1 => .I2C1,
            .I2C2 => .I2C2,
            .I2C3 => .I2C3,
            .I2C4 => .I2C4,
        };
    }
};

/// I2C clock speed configuration
pub const Speed = enum {
    /// Standard mode: 100 kHz
    I2C_100KHZ,
    /// Fast mode: 400 kHz
    I2C_400KHZ,
    /// Fast mode plus: ~886 kHz (approximates 1 MHz)
    I2C_1MHZ,
};

/// TIMINGR for `speed` at the actual I2C kernel clock (I2C1/2/3 share
/// `I2C123output`). TIMINGR is a multi-field register a solver (CubeMX) produces,
/// not a simple divide, so we don't compute it — we carry the hardware-measured
/// values from libdaisy (`src/per/i2c.cpp`) and select by the resolved clock
/// tree: `[0]` = 120 MHz kernel (480 MHz SYSCLK / VOS0 boost), `[1]` = 100 MHz
/// (400 MHz SYSCLK / VOS1). Any other kernel clock fails the build loudly rather
/// than silently mis-timing the bus.
fn timingrFor(comptime speed: Speed) u32 {
    const proven: [2]u32 = switch (speed) {
        .I2C_100KHZ => .{ 0x6090435F, 0x30E0628A },
        .I2C_400KHZ => .{ 0x30B00F2D, 0x20D01132 },
        .I2C_1MHZ => .{ 0x10A00B20, 0x1080091A },
    };
    return switch (@as(u32, @intFromFloat(rcc.clock_outputs.I2C123output))) {
        120_000_000 => proven[0],
        100_000_000 => proven[1],
        else => @compileError("no proven I2C TIMINGR for this kernel clock — add a measured value (cf. libdaisy src/per/i2c.cpp)"),
    };
}

/// I2C configuration structure
pub const Config = struct {
    /// Clock speed selection (default: 400 kHz)
    speed: Speed = .I2C_400KHZ,

    /// Pin configuration (optional - use default Daisy Seed pins if not specified)
    /// If provided, these pins will be configured automatically
    pin_config: ?PinConfig = null,

    /// Override TIMINGR register value (optional - uses libdaisy tested values if not specified)
    /// If null, uses hardcoded values from libdaisy that are known to work
    timingr_override: ?u32 = null,
};

/// Pin configuration for I2C
pub const PinConfig = struct {
    scl: struct { port: []const u8, pin: []const u8, af: gpio.AlternateFunction },
    sda: struct { port: []const u8, pin: []const u8, af: gpio.AlternateFunction },
};

/// Default pin configurations for Daisy Seed board
pub const daisy_pin_configs = struct {
    /// I2C1: PB8 (SCL), PB9 (SDA) - AF4
    pub const I2C1 = PinConfig{
        .scl = .{ .port = "B", .pin = "8", .af = .af4 },
        .sda = .{ .port = "B", .pin = "9", .af = .af4 },
    };

    /// I2C2: PB10 (SCL), PB11 (SDA) - AF4
    pub const I2C2 = PinConfig{
        .scl = .{ .port = "B", .pin = "10", .af = .af4 },
        .sda = .{ .port = "B", .pin = "11", .af = .af4 },
    };

    /// I2C3: PA8 (SCL), PC9 (SDA) - AF4
    pub const I2C3 = PinConfig{
        .scl = .{ .port = "A", .pin = "8", .af = .af4 },
        .sda = .{ .port = "C", .pin = "9", .af = .af4 },
    };

    /// I2C4: PD12 (SCL), PD13 (SDA) - AF4
    pub const I2C4 = PinConfig{
        .scl = .{ .port = "D", .pin = "12", .af = .af4 },
        .sda = .{ .port = "D", .pin = "13", .af = .af4 },
    };
};

/// I2C Device wrapper that provides zero-cost abstraction over microzig's I2C_Device
pub const I2C_Device = struct {
    inner: i2c_v2.I2C_Device,

    /// Initialize an I2C peripheral with the given configuration
    /// This should be called at comptime or at startup to compute timing parameters
    ///
    /// Note: After init(), call apply() to enable the peripheral
    pub fn init(comptime peripheral: Peripheral, comptime config: Config) !I2C_Device {
        const i2c_type = comptime peripheral.to_i2c_type();

        // Initialize the underlying microzig I2C device
        // This computes timing registers based on the clock configuration
        var inner = try i2c_v2.I2C_Device.init(i2c_type);

        // Override TIMINGR with libdaisy proven values if requested or use speed-based defaults
        inner.i2c.timingr = if (config.timingr_override) |timingr_val|
            @bitCast(timingr_val)
        else
            @bitCast(timingrFor(config.speed));

        // Configure pins if specified, otherwise use defaults
        const pin_cfg = config.pin_config orelse switch (peripheral) {
            .I2C1 => daisy_pin_configs.I2C1,
            .I2C2 => daisy_pin_configs.I2C2,
            .I2C3 => daisy_pin_configs.I2C3,
            .I2C4 => daisy_pin_configs.I2C4,
        };

        // Recover a bus left stuck by a reset mid-transfer, THEN switch the pins
        // to the I2C alternate function.
        recover_bus(pin_cfg);
        configure_pins(pin_cfg);

        return I2C_Device{ .inner = inner };
    }

    /// Apply the configuration and enable the I2C peripheral
    /// Must be called after init() and before using the device
    pub fn apply(self: *const I2C_Device) void {
        self.inner.apply();
    }

    /// Get the I2C_Device interface for use with microzig drivers.
    ///
    /// Returns a drivers.base.I2C_Device backed by THIS module's robust transfer
    /// routines (see `robust_vtable`), not microzig's built-in blocking loops.
    /// microzig's i2c_v2 spins forever with no timeout and never clears NACKF/
    /// STOPF, so a single NACK poisons every later transfer. Our routines add a
    /// per-transfer timeout, clear the status flags, and reset the peripheral on
    /// error — modeled on the libdaisy reference (10 ms timeout, re-init on error).
    ///
    /// `self` must live at a stable address (drivers copy this fat pointer by
    /// value and keep `ptr = self`).
    pub fn i2c_device(self: *I2C_Device) drivers.base.I2C_Device {
        return .{ .ptr = self, .vtable = &robust_vtable };
    }

    // === Robust register-level transfer implementation ===============
    //
    // Operates directly on the peripheral register block (self.inner.i2c.regs).
    // The clock, TIMINGR and pins are already set up by init()/apply().

    /// Per-transfer timeout, in milliseconds (matches libdaisy's default).
    const TRANSFER_TIMEOUT_MS: u32 = 10;

    /// ICR write-1-to-clear mask: NACKCF(4) | STOPCF(5) | BERRCF(8) | ARLOCF(9).
    /// Written raw so we don't depend on per-field register names.
    const ICR_CLEAR_MASK: u32 = (1 << 4) | (1 << 5) | (1 << 8) | (1 << 9);

    fn regs(self: *I2C_Device) @TypeOf(self.inner.i2c.regs) {
        return self.inner.i2c.regs;
    }

    /// Reset the peripheral state machine after an error or timeout. Toggling PE
    /// releases SCL/SDA and clears BUSY and all status flags; TIMINGR is retained.
    fn recover(self: *I2C_Device) void {
        const r = self.regs();
        r.CR1.modify(.{ .PE = 0 });
        var i: u32 = 0;
        while (i < 16) : (i += 1) asm volatile ("nop"); // hold PE=0 a few APB cycles
        r.CR1.modify(.{ .PE = 1 });
    }

    /// Wait until the given ISR flag is set, bailing out on NACK/bus-error or a
    /// timeout. On any failure the peripheral is reset before returning.
    fn wait_flag(self: *I2C_Device, comptime flag: []const u8) Error!void {
        const r = self.regs();
        const start = clock.get_tick();
        while (true) {
            const isr = r.ISR.read();
            if (@field(isr, flag) == 1) return;
            if (isr.NACKF == 1) {
                self.recover();
                return Error.NoAcknowledge;
            }
            if (isr.BERR == 1 or isr.ARLO == 1) {
                self.recover();
                return Error.UnknownAbort;
            }
            if (clock.get_tick() -% start >= TRANSFER_TIMEOUT_MS) {
                self.recover();
                return Error.Timeout;
            }
        }
    }

    /// Wait for the bus to be free before starting a new transfer.
    fn wait_not_busy(self: *I2C_Device) Error!void {
        const r = self.regs();
        const start = clock.get_tick();
        while (r.ISR.read().BUSY == 1) {
            if (clock.get_tick() -% start >= TRANSFER_TIMEOUT_MS) {
                self.recover();
                return Error.Timeout;
            }
        }
    }

    /// Master write of one datagram. `restart` leaves the bus held (AUTOEND off,
    /// stops at TC) so a repeated-START read can follow; otherwise a STOP is
    /// generated automatically.
    fn transfer_write(self: *I2C_Device, address: Address, data: []const u8, comptime restart: bool) Error!void {
        const r = self.regs();
        r.ICR.write_raw(ICR_CLEAR_MASK); // drop any stale flags from a prior transfer
        try self.wait_not_busy();

        r.CR2.modify(.{
            .NBYTES = @as(u8, @intCast(data.len)),
            .SADD = @as(u10, @intCast(@intFromEnum(address))) << 1,
            .AUTOEND = if (restart) .Software else .Automatic,
            .DIR = .Write,
        });
        r.CR2.modify(.{ .START = 1 });

        for (data) |byte| {
            try self.wait_flag("TXIS");
            r.TXDR.modify(.{ .TXDATA = byte });
        }

        if (restart) {
            try self.wait_flag("TC");
        } else {
            try self.wait_flag("STOPF");
            r.ICR.write_raw(ICR_CLEAR_MASK);
        }
    }

    /// Master read of one datagram. Issues its own (repeated) START. When it
    /// follows a `restart` write, `after_restart` must be true: the bus is
    /// legitimately still BUSY (held for the repeated START), so skip the
    /// bus-free wait that a standalone read performs.
    fn transfer_read(self: *I2C_Device, address: Address, buffer: []u8, comptime after_restart: bool) Error!void {
        const r = self.regs();
        r.ICR.write_raw(ICR_CLEAR_MASK);
        if (!after_restart) try self.wait_not_busy();

        r.CR2.modify(.{
            .NBYTES = @as(u8, @intCast(buffer.len)),
            .SADD = @as(u10, @intCast(@intFromEnum(address))) << 1,
            .AUTOEND = .Automatic,
            .DIR = .Read,
        });
        r.CR2.modify(.{ .START = 1 });

        for (buffer) |*slot| {
            try self.wait_flag("RXNE");
            slot.* = r.RXDR.read().RXDATA;
        }

        try self.wait_flag("STOPF");
        r.ICR.write_raw(ICR_CLEAR_MASK);
    }

    const robust_vtable = drivers.base.I2C_Device.VTable{
        .writev_fn = robust_writev,
        .readv_fn = robust_readv,
        .writev_then_readv_fn = robust_writev_then_readv,
    };

    fn robust_writev(ctx: *anyopaque, address: Address, datagrams: []const []const u8) InterfaceError!void {
        const self: *I2C_Device = @ptrCast(@alignCast(ctx));
        address.check_reserved() catch return InterfaceError.TargetAddressReserved;
        for (datagrams) |chunk| {
            try self.transfer_write(address, chunk, false);
        }
    }

    fn robust_readv(ctx: *anyopaque, address: Address, datagrams: []const []u8) InterfaceError!usize {
        const self: *I2C_Device = @ptrCast(@alignCast(ctx));
        address.check_reserved() catch return InterfaceError.TargetAddressReserved;
        var total: usize = 0;
        for (datagrams) |chunk| {
            try self.transfer_read(address, chunk, false);
            total += chunk.len;
        }
        return total;
    }

    fn robust_writev_then_readv(
        ctx: *anyopaque,
        address: Address,
        write_chunks: []const []const u8,
        read_chunks: []const []u8,
    ) InterfaceError!void {
        const self: *I2C_Device = @ptrCast(@alignCast(ctx));
        address.check_reserved() catch return InterfaceError.TargetAddressReserved;
        for (write_chunks, 0..) |chunk, index| {
            try self.transfer_write(address, chunk, true);
            try self.transfer_read(address, read_chunks[index], true);
        }
    }

    /// Write data to an I2C device (blocking)
    pub fn write(self: *I2C_Device, address: Address, data: []const u8) Error!void {
        const dev = self.i2c_device();
        return dev.write(address, data);
    }

    /// Write multiple chunks to an I2C device (blocking)
    pub fn writev(self: *I2C_Device, address: Address, chunks: []const []const u8) Error!void {
        const dev = self.i2c_device();
        return dev.writev(address, chunks);
    }

    /// Read data from an I2C device (blocking)
    pub fn read(self: *I2C_Device, address: Address, buffer: []u8) Error!usize {
        const dev = self.i2c_device();
        return dev.read(address, buffer);
    }

    /// Read multiple chunks from an I2C device (blocking)
    pub fn readv(self: *I2C_Device, address: Address, buffers: []const []u8) Error!usize {
        const dev = self.i2c_device();
        return dev.readv(address, buffers);
    }

    /// Write then read from an I2C device (blocking, with repeated start)
    /// This is useful for reading registers: write register address, then read value
    pub fn write_then_read(
        self: *I2C_Device,
        address: Address,
        write_data: []const u8,
        read_buffer: []u8,
    ) Error!void {
        const dev = self.i2c_device();
        return dev.write_then_read(address, write_data, read_buffer);
    }

    /// Write multiple chunks then read multiple chunks (blocking, with repeated start)
    pub fn writev_then_readv(
        self: *I2C_Device,
        address: Address,
        write_chunks: []const []const u8,
        read_chunks: []const []u8,
    ) Error!void {
        const dev = self.i2c_device();
        return dev.writev_then_readv(address, write_chunks, read_chunks);
    }

    /// Read from a specific register address (convenience function)
    /// Equivalent to write_then_read with a single-byte register address
    pub fn read_register(
        self: *I2C_Device,
        device_addr: Address,
        register_addr: u8,
        buffer: []u8,
    ) Error!void {
        const reg_bytes = [_]u8{register_addr};
        return self.write_then_read(device_addr, &reg_bytes, buffer);
    }

    /// Write to a specific register address (convenience function)
    /// Sends register address followed by data bytes
    pub fn write_register(
        self: *I2C_Device,
        device_addr: Address,
        register_addr: u8,
        data: []const u8,
    ) Error!void {
        const reg_bytes = [_]u8{register_addr};
        return self.writev(device_addr, &.{ &reg_bytes, data });
    }
};

/// Recover a stuck I2C bus before the peripheral takes over the pins.
///
/// A CPU reset resets the I2C peripheral but NOT the bus or the slaves. A slave
/// (e.g. the MCP23017) interrupted mid-byte keeps driving SDA low, so the next
/// transfer's START never completes and every transfer times out. The standard
/// fix: drive the pins as GPIO and bit-bang up to 9 SCL clocks — one byte + ACK
/// — until the slave finishes and releases SDA, then issue a STOP. Must run
/// BEFORE `configure_pins` switches the pins to the I2C alternate function.
fn recover_bus(comptime pin_cfg: PinConfig) void {
    const scl = comptime gpio.Pin.init(pin_cfg.scl.port, pin_cfg.scl.pin, .{
        .mode = .output,
        .otype = .OpenDrain,
        .pull = .PullUp,
        .speed = .VeryHighSpeed,
    });
    const sda = comptime gpio.Pin.init(pin_cfg.sda.port, pin_cfg.sda.pin, .{
        .mode = .output,
        .otype = .OpenDrain,
        .pull = .PullUp,
        .speed = .VeryHighSpeed,
    });

    scl.configure();
    sda.configure();
    // Release both lines (open-drain high = let the pull-ups win).
    scl.write(.High);
    sda.write(.High);
    bit_delay();

    // Clock SCL until the slave releases SDA (bus is idle-high when free).
    var pulses: u8 = 0;
    while (pulses < 9 and sda.read() == .Low) : (pulses += 1) {
        scl.write(.Low);
        bit_delay();
        scl.write(.High);
        bit_delay();
    }

    // Only if we actually had to clock (bus was stuck), issue a STOP —
    // SDA low->high while SCL is high — to leave the bus cleanly idle.
    if (pulses > 0) {
        sda.write(.Low);
        bit_delay();
        scl.write(.High);
        bit_delay();
        sda.write(.High);
        bit_delay();
    }
}

/// Half-period for the recovery bit-bang (~100 kHz). Timing isn't critical (it
/// only has to satisfy a slave's setup/hold and runs once at startup); uses the
/// SysTick-independent `clock.delay_us` since SysTick may not be up this early.
inline fn bit_delay() void {
    clock.delay_us(5);
}

/// Configure GPIO pins for I2C function.
///
/// Pins use open-drain with NO internal pull-up, matching the libdaisy reference
/// (`GPIO_MODE_AF_OD` / `GPIO_NOPULL`). The board provides external ~4.7kΩ
/// pull-ups on SCL/SDA, which the 400 kHz TIMINGR values are tuned for; the weak
/// (~40kΩ) internal pull-ups would slow the rise time and are intentionally off.
fn configure_pins(comptime pin_cfg: PinConfig) void {
    // Configure SCL pin
    const scl_pin = comptime gpio.Pin.init(pin_cfg.scl.port, pin_cfg.scl.pin, .{
        .mode = .{ .alternate = pin_cfg.scl.af },
        .otype = .OpenDrain,
        .speed = .VeryHighSpeed,
        .pull = .Floating,
    });
    scl_pin.configure();

    // Configure SDA pin
    const sda_pin = comptime gpio.Pin.init(pin_cfg.sda.port, pin_cfg.sda.pin, .{
        .mode = .{ .alternate = pin_cfg.sda.af },
        .otype = .OpenDrain,
        .speed = .VeryHighSpeed,
        .pull = .Floating,
    });
    sda_pin.configure();
}

/// Helper to create an I2C device at comptime with error handling
/// Usage: `const i2c = try hal.i2c.create(.I2C1, .{});`
pub fn create(comptime peripheral: Peripheral, comptime config: Config) !I2C_Device {
    return I2C_Device.init(peripheral, config);
}
