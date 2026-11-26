//! The Daisy-side client of the panel scanner, std only so the host tests
//! it. The scanner reports state, not events: every read gives the whole
//! debounced key map and four wrapping detent counters. The client keeps
//! a copy of the state it has reported and turns the difference to each
//! new frame into events. A lost, repeated or refused read therefore loses
//! nothing; the next good frame carries every change since.
//!
//! What a state can not carry: a key pressed and released again between
//! two polls gives no event (a key changes after 5 ms in the scanner, so
//! poll more often than that, or on INT), and more than 127 detents of
//! one encoder between two delivered turns are taken the shorter way round
//! (a difference of exactly 128 reads as -128).
//!
//! **Do not rely on INT alone.** INT can read released while this client
//! still owes work:
//! - On a booted frame the acknowledge may go through and the
//!   `clear_booted` after it fail. The scanner releases INT, but the
//!   releases and `restarted` are still owed (held notes stay on).
//! - After 256 changes without an acknowledge, `seq` comes round to the
//!   acknowledged value.
//!
//! So a `poll` that returned an error is retried without waiting for INT,
//! and the Daisy also polls on a timer.
//!
//! The panel updater (`panel_update.zig`) needs the scanner to itself: do
//! not poll while it runs, and create a new client after it has run, since
//! the scanner may then run another image with fresh counters.

const std = @import("std");
const proto = @import("panel_proto.zig");

pub const Event = union(enum) {
    key: struct { index: u6, pressed: bool },
    turn: struct { encoder: u2, steps: i8 },
    restarted, // the scanner started again; held keys have been released
};

/// Counts that saturate rather than wrap.
pub const Stats = struct { bad_frames: u32 = 0, bus_errors: u32 = 0, restarts: u32 = 0 };

