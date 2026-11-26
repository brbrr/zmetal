//! The cause of the last reset, from the RCC reset flags (RCC_RSR).
//!
//! The flags stay set across resets until they are cleared, so they add up:
//! read `cause` early in `main`, then `clearFlags`, so the next boot sees
//! only the flags of its own reset.
const microzig = @import("microzig");
const RCC = microzig.chip.peripherals.RCC;
const reset_cause = @import("reset_cause.zig");

pub const Cause = reset_cause.Cause;

/// What reset the chip last (see `reset_cause.decode` for how several set
/// flags are told apart).
pub fn cause() Cause {
    return reset_cause.decode(rawFlags());
}

/// The reset flags as they are: the raw RCC_RSR value (bit numbers in
/// reset_cause.zig), for a report or a debugger.
pub fn rawFlags() u32 {
    return RCC.RSR.raw;
}

/// Clear the reset flags: set RMVF, then clear it again. RM0433 describes
/// RMVF as set and reset by software, with the flags held cleared while it
/// is 1; left at 1 it would hide the flags of the next reset. Should it
/// clear itself instead, the second write changes nothing. (ST's HAL only
/// sets it.)
pub fn clearFlags() void {
    RCC.RSR.modify_one("RMVF", 1);
    RCC.RSR.modify_one("RMVF", 0);
}
