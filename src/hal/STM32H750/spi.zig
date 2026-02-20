const std = @import("std");
const microzig = @import("microzig");
const chip = microzig.chip;

const rcc = @import("rcc.zig");
const gpio = @import("gpio.zig");
const clock = @import("clock.zig");
const dma = @import("dma_custom_backup.zig");
const dma_utils = @import("dma_utils.zig");
const cache = @import("cache.zig");

const SPI_Peripheral = chip.types.peripherals.SPI1;

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
    sclk: struct { port: []const u8, pin: []const u8, af: u8 },
    miso: struct { port: []const u8, pin: []const u8, af: u8 },
    mosi: struct { port: []const u8, pin: []const u8, af: u8 },
    nss: struct { port: []const u8, pin: []const u8, af: u8 },
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
// dma1_s2
// pub const rx_dma_channel: dma.Channel = dma.channel(10);
// dma1_s3
pub const tx_dma_channel: dma.Channel = dma.channel(11);
// [0, 7] = 8,

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

            if (err.any()) {
                // call error callback if you add one, or fold into user_callback with a result param
                @breakpoint();
                @panic("SPI error");
            }

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
            dev.dma_busy = false;

            @panic("SPI error");
        }

        const err = dev.close_transfer();

        if (err.any()) {
            // call error callback if you add one, or fold into user_callback with a result param
            @breakpoint();
            @panic("SPI error");
        }
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
            .FTHVL = 0,
            .MBR = @intFromEnum(self.config.baud_prescaler),
            .CRCEN = 0,
        });

        // Configure CFG2
        const ssm: u1 = if (self.config.chip_select == .Software) 1 else 0;
        const ssoe: u1 = if (self.config.chip_select == .HardwareOutput) 1 else 0;

        self.spi.CFG2.raw = 0;
        self.spi.CFG2.modify(.{
            .MSSI = 0,
            .MIDI = 0,
            .COMM = self.config.direction.reg(),
            .MASTER = 1,
            .CPHA = self.config.mode.get_cpha(),
            .CPOL = self.config.mode.get_cpol(),
            .SSM = ssm,
            .SSOE = ssoe,
            .AFCNTR = 1,
        });
    }

    /// Blocking transmit
    pub fn write_blocking(self: *const SPI_Device, data: []const u8) !void {
        if (data.len == 0) return;

        self.spi.CR1.modify(.{ .SPE = 0 });
        self.spi.CFG2.modify(.{ .COMM = 0b01 }); // TX only
        self.spi.CR2.modify(.{ .TSIZE = @as(u16, @intCast(data.len)) });
        self.spi.CR1.modify(.{ .SPE = 1 });
        self.spi.CR1.modify(.{ .CSTART = 1 });

        const txdr_ptr: *volatile u8 = @ptrCast(&self.spi.TXDR);
        for (data) |byte| {
            while (self.spi.SR.read().TXP == 0) {}
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
            if (clock.get_tick() - start_ms > timeout_ms) {
                return error.Timeout;
            }
        }
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
        cache.clean_dcache_by_addr(@intFromPtr(data.ptr), data.len);

        // Set busy flag and callback
        self.dma_busy = true;
        self.transfer_state = .busy_tx;
        self.user_callback = callback;
        self.user_context = context;

        // Disable SPI before config (HAL pattern)
        self.spi.CR1.modify(.{ .SPE = 0 });

        // Clear all interrupt enables and flags
        self.spi.IER.raw = 0;
        self.spi.IFCR.raw = 0x1FF;

        // Set TX-only mode
        self.spi.CFG2.modify(.{ .COMM = 0b01 });

        // Set transfer size
        self.spi.CR2.modify(.{ .TSIZE = @as(u16, @intCast(data.len)) });

        // Setup DMA
        var handlers = self.dma_channel.handlers();
        handlers.complete = dma_tx_complete;
        handlers.ctx = self;

        try self.dma_channel.setup_transfer(
            self.dma_tx_target(),
            data,
            .{
                .enable = true,
                .mode = .normal,
                .priority = .VeryHigh,
                .fifo_mode = 0,
                .size = null,
            },
        );

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

    pub fn dma_tx_target(self: *const SPI_Device) dma.DMA_WriteTarget {
        const dreq = switch (self.peripheral) {
            .SPI1 => dma_utils.DmaRequest.SPI1_TX,
            .SPI2 => dma_utils.DmaRequest.SPI2_TX,
            .SPI3 => dma_utils.DmaRequest.SPI3_TX,
            .SPI4 => dma_utils.DmaRequest.SPI4_TX,
            .SPI5 => dma_utils.DmaRequest.SPI5_TX,
            .SPI6 => dma_utils.DmaRequest.SPI5_TX,
        };

        return .{
            .dreq = dreq,
            .addr = @intFromPtr(&self.spi.TXDR),
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
            .DPXPIE = 0,
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
    const sclk = comptime gpio.Pin.init(pin_cfg.sclk.port, pin_cfg.sclk.pin, .{
        .mode = .{ .alternate = @enumFromInt(pin_cfg.sclk.af) },
        .speed = .VeryHighSpeed,
    });
    sclk.configure();

    if (config.direction != .TxOnly) {
        const miso = comptime gpio.Pin.init(pin_cfg.miso.port, pin_cfg.miso.pin, .{
            .mode = .{ .alternate = @enumFromInt(pin_cfg.miso.af) },
            .speed = .VeryHighSpeed,
        });
        miso.configure();
    }

    if (config.direction != .RxOnly) {
        const mosi = comptime gpio.Pin.init(pin_cfg.mosi.port, pin_cfg.mosi.pin, .{
            .mode = .{ .alternate = @enumFromInt(pin_cfg.mosi.af) },
            .speed = .VeryHighSpeed,
        });
        mosi.configure();
    }

    if (config.chip_select == .HardwareOutput) {
        const nss = comptime gpio.Pin.init(pin_cfg.nss.port, pin_cfg.nss.pin, .{
            .mode = .{ .alternate = @enumFromInt(pin_cfg.nss.af) },
            .speed = .VeryHighSpeed,
        });
        nss.configure();
    }
}

pub const daisy_pin_configs = struct {
    pub const SPI1 = PinConfig{
        .sclk = .{ .port = "G", .pin = "11", .af = 5 },
        .mosi = .{ .port = "B", .pin = "5", .af = 5 },
        .miso = .{ .port = "B", .pin = "4", .af = 5 },
        .nss = .{ .port = "G", .pin = "10", .af = 0 },
    };

    pub const SPI2 = PinConfig{
        .sclk = .{ .port = "B", .pin = "13", .af = 5 },
        .miso = .{ .port = "B", .pin = "14", .af = 5 },
        .mosi = .{ .port = "B", .pin = "15", .af = 5 },
        .nss = .{ .port = "B", .pin = "12", .af = 5 },
    };

    pub const SPI3 = PinConfig{
        .sclk = .{ .port = "C", .pin = "10", .af = 6 },
        .miso = .{ .port = "C", .pin = "11", .af = 6 },
        .mosi = .{ .port = "C", .pin = "12", .af = 6 },
        .nss = .{ .port = "A", .pin = "15", .af = 6 },
    };

    pub const SPI4 = PinConfig{
        .sclk = .{ .port = "E", .pin = "12", .af = 5 },
        .miso = .{ .port = "E", .pin = "13", .af = 5 },
        .mosi = .{ .port = "E", .pin = "14", .af = 5 },
        .nss = .{ .port = "E", .pin = "11", .af = 5 },
    };

    pub const SPI5 = PinConfig{
        .sclk = .{ .port = "F", .pin = "7", .af = 5 },
        .miso = .{ .port = "F", .pin = "8", .af = 5 },
        .mosi = .{ .port = "F", .pin = "9", .af = 5 },
        .nss = .{ .port = "F", .pin = "6", .af = 5 },
    };

    pub const SPI6 = PinConfig{
        .sclk = .{ .port = "G", .pin = "13", .af = 5 },
        .miso = .{ .port = "G", .pin = "12", .af = 5 },
        .mosi = .{ .port = "G", .pin = "14", .af = 5 },
        .nss = .{ .port = "G", .pin = "8", .af = 5 },
    };
};