/// The client over a `Bus`, which is a type or a pointer to a type that has:
///
/// - `pub const Error`: the error set of its transfers;
/// - `read(self, address: u7, rx: []u8) Error!void`: a plain read
///   (START, address, `rx.len` bytes, STOP);
/// - `write(self, address: u7, bytes: []const u8) Error!void`.
pub fn PanelClient(comptime Bus: type) type {
    const Impl = switch (@typeInfo(Bus)) {
        .pointer => |p| p.child,
        else => Bus,
    };

    return struct {
        const Self = @This();
        pub const Error = Impl.Error;

        bus: Bus,
        /// The keys reported pressed so far.
        keys: u64 = 0,
        /// The counters as reported so far.
        enc: [proto.encoder_count]u8 = @splat(0),
        /// False until a frame was accepted; the first one sets the counters' base.
        based: bool = false,
        fw: ?u8 = null,
        in_trial: ?bool = null,
        /// The `seq` last acknowledged to the scanner; null until the first.
        acked: ?u8 = null,
        counters: Stats = .{},

        pub fn init(bus: Bus) Self {
            return .{ .bus = bus };
        }

        /// Reads one frame and puts the events since the last accepted one
        /// in `out`; returns the part of `out` used.
        ///
        /// - A frame that fails `decode` counts in `bad_frames`, changes
        ///   nothing and is not acknowledged.
        /// - A frame with `booted` set: a release for every key reported
        ///   pressed, then `restarted`; the counters are re-based on the
        ///   frame, and `0x02 <seq>` and `clear_booted` are written. Keys
        ///   already down in it come as presses from the next frame. Until
        ///   the scanner has acted on the command, a frame read again still
        ///   has `booted` set and gives another `restarted`, which is
        ///   harmless: there is nothing left to release.
        /// - Otherwise: a `key` event per changed key in ascending index
        ///   order, then a `turn` per encoder whose counter moved; and
        ///   `0x02 <seq>` is written once the client's copy has caught up
        ///   with the frame, unless that `seq` was acknowledged already. A
        ///   frame without changes is acknowledged too.
        ///
        /// When `out` is too small, the events that did not fit stay pending
        /// for the next poll: the client advances its copy of the state only
        /// for events it delivered, and acknowledges nothing (so INT stays
        /// low and asks for the next poll). `clear_booted` and its
        /// acknowledge are written only once `restarted` is delivered. The
        /// writes come before anything is delivered: a bus error, on the read
        /// or on a write, passes through, counts in `bus_errors`, delivers
        /// nothing and advances no copy of the state, and the next poll tries
        /// again. (A frame accepted before a failed write has already set
        /// `firmware()`, `trial()` and, if it was the first, the counters'
        /// base; none of them produces an event.)
        pub fn poll(self: *Self, out: []Event) Error![]Event {
            var raw: [proto.frame_len]u8 = undefined;
            self.bus.read(proto.address, &raw) catch |err| {
                self.counters.bus_errors +|= 1;
                return err;
            };
            const f = proto.decode(&raw) catch {
                self.counters.bad_frames +|= 1;
                return out[0..0];
            };

            self.fw = f.fw;
            self.in_trial = f.trial;
            if (!self.based) {
                self.enc = f.enc;
                self.based = true;
            }
            return if (f.booted) self.restart(f, out) else self.changes(f, out);
        }

        /// The scanner's firmware number; null until a frame was accepted.
        pub fn firmware(self: *const Self) ?u8 {
            return self.fw;
        }

        /// Whether the scanner said it runs from an uncommitted image, as
        /// of the last accepted frame; null until a frame was accepted.
        pub fn trial(self: *const Self) ?bool {
            return self.in_trial;
        }

        pub fn stats(self: *const Self) Stats {
            return self.counters;
        }

        fn send(self: *Self, c: proto.Command) Error!void {
            var cmd: [proto.max_command_len]u8 = undefined;
            self.bus.write(proto.address, proto.encodeCommand(c, &cmd)) catch |err| {
                self.counters.bus_errors +|= 1;
                return err;
            };
        }

        fn isAcked(self: *const Self, seq: u8) bool {
            return if (self.acked) |a| a == seq else false;
        }

        fn restart(self: *Self, f: proto.Frame, out: []Event) Error![]Event {
            const held: usize = @popCount(self.keys);
            const complete = out.len > held;
            if (complete) {
                // Before anything is delivered, so a failed write changes
                // nothing. The acknowledge first: `booted` stays set, and the
                // restart pending, until `clear_booted` has gone through. A
                // restarted scanner has forgotten every acknowledge, so this
                // one is sent whatever `seq` it carries.
                try self.send(.{ .ack = f.seq });
                try self.send(.clear_booted);
            }

            var n: usize = 0;
            while (self.keys != 0 and n < out.len) : (n += 1) {
                const index: u6 = @intCast(@ctz(self.keys));
                out[n] = .{ .key = .{ .index = index, .pressed = false } };
                self.keys &= self.keys - 1; // clears the lowest bit, `index`
            }
            if (!complete) return out[0..n];

            out[n] = .restarted;
            self.enc = f.enc;
            self.acked = f.seq;
            self.counters.restarts +|= 1;
            return out[0 .. n + 1];
        }

        fn changes(self: *Self, f: proto.Frame, out: []Event) Error![]Event {
            var diff = f.keys ^ self.keys;
            var moved: usize = 0;
            for (f.enc, self.enc) |now, was| moved += @intFromBool(now != was);
            const catches_up = @as(usize, @popCount(diff)) + moved <= out.len;
            const ack = catches_up and !self.isAcked(f.seq);
            if (ack) try self.send(.{ .ack = f.seq }); // before anything is delivered

            var n: usize = 0;
            while (diff != 0 and n < out.len) : (n += 1) {
                const index: u6 = @intCast(@ctz(diff));
                const mask = @as(u64, 1) << index;
                out[n] = .{ .key = .{ .index = index, .pressed = f.keys & mask != 0 } };
                self.keys ^= mask;
                diff ^= mask;
            }

            for (f.enc, &self.enc, 0..) |now, *was, e| {
                if (n == out.len) break;
                if (now == was.*) continue;
                out[n] = .{ .turn = .{ .encoder = @intCast(e), .steps = @bitCast(now -% was.*) } };
                was.* = now;
                n += 1;
            }

            if (ack) self.acked = f.seq;
            return out[0..n];
        }
    };
}

// ============================================================================

const testing = std.testing;

