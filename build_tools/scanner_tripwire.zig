//! A build-time tripwire for scanner rule S5 of "Never unflashable" (the
//! panel scanner plan): the scanner never starts the watchdog, never
//! writes an option byte and never configures PF2 (NRST). `zig build
//! scanner` runs this on `scanner.bin` and fails when the image holds, as
//! a 32-bit little-endian word at any 2-byte-aligned offset, one of the
//! words of `forbidden`: the address of the IWDG, FLASH_OPTKEYR,
//! FLASH_OPTR or GPIOF, or one of the two option-byte unlock keys.
//!
//! Why words: on the Cortex-M0+ a 32-bit constant comes from a literal
//! pool in flash, so code that names one of these registers, or writes
//! one of the keys, usually puts that word in the image. It is a
//! tripwire, not a proof. A store that reaches a register as a base plus
//! an offset leaves no such word, and the compiler does that whenever the
//! base is at hand: a store to FLASH_OPTR or FLASH_OPTKEYR, even through
//! `@ptrFromInt(0x4002_2020)`, became `str rX, [rY, #0x20]` off the flash
//! registers' base 0x4002_2000, which the image holds for FLASH_ACR, and
//! passed the address check (tried 2026-11-26). The keys close that gap
//! for option bytes: no option byte changes without OPTKEY1 and OPTKEY2
//! written to FLASH_OPTKEYR first, and neither key fits an immediate. The
//! IWDG and GPIOF stores were caught by their addresses. The store
//! resolver of the Task 5 review, which follows every store to its
//! address, is the full check. A word that equals one of these in data
//! fails the build too; look at it before changing this list.
//!
//! Usage: `scanner_tripwire <scanner.bin> <checked.bin>`. A clean image is
//! copied to `<checked.bin>`, which is what a Daisy firmware embeds and
//! the build installs, so nothing is built on an image that failed;
//! otherwise it prints the word and where it is, and exits 1. Std only;
//! its tests run in `zig build test`.

const std = @import("std");

pub const Forbidden = struct { word: u32, what: []const u8 };

/// The addresses are from the generated STM32C031K6 definitions
/// (microzig's register data, `data/chips/STM32C031K6.json` and
/// `data/registers/flash_c0.json`): IWDG at 0x4000_3000 (KR at offset 0),
/// FLASH at 0x4002_2000 with OPTKEYR at 0x0C and OPTR at 0x20, GPIOF at
/// 0x5000_1400. The keys are RM0490's (through the facts file,
/// docs/superpowers/specs/2026-11-25-c031-flash-facts.md section 2), the
/// same as ST's FLASH_OPT_KEY1 and FLASH_OPT_KEY2 in the STM32H7 HAL.
pub const forbidden = [_]Forbidden{
    .{ .word = 0x4000_3000, .what = "the IWDG (S5: the scanner never starts the watchdog)" },
    .{ .word = 0x4002_200C, .what = "FLASH_OPTKEYR (S5: no option-byte write)" },
    .{ .word = 0x4002_2020, .what = "FLASH_OPTR (S5: no option-byte write)" },
    .{ .word = 0x5000_1400, .what = "GPIOF (S5: PF2 is NRST and is never configured)" },
    .{ .word = 0x0819_2A3B, .what = "OPTKEY1, the first option-byte unlock key (S5: no option-byte write)" },
    .{ .word = 0x4C5D_6E7F, .what = "OPTKEY2, the second option-byte unlock key (S5: no option-byte write)" },
};

pub const Hit = struct { offset: usize, forbidden: Forbidden };

/// The first forbidden word in `image` at a 2-byte-aligned offset, or null.
pub fn findForbidden(image: []const u8) ?Hit {
    var offset: usize = 0;
    while (offset + 4 <= image.len) : (offset += 2) {
        const word = std.mem.readInt(u32, image[offset..][0..4], .little);
        for (forbidden) |f| {
            if (word == f.word) return .{ .offset = offset, .forbidden = f };
        }
    }
    return null;
}

