//! ADC1, single conversions: one channel at a time, 16-bit, started by
//! software. Blocking, for one caller at a time (not for interrupts).
//!
//! `init` once, after `Seed.init` (its waits run on the millisecond tick),
//! then an `Input` per pin.
const std = @import("std");
const microzig = @import("microzig");
const chip = microzig.chip;
const ADC1 = chip.peripherals.ADC1;
const ADC12_COMMON = chip.peripherals.ADC12_COMMON;
const rcc = @import("rcc.zig");
const clock = @import("clock.zig");
const pin_name = @import("pin_name.zig");
const Gpio = @import("gpio_rt.zig").Gpio;
const adc_math = @import("adc_math.zig");

/// A 16-bit reading in millivolts for a reference of `vref_mv` (see `adc_math.toMillivolts`).
pub const toMillivolts = adc_math.toMillivolts;

pub const Error = error{Timeout};

/// How long a channel is sampled, in ADC clock cycles (SMPR's SMPx field,
/// in its order: 1.5 cycles is 0, 810.5 is 7). A high-impedance source
/// needs a long one.
pub const SampleTime = enum { cycles_1_5, cycles_2_5, cycles_8_5, cycles_16_5, cycles_32_5, cycles_64_5, cycles_387_5, cycles_810_5 };

/// ADC1's kernel clock: PLL3 R on the Seed, about 24.6 MHz.
const kernel_hz: u32 = @intFromFloat(rcc.clock_outputs.ADCoutput);

/// The most time a wait for the ADC takes before `Error.Timeout`. The
/// calibration has its own limit, `calibration_timeout_ms`.
const timeout_ms = 10;

/// tCAL, the offset and linearity calibration: 165,010 ADC clock cycles
/// (DS12556 Rev 8, table 75 for revision Y, table 172 for revision V).
const calibration_cycles = 165_010;

/// The most time the calibration takes before `Error.Timeout`: twice tCAL
/// at the slower clock, revision V's (the kernel clock divided by 2, then
/// by 2 again inside the ADC), so revision Y has a wide margin too. With
/// this board's clock (24.6 MHz divided by 2), tCAL is about 13.4 ms on
/// revision Y and about 26.8 ms on revision V; the limit is 54 ms.
const calibration_timeout_ms = 2 * ((calibration_cycles * 1000 + kernel_hz / 4 - 1) / (kernel_hz / 4));

/// Regulator on, calibration, enable. 16-bit, single conversion, software
/// start. Call once.
///
/// Blocks for the calibration: tens of milliseconds (about 13 ms on
/// revision Y silicon, 27 ms on revision V, with this board's clock), so
/// keep it out of time-critical code.
///
/// The order is ST's (`HAL_ADC_Init`, `HAL_ADCEx_Calibration_Start`,
/// `ADC_Enable`): out of deep power-down, the regulator on and time for it
/// to start (tADCVREG_STUP), the clock and the conversion settings, a
/// single-ended offset and linearity calibration, then the ADC enabled.
pub fn init() Error!void {
    if (kernel_hz == 0) @compileError("adc: no ADC kernel clock (set ADCCLockSelection in the clock tree)");
    // The clock: the kernel clock divided by 2 (CCR.PRESC, asynchronous
    // mode), with CR.BOOST left at its reset value 0. ST's rules, in
    // `ADC_ConfigureBoostMode` (Drivers/STM32H7xx_HAL_Driver/Src/
    // stm32h7xx_hal_adc.c in libdaisy): revision Y silicon wants its BOOST
    // bit clear up to 20 MHz; revision V halves the clock once more and
    // wants BOOST 0 up to 6.25 MHz. So the kernel clock divided by 2, at
    // most 12.5 MHz, is right on both.
    comptime if (kernel_hz / 2 > 12_500_000) @compileError("adc: the ADC kernel clock divided by 2 is over 12.5 MHz, too fast with BOOST at 0");

    rcc.enable_clock(.ADC1);

    setCr(.{ .DEEPPWD = 0 });
    setCr(.{ .ADVREGEN = 1 });
    // The regulator needs up to 10 us to start (tADCVREG_STUP: 5 us typical,
    // 10 us max; DS12556 tables 75 and 172). A whole millisecond on the
    // SysTick tick, far more than needed (`delay_us(10)` would do), but it
    // costs nothing beside the calibration that follows, which takes far
    // longer.
    clock.delay_ms(1);

    // CCR is shared with ADC2: written while both are off.
    ADC12_COMMON.CCR.modify(.{ .CKMODE = .Asynchronous, .PRESC = .Div2 });
    ADC1.CFGR.modify(.{ .RES = .Bits16, .CONT = 0, .EXTEN = .Disabled });

    setCr(.{ .ADCALDIF = .SingleEnded, .ADCALLIN = 1, .ADCAL = 1 });
    try waitFor(calibrated, calibration_timeout_ms);

    clearFlags(.{ .ADRDY = 1 });
    setCr(.{ .ADEN = 1 });
    try waitFor(ready, timeout_ms);
}

