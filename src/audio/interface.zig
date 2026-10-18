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
    // Interleaved samples per block: the SAI half-buffer.
    const MAX = 256;
    // The USB bridge moves at most this many samples a call, so a larger
    // codec block goes to and from USB in chunks of it.
    const USB_CHUNK = if (opts.usb) usb_audio.MAX_SAMPLES else MAX;

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
            // Silence when the host is idle. Each chunk is one call of the
            // playback PLL, which is tuned per 1 ms call, so a 2 ms block
            // makes two calls and the loop keeps its pace.
            if (opts.usb) {
                var at: usize = 0;
                while (at < n) : (at += USB_CHUNK) _ = usb_audio.readPlayback(usb_in[at..@min(n, at + USB_CHUNK)]);
            }

            var usb_out: [MAX]f32 = @splat(0);
            @memset(line_out[0..n], 0); // Program writes only what it routes

            self.program.process(.{
                .line_in = line_in[0..n],
                .usb_in = usb_in[0..n],
                .line_out = line_out[0..n],
                .usb_out = usb_out[0..n],
            });

            // A no-op when the host is not recording.
            if (opts.usb) {
                var at: usize = 0;
                while (at < n) : (at += USB_CHUNK) usb_audio.writeCapture(usb_out[at..@min(n, at + USB_CHUNK)]);
            }
        }
    };
}