/// Serves frames from a list, one per read, repeating the last one when the
/// list runs out; records the writes. `fail_read` makes the next read fail
/// (it serves no frame); `fail_write` makes a write fail after
/// `fail_write_after` more writes went through.
const FakeBus = struct {
    pub const Error = error{ Nack, Timeout };

    frames: []const [proto.frame_len]u8,
    next: usize = 0,
    fail_read: ?Error = null,
    fail_write: ?Error = null,
    fail_write_after: usize = 0,
    reads: usize = 0,
    bad_reads: usize = 0, // reads not of 16 bytes from the scanner's address
    writes: [16][4]u8 = undefined,
    write_lens: [16]usize = undefined,
    write_count: usize = 0,
    bad_writes: usize = 0, // writes not to the scanner's address

    pub fn read(self: *FakeBus, address: u7, rx: []u8) Error!void {
        self.reads += 1;
        if (address != proto.address or rx.len != proto.frame_len) self.bad_reads += 1;
        if (self.fail_read) |e| {
            self.fail_read = null;
            return e;
        }
        @memcpy(rx, &self.frames[self.next]);
        if (self.next + 1 < self.frames.len) self.next += 1;
    }

    pub fn write(self: *FakeBus, address: u7, bytes: []const u8) Error!void {
        if (address != proto.address) self.bad_writes += 1;
        if (self.fail_write) |e| {
            if (self.fail_write_after == 0) {
                self.fail_write = null;
                return e;
            }
            self.fail_write_after -= 1;
        }
        @memcpy(self.writes[self.write_count][0..bytes.len], bytes);
        self.write_lens[self.write_count] = bytes.len;
        self.write_count += 1;
    }

    fn written(self: *const FakeBus, i: usize) []const u8 {
        return self.writes[i][0..self.write_lens[i]];
    }
};

const Client = PanelClient(*FakeBus);

fn frame(seq: u8, booted: bool, keys: u64, enc: [4]u8) [proto.frame_len]u8 {
    return proto.encode(.{ .fw = 3, .seq = seq, .booted = booted, .keys = keys, .enc = enc });
}

fn bit(n: u6) u64 {
    return @as(u64, 1) << n;
}

fn press(n: u6) Event {
    return .{ .key = .{ .index = n, .pressed = true } };
}

fn release(n: u6) Event {
    return .{ .key = .{ .index = n, .pressed = false } };
}

fn turn(e: u2, steps: i8) Event {
    return .{ .turn = .{ .encoder = e, .steps = steps } };
}

fn expectEvents(want: []const Event, got: []const Event) !void {
    try testing.expectEqualSlices(Event, want, got);
}

/// Checks every write the fake has recorded so far, in order.
fn expectWrites(bus: *const FakeBus, want: []const []const u8) !void {
    try testing.expectEqual(want.len, bus.write_count);
    for (want, 0..) |w, i| try testing.expectEqualSlices(u8, w, bus.written(i));
    try testing.expectEqual(@as(usize, 0), bus.bad_writes);
}

const no_events: []const Event = &.{};

test "the first accepted frame with keys already down produces presses, and no turns from the counters' start" {
    const frames = [_][16]u8{frame(9, false, bit(3) | bit(17), .{ 10, 200, 0, 5 })};
    var bus = FakeBus{ .frames = &frames };
    var c = Client.init(&bus);
    try testing.expectEqual(@as(?u8, null), c.firmware());
    var buf: [16]Event = undefined;
    try expectEvents(&.{ press(3), press(17) }, try c.poll(&buf));
    try testing.expectEqual(@as(?u8, 3), c.firmware());
    try testing.expectEqual(@as(usize, 1), bus.reads);
    try testing.expectEqual(@as(usize, 0), bus.bad_reads); // 16 bytes from 0x42
    try testing.expectEqual(Stats{}, c.stats());
}

test "an accepted frame is followed by exactly one 0x02 <seq> write" {
    const frames = [_][16]u8{
        frame(9, false, bit(3), .{ 0, 0, 0, 0 }),
        frame(10, false, bit(3) | bit(4), .{ 0, 0, 0, 0 }),
    };
    var bus = FakeBus{ .frames = &frames };
    var c = Client.init(&bus);
    var buf: [16]Event = undefined;
    try expectEvents(&.{press(3)}, try c.poll(&buf));
    try expectWrites(&bus, &.{&.{ 0x02, 9 }});
    try expectEvents(&.{press(4)}, try c.poll(&buf));
    try expectWrites(&bus, &.{ &.{ 0x02, 9 }, &.{ 0x02, 10 } });
}

