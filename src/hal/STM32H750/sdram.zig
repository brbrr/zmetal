//! FMC SDRAM driver for STM32H750 (fmc_v3x1 peripheral, SDRAM bank 1).
//!
//! Brings up the Daisy Seed's 64 MB external SDRAM (AS4C16M32MSA-6BIN) at
//! 0xC0000000 via the FMC controller's dedicated SDRAM state machine. Config
//! values and the init sequence are ported from libdaisy's
//! `src/dev/sdram.cpp` (proven on this exact board); register field names are
//! transcribed from microzig's generated `fmc_v3x1.FMC` struct.

const microzig = @import("microzig");
const chip = microzig.chip;
const daisy = @import("daisy.zig");
const gpio = @import("gpio.zig");
const clock = @import("clock.zig");

const regs = chip.peripherals.FMC;
const rcc = chip.peripherals.RCC;

/// FMC kernel clock (FMCSEL = PLL2_R per `daisy.clk_config.FMCCLockSelection`),
/// read from the computed clock tree — same mechanism sdmmc.zig uses for
/// `KERNEL_CLK_HZ`. Rounded to the nearest MHz to shed f32 noise.
const FMC_KER_HZ: u32 = @intFromFloat(@round(@as(f64, daisy.clock_outputs.FMCoutput) / 1_000_000.0) * 1_000_000.0);

/// SDCLK = FMC_ker / 2 (SDCR.SDCLK = Div2, per the config values below).
const SDCLK_HZ: u32 = FMC_KER_HZ / 2;

/// Refresh timer COUNT, matching libdaisy's 0x81A-20 = 2054 (proven on this
/// board). The textbook formula for 100 MHz SDCLK / 8192 rows gives 761 (more
/// frequent); libdaisy's larger interval works fine and is kept for parity.
const REFRESH_COUNT: u13 = 0x81A - 20;

pub const BASE: usize = 0xC000_0000;
pub const SIZE: usize = 64 * 1024 * 1024;

/// `selfTest()` result: 1 = pass, 0 = fail/not-run.
pub var st_ok: u32 = 0;
/// First mismatch byte offset from BASE; 0xFFFF_FFFF if the test passed.
pub var st_fail_addr: u32 = 0xFFFF_FFFF;

comptime {
    // Written by selfTest(), read only via the debugger. ReleaseSafe would
    // dead-strip these write-only globals — pin them as named symbols so they
    // survive and are readable over SWD.
    @export(&st_ok, .{ .name = "sdram_st_ok" });
    @export(&st_fail_addr, .{ .name = "sdram_st_fail_addr" });
}

