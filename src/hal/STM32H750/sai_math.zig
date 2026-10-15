//! Pure SAI math (no MMIO): master-clock divider and audio-config validation.
//! Host-tested; used by sai.zig.
const std = @import("std");

/// MCKDIV for the SAI master clock (ST HAL algorithm: ratio computed x10 and
/// rounded up when the tenths digit exceeds 8). MCKDIV is a 6-bit field.
pub fn computeMckDiv(sai_ck: u32, fs: u32, frame_length: u32, no_divider: bool, oversampling: bool) error{MckDivOutOfRange}!u6 {
    const tmpval: u64 = if (no_divider)
        // NODIV = 1: MCKDIV = SAI_CK / (FS * FRL)
        (@as(u64, sai_ck) * 10) / (@as(u64, fs) * frame_length)
    else
        // NODIV = 0: MCKDIV = SAI_CK / (FS * (OSR+1) * 256)
        (@as(u64, sai_ck) * 10) / (@as(u64, fs) * @as(u64, if (oversampling) 2 else 1) * 256);
    var mckdiv: u64 = tmpval / 10;
    if (tmpval % 10 > 8) mckdiv += 1;
    return std.math.cast(u6, mckdiv) orelse error.MckDivOutOfRange;
}

/// Reject audio configs the SAI/DMA path cannot serve: only 24- and 32-bit
/// samples (slots and DMA buffers are 32-bit), and 1..max_block frames.
pub fn validate(bit_depth_bits: u8, block_size: usize, max_block: usize) error{ UnsupportedBitDepth, BlockSizeTooLarge, BlockSizeZero }!void {
    if (bit_depth_bits != 24 and bit_depth_bits != 32) return error.UnsupportedBitDepth;
    if (block_size == 0) return error.BlockSizeZero;
    if (block_size > max_block) return error.BlockSizeTooLarge;
}

// Daisy PLL3P: HSE 16 MHz / DIVM3 6 * DIVN3 295 / DIVP3 16 (daisy.zig clk_config).
const daisy_sai_ck: u32 = 49_166_666;

test "48 kHz, NODIV=0: MCKDIV = 4" {
    try std.testing.expectEqual(@as(u6, 4), try computeMckDiv(daisy_sai_ck, 48_000, 64, false, false));
}

test "8 kHz needs a 6-bit MCKDIV (24), not a u4 truncation" {
    try std.testing.expectEqual(@as(u6, 24), try computeMckDiv(daisy_sai_ck, 8_000, 64, false, false));
}

test "divider above 63 is an error, not a trap" {
    try std.testing.expectError(error.MckDivOutOfRange, computeMckDiv(daisy_sai_ck, 1_000, 64, false, false));
}

test "16-bit is rejected (DMA buffers and slots are 32-bit)" {
    try std.testing.expectError(error.UnsupportedBitDepth, validate(16, 48, 128));
}

test "block size bounds" {
    try validate(24, 128, 128);
    try std.testing.expectError(error.BlockSizeTooLarge, validate(24, 129, 128));
    try std.testing.expectError(error.BlockSizeZero, validate(32, 0, 128));
}