test "an accepted frame is acknowledged even when it produced no events, even with an out of length 0" {
    const frames = [_][16]u8{frame(0, false, 0, .{ 7, 7, 7, 7 })};
    var bus = FakeBus{ .frames = &frames };
    var c = Client.init(&bus);
    var buf: [16]Event = undefined;
    try expectEvents(no_events, try c.poll(buf[0..0]));
    try expectWrites(&bus, &.{&.{ 0x02, 0 }});
}

test "a changed key produces one event" {
    const frames = [_][16]u8{
        frame(1, false, bit(3), .{ 0, 0, 0, 0 }),
        frame(2, false, bit(3) | bit(20), .{ 0, 0, 0, 0 }),
        frame(3, false, bit(20), .{ 0, 0, 0, 0 }),
    };
    var bus = FakeBus{ .frames = &frames };
    var c = Client.init(&bus);
    var buf: [16]Event = undefined;
    try expectEvents(&.{press(3)}, try c.poll(&buf));
    try expectEvents(&.{press(20)}, try c.poll(&buf));
    try expectEvents(&.{release(3)}, try c.poll(&buf));
}

test "no change produces no events, and the same frame read again is not acknowledged a second time" {
    const frames = [_][16]u8{frame(1, false, bit(48), .{ 1, 2, 3, 4 })};
    var bus = FakeBus{ .frames = &frames };
    var c = Client.init(&bus);
    var buf: [16]Event = undefined;
    try expectEvents(&.{press(48)}, try c.poll(&buf));
    for (0..5) |_| try expectEvents(no_events, try c.poll(&buf));
    try expectWrites(&bus, &.{&.{ 0x02, 1 }});
}

test "a counter going 250 to 4 gives steps 10, and 4 to 250 gives -10" {
    const frames = [_][16]u8{
        frame(1, false, 0, .{ 0, 0, 250, 0 }),
        frame(2, false, 0, .{ 0, 0, 4, 0 }),
        frame(3, false, 0, .{ 0, 0, 250, 0 }),
    };
    var bus = FakeBus{ .frames = &frames };
    var c = Client.init(&bus);
    var buf: [16]Event = undefined;
    try expectEvents(no_events, try c.poll(&buf));
    try expectEvents(&.{turn(2, 10)}, try c.poll(&buf));
    try expectEvents(&.{turn(2, -10)}, try c.poll(&buf));
}

test "a difference of 128 gives -128 without a panic, and more than 127 is taken the shorter way round" {
    const frames = [_][16]u8{
        frame(1, false, 0, .{ 0, 0, 0, 0 }),
        frame(2, false, 0, .{ 128, 0, 0, 0 }),
        frame(3, false, 0, .{ 0, 0, 0, 0 }),
        frame(4, false, 0, .{ 200, 127, 0, 0 }),
    };
    var bus = FakeBus{ .frames = &frames };
    var c = Client.init(&bus);
    var buf: [16]Event = undefined;
    try expectEvents(no_events, try c.poll(&buf));
    try expectEvents(&.{turn(0, -128)}, try c.poll(&buf));
    try expectEvents(&.{turn(0, -128)}, try c.poll(&buf)); // 128 back to 0
    try expectEvents(&.{ turn(0, -56), turn(1, 127) }, try c.poll(&buf)); // 200 clockwise reads as 56 back
}

test "a frame with a bad CRC produces nothing, counts once, is not acknowledged, and the next good frame is compared with the last good one" {
    var damaged = frame(2, false, bit(1) | bit(2), .{ 9, 0, 0, 0 });
    damaged[6] ^= 0x10;
    var foreign = frame(5, false, bit(1) | bit(2), .{ 9, 0, 0, 0 });
    foreign[0] = 2;
    foreign[15] = proto.crc8(foreign[0..15]);
    const frames = [_][16]u8{
        frame(1, false, bit(1), .{ 5, 0, 0, 0 }),
        damaged,
        frame(3, false, bit(2), .{ 7, 0, 0, 0 }),
        foreign,
        @splat(0xFF), // nobody on the bus
        frame(4, false, bit(2), .{ 7, 0, 0, 0 }),
    };
    var bus = FakeBus{ .frames = &frames };
    var c = Client.init(&bus);
    var buf: [16]Event = undefined;
    try expectEvents(&.{press(1)}, try c.poll(&buf));
    try expectEvents(no_events, try c.poll(&buf));
    try testing.expectEqual(@as(u32, 1), c.stats().bad_frames);
    try expectWrites(&bus, &.{&.{ 0x02, 1 }});
    try expectEvents(&.{ release(1), press(2), turn(0, 2) }, try c.poll(&buf));
    try expectEvents(no_events, try c.poll(&buf));
    try expectEvents(no_events, try c.poll(&buf));
    try testing.expectEqual(Stats{ .bad_frames = 3 }, c.stats());
    try expectWrites(&bus, &.{ &.{ 0x02, 1 }, &.{ 0x02, 3 } });
    try expectEvents(no_events, try c.poll(&buf));
    try expectWrites(&bus, &.{ &.{ 0x02, 1 }, &.{ 0x02, 3 }, &.{ 0x02, 4 } });
}

