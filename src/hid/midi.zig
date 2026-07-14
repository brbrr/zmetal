//! MIDI byte-stream parser (MIDI 1.0).
//!
//! Pure and hardware-agnostic — fed one raw byte at a time by the UART layer —
//! so it is fully host-testable. Handles channel voice messages with running
//! status, ignores System Real-Time bytes (which may interleave anywhere), and
//! skips System Exclusive payloads. System Common messages cancel running
//! status; their data bytes are harmlessly dropped (we don't emit them).

const std = @import("std");

pub const MessageKind = enum {
    note_off,
    note_on,
    poly_aftertouch,
    control_change,
    program_change,
    channel_pressure,
    pitch_bend,
};

pub const Message = struct {
    kind: MessageKind,
    channel: u4,
    /// note / cc number / program / pressure / pitch-bend LSB.
    data1: u8,
    /// velocity / cc value / pitch-bend MSB (0 for single-data messages).
    data2: u8,
};

/// Data-byte count for a channel status byte (0x80..0xEF).
fn expectedData(status: u8) u8 {
    return switch (status & 0xF0) {
        0xC0, 0xD0 => 1, // program change, channel pressure
        else => 2, // note off/on, poly aftertouch, control change, pitch bend
    };
}

fn kindOf(status: u8) MessageKind {
    return switch (status & 0xF0) {
        0x80 => .note_off,
        0x90 => .note_on,
        0xA0 => .poly_aftertouch,
        0xB0 => .control_change,
        0xC0 => .program_change,
        0xD0 => .channel_pressure,
        0xE0 => .pitch_bend,
        else => unreachable,
    };
}

pub const Parser = struct {
    /// Current running status byte (0 = none / cancelled).
    status: u8 = 0,
    data: [2]u8 = .{ 0, 0 },
    data_count: u8 = 0,
    in_sysex: bool = false,

    pub fn init() Parser {
        return .{};
    }

    /// Feed one raw MIDI byte; returns a completed `Message` or null.
    pub fn feed(self: *Parser, byte: u8) ?Message {
        // System Real-Time (0xF8..0xFF): single byte, may interleave anywhere,
        // does not affect running status or an in-progress message.
        if (byte >= 0xF8) return null;

        if (byte >= 0x80) {
            // Status byte.
            switch (byte) {
                0xF0 => { // SysEx start
                    self.in_sysex = true;
                    self.status = 0;
                },
                0xF7 => { // SysEx end
                    self.in_sysex = false;
                    self.status = 0;
                },
                0xF1...0xF6 => { // System Common: cancels running status
                    self.status = 0;
                    self.in_sysex = false;
                },
                else => { // 0x80..0xEF channel voice message
                    self.status = byte;
                    self.data_count = 0;
                },
            }
            return null;
        }

        // Data byte.
        if (self.in_sysex or self.status == 0) return null; // sysex payload / orphan
        self.data[self.data_count] = byte;
        self.data_count += 1;
        if (self.data_count < expectedData(self.status)) return null;

        self.data_count = 0; // allow running status for the next message
        return .{
            .kind = kindOf(self.status),
            .channel = @intCast(self.status & 0x0F),
            .data1 = self.data[0],
            .data2 = self.data[1],
        };
    }
};

/// Single-slot-sacrificed SPSC ring of decoded `Message`s. Pure and
/// hardware-agnostic; shared by the MIDI transports (see `midi_port.zig`) to
/// buffer messages between the decode point and the consumer.
pub const MessageQueue = struct {
    ring: [64]Message = undefined,
    head: usize = 0,
    tail: usize = 0,

    pub fn init() MessageQueue {
        return .{};
    }

    /// Enqueue a message; drops it if the queue is full.
    pub fn push(self: *MessageQueue, msg: Message) void {
        const next = (self.head + 1) % self.ring.len;
        if (next == self.tail) return; // full: drop
        self.ring[self.head] = msg;
        self.head = next;
    }

    /// Pop the next message, or null if empty.
    pub fn pop(self: *MessageQueue) ?Message {
        if (self.tail == self.head) return null;
        const msg = self.ring[self.tail];
        self.tail = (self.tail + 1) % self.ring.len;
        return msg;
    }
};

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

fn feedAll(p: *Parser, bytes: []const u8) ?Message {
    var last: ?Message = null;
    for (bytes) |b| {
        if (p.feed(b)) |m| last = m;
    }
    return last;
}

