//! A timer channel as a PWM output: edge-aligned PWM mode 1, counting up
//! from 0 with the prescaler at 0, the period worked out from a frequency at
//! comptime.
//!
//! The output is off until a duty is set: `init` starts at duty 0, and the
//! pin is switched to the timer last, so the first level it drives is the
//! off level. Duty 0 and duty 65535 are constant levels, without a glitch
//! pulse: a compare value of 0 holds the channel inactive, one above the
//! reload value holds it active for the whole period. A new duty takes
//! effect at the next period boundary (the compare value is preloaded).
//!
//! Until `init` the pin keeps its reset mode (analog: not driven), so a
//! load that must stay off from reset needs a pull resistor to its off
//! level.
const std = @import("std");
const microzig = @import("microzig");
const chip = microzig.chip;
const timer_v1 = chip.types.peripherals.timer_v1;
const rcc = @import("rcc.zig");
const gpio = @import("gpio.zig");
const pwm_math = @import("pwm_math.zig");

pub const Timer = enum { TIM2 }; // add a timer when a board needs it and it has run on hardware
pub const Channel = enum(u2) { ch1, ch2, ch3, ch4 };

pub const Config = struct {
    /// The channel's output pin and its alternate function, e.g. D16 (PA3)
    /// on AF1 for TIM2 channel 4.
    pin: gpio.AfPin,
    /// In Hz. A period must hold at least 100 timer counts, so a duty step
    /// is at most 1 %: up to about 2.4 MHz at the Seed's 240 MHz timer
    /// clock. 0 or a higher frequency is a compile error.
    frequency_hz: u32,
    /// The load is on while the pin is low.
    active_low: bool = false,
};

/// The clock a timer counts, in Hz. TIM2 is an APB1 timer: `Tim1Output`,
/// 240 MHz on the Seed (APB1 at 120 MHz, doubled for its timers).
fn timerClockHz(comptime timer: Timer) u32 {
    return switch (timer) {
        .TIM2 => @intFromFloat(rcc.clock_outputs.Tim1Output),
    };
}

pub fn Pwm(comptime timer: Timer, comptime channel: Channel) type {
    return struct {
        const Self = @This();
        const regs = @field(chip.peripherals, @tagName(timer));
        const index: u2 = @intFromEnum(channel);

        /// Timer counts in one period.
        period: u32,

        /// Configure the timer and channel and switch the pin to them, at
        /// duty 0: the load is off. A frequency the timer cannot give with
        /// 1 % steps is a compile error.
        ///
        /// The order: clock on; prescaler 0, ARR = period - 1, the channel's
        /// CCR = 0; PWM mode 1 with compare preload; polarity from
        /// `active_low` and the channel output on; ARR preload on; one update
        /// event to load ARR and CCR; counter on; and last the pin to its
        /// alternate function.
        pub fn init(comptime config: Config) Self {
            const period = comptime pwm_math.periodCounts(timerClockHz(timer), config.frequency_hz) catch |e| @compileError(@errorName(e));

            rcc.enable_clock(@field(rcc.RccPeriferals, @tagName(timer)));
            regs.PSC = 0; // 32-bit counter: no prescaler needed
            regs.ARR = period - 1;
            regs.CCR[index] = 0;
            setPwmMode1();
            enableOutput(config.active_low);
            regs.CR1.modify(.{ .ARPE = 1 });
            // Update event: ARR and CCR reach their active registers, and the
            // counter restarts from 0.
            regs.EGR.write(.{ .UG = 1, .@"CCG[0]" = 0, .@"CCG[1]" = 0, .@"CCG[2]" = 0, .@"CCG[3]" = 0, .TG = 0 });
            regs.CR1.modify(.{ .CEN = 1 });

            // Low speed: the gentlest edges, plenty for a PWM output.
            const pin = comptime gpio.Pin.from(config.pin.pin, .{
                .mode = .{ .alternate = config.pin.af },
                .speed = .LowSpeed,
            });
            pin.configure();
            return .{ .period = period };
        }

        /// 0 = always off, 65535 = always on; in between, the on time is
        /// `duty / 65535` of a period. Takes effect at the next period
        /// boundary.
        pub fn setDuty(self: Self, duty: u16) void {
            regs.CCR[index] = pwm_math.compareCounts(self.period, duty);
        }

        /// PWM mode 1 with compare preload in the channel's half of its
        /// capture/compare mode register: CCMR1 holds channels 1 and 2,
        /// CCMR2 channels 3 and 4. The register definitions give these
        /// registers their input-capture layout only (`CCMR_Input`), so the
        /// output-compare fields are written as bits (RM0433, CMSIS
        /// `TIM_CCMRx_*`). From bit `shift` (0 for channels 1 and 3, 8 for 2
        /// and 4): CCxS (2 bits), OCxFE, OCxPE, OCxM[2:0] (3 bits), OCxCE;
        /// and OCxM[3] at bit 16 + `shift`. All of them are cleared, then
        /// CCxS = output, OCxPE = 1 and OCxM = PWM mode 1 (0b0110) set.
        fn setPwmMode1() void {
            const shift: u5 = if (index % 2 == 0) 0 else 8;
            const clear: u32 = (@as(u32, 0xFF) << shift) | (@as(u32, 1) << (16 + shift));
            const set: u32 = (@as(u32, @intFromEnum(timer_v1.CCMR_Output_CCS.Output)) << shift) |
                (@as(u32, 1) << (shift + 3)) | // OCxPE
                (@as(u32, @intFromEnum(timer_v1.OCM.PwmMode1)) << (shift + 4)); // OCxM[2:0]
            const ccmr = &regs.CCMR_Input[index / 2];
            ccmr.raw = (ccmr.raw & ~clear) | set;
        }

        /// The channel's output on (CCxE), with CCxP set for `active_low`
        /// (the output is the inverted reference) and CCxNP clear, as an
        /// output needs.
        fn enableOutput(comptime active_low: bool) void {
            const i = std.fmt.comptimePrint("[{d}]", .{index});
            var ccer = regs.CCER.read();
            @field(ccer, "CCP" ++ i) = @intFromBool(active_low);
            @field(ccer, "CCNP" ++ i) = 0;
            @field(ccer, "CCE" ++ i) = 1;
            regs.CCER.write(ccer);
        }
    };
}
