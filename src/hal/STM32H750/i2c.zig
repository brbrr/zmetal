//! I2C driver for STM32H750, wrapping microzig's `i2c_v2` with Daisy-specific
//! pin/timing config and a robust register-level transfer path (see
//! `i2c_device` for why the built-in blocking loops are bypassed).
//!
//! Usage: `var dev = try I2C_Device.init(.I2C1, .{});` then
//! `dev.i2c_device()` for the microzig driver interface.

const std = @import("std");
const microzig = @import("microzig");
const chip = microzig.chip;
const drivers = microzig.drivers;

// Import STM32 common I2C implementation
const stm32_common = @import("stm32_common");
const i2c_v2 = stm32_common.i2c_v2;
const enums = stm32_common.enums;

// Import HAL modules
const rcc = @import("rcc.zig");
const gpio = @import("gpio.zig");
const clock = @import("clock.zig");
const time = @import("time.zig");
const i2c_seg = @import("i2c_seg.zig");
const i2c_gap = @import("i2c_gap.zig");
const i2c_recovery = @import("i2c_recovery.zig");
const i2c_regs = microzig.chip.types.peripherals.i2c_v2;

fn reloadMode(more: bool) i2c_regs.RELOAD {
    return if (more) .NotCompleted else .Completed;
}

/// Software end (TC, bus held) while more segments follow or a repeated START
/// is wanted; otherwise automatic STOP after NBYTES.
fn endMode(hold: bool) i2c_regs.AUTOEND {
    return if (hold) .Software else .Automatic;
}

/// Re-export I2C_Device types from microzig
pub const Address = drivers.base.I2C_Device.Address;
pub const Error = drivers.base.I2C_Device.Error;
pub const InterfaceError = drivers.base.I2C_Device.InterfaceError;

/// What one bus recovery found and did (see `i2c_recovery.zig`).
pub const Recovery = i2c_recovery.Recovery;

/// I2C peripheral selection
pub const Peripheral = enum {
    I2C1,
    I2C2,
    I2C3,
    I2C4,

    fn to_i2c_type(self: Peripheral) enums.I2C_Type {
        return @field(enums.I2C_Type, @tagName(self));
    }
};

/// I2C clock speed configuration
pub const Speed = enum {
    /// Standard mode: 100 kHz
    I2C_100KHZ,
    /// Fast mode: 400 kHz
    I2C_400KHZ,
    /// Fast mode plus: ~886 kHz (approximates 1 MHz)
    I2C_1MHZ,
};

/// TIMINGR for `speed` at the actual I2C kernel clock (I2C1/2/3 share
/// `I2C123output`). TIMINGR is a multi-field register a solver (CubeMX) produces,
/// not a simple divide, so we don't compute it — we carry the hardware-measured
/// values from libdaisy (`src/per/i2c.cpp`) and select by the resolved clock
/// tree: `[0]` = 120 MHz kernel (480 MHz SYSCLK / VOS0 boost), `[1]` = 100 MHz
/// (400 MHz SYSCLK / VOS1). Any other kernel clock fails the build loudly rather
/// than silently mis-timing the bus.
fn timingrFor(comptime speed: Speed) u32 {
    const proven: [2]u32 = switch (speed) {
        .I2C_100KHZ => .{ 0x6090435F, 0x30E0628A },
        .I2C_400KHZ => .{ 0x30B00F2D, 0x20D01132 },
        .I2C_1MHZ => .{ 0x10A00B20, 0x1080091A },
    };
    return switch (@as(u32, @intFromFloat(rcc.clock_outputs.I2C123output))) {
        120_000_000 => proven[0],
        100_000_000 => proven[1],
        else => @compileError("no proven I2C TIMINGR for this kernel clock — add a measured value (cf. libdaisy src/per/i2c.cpp)"),
    };
}

