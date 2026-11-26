//! The link between the panel scanner (an STM32C031) and the Daisy: the
//! 16-byte state frame the scanner answers to every read, and the commands
//! the Daisy writes. std only, so both ends and the host tests share it.
//!
//! Read (plain, no register address; the Daisy reads 16 bytes, bytes past
//! 15 read 0xFF). The frame is a snapshot taken at the address match:
//!
//! | byte  | field   | meaning                                                  |
//! |-------|---------|----------------------------------------------------------|
//! | 0     | `proto` | 0x01; a client that reads another value stops there      |
//! | 1     | `fw`    | scanner firmware number                                  |
//! | 2     | `seq`   | advanced (wrapping) on every change of bytes 3-14        |
//! | 3     | `flags` | bit 0 `booted`: set at start-up, cleared by 0x01;        |
//! |       |         | bit 1 `trial`: running from an uncommitted image;        |
//! |       |         | bits 2-7 are sent as 0 and ignored when read             |
//! | 4-10  | `keys`  | key n at bit n % 8 of byte 4 + n / 8; 1 = pressed        |
//! | 11-14 | `enc`   | ENC1-4 detent counters, +1 clockwise, wrapping           |
//! | 15    | `crc`   | CRC-8 (polynomial 0x07, initial 0) of bytes 0-14         |
//!
//! Write (exact lengths; anything else is ignored):
//!
//! | bytes            | command                                            |
//! |------------------|----------------------------------------------------|
//! | `0x01`           | clear `booted`                                     |
//! | `0x02 <seq>`     | acknowledge: the host has read and accepted `seq`  |
//! | `0xB0 0x07 0x5A` | enter the ROM bootloader                           |
//!
//! INT (open-drain, active low) is low while the scanner's current `seq`
//! differs from the last acknowledged one, and from start-up until the
//! first acknowledge. Reading a frame does not change it: only the host's
//! acknowledge does, so it does not depend on how the target's peripheral
//! counts the bytes it sends.

const std = @import("std");

pub const address: u7 = 0x42;
pub const proto_version: u8 = 1;
pub const frame_len = 16;
pub const rows = 7;
pub const cols = 7;
pub const key_count = 49;
pub const encoder_count = 4;

/// The state of the panel as one frame. `encode` puts it on the wire,
/// `decode` takes it back.
pub const Frame = struct {
    /// The scanner's firmware number, set at build time.
    fw: u8,
    /// Advanced (wrapping) on every change of `booted`, `keys` or `enc`.
    seq: u8,
    /// Set at start-up, cleared by the `clear_booted` command.
    booted: bool,
    /// The scanner runs from an image that is not committed: its first
    /// flash location read erased at start-up.
    trial: bool = false,
    keys: u64, // bit n = key n; bits 49..63 are 0
    /// One wrapping detent counter per encoder: +1 clockwise, -1 counter-clockwise.
    enc: [encoder_count]u8,
};

/// The bits of `Frame.keys` that name a key.
pub const key_mask: u64 = (@as(u64, 1) << key_count) - 1;

const flag_booted: u8 = 0x01;
const flag_trial: u8 = 0x02;
const keys_offset = 4;
const keys_len = 7; // 49 bits
const enc_offset = keys_offset + keys_len;
const crc_offset = frame_len - 1;

comptime {
    std.debug.assert(enc_offset + encoder_count == crc_offset);
    std.debug.assert(keys_len * 8 >= key_count);
}

/// CRC-8 with polynomial 0x07, initial value 0, no reflection, no final XOR.
pub fn crc8(bytes: []const u8) u8 {
    var crc: u8 = 0;
    for (bytes) |b| {
        crc ^= b;
        for (0..8) |_| {
            crc = if (crc & 0x80 != 0) (crc << 1) ^ 0x07 else crc << 1;
        }
    }
    return crc;
}

/// The frame as the scanner sends it. Bits of `keys` above key 48 are dropped.
pub fn encode(f: Frame) [frame_len]u8 {
    var b: [frame_len]u8 = undefined;
    b[0] = proto_version;
    b[1] = f.fw;
    b[2] = f.seq;
    b[3] = (if (f.booted) flag_booted else 0) | (if (f.trial) flag_trial else 0);
    std.mem.writeInt(u56, b[keys_offset..][0..keys_len], @intCast(f.keys & key_mask), .little);
    b[enc_offset..][0..encoder_count].* = f.enc;
    b[crc_offset] = crc8(b[0..crc_offset]);
    return b;
}

pub const DecodeError = error{ WrongProtocol, BadCrc };

