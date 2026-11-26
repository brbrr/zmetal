//! Debounce for the panel's whole key map, std only so the host tests it.
//!
//! Each key has its own count of samples in a row that disagree with what
//! is reported for it. A sample that agrees resets the count, so a bounce
//! or a glitch shorter than `threshold` samples changes nothing, and a
//! key that chatters reports one change, `threshold` samples after it
//! settles. Presses and releases are treated alike.

const std = @import("std");
const proto = @import("panel_proto.zig");

/// One counter per key: the reported state of a key changes after `threshold`
/// samples in a row that differ from it.
pub fn Debouncer(comptime threshold: u8) type {
    if (threshold == 0) @compileError("a debouncer needs a threshold of at least one sample");

    return struct {
        const Self = @This();

        /// The debounced key map; starts with every key released.
        reported: u64 = 0,
        /// Per key: samples in a row that differed from `reported`, below `threshold`.
        runs: [proto.key_count]u8 = @splat(0),

        /// Feed one sample of all keys (bit n = key n, 1 = pressed), get
        /// the debounced map. Bits 49..63 of `raw` are ignored.
        pub fn update(self: *Self, raw: u64) u64 {
            var differs = (raw ^ self.reported) & proto.key_mask;
            var flips: u64 = 0;
            var mask: u64 = 1;
            for (&self.runs) |*run| {
                if (differs & 1 == 0) {
                    run.* = 0;
                } else {
                    run.* += 1; // below `threshold` before, so it fits a u8
                    if (run.* == threshold) {
                        flips |= mask;
                        run.* = 0;
                    }
                }
                differs >>= 1;
                mask <<= 1;
            }
            self.reported ^= flips;
            return self.reported;
        }

        /// The debounced key map as of the last `update`.
        pub fn state(self: *const Self) u64 {
            return self.reported;
        }
    };
}

// ============================================================================

const testing = std.testing;
const D = Debouncer(5);

fn bit(n: u6) u64 {
    return @as(u64, 1) << n;
}

/// Feeds `raw` `n` times and checks the output stays `want` throughout.
fn feedSteady(d: *D, raw: u64, n: usize, want: u64) !void {
    for (0..n) |_| try testing.expectEqual(want, d.update(raw));
}

test "a key held from sample 1 reads pressed exactly at the 5th update" {
    var d: D = .{};
    try testing.expectEqual(@as(u64, 0), d.state());
    try feedSteady(&d, bit(20), 4, 0);
    try testing.expectEqual(bit(20), d.update(bit(20)));
    try testing.expectEqual(bit(20), d.state());
    try feedSteady(&d, bit(20), 10, bit(20));
}

test "a 4-sample press on a released key changes nothing" {
    var d: D = .{};
    try feedSteady(&d, bit(7), 4, 0);
    try feedSteady(&d, 0, 20, 0);
}

test "a 4-sample gap in a held key changes nothing" {
    var d: D = .{};
    try feedSteady(&d, bit(33), 4, 0);
    try feedSteady(&d, bit(33), 1, bit(33));
    try feedSteady(&d, 0, 4, bit(33)); // the glitch
    try feedSteady(&d, bit(33), 20, bit(33));
}

test "chatter for 4 samples then steady gives one press" {
    var d: D = .{};
    const k = bit(12);
    var transitions: usize = 0;
    var last: u64 = 0;
    for ([_]u64{ k, 0, k, 0 } ++ @as([20]u64, @splat(k))) |raw| {
        const out = d.update(raw);
        if (out != last) transitions += 1;
        last = out;
    }
    try testing.expectEqual(@as(usize, 1), transitions);
    try testing.expectEqual(k, d.state());
}

test "chatter on a held key's release for 4 samples then steady gives one release" {
    var d: D = .{};
    const k = bit(40);
    try feedSteady(&d, k, 4, 0);
    try feedSteady(&d, k, 1, k);
    var transitions: usize = 0;
    var last: u64 = k;
    for ([_]u64{ 0, k, 0, k } ++ @as([20]u64, @splat(0))) |raw| {
        const out = d.update(raw);
        if (out != last) transitions += 1;
        last = out;
    }
    try testing.expectEqual(@as(usize, 1), transitions);
    try testing.expectEqual(@as(u64, 0), d.state());
}

test "two keys with different timings do not influence each other" {
    var d: D = .{};
    const a = bit(0);
    const b = bit(48);
    // a from sample 1, b from sample 3.
    try testing.expectEqual(@as(u64, 0), d.update(a));
    try testing.expectEqual(@as(u64, 0), d.update(a));
    try testing.expectEqual(@as(u64, 0), d.update(a | b));
    try testing.expectEqual(@as(u64, 0), d.update(a | b));
    try testing.expectEqual(a, d.update(a | b)); // a's 5th sample, b's 3rd
    try testing.expectEqual(a, d.update(a | b));
    try testing.expectEqual(a | b, d.update(a | b)); // b's 5th
    // a released while b stays: only a goes, after 5 samples of its own.
    try feedSteady(&d, b, 4, a | b);
    try testing.expectEqual(b, d.update(b));
    try feedSteady(&d, b, 10, b);
}

test "an agreeing sample starts the count again: two 3-sample glitches on a held key change nothing" {
    var d: D = .{};
    try feedSteady(&d, bit(9), 4, 0);
    try feedSteady(&d, bit(9), 1, bit(9));
    try feedSteady(&d, 0, 3, bit(9)); // a glitch
    try feedSteady(&d, bit(9), 10, bit(9));
    try feedSteady(&d, 0, 3, bit(9)); // another: 6 differing samples, never 5 in a row
    try feedSteady(&d, bit(9), 1, bit(9));
}

test "a release takes 5 samples as well" {
    var d: D = .{};
    try feedSteady(&d, bit(25), 4, 0);
    try feedSteady(&d, bit(25), 1, bit(25));
    try feedSteady(&d, 0, 4, bit(25));
    try testing.expectEqual(@as(u64, 0), d.update(0));
    try testing.expectEqual(@as(u64, 0), d.state());
}

test "bits 49 to 63 of the input never show in the output" {
    var d: D = .{};
    try feedSteady(&d, ~proto.key_mask, 20, 0);
    try feedSteady(&d, ~@as(u64, 0), 4, 0);
    try testing.expectEqual(proto.key_mask, d.update(~@as(u64, 0)));
    try feedSteady(&d, ~@as(u64, 0), 20, proto.key_mask);
}
