const std = @import("std");

pub const CONFIG_TOTAL_LEN: u16 = 167;
pub const ITF_NUM_TOTAL: u8 = 4;

// USB spec constants.
const EP_NOTIF: u8 = 0x81;
const EP_CDC_OUT: u8 = 0x02;
const EP_CDC_IN: u8 = 0x82;
const EP_MIDI_OUT: u8 = 0x03;
const EP_MIDI_IN: u8 = 0x83;
const FS_BULK: u16 = 64;
const NOTIF_SIZE: u16 = 8;

// Interface numbers.
const ITF_CDC: u8 = 0; // + 1 = CDC data
const ITF_MIDI_AC: u8 = 2; // Audio Control
const ITF_MIDI_MS: u8 = 3; // MIDIStreaming

fn u16le(v: u16) [2]u8 {
    return .{ @intCast(v & 0xFF), @intCast(v >> 8) };
}

pub const config_desc: [CONFIG_TOTAL_LEN]u8 = build_config();

fn build_config() [CONFIG_TOTAL_LEN]u8 {
    const total = u16le(CONFIG_TOTAL_LEN);
    return
        // ---- Configuration descriptor (9) ----
        [_]u8{ 9, 0x02, total[0], total[1], ITF_NUM_TOTAL, 1, 0, 0x80, 50 } // 0x80 bus-powered, 100mA
        // ==== CDC (IAD + control + functionals + notif EP) ====
        // Interface Association Descriptor (8)
        ++ [_]u8{ 8, 0x0B, ITF_CDC, 2, 0x02, 0x02, 0x00, 0 }
        // CDC control interface (9): class CDC(0x02), subclass ACM(0x02)
        ++ [_]u8{ 9, 0x04, ITF_CDC, 0, 1, 0x02, 0x02, 0x00, 0 }
        // CDC Header functional (5)
        ++ [_]u8{ 5, 0x24, 0x00, 0x10, 0x01 }
        // CDC Call Management functional (5): data iface = ITF_CDC+1
        ++ [_]u8{ 5, 0x24, 0x01, 0x00, ITF_CDC + 1 }
        // CDC ACM functional (4): bmCapabilities = 0x02 (line coding)
        ++ [_]u8{ 4, 0x24, 0x02, 0x02 }
        // CDC Union functional (5): control = ITF_CDC, subordinate = ITF_CDC+1
        ++ [_]u8{ 5, 0x24, 0x06, ITF_CDC, ITF_CDC + 1 }
        // Notification endpoint (7): interrupt IN, 8 bytes, 16ms
        ++ [_]u8{ 7, 0x05, EP_NOTIF, 0x03 } ++ u16le(NOTIF_SIZE) ++ [_]u8{16}
        // ==== CDC data interface (9) + 2 bulk EPs ====
        ++ [_]u8{ 9, 0x04, ITF_CDC + 1, 0, 2, 0x0A, 0x00, 0x00, 0 }
        ++ [_]u8{ 7, 0x05, EP_CDC_OUT, 0x02 } ++ u16le(FS_BULK) ++ [_]u8{0}
        ++ [_]u8{ 7, 0x05, EP_CDC_IN, 0x02 } ++ u16le(FS_BULK) ++ [_]u8{0}
        // ==== MIDI: Audio Control interface (9) + AC header (9) ====
        ++ [_]u8{ 9, 0x04, ITF_MIDI_AC, 0, 0, 0x01, 0x01, 0x00, 0 }
        ++ [_]u8{ 9, 0x24, 0x01 } ++ u16le(0x0100) ++ u16le(9) ++ [_]u8{ 1, ITF_MIDI_MS }
        // ==== MIDIStreaming interface (9) + MS header (7) ====
        ++ [_]u8{ 9, 0x04, ITF_MIDI_MS, 0, 2, 0x01, 0x03, 0x00, 0 }
        ++ [_]u8{ 7, 0x24, 0x01 } ++ u16le(0x0100) ++ u16le(7 + 6 + 6 + 9 + 9 + 5 + 5)
        // MIDI IN Jack embedded (6): jackID 1
        ++ [_]u8{ 6, 0x24, 0x02, 0x01, 1, 0 }
        // MIDI IN Jack external (6): jackID 2
        ++ [_]u8{ 6, 0x24, 0x02, 0x02, 2, 0 }
        // MIDI OUT Jack embedded (9): jackID 3, 1 pin from external jack 2 pin 1
        ++ [_]u8{ 9, 0x24, 0x03, 0x01, 3, 1, 2, 1, 0 }
        // MIDI OUT Jack external (9): jackID 4, 1 pin from embedded jack 1 pin 1
        ++ [_]u8{ 9, 0x24, 0x03, 0x02, 4, 1, 1, 1, 0 }
        // Bulk OUT endpoint (9: audio EP descriptor) + MS bulk data EP (5)
        ++ [_]u8{ 9, 0x05, EP_MIDI_OUT, 0x02 } ++ u16le(FS_BULK) ++ [_]u8{ 0, 0, 0 }
        ++ [_]u8{ 5, 0x25, 0x01, 1, 1 } // assoc embedded IN jack 1
        // Bulk IN endpoint (9) + MS bulk data EP (5)
        ++ [_]u8{ 9, 0x05, EP_MIDI_IN, 0x02 } ++ u16le(FS_BULK) ++ [_]u8{ 0, 0, 0 }
        ++ [_]u8{ 5, 0x25, 0x01, 1, 3 }; // assoc embedded OUT jack 3
}

