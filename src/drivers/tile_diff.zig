//! The tile diff behind the ILI9341 driver's partial flush. It is std
//! only, so the host tests it.
//!
//! The frame is cut into 50 tiles of 32 by 48 pixels. A tile is sent when
//! its hash changed since the last flush. A caller that knows which part
//! of the frame it drew passes a mask, and only the tiles in the mask are
//! read: the others keep their hash, so a change there is still found by
//! a later flush whose mask holds them.

const std = @import("std");

pub const WIDTH = 320;
pub const HEIGHT = 240;
pub const TILE_W = 32;
pub const TILE_H = 48;
pub const TILE_COLS = WIDTH / TILE_W; // 10
pub const TILE_ROWS = HEIGHT / TILE_H; // 5
pub const TILE_COUNT = TILE_COLS * TILE_ROWS; // 50
pub const FB_SIZE = WIDTH * HEIGHT * 2;

/// Bit `i` is tile `i`, row-major from the top left.
pub const Mask = u64;
pub const all_tiles: Mask = (@as(Mask, 1) << TILE_COUNT) - 1;

comptime {
    std.debug.assert(WIDTH % TILE_W == 0 and HEIGHT % TILE_H == 0);
    std.debug.assert(TILE_COUNT <= @bitSizeOf(Mask));
}

/// FNV-1a over one tile's rows, a word at a time.
pub fn hash(fb: []const u8, tx: usize, ty: usize) u32 {
    const x0 = tx * TILE_W;
    const y0 = ty * TILE_H;
    var h: u32 = 2166136261;
    var r: usize = 0;
    while (r < TILE_H) : (r += 1) {
        const off = ((y0 + r) * WIDTH + x0) * 2;
        const row = fb[off..][0 .. TILE_W * 2];
        var i: usize = 0;
        while (i < row.len) : (i += 4) {
            const w = std.mem.readInt(u32, row[i..][0..4], .little);
            h = (h ^ w) *% 16777619;
        }
    }
    return h;
}

/// Hashes the tiles in `mask`, stores their hashes, and lists in `out`
/// the ones whose hash changed, in tile order. Returns the count. With
/// `valid` false the stored hashes mean nothing: every tile is hashed
/// and listed, whatever the mask.
pub fn collect(fb: []const u8, hashes: *[TILE_COUNT]u32, valid: bool, mask: Mask, out: *[TILE_COUNT]u16) usize {
    const m = if (valid) mask else all_tiles;
    var n: usize = 0;
    var idx: u16 = 0;
    while (idx < TILE_COUNT) : (idx += 1) {
        if (m & (@as(Mask, 1) << @intCast(idx)) == 0) continue;
        const h = hash(fb, idx % TILE_COLS, idx / TILE_COLS);
        if (!valid or h != hashes[idx]) {
            hashes[idx] = h;
            out[n] = idx;
            n += 1;
        }
    }
    return n;
}

// ============================================================================

const testing = std.testing;

const Fixture = struct {
    fb: [FB_SIZE]u8 = @splat(0),
    hashes: [TILE_COUNT]u32 = @splat(0),
    out: [TILE_COUNT]u16 = undefined,

    fn touch(f: *Fixture, x: usize, y: usize) void {
        f.fb[(y * WIDTH + x) * 2] +%= 1;
    }

    fn run(f: *Fixture, valid: bool, mask: Mask) []const u16 {
        return f.out[0..collect(&f.fb, &f.hashes, valid, mask, &f.out)];
    }
};

fn bit(i: u6) Mask {
    return @as(Mask, 1) << i;
}

test "with no valid hashes every tile is listed, whatever the mask" {
    var f = Fixture{};
    const got = f.run(false, bit(3));
    try testing.expectEqual(@as(usize, TILE_COUNT), got.len);
    for (got, 0..) |t, i| try testing.expectEqual(@as(u16, @intCast(i)), t);
    try testing.expectEqual(@as(usize, 0), f.run(true, all_tiles).len);
}

test "a changed pixel lists its tile only" {
    var f = Fixture{};
    _ = f.run(false, all_tiles);
    f.touch(3 * TILE_W + 5, 1 * TILE_H + 7); // tile 13
    try testing.expectEqualSlices(u16, &.{13}, f.run(true, all_tiles));
    try testing.expectEqual(@as(usize, 0), f.run(true, all_tiles).len);
}

test "a change outside the mask waits for a mask that holds its tile" {
    var f = Fixture{};
    _ = f.run(false, all_tiles);
    f.touch(3 * TILE_W, TILE_H); // tile 13
    try testing.expectEqual(@as(usize, 0), f.run(true, bit(12) | bit(14)).len);
    try testing.expectEqualSlices(u16, &.{13}, f.run(true, bit(13)));
}

test "only the masked tiles of several changed ones are listed, in tile order" {
    var f = Fixture{};
    _ = f.run(false, all_tiles);
    f.touch(0, 0); // tile 0
    f.touch(WIDTH - 1, HEIGHT - 1); // tile 49
    f.touch(9 * TILE_W, 2 * TILE_H); // tile 29
    try testing.expectEqualSlices(u16, &.{ 29, 49 }, f.run(true, bit(49) | bit(29)));
    try testing.expectEqualSlices(u16, &.{0}, f.run(true, all_tiles));
}

test "the edge pixels of a tile belong to it and not to its neighbours" {
    var f = Fixture{};
    _ = f.run(false, all_tiles);
    f.touch(TILE_W - 1, TILE_H - 1); // last pixel of tile 0
    try testing.expectEqualSlices(u16, &.{0}, f.run(true, all_tiles));
    f.touch(TILE_W, 0); // first pixel of tile 1
    try testing.expectEqualSlices(u16, &.{1}, f.run(true, all_tiles));
}
