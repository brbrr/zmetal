//! WoopyOne v0.1 front-panel wiring for the synth example: an 8x6 key matrix on
//! the MCP23017 at 0x21 and four encoders on the MCP23017 at 0x20.
const zmetal = @import("zmetal");

pub const ROWS = 8;
pub const COLS = 6;

/// Columns on Port A pins 0-5, rows on Port B pins 0-7 (expander pins 8-15).
pub const Keyboard = zmetal.hid.keyboard.McpMatrixKeyboard(.{ .address = 0x21, .rows = ROWS, .cols = COLS });

/// Encoder expander pins (0-7 = Port A, 8-15 = Port B).
const enc_pins = [_]zmetal.hid.encoders.EncPins{
    .{ .a = 10, .b = 9, .sw = 11 }, // ENC 0
    .{ .a = 13, .b = 12, .sw = 14 }, // ENC 1
    .{ .a = 2, .b = 1, .sw = 3 }, // ENC 2
    .{ .a = 5, .b = 4, .sw = 6 }, // ENC 3
};
pub const Encoders = zmetal.hid.encoders.McpEncoders(.{ .address = 0x20, .pins = &enc_pins });

/// Translate the debouncer's scan-order index (row-major, `row*COLS + col`) into
/// this keyboard's physical/logical key numbering — the WoopyOne column-major
/// layout `col*ROWS + row`, where logical keys 0..23 (Port-A columns 0..2) are
/// the note keys and columns 3..5 are non-note keys.
pub fn logicalKey(scan_idx: u8) u8 {
    const row = scan_idx / COLS; // 0..ROWS-1  (Port B row pin)
    const col = scan_idx % COLS; // 0..COLS-1  (Port A col pin)
    return col * ROWS + row;
}