/// Bring up FMC SDRAM bank 1. Usable at `BASE` after this returns.
pub fn init() void {
    // --- Clock + pins ---
    rcc.AHB3ENR.modify(.{ .FMCEN = 1 });
    _ = rcc.AHB3ENR.read(); // RCC settle readback
    configurePins();

    // --- Step 4: FMC controller config ---
    // ColumnBits=9, RowBits=13, MemBusWidth=32, InternalBanks=4, CAS=3,
    // ReadBurst=enable, ReadPipeDelay=0, SDCLK=FMC_ker/2, WriteProtection off.
    regs.SDCR[0].modify(.{
        .NC = .Bits9,
        .NR = .Bits13,
        .MWID = .Bits32,
        .NB = .NB4,
        .CAS = .Clocks3,
        .WP = 0,
        .SDCLK = .Div2,
        .RBURST = 1,
        .RPIPE = .NoDelay,
    });

    // SDTR timings (SDCLK cycles), values are N-1 encoded per the FMC
    // register semantics (matches libdaisy's SdramTiming verbatim: field
    // values below are the *delay counts*, transcribed directly into the
    // like-named register fields).
    regs.SDTR[0].modify(.{
        .TMRD = 2 - 1, // LoadToActiveDelay
        .TXSR = 7 - 1, // ExitSelfRefreshDelay
        .TRAS = 4 - 1, // SelfRefreshTime
        .TRC = 8 - 1, // RowCycleDelay
        .TWR = 3 - 1, // WriteRecoveryTime
        .TRP = 16 - 1, // RPDelay
        .TRCD = 10 - 1, // RCDDelay
    });

    // Enable the FMC controller. BCR1.FMCEN (bit 31) is the controller-level
    // enable, distinct from the RCC AHB3ENR clock gate set above; STM32H7
    // requires it (ST HAL's __FMC_ENABLE()). Without it the FMC never drives
    // the external bus and every SDRAM access takes a precise BusFault.
    regs.BCR1.modify(.{ .FMCEN = 1 });

    // --- Init command sequence (SDRAM bank 1: SDNE0/SDCKE0) ---
    // This FMC variant's SDSR does not expose a usable BUSY flag, so instead of
    // busy-polling we insert explicit spacing between commands (SDCLK-domain
    // command times are ns-scale; the delays below are microseconds).
    regs.SDCMR.modify(.{ .MODE = .ClockConfigurationEnable, .CTB1 = 1, .CTB2 = 0, .NRFS = 0, .MRD = 0 });
    // JEDEC requires a >=100us pause after the clock-enable command. A
    // cycle-counted busy-wait (not the SysTick delay) keeps this real regardless
    clock.delay_us(1000);

    regs.SDCMR.modify(.{ .MODE = .PALL, .CTB1 = 1, .CTB2 = 0, .NRFS = 0, .MRD = 0 });
    clock.delay_us(200);

    // NRFS holds (AutoRefreshNumber - 1); issue 4 auto-refresh cycles.
    regs.SDCMR.modify(.{ .MODE = .AutoRefreshCommand, .CTB1 = 1, .CTB2 = 0, .NRFS = 4 - 1, .MRD = 0 });
    clock.delay_us(200);

    // Mode register (= libdaisy's 0x232): burst length 4, sequential burst,
    // CAS latency 3, single-location write burst.
    const mode_reg: u13 =
        (1 << 1) | // BURST_LENGTH_4
        (0 << 3) | // BURST_TYPE_SEQUENTIAL
        (3 << 4) | // CAS_LATENCY_3 ((1<<4)|(1<<5))
        (1 << 9); // WRITEBURST_MODE_SINGLE

    regs.SDCMR.modify(.{ .MODE = .LoadModeRegister, .CTB1 = 1, .CTB2 = 0, .NRFS = 0, .MRD = mode_reg });
    clock.delay_us(200);

    regs.SDRTR.modify(.{ .COUNT = REFRESH_COUNT });
}

