//! SPI peripheral driver for STM32H750
//!
//! This module provides SPI support for the STM32H750 (Daisy Seed platform).
//! The STM32H7 series uses a newer SPI peripheral architecture with different
//! registers compared to older STM32 families.
//!
//! Features:
//! - Master mode support
//! - Blocking read/write/transceive operations
//! - Configurable speed, clock polarity/phase, data size
//! - Software or hardware NSS (chip select)
//! - Default Daisy Seed pin configurations
//!
//! Example usage:
//! ```zig
//! var spi1 = try hal.spi.SPI_Device.init(.SPI1, .{
//!     .baud_prescaler = .PS_8,  // ~60 MHz / 8 = 7.5 MHz
//!     .mode = .Mode0,
//! });
//! spi1.apply();
//!
//! const data = [_]u8{0x42, 0x43};
//! try spi1.write_blocking(&data);
//! ```

const std = @import("std");
const microzig = @import("microzig");
const chip = microzig.chip;

// Import HAL modules
const rcc = @import("rcc.zig");
const gpio = @import("gpio.zig");
const pins = @import("pins.zig");
const clock = @import("clock.zig");

// SPI peripheral type from chip definitions
const SPI_Peripheral = chip.types.peripherals.SPI1;

/// SPI peripheral selection
pub const Peripheral = enum {
    SPI1,
    SPI2,
    SPI3,
    SPI4,
    SPI5,
    SPI6,

    fn to_rcc_peripheral(self: Peripheral) rcc.RccPeriferals {
        return switch (self) {
            .SPI1 => .SPI1,
            .SPI2 => .SPI2,
            .SPI3 => .SPI3,
            .SPI4 => .SPI4,
            .SPI5 => .SPI5,
            .SPI6 => .SPI6,
        };
    }

    fn get_registers(self: Peripheral) *volatile SPI_Peripheral {
        return switch (self) {
            .SPI1 => chip.peripherals.SPI1,
            .SPI2 => chip.peripherals.SPI2,
            .SPI3 => chip.peripherals.SPI3,
            .SPI4 => chip.peripherals.SPI4,
            .SPI5 => chip.peripherals.SPI5,
            .SPI6 => chip.peripherals.SPI6,
        };
    }
};

/// SPI clock mode (combines CPOL and CPHA)
pub const ClockMode = enum {
    /// Mode 0: CPOL=0, CPHA=0 (idle low, sample on first edge)
    Mode0,
    /// Mode 1: CPOL=0, CPHA=1 (idle low, sample on second edge)
    Mode1,
    /// Mode 2: CPOL=1, CPHA=0 (idle high, sample on first edge)
    Mode2,
    /// Mode 3: CPOL=1, CPHA=1 (idle high, sample on second edge)
    Mode3,

    fn get_cpol(self: ClockMode) u1 {
        return switch (self) {
            .Mode0, .Mode1 => 0,
            .Mode2, .Mode3 => 1,
        };
    }

    fn get_cpha(self: ClockMode) u1 {
        return switch (self) {
            .Mode0, .Mode2 => 0,
            .Mode1, .Mode3 => 1,
        };
    }
};

/// Baud rate prescaler (divides peripheral clock)
pub const BaudPrescaler = enum(u3) {
    PS_2 = 0,
    PS_4 = 1,
    PS_8 = 2,
    PS_16 = 3,
    PS_32 = 4,
    PS_64 = 5,
    PS_128 = 6,
    PS_256 = 7,
};

/// Chip select management mode
pub const ChipSelect = enum {
    /// Software NSS management (manual control via GPIO)
    Software,
    /// Hardware NSS output (automatic control by SPI peripheral)
    HardwareOutput,
};

/// SPI communication direction
pub const Direction = enum {
    /// Full duplex (TX and RX simultaneously)
    FullDuplex,
    /// Transmit only
    TxOnly,
    /// Receive only
    RxOnly,
};

/// Pin configuration for SPI
pub const PinConfig = struct {
    sclk: struct { port: []const u8, pin: []const u8, af: u8 },
    miso: struct { port: []const u8, pin: []const u8, af: u8 },
    mosi: struct { port: []const u8, pin: []const u8, af: u8 },
    nss: struct { port: []const u8, pin: []const u8, af: u8 },
};