test "note on" {
    var p = Parser.init();
    const m = feedAll(&p, &.{ 0x90, 0x3C, 0x40 }).?;
    try expectEqual(MessageKind.note_on, m.kind);
    try expectEqual(@as(u4, 0), m.channel);
    try expectEqual(@as(u8, 60), m.data1);
    try expectEqual(@as(u8, 64), m.data2);
}

test "note off, non-zero channel" {
    var p = Parser.init();
    const m = feedAll(&p, &.{ 0x82, 0x3C, 0x00 }).?;
    try expectEqual(MessageKind.note_off, m.kind);
    try expectEqual(@as(u4, 2), m.channel);
    try expectEqual(@as(u8, 60), m.data1);
}

test "running status: two note-ons share one status byte" {
    var p = Parser.init();
    try expect(p.feed(0x90) == null);
    try expect(p.feed(0x3C) == null);
    const m1 = p.feed(0x40).?;
    try expectEqual(@as(u8, 60), m1.data1);
    // no new status byte:
    try expect(p.feed(0x3E) == null);
    const m2 = p.feed(0x50).?;
    try expectEqual(MessageKind.note_on, m2.kind);
    try expectEqual(@as(u8, 62), m2.data1);
    try expectEqual(@as(u8, 80), m2.data2);
}

test "note on with velocity 0 (consumer treats as note off)" {
    var p = Parser.init();
    const m = feedAll(&p, &.{ 0x90, 0x40, 0x00 }).?;
    try expectEqual(MessageKind.note_on, m.kind);
    try expectEqual(@as(u8, 0), m.data2);
}

test "control change" {
    var p = Parser.init();
    const m = feedAll(&p, &.{ 0xB1, 0x07, 0x7F }).?;
    try expectEqual(MessageKind.control_change, m.kind);
    try expectEqual(@as(u4, 1), m.channel);
    try expectEqual(@as(u8, 7), m.data1);
    try expectEqual(@as(u8, 127), m.data2);
}

test "program change is a single-data message" {
    var p = Parser.init();
    const m = feedAll(&p, &.{ 0xC0, 0x05 }).?;
    try expectEqual(MessageKind.program_change, m.kind);
    try expectEqual(@as(u8, 5), m.data1);
}

test "real-time byte interleaved mid-message is ignored" {
    var p = Parser.init();
    try expect(p.feed(0x90) == null);
    try expect(p.feed(0x3C) == null);
    try expect(p.feed(0xF8) == null); // MIDI clock in the middle
    const m = p.feed(0x40).?;
    try expectEqual(MessageKind.note_on, m.kind);
    try expectEqual(@as(u8, 60), m.data1);
    try expectEqual(@as(u8, 64), m.data2);
}

test "sysex payload is skipped" {
    var p = Parser.init();
    try expect(feedAll(&p, &.{ 0xF0, 0x7E, 0x00, 0x06, 0x01, 0xF7 }) == null);
    // and a normal message parses fine afterwards
    const m = feedAll(&p, &.{ 0x90, 0x3C, 0x40 }).?;
    try expectEqual(MessageKind.note_on, m.kind);
}

test "MessageQueue: fifo order and empty" {
    var q = MessageQueue.init();
    try expect(q.pop() == null);
    q.push(.{ .kind = .note_on, .channel = 0, .data1 = 60, .data2 = 64 });
    q.push(.{ .kind = .note_off, .channel = 1, .data1 = 62, .data2 = 0 });
    try expectEqual(@as(u8, 60), q.pop().?.data1);
    try expectEqual(@as(u8, 62), q.pop().?.data1);
    try expect(q.pop() == null);
}

test "MessageQueue: drops on full, keeps oldest, no corruption" {
    var q = MessageQueue.init();
    var i: u8 = 0;
    while (i < 100) : (i += 1) {
        q.push(.{ .kind = .note_on, .channel = 0, .data1 = i, .data2 = 0 });
    }
    // capacity is ring.len - 1 = 63; oldest retained, newest dropped.
    var count: usize = 0;
    var last: u8 = 0;
    while (q.pop()) |m| : (count += 1) {
        try expectEqual(@as(u8, @intCast(count)), m.data1); // oldest-first, contiguous
        last = m.data1;
    }
    try expectEqual(@as(usize, 63), count);
    try expectEqual(@as(u8, 62), last);
}