test "a bad first frame leaves the client without a firmware number and writes nothing" {
    var damaged = frame(1, false, 0, .{ 0, 0, 0, 0 });
    damaged[1] ^= 0x01;
    const frames = [_][16]u8{ damaged, frame(1, false, bit(4), .{ 3, 0, 0, 0 }) };
    var bus = FakeBus{ .frames = &frames };
    var c = Client.init(&bus);
    var buf: [16]Event = undefined;
    try expectEvents(no_events, try c.poll(&buf));
    try testing.expectEqual(@as(?u8, null), c.firmware());
    try expectWrites(&bus, &.{});
    try expectEvents(&.{press(4)}, try c.poll(&buf)); // and its counters are the base
    try testing.expectEqual(@as(?u8, 3), c.firmware());
}

test "a booted frame after keys were held gives their releases, then restarted, and writes both 0x02 <seq> and 0x01" {
    const frames = [_][16]u8{
        frame(7, false, bit(5) | bit(40), .{ 1, 2, 3, 4 }),
        frame(0, true, bit(7), .{ 0, 0, 0, 0 }), // the scanner restarted, key 7 is down
        frame(1, false, bit(7), .{ 1, 0, 0, 0 }),
    };
    var bus = FakeBus{ .frames = &frames };
    var c = Client.init(&bus);
    var buf: [16]Event = undefined;
    try expectEvents(&.{ press(5), press(40) }, try c.poll(&buf));
    try expectEvents(&.{ release(5), release(40), .restarted }, try c.poll(&buf));
    try expectWrites(&bus, &.{ &.{ 0x02, 7 }, &.{ 0x02, 0 }, &.{0x01} });
    try testing.expectEqual(Stats{ .restarts = 1 }, c.stats());
    // The counters were re-based on the booted frame: only the new detent shows.
    try expectEvents(&.{ press(7), turn(0, 1) }, try c.poll(&buf));
    try expectWrites(&bus, &.{ &.{ 0x02, 7 }, &.{ 0x02, 0 }, &.{0x01}, &.{ 0x02, 1 } });
}

test "a booted first frame gives restarted and writes both 0x02 <seq> and 0x01" {
    const frames = [_][16]u8{
        frame(0, true, bit(0), .{ 0, 0, 0, 0 }),
        frame(1, false, bit(0), .{ 0, 0, 0, 0 }),
    };
    var bus = FakeBus{ .frames = &frames };
    var c = Client.init(&bus);
    var buf: [16]Event = undefined;
    try expectEvents(&.{.restarted}, try c.poll(&buf));
    try expectWrites(&bus, &.{ &.{ 0x02, 0 }, &.{0x01} });
    try expectEvents(&.{press(0)}, try c.poll(&buf));
}

test "a booted frame with the seq last acknowledged before the restart is acknowledged again" {
    const frames = [_][16]u8{
        frame(0, false, 0, .{ 0, 0, 0, 0 }),
        frame(0, true, 0, .{ 0, 0, 0, 0 }), // restarted; its link forgot the acknowledge
    };
    var bus = FakeBus{ .frames = &frames };
    var c = Client.init(&bus);
    var buf: [16]Event = undefined;
    try expectEvents(no_events, try c.poll(&buf));
    try expectEvents(&.{.restarted}, try c.poll(&buf));
    try expectWrites(&bus, &.{ &.{ 0x02, 0 }, &.{ 0x02, 0 }, &.{0x01} });
}