/// I2C configuration structure
///
/// `min_start_gap_us` and `min_bus_free_us` exist for the BQ25628 charger
/// (TI SLUSEG4C §8.5.1): at least 90 us between a START and any later START
/// on the bus, at any speed, and at 400 kHz also a bus-free time (STOP to
/// START) of at least 68 us. The same section asks for tSU:STA >= 68 us
/// before a repeated START at 400 kHz. A master cannot stretch that with
/// this peripheral: the driver waits for the gaps before the one CR2 write
/// that sets up the transfer and sets START, so before a repeated START the
/// peripheral holds the bus in TC with SCL low for the whole wait, and
/// tSU:STA (SCL high) stays the peripheral's own. On a bus with such a
/// part, 400 kHz targets should use plain reads and writes (no repeated
/// START), or run at 100 kHz, where only the 90 us rule applies.
pub const Config = struct {
    /// Clock speed selection (default: 400 kHz)
    speed: Speed = .I2C_400KHZ,

    /// Pin configuration (optional - use default Daisy Seed pins if not specified)
    /// If provided, these pins will be configured automatically
    pin_config: ?PinConfig = null,

    /// Override TIMINGR register value (optional - uses libdaisy tested values if not specified)
    /// If null, uses hardcoded values from libdaisy that are known to work
    timingr_override: ?u32 = null,

    /// The least time, in microseconds, between two STARTs on this bus,
    /// through the bus and all its targets: repeated STARTs and the START
    /// after a NACK included. The driver keeps 2 us more than this
    /// (`i2c_gap.guard_us`: what its clock cannot see), so 90 waits 92.
    /// 0 (the default) never waits.
    min_start_gap_us: u32 = 0,

    /// The least time, in microseconds, between a STOP (or a transfer that
    /// ended in an error) and the next START that is not a repeated START
    /// (tBUF). The driver keeps 2 us more, as for `min_start_gap_us`.
    /// 0 (the default) never waits.
    min_bus_free_us: u32 = 0,
};

/// Pin configuration for I2C
pub const PinConfig = struct {
    scl: gpio.AfPin,
    sda: gpio.AfPin,
};

/// Default pin configurations for Daisy Seed board
pub const daisy_pin_configs = struct {
    /// I2C1: PB8 (SCL), PB9 (SDA) - AF4
    pub const I2C1 = PinConfig{
        .scl = .{ .pin = .{ .port = .B, .num = 8 }, .af = .af4 },
        .sda = .{ .pin = .{ .port = .B, .num = 9 }, .af = .af4 },
    };

    /// I2C2: PB10 (SCL), PB11 (SDA) - AF4
    pub const I2C2 = PinConfig{
        .scl = .{ .pin = .{ .port = .B, .num = 10 }, .af = .af4 },
        .sda = .{ .pin = .{ .port = .B, .num = 11 }, .af = .af4 },
    };

    /// I2C3: PA8 (SCL), PC9 (SDA) - AF4
    pub const I2C3 = PinConfig{
        .scl = .{ .pin = .{ .port = .A, .num = 8 }, .af = .af4 },
        .sda = .{ .pin = .{ .port = .C, .num = 9 }, .af = .af4 },
    };

    /// I2C4: PD12 (SCL), PD13 (SDA) - AF4
    pub const I2C4 = PinConfig{
        .scl = .{ .pin = .{ .port = .D, .num = 12 }, .af = .af4 },
        .sda = .{ .pin = .{ .port = .D, .num = 13 }, .af = .af4 },
    };
};

/// `time.nowUs`, kept out of line: the driver reads the time in several
/// places, some inlined into every `wait_flag`, and a copy of `nowUs` at
/// each made synth about 4 KB larger.
noinline fn nowUs() u64 {
    return time.nowUs();
}

/// Pulse the peripheral's RCC reset line.
fn resetPeripheral(comptime peripheral: Peripheral) void {
    const RCC = microzig.chip.peripherals.RCC;
    const field = @tagName(peripheral) ++ "RST";
    const reg = if (peripheral == .I2C4) &RCC.APB4RSTR else &RCC.APB1LRSTR;
    reg.modify_one(field, 1);
    clock.delay_us(10);
    reg.modify_one(field, 0);
    clock.delay_us(10);
}

