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

const usb_audio = microzig.hal.usb_audio;
const ssai = microzig.hal.sai;

pub const AudioIO = @import("audio_io.zig").AudioIO;

const MAX = usb_audio.MAX_SAMPLES;

/// A Program is any type with `pub fn process(self: *Program, io: AudioIO) void`.
pub fn AudioInterface(comptime Program: type) type {
    return struct {
        const Self = @This();
        program: *Program,

        pub fn init(program: *Program) Self {
            return .{ .program = program };
        }

        /// One audio block: gather input buses -> program.process -> emit output
        /// buses. `line_in`/`line_out` are the SAI codec buffers; `size` is the
        /// interleaved sample count.
        fn render(self: *Self, line_in: []const f32, line_out: []f32, size: u16) void {
            const n: usize = size;
            std.debug.assert(n <= MAX);

            var usb_in: [MAX]f32 = undefined;
            _ = usb_audio.readPlayback(usb_in[0..n]); // silence when host idle

            var usb_out: [MAX]f32 = @splat(0);
            @memset(line_out[0..n], 0); // Program writes only what it routes

            self.program.process(.{
                .line_in = line_in[0..n],
                .usb_in = usb_in[0..n],
                .line_out = line_out[0..n],
                .usb_out = usb_out[0..n],
            });

            usb_audio.writeCapture(usb_out[0..n]); // no-op when host not recording
        }

        /// Build the free-function SAI callback bound to this instance. `self`
        /// must be a comptime-known pointer — i.e. the address of a module-level
        /// instance — so the returned `fn` closes over it at zero cost.
        pub fn saiCallback(comptime self: *Self) *const ssai.AudioCallback {
            return &struct {
                fn cb(input: []const f32, output: []f32, size: u16) void {
                    self.render(input, output, size);
                }
            }.cb;
        }
    };
}
