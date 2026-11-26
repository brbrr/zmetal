//! The panel scanner's I2C target as a state machine, std only so the host
//! tests it without a bus. The register layer passes each bus event in:
//!
//! - `onAddress(reading, frame)` at the address match. A read takes its
//!   snapshot of the frame here; a write starts collecting a command.
//! - `nextByte()` for every byte the master clocks out of us. Bytes past
//!   the 16 of the frame are 0xFF.
//! - `onByte(b)` for every byte the master writes.
//! - `onStop()` at the STOP. It ends the transaction: a write gives its
//!   command if its bytes are exactly one; a read gives nothing.
//!
//! INT follows the host's acknowledge (`0x02 <seq>`), which the link
//! records itself when `onStop` returns it. Reads never change INT, so it
//! does not matter how far ahead the peripheral asks for bytes: a byte
//! requested and not sent changes nothing.
//!
//! A transaction is finished only by its STOP. A new address without one
//! (a repeated START, which the protocol does not use) drops the
//! unfinished transaction: a write gives no command and acknowledges
//! nothing.

const std = @import("std");
const proto = @import("panel_proto.zig");

/// What the I2C target does with each bus event; no registers.
pub const Link = struct {
    mode: Mode = .idle,
    /// The current read's frame, encoded at its address match.
    tx: [proto.frame_len]u8 = undefined,
    /// Bytes handed out in the current read, saturating.
    sent: u8 = 0,
    /// The first bytes of the current write.
    rx: [max_command_len]u8 = undefined,
    /// Bytes received in the current write, saturating; may exceed `rx.len`.
    received: u8 = 0,
    /// The `seq` of the host's last acknowledge; null until the first.
    acked: ?u8 = null,

    const Mode = enum { idle, reading, writing };

    const max_command_len = proto.max_command_len;

    pub fn init() Link {
        return .{};
    }

    /// Our address matched: snapshot `frame` for a read, reset for a write.
    pub fn onAddress(self: *Link, reading: bool, frame: proto.Frame) void {
        if (reading) {
            self.mode = .reading;
            self.tx = proto.encode(frame);
            self.sent = 0;
        } else {
            self.mode = .writing;
            self.received = 0;
        }
    }

    /// The master clocks a byte out of us. 0xFF past the frame, or outside a read.
    pub fn nextByte(self: *Link) u8 {
        if (self.mode != .reading) return 0xFF;
        const b = if (self.sent < proto.frame_len) self.tx[self.sent] else 0xFF;
        self.sent +|= 1;
        return b;
    }

    /// The master sent us a byte. Ignored outside a write; bytes past the
    /// longest command are counted, not kept.
    pub fn onByte(self: *Link, b: u8) void {
        if (self.mode != .writing) return;
        if (self.received < self.rx.len) self.rx[self.received] = b;
        self.received +|= 1;
    }

    /// The STOP: the command just received, if a write completed one. An
    /// acknowledge is recorded here and still returned, for the main loop
    /// to ignore.
    pub fn onStop(self: *Link) ?proto.Command {
        const mode = self.mode;
        self.mode = .idle;
        if (mode != .writing or self.received > self.rx.len) return null;
        const command = proto.decodeCommand(self.rx[0..self.received]) orelse return null;
        switch (command) {
            .ack => |seq| self.acked = seq,
            .clear_booted, .enter_bootloader => {},
        }
        return command;
    }

    /// True while the host has not acknowledged the state `current_seq`.
    /// An acknowledge of another `seq`, an older one arriving late among
    /// them, leaves it asserted. After 256 changes without an acknowledge
    /// `seq` comes round to the acknowledged value and INT reads as
    /// released until the next change.
    pub fn intAsserted(self: *const Link, current_seq: u8) bool {
        const acked = self.acked orelse return true;
        return acked != current_seq;
    }
};

// ============================================================================

const testing = std.testing;

const f5 = proto.Frame{ .fw = 3, .seq = 5, .booted = true, .keys = (1 << 0) | (1 << 48), .enc = .{ 1, 255, 0, 7 } };
const f6 = proto.Frame{ .fw = 3, .seq = 6, .booted = false, .keys = (1 << 8) | (1 << 9) | (1 << 30), .enc = .{ 2, 255, 0, 7 } };

/// One read transaction of `n` bytes: address, `n` bytes clocked out, STOP.
/// Returns the first bytes (up to 32) and checks the STOP gives no command.
fn read(link: *Link, frame: proto.Frame, n: usize) ![32]u8 {
    var got: [32]u8 = @splat(0xAA);
    link.onAddress(true, frame);
    for (0..n) |i| {
        const b = link.nextByte();
        if (i < got.len) got[i] = b;
    }
    try testing.expectEqual(@as(?proto.Command, null), link.onStop());
    return got;
}

