const std = @import("std");
const microzig = @import("microzig");
const hal = @import("hal.zig");
const daisy = @import("daisy.zig");
const regs = microzig.chip.peripherals;
const cpu = microzig.cpu;
const Channel = hal.dma.Channel;

// SAI Configuration Types
const SampleRate = enum(u32) {
    @"8khz" = 8000,
    @"16khz" = 16000,
    @"32khz" = 32000,
    @"48khz" = 48000,
    @"96khz" = 96000,
};

const BitDepth = enum(u8) {
    @"16bit" = 16,
    @"24bit" = 24,
    @"32bit" = 32,
};

const Direction = enum {
    transmit,
    receive,
};

const SyncMode = enum {
    master,
    slave,
};

const SaiConfig = struct {
    sample_rate: SampleRate = .@"48khz",
    bit_depth: BitDepth = .@"24bit",
    a_sync: SyncMode = .master,
    b_sync: SyncMode = .slave,
    a_dir: Direction = .transmit,
    b_dir: Direction = .receive,
};

pub const tx_chan = hal.dma.channel(0);
pub const rx_chan = hal.dma.channel(1);

pub fn dma1_0_handler() callconv(.c) void {
    hal.dma.dma_irq_handler(tx_chan);
}

pub fn dma1_1_handler() callconv(.c) void {
    hal.dma.dma_irq_handler(rx_chan);
}

pub const AudioCallback = fn (input: []const u32, output: []u32) void;

const BufferSize: u32 = 1024;
var tx_buffer: [BufferSize]u32 align(32) linksection(".sram1_bss") = undefined;
var rx_buffer: [BufferSize]u32 align(32) linksection(".sram1_bss") = undefined;

const sai_p_cfg: hal.gpio.PinConfig = .{
    .mode = .{ .alternate = .af6 },
    .otype = .PushPull,
    .speed = .HighSpeed,
    .pull = .Floating,
};
const mclk = hal.gpio.Pin.init("E", "2", sai_p_cfg);
const sb = hal.gpio.Pin.init("E", "3", sai_p_cfg);
const fs = hal.gpio.Pin.init("E", "4", sai_p_cfg);
const sck = hal.gpio.Pin.init("E", "5", sai_p_cfg);
const sa = hal.gpio.Pin.init("E", "6", sai_p_cfg);
const codec_reset = hal.gpio.Pin.init("B", "11", .{ .mode = .output, .pull = .Floating, .otype = .PushPull, .speed = .LowSpeed });

