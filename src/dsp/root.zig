//! zmetal DSP: std-only building blocks (no microzig), host-testable.
pub const osc = @import("osc.zig");
pub const mono_voice = @import("mono_voice.zig");
pub const util = @import("util.zig");
pub const AudioIO = @import("audio_io.zig").AudioIO;

test {
    _ = osc;
    _ = mono_voice;
    _ = util;
}