/// One write transaction: address, `bytes`, STOP. Returns what the STOP gives.
fn write(link: *Link, bytes: []const u8) ?proto.Command {
    link.onAddress(false, f6); // the frame does not matter to a write
    for (bytes) |b| link.onByte(b);
    return link.onStop();
}

/// The host's acknowledge of `seq`; checks the STOP hands it to the main loop.
fn ack(link: *Link, seq: u8) !void {
    try testing.expectEqual(@as(?proto.Command, .{ .ack = seq }), write(link, &.{ 0x02, seq }));
}

test "from init, INT is asserted for any seq" {
    const link = Link.init();
    for (0..256) |seq| try testing.expect(link.intAsserted(@intCast(seq)));
}

test "a 16-byte read returns exactly encode(frame) and does not release INT" {
    var link = Link.init();
    const got = try read(&link, f5, 16);
    try testing.expectEqualSlices(u8, &proto.encode(f5), got[0..16]);
    try testing.expect(link.intAsserted(f5.seq));
}

test "bytes 17 and 18 of a longer read are 0xFF" {
    var link = Link.init();
    const got = try read(&link, f5, 18);
    try testing.expectEqualSlices(u8, &proto.encode(f5), got[0..16]);
    try testing.expectEqual(@as(u8, 0xFF), got[16]);
    try testing.expectEqual(@as(u8, 0xFF), got[17]);
}

test "a read far longer than the frame gives 0xFF to the end and overflows nothing" {
    var link = Link.init();
    link.onAddress(true, f5);
    for (0..16) |_| _ = link.nextByte();
    for (16..1000) |_| try testing.expectEqual(@as(u8, 0xFF), link.nextByte());
    try testing.expectEqual(@as(?proto.Command, null), link.onStop());
    try testing.expect(link.intAsserted(f5.seq));
}

test "an ack of the current seq releases INT, with or without a read before it" {
    var link = Link.init();
    _ = try read(&link, f5, 16);
    try ack(&link, f5.seq);
    try testing.expect(!link.intAsserted(f5.seq));

    var link2 = Link.init();
    try ack(&link2, 0x37);
    try testing.expect(!link2.intAsserted(0x37));
}

test "a new seq asserts INT again" {
    var link = Link.init();
    try ack(&link, 5);
    try testing.expect(!link.intAsserted(5));
    try testing.expect(link.intAsserted(6));
    try testing.expect(link.intAsserted(4));
}

test "an ack of an old seq leaves INT asserted" {
    var link = Link.init();
    try ack(&link, 5); // the scanner has moved on to 6 meanwhile
    try testing.expect(link.intAsserted(6));
    try ack(&link, 6);
    try testing.expect(!link.intAsserted(6));
    try ack(&link, 5); // a stale acknowledge arriving late
    try testing.expect(link.intAsserted(6));
}

test "reads of 10, 16 and 30 bytes, or none, change nothing about INT" {
    var link = Link.init();
    const got = try read(&link, f5, 10);
    try testing.expectEqualSlices(u8, proto.encode(f5)[0..10], got[0..10]);
    try testing.expect(link.intAsserted(f5.seq));
    _ = try read(&link, f5, 30);
    try testing.expect(link.intAsserted(f5.seq));
    _ = try read(&link, f5, 0);
    try testing.expect(link.intAsserted(f5.seq));

    try ack(&link, f5.seq);
    for ([_]usize{ 10, 16, 30, 0 }) |n| {
        _ = try read(&link, f5, n);
        try testing.expect(!link.intAsserted(f5.seq));
    }
}

test "the frame is snapshot at the address: a change during the read shows only at the next address" {
    var link = Link.init();
    link.onAddress(true, f5);
    var got: [16]u8 = undefined;
    for (got[0..8]) |*b| b.* = link.nextByte();
    // The scanner's state moves on to f6 here; the link is not told until the next address.
    for (got[8..16]) |*b| b.* = link.nextByte();
    try testing.expectEqual(@as(?proto.Command, null), link.onStop());
    try testing.expectEqualSlices(u8, &proto.encode(f5), &got);

    const got2 = try read(&link, f6, 16);
    try testing.expectEqualSlices(u8, &proto.encode(f6), got2[0..16]);
}

test "the write 0x01 gives clear_booted at the STOP" {
    var link = Link.init();
    try testing.expectEqual(@as(?proto.Command, .clear_booted), write(&link, &.{0x01}));
}

test "the write 0xB0 0x07 0x5A gives enter_bootloader at the STOP" {
    var link = Link.init();
    try testing.expectEqual(@as(?proto.Command, .enter_bootloader), write(&link, &.{ 0xB0, 0x07, 0x5A }));
}

test "the write 0xB0 0x07 then STOP gives null" {
    var link = Link.init();
    try testing.expectEqual(@as(?proto.Command, null), write(&link, &.{ 0xB0, 0x07 }));
}