/// FMC SDRAM pins (Daisy Seed), all AF12. Transcribed from libdaisy
/// `src/dev/sdram.cpp` HAL_FMC_MspInit. NOTE: SDNWE is on PH5 (the Daisy's
/// actual routing), not PC0 as libdaisy's comment claims — driving only PC0
/// leaves the SDRAM write-enable floating (corrupt writes / addressing alias).
/// Both are configured, matching libdaisy's runtime.
fn configurePins() void {
    gpio.configureAlternates(&.{
        // Address A0-A12
        .{ .port = "F", .num = "0", .af = .af12 }, // A0
        .{ .port = "F", .num = "1", .af = .af12 }, // A1
        .{ .port = "F", .num = "2", .af = .af12 }, // A2
        .{ .port = "F", .num = "3", .af = .af12 }, // A3
        .{ .port = "F", .num = "4", .af = .af12 }, // A4
        .{ .port = "F", .num = "5", .af = .af12 }, // A5
        .{ .port = "F", .num = "12", .af = .af12 }, // A6
        .{ .port = "F", .num = "13", .af = .af12 }, // A7
        .{ .port = "F", .num = "14", .af = .af12 }, // A8
        .{ .port = "F", .num = "15", .af = .af12 }, // A9
        .{ .port = "G", .num = "0", .af = .af12 }, // A10
        .{ .port = "G", .num = "1", .af = .af12 }, // A11
        .{ .port = "G", .num = "2", .af = .af12 }, // A12
        // Data D0-D31
        .{ .port = "D", .num = "14", .af = .af12 }, // D0
        .{ .port = "D", .num = "15", .af = .af12 }, // D1
        .{ .port = "D", .num = "0", .af = .af12 }, // D2
        .{ .port = "D", .num = "1", .af = .af12 }, // D3
        .{ .port = "E", .num = "7", .af = .af12 }, // D4
        .{ .port = "E", .num = "8", .af = .af12 }, // D5
        .{ .port = "E", .num = "9", .af = .af12 }, // D6
        .{ .port = "E", .num = "10", .af = .af12 }, // D7
        .{ .port = "E", .num = "11", .af = .af12 }, // D8
        .{ .port = "E", .num = "12", .af = .af12 }, // D9
        .{ .port = "E", .num = "13", .af = .af12 }, // D10
        .{ .port = "E", .num = "14", .af = .af12 }, // D11
        .{ .port = "E", .num = "15", .af = .af12 }, // D12
        .{ .port = "D", .num = "8", .af = .af12 }, // D13
        .{ .port = "D", .num = "9", .af = .af12 }, // D14
        .{ .port = "D", .num = "10", .af = .af12 }, // D15
        .{ .port = "H", .num = "8", .af = .af12 }, // D16
        .{ .port = "H", .num = "9", .af = .af12 }, // D17
        .{ .port = "H", .num = "10", .af = .af12 }, // D18
        .{ .port = "H", .num = "11", .af = .af12 }, // D19
        .{ .port = "H", .num = "12", .af = .af12 }, // D20
        .{ .port = "H", .num = "13", .af = .af12 }, // D21
        .{ .port = "H", .num = "14", .af = .af12 }, // D22
        .{ .port = "H", .num = "15", .af = .af12 }, // D23
        .{ .port = "I", .num = "0", .af = .af12 }, // D24
        .{ .port = "I", .num = "1", .af = .af12 }, // D25
        .{ .port = "I", .num = "2", .af = .af12 }, // D26
        .{ .port = "I", .num = "3", .af = .af12 }, // D27
        .{ .port = "I", .num = "6", .af = .af12 }, // D28
        .{ .port = "I", .num = "7", .af = .af12 }, // D29
        .{ .port = "I", .num = "9", .af = .af12 }, // D30
        .{ .port = "I", .num = "10", .af = .af12 }, // D31
        // Bank address
        .{ .port = "G", .num = "4", .af = .af12 }, // BA0
        .{ .port = "G", .num = "5", .af = .af12 }, // BA1
        // Control
        .{ .port = "F", .num = "11", .af = .af12 }, // SDNRAS
        .{ .port = "G", .num = "15", .af = .af12 }, // SDNCAS
        .{ .port = "H", .num = "5", .af = .af12 }, // SDNWE (Daisy actual)
        .{ .port = "C", .num = "0", .af = .af12 }, // SDNWE (alt; libdaisy also sets)
        .{ .port = "H", .num = "3", .af = .af12 }, // SDNE0
        .{ .port = "H", .num = "2", .af = .af12 }, // SDCKE0
        .{ .port = "G", .num = "8", .af = .af12 }, // SDCLK
        // Byte lane enables
        .{ .port = "E", .num = "0", .af = .af12 }, // NBL0
        .{ .port = "E", .num = "1", .af = .af12 }, // NBL1
        .{ .port = "I", .num = "4", .af = .af12 }, // NBL2
        .{ .port = "I", .num = "5", .af = .af12 }, // NBL3
    });
}

/// Destructive RAM test: write an incrementing pattern across the first 1 MB of
/// SDRAM, read it back, and record the result in `st_ok` / `st_fail_addr`
/// (inspectable over SWD). Not run during normal boot — call manually when
/// verifying hardware. The 1 MB span far exceeds the 16 KB D-cache, so most
/// accesses round-trip through the real FMC bus rather than hitting the cache.
pub fn selfTest() void {
    st_ok = 0;
    st_fail_addr = 0xFFFF_FFFF;

    const words: [*]volatile u32 = @ptrFromInt(BASE);
    const n: u32 = 256 * 1024; // 1 MB

    var i: u32 = 0;
    while (i < n) : (i += 1) words[i] = i;
    i = 0;
    while (i < n) : (i += 1) {
        if (words[i] != i) {
            st_fail_addr = i * 4;
            return;
        }
    }

    st_ok = 1;
}
