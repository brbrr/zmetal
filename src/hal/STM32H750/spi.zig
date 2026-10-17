const std = @import("std");
const microzig = @import("microzig");
const chip = microzig.chip;

const rcc = @import("rcc.zig");
const gpio = @import("gpio.zig");
const clock = @import("clock.zig");
const dma = @import("dma.zig");
const dma_utils = @import("dma_utils.zig");
const cache = @import("cache.zig");

const spi_types = chip.types.peripherals.spi_v3;
const SPI_Peripheral = spi_types.SPI;

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

pub const ClockMode = enum {
    Mode0,
    Mode1,
    Mode2,
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

pub const ChipSelect = enum { Software, HardwareOutput };

pub const Direction = enum {
    FullDuplex,
    TxOnly,
    RxOnly,

    pub fn reg(self: Direction) u2 {
        return switch (self) {
            .FullDuplex => 0b00,
            .TxOnly => 0b01,
            .RxOnly => 0b10,
        };
    }
};

pub const SpiError = packed struct(u8) {
    ovr: bool = false,
    udr: bool = false,
    modf: bool = false,
    fre: bool = false,
    _pad: u4 = 0,

    pub const none = SpiError{};
    pub fn any(e: SpiError) bool {
        return e.ovr or e.udr or e.modf or e.fre;
    }
};

pub const PinConfig = struct {
    sclk: gpio.AfPin,
    miso: gpio.AfPin,
    mosi: gpio.AfPin,
    nss: gpio.AfPin,
};

pub const Config = struct {
    mode: ClockMode = .Mode0,
    data_size: u5 = 8,
    baud_prescaler: BaudPrescaler = .PS_8,
    chip_select: ChipSelect = .Software,
    direction: Direction = .FullDuplex,
    pin_config: ?PinConfig = null,
};

// Single global instance pointer for IRQ handler
pub var spi_instances: [1]?*SPI_Device = [_]?*SPI_Device{null};
// SPI TX uses DMA2 Stream3 (channel 11 = DMA(11/8+1) stream 11%8).
pub const tx_dma_channel: dma.Channel = dma.channel(11);

/// SPI transfer errors seen in the IRQ (OVR/MODF/UDR/TIFRE or a close_transfer
/// error). Counted, never fatal; the transfer is ended and the callback runs.
pub var error_count: u32 = 0;

pub fn tx_dma_irq_handler() callconv(.c) void {
    dma.dma_irq_handler(tx_dma_channel);
}

pub fn spi1_irq_handler() callconv(.c) void {
    if (spi_instances[0]) |dev| {
        const spi = dev.spi;
        const sr = spi.SR.read();
        // EOT: End of Transfer - all data shifted out on wire
        if (sr.EOT == 1) {

            // Clear flags
            spi.IFCR.modify(.{ .EOTC = 1, .TXTFC = 1, .SUSPC = 1 });

            // Disable EOT interrupt
            spi.IER.modify(.{ .EOTIE = 0 });

            const err = dev.close_transfer();
            if (err.any()) error_count +%= 1;

            // Mark not busy
            dev.dma_busy = false;
            dev.transfer_state = .idle;

            // Call user callback
            if (dev.user_callback) |cb| {
                cb(dev.user_context);
            }

            return;
        }

        // Handle errors
        if (sr.OVR == 1 or sr.MODF == 1 or sr.UDR == 1 or sr.TIFRE == 1) {
            spi.IER.raw = 0;
            spi.CFG1.modify(.{ .TXDMAEN = 0 });
            spi.IFCR.raw = 0x1FF;
            spi.CR1.modify(.{ .SPE = 0 });

            const regs = dev.dma_channel.get_regs();
            regs.CR.modify_one("EN", 0);
            var timeout: u32 = 1000;
            while (regs.CR.read().EN != 0 and timeout > 0) : (timeout -= 1) {}

            dev.dma_channel.clear_flags();
            error_count +%= 1;
            dev.dma_busy = false;
            dev.transfer_state = .idle;
            // Still notify the owner so nothing waits forever on a dead transfer.
            if (dev.user_callback) |cb| cb(dev.user_context);
            return;
        }

        // Neither EOT nor an error flag: spurious entry. Leave the transfer
        // running (closing it here would drop SPE mid-transfer).
    }
}

pub const TransferState = enum {
    idle,
    busy_tx,
    busy_rx,
    busy_tx_rx,
};

pub const SPI_Device = struct {
    peripheral: Peripheral,
    spi: *volatile SPI_Peripheral,
    config: Config,

    comptime dma_channel: dma.Channel = tx_dma_channel,
    dma_busy: bool = false,

    // User callback for single transfer completion
    user_callback: ?*const fn (ctx: ?*anyopaque) void = null,
    user_context: ?*anyopaque = null,

    transfer_state: TransferState = .idle,

    pub fn init(comptime peripheral: Peripheral, comptime config: Config) !SPI_Device {
        rcc.enable_clock(peripheral.to_rcc_peripheral());

        const pin_cfg = config.pin_config orelse switch (peripheral) {
            .SPI1 => daisy_pin_configs.SPI1,
            .SPI2 => daisy_pin_configs.SPI2,
            .SPI3 => daisy_pin_configs.SPI3,
            .SPI4 => daisy_pin_configs.SPI4,
            .SPI5 => daisy_pin_configs.SPI5,
            .SPI6 => daisy_pin_configs.SPI6,
        };

        configure_pins(pin_cfg, config);
        try tx_dma_channel.claim();

        return SPI_Device{
            .peripheral = peripheral,
            .spi = peripheral.get_registers(),
            .config = config,
        };
    }

    pub fn deinit(self: *SPI_Device) void {
        self.dma_channel.unclaim();
    }

    /// Configure SPI peripheral registers (call once after init)
    pub fn apply(self: *SPI_Device) void {
        spi_instances[0] = self;

        // Only SPI1 has a handler in hal.default_interrupts.
        if (self.peripheral == .SPI1) {
            // Below the audio, with the display's DMA (`daisy.display_priority`).
            microzig.cpu.interrupt.set_priority(.SPI1, @enumFromInt(1));
            microzig.cpu.interrupt.enable(.SPI1);
        }

        // Disable SPI
        self.spi.CR1.modify(.{ .SPE = 0 });
        self.spi.CR1.raw = 0;

        // Set SSI if software NSS
        if (self.config.chip_select == .Software) {
            self.spi.CR1.modify(.{ .SSI = 1 });
        }

        // Configure CFG1
        const dsize: u5 = self.config.data_size - 1;
        self.spi.CFG1.raw = 0;
        self.spi.CFG1.modify(.{
            .DSIZE = dsize,
            .FTHLV = @as(spi_types.FTHLV, @enumFromInt(0)),
            .MBR = @as(spi_types.MBR, @enumFromInt(@intFromEnum(self.config.baud_prescaler))),
            .CRCEN = 0,
        });

        // Configure CFG2
        const ssm: u1 = if (self.config.chip_select == .Software) 1 else 0;
        const ssoe: u1 = if (self.config.chip_select == .HardwareOutput) 1 else 0;

        self.spi.CFG2.raw = 0;
        self.spi.CFG2.modify(.{
            .MSSI = 0,
            .MIDI = 0,
            .COMM = @as(spi_types.COMM, @enumFromInt(self.config.direction.reg())),
            .MASTER = @as(spi_types.MASTER, @enumFromInt(1)),
            .CPHA = @as(spi_types.CPHA, @enumFromInt(self.config.mode.get_cpha())),
            .CPOL = @as(spi_types.CPOL, @enumFromInt(self.config.mode.get_cpol())),
            .SSM = ssm,
            .SSOE = ssoe,
            .AFCNTR = 1,
        });
    }

    /// Blocking transmit
    pub fn write_blocking(self: *const SPI_Device, data: []const u8) !void {
        if (data.len == 0) return;
        if (data.len > 65535) return error.InvalidSize; // TSIZE is 16-bit

        self.spi.CR1.modify(.{ .SPE = 0 });
        self.spi.CFG2.modify(.{ .COMM = @as(spi_types.COMM, @enumFromInt(0b01)) }); // TX only
        self.spi.CR2.modify(.{ .TSIZE = @as(u16, @intCast(data.len)) });
        self.spi.CR1.modify(.{ .SPE = 1 });
        self.spi.CR1.modify(.{ .CSTART = 1 });

        const txdr_ptr: *volatile u8 = @ptrCast(&self.spi.TXDR8);
        const start = clock.get_tick();
        for (data) |byte| {
            while (self.spi.SR.read().TXP == 0) {
                if (clock.elapsed_ms(start) > 1000) return error.Timeout;
            }
            txdr_ptr.* = byte;
        }

        try self.wait_eot();

        self.spi.IFCR.modify(.{ .EOTC = 1, .TXTFC = 1 });
        self.spi.CR1.modify(.{ .SPE = 0 });
    }

    fn wait_eot(self: *const SPI_Device) !void {
        const timeout_ms = 1000;
        const start_ms = clock.get_tick();

        while (self.spi.SR.read().EOT == 0) {
            if (clock.elapsed_ms(start_ms) > timeout_ms) {
                return error.Timeout;
            }
        }
    }

    /// Stops a DMA transmit in flight and leaves the device idle, with no
    /// completion callback. For a halt path with interrupts off; the data
    /// being sent is cut short.
    pub fn abort_dma(self: *SPI_Device) void {
        if (self.dma_channel.is_claimed()) {
            var regs = self.dma_channel.get_regs();
            regs.CR.modify_one("EN", 0);
            var timeout: u32 = 100_000;
            while (regs.CR.read().EN != 0 and timeout > 0) : (timeout -= 1) {}
            self.dma_channel.clear_flags();
        }
        self.spi.IER.raw = 0;
        self.spi.CFG1.modify(.{ .TXDMAEN = 0 });
        self.spi.IFCR.raw = 0x1FF;
        self.spi.CR1.modify(.{ .SPE = 0 });
        self.dma_busy = false;
        self.transfer_state = .idle;
    }

    /// Check if DMA transfer is in progress
    pub fn is_dma_busy(self: *const SPI_Device) bool {
        return self.dma_busy;
    }

    /// Wait for DMA to complete (blocking)
    pub fn wait_dma_complete(self: *const SPI_Device) void {
        while (self.dma_busy) {
            microzig.cpu.nop();
        }
    }

    /// Single-chunk DMA transfer (max 65535 bytes)
    /// Follows HAL_SPI_Transmit_DMA pattern from STM32 HAL
    pub fn write_dma(
        self: *SPI_Device,
        data: []const u8,
        callback: ?*const fn (ctx: ?*anyopaque) void,
        context: ?*anyopaque,
    ) !void {
        if (data.len == 0 or data.len > 65535) {
            return error.InvalidSize;
        }

        if (!self.dma_channel.is_claimed()) {
            return error.DMANotInitialized;
        }

        if (self.dma_busy) {
            return error.DMABusy;
        }

        // Clean D-cache for DMA
        // cache.clean_dcache_by_addr(@intFromPtr(data.ptr), data.len);

        self.user_callback = callback;
        self.user_context = context;

        // Disable SPI before config (HAL pattern)
        self.spi.CR1.modify(.{ .SPE = 0 });

        // Clear all interrupt enables and flags
        self.spi.IER.raw = 0;
        self.spi.IFCR.raw = 0x1FF;

        // Set TX-only mode
        self.spi.CFG2.modify(.{ .COMM = @as(spi_types.COMM, @enumFromInt(0b01)) });

        // Set transfer size
        self.spi.CR2.modify(.{ .TSIZE = @as(u16, @intCast(data.len)) });

        // Setup DMA
        var handlers = self.dma_channel.handlers();
        handlers.complete = dma_tx_complete;
        handlers.ctx = self;

        try self.dma_channel.setup_transfer(
            try self.dma_tx_target(),
            data,
            .{
                .enable = true,
                .mode = .normal,
                .priority = .VeryHigh,
                .fifo_mode = 3, // FIFO enabled, full threshold (libdaisy parity)
                .size = null,
            },
        );

        // Busy only once the DMA is actually set up (a failed setup must not
        // leave the device stuck busy).
        self.dma_busy = true;
        self.transfer_state = .busy_tx;

        var dma_regs = self.dma_channel.get_regs();
        dma_regs.CR.modify_one("EN", 0);
        dma_regs.NDTR.modify_one("NDT", @intCast(data.len));
        dma_regs.CR.modify_one("EN", 1);

        // Enable DMA request
        self.spi.CFG1.modify(.{ .TXDMAEN = 1 });

        // Enable SPI
        self.spi.CR1.modify(.{ .SPE = 1 });

        // Start transfer
        self.spi.CR1.modify(.{ .CSTART = 1 });
    }

    fn dma_tx_complete(chan: dma.Channel, ctx: *anyopaque) void {
        var self: *SPI_Device = @ptrCast(@alignCast(ctx));

        // Wait for DMA to fully disable
        const regs = chan.get_regs();
        var timeout: u32 = 1000;
        while (regs.CR.read().EN != 0 and timeout > 0) : (timeout -= 1) {}

        // Clear DMA flags
        self.dma_channel.clear_flags();

        // Disable DMA request
        self.spi.CFG1.modify(.{ .TXDMAEN = 0 });

        // Enable EOT interrupt - callback will be called from SPI IRQ
        self.spi.IER.modify(.{ .EOTIE = 1 });
    }

    pub fn dma_tx_target(self: *const SPI_Device) error{Unsupported}!dma.DMA_WriteTarget {
        const dreq = switch (self.peripheral) {
            .SPI1 => dma_utils.DmaRequest.SPI1_TX,
            .SPI2 => dma_utils.DmaRequest.SPI2_TX,
            .SPI3 => dma_utils.DmaRequest.SPI3_TX,
            .SPI4 => dma_utils.DmaRequest.SPI4_TX,
            .SPI5 => dma_utils.DmaRequest.SPI5_TX,
            .SPI6 => return error.Unsupported, // SPI6 is served by BDMA only
        };

        return .{
            .dreq = dreq,
            .addr = @intFromPtr(&self.spi.TXDR8),
        };
    }

    /// Equivalent to HAL's SPI_CloseTransfer.
    /// Call at EOT before firing user callback.
    /// Returns any errors detected in SR at close time.
    pub fn close_transfer(self: *SPI_Device) SpiError {
        const sr = self.spi.SR.read(); // 1. snapshot SR first

        self.spi.IFCR.modify(.{ .EOTC = 1, .TXTFC = 1 }); // ← add SUSPC
        self.spi.CR1.modify(.{ .SPE = 0 }); // 3. disable SPI
        self.spi.IER.modify(.{
            .EOTIE = 0,
            .TXPIE = 0,
            .RXPIE = 0,
            .DXPIE = 0,
            .UDRIE = 0,
            .OVRIE = 0,
            .TIFREIE = 0,
            .MODFIE = 0,
        });

        self.spi.CFG1.modify(.{ .TXDMAEN = 0, .RXDMAEN = 0 }); // 5. disable DMA reqs

        var err = SpiError{};

        // 5. UDR: only reported when not RX-only
        if (self.transfer_state != .busy_rx) {
            if (sr.UDR == 1) {
                err.udr = true;
                self.spi.IFCR.modify(.{ .UDRC = 1 });
            }
        }

        // 6. OVR: only reported when not TX-only
        if (self.transfer_state != .busy_tx) {
            if (sr.OVR == 1) {
                err.ovr = true;
                self.spi.IFCR.modify(.{ .OVRC = 1 });
            }
        }

        // 7. MODF: always
        if (sr.MODF == 1) {
            err.modf = true;
            self.spi.IFCR.modify(.{ .MODFC = 1 });
        }

        // 8. FRE: always
        if (sr.TIFRE == 1) {
            err.fre = true;
            self.spi.IFCR.modify(.{ .TIFREC = 1 });
        }

        return err;
    }
};

fn configure_pins(comptime pin_cfg: PinConfig, comptime config: Config) void {
    const sclk = comptime gpio.Pin.from(pin_cfg.sclk.pin, .{
        .mode = .{ .alternate = pin_cfg.sclk.af },
        .speed = .VeryHighSpeed,
    });
    sclk.configure();

    if (config.direction != .TxOnly) {
        const miso = comptime gpio.Pin.from(pin_cfg.miso.pin, .{
            .mode = .{ .alternate = pin_cfg.miso.af },
            .speed = .VeryHighSpeed,
        });
        miso.configure();
    }

    if (config.direction != .RxOnly) {
        const mosi = comptime gpio.Pin.from(pin_cfg.mosi.pin, .{
            .mode = .{ .alternate = pin_cfg.mosi.af },
            .speed = .VeryHighSpeed,
        });
        mosi.configure();
    }

    if (config.chip_select == .HardwareOutput) {
        const nss = comptime gpio.Pin.from(pin_cfg.nss.pin, .{
            .mode = .{ .alternate = pin_cfg.nss.af },
            .speed = .VeryHighSpeed,
        });
        nss.configure();
    }
}

pub const daisy_pin_configs = struct {
    pub const SPI1 = PinConfig{
        .sclk = .{ .pin = .{ .port = .G, .num = 11 }, .af = .af5 },
        .mosi = .{ .pin = .{ .port = .B, .num = 5 }, .af = .af5 },
        .miso = .{ .pin = .{ .port = .B, .num = 4 }, .af = .af5 },
        .nss = .{ .pin = .{ .port = .G, .num = 10 }, .af = .af5 }, // SPI1_NSS = AF5
    };

    pub const SPI2 = PinConfig{
        .sclk = .{ .pin = .{ .port = .B, .num = 13 }, .af = .af5 },
        .miso = .{ .pin = .{ .port = .B, .num = 14 }, .af = .af5 },
        .mosi = .{ .pin = .{ .port = .B, .num = 15 }, .af = .af5 },
        .nss = .{ .pin = .{ .port = .B, .num = 12 }, .af = .af5 },
    };

    pub const SPI3 = PinConfig{
        .sclk = .{ .pin = .{ .port = .C, .num = 10 }, .af = .af6 },
        .miso = .{ .pin = .{ .port = .C, .num = 11 }, .af = .af6 },
        .mosi = .{ .pin = .{ .port = .C, .num = 12 }, .af = .af6 },
        .nss = .{ .pin = .{ .port = .A, .num = 15 }, .af = .af6 },
    };

    pub const SPI4 = PinConfig{
        .sclk = .{ .pin = .{ .port = .E, .num = 12 }, .af = .af5 },
        .miso = .{ .pin = .{ .port = .E, .num = 13 }, .af = .af5 },
        .mosi = .{ .pin = .{ .port = .E, .num = 14 }, .af = .af5 },
        .nss = .{ .pin = .{ .port = .E, .num = 11 }, .af = .af5 },
    };

    pub const SPI5 = PinConfig{
        .sclk = .{ .pin = .{ .port = .F, .num = 7 }, .af = .af5 },
        .miso = .{ .pin = .{ .port = .F, .num = 8 }, .af = .af5 },
        .mosi = .{ .pin = .{ .port = .F, .num = 9 }, .af = .af5 },
        .nss = .{ .pin = .{ .port = .F, .num = 6 }, .af = .af5 },
    };

    pub const SPI6 = PinConfig{
        .sclk = .{ .pin = .{ .port = .G, .num = 13 }, .af = .af5 },
        .miso = .{ .pin = .{ .port = .G, .num = 12 }, .af = .af5 },
        .mosi = .{ .pin = .{ .port = .G, .num = 14 }, .af = .af5 },
        .nss = .{ .pin = .{ .port = .G, .num = 8 }, .af = .af5 },
    };
};