/// The frame in `bytes`, or why it cannot be used. The protocol byte is
/// checked first: a frame of another protocol is not interpreted further.
/// Only the defined bits are taken: bits 0 (`booted`) and 1 (`trial`) of
/// the flags, keys 0..48. Flag bits 2..7 are ignored, so a frame with any
/// of them set still decodes.
pub fn decode(bytes: *const [frame_len]u8) DecodeError!Frame {
    if (bytes[0] != proto_version) return error.WrongProtocol;
    if (crc8(bytes[0..crc_offset]) != bytes[crc_offset]) return error.BadCrc;
    return .{
        .fw = bytes[1],
        .seq = bytes[2],
        .booted = bytes[3] & flag_booted != 0,
        .trial = bytes[3] & flag_trial != 0,
        .keys = std.mem.readInt(u56, bytes[keys_offset..][0..keys_len], .little) & key_mask,
        .enc = bytes[enc_offset..][0..encoder_count].*,
    };
}

pub const Command = union(enum) {
    clear_booted,
    enter_bootloader,
    /// The host has read and accepted the state with this `seq`.
    ack: u8,
};

/// The longest command write, in bytes.
pub const max_command_len = 3;

const clear_booted_bytes = [_]u8{0x01};
const enter_bootloader_bytes = [_]u8{ 0xB0, 0x07, 0x5A };
const ack_opcode: u8 = 0x02;

/// The bytes of a command write, in `buf`.
pub fn encodeCommand(c: Command, buf: *[max_command_len]u8) []const u8 {
    switch (c) {
        .clear_booted => {
            buf[0..clear_booted_bytes.len].* = clear_booted_bytes;
            return buf[0..clear_booted_bytes.len];
        },
        .enter_bootloader => {
            buf[0..enter_bootloader_bytes.len].* = enter_bootloader_bytes;
            return buf[0..enter_bootloader_bytes.len];
        },
        .ack => |seq| {
            buf[0..2].* = .{ ack_opcode, seq };
            return buf[0..2];
        },
    }
}

/// The command a complete write carries: its bytes must match exactly, so
/// a prefix of a command, or a command with bytes after it, is null.
pub fn decodeCommand(bytes: []const u8) ?Command {
    if (std.mem.eql(u8, bytes, &clear_booted_bytes)) return .clear_booted;
    if (std.mem.eql(u8, bytes, &enter_bootloader_bytes)) return .enter_bootloader;
    if (bytes.len == 2 and bytes[0] == ack_opcode) return .{ .ack = bytes[1] };
    return null;
}

/// The key number on the wire: `row * 7 + col`, row and col below 7.
pub fn keyIndex(row: u3, col: u3) u6 {
    std.debug.assert(row < rows and col < cols);
    return @as(u6, row) * cols + col;
}

// ============================================================================

