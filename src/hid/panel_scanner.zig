//! The panel scanner's core, std only so the host tests it: it turns raw
//! matrix and encoder samples into the state frame of `panel_proto`.
//!
//! `tick` runs at 8 kHz. Every tick samples the four encoders, as
//! `encoder.Encoder` decodes them (one count per detent, on the falling
//! edge of one channel while the other is low). Every 8th tick scans the
//! matrix through `matrix_scan.Scanner` (bit `row * 7 + col`, 1 = pressed:
//! a pressed key pulls its row low while its column is driven low) and
//! feeds the result to a `panel_debounce.Debouncer`, so a key changes after
//! 5 equal scans (5 ms). A failed matrix read is not a sample: the
//! debouncer and the key map stay as they were.
//!
//! `seq` advances (wrapping) once per tick in which the key map, a detent
//! counter or `booted` changed, and at no other time.

const std = @import("std");
const proto = @import("panel_proto.zig");
const panel_debounce = @import("panel_debounce.zig");
const matrix_scan = @import("matrix_scan.zig");
const encoder = @import("encoder.zig");

pub const ticks_per_scan = 8; // the matrix is scanned on every 8th tick
pub const debounce_samples = 5;

/// `Io`: the `matrix_scan` contract plus `encoderPins(self) [4][2]u1` (A and B of ENC1..4).
///
/// - `drive(io, columns: u8) !void`: a 0 bit drives that column (COL_1..7 = bits 0..6) low.
/// - `sense(io) !u8`: the rows (ROW_1..7 = bits 0..6); a pressed key pulls its row low.
/// - `settle(io) void`: the wait between a drive and a sense.
/// - `encoderPins(io) [4][2]u1`: the levels of A (`[i][0]`) and B (`[i][1]`) of ENC1..4, 1 = high.
///
/// `Io` may be a pointer; it is stored once, in the matrix scanner.
pub fn Scanner(comptime Io: type) type {
    return struct {
        const Self = @This();

        matrix: matrix_scan.Scanner(Io, proto.rows, proto.cols),
        debouncer: panel_debounce.Debouncer(debounce_samples) = .{},
        encoders: [proto.encoder_count]encoder.Encoder = @splat(encoder.Encoder.init()),
        state: proto.Frame,
        /// Ticks since the last matrix scan, below `ticks_per_scan`.
        phase: u8 = 0,

        pub fn init(io: Io, fw: u8) Self {
            return .{
                .matrix = .{ .io = io },
                .state = .{ .fw = fw, .seq = 0, .booted = true, .keys = 0, .enc = @splat(0) },
            };
        }

        /// One 8 kHz tick: the encoders every tick, the matrix every 8th.
        pub fn tick(self: *Self) void {
            var changed = false;

            const pins: [proto.encoder_count][2]u1 = self.matrix.io.encoderPins();
            for (&self.encoders, &self.state.enc, pins) |*e, *count, ab| {
                // The encoder switches are matrix keys: the switch input stays released.
                const inc = e.step(ab[0], ab[1], 1).inc;
                if (inc != 0) {
                    count.* +%= @as(u8, @bitCast(inc));
                    changed = true;
                }
            }

            self.phase += 1;
            if (self.phase == ticks_per_scan) {
                self.phase = 0;
                if (self.matrix.scan()) |raw| {
                    const keys = self.debouncer.update(raw);
                    if (keys != self.state.keys) {
                        self.state.keys = keys;
                        changed = true;
                    }
                } else |_| {} // no sample: `matrix_scan` drives the columns again next time
            }

            if (changed) self.state.seq +%= 1;
        }

        /// The state to serve, as of the last tick.
        pub fn frame(self: *const Self) proto.Frame {
            return self.state;
        }

        /// Whether the scanner runs from an uncommitted image, reported in
        /// every frame. Meant to be set once at start-up, before the first
        /// read: it does not advance `seq`.
        pub fn setTrial(self: *Self, trial: bool) void {
            self.state.trial = trial;
        }

        /// The Daisy's `clear_booted` command. Clearing a clear flag changes nothing.
        pub fn clearBooted(self: *Self) void {
            if (!self.state.booted) return;
            self.state.booted = false;
            self.state.seq +%= 1;
        }
    };
}

// ============================================================================

const testing = std.testing;

/// A 7x7 matrix of switches, scanned as `matrix_scan` expects: a 0 bit of
/// `drive` pulls that column low, and a row reads low (bit 0) when a
/// pressed key joins it to a low column. Pressed keys are kept as a set of
/// (row, col) pairs, one column mask per row, independent of `keyIndex`.
/// The encoder pins idle high, as `encoder.zig` expects.
const FakeIo = struct {
    pressed: [proto.rows]u8 = @splat(0),
    driven: u8 = 0xFF,
    enc: [proto.encoder_count][2]u1 = @splat(.{ 1, 1 }),
    fail_sense: bool = false,

    pub fn drive(self: *FakeIo, columns: u8) !void {
        self.driven = columns;
    }

    pub fn sense(self: *FakeIo) !u8 {
        if (self.fail_sense) return error.Bus;
        var v: u8 = 0xFF;
        for (self.pressed, 0..) |cols_down, row| {
            if (cols_down & ~self.driven != 0) v &= ~(@as(u8, 1) << @intCast(row));
        }
        return v;
    }

    pub fn settle(_: *FakeIo) void {}

    pub fn encoderPins(self: *FakeIo) [proto.encoder_count][2]u1 {
        return self.enc;
    }

    fn press(self: *FakeIo, row: u3, col: u3) void {
        self.pressed[row] |= @as(u8, 1) << col;
    }

    fn release(self: *FakeIo, row: u3, col: u3) void {
        self.pressed[row] &= ~(@as(u8, 1) << col);
    }
};