/// One ADC1 input, on a pin.
pub const Input = struct {
    channel: u5,

    /// Pin to analog mode, channel preselected, sample time set. A pin
    /// without an ADC1 input is a compile error.
    pub fn init(comptime pin: pin_name.Pin, comptime sample_time: SampleTime) Input {
        const channel = comptime adc_math.channelFor(pin) orelse
            @compileError(std.fmt.comptimePrint("adc: P{s}{d} has no ADC1 input", .{ @tagName(pin.port), pin.num }));

        // Only this pin's bits of the port's registers are written.
        _ = Gpio.init(pin, .{ .mode = .analog });

        // The H7 converts only a channel preselected in PCSEL. The sample
        // times of channels 0-9 are in SMPR1, those of 10-19 in SMPR2.
        ADC1.PCSEL.modify_one(std.fmt.comptimePrint("PCSEL[{d}]", .{channel}), .Preselected);
        ADC1.SMPR[channel / 10].modify_one(
            std.fmt.comptimePrint("SMP[{d}]", .{channel % 10}),
            @enumFromInt(@intFromEnum(sample_time)),
        );
        return .{ .channel = channel };
    }

    /// One conversion, 0..65535.
    pub fn read(self: Input) Error!u16 {
        ADC1.SQR1.write(.{ .L = 0, .@"SQ[0]" = self.channel, .@"SQ[1]" = 0, .@"SQ[2]" = 0, .@"SQ[3]" = 0 });
        // Stale flags from an earlier conversion out first, as ST's
        // `HAL_ADC_Start` does; reading DR clears EOC.
        clearFlags(.{ .EOC = 1, .EOS = 1, .OVR = 1 });
        setCr(.{ .ADSTART = 1 });
        try waitFor(converted, timeout_ms);
        return ADC1.DR.read().RDATA;
    }

    /// The mean of `samples` conversions, rounded down.
    pub fn readAveraged(self: Input, comptime samples: u8) Error!u16 {
        if (samples == 0) @compileError("adc: readAveraged needs at least 1 sample");
        var sum: u32 = 0; // 255 * 65535 fits
        for (0..samples) |_| sum += try self.read();
        return @intCast(sum / samples);
    }
};

/// Write CR with `fields` set and its "rs" bits (ADEN, ADDIS, ADSTART,
/// JADSTART, ADSTP, JADSTP, ADCAL) 0 unless `fields` sets them. Software
/// can only set those bits, and setting one starts an action (a 0 written
/// does nothing), so a write must not carry back the 1s it read: ADEN
/// written again while the ADC is on, for one. ST's LL writes CR the same
/// way (`ADC_CR_BITS_PROPERTY_RS`, stm32h7xx_ll_adc.h).
fn setCr(fields: anytype) void {
    var cr = ADC1.CR.read();
    cr.ADEN = 0;
    cr.ADDIS = 0;
    cr.ADSTART = 0;
    cr.JADSTART = 0;
    cr.ADSTP = @enumFromInt(0);
    cr.JADSTP = @enumFromInt(0);
    cr.ADCAL = 0;
    inline for (@typeInfo(@TypeOf(fields)).@"struct".field_names) |name| {
        @field(cr, name) = @field(fields, name);
    }
    ADC1.CR.write(cr);
}

/// Clear the ISR flags `flags` sets to 1. A flag clears on a written 1; the
/// 0s written to the others leave them.
fn clearFlags(flags: anytype) void {
    var isr: @TypeOf(ADC1.ISR.read()) = @bitCast(@as(u32, 0));
    inline for (@typeInfo(@TypeOf(flags)).@"struct".field_names) |name| {
        @field(isr, name) = @field(flags, name);
    }
    ADC1.ISR.write(isr);
}

/// Poll `done` until it returns true; `Error.Timeout` once more than
/// `limit_ms` has passed without.
fn waitFor(comptime done: fn () bool, limit_ms: u32) Error!void {
    const start = clock.get_tick();
    while (!done()) {
        if (clock.elapsed_ms(start) > limit_ms) {
            // Once more: something may have held the core past the limit.
            if (done()) return;
            return Error.Timeout;
        }
    }
}

fn calibrated() bool {
    return ADC1.CR.read().ADCAL == 0;
}

fn ready() bool {
    if (ADC1.ISR.read().ADRDY == 1) return true;
    // ADEN set less than 4 ADC clock cycles after the calibration ended is
    // cleared again by the calibration logic: set it until ADRDY comes (ST's
    // `ADC_Enable`).
    if (ADC1.CR.read().ADEN == 0) setCr(.{ .ADEN = 1 });
    return false;
}

fn converted() bool {
    return ADC1.ISR.read().EOC == 1;
}
