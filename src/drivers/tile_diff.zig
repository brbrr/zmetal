//! The tile diff behind the ILI9341 driver's partial flush. It is std
//! only, so the host tests it.
//!
//! The frame is cut into 50 tiles of 32 by 48 pixels. A tile is sent when
//! its hash changed since the last flush. A caller that knows which part
//! of the frame it drew passes a mask, and only the tiles in the mask are
//! read: the others keep their hash, so a change there is still found by
//! a later flush whose mask holds them.
//!
//! The changed tiles go in runs: tiles that are side by side are one
//! transfer (`firstRun`).

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

/// A group of dirty tiles that one transfer sends: `cols` tiles from tile
/// column `tx`, in `rows` tile rows from row `ty`.
pub const Run = struct {
    tx: u16,
    ty: u16,
    cols: u16,
    rows: u16,

    /// The entries of the dirty list that the run takes.
    pub fn tiles(r: Run) usize {
        return @as(usize, r.cols) * r.rows;
    }
};

/// Gives the run at the start of `list`, the dirty tiles in tile order.
/// `list` is not empty.
///
/// A transfer has a fixed cost: the window commands, and a wait for the
/// two interrupts that end it. So tiles that are side by side go as one
/// transfer. A run of whole tile rows is one part of the frame memory,
/// and it has no limit: the driver sends it from the frame with no copy.
/// A shorter run needs a copy, so it is one row high and at most
/// `max_cols` tiles wide. `max_cols` is 1 or more.
pub fn firstRun(list: []const u16, max_cols: usize) Run {
    const first = list[0];
    const ty = first / TILE_COLS;
    var cols: u16 = 1;
    while (cols < list.len and list[cols] == first + cols and (first + cols) / TILE_COLS == ty) cols += 1;
    if (cols < TILE_COLS) {
        return .{ .tx = first % TILE_COLS, .ty = ty, .cols = @intCast(@min(cols, max_cols)), .rows = 1 };
    }
    // The list has each tile once, in order. So when the last tile of the
    // next row is at its place, the row is whole.
    var rows: u16 = 1;
    while (true) {
        const last = @as(usize, rows + 1) * TILE_COLS - 1;
        if (last >= list.len or list[last] != first + last) break;
        rows += 1;
    }
    return .{ .tx = 0, .ty = ty, .cols = TILE_COLS, .rows = rows };
}

// ============================================================================

const testing = std.testing;

/// Cuts `list` into its runs and gives the count.
fn runsOf(list: []const u16, max_cols: usize, out: []Run) usize {
    var at: usize = 0;
    var n: usize = 0;
    while (at < list.len) : (n += 1) {
        out[n] = firstRun(list[at..], max_cols);
        at += out[n].tiles();
    }
    return n;
}

test "tiles side by side in one row are one run, up to the limit" {
    var out: [TILE_COUNT]Run = undefined;
    // Tiles 12, 13, 14 and 16 of row 1.
    try testing.expectEqual(@as(usize, 2), runsOf(&.{ 12, 13, 14, 16 }, 5, &out));
    try testing.expectEqual(Run{ .tx = 2, .ty = 1, .cols = 3, .rows = 1 }, out[0]);
    try testing.expectEqual(Run{ .tx = 6, .ty = 1, .cols = 1, .rows = 1 }, out[1]);
    // The limit cuts a run of 7 into 5 and 2.
    try testing.expectEqual(@as(usize, 2), runsOf(&.{ 1, 2, 3, 4, 5, 6, 7 }, 5, &out));
    try testing.expectEqual(Run{ .tx = 1, .ty = 0, .cols = 5, .rows = 1 }, out[0]);
    try testing.expectEqual(Run{ .tx = 6, .ty = 0, .cols = 2, .rows = 1 }, out[1]);
}

test "the last tile of a row and the first of the next are two runs" {
    var out: [TILE_COUNT]Run = undefined;
    try testing.expectEqual(@as(usize, 2), runsOf(&.{ 9, 10 }, 5, &out));
    try testing.expectEqual(Run{ .tx = 9, .ty = 0, .cols = 1, .rows = 1 }, out[0]);
    try testing.expectEqual(Run{ .tx = 0, .ty = 1, .cols = 1, .rows = 1 }, out[1]);
}

test "whole rows are one run of any height, and the rest follows" {
    var out: [TILE_COUNT]Run = undefined;
    var all: [TILE_COUNT]u16 = undefined;
    for (&all, 0..) |*t, i| t.* = @intCast(i);
    // The full frame.
    try testing.expectEqual(@as(usize, 1), runsOf(&all, 5, &out));
    try testing.expectEqual(Run{ .tx = 0, .ty = 0, .cols = TILE_COLS, .rows = TILE_ROWS }, out[0]);
    // Rows 1 and 2 whole, then three tiles of row 3.
    try testing.expectEqual(@as(usize, 2), runsOf(all[10..33], 5, &out));
    try testing.expectEqual(Run{ .tx = 0, .ty = 1, .cols = TILE_COLS, .rows = 2 }, out[0]);
    try testing.expectEqual(Run{ .tx = 0, .ty = 3, .cols = 3, .rows = 1 }, out[1]);
    // Nine tiles of a row are not a whole row: 5 and 4.
    try testing.expectEqual(@as(usize, 2), runsOf(all[20..29], 5, &out));
    try testing.expectEqual(Run{ .tx = 0, .ty = 2, .cols = 5, .rows = 1 }, out[0]);
    try testing.expectEqual(Run{ .tx = 5, .ty = 2, .cols = 4, .rows = 1 }, out[1]);
}

test "the runs of a list take each tile once" {
    var prng = std.Random.DefaultPrng.init(7);
    const r = prng.random();
    var out: [TILE_COUNT]Run = undefined;
    for (0..500) |_| {
        var list: [TILE_COUNT]u16 = undefined;
        var n: usize = 0;
        const density = r.intRangeAtMost(u8, 1, 10);
        for (0..TILE_COUNT) |t| if (r.intRangeAtMost(u8, 1, 10) <= density) {
            list[n] = @intCast(t);
            n += 1;
        };
        if (n == 0) continue;
        const max_cols = r.intRangeAtMost(usize, 1, TILE_COLS - 1);
        var seen: Mask = 0;
        for (out[0..runsOf(list[0..n], max_cols, &out)]) |run| {
            try testing.expect(run.cols == TILE_COLS or (run.rows == 1 and run.cols <= max_cols));
            for (0..run.rows) |dy| for (0..run.cols) |dx| {
                const t: u6 = @intCast((run.ty + dy) * TILE_COLS + run.tx + dx);
                try testing.expect(seen & bit(t) == 0);
                seen |= bit(t);
            };
        }
        var want: Mask = 0;
        for (list[0..n]) |t| want |= bit(@intCast(t));
        try testing.expectEqual(want, seen);
    }
}

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
