//! The stack guard's arithmetic, std-only so the host can test it. The
//! stack grows down from the top of the DTCM toward the placed data; an
//! MPU region with no access sits between them, so an overflow faults
//! instead of writing over the data. `mpu.zig` places the region and
//! `fault.zig` reads the result.

const std = @import("std");

/// The guard's size. A region must be a power of two and aligned to its
/// size. A frame that allocates more than this at once could jump over
/// the guard, so it is larger than the deepest frame, not the 32 B minimum.
pub const size: u32 = 1024;

/// The guard's lowest address: the first address at or above the end of
/// the placed data that is aligned to the guard's size.
pub fn base(data_end: u32) u32 {
    return std.mem.alignForward(u32, data_end, size);
}

/// The lowest address the stack may use: the guard's end.
pub fn stackLow(data_end: u32) u32 {
    return base(data_end) + size;
}

// The CFSR bits a stack overflow sets (the MMFSR, its low byte).
const mstkerr: u32 = 1 << 4; // the push of an exception frame faulted
const mmarvalid: u32 = 1 << 7; // MMFAR holds the faulting address

/// True when the fault came from the stack running into the guard: an
/// exception frame that could not be pushed, or an access in the guard.
/// `guard_base` 0 means no guard is set.
pub fn isOverflow(cfsr: u32, mmfar: u32, guard_base: u32) bool {
    if (guard_base == 0) return false;
    if (cfsr & mstkerr != 0) return true;
    return cfsr & mmarvalid != 0 and mmfar >= guard_base and mmfar < guard_base + size;
}

const testing = std.testing;

test "the guard sits at the first aligned address at or above the data, and the stack starts above it" {
    try testing.expectEqual(@as(u32, 0x2001_0400), base(0x2001_0004));
    try testing.expectEqual(@as(u32, 0x2001_0400), base(0x2001_0400));
    try testing.expectEqual(@as(u32, 0x2001_0800), stackLow(0x2001_0004));
    try testing.expectEqual(@as(u32, 0), base(0x2001_0004) % size);
}

test "an overflow is a failed frame push or an access inside the guard, and nothing without a guard" {
    const g: u32 = 0x2001_0400;
    try testing.expect(isOverflow(mstkerr, 0, g));
    try testing.expect(isOverflow(mmarvalid | 0x02, g + 8, g));
    try testing.expect(!isOverflow(mmarvalid | 0x02, g + size, g));
    try testing.expect(!isOverflow(0x02, g + 8, g)); // address not valid
    try testing.expect(!isOverflow(mstkerr, 0, 0));
}