// ---- Device descriptor (18) ----
const VID: u16 = 0xCafe; // TinyUSB example VID; fine for local bring-up
const PID: u16 = 0x4001;
const device_desc: [18]u8 = blk: {
    const vid = u16le(VID);
    const pid = u16le(PID);
    const bcd = u16le(0x0200); // USB 2.0
    const dev = u16le(0x0100);
    break :blk [_]u8{
        18, 0x01, bcd[0], bcd[1],
        0xEF, 0x02, 0x01, // Misc / IAD device class
        64, // EP0 size
        vid[0], vid[1], pid[0], pid[1],
        dev[0], dev[1],
        1, 2, 3, // iManufacturer, iProduct, iSerial
        1, // bNumConfigurations
    };
};

// ---- String descriptors ----
const str_lang: [2]u16 = .{ (3 << 8) | 4, 0x0409 };

fn strDesc(comptime s: []const u8) [s.len + 1]u16 {
    var out: [s.len + 1]u16 = undefined;
    // USB string descriptor header, little-endian u16: low byte = bLength,
    // high byte = bDescriptorType (0x03 = STRING).
    out[0] = (@as(u16, 0x03) << 8) | @as(u16, s.len * 2 + 2);
    for (s, 0..) |ch, i| out[i + 1] = ch;
    return out;
}
const str_mfr = strDesc("zmetal");
const str_product = strDesc("Daisy CDC+MIDI");
const str_serial = strDesc("123456");

export fn tud_descriptor_device_cb() callconv(.c) [*]const u8 {
    return &device_desc;
}
export fn tud_descriptor_configuration_cb(index: u8) callconv(.c) [*]const u8 {
    _ = index;
    return &config_desc;
}
var string_buf: [32]u16 = undefined;
export fn tud_descriptor_string_cb(index: u8, langid: u16) callconv(.c) [*]const u16 {
    _ = langid;
    const src: []const u16 = switch (index) {
        0 => &str_lang,
        1 => &str_mfr,
        2 => &str_product,
        3 => &str_serial,
        else => &str_lang,
    };
    @memcpy(string_buf[0..src.len], src);
    return &string_buf;
}

test "config descriptor total length and interface count" {
    try std.testing.expectEqual(@as(usize, CONFIG_TOTAL_LEN), config_desc.len);
    // Configuration descriptor header: wTotalLength (LE) at bytes 2..3,
    // bNumInterfaces at byte 4.
    const total = @as(u16, config_desc[2]) | (@as(u16, config_desc[3]) << 8);
    try std.testing.expectEqual(CONFIG_TOTAL_LEN, total);
    try std.testing.expectEqual(ITF_NUM_TOTAL, config_desc[4]);
}

test "string descriptor header: bLength low byte, type 0x03 high byte" {
    // "zmetal" = 6 code points -> bLength = 6*2 + 2 = 14; type = 0x03.
    try std.testing.expectEqual(@as(u16, (@as(u16, 0x03) << 8) | 14), str_mfr[0]);
    // langid descriptor stays correct: bLength=4, type=0x03.
    try std.testing.expectEqual(@as(u16, (@as(u16, 0x03) << 8) | 4), str_lang[0]);
}
