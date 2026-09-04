//! Pure PCM conversion between host little-endian samples and the audio float
//! domain, for 16 / 24 / 32-bit (subslot 2 / 3 / 4). The per-width math is a
//! comptime-specialized `iN` + `std.mem.readInt/writeInt` (no hand-rolled
//! shifts); `pcmToFloat`/`floatToPcm` dispatch on the runtime subslot. Leaf
//! module (only `std`) so it runs on the host via `zig test`.
const std = @import("std");

/// The signed integer sample type for a given subslot byte count.
fn Sample(comptime bytes: u8) type {
    return switch (bytes) {
        2 => i16,
        3 => i24,
        4 => i32,
        else => @compileError("unsupported subslot"),
    };
}

/// Full-scale = 2^(bits-1), as f32. Power of two, so /·· and *·· are exact and
/// LLVM lowers the division to a reciprocal multiply.
fn fullScale(comptime T: type) f32 {
    return @floatFromInt(@as(i64, 1) << (@typeInfo(T).int.bits - 1));
}

/// One little-endian sample -> float [-1, 1].
pub fn unpack(comptime bytes: u8, b: *const [bytes]u8) f32 {
    const T = Sample(bytes);
    return @as(f32, @floatFromInt(std.mem.readInt(T, b, .little))) / fullScale(T);
}

// Clamp the float just inside +-1.0 before scaling. This keeps `scaled` within
// the iN range at every width — critical for i32, whose maxInt isn't exactly
// representable in f32 (it rounds up to 2^31 and would overflow @intFromFloat).
const FS_MAX: f32 = 0.9999998;

/// float -> one little-endian sample (saturating).
pub fn pack(comptime bytes: u8, s: f32) [bytes]u8 {
    const T = Sample(bytes);
    const v: T = @intFromFloat(std.math.clamp(s, -FS_MAX, FS_MAX) * fullScale(T));
    var out: [bytes]u8 = undefined;
    std.mem.writeInt(T, &out, v, .little);
    return out;
}

fn toFloat(comptime bytes: u8, pcm_bytes: []const u8, out: []f32) void {
    const avail = pcm_bytes.len / bytes;
    for (out, 0..) |*o, i| {
        o.* = if (i < avail) unpack(bytes, pcm_bytes[i * bytes ..][0..bytes]) else 0;
    }
}

fn fromFloat(comptime bytes: u8, in: []const f32, pcm_bytes: []u8) void {
    std.debug.assert(pcm_bytes.len == in.len * bytes);
    for (in, 0..) |s, i| {
        pcm_bytes[i * bytes ..][0..bytes].* = pack(bytes, s);
    }
}

/// Fill `out` (samples) from interleaved PCM of the given subslot size. Samples
/// beyond the available PCM are set to 0 (host->device underrun -> silence).
pub fn pcmToFloat(subslot: u8, pcm_bytes: []const u8, out: []f32) void {
    switch (subslot) {
        2 => toFloat(2, pcm_bytes, out),
        3 => toFloat(3, pcm_bytes, out),
        4 => toFloat(4, pcm_bytes, out),
        else => unreachable,
    }
}

/// Fill `pcm_bytes` (len == in.len * subslot) from samples.
pub fn floatToPcm(subslot: u8, in: []const f32, pcm_bytes: []u8) void {
    switch (subslot) {
        2 => fromFloat(2, in, pcm_bytes),
        3 => fromFloat(3, in, pcm_bytes),
        4 => fromFloat(4, in, pcm_bytes),
        else => unreachable,
    }
}

test "unpack/pack round-trips interior values at 16/24/32-bit" {
    // 0 and a mid-scale value round-trip exactly at every width.
    inline for (.{ 2, 3, 4 }) |bytes| {
        var zero: [bytes]u8 = @splat(0);
        try std.testing.expectApproxEqAbs(@as(f32, 0), unpack(bytes, &zero), 1e-9);
        // half-scale positive round-trips exactly (exact power-of-two scaling).
        const half = pack(bytes, 0.5);
        try std.testing.expectApproxEqAbs(@as(f32, 0.5), unpack(bytes, &half), 1e-6);
    }
}

test "pack saturates out-of-range floats into range at each width" {
    inline for (.{ 2, 3, 4 }) |bytes| {
        try std.testing.expect(unpack(bytes, &pack(bytes, 2.0)) > 0.99);
        try std.testing.expect(unpack(bytes, &pack(bytes, 2.0)) <= 1.0);
        try std.testing.expect(unpack(bytes, &pack(bytes, -2.0)) < -0.99);
        try std.testing.expect(unpack(bytes, &pack(bytes, -2.0)) >= -1.0);
    }
}

test "pcmToFloat zero-fills on underrun (24-bit)" {
    var out: [4]f32 = .{ 1, 1, 1, 1 };
    const pcm = [_]u8{ 0, 0, 0, 0, 0, 0 }; // 2 samples for a 4-sample request
    pcmToFloat(3, &pcm, &out);
    try std.testing.expectEqual(@as(f32, 0), out[0]);
    try std.testing.expectEqual(@as(f32, 0), out[3]);
}

test "floatToPcm fills exact byte count per subslot" {
    inline for (.{ 2, 3, 4 }) |bytes| {
        var pcm: [2 * bytes]u8 = undefined;
        const in = [_]f32{ 0.0, 0.0 };
        floatToPcm(bytes, &in, &pcm);
        for (pcm) |b| try std.testing.expectEqual(@as(u8, 0), b);
    }
}