/// I2C Device wrapper that provides zero-cost abstraction over microzig's I2C_Device
pub const I2C_Device = struct {
    inner: i2c_v2.I2C_Device,
    /// What the bus recovery in `init` found and did.
    boot_recovery: Recovery,
    /// The run-time bus recovery on this device's pins (see `recoverBus`).
    /// A comptime-made function, because the GPIO pins are comptime.
    pin_recovery: *const fn () Recovery,
    /// The TIMINGR of the bus's own speed (`Config.speed`, or
    /// `Config.timingr_override`): what `i2c_device()` transfers run at.
    default_timingr: u32,
    /// The TIMINGR in the peripheral now: a `Target` may have switched it.
    current_timingr: u32,
    /// `Config.min_start_gap_us`.
    min_start_gap_us: u32,
    /// `Config.min_bus_free_us`.
    min_bus_free_us: u32,
    /// `nowUs()` just before the last START (kept while a gap is set; set
    /// by `init` and `recoverBus` too, for their STOPs).
    last_start_us: u64 = 0,
    /// `nowUs()` when the last transfer ended (kept while
    /// `min_bus_free_us` is set; set by `init` and `recoverBus` too).
    last_stop_us: u64 = 0,

    /// Initialize an I2C peripheral with the given configuration
    /// This should be called at comptime or at startup to compute timing parameters
    ///
    /// It ends by applying the configuration: the peripheral is enabled
    /// with its TIMINGR when it returns.
    pub fn init(comptime peripheral: Peripheral, comptime config: Config) !I2C_Device {
        const i2c_type = comptime peripheral.to_i2c_type();

        // Initialize the underlying microzig I2C device
        // This computes timing registers based on the clock configuration
        var inner = try i2c_v2.I2C_Device.init(i2c_type);

        // Override TIMINGR with libdaisy proven values if requested or use speed-based defaults
        const timingr: u32 = if (config.timingr_override) |timingr_val|
            timingr_val
        else
            timingrFor(config.speed);
        inner.i2c.timingr = @bitCast(timingr);

        // Configure pins if specified, otherwise use defaults
        const pin_cfg = config.pin_config orelse switch (peripheral) {
            .I2C1 => daisy_pin_configs.I2C1,
            .I2C2 => daisy_pin_configs.I2C2,
            .I2C3 => daisy_pin_configs.I2C3,
            .I2C4 => daisy_pin_configs.I2C4,
        };

        // Reset the peripheral (clears a BUSY state left over from before a CPU
        // reset), recover a bus left stuck mid-transfer, THEN switch the pins to
        // the I2C alternate function.
        resetPeripheral(peripheral);
        const boot = recover_bus(pin_cfg, .if_clocked);
        configure_pins(pin_cfg);

        var dev = I2C_Device{
            .inner = inner,
            .boot_recovery = boot,
            .pin_recovery = &RunTimeRecovery(pin_cfg).run,
            .default_timingr = timingr,
            .current_timingr = timingr,
            .min_start_gap_us = config.min_start_gap_us,
            .min_bus_free_us = config.min_bus_free_us,
        };
        dev.apply();
        // The boot recovery may have clocked the bus and sent a STOP (a
        // START and a STOP on the wire), as `recoverBus` does: the first
        // transfer waits its gaps from here. Stamped whatever the recovery
        // found, which costs a first transfer within one gap of `init` the
        // rest of that gap.
        if (comptime config.min_start_gap_us != 0 or config.min_bus_free_us != 0) {
            const now = nowUs();
            dev.last_start_us = now;
            dev.last_stop_us = now;
        }
        return dev;
    }

    /// Frees a bus that a slave holds, at run time. The peripheral goes
    /// off, which resets its state machine and releases the lines. The
    /// recovery then runs on the device's own pins, always with a STOP.
    /// Then the pins go back to the alternate function, and `apply`
    /// enables the peripheral again with its TIMINGR.
    ///
    /// It blocks for about 150 us. Call it between transfers, from the
    /// context that does the transfers. It writes the GPIO port's mode
    /// registers, so no other context may configure pins of that port
    /// at the same time.
    pub fn recoverBus(self: *I2C_Device) Recovery {
        const r = self.regs();
        r.CR1.modify(.{ .PE = 0 });
        const result = self.pin_recovery();
        r.ICR.write_raw(ICR_CLEAR_MASK);
        self.apply();
        // The recovery's STOP is a START and then a STOP on the wire (SDA
        // falls, then rises, with SCL high): both count for the gaps.
        if (self.min_start_gap_us != 0) self.last_start_us = nowUs();
        self.noteStop();
        return result;
    }

    /// Apply the configuration and enable the I2C peripheral. `init`
    /// already does this; calling it again is safe (callers that still
    /// call it after `init` keep working). It writes the bus's own
    /// TIMINGR, whatever speed a `Target` left in the peripheral.
    pub fn apply(self: *I2C_Device) void {
        self.inner.apply();
        self.current_timingr = self.default_timingr;
    }

    /// A view of this bus for one slave whose transfers run at `speed`,
    /// whatever the bus's own speed; the bus's gaps between STARTs apply
    /// to it too. The target keeps a pointer to the bus: `self` must stay
    /// at a stable address while the target is used.
    pub fn target(self: *I2C_Device, comptime speed: Speed) Target {
        return .{ .bus = self, .timingr = timingrFor(speed) };
    }

    /// Get the I2C_Device interface for use with microzig drivers.
    ///
    /// Returns a drivers.base.I2C_Device backed by THIS module's robust transfer
    /// routines (see `robust_vtable`), not microzig's built-in blocking loops.
    /// microzig's i2c_v2 spins forever with no timeout and never clears NACKF/
    /// STOPF, so a single NACK poisons every later transfer. Our routines add a
    /// per-transfer timeout, clear the status flags, and reset the peripheral on
    /// error — modeled on the libdaisy reference (10 ms timeout, re-init on error).
    ///
    /// Transfers through it run at the bus's configured speed (see `target`
    /// for a slave at another speed).
    ///
    /// `self` must live at a stable address (drivers copy this fat pointer by
    /// value and keep `ptr = self`).
    pub fn i2c_device(self: *I2C_Device) drivers.base.I2C_Device {
        return .{ .ptr = self, .vtable = &robust_vtable };
    }

    // === Robust register-level transfer implementation ===============
    //
    // Operates directly on the peripheral register block (self.inner.i2c.regs).
    // The clock, TIMINGR and pins are already set up by init()/apply().

    /// Per-transfer timeout, in milliseconds (matches libdaisy's default).
    const TRANSFER_TIMEOUT_MS: u32 = 10;

    /// ICR write-1-to-clear mask: NACKCF(4) | STOPCF(5) | BERRCF(8) | ARLOCF(9).
    /// Written raw so we don't depend on per-field register names.
    const ICR_CLEAR_MASK: u32 = (1 << 4) | (1 << 5) | (1 << 8) | (1 << 9);

    fn regs(self: *I2C_Device) @TypeOf(self.inner.i2c.regs) {
        return self.inner.i2c.regs;
    }

    /// Reset the peripheral state machine after an error or timeout. Toggling PE
    /// releases SCL/SDA and clears BUSY and all status flags; TIMINGR is retained.
    /// The error ends the transfer, so the bus-free time counts from here.
    fn recover(self: *I2C_Device) void {
        const r = self.regs();
        r.CR1.modify(.{ .PE = 0 });
        var i: u32 = 0;
        while (i < 16) : (i += 1) asm volatile ("nop"); // hold PE=0 a few APB cycles
        r.CR1.modify(.{ .PE = 1 });
        self.noteStop();
    }

    /// Puts `timingr` in TIMINGR unless it is there already. TIMINGR may
    /// only change while PE = 0, so the peripheral goes off and on again;
    /// between transfers the bus is idle, so that drops nothing.
    fn useTiming(self: *I2C_Device, timingr: u32) void {
        if (timingr == self.current_timingr) return;
        const r = self.regs();
        r.CR1.modify(.{ .PE = 0 });
        r.TIMINGR.write_raw(timingr);
        r.CR1.modify(.{ .PE = 1 });
        self.current_timingr = timingr;
    }

    /// The most rounds `awaitStartGap` waits: the last-resort bound. A
    /// running clock ends the wait in a round or two, also after it was
    /// set back (the stamp is pulled back once, see `i2c_gap.pullBack`).
    /// Only a clock that stands still (SysTick not started: `nowUs` does
    /// not move, and every round asks for the whole gap again), or one
    /// that steps back again in every round, reaches it: about 64 times
    /// the guarded gap, 5.9 ms for a gap of 90 us.
    const GAP_ROUNDS_MAX: u32 = 64;

    /// Waits until the next START is `min_start_gap_us` after the last
    /// START and, unless it is a `repeated` START, `min_bus_free_us` after
    /// the last STOP, each with the guard `i2c_gap.guard_us`; then notes
    /// the START. The transfers call it before the one CR2 write that sets
    /// up the transfer and sets START together, as ST's HAL does
    /// (`I2C_TransferConfig`): nothing of the next transfer is written
    /// during the wait. Before a repeated START the peripheral therefore
    /// stays in TC from the write before, holding the bus with SCL low, so
    /// waiting there is legal.
    ///
    /// Each round's decision is `i2c_gap.startWaitUs` (pure, host-tested):
    /// a stamp later than now (the clock was set back, as
    /// `clock.hal_init_tick` does) counts as taken now, so the wait is then
    /// one whole gap. `clock.delay_us` waits on the cycle counter and does
    /// not run short, but the gaps are measured on `nowUs` (SysTick), a
    /// different counter that counts whole microseconds, so each round asks
    /// `nowUs` again and waits for what is left. A clock that stands still
    /// (SysTick not running) never brings the wait to 0 and ends it after
    /// `GAP_ROUNDS_MAX` rounds, so the wait adds no precondition to the
    /// transfer timeouts' own.
    fn awaitStartGap(self: *I2C_Device, comptime repeated: bool) void {
        if (self.min_start_gap_us == 0 and (repeated or self.min_bus_free_us == 0)) return;
        var rounds: u32 = 0;
        while (rounds < GAP_ROUNDS_MAX) : (rounds += 1) {
            const wait = i2c_gap.startWaitUs(
                nowUs(),
                &self.last_start_us,
                &self.last_stop_us,
                self.min_start_gap_us,
                self.min_bus_free_us,
                repeated,
            );
            if (wait == 0) break;
            clock.delay_us(wait);
        }
        self.last_start_us = nowUs();
    }

    /// Notes that the bus went free now, for `min_bus_free_us`.
    fn noteStop(self: *I2C_Device) void {
        if (self.min_bus_free_us != 0) self.last_stop_us = nowUs();
    }

    /// Wait until the given ISR flag is set, bailing out on NACK/bus-error or a
    /// timeout. On any failure the peripheral is reset before returning.
    fn wait_flag(self: *I2C_Device, comptime flag: []const u8) Error!void {
        const r = self.regs();
        const start = clock.get_tick();
        while (true) {
            const isr = r.ISR.read();
            // Errors first: after an address/data NACK the hardware still raises
            // STOPF (AUTOEND) — if both are visible (poll preempted between them),
            // the NACK must win or an absent device reads as ACK.
            if (isr.NACKF == 1) {
                self.recover();
                return Error.NoAcknowledge;
            }
            if (isr.BERR == 1 or isr.ARLO == 1) {
                self.recover();
                return Error.UnknownAbort;
            }
            if (@field(isr, flag) == 1) return;
            if (clock.get_tick() -% start >= TRANSFER_TIMEOUT_MS) {
                self.recover();
                return Error.Timeout;
            }
        }
    }

    /// Wait for the bus to be free before starting a new transfer.
    fn wait_not_busy(self: *I2C_Device) Error!void {
        const r = self.regs();
        const start = clock.get_tick();
        while (r.ISR.read().BUSY == 1) {
            if (clock.get_tick() -% start >= TRANSFER_TIMEOUT_MS) {
                self.recover();
                return Error.Timeout;
            }
        }
    }

    /// Master write of `chunks` as ONE transaction: a single START, the
    /// concatenated bytes (NBYTES <= 255 per segment, RELOAD between segments),
    /// then STOP. `restart` instead holds the bus (software end, wait for TC) so
    /// a repeated-START read can follow.
    fn transfer_write(self: *I2C_Device, address: Address, chunks: []const []const u8, comptime restart: bool) Error!void {
        const r = self.regs();
        r.ICR.write_raw(ICR_CLEAR_MASK); // drop any stale flags from a prior transfer
        try self.wait_not_busy();

        var segs = i2c_seg.segments(i2c_seg.totalLen([]const u8, chunks));
        var bytes = i2c_seg.ByteIter([]const u8){ .chunks = chunks };
        // Zero-length write (address probe): NBYTES = 0.
        var seg = segs.next() orelse i2c_seg.Segment{ .nbytes = 0, .reload = false };

        // The set-up and START in one write, after the wait (see `awaitStartGap`).
        self.awaitStartGap(false);
        r.CR2.modify(.{
            .NBYTES = seg.nbytes,
            .RELOAD = reloadMode(seg.reload),
            .SADD = @as(u10, @intCast(@intFromEnum(address))) << 1,
            .AUTOEND = endMode(seg.reload or restart),
            .DIR = .Write,
            .START = 1,
        });

        while (true) {
            for (0..seg.nbytes) |_| {
                try self.wait_flag("TXIS");
                r.TXDR.modify(.{ .TXDATA = bytes.next().?.* });
            }
            if (!seg.reload) break;
            try self.wait_flag("TCR");
            seg = segs.next().?;
            r.CR2.modify(.{
                .NBYTES = seg.nbytes,
                .RELOAD = reloadMode(seg.reload),
                .AUTOEND = endMode(seg.reload or restart),
            });
        }

        if (restart) {
            try self.wait_flag("TC");
        } else {
            try self.wait_flag("STOPF");
            r.ICR.write_raw(ICR_CLEAR_MASK);
            self.noteStop();
        }
    }

    /// Master read into `chunks` as ONE transaction (segmented like
    /// `transfer_write`). Issues its own (repeated) START. When it follows a
    /// `restart` write, `after_restart` must be true: the bus is legitimately
    /// still BUSY (held for the repeated START), so skip the bus-free wait.
    fn transfer_read(self: *I2C_Device, address: Address, chunks: []const []u8, comptime after_restart: bool) Error!void {
        const r = self.regs();
        r.ICR.write_raw(ICR_CLEAR_MASK);
        if (!after_restart) try self.wait_not_busy();

        var segs = i2c_seg.segments(i2c_seg.totalLen([]u8, chunks));
        var bytes = i2c_seg.ByteIter([]u8){ .chunks = chunks };
        var seg = segs.next() orelse {
            // Nothing to read. After a `restart` write the bus is still held
            // (TC, SCL stretched): release it with a STOP, or the next transfer
            // finds the bus BUSY.
            if (after_restart) {
                r.CR2.modify(.{ .STOP = 1 });
                try self.wait_flag("STOPF");
                r.ICR.write_raw(ICR_CLEAR_MASK);
                self.noteStop();
            }
            return;
        };

        // The set-up and START in one write, after the wait (see
        // `awaitStartGap`): after a `restart` write the peripheral waits in
        // TC, and AUTOEND written there on its own, before START, may end
        // the transfer with a STOP instead of the repeated START.
        self.awaitStartGap(after_restart);
        r.CR2.modify(.{
            .NBYTES = seg.nbytes,
            .RELOAD = reloadMode(seg.reload),
            .SADD = @as(u10, @intCast(@intFromEnum(address))) << 1,
            .AUTOEND = endMode(seg.reload),
            .DIR = .Read,
            .START = 1,
        });

        while (true) {
            for (0..seg.nbytes) |_| {
                try self.wait_flag("RXNE");
                bytes.next().?.* = r.RXDR.read().RXDATA;
            }
            if (!seg.reload) break;
            try self.wait_flag("TCR");
            seg = segs.next().?;
            r.CR2.modify(.{
                .NBYTES = seg.nbytes,
                .RELOAD = reloadMode(seg.reload),
                .AUTOEND = endMode(seg.reload),
            });
        }

        try self.wait_flag("STOPF");
        r.ICR.write_raw(ICR_CLEAR_MASK);
        self.noteStop();
    }

    const robust_vtable = drivers.base.I2C_Device.VTable{
        .writev_fn = robust_writev,
        .readv_fn = robust_readv,
        .writev_then_readv_fn = robust_writev_then_readv,
    };

    fn robust_writev(ctx: *anyopaque, address: Address, datagrams: []const []const u8) InterfaceError!void {
        const self: *I2C_Device = @ptrCast(@alignCast(ctx));
        return self.writevAt(self.default_timingr, address, datagrams);
    }

    fn robust_readv(ctx: *anyopaque, address: Address, datagrams: []const []u8) InterfaceError!usize {
        const self: *I2C_Device = @ptrCast(@alignCast(ctx));
        return self.readvAt(self.default_timingr, address, datagrams);
    }

    fn robust_writev_then_readv(
        ctx: *anyopaque,
        address: Address,
        write_chunks: []const []const u8,
        read_chunks: []const []u8,
    ) InterfaceError!void {
        const self: *I2C_Device = @ptrCast(@alignCast(ctx));
        return self.writevThenReadvAt(self.default_timingr, address, write_chunks, read_chunks);
    }

    // The transfers behind both vtables, the bus's and a `Target`'s: check
    // the address, switch to `timingr`, then the register-level transfer.

    fn writevAt(self: *I2C_Device, timingr: u32, address: Address, datagrams: []const []const u8) InterfaceError!void {
        address.check_reserved() catch return InterfaceError.TargetAddressReserved;
        self.useTiming(timingr);
        try self.transfer_write(address, datagrams, false);
    }

    fn readvAt(self: *I2C_Device, timingr: u32, address: Address, datagrams: []const []u8) InterfaceError!usize {
        address.check_reserved() catch return InterfaceError.TargetAddressReserved;
        self.useTiming(timingr);
        try self.transfer_read(address, datagrams, false);
        return i2c_seg.totalLen([]u8, datagrams);
    }

    /// Switches speed once, before the write: turning the peripheral off
    /// between the write and the repeated-START read would drop the bus
    /// it holds.
    fn writevThenReadvAt(
        self: *I2C_Device,
        timingr: u32,
        address: Address,
        write_chunks: []const []const u8,
        read_chunks: []const []u8,
    ) InterfaceError!void {
        address.check_reserved() catch return InterfaceError.TargetAddressReserved;
        self.useTiming(timingr);
        try self.transfer_write(address, write_chunks, true);
        try self.transfer_read(address, read_chunks, true);
    }

    /// Write data to an I2C device (blocking)
    pub fn write(self: *I2C_Device, address: Address, data: []const u8) InterfaceError!void {
        const dev = self.i2c_device();
        return dev.write(address, data);
    }

    /// Write multiple chunks to an I2C device (blocking)
    pub fn writev(self: *I2C_Device, address: Address, chunks: []const []const u8) InterfaceError!void {
        const dev = self.i2c_device();
        return dev.writev(address, chunks);
    }

    /// Read data from an I2C device (blocking)
    pub fn read(self: *I2C_Device, address: Address, buffer: []u8) InterfaceError!usize {
        const dev = self.i2c_device();
        return dev.read(address, buffer);
    }

    /// Read multiple chunks from an I2C device (blocking)
    pub fn readv(self: *I2C_Device, address: Address, buffers: []const []u8) InterfaceError!usize {
        const dev = self.i2c_device();
        return dev.readv(address, buffers);
    }

    /// Write then read from an I2C device (blocking, with repeated start)
    /// This is useful for reading registers: write register address, then read value
    pub fn write_then_read(
        self: *I2C_Device,
        address: Address,
        write_data: []const u8,
        read_buffer: []u8,
    ) InterfaceError!void {
        const dev = self.i2c_device();
        return dev.write_then_read(address, write_data, read_buffer);
    }

    /// Write multiple chunks then read multiple chunks (blocking, with repeated start)
    pub fn writev_then_readv(
        self: *I2C_Device,
        address: Address,
        write_chunks: []const []const u8,
        read_chunks: []const []u8,
    ) InterfaceError!void {
        const dev = self.i2c_device();
        return dev.writev_then_readv(address, write_chunks, read_chunks);
    }

    /// Read from a specific register address (convenience function)
    /// Equivalent to write_then_read with a single-byte register address
    pub fn read_register(
        self: *I2C_Device,
        device_addr: Address,
        register_addr: u8,
        buffer: []u8,
    ) InterfaceError!void {
        const reg_bytes = [_]u8{register_addr};
        return self.write_then_read(device_addr, &reg_bytes, buffer);
    }

    /// Write to a specific register address (convenience function)
    /// Sends register address followed by data bytes
    pub fn write_register(
        self: *I2C_Device,
        device_addr: Address,
        register_addr: u8,
        data: []const u8,
    ) InterfaceError!void {
        const reg_bytes = [_]u8{register_addr};
        return self.writev(device_addr, &.{ &reg_bytes, data });
    }
};