test "a booted frame that does not fit in out releases what fits and restarts and acknowledges on a later poll" {
    const frames = [_][16]u8{
        frame(3, false, bit(10) | bit(11), .{ 0, 0, 0, 0 }),
        frame(0, true, 0, .{ 0, 0, 0, 0 }),
    };
    var bus = FakeBus{ .frames = &frames };
    var c = Client.init(&bus);
    var buf: [16]Event = undefined;
    try expectEvents(&.{ press(10), press(11) }, try c.poll(&buf));
    try expectEvents(&.{release(10)}, try c.poll(buf[0..1]));
    try expectWrites(&bus, &.{&.{ 0x02, 3 }});
    try expectEvents(&.{release(11)}, try c.poll(buf[0..1]));
    try expectWrites(&bus, &.{&.{ 0x02, 3 }});
    try expectEvents(&.{.restarted}, try c.poll(buf[0..1]));
    try expectWrites(&bus, &.{ &.{ 0x02, 3 }, &.{ 0x02, 0 }, &.{0x01} });
    try testing.expectEqual(Stats{ .restarts = 1 }, c.stats());
}

test "a failed write on a booted frame, the acknowledge or the clear_booted, passes through, counts, changes nothing, and is tried again" {
    const frames = [_][16]u8{
        frame(3, false, bit(30), .{ 0, 0, 0, 0 }),
        frame(0, true, 0, .{ 0, 0, 0, 0 }),
    };
    for ([_]usize{ 0, 1 }) |which| {
        var bus = FakeBus{ .frames = &frames };
        var c = Client.init(&bus);
        var buf: [16]Event = undefined;
        try expectEvents(&.{press(30)}, try c.poll(&buf));
        bus.fail_write = error.Timeout;
        bus.fail_write_after = which;
        try testing.expectError(error.Timeout, c.poll(&buf));
        try testing.expectEqual(Stats{ .bus_errors = 1 }, c.stats());
        try expectEvents(&.{ release(30), .restarted }, try c.poll(&buf));
        try testing.expectEqual(Stats{ .bus_errors = 1, .restarts = 1 }, c.stats());
        try testing.expectEqualSlices(u8, &.{0x01}, bus.written(bus.write_count - 1));
    }
}

test "an out of length 2 with five changes delivers 2, then 2, then 1, and acknowledges only with the last" {
    const frames = [_][16]u8{
        frame(1, false, 0, .{ 0, 0, 0, 0 }),
        frame(2, false, bit(1) | bit(2) | bit(3), .{ 0, 5, 0, 250 }),
    };
    var bus = FakeBus{ .frames = &frames };
    var c = Client.init(&bus);
    var buf: [16]Event = undefined;
    try expectEvents(no_events, try c.poll(&buf));
    try expectWrites(&bus, &.{&.{ 0x02, 1 }});
    try expectEvents(&.{ press(1), press(2) }, try c.poll(buf[0..2]));
    try expectWrites(&bus, &.{&.{ 0x02, 1 }});
    try expectEvents(&.{ press(3), turn(1, 5) }, try c.poll(buf[0..2]));
    try expectWrites(&bus, &.{&.{ 0x02, 1 }});
    try expectEvents(&.{turn(3, -6)}, try c.poll(buf[0..2]));
    try expectWrites(&bus, &.{ &.{ 0x02, 1 }, &.{ 0x02, 2 } });
    try expectEvents(no_events, try c.poll(buf[0..2]));
    try expectWrites(&bus, &.{ &.{ 0x02, 1 }, &.{ 0x02, 2 } });
}

test "an out of length 0 delivers nothing, loses nothing, and acknowledges nothing pending" {
    const frames = [_][16]u8{
        frame(1, false, bit(9), .{ 0, 0, 0, 0 }),
        frame(2, false, bit(9) | bit(12), .{ 0, 0, 1, 0 }),
    };
    var bus = FakeBus{ .frames = &frames };
    var c = Client.init(&bus);
    var buf: [16]Event = undefined;
    try expectEvents(no_events, try c.poll(buf[0..0]));
    try testing.expectEqual(@as(?u8, 3), c.firmware());
    try expectEvents(no_events, try c.poll(buf[0..0]));
    try expectWrites(&bus, &.{});
    try expectEvents(&.{ press(9), press(12), turn(2, 1) }, try c.poll(&buf));
    try expectWrites(&bus, &.{&.{ 0x02, 2 }});
}