/// `error.Forbidden` when `findForbidden` finds a word.
pub fn check(image: []const u8) error{Forbidden}!void {
    if (findForbidden(image) != null) return error.Forbidden;
}

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    if (args.len != 3) {
        std.debug.print("usage: scanner_tripwire <scanner.bin> <checked.bin>\n", .{});
        std.process.exit(2);
    }
    const io = init.io;
    const cwd = std.Io.Dir.cwd();
    const image = try cwd.readFileAlloc(io, args[1], arena, .limited(1 << 20));
    if (findForbidden(image)) |hit| {
        std.debug.print(
            "scanner.bin fails the S5 tripwire: the image holds 0x{X:0>8}, {s}, " ++
                "at offset 0x{X} (flash address 0x{X:0>8}). See build_tools/scanner_tripwire.zig " ++
                "and rule S5 of \"Never unflashable\" in the panel scanner plan.\n",
            .{ hit.forbidden.word, hit.forbidden.what, hit.offset, 0x0800_0000 + hit.offset },
        );
        std.process.exit(1);
    }
    try cwd.writeFile(io, .{ .sub_path = args[2], .data = image });
}

// ============================================================================

const testing = std.testing;

/// 64 bytes of a plausible image: no word of it is forbidden.
fn cleanImage() [64]u8 {
    var image: [64]u8 = undefined;
    for (&image, 0..) |*b, i| b.* = @truncate(i *% 37 +% 11);
    return image;
}

test "an image without the words passes" {
    const image = cleanImage();
    try check(&image);
    try testing.expectEqual(@as(?Hit, null), findForbidden(&image));
    try check(&.{});
    try check(&.{ 0x00, 0x30, 0x00 }); // shorter than a word
}

test "each word, little-endian at a 2-byte-aligned offset, fails" {
    // The bytes are written out by hand, low byte first.
    const words = [_][4]u8{
        .{ 0x00, 0x30, 0x00, 0x40 }, // 0x4000_3000, IWDG
        .{ 0x0C, 0x20, 0x02, 0x40 }, // 0x4002_200C, FLASH_OPTKEYR
        .{ 0x20, 0x20, 0x02, 0x40 }, // 0x4002_2020, FLASH_OPTR
        .{ 0x00, 0x14, 0x00, 0x50 }, // 0x5000_1400, GPIOF
        .{ 0x3B, 0x2A, 0x19, 0x08 }, // 0x0819_2A3B, OPTKEY1
        .{ 0x7F, 0x6E, 0x5D, 0x4C }, // 0x4C5D_6E7F, OPTKEY2
    };
    comptime std.debug.assert(words.len == forbidden.len);
    for (words, forbidden) |w, f| {
        for ([_]usize{ 0, 2, 6, 60 }) |at| { // 4-aligned and not, the last word
            var image = cleanImage();
            image[at..][0..4].* = w;
            try testing.expectError(error.Forbidden, check(&image));
            const hit = findForbidden(&image) orelse return error.TestUnexpectedResult;
            try testing.expectEqual(at, hit.offset);
            try testing.expectEqual(f.word, hit.forbidden.word);
        }
    }
}

test "a word at an odd offset passes" {
    var image = cleanImage();
    image[5..][0..4].* = .{ 0x20, 0x20, 0x02, 0x40 }; // FLASH_OPTR at offset 5
    try check(&image);
    image = cleanImage();
    image[59..][0..4].* = .{ 0x00, 0x30, 0x00, 0x40 }; // the IWDG at offset 59
    try check(&image);
}

test "the flash registers' base, the flash keys and a big-endian word pass" {
    var image = cleanImage();
    image[8..][0..4].* = .{ 0x00, 0x20, 0x02, 0x40 }; // 0x4002_2000, FLASH_ACR's address
    image[16..][0..4].* = .{ 0x40, 0x02, 0x20, 0x20 }; // FLASH_OPTR, big-endian
    image[24..][0..4].* = .{ 0x23, 0x01, 0x67, 0x45 }; // 0x4567_0123, KEY1 (the page erase's)
    image[32..][0..4].* = .{ 0xAB, 0x89, 0xEF, 0xCD }; // 0xCDEF_89AB, KEY2
    try check(&image);
}