/// Default pin configurations for Daisy Seed board
/// Based on libdaisy mappings
pub const daisy_pin_configs = struct {
    /// SPI1: PG11 (SCLK), PB5 (MOSI), PB4 (MISO) - AF5
    pub const SPI1 = PinConfig{
        .sclk = .{ .port = "G", .pin = "11", .af = 5 },
        .mosi = .{ .port = "B", .pin = "5", .af = 5 },
        .miso = .{ .port = "B", .pin = "4", .af = 5 },
        .nss = .{ .port = "G", .pin = "10", .af = 0 }, // Not used - manual CS
    };

    /// SPI2: PB13 (SCLK), PB14 (MISO), PB15 (MOSI), PB12 (NSS) - AF5
    pub const SPI2 = PinConfig{
        .sclk = .{ .port = "B", .pin = "13", .af = 5 },
        .miso = .{ .port = "B", .pin = "14", .af = 5 },
        .mosi = .{ .port = "B", .pin = "15", .af = 5 },
        .nss = .{ .port = "B", .pin = "12", .af = 5 },
    };

    /// SPI3: PC10 (SCLK), PC11 (MISO), PC12 (MOSI), PA15 (NSS) - AF6
    pub const SPI3 = PinConfig{
        .sclk = .{ .port = "C", .pin = "10", .af = 6 },
        .miso = .{ .port = "C", .pin = "11", .af = 6 },
        .mosi = .{ .port = "C", .pin = "12", .af = 6 },
        .nss = .{ .port = "A", .pin = "15", .af = 6 },
    };

    /// SPI4: PE12 (SCLK), PE13 (MISO), PE14 (MOSI), PE11 (NSS) - AF5
    pub const SPI4 = PinConfig{
        .sclk = .{ .port = "E", .pin = "12", .af = 5 },
        .miso = .{ .port = "E", .pin = "13", .af = 5 },
        .mosi = .{ .port = "E", .pin = "14", .af = 5 },
        .nss = .{ .port = "E", .pin = "11", .af = 5 },
    };

    /// SPI5: PF7 (SCLK), PF8 (MISO), PF9 (MOSI), PF6 (NSS) - AF5
    pub const SPI5 = PinConfig{
        .sclk = .{ .port = "F", .pin = "7", .af = 5 },
        .miso = .{ .port = "F", .pin = "8", .af = 5 },
        .mosi = .{ .port = "F", .pin = "9", .af = 5 },
        .nss = .{ .port = "F", .pin = "6", .af = 5 },
    };

    /// SPI6: PG13 (SCLK), PG12 (MISO), PG14 (MOSI), PG8 (NSS) - AF5
    pub const SPI6 = PinConfig{
        .sclk = .{ .port = "G", .pin = "13", .af = 5 },
        .miso = .{ .port = "G", .pin = "12", .af = 5 },
        .mosi = .{ .port = "G", .pin = "14", .af = 5 },
        .nss = .{ .port = "G", .pin = "8", .af = 5 },
    };
};

/// SPI configuration structure
pub const Config = struct {
    /// Clock mode (default: Mode 0)
    mode: ClockMode = .Mode0,

    /// Data size in bits (4-32 bits, default: 8)
    data_size: u5 = 8,

    /// Baud rate prescaler (default: divide by 8)
    baud_prescaler: BaudPrescaler = .PS_8,

    /// Chip select management (default: software)
    chip_select: ChipSelect = .Software,

    /// Communication direction (default: full duplex)
    direction: Direction = .FullDuplex,

    /// Pin configuration (optional - uses Daisy defaults if not specified)
    pin_config: ?PinConfig = null,
};