test "a failing acknowledge write returns the bus error, delivers nothing, and the next poll acknowledges" {
    const frames = [_][16]u8{frame(4, false, bit(1), .{ 0, 0, 0, 0 })};
    var bus = FakeBus{ .frames = &frames };
    var c = Client.init(&bus);
    var buf: [16]Event = undefined;
    bus.fail_write = error.Nack;
    try testing.expectError(error.Nack, c.poll(&buf));
    try testing.expectEqual(Stats{ .bus_errors = 1 }, c.stats());
    try expectWrites(&bus, &.{});
    try expectEvents(&.{press(1)}, try c.poll(&buf)); // the press was not lost
    try expectWrites(&bus, &.{&.{ 0x02, 4 }});
}

test "a bus error on the read passes through unchanged, counts, and leaves the state untouched" {
    const frames = [_][16]u8{
        frame(1, false, bit(1), .{ 4, 0, 0, 0 }),
        frame(2, false, bit(1) | bit(2), .{ 6, 0, 0, 0 }),
    };
    var bus = FakeBus{ .frames = &frames };
    var c = Client.init(&bus);
    var buf: [16]Event = undefined;
    bus.fail_read = error.Nack;
    try testing.expectError(error.Nack, c.poll(&buf));
    try testing.expectEqual(@as(?u8, null), c.firmware());
    try expectWrites(&bus, &.{});
    try expectEvents(&.{press(1)}, try c.poll(&buf));
    bus.fail_read = error.Timeout;
    try testing.expectError(error.Timeout, c.poll(&buf));
    try testing.expectEqual(Stats{ .bus_errors = 2 }, c.stats());
    try expectEvents(&.{ press(2), turn(0, 2) }, try c.poll(&buf));
}

test "trial is null until a frame was accepted, then follows the accepted frames only" {
    var damaged = proto.encode(.{ .fw = 3, .seq = 2, .booted = false, .trial = false, .keys = 0, .enc = .{ 0, 0, 0, 0 } });
    damaged[6] ^= 0x01;
    const frames = [_][16]u8{
        proto.encode(.{ .fw = 3, .seq = 1, .booted = false, .trial = true, .keys = 0, .enc = .{ 0, 0, 0, 0 } }),
        damaged,
        proto.encode(.{ .fw = 3, .seq = 3, .booted = false, .trial = false, .keys = 0, .enc = .{ 0, 0, 0, 0 } }),
    };
    var bus = FakeBus{ .frames = &frames };
    var c = Client.init(&bus);
    var buf: [16]Event = undefined;
    try testing.expectEqual(@as(?bool, null), c.trial());
    try expectEvents(no_events, try c.poll(&buf));
    try testing.expectEqual(@as(?bool, true), c.trial());
    try expectEvents(no_events, try c.poll(&buf)); // refused: trial unchanged
    try testing.expectEqual(@as(?bool, true), c.trial());
    try expectEvents(no_events, try c.poll(&buf));
    try testing.expectEqual(@as(?bool, false), c.trial());
}

/// A `Bus` passed by value, whose methods take `self` by value.
const ValueBus = struct {
    pub const Error = FakeBus.Error;
    inner: *FakeBus,

    pub fn read(self: ValueBus, address: u7, rx: []u8) Error!void {
        return self.inner.read(address, rx);
    }

    pub fn write(self: ValueBus, address: u7, bytes: []const u8) Error!void {
        return self.inner.write(address, bytes);
    }
};

test "a Bus passed by value works like a pointer" {
    const frames = [_][16]u8{
        frame(1, false, bit(2), .{ 0, 0, 0, 0 }),
        frame(0, true, 0, .{ 0, 0, 0, 0 }),
    };
    var bus = FakeBus{ .frames = &frames };
    var c = PanelClient(ValueBus).init(.{ .inner = &bus });
    var buf: [16]Event = undefined;
    try expectEvents(&.{press(2)}, try c.poll(&buf));
    try expectEvents(&.{ release(2), .restarted }, try c.poll(&buf));
    try expectWrites(&bus, &.{ &.{ 0x02, 1 }, &.{ 0x02, 0 }, &.{0x01} });
    bus.fail_read = error.Nack;
    try testing.expectError(error.Nack, c.poll(&buf));
}