test "a write of no bytes, or one unknown byte, gives null" {
    var link = Link.init();
    try testing.expectEqual(@as(?proto.Command, null), write(&link, &.{}));
    try testing.expectEqual(@as(?proto.Command, null), write(&link, &.{0x55}));
    try testing.expectEqual(@as(?proto.Command, null), write(&link, &.{0xB0}));
}

test "an acknowledge needs exactly two bytes: 0x02 alone, or with more, acknowledges nothing" {
    var link = Link.init();
    try testing.expectEqual(@as(?proto.Command, null), write(&link, &.{0x02}));
    try testing.expect(link.intAsserted(0x02));
    try testing.expectEqual(@as(?proto.Command, null), write(&link, &.{ 0x02, 0x05, 0x00 }));
    try testing.expect(link.intAsserted(5));
    try ack(&link, 5);
    try testing.expect(!link.intAsserted(5));
}

test "five bytes of rubbish give null and overflow nothing, even when they start with a command" {
    var link = Link.init();
    try testing.expectEqual(@as(?proto.Command, null), write(&link, &.{ 0x13, 0x37, 0xC0, 0xFF, 0xEE }));
    try testing.expectEqual(@as(?proto.Command, null), write(&link, &.{ 0xB0, 0x07, 0x5A, 0x00, 0x00 }));
    try testing.expectEqual(@as(?proto.Command, null), write(&link, &.{ 0x01, 0x01, 0x01, 0x01, 0x01 }));
    try testing.expectEqual(@as(?proto.Command, null), write(&link, &.{ 0x02, 0x05, 0x00, 0x00, 0x00 }));
    var long: [1000]u8 = undefined;
    for (&long, 0..) |*b, i| b.* = @truncate(i +% 2); // starts 0x02 0x03
    try testing.expectEqual(@as(?proto.Command, null), write(&link, &long));
    try testing.expect(link.intAsserted(5));
    try testing.expect(link.intAsserted(3));
    // The link still works afterwards.
    try testing.expectEqual(@as(?proto.Command, .clear_booted), write(&link, &.{0x01}));
}

test "a write followed by a read, two transactions, both work" {
    var link = Link.init();
    try ack(&link, f6.seq);
    const got = try read(&link, f6, 16);
    try testing.expectEqualSlices(u8, &proto.encode(f6), got[0..16]);
    try testing.expect(!link.intAsserted(f6.seq));
    // And a read followed by a write.
    try testing.expectEqual(@as(?proto.Command, .enter_bootloader), write(&link, &.{ 0xB0, 0x07, 0x5A }));
    try testing.expect(!link.intAsserted(f6.seq)); // other commands leave the acknowledge alone
}

test "a STOP without a transaction returns null and acknowledges nothing" {
    var link = Link.init();
    try testing.expectEqual(@as(?proto.Command, null), link.onStop());
    try testing.expect(link.intAsserted(0));
    // A second STOP after a completed write or read is no transaction either.
    try testing.expectEqual(@as(?proto.Command, .clear_booted), write(&link, &.{0x01}));
    try testing.expectEqual(@as(?proto.Command, null), link.onStop());
    try ack(&link, 9);
    try testing.expectEqual(@as(?proto.Command, null), link.onStop());
    _ = try read(&link, f5, 16);
    try testing.expectEqual(@as(?proto.Command, null), link.onStop());
    try testing.expect(!link.intAsserted(9));
}

test "bytes in the wrong direction are ignored" {
    var link = Link.init();
    try testing.expectEqual(@as(u8, 0xFF), link.nextByte()); // no read in progress
    link.onAddress(true, f5);
    link.onByte(0x02); // not a write: no acknowledge
    link.onByte(f5.seq);
    for (0..16) |_| _ = link.nextByte();
    try testing.expectEqual(@as(?proto.Command, null), link.onStop());
    try testing.expect(link.intAsserted(f5.seq));
    link.onAddress(false, f5);
    try testing.expectEqual(@as(u8, 0xFF), link.nextByte()); // not a read
    link.onByte(0x01);
    try testing.expectEqual(@as(?proto.Command, .clear_booted), link.onStop());
}

test "a new address without a STOP drops the unfinished transaction" {
    var link = Link.init();
    link.onAddress(false, f5);
    link.onByte(0x02);
    link.onByte(f5.seq);
    link.onAddress(true, f5); // repeated START: the acknowledge never completed
    for (0..16) |_| _ = link.nextByte();
    try testing.expectEqual(@as(?proto.Command, null), link.onStop());
    try testing.expect(link.intAsserted(f5.seq));

    link.onAddress(false, f5);
    link.onByte(0x01);
    link.onAddress(false, f5); // a second write restarts the collection
    link.onByte(0x02);
    link.onByte(f5.seq);
    try testing.expectEqual(@as(?proto.Command, .{ .ack = f5.seq }), link.onStop());
    try testing.expect(!link.intAsserted(f5.seq));
}
