//! What sets one display controller apart from another behind the same
//! SPI driver: the sequence that follows the hardware reset, the order of
//! the sub-pixels and the direction the glass is wired in. It is std only,
//! so the host tests it.

const std = @import("std");

/// One entry of an init sequence: a command with its parameters, or a wait.
pub const Step = union(enum) {
    command: struct { op: u8, params: []const u8 = &.{} },
    delay_ms: u16,
};

pub const Panel = struct {
    /// What follows the hardware reset: commands and the waits between them.
    init: []const Step,
    /// MADCTL bit 3: the panel's sub-pixels are wired blue-green-red.
    bgr: bool,
    /// The glass is wired with its X direction reversed (true for ILI9341 modules).
    mirror_x: bool,
};

pub const Orientation = enum {
    Portrait,
    Landscape,
    PortraitFlipped,
    LandscapeFlipped,
};

/// The ILI9341 modules zmetal has driven since the start: the sequence is
/// the one the driver sent before it became data, byte for byte.
pub const ili9341: Panel = .{
    .init = &.{
        .{ .command = .{ .op = 0x01 } }, // SWRESET
        .{ .delay_ms = 100 },
        .{ .command = .{ .op = 0xCB, .params = &.{ 0x39, 0x2C, 0x00, 0x34, 0x02 } } }, // power control A
        .{ .command = .{ .op = 0xCF, .params = &.{ 0x00, 0xC1, 0x30 } } }, // power control B
        .{ .command = .{ .op = 0xE8, .params = &.{ 0x85, 0x00, 0x78 } } }, // driver timing control A
        .{ .command = .{ .op = 0xEA, .params = &.{ 0x00, 0x00 } } }, // driver timing control B
        .{ .command = .{ .op = 0xED, .params = &.{ 0x64, 0x03, 0x12, 0x81 } } }, // power-on sequence
        .{ .command = .{ .op = 0xF7, .params = &.{0x20} } }, // pump ratio
        .{ .command = .{ .op = 0xC0, .params = &.{0x23} } }, // PWCTR1
        .{ .command = .{ .op = 0xC1, .params = &.{0x10} } }, // PWCTR2
        .{ .command = .{ .op = 0xC5, .params = &.{ 0x3E, 0x28 } } }, // VMCTR1
        .{ .command = .{ .op = 0xC7, .params = &.{0x86} } }, // VMCTR2
        .{ .command = .{ .op = 0x36, .params = &.{0x48} } }, // MADCTL: madctl(ili9341, .Portrait)
        .{ .command = .{ .op = 0x3A, .params = &.{0x55} } }, // PIXFMT: 16-bit pixels
        .{ .command = .{ .op = 0xB1, .params = &.{ 0x00, 0x18 } } }, // FRMCTR1
        .{ .command = .{ .op = 0xB6, .params = &.{ 0x08, 0x82, 0x27 } } }, // DFUNCTR
        .{ .command = .{ .op = 0xF2, .params = &.{0x00} } }, // 3-gamma off
        .{ .command = .{ .op = 0x26, .params = &.{0x01} } }, // GAMMASET: curve 1
        .{ .command = .{ .op = 0xE0, .params = &.{
            0x0F, 0x31, 0x2B, 0x0C, 0x0E, 0x08, 0x4E, 0xF1,
            0x37, 0x07, 0x10, 0x03, 0x0E, 0x09, 0x00,
        } } }, // GMCTRP1: positive gamma
        .{ .command = .{ .op = 0xE1, .params = &.{
            0x00, 0x0E, 0x14, 0x03, 0x11, 0x07, 0x31, 0xC1,
            0x48, 0x08, 0x0F, 0x0C, 0x31, 0x36, 0x0F,
        } } }, // GMCTRN1: negative gamma
        .{ .command = .{ .op = 0x11 } }, // SLPOUT
        .{ .delay_ms = 120 },
        .{ .command = .{ .op = 0x29 } }, // DISPON
        .{ .delay_ms = 100 },
    },
    .bgr = true,
    .mirror_x = true,
};