const TestScanner = Scanner(*FakeIo);

fn key(row: u3, col: u3) u64 {
    return @as(u64, 1) << proto.keyIndex(row, col);
}

fn ticks(s: *TestScanner, n: usize) void {
    for (0..n) |_| s.tick();
}

/// One quadrature cycle on encoder `e`, one state per tick, starting and
/// ending at rest (A and B high). Clockwise: A leads, 11 10 00 01 11;
/// counter-clockwise: B leads, 11 01 00 10 11 (as in `encoder.zig`).
fn detent(io: *FakeIo, s: *TestScanner, e: usize, clockwise: bool) void {
    const cw = [_][2]u1{ .{ 1, 0 }, .{ 0, 0 }, .{ 0, 1 }, .{ 1, 1 } };
    const ccw = [_][2]u1{ .{ 0, 1 }, .{ 0, 0 }, .{ 1, 0 }, .{ 1, 1 } };
    for (if (clockwise) cw else ccw) |ab| {
        io.enc[e] = ab;
        s.tick();
    }
}

test "after init the frame is booted, at seq 0, with no keys and the firmware number" {
    var io = FakeIo{};
    const s = TestScanner.init(&io, 3);
    try testing.expectEqual(proto.Frame{ .fw = 3, .seq = 0, .booted = true, .keys = 0, .enc = .{ 0, 0, 0, 0 } }, s.frame());
}

test "a key held for 5 scans (40 ticks) appears at bit keyIndex(row, col) and seq advances by 1" {
    var io = FakeIo{};
    var s = TestScanner.init(&io, 3);
    io.press(2, 5);
    ticks(&s, 5 * ticks_per_scan - 1);
    try testing.expectEqual(@as(u64, 0), s.frame().keys);
    try testing.expectEqual(@as(u8, 0), s.frame().seq);
    s.tick();
    try testing.expectEqual(key(2, 5), s.frame().keys);
    try testing.expectEqual(@as(u64, 1) << 19, s.frame().keys); // 2 * 7 + 5
    try testing.expectEqual(@as(u8, 1), s.frame().seq);
}

test "two keys in different rows of one column both appear, and nothing else" {
    var io = FakeIo{};
    var s = TestScanner.init(&io, 3);
    io.press(1, 3);
    io.press(5, 3);
    ticks(&s, 5 * ticks_per_scan);
    try testing.expectEqual(key(1, 3) | key(5, 3), s.frame().keys);
    try testing.expectEqual(@as(u8, 1), s.frame().seq); // both in one change
}

test "a key released disappears after 5 scans" {
    var io = FakeIo{};
    var s = TestScanner.init(&io, 3);
    io.press(6, 0);
    io.press(0, 6);
    ticks(&s, 5 * ticks_per_scan);
    try testing.expectEqual(key(6, 0) | key(0, 6), s.frame().keys);
    io.release(6, 0);
    ticks(&s, 5 * ticks_per_scan - 1);
    try testing.expectEqual(key(6, 0) | key(0, 6), s.frame().keys);
    s.tick();
    try testing.expectEqual(key(0, 6), s.frame().keys);
    try testing.expectEqual(@as(u8, 2), s.frame().seq);
}

test "a clockwise detent on ENC2 raises enc[1] by 1 and seq by 1, a counter-clockwise one lowers it" {
    var io = FakeIo{};
    var s = TestScanner.init(&io, 3);
    detent(&io, &s, 1, true);
    try testing.expectEqual([4]u8{ 0, 1, 0, 0 }, s.frame().enc);
    try testing.expectEqual(@as(u8, 1), s.frame().seq);
    detent(&io, &s, 1, false);
    try testing.expectEqual([4]u8{ 0, 0, 0, 0 }, s.frame().enc);
    try testing.expectEqual(@as(u8, 2), s.frame().seq);
    detent(&io, &s, 1, false); // below zero: wraps
    try testing.expectEqual([4]u8{ 0, 255, 0, 0 }, s.frame().enc);
    try testing.expectEqual(@as(u8, 3), s.frame().seq);
}

test "each encoder has its own counter" {
    var io = FakeIo{};
    var s = TestScanner.init(&io, 3);
    detent(&io, &s, 0, true);
    detent(&io, &s, 3, false);
    detent(&io, &s, 3, false);
    detent(&io, &s, 2, true);
    try testing.expectEqual([4]u8{ 1, 0, 1, 254 }, s.frame().enc);
    try testing.expectEqual(@as(u8, 4), s.frame().seq);
}

