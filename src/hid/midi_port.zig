//! Generic MIDI port: decodes/encodes MIDI 1.0 messages over any byte stream
//! presenting the uniform `read`/`write` contract (see
//! `microzig.drivers.base.StreamDevice`).
//!
//! Kept separate from `midi.zig` (the pure parser + `MessageQueue`) because
//! this file imports `microzig` for the default `Stream` type, which would
//! taint `midi.zig`'s host-testability. `midi.zig`'s tests must keep running
//! with a plain `zig test src/hid/midi.zig` (no microzig / no board).
//!
//! `MidiPort` is comptime-generic over the stream type, so instantiating it
//! with a concrete stream (e.g. `hal.usb.MidiStream`, `hal.usart.UartStream(.USART1)`)
//! is zero-cost — the compiler drops the erased `StreamDevice` vtable path
//! entirely unless it's actually used (i.e. `cfg.Stream` defaults to it).

const std = @import("std");
const midi = @import("midi.zig");

pub const Message = midi.Message;
pub const MessageKind = midi.MessageKind;

/// Resolves to `microzig.drivers.base.StreamDevice`. Wrapped in a function
/// (rather than referenced directly as `MidiPort`'s default parameter value)
/// so the `@import("microzig")` is only ever evaluated when `cfg.Stream` is
/// actually defaulted — `orelse` short-circuits at comptime. This keeps
/// `zig test src/hid/midi_port.zig` runnable on the host (no microzig module
/// registered) as long as every test passes an explicit `Stream`.
fn defaultStreamType() type {
    const microzig = @import("microzig");
    return microzig.drivers.base.StreamDevice;
}

pub fn MidiPort(comptime cfg: struct { Stream: ?type = null }) type {
    const Stream = cfg.Stream orelse defaultStreamType();
    return struct {
        const Self = @This();

        stream: Stream,
        parser: midi.Parser = midi.Parser.init(),
        rx: midi.MessageQueue = midi.MessageQueue.init(),

        pub fn init(stream: Stream) Self {
            return .{ .stream = stream };
        }

        /// Decode the next MIDI message from the stream, or null if none pending.
        pub fn poll(self: *Self) ?Message {
            if (self.rx.pop()) |m| return m;
            var buf: [64]u8 = undefined;
            const n = self.stream.read(&buf) catch return null;
            for (buf[0..n]) |b| {
                if (self.parser.feed(b)) |m| self.rx.push(m);
            }
            return self.rx.pop();
        }

        /// Serialize and send a message; returns false if the stream isn't ready.
        pub fn send(self: *Self, msg: Message) bool {
            const status: u8 = @as(u8, switch (msg.kind) {
                .note_off => 0x80,
                .note_on => 0x90,
                .poly_aftertouch => 0xA0,
                .control_change => 0xB0,
                .program_change => 0xC0,
                .channel_pressure => 0xD0,
                .pitch_bend => 0xE0,
            }) | @as(u8, msg.channel);
            const single = switch (msg.kind) {
                .program_change, .channel_pressure => true,
                else => false,
            };
            const bytes = if (single) &[_]u8{ status, msg.data1 } else &[_]u8{ status, msg.data1, msg.data2 };
            const want = bytes.len;
            const n = self.stream.write(bytes) catch return false;
            return n == want;
        }
    };
}

const expectEqual = std.testing.expectEqual;

test "MidiPort decodes note-on from a fake byte stream" {
    const Fake = struct {
        const S = @This();
        data: []const u8 = &.{ 0x90, 0x3C, 0x40 },
        pos: usize = 0,

        pub fn read(self: *S, buf: []u8) !usize {
            const n = @min(buf.len, self.data.len - self.pos);
            @memcpy(buf[0..n], self.data[self.pos..][0..n]);
            self.pos += n;
            return n;
        }
        pub fn write(_: *S, bytes: []const u8) !usize {
            return bytes.len;
        }
    };

    var fake = Fake{};
    var port = MidiPort(.{ .Stream = *Fake }).init(&fake);
    const m = port.poll().?;
    try expectEqual(MessageKind.note_on, m.kind);
    try expectEqual(@as(u8, 60), m.data1);
    try expectEqual(@as(u8, 64), m.data2);
}

test "MidiPort.send serializes a note-on and reports success" {
    const Sink = struct {
        const S = @This();
        sent: [3]u8 = undefined,
        len: usize = 0,

        pub fn read(_: *S, _: []u8) !usize {
            return 0;
        }
        pub fn write(self: *S, bytes: []const u8) !usize {
            @memcpy(self.sent[0..bytes.len], bytes);
            self.len = bytes.len;
            return bytes.len;
        }
    };

    var sink = Sink{};
    var port = MidiPort(.{ .Stream = *Sink }).init(&sink);
    const ok = port.send(.{ .kind = .note_on, .channel = 0, .data1 = 60, .data2 = 64 });
    try std.testing.expect(ok);
    try expectEqual(@as(usize, 3), sink.len);
    try expectEqual(@as(u8, 0x90), sink.sent[0]);
}