/// An ST7789(V) panel, 240 by 320.
///
/// No power, porch or gamma register is written: the controller keeps its
/// power-on values there. COLMOD is set to 16-bit pixels, which is not the
/// default (18 bits). The panel maker's values were not available;
/// [DISPLAY] A.5 (the v3-drivers display research) lists the voltage,
/// porch and gamma blocks other drivers send, to try if the picture needs
/// it.
///
/// None of `bgr`, `mirror_x` or inversion was measured on this panel; the
/// first board settles them. `mirror_x = false` is what every reference in
/// [DISPLAY] A.5 that gives a MADCTL value does (Linux DRM, fbtft,
/// Adafruit; TFT_eSPI's colour-order macro and Zephyr's devicetree value
/// are not given there), and microzig's st77xx driver too. RGB order and
/// inversion on are what most do: Adafruit sets BGR, and the datasheet's
/// default, microzig's default (`display_inversion = false`) and one Linux
/// DRM panel (t28cp45tn89) leave inversion off.
pub const st7789: Panel = .{
    .init = &.{
        .{ .command = .{ .op = 0x01 } }, // SWRESET
        .{ .delay_ms = 120 },
        .{ .command = .{ .op = 0x11 } }, // SLPOUT
        .{ .delay_ms = 120 },
        .{ .command = .{ .op = 0x3A, .params = &.{0x55} } }, // COLMOD: 16-bit pixels
        .{ .command = .{ .op = 0x36, .params = &.{0x00} } }, // MADCTL: madctl(st7789, .Portrait)
        .{ .command = .{ .op = 0x21 } }, // INVON
        .{ .command = .{ .op = 0x13 } }, // NORON
        .{ .command = .{ .op = 0x29 } }, // DISPON
        .{ .delay_ms = 20 },
    },
    .bgr = false,
    .mirror_x = false,
};

const MADCTL_MY: u8 = 0x80;
const MADCTL_MX: u8 = 0x40;
const MADCTL_MV: u8 = 0x20;
const MADCTL_BGR: u8 = 0x08;

/// MADCTL for an orientation. Bits (the same on both controllers): MY 0x80,
/// MX 0x40, MV 0x20, BGR 0x08. Unmirrored: Portrait 0x00, Landscape MV|MX,
/// PortraitFlipped MX|MY, LandscapeFlipped MV|MY; `mirror_x` toggles MX;
/// `bgr` adds 0x08.
pub fn madctl(panel: Panel, orientation: Orientation) u8 {
    const unmirrored: u8 = switch (orientation) {
        .Portrait => 0,
        .Landscape => MADCTL_MV | MADCTL_MX,
        .PortraitFlipped => MADCTL_MX | MADCTL_MY,
        .LandscapeFlipped => MADCTL_MV | MADCTL_MY,
    };
    const mx: u8 = if (panel.mirror_x) MADCTL_MX else 0;
    const bgr: u8 = if (panel.bgr) MADCTL_BGR else 0;
    return (unmirrored ^ mx) | bgr;
}

/// True when `panel.init` sets MADCTL (0x36) and every MADCTL step in it
/// carries `madctl(panel, .Portrait)`, the orientation a driver records
/// after running the table. A panel copied with `bgr` or `mirror_x`
/// changed but its table's MADCTL step left as it was fails this.
pub fn madctlAgrees(panel: Panel) bool {
    var found = false;
    for (panel.init) |step| switch (step) {
        .command => |c| if (c.op == 0x36) {
            if (c.params.len != 1 or c.params[0] != madctl(panel, .Portrait)) return false;
            found = true;
        },
        .delay_ms => {},
    };
    return found;
}

/// Sends `steps` to `sink`: each command, then its parameters when it has
/// some, and the waits. A command without parameters gets no `data` call
/// (no data phase on the wire), as the ILI9341 driver always sent it.
///
/// `sink` has `command(op: u8) !void`, `data(params: []const u8) !void`
/// and `delayMs(ms: u16) void`.
pub fn run(steps: []const Step, sink: anytype) !void {
    for (steps) |step| switch (step) {
        .command => |c| {
            try sink.command(c.op);
            if (c.params.len > 0) try sink.data(c.params);
        },
        .delay_ms => |ms| sink.delayMs(ms),
    };
}

// ============================================================
// Tests
// ============================================================