test "256 clockwise detents bring the counter back to its start" {
    var io = FakeIo{};
    var s = TestScanner.init(&io, 3);
    detent(&io, &s, 1, true);
    try testing.expectEqual(@as(u8, 1), s.frame().enc[1]);
    for (0..256) |_| detent(&io, &s, 1, true);
    try testing.expectEqual(@as(u8, 1), s.frame().enc[1]);
    try testing.expectEqual(@as(u8, 1), s.frame().seq); // 257 changes, wrapping
}

test "clearBooted clears the flag and advances seq once" {
    var io = FakeIo{};
    var s = TestScanner.init(&io, 3);
    s.clearBooted();
    try testing.expect(!s.frame().booted);
    try testing.expectEqual(@as(u8, 1), s.frame().seq);
    s.clearBooted(); // already clear: no change, no new seq
    try testing.expect(!s.frame().booted);
    try testing.expectEqual(@as(u8, 1), s.frame().seq);
}

test "ticks with nothing changing leave seq alone" {
    var io = FakeIo{};
    var s = TestScanner.init(&io, 3);
    ticks(&s, 1000);
    try testing.expectEqual(@as(u8, 0), s.frame().seq);
    io.press(4, 4);
    ticks(&s, 5 * ticks_per_scan);
    try testing.expectEqual(@as(u8, 1), s.frame().seq);
    ticks(&s, 1000); // a key held steady
    io.enc[2] = .{ 0, 0 }; // an encoder resting half-way: no edge, no detent
    ticks(&s, 1000);
    try testing.expectEqual(@as(u8, 1), s.frame().seq);
    try testing.expectEqual(key(4, 4), s.frame().keys);
    try testing.expectEqual([4]u8{ 0, 0, 0, 0 }, s.frame().enc);
}

test "a key change and a detent in the same tick advance seq once" {
    var io = FakeIo{};
    var s = TestScanner.init(&io, 3);
    io.press(3, 1);
    ticks(&s, 5 * ticks_per_scan - 2);
    io.enc[0] = .{ 1, 0 };
    s.tick();
    io.enc[0] = .{ 0, 0 }; // the clockwise detent counts here, on the 5th scan's tick
    s.tick();
    try testing.expectEqual(key(3, 1), s.frame().keys);
    try testing.expectEqual(@as(u8, 1), s.frame().enc[0]);
    try testing.expectEqual(@as(u8, 1), s.frame().seq);
}

test "a matrix read error leaves the key map as it was" {
    var io = FakeIo{};
    var s = TestScanner.init(&io, 3);

    // A press seen only by failed reads never arrives.
    io.press(0, 0);
    io.fail_sense = true;
    ticks(&s, 20 * ticks_per_scan);
    try testing.expectEqual(@as(u64, 0), s.frame().keys);
    try testing.expectEqual(@as(u8, 0), s.frame().seq);

    // A held key is not released by failed reads.
    io.fail_sense = false;
    ticks(&s, 5 * ticks_per_scan);
    try testing.expectEqual(key(0, 0), s.frame().keys);
    try testing.expectEqual(@as(u8, 1), s.frame().seq);
    io.fail_sense = true;
    ticks(&s, 20 * ticks_per_scan);
    try testing.expectEqual(key(0, 0), s.frame().keys);
    try testing.expectEqual(@as(u8, 1), s.frame().seq);

    // Failed reads are no samples: a release still takes 5 good scans.
    io.release(0, 0);
    ticks(&s, 20 * ticks_per_scan);
    io.fail_sense = false;
    ticks(&s, 5 * ticks_per_scan - 1);
    try testing.expectEqual(key(0, 0), s.frame().keys);
    s.tick();
    try testing.expectEqual(@as(u64, 0), s.frame().keys);
    try testing.expectEqual(@as(u8, 2), s.frame().seq);
}

test "setTrial is reported in every frame and does not advance seq" {
    var io = FakeIo{};
    var s = TestScanner.init(&io, 3);
    try testing.expect(!s.frame().trial);
    s.setTrial(true);
    try testing.expect(s.frame().trial);
    try testing.expectEqual(@as(u8, 0), s.frame().seq);

    // It stays through changes of everything else.
    io.press(1, 1);
    ticks(&s, 5 * ticks_per_scan);
    detent(&io, &s, 2, true);
    s.clearBooted();
    try testing.expect(s.frame().trial);
    try testing.expectEqual(proto.Frame{ .fw = 3, .seq = 3, .booted = false, .trial = true, .keys = key(1, 1), .enc = .{ 0, 0, 1, 0 } }, s.frame());

    s.setTrial(false);
    try testing.expect(!s.frame().trial);
    try testing.expectEqual(@as(u8, 3), s.frame().seq);
}

test "the encoders turn while the matrix reads fail" {
    var io = FakeIo{};
    var s = TestScanner.init(&io, 3);
    io.fail_sense = true;
    detent(&io, &s, 0, true);
    try testing.expectEqual(@as(u8, 1), s.frame().enc[0]);
    try testing.expectEqual(@as(u8, 1), s.frame().seq);
}
