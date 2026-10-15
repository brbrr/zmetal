//! Daisy Seed header pin names (libdaisy `seed::D0..D32` / `A0..A13`,
//! daisy_seed.h). Use with `hal.Gpio.init(seed.D7, .{})` or any driver config.
const pin_name = @import("pin_name.zig");
const Pin = pin_name.Pin;

fn p(comptime port: pin_name.Port, comptime num: u4) Pin {
    return .{ .port = port, .num = num };
}

pub const D0 = p(.B, 12);
pub const D1 = p(.C, 11);
pub const D2 = p(.C, 10);
pub const D3 = p(.C, 9);
pub const D4 = p(.C, 8);
pub const D5 = p(.D, 2);
pub const D6 = p(.C, 12);
pub const D7 = p(.G, 10);
pub const D8 = p(.G, 11);
pub const D9 = p(.B, 4);
pub const D10 = p(.B, 5);
pub const D11 = p(.B, 8);
pub const D12 = p(.B, 9);
pub const D13 = p(.B, 6);
pub const D14 = p(.B, 7);
pub const D15 = p(.C, 0);
pub const D16 = p(.A, 3);
pub const D17 = p(.B, 1);
pub const D18 = p(.A, 7);
pub const D19 = p(.A, 6);
pub const D20 = p(.C, 1);
pub const D21 = p(.C, 4);
pub const D22 = p(.A, 5);
pub const D23 = p(.A, 4);
pub const D24 = p(.A, 1);
pub const D25 = p(.A, 0);
pub const D26 = p(.D, 11);
pub const D27 = p(.G, 9);
pub const D28 = p(.A, 2);
pub const D29 = p(.B, 14);
pub const D30 = p(.B, 15);
/// Daisy Seed 2 DFM only.
pub const D31 = p(.C, 2);
/// Daisy Seed 2 DFM only.
pub const D32 = p(.C, 3);

// Analog inputs share the digital header pins.
pub const A0 = D15;
pub const A1 = D16;
pub const A2 = D17;
pub const A3 = D18;
pub const A4 = D19;
pub const A5 = D20;
pub const A6 = D21;
pub const A7 = D22;
pub const A8 = D23;
pub const A9 = D24;
pub const A10 = D25;
pub const A11 = D28;
pub const A12 = D31;
pub const A13 = D32;

/// On-board user LED.
pub const LED = p(.C, 7);