fn expectSteps(expected: []const Step, actual: []const Step) !void {
    for (expected, 0..) |e, i| {
        errdefer std.debug.print("step {d} differs\n", .{i});
        if (i >= actual.len) return error.TestExpectedEqual;
        const a = actual[i];
        try std.testing.expectEqual(std.meta.activeTag(e), std.meta.activeTag(a));
        switch (e) {
            .command => |c| {
                try std.testing.expectEqual(c.op, a.command.op);
                try std.testing.expectEqualSlices(u8, c.params, a.command.params);
            },
            .delay_ms => |ms| try std.testing.expectEqual(ms, a.delay_ms),
        }
    }
    try std.testing.expectEqual(expected.len, actual.len);
}

/// `init_display` in `ili9341.zig` as it was before the sequence became
/// data (commit 33a22dc), from the first command after `self.reset()` to
/// the end. Each entry names the source line it came from and the old
/// `Command` enum name of its opcode.
const ili9341_before = [_]Step{
    .{ .command = .{ .op = 0x01 } }, // 91 SWRESET
    .{ .delay_ms = 100 }, // 92
    .{ .command = .{ .op = 0xCB, .params = &.{ 0x39, 0x2C, 0x00, 0x34, 0x02 } } }, // 94-95 PWCTRA
    .{ .command = .{ .op = 0xCF, .params = &.{ 0x00, 0xC1, 0x30 } } }, // 97-98 PWCTRB
    .{ .command = .{ .op = 0xE8, .params = &.{ 0x85, 0x00, 0x78 } } }, // 100-101 DTCA
    .{ .command = .{ .op = 0xEA, .params = &.{ 0x00, 0x00 } } }, // 103-104 DTCB
    .{ .command = .{ .op = 0xED, .params = &.{ 0x64, 0x03, 0x12, 0x81 } } }, // 106-107 POWER_SEQ
    .{ .command = .{ .op = 0xF7, .params = &.{0x20} } }, // 109-110 PUMP_RATIO
    .{ .command = .{ .op = 0xC0, .params = &.{0x23} } }, // 112-113 PWCTR1
    .{ .command = .{ .op = 0xC1, .params = &.{0x10} } }, // 115-116 PWCTR2
    .{ .command = .{ .op = 0xC5, .params = &.{ 0x3E, 0x28 } } }, // 118-119 VMCTR1
    .{ .command = .{ .op = 0xC7, .params = &.{0x86} } }, // 121-122 VMCTR2
    .{ .command = .{ .op = 0x36, .params = &.{0x48} } }, // 124-125 MADCTL
    .{ .command = .{ .op = 0x3A, .params = &.{0x55} } }, // 127-128 PIXFMT
    .{ .command = .{ .op = 0xB1, .params = &.{ 0x00, 0x18 } } }, // 130-131 FRMCTR1
    .{ .command = .{ .op = 0xB6, .params = &.{ 0x08, 0x82, 0x27 } } }, // 133-134 DFUNCTR
    .{ .command = .{ .op = 0xF2, .params = &.{0x00} } }, // 136-137 ENABLE_3G
    .{ .command = .{ .op = 0x26, .params = &.{0x01} } }, // 139-140 GAMMASET
    .{ .command = .{ .op = 0xE0, .params = &.{
        0x0F, 0x31, 0x2B, 0x0C, 0x0E, 0x08, 0x4E, 0xF1,
        0x37, 0x07, 0x10, 0x03, 0x0E, 0x09, 0x00,
    } } }, // 142-146 GMCTRP1
    .{ .command = .{ .op = 0xE1, .params = &.{
        0x00, 0x0E, 0x14, 0x03, 0x11, 0x07, 0x31, 0xC1,
        0x48, 0x08, 0x0F, 0x0C, 0x31, 0x36, 0x0F,
    } } }, // 148-152 GMCTRN1
    .{ .command = .{ .op = 0x11 } }, // 154 SLPOUT
    .{ .delay_ms = 120 }, // 155
    .{ .command = .{ .op = 0x29 } }, // 157 DISPON
    .{ .delay_ms = 100 }, // 158
};

test "the ILI9341 table is the sequence the driver sent before" {
    try expectSteps(&ili9341_before, ili9341.init);
    try std.testing.expect(ili9341.bgr);
    try std.testing.expect(ili9341.mirror_x);
}

