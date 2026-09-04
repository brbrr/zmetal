//! Runtime audio format configuration — the single value that drives both the
//! SAI codec path and the USB audio class. Built once at board bring-up
//! (`daisy.init`) and threaded into the SAI (`sai.configFromAudio`) and USB
//! audio (`usb_audio.configure` / descriptor build).
//!
//! `sample_rate` and `bit_depth` are the user-facing format (typed enums, so
//! only supported values are expressible); the USB wire subslot (packed
//! bytes/sample) and the SAI slot/data-size are derived from them. These enums
//! are the canonical definitions — `sai.zig` re-exports them.
//!
//! NOTE: the TinyUSB C driver's EP/FIFO buffers are sized at compile time to a
//! max envelope (see tusb_config.h) that must cover any config chosen here;
//! `usb_audio.configure` asserts the chosen format fits.

/// Supported sample rates. Tag value is the frequency in Hz.
pub const SampleRate = enum(u32) {
    @"8khz" = 8000,
    @"16khz" = 16000,
    @"32khz" = 32000,
    @"48khz" = 48000,
    @"96khz" = 96000,
};

/// Supported bit depths. Tag value is the resolution in bits.
pub const BitDepth = enum(u8) {
    @"16bit" = 16,
    @"24bit" = 24,
    @"32bit" = 32,
};

pub const AudioConfig = struct {
    sample_rate: SampleRate = .@"48khz",
    bit_depth: BitDepth = .@"24bit",
    channels: u8 = 2, // stereo (asserted == 2 for now)
    // NOTE: currently capped by usb_audio's MAX_SAMPLES envelope (blocksize <= 48).
    blocksize: u16 = 48, // SAI frames per DMA half-buffer

    /// Sample rate in Hz.
    pub fn rateHz(self: AudioConfig) u32 {
        return @intFromEnum(self.sample_rate);
    }

    /// Resolution in bits.
    pub fn bits(self: AudioConfig) u8 {
        return @intFromEnum(self.bit_depth);
    }

    /// USB wire bytes per sample (packed): 16->2, 24->3, 32->4.
    pub fn subslot(self: AudioConfig) u8 {
        return switch (self.bit_depth) {
            .@"16bit" => 2,
            .@"24bit" => 3,
            .@"32bit" => 4,
        };
    }

    /// Bytes per interleaved frame on the USB wire.
    pub fn frameBytes(self: AudioConfig) u16 {
        return self.subslot() * self.channels;
    }

    /// Isochronous endpoint wMaxPacketSize (full-speed): one 1 ms frame of audio
    /// plus one sample of slack. `(rate/1000 + 1) * frameBytes`.
    pub fn epSize(self: AudioConfig) u16 {
        return @intCast((self.rateHz() / 1000 + 1) * self.frameBytes());
    }

    /// Interleaved samples the SAI callback delivers per block (blocksize * ch).
    pub fn samplesPerBlock(self: AudioConfig) u16 {
        return self.blocksize * self.channels;
    }
};
