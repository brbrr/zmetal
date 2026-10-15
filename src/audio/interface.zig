//! Audio interface — the real-time I/O scaffold that drives a pluggable Program.
//!
//! The engine is a pure patchbay: it reads the input buses (line-in from the
//! codec, USB-in from the host), zeroes the output buses, calls the Program's
//! `process(io)`, and pushes the output buses back out (line-out to the codec,
//! USB-out to the host). It holds NO routing policy — all routing and DSP live
//! in the Program. Generic over the Program type at comptime (zero-cost).
//!
//! Runs in the SAI DMA ISR.
const std = @import("std");
const microzig = @import("microzig");

pub const AudioIO = @import("zmetal_dsp").AudioIO;

pub const Options = struct {
    /// Route USB Audio (UAC2) in/out through the Program. Without it the USB
    /// buses are silent and TinyUSB is not referenced.
    usb: bool = false,
};

/// A Program is any type with `pub fn process(self: *Program, io: AudioIO) void`.
pub fn AudioInterface(comptime Program: type, comptime opts: Options) type {
    const usb_audio = if (opts.usb) microzig.hal.usb_audio else struct {};
    // Interleaved samples per block: the USB bridge's envelope, or the SAI
    // half-buffer (256) when USB is off.
    const MAX = if (opts.usb) usb_audio.MAX_SAMPLES else 256;

    return struct {
        const Self = @This();
        program: *Program,

        pub fn init(program: *Program) Self {
            return .{ .program = program };
        }

        /// One audio block: gather input buses -> program.process -> emit output
        /// buses. `line_in`/`line_out` are the SAI codec buffers (interleaved).
        /// Use as `seed.startAudioCtx(&iface, Iface.render)`.
        pub fn render(self: *Self, line_in: []const f32, line_out: []f32) void {
            const n: usize = line_out.len;
            std.debug.assert(n <= MAX);

            var usb_in: [MAX]f32 = @splat(0);
            if (opts.usb) _ = usb_audio.readPlayback(usb_in[0..n]); // silence when host idle

            var usb_out: [MAX]f32 = @splat(0);
            @memset(line_out[0..n], 0); // Program writes only what it routes

            self.program.process(.{
                .line_in = line_in[0..n],
                .usb_in = usb_in[0..n],
                .line_out = line_out[0..n],
                .usb_out = usb_out[0..n],
            });

            if (opts.usb) usb_audio.writeCapture(usb_out[0..n]); // no-op when host not recording
        }
    };
}