pub const SaiDriver = struct {
    config: SaiConfig,
    initialized: bool = false,
    transfer_size: u32 = 0,

    // Set by user
    user_callback: ?*const AudioCallback = null,

    const Self = @This();

    pub fn init(config: SaiConfig) Self {
        return Self{
            .config = config,
        };
    }

    pub fn setup(self: *Self) !void {
        // Enable clocks
        self.initPins();
        self.disable();
        try self.initCodec();
        regs.RCC.APB2ENR.modify(.{ .SAI1EN = 1 });
        try self.initSaiBlocks();
        self.initialized = true;
    }

    pub fn initPins(self: *Self) void {
        _ = self;
        fs.configure();
        mclk.configure();
        sck.configure();
        sa.configure();
        sb.configure();
        codec_reset.configure();
    }

    pub fn tx(self: Self) hal.dma.DMA_WriteTarget {
        return .{
            .dreq = if (self.config.a_dir == .transmit) .SAI1_A else .SAI1_B,
            .addr = if (self.config.a_dir == .transmit) @intFromPtr(&regs.SAI1.SAI_ADR) else @intFromPtr(&regs.SAI1.SAI_BDR),
        };
    }

    pub fn rx(self: Self) hal.dma.DMA_ReadTarget {
        return .{
            .dreq = if (self.config.a_dir == .receive) .SAI1_A else .SAI1_B,
            .addr = if (self.config.a_dir == .receive) @intFromPtr(&regs.SAI1.SAI_ADR) else @intFromPtr(&regs.SAI1.SAI_BDR),
        };
    }

    fn initSaiBlocks(self: *Self) !void {
        const frame_length: u7 = switch (self.config.bit_depth) {
            .@"16bit" => 32, // 16 bits * 2 channels
            .@"24bit" => 64, // 32 bits * 2 channels (24-bit in 32-bit frame)
            .@"32bit" => 64, // 32 bits * 2 channels
        };

        const data_size: u3 = switch (self.config.bit_depth) {
            .@"16bit" => 4,
            .@"24bit" => 6,
            .@"32bit" => 7,
        };

        const protocol: u1 = switch (self.config.bit_depth) {
            .@"16bit" => 0,
            .@"24bit" => 1, // Change to 0 for I2S
            .@"32bit" => 0,
        };
        var f_pol: u1 = 0; // SAI_FS_ACTIVE_LOW
        var f_off: u1 = 1; // SAI_FS_BEFOREFIRSTBIT

        if (protocol == 1) { // Not SAI_I2S_STANDARD
            f_pol = 1; // SAI_FS_ACTIVE_HIGH
            f_off = 0; // SAI_FS_FIRSTBIT
        }

        regs.SAI1.SAI_GCR.raw = 0;

        const clocks = hal.rcc.getPLL3Clocks();
        _ = clocks;

        const mck_div = SaiDriver.computeMckDiv(daisy.clock_outputs.SAI1output, @intFromEnum(self.config.sample_rate), frame_length, false, false);

        // Configure SAI1 Block A (Master Transmitter)
        regs.SAI1.SAI_ACR1.raw = 0;
        regs.SAI1.SAI_ACR1.modify(.{
            .MODE = 0, // Master transmitter
            .PRTCFG = 0, // Free protocol
            .DS = data_size,
            .LSBFIRST = 0, // MSB first
            .CKSTR = 1, // Clock strobing on falling edge
            .SYNCEN = 0, // Asynchronous
            .MONO = 0, // Stereo
            .OUTDRIV = 0, // Output drive disable
            .NOMCK = 0,
            .MCKDIV = mck_div,
        });

        regs.SAI1.SAI_ACR2.raw = 0;
        regs.SAI1.SAI_ACR2.modify(.{
            .FTH = 0, // FIFO threshold = 1/4
            .FFLUSH = 1, // Flush FIFO
            .TRIS = 0, // No high-Z state
            .MUTE = 0, // No mute
            .MUTEVAL = 0,
            .MUTECNT = 0,
            .CPL = 0, // No complement
            .COMP = 0b00, // No companding
        });

        regs.SAI1.SAI_AFRCR.raw = 0;
        regs.SAI1.SAI_AFRCR.modify(.{
            .FRL = frame_length - 1, // Frame length
            .FSALL = frame_length / 2 - 1, // Frame sync length
            .FSPOL = f_pol,
            .FSOFF = f_off,
            .FSDEF = 1, // FS = channel start indicator, not "active all frame"
        });

        // regs.SAI1.SAI_ASLOTR.raw = 0;
        regs.SAI1.SAI_ASLOTR.modify(.{
            .FBOFF = 0, // First bit offset
            .SLOTSZ = 0b10, // 32-bit slot size for 24-bit data
            .NBSLOT = 1, // 2 slots - 1
            .SLOTEN = 65535, // Enable all
        });

        // Configure SAI1 Block B (Slave Receiver)
        regs.SAI1.SAI_BCR1.modify(.{
            .MODE = 3, // Slave receiver
            .PRTCFG = 0, // Free protocol
            .DS = data_size,
            .LSBFIRST = 0, // MSB first
            .CKSTR = 1, // Clock strobing on rising edge
            .SYNCEN = 1, // Synchronous with other sub-block
            .MONO = 0, // Stereo
            .OUTDRIV = 0, // Output drive disabled (slave)
            .NOMCK = 0,
            .MCKDIV = mck_div,
        });

        regs.SAI1.SAI_BCR2.modify(.{
            .FTH = 0, // FIFO threshold = 1/4
            .FFLUSH = 1, // Flush FIFO
            .TRIS = 0, // No high-Z state
            .MUTE = 0, // No mute
            .MUTEVAL = 0,
            .MUTECNT = 0,
            .CPL = 0, // No complement
            .COMP = 0b00, // No companding
        });

        regs.SAI1.SAI_BFRCR.raw = 0;
        regs.SAI1.SAI_BFRCR.modify(.{
            .FRL = frame_length - 1, // Frame length
            .FSALL = frame_length / 2 - 1, // Frame sync length
            .FSPOL = f_pol,
            .FSOFF = f_off,
            .FSDEF = 1, // FS = channel start indicator, not "active all frame"
        });

        regs.SAI1.SAI_BSLOTR.modify(.{
            .FBOFF = 0, // First bit offset
            .SLOTSZ = 0b10, // 32-bit slot size for 24-bit data
            .NBSLOT = 1, // 2 slots - 1
            .SLOTEN = 65535, // Enable all
            // .SLOTEN = 2, // Enable all
        });

        regs.SAI1.SAI_PDMCR.raw = 0;

        cpu.dsb();
        cpu.isb();
    }

    fn initCodec(self: *Self) !void {
        _ = self;

        // AK4556 reset sequence
        // Set reset high
        // hal.clock.delay(100);
        regs.GPIOB.BSRR.write_raw(1 << 11);
        hal.clock.delay(1);
        regs.GPIOB.BSRR.write_raw(1 << (11 + 16));
        hal.clock.delay(1);
        regs.GPIOB.BSRR.write_raw(1 << 11);
        //
        // hal.clock.delay(100);
    }

    pub fn enable(self: *Self) !void {
        if (!self.initialized) return error.NotInitialized;

        // Enable SAI blocks (B first for slave, then A for master)
        regs.SAI1.SAI_BCR1.modify(.{ .SAIXEN = 1 });
        hal.clock.delay(100);
        regs.SAI1.SAI_ACR1.modify(.{ .SAIXEN = 1 });
        hal.clock.delay(100);
    }

    pub fn disable(self: *Self) void {
        _ = self;
        // Disable SAI blocks
        regs.SAI1.SAI_ACR1.modify_one("SAIXEN", 0);
        while (regs.SAI1.SAI_ACR1.read().SAIXEN != 0) microzig.cpu.nop();
        regs.SAI1.SAI_BCR1.modify_one("SAIXEN", 0);
        while (regs.SAI1.SAI_BCR1.read().SAIXEN != 0) microzig.cpu.nop();
    }

    pub fn startAudio(self: *Self, cb: *const AudioCallback) !void {
        try tx_chan.claim();
        try rx_chan.claim();
        for (&tx_buffer) |*x| x.* = 0;
        for (&rx_buffer) |*x| x.* = 0;

        const blocksize = 48;
        self.transfer_size = blocksize * 2 * 2;
        self.user_callback = cb;

        // Fill initial TX buffer with first audio data
        self.fillTxBuffer(0); // Fill first half
        self.fillTxBuffer(self.transfer_size / 2); // Fill second half

        // TX
        {
            // Configure DMA for TX (memory -> peripheral)
            try tx_chan.setup_transfer(
                self.tx(), // peripheral
                &tx_buffer, // memory
                // tx_buffer[0..self.transfer_size], // memory
                .{ .enable = true, .mode = .circular, .priority = .High, .fifo_mode = 0, .size = self.transfer_size },
            );
            regs.SAI1.SAI_ACR1.modify_one("DMAEN", 1);
            hal.clock.delay(100);
            while (regs.SAI1.SAI_ASR.read().FLVL == 0) { // SAI_FIFOSTATUS_EMPTY
                microzig.cpu.nop();
            }

            var tx_handlers = tx_chan.handlers();
            tx_handlers.complete = SaiDriver.tx_dma_complete;
            tx_handlers.half_complete = SaiDriver.tx_dma_half_complete;
            tx_handlers.ctx = self;

            // Enable SAI blocks (B first for slave, then A for master)
            regs.SAI1.SAI_ACR1.modify(.{ .SAIXEN = 1 });
            hal.clock.delay(100);
        }

        {
            // Configure DMA for RX (peripheral -> memory)
            try rx_chan.setup_transfer(
                &rx_buffer, // memory
                // rx_buffer[0..self.transfer_size], // memory
                self.rx(), // peripheral
                .{ .enable = true, .mode = .circular, .priority = .High, .fifo_mode = 0, .size = self.transfer_size },
            );

            regs.SAI1.SAI_BCR1.modify_one("DMAEN", 1);
            hal.clock.delay(100);

            // var rx_handlers = rx_chan.handlers();
            // rx_handlers.complete = SaiDriver.rx_dma_complete;
            // rx_handlers.half_complete = SaiDriver.rx_dma_complete;
            // rx_handlers.ctx = self;

            regs.SAI1.SAI_BCR1.modify(.{ .SAIXEN = 1 });
            hal.clock.delay(100);
        }

        // Enable SAI blocks
        // try self.enable();
        cpu.dsb();
        cpu.isb();
    }

    // DMA complete handlers (second half of buffer)
    pub fn tx_dma_complete(chan: Channel, ctx: *anyopaque) void {
        _ = chan;
        const self: *SaiDriver = @ptrCast(@alignCast(ctx));
        // Fill second half of buffer
        self.fillTxBuffer(self.transfer_size / 2);
    }

    // DMA half complete handlers (first half of buffer)
    pub fn tx_dma_half_complete(chan: Channel, ctx: *anyopaque) void {
        _ = chan;
        const self: *SaiDriver = @ptrCast(@alignCast(ctx));
        // Fill first half of buffer
        self.fillTxBuffer(0);
    }

    fn fillTxBuffer(self: *Self, offset: u32) void {
        const half_size = self.transfer_size / 2;
        var temp_buffer: [200]u32 = undefined;

        self.user_callback.?(rx_buffer[offset .. offset + half_size], temp_buffer[0..half_size]);
        @memcpy(tx_buffer[offset .. offset + half_size], temp_buffer[0..half_size]);
    }

    fn internal_callback(self: *SaiDriver, ch: hal.dma.Channel) void {
        // Figure out which half completed
        // DMA NDTR register halves: half-transfer (HT) vs transfer-complete (TC)
        const ndtr = ch.get_regs().NDTR.read().NDT;
        const start: u32 = if (ndtr > self.transfer_size / 2) 0 else self.transfer_size / 2;

        if (self.user_callback) |cb| {
            cb(rx_buffer[start .. start + self.transfer_size], tx_buffer[start .. start + self.transfer_size]);
        }
    }

    // Blocking transmit function
    pub fn transmitBlocking(self: *Self, data: []const u32) !void {
        if (!self.initialized) return error.NotInitialized;

        for (data) |sample| {
            // Wait for transmit FIFO to be ready
            while (regs.SAI1.SAI_ASR.read().FLVL == 0b111) {} // Wait if FIFO full

            // Write sample to data register
            regs.SAI1.SAI_ADR.write_raw(sample);
        }
    }

    // Blocking receive function
    pub fn receiveBlocking(self: *Self, buffer: []u32) !void {
        if (!self.initialized) return error.NotInitialized;

        for (buffer) |*sample| {
            // Wait for receive FIFO to have data
            while (regs.SAI1.SAI_BSR.read().FLVL == 0b000) {} // Wait if FIFO empty

            // Read sample from data register
            sample.* = regs.SAI1.SAI_BDR.read_raw();
        }
    }

    pub fn computeMckDiv(
        sai_ck: u32, // SAI input clock frequency in Hz
        audio_freq: u32, // Desired sample rate (FS)
        frame_length: u32, // Frame length in bits
        no_divider: bool,
        oversampling: bool, // Only used if no_divider == false
    ) u4 {
        var tmpval: u32 = 0;

        if (no_divider) {
            // NODIV = 1
            tmpval = sai_ck / (audio_freq * frame_length) - 1;
        } else {
            // NODIV = 0
            const osr: u32 = if (oversampling) 2 else 1;
            tmpval = (sai_ck) / (audio_freq * osr * 256);
        }

        // Divide by 10 with rounding
        var mckdiv: u32 = tmpval;
        if ((tmpval % 10) > 8) {
            mckdiv += 1;
        }
        return @intCast(mckdiv);
    }
};