/// SPI Device wrapper
pub const SPI_Device = struct {
    peripheral: Peripheral,
    spi: *volatile SPI_Peripheral,
    config: Config,

    /// Initialize an SPI peripheral with the given configuration
    pub fn init(comptime peripheral: Peripheral, comptime config: Config) !SPI_Device {
        // Enable RCC clock for SPI peripheral
        rcc.enable_clock(peripheral.to_rcc_peripheral());

        // Get pin configuration (use default or override)
        const pin_cfg = config.pin_config orelse switch (peripheral) {
            .SPI1 => daisy_pin_configs.SPI1,
            .SPI2 => daisy_pin_configs.SPI2,
            .SPI3 => daisy_pin_configs.SPI3,
            .SPI4 => daisy_pin_configs.SPI4,
            .SPI5 => daisy_pin_configs.SPI5,
            .SPI6 => daisy_pin_configs.SPI6,
        };

        // Configure GPIO pins
        configure_pins(pin_cfg, config);

        return SPI_Device{
            .peripheral = peripheral,
            .spi = peripheral.get_registers(),
            .config = config,
        };
    }

    /// Apply configuration to the SPI peripheral
    /// Matches HAL_SPI_Init sequence
    pub fn apply(self: *const SPI_Device) void {
        // HAL: __HAL_SPI_DISABLE
        self.spi.CR1.modify(.{ .SPE = 0 });

        // HAL: Configure CR1 bits BEFORE CFG1/CFG2
        // Initialize CR1 with known state (use .raw = 0 pattern like SAI)
        self.spi.CR1.raw = 0;

        // HAL: SET_BIT(CR1, SPI_CR1_SSI) if software NSS
        // Do this BEFORE CFG1/CFG2 writes to match HAL order
        if (self.config.chip_select == .Software) {
            self.spi.CR1.modify(.{ .SSI = 1 });
        }

        // HAL: WRITE_REG(CFG1, ...)
        const dsize: u5 = self.config.data_size - 1;
        self.spi.CFG1.raw = 0;
        self.spi.CFG1.modify(.{
            .DSIZE = dsize,
            .FTHVL = 0,
            .MBR = @intFromEnum(self.config.baud_prescaler),
            .CRCEN = 0,
        });

        // HAL: WRITE_REG(CFG2, ...)
        const comm: u2 = switch (self.config.direction) {
            .FullDuplex => 0b00,
            .TxOnly => 0b01,
            .RxOnly => 0b10,
        };

        const ssm: u1 = if (self.config.chip_select == .Software) 1 else 0;
        const ssoe: u1 = if (self.config.chip_select == .HardwareOutput) 1 else 0;

        self.spi.CFG2.raw = 0;
        self.spi.CFG2.modify(.{
            .MSSI = 0,
            .MIDI = 0,
            .COMM = comm,
            .MASTER = 1,
            .CPHA = self.config.mode.get_cpha(),
            .CPOL = self.config.mode.get_cpol(),
            .SSM = ssm,
            .SSOE = ssoe,
            .AFCNTR = 1,
        });

        // Don't enable SPI here - per-transfer enable/disable
    }

    /// Blocking transmit
    pub fn write_blocking(self: *const SPI_Device, data: []const u8) !void {
        if (data.len == 0) return;

        // HAL: SPI_2LINES_TX - MODIFY_REG(CFG2, SPI_CFG2_COMM, SPI_CFG2_COMM_0)
        // Sets COMM=0b01 (TxOnly) even when configured as FullDuplex
        self.spi.CFG2.modify(.{ .COMM = 0b01 });

        // HAL: MODIFY_REG(CR2, SPI_CR2_TSIZE, Size)
        self.spi.CR2.modify(.{ .TSIZE = @as(u16, @intCast(data.len)) });

        // HAL: SET_BIT(CR1, SPI_CR1_SPE)
        self.spi.CR1.modify(.{ .SPE = 1 });

        // HAL: SET_BIT(CR1, SPI_CR1_CSTART)
        self.spi.CR1.modify(.{ .CSTART = 1 });

        // Transmit data
        const txdr_ptr: *volatile u8 = @ptrCast(&self.spi.TXDR);
        for (data) |byte| {
            // Wait for TXP
            while (self.spi.SR.read().TXP == 0) {}
            txdr_ptr.* = byte;
        }

        // Wait for EOT
        try self.wait_eot();

        // HAL: Clear EOT and TXTF flags, disable SPI
        self.spi.IFCR.modify(.{ .EOTC = 1, .TXTFC = 1 });
        self.spi.CR1.modify(.{ .SPE = 0 });
    }

    /// Blocking receive
    pub fn read_blocking(self: *const SPI_Device, buffer: []u8) !void {
        if (buffer.len == 0) return;

        // Set transfer size
        self.spi.CR2.modify(.{ .TSIZE = @as(u16, @intCast(buffer.len)) });

        // Start transfer
        self.spi.CR1.modify(.{ .CSTART = 1 });

        // Receive data
        for (buffer) |*byte| {
            // Wait for RX ready
            while (self.spi.SR.read().RXP == 0) {}
            // Read data (8-bit access)
            const rxdr_ptr: *volatile u8 = @ptrCast(&self.spi.RXDR);
            byte.* = rxdr_ptr.*;
        }

        // Wait for end of transfer
        try self.wait_eot();

        // Clear EOT flag
        self.spi.IFCR.modify(.{ .EOTC = 1 });
    }

    /// Blocking transceive (full duplex)
    pub fn transceive_blocking(self: *const SPI_Device, tx_data: []const u8, rx_buffer: []u8) !void {
        const len = @max(tx_data.len, rx_buffer.len);
        if (len == 0) return;

        // Set transfer size
        self.spi.CR2.modify(.{ .TSIZE = @as(u16, @intCast(len)) });

        // Start transfer
        self.spi.CR1.modify(.{ .CSTART = 1 });

        const txdr_ptr: *volatile u8 = @ptrCast(&self.spi.TXDR);
        const rxdr_ptr: *volatile u8 = @ptrCast(&self.spi.RXDR);

        var tx_idx: usize = 0;
        var rx_idx: usize = 0;

        // Transceive data
        while (tx_idx < len or rx_idx < len) {
            // Transmit if data available and TX ready
            if (tx_idx < len and self.spi.SR.read().TXP != 0) {
                const byte = if (tx_idx < tx_data.len) tx_data[tx_idx] else 0x00;
                txdr_ptr.* = byte;
                tx_idx += 1;
            }

            // Receive if RX ready
            if (rx_idx < len and self.spi.SR.read().RXP != 0) {
                const byte = rxdr_ptr.*;
                if (rx_idx < rx_buffer.len) {
                    rx_buffer[rx_idx] = byte;
                }
                rx_idx += 1;
            }
        }

        // Wait for end of transfer
        try self.wait_eot();

        // Clear EOT flag
        self.spi.IFCR.modify(.{ .EOTC = 1 });
    }

    /// Wait for end of transfer with timeout
    /// HAL: SPI_WaitOnFlagUntilTimeout(hspi, SPI_FLAG_EOT, RESET, ...)
    /// Waits while (flag==RESET), exits when (flag==SET), i.e., wait for EOT to become 1
    fn wait_eot(self: *const SPI_Device) !void {
        const timeout_ms = 1000;
        const start_ms = clock.get_tick();

        // Wait for EOT flag to be SET (bit == 1)
        while (self.spi.SR.read().EOT == 0) {
            if (clock.get_tick() - start_ms > timeout_ms) {
                return error.Timeout;
            }
        }
    }
};

