const std = @import("std");

pub const CONFIG_TOTAL_LEN: u16 = 369;
pub const ITF_NUM_TOTAL: u8 = 7;

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

// Audio interface numbers.
const ITF_AUDIO_CTRL: u8 = 4;
const ITF_AUDIO_SPK: u8 = 5; // AudioStreaming, host -> device (playback / OUT)
const ITF_AUDIO_MIC: u8 = 6; // AudioStreaming, device -> host (capture / IN)

// Audio endpoints.
const EP_AUDIO_OUT: u8 = 0x04; // iso OUT (playback data)
const EP_AUDIO_IN: u8 = 0x85; // iso IN  (capture data). 0x84 is reserved for a
// future feedback EP (only usable on the HS port; macOS ignores UAC2 FS feedback).

// UAC2 entity IDs (arbitrary, unique within the function).
const ENT_CLOCK: u8 = 0x04;
const ENT_SPK_IN_TERM: u8 = 0x01; // USB streaming -> DAC path
const ENT_SPK_OUT_TERM: u8 = 0x03;
const ENT_MIC_IN_TERM: u8 = 0x11; // ADC -> USB streaming path
const ENT_MIC_OUT_TERM: u8 = 0x13;

// Iso data EP wMaxPacketSize: (48+1)*3 bytes *2ch = 294 (matches TUD_AUDIO_EP_SIZE FS).
const AUDIO_EP_SZ: u16 = 294;

fn u16le(v: u16) [2]u8 {
    var b: [2]u8 = undefined;
    std.mem.writeInt(u16, &b, v, .little);
    return b;
}

fn u32le(v: u32) [4]u8 {
    var b: [4]u8 = undefined;
    std.mem.writeInt(u32, &b, v, .little);
    return b;
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
        ++ [_]u8{ 5, 0x25, 0x01, 1, 3 } // assoc embedded OUT jack 3
        ++ build_audio();
}

// UAC2 audio function descriptor (209 bytes). Layout mirrors
// TUD_AUDIO20_HEADSET_STEREO_DESCRIPTOR minus the feature unit and interrupt EP.
const AUDIO_DESC_LEN: u16 = 202;
// CS-AC header wTotalLength = CLK_SRC + 2*(INPUT_TERM+OUTPUT_TERM) + CS_AC_LEN.
const AUDIO_CS_AC_TOTAL: u16 = 8 + 17 + 12 + 17 + 12 + 9; // = 75