const math = std.math;
/// Converts a float sample to a 24-bit signed integer packed in a u32
/// Input float should be in range [-1.0, 1.0]
pub fn fto241(sample: f32) u32 {
    const FBIPMAX: f32 = 0.999985; // close to 1.0 - LSB at 24-bit
    const FBIPMIN: f32 = -FBIPMAX;
    const F2S24_SCALE: f32 = 8388608.0; // 2^23

    // Clamp to prevent overflow
    const clamped = math.clamp(sample, FBIPMIN, FBIPMAX);

    // Scale to 24-bit signed range
    const scaled: f64 = clamped * F2S24_SCALE;

    // Convert to i32
    const as_i32 = @as(i32, @intFromFloat(scaled));

    // Bitcast to u32 to preserve two's complement representation
    return @as(u32, @bitCast(as_i32));
}

pub fn fto24(sample: f32) u32 {
    const scaled = sample * 8388607.0; // 2^23 - 1

    // Round to nearest integer
    const rounded = @round(scaled);

    // Convert to i32 first
    const as_i32 = @as(i32, @intFromFloat(rounded));

    // Cast to u32 and mask to 24 bits to ensure clean result
    const as_u32 = @as(u32, @bitCast(as_i32));

    // Mask to 24 bits (0xFFFFFF)
    return as_u32 & 0xFFFFFF;
}

pub fn monitorSaiErrors() void {
    const status = regs.SAI1.SAI_ASR.read();
    if (status.OVRUDR == 1) {
        // std.log.err("SAI Overrun/Underrun!");
        @panic("!!!");
    }
    if (status.FREQ == 1) {
        // @panic("!!!");
    }
    std.log.info("FIFO level: {d}/8", .{status.FLVL});
}