test "the ST7789 table: reset, sleep out, 16-bit pixels, MADCTL, inversion on, normal mode, display on" {
    const expected = [_]Step{
        .{ .command = .{ .op = 0x01 } }, // SWRESET
        .{ .delay_ms = 120 },
        .{ .command = .{ .op = 0x11 } }, // SLPOUT
        .{ .delay_ms = 120 },
        .{ .command = .{ .op = 0x3A, .params = &.{0x55} } }, // COLMOD: 16-bit pixels
        .{ .command = .{ .op = 0x36, .params = &.{0x00} } }, // MADCTL for .Portrait
        .{ .command = .{ .op = 0x21 } }, // INVON
        .{ .command = .{ .op = 0x13 } }, // NORON
        .{ .command = .{ .op = 0x29 } }, // DISPON
        .{ .delay_ms = 20 },
    };
    try expectSteps(&expected, st7789.init);
    try std.testing.expect(!st7789.bgr);
    try std.testing.expect(!st7789.mirror_x);
}

test "madctl: the ILI9341 values the driver computed before, and microzig's ST7789 values" {
    // ili9341.zig set_orientation before the sequence became data.
    try std.testing.expectEqual(@as(u8, 0x48), madctl(ili9341, .Portrait));
    try std.testing.expectEqual(@as(u8, 0x28), madctl(ili9341, .Landscape));
    try std.testing.expectEqual(@as(u8, 0x88), madctl(ili9341, .PortraitFlipped));
    try std.testing.expectEqual(@as(u8, 0xE8), madctl(ili9341, .LandscapeFlipped));
    // microzig drivers/src/display/st77xx.zig AddressOrder deg0/90/180/270.
    try std.testing.expectEqual(@as(u8, 0x00), madctl(st7789, .Portrait));
    try std.testing.expectEqual(@as(u8, 0x60), madctl(st7789, .Landscape));
    try std.testing.expectEqual(@as(u8, 0xC0), madctl(st7789, .PortraitFlipped));
    try std.testing.expectEqual(@as(u8, 0xA0), madctl(st7789, .LandscapeFlipped));
}

test "each table's own MADCTL is the one for the orientation the driver records after init" {
    for ([_]Panel{ ili9341, st7789 }) |panel| {
        var found: usize = 0;
        for (panel.init) |step| switch (step) {
            .command => |c| if (c.op == 0x36) {
                try std.testing.expectEqualSlices(u8, &.{madctl(panel, .Portrait)}, c.params);
                found += 1;
            },
            .delay_ms => {},
        };
        try std.testing.expectEqual(@as(usize, 1), found);
    }
}

test "a table's MADCTL must match the panel's flags" {
    try std.testing.expect(madctlAgrees(ili9341));
    try std.testing.expect(madctlAgrees(st7789));
    // The table copied, a flag flipped, the MADCTL step left as it was.
    var bgr = st7789;
    bgr.bgr = true;
    try std.testing.expect(!madctlAgrees(bgr));
    var mirrored = st7789;
    mirrored.mirror_x = true;
    try std.testing.expect(!madctlAgrees(mirrored));
    // The same copy with its MADCTL step changed to match: 0x00 ^ MX | BGR.
    var both = st7789;
    both.bgr = true;
    both.mirror_x = true;
    const steps = [_]Step{
        .{ .command = .{ .op = 0x01 } },
        .{ .command = .{ .op = 0x36, .params = &.{0x48} } },
    };
    both.init = &steps;
    try std.testing.expect(madctlAgrees(both));
    // A table that never sets MADCTL leaves the controller's own value,
    // which nothing ties to the flags.
    both.init = steps[0..1];
    try std.testing.expect(!madctlAgrees(both));
    // A second MADCTL step that disagrees.
    const twice = [_]Step{
        .{ .command = .{ .op = 0x36, .params = &.{0x48} } },
        .{ .command = .{ .op = 0x36, .params = &.{0x00} } },
    };
    both.init = &twice;
    try std.testing.expect(!madctlAgrees(both));
}

/// What a sink saw, in order: the calls `run` made.
const Call = union(enum) {
    command: u8,
    data: []const u8,
    delay_ms: u16,
};

