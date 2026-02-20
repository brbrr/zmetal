const std = @import("std");
const math = std.math;
const microzig = @import("microzig");
const hal = @import("hal.zig");
const daisy = @import("daisy.zig");
const regs = microzig.chip.peripherals;
const cpu = microzig.cpu;
const Channel = hal.dma.Channel;

// ============================================================================
// Configuration Types
// ============================================================================

pub const SampleRate = enum(u32) {
    @"8khz" = 8000,
    @"16khz" = 16000,
    @"32khz" = 32000,
    @"48khz" = 48000,
    @"96khz" = 96000,
};

pub const BitDepth = enum(u8) {
    @"16bit" = 16,
    @"24bit" = 24,
    @"32bit" = 32,
};

pub const Direction = enum {
    transmit,
    receive,
};

pub const SyncMode = enum {
    master,
    slave,
};

pub const SaiConfig = struct {
    sample_rate: SampleRate = .@"48khz",
    bit_depth: BitDepth = .@"24bit",
    a_sync: SyncMode = .master,
    b_sync: SyncMode = .slave,
    a_dir: Direction = .transmit,
    b_dir: Direction = .receive,
    blocksize: u16 = 48,

    fn getSaiRegFlags(self: SaiConfig) struct { frame_length: u7, data_size: u3, f_pol: u1, f_off: u1 } {
        const frame_length: u7 = switch (self.bit_depth) {
            .@"16bit" => 32, // 16 bits * 2 channels
            .@"24bit" => 64, // 32 bits * 2 channels (24-bit in 32-bit frame)
            .@"32bit" => 64, // 32 bits * 2 channels
        };

        const data_size: u3 = switch (self.bit_depth) {
            .@"16bit" => 4,
            .@"24bit" => 6,
            .@"32bit" => 7,
        };

        const protocol: u1 = switch (self.bit_depth) {
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

        return .{
            .frame_length = frame_length,
            .data_size = data_size,
            .f_pol = f_pol,
            .f_off = f_off,
        };
    }
};

pub const AudioCallback = fn (input: []const f32, output: []f32, size: u16) void;

const buf_size = 200;
const S = struct {
    var f_in: [buf_size]f32 = undefined;
    var f_out: [buf_size]f32 = undefined;
};

// ============================================================================
// DMA Channels (fixed for SAI1: Stream0=TX, Stream1=RX)
// ============================================================================

pub const tx_chan = hal.dma.channel(0);
pub const rx_chan = hal.dma.channel(1);

pub fn dma1_0_handler() callconv(.c) void {
    hal.dma.dma_irq_handler(tx_chan);
}

pub fn dma1_1_handler() callconv(.c) void {
    hal.dma.dma_irq_handler(rx_chan);
}

// ============================================================================
// Buffers (placed in DMA-safe non-cacheable SRAM1)
// ============================================================================

const BufferSize: u32 = 1024;
var tx_buffer: [BufferSize]u32 linksection(".sram1_bss") = undefined;
var rx_buffer: [BufferSize]u32 linksection(".sram1_bss") = undefined;

// ============================================================================
// GPIO Pin Configuration (match libdaisy: AF6, PushPull, MediumSpeed, PullUp)
// ============================================================================

const sai_p_cfg: hal.gpio.PinConfig = .{
    .mode = .{ .alternate = .af6 },
    .otype = .PushPull,
    .speed = .VeryHighSpeed,
    .pull = .PullUp,
};

const mclk = hal.gpio.Pin.init("E", "2", sai_p_cfg);
const sb = hal.gpio.Pin.init("E", "3", sai_p_cfg);
const fs = hal.gpio.Pin.init("E", "4", sai_p_cfg);
const sck = hal.gpio.Pin.init("E", "5", sai_p_cfg);
const sa = hal.gpio.Pin.init("E", "6", sai_p_cfg);
const codec_reset = hal.gpio.Pin.init("B", "11", .{
    .mode = .output,
    .pull = .Floating,
    .otype = .PushPull,
    .speed = .LowSpeed,
});

// ============================================================================
// SAI Driver
// ============================================================================

pub const SaiDriver = struct {
    const Self = @This();

    config: SaiConfig,
    transfer_size: u16 = 0,
    user_callback: ?*const AudioCallback = null,

    // ------------------------------------------------------------------
    // Public API
    // ------------------------------------------------------------------

    /// Create and initialize the SAI peripheral.
    /// Configures clocks, pins, codec, and SAI register blocks.
    /// Does NOT start audio — call start() for that.
    pub fn init(config: SaiConfig) Self {
        var self = Self{ .config = config };

        // Enable SAI1 clock
        hal.rcc.enable_clock(.SAI1);

        // Configure GPIO pins
        mclk.configure();
        fs.configure();
        sck.configure();
        sa.configure();
        sb.configure();
        codec_reset.configure();

        // Disable SAI blocks before configuration
        disableSai();

        // Reset codec (AK4556)
        resetCodec();

        tx_chan.claim() catch unreachable;
        rx_chan.claim() catch unreachable;

        self.transfer_size = self.config.blocksize * 2 * 2; // blocksize * 2 channels * 2 halves

        @memset(&tx_buffer, 0);
        @memset(&rx_buffer, 0);
        // Configure SAI register blocks
        self.initSaiBlocks();

        return self;
    }

    /// Start DMA audio streaming with the given callback.
    /// Follows libdaisy's start sequence: slave (RX) first, then master (TX).
    pub fn start(self: *Self, callback: *const AudioCallback) !void {
        self.user_callback = callback;

        // Pre-fill TX buffer with silence
        // self.fillTxBuffer(0);

        const rx_hdl = rx_chan.handlers();
        rx_hdl.complete = rx_dma_complete;
        rx_hdl.half_complete = rx_dma_half_complete;
        rx_hdl.ctx = @ptrCast(self);

        // ----- START SLAVE (Block B / RX) -----
        var rx_regs = rx_chan.get_regs();
        rx_regs.CR.modify_one("EN", 0);
        while (rx_regs.CR.read().EN != 0) microzig.cpu.nop();

        rx_regs.NDTR.modify_one("NDT", self.transfer_size);
        rx_regs.CR.modify_one("EN", 1);
        // Enable DMA request on Block B
        regs.SAI1.SAI_BCR1.modify(.{ .DMAEN = 1 });

        // Enable Block B (slave — waits for master clock before actually receiving)
        regs.SAI1.SAI_BCR1.modify(.{ .SAIXEN = 1 });

        // ----- START MASTER (Block A / TX) -----
        var tx_regs = tx_chan.get_regs();
        tx_regs.CR.modify_one("EN", 0);
        while (tx_regs.CR.read().EN != 0) microzig.cpu.nop();
        tx_regs.NDTR.modify_one("NDT", self.transfer_size);
        tx_regs.CR.modify_one("EN", 1);

        // Enable DMA request on Block A
        regs.SAI1.SAI_ACR1.modify(.{ .DMAEN = 1 });

        // Wait for TX FIFO to have data (DMA fills it from tx_buffer)
        var timeout: u32 = hal.clock.SystemCoreClock / 1000;
        while (regs.SAI1.SAI_ASR.read().FLVL == 0) {
            if (timeout == 0) return error.Timeout;
            timeout -= 1;
        }
        // Enable Block A (master — starts clocking, slave syncs)
        regs.SAI1.SAI_ACR1.modify(.{ .SAIXEN = 1 });

        cpu.dsb();
        cpu.isb();
    }

    /// Stop audio streaming. Disables SAI and DMA.
    pub fn stop(self: *Self) void {
        _ = self;

        // Disable SAI error interrupts
        regs.SAI1.SAI_AIM.raw = 0;
        regs.SAI1.SAI_BIM.raw = 0;

        // Disable DMA requests
        regs.SAI1.SAI_ACR1.modify(.{ .DMAEN = 0 });
        regs.SAI1.SAI_BCR1.modify(.{ .DMAEN = 0 });

        // Disable SAI blocks
        disableSai();

        // Release DMA channels
        tx_chan.unclaim();
        rx_chan.unclaim();
    }

    // ------------------------------------------------------------------
    // SAI1 Error Interrupt Handler
    // ------------------------------------------------------------------

    pub fn sai1_irq_handler() callconv(.c) void {
        // Block A (master TX) errors
        const a_sr = regs.SAI1.SAI_ASR.read();
        const a_im = regs.SAI1.SAI_AIM.read();

        if (a_sr.OVRUDR == 1 and a_im.OVRUDRIE == 1) {
            regs.SAI1.SAI_ACLRFR.modify(.{ .COVRUDR = 1 });
        }
        if (a_sr.WCKCFG == 1 and a_im.WCKCFGIE == 1) {
            regs.SAI1.SAI_ACLRFR.modify(.{ .CWCKCFG = 1 });
        }

        // Block B (slave RX) errors
        const b_sr = regs.SAI1.SAI_BSR.read();
        const b_im = regs.SAI1.SAI_BIM.read();

        if (b_sr.OVRUDR == 1 and b_im.OVRUDRIE == 1) {
            regs.SAI1.SAI_BCLRFR.modify(.{ .COVRUDR = 1 });
        }
        if (b_sr.AFSDET == 1 and b_im.AFSDETIE == 1) {
            regs.SAI1.SAI_BCLRFR.modify(.{ .CAFSDET = 1 });
        }
        if (b_sr.LFSDET == 1 and b_im.LFSDETIE == 1) {
            regs.SAI1.SAI_BCLRFR.modify(.{ .CLFSDET = 1 });
        }
    }

    // ------------------------------------------------------------------
    // DMA Targets
    // ------------------------------------------------------------------

    pub fn txTarget(self: Self) hal.dma.DMA_WriteTarget {
        return .{
            .dreq = if (self.config.a_dir == .transmit) .SAI1_A else .SAI1_B,
            .addr = if (self.config.a_dir == .transmit) @intFromPtr(&regs.SAI1.SAI_ADR) else @intFromPtr(&regs.SAI1.SAI_BDR),
        };
    }

    pub fn rxTarget(self: Self) hal.dma.DMA_ReadTarget {
        return .{
            .dreq = if (self.config.a_dir == .receive) .SAI1_A else .SAI1_B,
            .addr = if (self.config.a_dir == .receive) @intFromPtr(&regs.SAI1.SAI_ADR) else @intFromPtr(&regs.SAI1.SAI_BDR),
        };
    }

    // ------------------------------------------------------------------
    // SAI Block Configuration
    // ------------------------------------------------------------------

    fn initSaiBlocks(self: *Self) void {
        const data = self.config.getSaiRegFlags();
        const mck_div = computeMckDiv(daisy.clock_outputs.SAI1output, @intFromEnum(self.config.sample_rate), data.frame_length, false, false);

        regs.SAI1.SAI_GCR.raw = 0;

        // ---- Block A: Master Transmitter ----
        regs.SAI1.SAI_ACR1.raw = 0;
        regs.SAI1.SAI_ACR1.modify(.{
            .MODE = 0, // Master transmitter
            .PRTCFG = 0, // Free protocol
            .DS = data.data_size,
            .LSBFIRST = 0, // MSB first
            .CKSTR = 1, // Clock strobing on falling edge
            .SYNCEN = 0, // Asynchronous (master generates clocks)
            .MONO = 0, // Stereo
            .OUTDRIV = 0, // Output drive disabled
            .NOMCK = 0, // Master clock divider enabled
            .MCKDIV = mck_div,
        });

        regs.SAI1.SAI_ACR2.raw = 0;
        // NOTE: libdaisy don't do that
        // regs.SAI1.SAI_ACR2.modify(.{
        //     .FTH = 0, // FIFO threshold = 1/4
        //     .FFLUSH = 1, // Flush FIFO
        //     .TRIS = 0, // No high-Z state
        //     .MUTE = 0, // No mute
        //     .MUTEVAL = 0,
        //     .MUTECNT = 0,
        //     .CPL = 0, // No complement
        //     .COMP = 0b00, // No companding
        // });

        regs.SAI1.SAI_AFRCR.raw = 0;
        regs.SAI1.SAI_AFRCR.modify(.{
            .FRL = data.frame_length - 1, // Frame length
            .FSALL = data.frame_length / 2 - 1, // Frame sync length
            .FSPOL = data.f_pol,
            .FSOFF = data.f_off,
            .FSDEF = 1, // FS = channel identification
        });

        regs.SAI1.SAI_ASLOTR.raw = 0;
        regs.SAI1.SAI_ASLOTR.modify(.{
            .FBOFF = 0, // First bit offset
            .SLOTSZ = 0b10, // 32-bit slot size
            .NBSLOT = 1, // 2 slots - 1
            .SLOTEN = 0xffff, // Enable all
        });

        try rx_chan.setup_transfer(&rx_buffer, self.rxTarget(), .{
            .enable = true,
            .mode = .circular,
            .priority = .High,
            .fifo_mode = 0,
            .size = self.transfer_size,
        });

        // Enable SAI error interrupts for slave
        regs.SAI1.SAI_BIM.modify(.{
            .OVRUDRIE = 1,
            .WCKCFGIE = 1,
            .CNRDYIE = 1,
            .AFSDETIE = 1,
            .LFSDETIE = 1,
        });

        // ---- Block B: Slave Receiver ----
        regs.SAI1.SAI_BCR1.raw = 0;
        regs.SAI1.SAI_BCR1.modify(.{
            .MODE = 3, // Slave receiver
            .PRTCFG = 0, // Free protocol
            .DS = data.data_size,
            .LSBFIRST = 0, // MSB first
            .CKSTR = 1, // Clock strobing on rising edge
            .SYNCEN = 1, // Synchronous with other sub-block (Block A)
            .MONO = 0, // Stereo
            .OUTDRIV = 0, // Output drive disabled
            .NOMCK = 0,
            .MCKDIV = mck_div, // Slave ignores MCKDIV
        });

        regs.SAI1.SAI_BCR2.raw = 0;
        // NOTE: libdaisy doesn't do that
        // regs.SAI1.SAI_BCR2.modify(.{
        //     .FTH = 0, // FIFO threshold
        //     .FFLUSH = 1, // Flush FIFO
        //     .TRIS = 0, // No high-Z state
        //     .MUTE = 0, // No mute
        //     .MUTEVAL = 0,
        //     .MUTECNT = 0,
        //     .CPL = 0, // No complement
        //     .COMP = 0b00, // No companding
        // });

        regs.SAI1.SAI_BFRCR.raw = 0;
        regs.SAI1.SAI_BFRCR.modify(.{
            .FRL = data.frame_length - 1, // Frame length
            .FSALL = data.frame_length / 2 - 1, // Frame sync length
            .FSPOL = data.f_pol,
            .FSOFF = data.f_off,
            .FSDEF = 1, // FS = channel identification
        });

        regs.SAI1.SAI_BSLOTR.raw = 0;
        regs.SAI1.SAI_BSLOTR.modify(.{
            .FBOFF = 0, // First bit offset
            .SLOTSZ = 0b10, // 32-bit slot size
            .NBSLOT = 1, // 2 slots - 1
            .SLOTEN = 0xffff, // Enable all
        });

        // Disable PDM
        regs.SAI1.SAI_PDMCR.raw = 0;

        try tx_chan.setup_transfer(self.txTarget(), &tx_buffer, .{
            .enable = true,
            .mode = .circular,
            .priority = .High,
            .fifo_mode = 0,
            .size = self.transfer_size,
        });

        // Enable SAI error interrupts for master
        regs.SAI1.SAI_AIM.modify(.{
            .OVRUDRIE = 1,
            .WCKCFGIE = 1,
            .CNRDYIE = 1,
            .AFSDETIE = 1,
            .LFSDETIE = 1,
        });

        cpu.dsb();
        cpu.isb();
    }

    // ------------------------------------------------------------------
    // Codec Reset (AK4556)
    // ------------------------------------------------------------------

    fn resetCodec() void {
        regs.GPIOB.BSRR.write_raw(1 << 11); // Set B11 high
        hal.clock.delay_ms(1);
        regs.GPIOB.BSRR.write_raw(1 << (11 + 16)); // Reset B11 low
        hal.clock.delay_ms(1);
        regs.GPIOB.BSRR.write_raw(1 << 11); // Set B11 high
    }

    // ------------------------------------------------------------------
    // SAI Enable/Disable
    // ------------------------------------------------------------------

    fn disableSai() void {
        regs.SAI1.SAI_ACR1.modify(.{ .SAIXEN = 0 });
        while (regs.SAI1.SAI_ACR1.read().SAIXEN != 0) cpu.nop();
        regs.SAI1.SAI_BCR1.modify(.{ .SAIXEN = 0 });
        while (regs.SAI1.SAI_BCR1.read().SAIXEN != 0) cpu.nop();
    }

    // ------------------------------------------------------------------
    // DMA Callbacks (driven by RX DMA half/complete interrupts)
    // ------------------------------------------------------------------

    fn rx_dma_complete(chan: Channel, ctx: *anyopaque) void {
        _ = chan;
        const self: *SaiDriver = @ptrCast(@alignCast(ctx));
        self.fillTxBuffer(self.transfer_size / 2);
    }

    fn rx_dma_half_complete(chan: Channel, ctx: *anyopaque) void {
        _ = chan;
        const self: *SaiDriver = @ptrCast(@alignCast(ctx));
        self.fillTxBuffer(0);
    }

    // ------------------------------------------------------------------
    // Audio Processing
    // ------------------------------------------------------------------

    fn fillTxBuffer(self: *Self, offset: u32) void {
        const half_size = self.transfer_size / 2;
        std.debug.assert(half_size <= buf_size);

        // Convert SAI input to floats
        switch (self.config.bit_depth) {
            .@"24bit" => {
                for (0..half_size) |i| {
                    S.f_in[i] = s24tof(rx_buffer[offset + i]);
                }
            },
            else => unreachable,
        }

        if (self.user_callback) |cb| {
            cb(S.f_in[0..half_size], S.f_out[0..half_size], @intCast(half_size));
        }

        // Convert floats back to SAI output
        switch (self.config.bit_depth) {
            .@"24bit" => {
                for (0..half_size) |i| {
                    tx_buffer[offset + i] = fto24(S.f_out[i]);
                }
            },
            else => unreachable,
        }
    }

    // ------------------------------------------------------------------
    // Clock Divider Calculation
    // ------------------------------------------------------------------

    /// Compute MCKDIV matching the C HAL formula with *10 rounding precision.
    /// Reference: stm32h7xx_hal_sai.c lines 614-660
    pub fn computeMckDiv(
        sai_ck: u32,
        audio_freq: u32,
        frame_length: u32,
        no_divider: bool,
        oversampling: bool,
    ) u4 {
        var tmpval: u32 = undefined;

        if (no_divider) {
            // NODIV = 1: MCKDIV = SAI_CK / (FS * FRL)
            tmpval = (sai_ck * 10) / (audio_freq * frame_length);
        } else {
            // NODIV = 0: MCKDIV = SAI_CK / (FS * (OSR+1) * 256)
            const osr: u32 = if (oversampling) 2 else 1;
            tmpval = (sai_ck * 10) / (audio_freq * osr * 256);
        }

        var mckdiv: u32 = tmpval / 10;
        if ((tmpval % 10) > 8) {
            mckdiv += 1;
        }
        return @intCast(mckdiv);
    }
};

// ============================================================================
// Sample Format Conversion (24-bit signed integer ↔ float)
// ============================================================================

/// Convert float [-1.0, 1.0] to 24-bit signed integer (as u32)
pub fn fto24(sample: f32) u32 {
    const FBIPMAX: f32 = 0.999985;
    const FBIPMIN: f32 = -FBIPMAX;
    const F2S24_SCALE: f32 = 8388608.0; // 2^23

    const clamped = math.clamp(sample, FBIPMIN, FBIPMAX);
    const scaled: f64 = clamped * F2S24_SCALE;
    const as_i32 = @as(i32, @intFromFloat(scaled));
    return @as(u32, @bitCast(as_i32));
}

/// Convert 24-bit signed integer (as u32) to float [-1.0, 1.0]
pub fn s24tof(xx: u32) f32 {
    const S242F_SCALE: f32 = 1.192092896e-07; // 1 / 2^23
    const as_i32 = @as(i32, @bitCast(xx));
    const sign_extended = as_i32 << 8 >> 8; // Sign-extend from 24-bit
    return @as(f32, @floatFromInt(sign_extended)) * S242F_SCALE;
}