fn build_audio() [AUDIO_DESC_LEN]u8 {
    return
        // ---- Interface Association Descriptor (8): audio class, protocol v2 ----
        [_]u8{ 8, 0x0B, ITF_AUDIO_CTRL, 3, 0x01, 0x00, 0x20, 0 }
        // ---- Standard AC interface (9): itf 4, 0 EPs, subclass CONTROL(1), proto v2 ----
        ++ [_]u8{ 9, 0x04, ITF_AUDIO_CTRL, 0, 0, 0x01, 0x01, 0x20, 0 }
        // ---- Class-Specific AC header (9): bcdADC 0x0200, category HEADSET(0x04), wTotalLength, ctrl 0 ----
        ++ [_]u8{ 9, 0x24, 0x01 } ++ u16le(0x0200) ++ [_]u8{0x04} ++ u16le(AUDIO_CS_AC_TOTAL) ++ [_]u8{0}
        // ---- Clock Source (8): id, attr INT_FIX(1), ctrl freq-R(1), assoc 0 ----
        ++ [_]u8{ 8, 0x24, 0x0A, ENT_CLOCK, 0x01, 0x01, 0x00, 0 }
        // ---- SPK Input Terminal (17): USB_STREAMING(0x0101), 2ch, clk ENT_CLOCK ----
        ++ [_]u8{ 17, 0x24, 0x02, ENT_SPK_IN_TERM } ++ u16le(0x0101) ++ [_]u8{ 0, ENT_CLOCK, 2 } ++ u32le(0) ++ [_]u8{0} ++ u16le(0) ++ [_]u8{0}
        // ---- SPK Output Terminal (12): HEADPHONES(0x0302), src = SPK input term, clk ENT_CLOCK ----
        ++ [_]u8{ 12, 0x24, 0x03, ENT_SPK_OUT_TERM } ++ u16le(0x0302) ++ [_]u8{ 0, ENT_SPK_IN_TERM, ENT_CLOCK } ++ u16le(0) ++ [_]u8{0}
        // ---- MIC Input Terminal (17): GENERIC_MIC(0x0201), 2ch, clk ENT_CLOCK ----
        ++ [_]u8{ 17, 0x24, 0x02, ENT_MIC_IN_TERM } ++ u16le(0x0201) ++ [_]u8{ 0, ENT_CLOCK, 2 } ++ u32le(0) ++ [_]u8{0} ++ u16le(0) ++ [_]u8{0}
        // ---- MIC Output Terminal (12): USB_STREAMING(0x0101), src = MIC input term, clk ENT_CLOCK ----
        ++ [_]u8{ 12, 0x24, 0x03, ENT_MIC_OUT_TERM } ++ u16le(0x0101) ++ [_]u8{ 0, ENT_MIC_IN_TERM, ENT_CLOCK } ++ u16le(0) ++ [_]u8{0}
        // ==== AudioStreaming SPK (itf 5): alt0 (0 EP), alt1 (data OUT + feedback IN) ====
        ++ [_]u8{ 9, 0x04, ITF_AUDIO_SPK, 0, 0, 0x01, 0x02, 0x20, 0 } // alt 0
        ++ [_]u8{ 9, 0x04, ITF_AUDIO_SPK, 1, 1, 0x01, 0x02, 0x20, 0 } // alt 1: 1 EP (data OUT, adaptive)
        // CS AS general (16): termid SPK_IN, ctrl 0, FORMAT_TYPE_I(1), PCM(0x00000001), 2ch
        ++ [_]u8{ 16, 0x24, 0x01, ENT_SPK_IN_TERM, 0, 0x01 } ++ u32le(0x00000001) ++ [_]u8{2} ++ u32le(0) ++ [_]u8{0}
        // Type I format (6): subslot 3 bytes, resolution 24
        ++ [_]u8{ 6, 0x24, 0x02, 0x01, 3, 24 }
        // Std AS iso data EP (7): OUT, ISO|ADAPTIVE|DATA (0x09), wMaxPacket, interval 1.
        // Adaptive sink: macOS will not drive a UAC2 feedback EP on full-speed
        // (it stalls after priming), so the host self-paces at nominal rate and
        // residual host/SAI clock drift is corrected in software by the
        // resampler (see resampler.zig + usb_audio.readPlayback).
        ++ [_]u8{ 7, 0x05, EP_AUDIO_OUT, 0x09 } ++ u16le(AUDIO_EP_SZ) ++ [_]u8{1}
        // CS AS iso EP (8): attr NON_MAX_PACKETS_OK(0x00), ctrl 0, lockdelay unit ms(1), lockdelay 1
        ++ [_]u8{ 8, 0x25, 0x01, 0x00, 0, 1 } ++ u16le(1)
        // ==== AudioStreaming MIC (itf 6): alt0 (0 EP), alt1 (data IN) ====
        ++ [_]u8{ 9, 0x04, ITF_AUDIO_MIC, 0, 0, 0x01, 0x02, 0x20, 0 } // alt 0
        ++ [_]u8{ 9, 0x04, ITF_AUDIO_MIC, 1, 1, 0x01, 0x02, 0x20, 0 } // alt 1: 1 EP (data IN)
        // CS AS general (16): termid MIC_OUT, ctrl 0, FORMAT_TYPE_I(1), PCM, 2ch
        ++ [_]u8{ 16, 0x24, 0x01, ENT_MIC_OUT_TERM, 0, 0x01 } ++ u32le(0x00000001) ++ [_]u8{2} ++ u32le(0) ++ [_]u8{0}
        // Type I format (6): subslot 3, resolution 24
        ++ [_]u8{ 6, 0x24, 0x02, 0x01, 3, 24 }
        // Std AS iso data EP (7): IN 0x85, ISO|ASYNC|DATA (0x05), wMaxPacket, interval 1
        ++ [_]u8{ 7, 0x05, EP_AUDIO_IN, 0x05 } ++ u16le(AUDIO_EP_SZ) ++ [_]u8{1}
        // CS AS iso EP (8): attr NON_MAX_PACKETS_OK(0x00), ctrl 0, lockdelay unit undefined(0), lockdelay 0
        ++ [_]u8{ 8, 0x25, 0x01, 0x00, 0, 0 } ++ u16le(0);
}

// ---- Runtime format patching --------------------------------------------
// `config_desc` above is the comptime golden for the default format. At init,
// `configure(cfg)` resets `config_buf` to that golden and overwrites only the
// format-dependent bytes (iso EP wMaxPacketSize + Type I subslot/resolution,
// for both the SPK and MIC streaming interfaces). The descriptor STRUCTURE and
// length never change with format, so only 8 bytes move — patched at these
// comptime-computed offsets. The host test below validates the offsets.

