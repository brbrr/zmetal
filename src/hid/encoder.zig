//! Rotary-encoder decoding: quadrature step detection + push-switch debounce.
//!
//! Pure and hardware-agnostic (fed raw pin levels by the driver in
//! `encoders.zig`), so it can be unit-tested on the host. The quadrature scheme
//! matches the WoopyOne reference: one increment per detent, detected on a
//! falling edge of one channel while the other is low.

const std = @import("std");

/// Result of feeding one sample to an `Encoder`.
pub const Update = struct {
    /// +1 clockwise, -1 counter-clockwise, 0 if no detent this sample.
    inc: i8 = 0,
    /// Debounced current switch state (true = held down).
    pressed: bool = false,
    /// Switch transitioned to pressed on this sample.
    just_pressed: bool = false,
    /// Switch transitioned to released on this sample.
    just_released: bool = false,
};

pub const Encoder = struct {
    /// 2-sample history of the A/B channels: bit1 = previous, bit0 = current.
    /// Idle-high (encoder released), matching open-drain inputs with pull-ups.
    a: u2 = 0b11,
    b: u2 = 0b11,
    /// Shift register of debounced "pressed" samples (active-high internally).
    sw: u8 = 0,
    down: bool = false,

    /// Consecutive equal samples required to flip the debounced switch state.
    /// At the ~2ms poll rate this is a ~6ms debounce.
    const SW_WINDOW: u8 = 0b111;

    pub fn init() Encoder {
        return .{};
    }

    /// Feed one sample of the raw expander pin levels (1 = high). `sw_pin` is
    /// active-low (pull-up), so the switch is "pressed" when it reads 0.
    pub fn step(self: *Encoder, a_pin: u1, b_pin: u1, sw_pin: u1) Update {
        self.a = (self.a << 1) | a_pin;
        self.b = (self.b << 1) | b_pin;

        var inc: i8 = 0;
        // A just fell (10) while B is low (00) => clockwise; mirror => CCW.
        if (self.a == 0b10 and self.b == 0b00) {
            inc = 1;
        } else if (self.b == 0b10 and self.a == 0b00) {
            inc = -1;
        }

        const pressed_now: u1 = if (sw_pin == 0) 1 else 0; // active-low
        self.sw = (self.sw << 1) | pressed_now;
        const window = self.sw & SW_WINDOW;

        var just_pressed = false;
        var just_released = false;
        if (!self.down and window == SW_WINDOW) {
            self.down = true;
            just_pressed = true;
        } else if (self.down and window == 0) {
            self.down = false;
            just_released = true;
        }

        return .{
            .inc = inc,
            .pressed = self.down,
            .just_pressed = just_pressed,
            .just_released = just_released,
        };
    }
};

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "clockwise detent yields +1" {
    var e = Encoder.init();
    // Sequence that lands A/B at a=10 (A falling), b=00 (B low): step(1,0) then (0,0).
    _ = e.step(1, 0, 1);
    const u = e.step(0, 0, 1);
    try expectEqual(@as(i8, 1), u.inc);
}

test "counter-clockwise detent yields -1" {
    var e = Encoder.init();
    _ = e.step(0, 1, 1);
    const u = e.step(0, 0, 1);
    try expectEqual(@as(i8, -1), u.inc);
}

test "idle yields no increments" {
    var e = Encoder.init();
    for (0..8) |_| {
        try expectEqual(@as(i8, 0), e.step(1, 1, 1).inc);
    }
}

test "switch debounces and reports edges once" {
    var e = Encoder.init();
    // Bounce before settling: a single low sample must not register.
    try expect(!e.step(0, 0, 0).just_pressed); // 1 low sample
    try expect(!e.step(0, 0, 1).just_pressed); // bounced back high
    // Three consecutive low (pressed) samples -> just_pressed exactly once.
    _ = e.step(0, 0, 0);
    _ = e.step(0, 0, 0);
    const p = e.step(0, 0, 0);
    try expect(p.just_pressed);
    try expect(p.pressed);
    try expect(!e.step(0, 0, 0).just_pressed); // stays pressed, no repeat edge

    // Three consecutive high (released) samples -> just_released once.
    _ = e.step(0, 0, 1);
    _ = e.step(0, 0, 1);
    const r = e.step(0, 0, 1);
    try expect(r.just_released);
    try expect(!r.pressed);
}

test "rotation and switch are independent" {
    var e = Encoder.init();
    _ = e.step(1, 0, 1);
    const u = e.step(0, 0, 1);
    try expectEqual(@as(i8, 1), u.inc);
    try expect(!u.pressed);
}