test "CRC-8 check value" {
    try std.testing.expectEqual(@as(u8, 0xF4), crc8("123456789"));
}
test "a frame on the wire" {
    const f = Frame{ .fw = 3, .seq = 5, .booted = true, .keys = (1 << 0) | (1 << 48), .enc = .{ 1, 255, 0, 7 } };
    const want = [16]u8{ 0x01, 0x03, 0x05, 0x01, 0x01, 0, 0, 0, 0, 0, 0x01, 0x01, 0xFF, 0x00, 0x07, 0x5F };
    try std.testing.expectEqualSlices(u8, &want, &encode(f));
    try std.testing.expectEqual(f, try decode(&want));
}
test "more frames" {
    const idle = [16]u8{ 0x01, 0x03, 0x00, 0x01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xC0 };
    try std.testing.expectEqualSlices(u8, &idle, &encode(.{ .fw = 3, .seq = 0, .booted = true, .keys = 0, .enc = .{ 0, 0, 0, 0 } }));
    const f2 = Frame{ .fw = 3, .seq = 6, .booted = false, .keys = (1 << 8) | (1 << 9) | (1 << 30), .enc = .{ 2, 255, 0, 7 } };
    const w2 = [16]u8{ 0x01, 0x03, 0x06, 0x00, 0x00, 0x03, 0x00, 0x40, 0, 0, 0, 0x02, 0xFF, 0x00, 0x07, 0x9A };
    try std.testing.expectEqualSlices(u8, &w2, &encode(f2));
}
test "a damaged or foreign frame is refused" {
    var b = encode(.{ .fw = 3, .seq = 5, .booted = false, .keys = 1, .enc = .{ 0, 0, 0, 0 } });
    b[6] ^= 0x10;
    try std.testing.expectError(error.BadCrc, decode(&b));
    var other = encode(.{ .fw = 3, .seq = 5, .booted = false, .keys = 1, .enc = .{ 0, 0, 0, 0 } });
    other[0] = 2;
    other[15] = crc8(other[0..15]);
    try std.testing.expectError(error.WrongProtocol, decode(&other));
    const floating: [16]u8 = @splat(0xFF); // nobody on the bus
    try std.testing.expect(std.meta.isError(decode(&floating)));
}
test "encode masks the bits no key has" {
    const b = encode(.{ .fw = 0, .seq = 0, .booted = false, .keys = ~@as(u64, 0), .enc = .{ 0, 0, 0, 0 } });
    try std.testing.expectEqual(@as(u8, 0x01), b[10]);
}
test "commands" {
    var buf: [3]u8 = undefined;
    try std.testing.expectEqualSlices(u8, &.{0x01}, encodeCommand(.clear_booted, &buf));
    try std.testing.expectEqualSlices(u8, &.{ 0xB0, 0x07, 0x5A }, encodeCommand(.enter_bootloader, &buf));
    try std.testing.expectEqual(@as(?Command, .clear_booted), decodeCommand(&.{0x01}));
    try std.testing.expectEqual(@as(?Command, .enter_bootloader), decodeCommand(&.{ 0xB0, 0x07, 0x5A }));
    try std.testing.expectEqual(@as(?Command, null), decodeCommand(&.{ 0xB0, 0x07 }));
    try std.testing.expectEqual(@as(?Command, null), decodeCommand(&.{0xB0}));
    try std.testing.expectEqual(@as(?Command, null), decodeCommand(&.{}));
    try std.testing.expectEqual(@as(?Command, null), decodeCommand(&.{0x55}));
}
test "the acknowledge command is 0x02 and the sequence number, exactly two bytes" {
    var buf: [3]u8 = undefined;
    try std.testing.expectEqualSlices(u8, &.{ 0x02, 0x37 }, encodeCommand(.{ .ack = 0x37 }, &buf));
    try std.testing.expectEqual(@as(?Command, .{ .ack = 0x37 }), decodeCommand(&.{ 0x02, 0x37 }));
    try std.testing.expectEqual(@as(?Command, .{ .ack = 0x00 }), decodeCommand(&.{ 0x02, 0x00 }));
    try std.testing.expectEqual(@as(?Command, .{ .ack = 0xFF }), decodeCommand(&.{ 0x02, 0xFF }));
    try std.testing.expectEqual(@as(?Command, null), decodeCommand(&.{0x02}));
    try std.testing.expectEqual(@as(?Command, null), decodeCommand(&.{ 0x02, 0x37, 0x00 }));
}
test "every command goes through encodeCommand and decodeCommand unchanged" {
    var buf: [3]u8 = undefined;
    for ([_]Command{ .clear_booted, .enter_bootloader, .{ .ack = 0 }, .{ .ack = 0x37 }, .{ .ack = 255 } }) |c| {
        const bytes = encodeCommand(c, &buf);
        try std.testing.expectEqual(@as([*]const u8, &buf), bytes.ptr); // written into `buf`
        try std.testing.expectEqual(@as(?Command, c), decodeCommand(bytes));
    }
}
test "the trial flag on the wire" {
    const t = Frame{ .fw = 7, .seq = 0, .booted = false, .trial = true, .keys = 0, .enc = .{ 0, 0, 0, 0 } };
    const want_t = [16]u8{ 0x01, 0x07, 0x00, 0x02, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xBA };
    try std.testing.expectEqualSlices(u8, &want_t, &encode(t));
    try std.testing.expectEqual(t, try decode(&want_t));

    const bt = Frame{ .fw = 7, .seq = 0x2A, .booted = true, .trial = true, .keys = (1 << 0) | (1 << 48), .enc = .{ 0x10, 0x20, 0x30, 0x40 } };
    const want_bt = [16]u8{ 0x01, 0x07, 0x2A, 0x03, 0x01, 0, 0, 0, 0, 0, 0x01, 0x10, 0x20, 0x30, 0x40, 0xED };
    try std.testing.expectEqualSlices(u8, &want_bt, &encode(bt));
    try std.testing.expectEqual(bt, try decode(&want_bt));
}
test "decode ignores the flag bits 2 to 7 and the key bits no key has" {
    var b = encode(.{ .fw = 3, .seq = 5, .booted = false, .keys = 1 << 48, .enc = .{ 0, 0, 0, 0 } });
    b[3] = 0xFC; // every flag bit but `booted` and `trial`
    b[10] = 0xFF; // key 48 and the 7 bits no key has
    b[15] = crc8(b[0..15]);
    const f = try decode(&b);
    try std.testing.expect(!f.booted);
    try std.testing.expect(!f.trial);
    try std.testing.expectEqual(@as(u64, 1 << 48), f.keys);

    b[3] = 0xFF; // and with both known flags set
    b[15] = crc8(b[0..15]);
    const g = try decode(&b);
    try std.testing.expect(g.booted and g.trial);
}
test "key numbering" {
    try std.testing.expectEqual(@as(u6, 0), keyIndex(0, 0));
    try std.testing.expectEqual(@as(u6, 48), keyIndex(6, 6));
    try std.testing.expectEqual(@as(u6, 9), keyIndex(1, 2));
}