/// One slave's view of the bus: transfers through it run at its own speed.
///
/// Made by `I2C_Device.target`. A transfer switches the peripheral to the
/// target's TIMINGR when the bus last ran at another speed, and the bus's
/// gaps between STARTs apply as to any transfer on the bus. It keeps a
/// pointer to the bus, so the bus must stay at a stable address while the
/// target is used.
pub const Target = struct {
    bus: *I2C_Device,
    timingr: u32,

    /// The microzig driver interface for this slave, as
    /// `I2C_Device.i2c_device` but at the target's speed.
    /// `self` must stay at a stable address, like the bus.
    pub fn i2c_device(self: *Target) drivers.base.I2C_Device {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable = drivers.base.I2C_Device.VTable{
        .writev_fn = writev,
        .readv_fn = readv,
        .writev_then_readv_fn = writevThenReadv,
    };

    fn writev(ctx: *anyopaque, address: Address, datagrams: []const []const u8) InterfaceError!void {
        const self: *Target = @ptrCast(@alignCast(ctx));
        return self.bus.writevAt(self.timingr, address, datagrams);
    }

    fn readv(ctx: *anyopaque, address: Address, datagrams: []const []u8) InterfaceError!usize {
        const self: *Target = @ptrCast(@alignCast(ctx));
        return self.bus.readvAt(self.timingr, address, datagrams);
    }

    fn writevThenReadv(
        ctx: *anyopaque,
        address: Address,
        write_chunks: []const []const u8,
        read_chunks: []const []u8,
    ) InterfaceError!void {
        const self: *Target = @ptrCast(@alignCast(ctx));
        return self.bus.writevThenReadvAt(self.timingr, address, write_chunks, read_chunks);
    }
};

/// The run-time recovery for one pin pair, as a function a device keeps.
fn RunTimeRecovery(comptime pin_cfg: PinConfig) type {
    return struct {
        /// Runs the recovery with a STOP, then gives the pins back to the
        /// peripheral.
        fn run() Recovery {
            const r = recover_bus(pin_cfg, .always);
            configure_pins(pin_cfg);
            return r;
        }
    };
}

/// Recover a stuck I2C bus before the peripheral takes over the pins.
///
/// A CPU reset resets the I2C peripheral but NOT the bus or the slaves. A slave
/// (e.g. the MCP23017) interrupted mid-byte keeps driving SDA low, so the next
/// transfer's START never completes and every transfer times out. The standard
/// fix: drive the pins as GPIO and bit-bang up to 9 SCL clocks — one byte + ACK
/// — until the slave finishes and releases SDA, then issue a STOP. Must run
/// BEFORE `configure_pins` switches the pins to the I2C alternate function.
/// `stop` tells when it gives the STOP. It returns what it found and did.
fn recover_bus(comptime pin_cfg: PinConfig, stop: i2c_recovery.Stop) Recovery {
    const Lines = struct {
        const scl = gpio.Pin.from(pin_cfg.scl.pin, .{
            .mode = .output,
            .otype = .OpenDrain,
            .pull = .PullUp,
            .speed = .VeryHighSpeed,
        });
        const sda = gpio.Pin.from(pin_cfg.sda.pin, .{
            .mode = .output,
            .otype = .OpenDrain,
            .pull = .PullUp,
            .speed = .VeryHighSpeed,
        });

        // Open-drain: High releases the line (the pull-ups take it high),
        // Low drives it low.
        pub fn sclHigh(_: @This()) void {
            scl.write(.High);
        }
        pub fn sclLow(_: @This()) void {
            scl.write(.Low);
        }
        pub fn sdaHigh(_: @This()) void {
            sda.write(.High);
        }
        pub fn sdaLow(_: @This()) void {
            sda.write(.Low);
        }
        pub fn sclIsLow(_: @This()) bool {
            return scl.read() == .Low;
        }
        pub fn sdaIsLow(_: @This()) bool {
            return sda.read() == .Low;
        }
        pub fn wait(_: @This()) void {
            bit_delay();
        }
    };

    // The recovery leaves both output latches high, so a later run does
    // not pull a line low when the pins become outputs.
    Lines.scl.configure();
    Lines.sda.configure();
    return i2c_recovery.run(Lines{}, stop);
}

/// Half-period for the recovery bit-bang (~100 kHz). Timing isn't critical (it
/// only has to satisfy a slave's setup/hold); uses
/// `clock.delay_us` because delay_ms's ~1 ms granularity is far too coarse for a
/// µs-scale bit-bang.
inline fn bit_delay() void {
    clock.delay_us(5);
}

/// Configure GPIO pins for I2C function.
///
/// Pins use open-drain with NO internal pull-up, matching the libdaisy reference
/// (`GPIO_MODE_AF_OD` / `GPIO_NOPULL`). The board provides external ~4.7kΩ
/// pull-ups on SCL/SDA, which the 400 kHz TIMINGR values are tuned for; the weak
/// (~40kΩ) internal pull-ups would slow the rise time and are intentionally off.
fn configure_pins(comptime pin_cfg: PinConfig) void {
    // Configure SCL pin
    const scl_pin = comptime gpio.Pin.from(pin_cfg.scl.pin, .{
        .mode = .{ .alternate = pin_cfg.scl.af },
        .otype = .OpenDrain,
        .speed = .VeryHighSpeed,
        .pull = .Floating,
    });
    scl_pin.configure();

    // Configure SDA pin
    const sda_pin = comptime gpio.Pin.from(pin_cfg.sda.pin, .{
        .mode = .{ .alternate = pin_cfg.sda.af },
        .otype = .OpenDrain,
        .speed = .VeryHighSpeed,
        .pull = .Floating,
    });
    sda_pin.configure();
}