const AUDIO_OFF = CONFIG_TOTAL_LEN - AUDIO_DESC_LEN; // 167: start of the audio block
// Offsets within the audio block of the two format-carrying descriptors:
const A_SPK_FMT = 8 + 9 + 9 + 8 + 17 + 12 + 17 + 12 + 9 + 9 + 16; // Type I (SPK): 126
const A_SPK_EP = A_SPK_FMT + 6; // SPK iso data EP: 132
const A_MIC_FMT = A_SPK_EP + 7 + 8 + 9 + 9 + 16; // Type I (MIC): 181
const A_MIC_EP = A_MIC_FMT + 6; // MIC iso data EP: 187
// Type I format layout: [len, 0x24, 0x02, FORMAT_TYPE_I, subslot, resolution]
// Iso EP layout:        [len, 0x05, ep, attr, wMaxPacketSize(u16), interval]
const OFF_SPK_SUBSLOT = AUDIO_OFF + A_SPK_FMT + 4;
const OFF_SPK_RES = AUDIO_OFF + A_SPK_FMT + 5;
const OFF_SPK_EPSZ = AUDIO_OFF + A_SPK_EP + 4;
const OFF_MIC_SUBSLOT = AUDIO_OFF + A_MIC_FMT + 4;
const OFF_MIC_RES = AUDIO_OFF + A_MIC_FMT + 5;
const OFF_MIC_EPSZ = AUDIO_OFF + A_MIC_EP + 4;

/// The configuration descriptor actually returned to the host. Starts as the
/// golden default; `configure()` rewrites the format fields for a runtime cfg.
var config_buf: [CONFIG_TOTAL_LEN]u8 = config_desc;

/// Patch the configuration descriptor's audio format for USB enumeration.
/// Takes the derived wire values (the caller computes them from AudioConfig):
/// `subslot` bytes/sample, `resolution` bits, `ep_size` iso wMaxPacketSize.
/// Channels are fixed at 2 (the descriptor's channel fields are hardcoded stereo).
pub fn configure(subslot: u8, resolution: u8, ep_size: u16) void {
    config_buf = config_desc; // reset to golden, then patch the format bytes
    const ep = u16le(ep_size);
    config_buf[OFF_SPK_SUBSLOT] = subslot;
    config_buf[OFF_SPK_RES] = resolution;
    config_buf[OFF_SPK_EPSZ] = ep[0];
    config_buf[OFF_SPK_EPSZ + 1] = ep[1];
    config_buf[OFF_MIC_SUBSLOT] = subslot;
    config_buf[OFF_MIC_RES] = resolution;
    config_buf[OFF_MIC_EPSZ] = ep[0];
    config_buf[OFF_MIC_EPSZ + 1] = ep[1];
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
const str_product = strDesc("Daisy Audio+MIDI+CDC");
const str_serial = strDesc("123456");

export fn tud_descriptor_device_cb() callconv(.c) [*]const u8 {
    return &device_desc;
}
export fn tud_descriptor_configuration_cb(index: u8) callconv(.c) [*]const u8 {
    _ = index;
    return &config_buf;
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
    // Audio block is exactly 202 bytes (adaptive OUT, no feedback EP); config is 369.
    try std.testing.expectEqual(@as(usize, AUDIO_DESC_LEN), build_audio().len);
    try std.testing.expectEqual(@as(usize, 369), config_desc.len);
}

test "configure: default matches golden; non-default patches only format fields" {
    // Default (24-bit, 3-byte subslot, EP 294) reproduces the golden byte-for-byte.
    configure(3, 24, 294);
    try std.testing.expectEqualSlices(u8, &config_desc, &config_buf);

    // 32-bit: only the 8 format bytes change, and correctly (validates offsets).
    const ep32: u16 = (48 + 1) * 4 * 2; // 392
    configure(4, 32, ep32);
    try std.testing.expectEqual(@as(u8, 4), config_buf[OFF_SPK_SUBSLOT]);
    try std.testing.expectEqual(@as(u8, 32), config_buf[OFF_SPK_RES]);
    try std.testing.expectEqual(@as(u8, 4), config_buf[OFF_MIC_SUBSLOT]);
    try std.testing.expectEqual(@as(u8, 32), config_buf[OFF_MIC_RES]);
    try std.testing.expectEqual(ep32, std.mem.readInt(u16, config_buf[OFF_SPK_EPSZ..][0..2], .little));
    try std.testing.expectEqual(ep32, std.mem.readInt(u16, config_buf[OFF_MIC_EPSZ..][0..2], .little));
    // Every byte except those 8 is unchanged from the golden.
    for (config_buf, config_desc, 0..) |b, g, i| {
        const is_fmt = i == OFF_SPK_SUBSLOT or i == OFF_SPK_RES or i == OFF_SPK_EPSZ or i == OFF_SPK_EPSZ + 1 or
            i == OFF_MIC_SUBSLOT or i == OFF_MIC_RES or i == OFF_MIC_EPSZ or i == OFF_MIC_EPSZ + 1;
        if (!is_fmt) try std.testing.expectEqual(g, b);
    }
    configure(3, 24, 294); // restore default
}

test "string descriptor header: bLength low byte, type 0x03 high byte" {
    // "zmetal" = 6 code points -> bLength = 6*2 + 2 = 14; type = 0x03.
    try std.testing.expectEqual(@as(u16, (@as(u16, 0x03) << 8) | 14), str_mfr[0]);
    // langid descriptor stays correct: bLength=4, type=0x03.
    try std.testing.expectEqual(@as(u16, (@as(u16, 0x03) << 8) | 4), str_lang[0]);
}