/// Configure GPIO pins for SPI
fn configure_pins(comptime pin_cfg: PinConfig, comptime config: Config) void {
    // Configure SCLK
    const sclk = comptime gpio.Pin.init(pin_cfg.sclk.port, pin_cfg.sclk.pin, .{
        .mode = .{ .alternate = @enumFromInt(pin_cfg.sclk.af) },
        .speed = .VeryHighSpeed,
    });
    sclk.configure();

    // Configure MISO (if needed)
    if (config.direction != .TxOnly) {
        const miso = comptime gpio.Pin.init(pin_cfg.miso.port, pin_cfg.miso.pin, .{
            .mode = .{ .alternate = @enumFromInt(pin_cfg.miso.af) },
            .speed = .VeryHighSpeed,
        });
        miso.configure();
    }

    // Configure MOSI (if needed)
    if (config.direction != .RxOnly) {
        const mosi = comptime gpio.Pin.init(pin_cfg.mosi.port, pin_cfg.mosi.pin, .{
            .mode = .{ .alternate = @enumFromInt(pin_cfg.mosi.af) },
            .speed = .VeryHighSpeed,
        });
        mosi.configure();
    }

    // Configure NSS (if hardware mode)
    if (config.chip_select == .HardwareOutput) {
        const nss = comptime gpio.Pin.init(pin_cfg.nss.port, pin_cfg.nss.pin, .{
            .mode = .{ .alternate = @enumFromInt(pin_cfg.nss.af) },
            .speed = .VeryHighSpeed,
        });
        nss.configure();
    }
}