/// Records the calls; when full it keeps no more and says so, so that a
/// `run` making too many calls fails a test instead of writing past
/// `calls`.
const Recorder = struct {
    calls: [64]Call = undefined,
    len: usize = 0,
    /// A call came while `calls` was full and was not recorded.
    overflowed: bool = false,

    pub fn command(r: *Recorder, op: u8) !void {
        try r.push(.{ .command = op });
    }
    pub fn data(r: *Recorder, params: []const u8) !void {
        try r.push(.{ .data = params });
    }
    pub fn delayMs(r: *Recorder, ms: u16) void {
        r.push(.{ .delay_ms = ms }) catch {}; // `delayMs` cannot fail; `overflowed` keeps it
    }
    fn push(r: *Recorder, c: Call) error{RecorderFull}!void {
        if (r.len == r.calls.len) {
            r.overflowed = true;
            return error.RecorderFull;
        }
        r.calls[r.len] = c;
        r.len += 1;
    }
    fn count(r: *const Recorder, tag: std.meta.Tag(Call)) usize {
        var n: usize = 0;
        for (r.calls[0..r.len]) |c| {
            if (std.meta.activeTag(c) == tag) n += 1;
        }
        return n;
    }
    /// The calls are `expected`, each of the same kind as expected before
    /// its fields are read.
    fn expectCalls(r: *const Recorder, expected: []const Call) !void {
        try std.testing.expect(!r.overflowed);
        for (expected, 0..) |e, i| {
            errdefer std.debug.print("call {d} differs\n", .{i});
            if (i >= r.len) return error.TestExpectedEqual;
            const a = r.calls[i];
            try std.testing.expectEqual(std.meta.activeTag(e), std.meta.activeTag(a));
            switch (e) {
                .command => |op| try std.testing.expectEqual(op, a.command),
                .data => |p| try std.testing.expectEqualSlices(u8, p, a.data),
                .delay_ms => |ms| try std.testing.expectEqual(ms, a.delay_ms),
            }
        }
        try std.testing.expectEqual(expected.len, r.len);
    }
};

test "run sends each command, then its parameters only when it has some, and the waits" {
    const steps = [_]Step{
        .{ .command = .{ .op = 0x01 } },
        .{ .delay_ms = 5 },
        .{ .command = .{ .op = 0x3A, .params = &.{0x55} } },
        .{ .command = .{ .op = 0x2A, .params = &.{ 0x00, 0x00, 0x01, 0x3F } } },
        .{ .command = .{ .op = 0x29 } },
    };
    var rec: Recorder = .{};
    try run(&steps, &rec);
    try rec.expectCalls(&.{
        .{ .command = 0x01 },
        .{ .delay_ms = 5 },
        .{ .command = 0x3A },
        .{ .data = &.{0x55} },
        .{ .command = 0x2A },
        .{ .data = &.{ 0x00, 0x00, 0x01, 0x3F } },
        .{ .command = 0x29 },
    });
}

test "running the ILI9341 table makes the calls init_display made" {
    var rec: Recorder = .{};
    try run(ili9341.init, &rec);
    try std.testing.expect(!rec.overflowed);
    // The old init_display after reset(): 21 send_command, 18 send_data
    // and 3 delay_ms calls; SWRESET, SLPOUT and DISPON had no send_data.
    try std.testing.expectEqual(@as(usize, 21), rec.count(.command));
    try std.testing.expectEqual(@as(usize, 18), rec.count(.data));
    try std.testing.expectEqual(@as(usize, 3), rec.count(.delay_ms));
    // In order: each command of the old code, then its data when the old
    // code sent some, and the waits where it waited.
    var expected: [64]Call = undefined;
    var n: usize = 0;
    for (ili9341_before) |step| switch (step) {
        .command => |c| {
            expected[n] = .{ .command = c.op };
            n += 1;
            if (c.params.len > 0) {
                expected[n] = .{ .data = c.params };
                n += 1;
            }
        },
        .delay_ms => |ms| {
            expected[n] = .{ .delay_ms = ms };
            n += 1;
        },
    };
    try rec.expectCalls(expected[0..n]);
}

test "running the ST7789 table sends parameters to COLMOD and MADCTL only" {
    var rec: Recorder = .{};
    try run(st7789.init, &rec);
    try rec.expectCalls(&.{
        .{ .command = 0x01 },
        .{ .delay_ms = 120 },
        .{ .command = 0x11 },
        .{ .delay_ms = 120 },
        .{ .command = 0x3A },
        .{ .data = &.{0x55} },
        .{ .command = 0x36 },
        .{ .data = &.{0x00} },
        .{ .command = 0x21 },
        .{ .command = 0x13 },
        .{ .command = 0x29 },
        .{ .delay_ms = 20 },
    });
}
