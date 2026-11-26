//! The panel link's std-only logic as one module, for the scanner firmware
//! (`scanner/main.zig`), whose root cannot import files outside its own
//! directory. The Daisy side reaches the same files through `zmetal.hid`.

const std = @import("std");

pub const panel_proto = @import("panel_proto.zig");
pub const panel_scanner = @import("panel_scanner.zig");
pub const panel_link = @import("panel_link.zig");

test {
    std.testing.refAllDecls(@This());
}
