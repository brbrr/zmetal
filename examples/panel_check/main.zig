//! panel_check: the Daisy side of the v3 board's panel scanner, an
//! STM32C031 on I2C1 (D11 SCL, D12 SDA) that answers at 0x42 with its
//! application and at 0x63 with its ROM bootloader. The C031's NRST is on
//! D26 (PD11, through 1 kOhm) and its INT on D27 (PG9, 10 kOhm pull-up).
//! For the v3 board only. Nothing of it has run on hardware yet.
//!
//! Two images from this one file, each with its own file name and its mode
//! fixed at build time (a comptime value, `build_mode`):
//!
//! - `probe`, `panel_check.{elf,bin}`, **cannot change the C031.** It
//!   sends the bootloader only the five read-only frames listed below (Get
//!   ID and Read Memory), and the application at 0x42 nothing at all;
//!   reading is not writing. It keeps NRST released (it never pulses it),
//!   measures INT's pull-up, waits 50 ms after its own start and records
//!   what answers: an application (its `fw`, its `trial` flag, and whether
//!   INT was low at start), a bootloader (its product ID, the first 8
//!   bytes of flash, and 8 bytes read at 0x1FFF_7800, the option bytes),
//!   or nothing. With an
//!   application it then reads its frames forever, decodes them itself and
//!   copies them into `report`. It never acknowledges a frame and never
//!   clears `booted`, so the application keeps INT low (asserted) for as
//!   long as `probe` runs; `int_low` shows the level. INT's release on an
//!   acknowledge is seen with the `update` image, whose client acknowledges.
//! - `update`, `panel_check_update.{elf,bin}`, does the same, then brings
//!   the scanner to the image this build embeds (`Updater.run`), records
//!   how that went, and mirrors frames forever through `PanelClient`, which
//!   acknowledges them. It is the only image that can change the C031.
//!
//! **What keeps `probe` from writing (rule R-probe)**, and how far each
//! part reaches:
//! - **The barrier, on the wire, at run time.** Every bus write of the
//!   `probe` image goes through `ProbeIo.write`, which sends a frame only if
//!   it is, byte for byte, one of the five of `probe_frames`, and only to
//!   the bootloader at 0x63. These are the Get ID command `02 FD`, the Read
//!   Memory command `11 EE`, the address frames of the flash base
//!   `08 00 00 00 08` and of the option bytes `1F FF 78 00 98`, and the
//!   byte count for 8 bytes `07 F8`. Anything else, every write to the
//!   application at 0x42 included, is refused before the bus is touched
//!   (`error.RefusedInProbe`) and counted in `report.refused_writes`, which
//!   makes the LED blink. Comptime checks run the same `probeMaySend` over
//!   the five frames, every other `{op, ~op}` command frame, the
//!   application's commands and an erase list shaped like an address frame.
//! - **The tripwires, at compile time.** In `probe` these do not compile:
//!   - `Updater.run`: the updater sits on `ProbeBoot`, which has only
//!     `productId` and `readMemory` and keeps no bootloader host, and on
//!     `ProbeIo`, which has no `resetPulse` and no `strap`;
//!   - the name `Host`, the bootloader host with its writing methods;
//!   - `intHeldLow`, `UpdateIo.resetPulse` and `UpdateIo.strap`, which
//!     drive INT or pulse NRST;
//!   - the names `UpdateIo` (the bus with no allow-list), `Client` and
//!     `panel_speed` (the client and its 400 kHz bus);
//!   - `newClient`, whose client acknowledges frames;
//!   - `scanner_image`.
//!
//!   `probe` keeps no D26 handle either: `nrstReleased` returns `void`.
//! - **Not guarded at compile time:** a bootloader host or `PanelClient`
//!   made afresh from its module, the HAL device `bus`, `io.bus` (the
//!   `I2cBus` behind the allow-list), `slow` in `main`, or any other
//!   `I2cBus` or `I2C_Device` value, and `hal.Gpio.init`/`handle` on D26
//!   or D27. Anything built on `io` still meets the allow-list on the wire;
//!   the rest goes around it. Never use them in `probe`.
//!
//! So the only bus writes a `probe` image makes are those five frames, and
//! it writes nothing to the application at 0x42.
//!
//! The strap test exists only in `update`. A strap entry (INT held low
//! through an NRST pulse) makes a committed application erase its own
//! first flash page: a write to the chip, so `probe` has no way to make
//! one. In `update`, set `strap_request` to 1 with a debugger while the
//! frames are mirrored: the example makes one strap entry, waits up to 1 s
//! for an answer and records it (`strap_presence`, `strap_test`).
//!
//! **The bus.** I2C1 at 100 kHz, its own speed, as the charger on the same
//! bus wants: at least 90 us between two STARTs and 68 us from a STOP to
//! the next START (`min_start_gap_us`, `min_bus_free_us`). The start-up
//! probe and all of `run`, the bootloader at 0x63 and the frames at 0x42,
//! go through one `Io` at 100 kHz, and so do `probe`'s frame reads. Only
//! the `update` image's client, after `run`, uses a 400 kHz target. Why
//! 100 kHz for the bootloader:
//! - it is always allowed on this bus (400 kHz would be too, as the host
//!   sends no repeated START, but it leaves less margin);
//! - the ROM's I2C target is unverified silicon whose timing we do not set
//!   (AN2606 says up to 1 MHz), and the board's rise time is unknown until
//!   the board exists: 100 kHz has the most margin for both;
//! - time does not matter here: a healthy update takes about 6 to 9 s at
//!   100 kHz, of which `goTrial`'s read-back of all 32 KB is about 3.3 s.
//!
//! **D26 and D27** are only ever driven low or released, never driven
//! high: both are open-drain whenever they are outputs. D26 is set up
//! once, released (open-drain, latch high), before anything else touches
//! the bus (`nrstReleased`; `probe` keeps no handle to it); only
//! `UpdateIo.resetPulse` (update) drives it low, for 10 ms. D27 is an
//! input (`intReleased`); at start, in both images, it is for 1 ms an
//! input with the Daisy's pull-down, to measure INT's pull-up
//! (`intPulledUp`, `int_pullup`); only `UpdateIo.strap` (update) makes it
//! an open-drain output driven low (`intHeldLow`), and returns it to an
//! input afterwards.
//!
//! **Bounds and the deadline.** The bootloader host bounds every wait by a
//! count of BUSY answers (1 000 for an answer, 10 000 for an erase). Its
//! header puts the whole update at about 40 minutes when the bootloader
//! answers BUSY up to every bound, counting 1 ms a poll. On this `Io` a
//! poll is a `delayMs(1)`, which lasts 1 to 2 ms (`delay_ms` rounds up a
//! tick), plus a one-byte read, about 0.25 ms at 100 kHz: up to about
//! 2.3 ms, so up to about twice the host's figures. AN4221 answers BUSY
//! only at the end of a No-Stretch write or erase, so only a confused
//! bootloader gets near these bounds.
//!
//! `run` gets `run_deadline_ms` (60 s, against an estimated 6 to 9 s for a
//! healthy update). After it every bus read and write of `UpdateIo` fails
//! with `error.DeadlinePassed`, and `report.deadline` says so. Pauses, the
//! NRST pulse and the INT strap are not stopped by it, so the updater's
//! strap entry still works, and its remaining waits end within a few
//! seconds.
//!
//! The updater's uncommit through the bootloader is stopped by it, though.
//! So after a deadline at `commit`, `start` or `reset_proof` the example
//! lifts the deadline and does that uncommit itself
//! (`uncommitAfterDeadline`), so the chip is not left committed to an
//! image whose start was never proven. That takes a few milliseconds and
//! one page erase when the bootloader behaves. At the host's bounds it
//! takes up to about 5 minutes: 50 Get IDs of up to about 4.6 s each, and
//! one uncommit of up to about 60 s. So from the start of `run` to the
//! frame loop the worst case is about 6 minutes; it is never unbounded.
//!
//! Reading the result: the user LED is off while the image starts (from
//! `seed.init` to the first look, about 50 ms).
//!
//! In `update` it then flickers at about 5 Hz while the update waits on the
//! chip. `UpdateIo.delayMs`, where the updater and the bootloader host make
//! every wait (frames, bootloader answers, BUSY), toggles it after each
//! 100 ms waited. It needs no timer and no interrupt. During bus transfers
//! with no wait between them the LED keeps its last state. The longest such
//! stretch in a healthy update is `goTrial`'s read-back of all of flash,
//! about 3 s; the other read-backs are a few tenths of a second.
//!
//! After that the LED is solid when no check failed and blinks at 2 Hz when
//! one did, and keeps doing so while the frames are read.
//!
//! Read `report` with a debugger (layout at `Report`). `Check` is `.pass`,
//! `.fail` or `.not_run`; the option bytes (`option_bytes`,
//! `option_bytes_safe`) are `.not_run` when the bootloader refuses to read
//! them, which is no failure, and `int_pullup` is `.not_run` when INT read
//! low while an application answered (see their fields).
//!
//! Build:
//! - `zig build panel_check -Doptimize=safe` (also part of `zig build
//!   -Doptimize=safe`): the `probe` image, `zig-out/firmware/panel_check.bin`.
//! - `zig build panel_check -Doptimize=safe -Dpanel-check=update
//!   [-Dscanner-fw=<n>]`: the same, and the `update` image,
//!   `zig-out/firmware/panel_check_update.bin`. It embeds the `scanner.bin`
//!   that this same build makes (in the build cache) with the same
//!   `-Dscanner-fw`. It does not embed a `zig-out/firmware/scanner.bin`
//!   left from an earlier `zig build scanner`, which this build neither
//!   reads nor writes.
//! `panel_check.{elf,bin}` is always the `probe` image: every build of this
//! example writes it, and no build writes an `update` image under that
//! name. A `panel_check_update.bin` from an earlier build stays in
//! `zig-out` until the next update build: build it again before flashing
//! it, so it carries the scanner image you mean. `report.mode` says which
//! image is running.
//!
//! **Bring-up, on the first v3 board, in this order, each rung only after
//! the one before. Never build `update` before `probe` has shown the
//! bootloader once.** `probe` is `panel_check.bin`, `update` is
//! `panel_check_update.bin`; check `report.mode` after every flash. Each
//! rung says what it leaves in the C031.
//! 1. `probe` (`panel_check.bin`) on a blank board: `presence ==
//!    .bootloader`, `product_id == 0x453`, `flash_head` all 0xFF;
//!    `int_pullup == .pass` (INT's 10 kOhm is there: without it INT floats
//!    on the Daisy's side whenever the application releases it, and the
//!    scanner's strap check rests on its own pull-up alone) and
//!    `int_low_at_start == false`; `option_bytes_safe == .pass`
//!    (read-out protection level 0, no hardware watchdog). Write down
//!    `option_bytes_raw`, and `optr_nrst_mode` and `optr_nboot_sel`:
//!    expected 3 (NRST bidirectional; 1, input only, works too; 2 makes
//!    PF2 a GPIO and the NRST line dead) and 1 (the boot chosen by the
//!    nBOOT0 option bit, not the BOOT0 pin), both the factory values
//!    reported for STM32 parts like it but not verified for the C031:
//!    stop and look before rung 2 if either differs. All of these rest on
//!    the first word at 0x1FFF_7800 being FLASH_OPTR, as on the G0; a
//!    `.fail` of `option_bytes_safe` means read FLASH_OPTR (0x4002_2020)
//!    over SWD before going on.
//!
//!    Leaves: the chip as it was (nothing written).
//!
//!    Before rung 2: a TC2030 cable and a debug probe on the bench: rung 2
//!    is the only step at which the first board can be left needing them,
//!    and no earlier rung can remove that. (It is the first time an image
//!    is committed and then started from a real reset. Rung 6, the update
//!    of a committed chip, has the same windows again for its new image.)
//! 2. `update` (`panel_check_update.bin`) on a blank board: `outcome ==
//!    .updated`, `step == .done`. Write down `step`, `update_error` and
//!    `update_ms` either way.
//!
//!    Leaves: the chip committed to the embedded image, running it.
//!
//!    If it stops earlier, the chip is uncommitted (power-cycle, and
//!    `probe` shows the bootloader again), except in these cases:
//!    - left committed and running the tried image:
//!      - `StartNotCleared` or `ResetNotSeen`: the image passed its trial,
//!        but the start or the reset proof failed;
//!      - `ResetIntoBootloader` (below);
//!      - the updater's start limits: `start`'s own error while the image
//!        did start (its acknowledge was lost), or `StartSilent` (or
//!        `start`'s error with frames that fail the check) when the strap
//!        did not reach the ROM and the image then ran;
//!      - a deadline (`deadline == .fail`) with `deadline_uncommit ==
//!        .fail`: the last 8-byte write of `commit` went through, or the
//!        started image ignored the strap.
//!
//!      `probe` then shows the application with `app_trial` clear. A
//!      later `update` with the same `-Dscanner-fw` reports `up_to_date`
//!      without the missing proof; raise the number to run the whole
//!      update again.
//!    - left committed, in its bootloader (the review's state E): an error
//!      from `commit`, or a Go refused at `start`, followed by the
//!      updater's clean-up `uncommit`, which failed too (its error is
//!      dropped: `update_error` names `commit`'s or `start`'s). `probe`
//!      then shows the bootloader with `flash_head` programmed, not all
//!      0xFF. A power cycle starts the image (it passed its trial); after
//!      a `VerifyFailed` at `commit`'s last read-back those first 8 bytes
//!      may be wrong, and then nothing answers after the power cycle: the
//!      pads. `update` again stages anew, page 0 first.
//!
//!    What four outcomes mean on the first board:
//!    - `ResetIntoBootloader` (`step == .reset_proof`): the reset proof's
//!      NRST pulse started the ROM, not the image: the empty flag the
//!      image cleared at its start did not survive the pulse (or the ROM
//!      cleared nothing and the flag stayed set). The image passed its
//!      trial and its start, so the updater started it again with Go and
//!      left it committed. Power-cycle once: it then starts from a real
//!      reset. Record it: it is the board's answer about the flag, and
//!      every update will end here until the updater changes.
//!    - `DeadAfterReset` after a clean `start`: after the pulse no frames
//!      came and the one Get ID found no bootloader either, so the image
//!      does not get going from a real reset (or the ROM was slow or its
//!      one Get ID was lost). The strap entry and the clean-up follow: if
//!      `probe` shows the bootloader after a power cycle, the chip is
//!      uncommitted; if nothing answers, the image dies before its strap
//!      check at every reset: the pads.
//!    - `TrialNoReturn` after good trial frames: the trial image ran its
//!      uncommit but the reset after it did not start the ROM: likely the
//!      ROM does not honour an empty flag set by software (or the image's
//!      command path is broken). The chip is uncommitted; power-cycle and
//!      `probe` shows the bootloader. Record it.
//!    - `TrialSilent`: look at `int_pullup` and INT first. A trial image
//!      that reads INT low ten times at its start (INT held or shorted
//!      low) erases its own first page and never answers.
//! 3. Frames, with `panel_check_update.bin` running: press every key and
//!    turn every encoder both ways while watching `report`. Each key sets
//!    bit `row * 7 + col` of `keys` (the spec's table), each detent moves
//!    its counter in `enc` by one, and `int_low` goes false once the client
//!    has acknowledged.
//!
//!    Leaves: flash as it was; only the scanner's RAM changes (the
//!    acknowledged `seq`, `booted` cleared).
//! 4. Power-cycle, `probe`: the application answers, `app_trial` clear
//!    (the committed image starts from a cold start). `frame_booted` and
//!    `int_low` stay true, as `probe` acknowledges nothing.
//!
//!    Leaves: the chip as it was (nothing written).
//! 5. Strap, with `panel_check_update.bin` (the flag exists only there):
//!    with the application running, set `strap_request` with the debugger.
//!    Expect `strap_presence == .bootloader`, and `probe` afterwards shows
//!    the bootloader. It tries the image's own uncommit and a software-set
//!    empty flag with the least machinery, before rung 6 relies on them;
//!    if it fails, the image is still committed and running.
//!
//!    Leaves: the chip uncommitted, in its bootloader (the application
//!    erased its own first page). Then `update` to restore, which leaves
//!    it as rung 2.
//! 6. `update` again with `-Dscanner-fw` raised by one: the first update of
//!    a committed chip. `outcome == .updated`.
//!
//!    Leaves: as rung 2, committed to the new image.
//!
//!    If it stops at `enter` with `NoBootloader`, the chip is unchanged
//!    (still committed to the old image) or uncommitted. Power-cycle and
//!    run it again: the ROM did not honour the empty flag the application
//!    set, and every later update needs a power cycle in the middle.
//!    Record it.
//!
//! **Do not leave `panel_check_update` running on a board that fails after
//! `stage`:** every Daisy boot runs the update again, and with it its
//! erases of page 0: two for a blank chip (the host's at `stage`, the
//! trial image's own), three for a committed one (the application's at
//! `enter` first), and one more for each clean-up `uncommit`. Flash
//! `panel_check.bin` (`probe`) instead while you look. The C031's flash
//! endurance was not looked up.
//!
//! **In `update`, a working committed application can be taken to its
//! bootloader:** when none of `find`'s three frame reads and three Get IDs
//! is answered (a bus fault at the Daisy's start is enough), the updater
//! makes the strap entry, and the application's own strap check erases its
//! first page. By design, and in the safe direction: the chip stays
//! flashable, and the update then runs; with the bus still broken it ends
//! `NoBootloader` on a chip that was fine. Mend the bus and run it again.
//!
//! What none of this covers (for the bring-up notes): a power cut or a
//! brown-out during the tens of milliseconds of a page-0 erase can leave a
//! first word that is neither erased nor valid, and one during `commit`'s
//! last 8-byte write a chip committed to first 8 bytes that are not whole;
//! an image whose command path and strap path both fail after it passed
//! its trial; a dead NRST line, with which a failed trial cannot be
//! cleaned up. For those the TC2030 pads remain. Three things about the
//! ROM and the empty flag are not known for the C031, and the first board
//! answers them: whether the ROM honours a flag set by software (rung 2
//! can already meet a `TrialNoReturn`; if not, the chip needs a power
//! cycle after the bootloader command, and is then in its bootloader);
//! whether a flag cleared by software holds across NRST (rung 2's reset
//! proof is the first test: `ResetIntoBootloader` if not); and whether the
//! ROM clears the flag itself (if it does, an NRST pulse to an uncommitted
//! chip sitting in its ROM leaves it dark until a power cycle: power-cycle
//! and run again).
const std = @import("std");
const microzig = @import("microzig");
const zmetal = @import("zmetal");
const build_config = @import("build_config");
const hal = zmetal.hal;
const i2c_bus = zmetal.drivers.i2c_bus;
const I2cBus = i2c_bus.I2cBus;
const stm32_i2c_boot = zmetal.drivers.stm32_i2c_boot;
const panel_update = zmetal.hid.panel_update;
const panel_client = zmetal.hid.panel_client;
const proto = zmetal.hid.panel_proto;

comptime {
    _ = microzig.export_startup();
}
pub const panic = microzig.panic;
pub const std_options = microzig.std_options(.{});

// SysTick, fault and USART1 handlers come from hal.default_interrupts.
pub const microzig_options: microzig.Options = .{};

pub const Check = enum(u8) { not_run, pass, fail };
pub const Mode = enum(u8) { probe, update };
/// What answered: `Updater.probe`'s result.
pub const Presence = enum(u8) { not_run, application, bootloader, nothing };
/// What `run` returned; `.failed` with the error in `update_error`.
pub const Outcome = enum(u8) { not_run, up_to_date, updated, failed };

/// The image's mode, set by `build.zig` for each of the two images
/// (`panel_check` is `probe`; `panel_check_update`, built with
/// `-Dpanel-check=update`, is `update`). Comptime: in `probe` nothing
/// behind `if (comptime build_mode == .update)` is analysed.
const build_mode: Mode = @field(Mode, @tagName(build_config.panel_check));

/// The firmware number of the scanner image (`-Dscanner-fw`, the option
/// the scanner step reads too): `run` gets this number with the image
/// built with it.
const scanner_fw: u8 = build_config.scanner_fw;

/// The scanner image, `update` only. Checked at compile time with the
/// bootloader host's own `checkImage`, so a wrong or empty `scanner.bin`
/// does not build; referring to it in `probe` does not compile.
const scanner_image: []const u8 = if (build_mode == .update)
    checkedImage(@embedFile("scanner.bin"))
else
    @compileError("the probe image embeds no scanner image");

fn checkedImage(comptime image: []const u8) []const u8 {
    @setEvalBranchQuota(10_000); // checkImage looks at up to 2040 bytes of page 0
    stm32_i2c_boot.checkImage(image, stm32_i2c_boot.c031) catch |err| @compileError(
        "scanner.bin is not an image an STM32C031 can run (" ++ @errorName(err) ++
            "): see stm32_i2c_boot.checkImage; it is the image of this build's scanner step (addScanner in build.zig)",
    );
    return image;
}

/// Every error `report` can name: the bus's, the deadline's, the
/// bootloader host's, the updater's and the probe's allow-list's.
const KnownError = i2c_bus.Error || error{DeadlinePassed} || stm32_i2c_boot.Error || panel_update.Error || error{RefusedInProbe};

/// An error as `report` keeps it: one name per error of `KnownError`, the
/// same numbers in both images (`@intFromError` values are not).
pub const ErrorCode = enum(u8) {
    none,
    // The bus (`i2c_bus.Error`) and the deadline (`UpdateIo`).
    Nack,
    Timeout,
    BusError,
    I2CError,
    DeadlinePassed,
    // The bootloader host (`stm32_i2c_boot.Error`; its NACK answer,
    // 0x1F, is `Refused`, at the end: a `Nack` above is the bus's, a
    // device that did not acknowledge its address).
    UnexpectedByte,
    Busy,
    WrongProduct,
    VerifyFailed,
    OutsideFlash,
    NotAnImage,
    NotBlank,
    NotTheStagedImage,
    // The updater (`panel_update.Error`).
    NoBootloader,
    TrialSilent,
    TrialWrongFirmware,
    TrialNotTrial,
    TrialNoReturn,
    StartSilent,
    StartNotCleared,
    ResetNotSeen,
    DeadAfterReset,
    // The probe's allow-list (`ProbeIo.write`).
    RefusedInProbe,
    // Added after the first numbering, at the end so no number moves.
    // The bootloader host: the bootloader answered NACK (0x1F).
    Refused,
    // The updater: the reset proof found the bootloader, not the image.
    ResetIntoBootloader,
};

comptime {
    // `errorCode` fails to compile for a name of `KnownError` that is
    // missing here; this catches a name here that `KnownError` lacks.
    if (@typeInfo(ErrorCode).@"enum".field_names.len != 1 + @typeInfo(KnownError).error_set.error_names.?.len)
        @compileError("ErrorCode must name exactly the errors of KnownError");
}

fn errorCode(err: KnownError) ErrorCode {
    return switch (err) {
        inline else => |e| @field(ErrorCode, @errorName(e)),
    };
}

/// What the example found and did (an `extern struct`: offsets stay put;
/// 88 bytes, 8-byte aligned, the same layout in both images). Offsets:
/// `keys` 0 (u64); the `u32`s `frames_accepted` 8, `bad_frames` 12,
/// `bus_errors` 16, `restarts` 20, `update_ms` 24, `refused_writes` 28;
/// `product_id` 32 (u16); `flash_head` 34..41, `option_bytes_raw` 42..49,
/// `enc` 50..53; then one byte each: `mode` 54, `want_fw` 55, `i2c_init`
/// 56, `presence` 57, `found` 58, `app_fw` 59, `app_trial` 60,
/// `int_low_at_start` 61, `bootloader_id` 62, `flash_read` 63,
/// `probe_error` 64, `option_bytes` 65, `option_bytes_error` 66, `update`
/// 67, `outcome` 68, `step` 69, `update_error` 70, `deadline` 71,
/// `deadline_uncommit` 72, `deadline_uncommit_error` 73, `strap_test` 74,
/// `strap_presence` 75, `frame_seen` 76, `frame_fw` 77, `frame_trial` 78,
/// `frame_booted` 79, `frame_seq` 80, `int_low` 81, `int_pullup` 82,
/// `option_bytes_safe` 83, `optr_nrst_mode` 84, `optr_nboot_sel` 85,
/// `reserved` 86..87 (always 0). A new byte field takes the place of a
/// `reserved` byte.
///
/// Fields an image cannot fill read 0: in `probe` the `update`,
/// `deadline*` and `strap*` fields and `restarts`; in `update`
/// `frame_booted`, `frame_seq` and `refused_writes`.
pub const Report = extern struct {
    /// The key map of the last frame (`probe`) or as the client delivered
    /// it (`update`): bit `row * 7 + col` set while that key is pressed
    /// (debounced by the scanner).
    keys: u64 = 0,
    /// Frames read and accepted (right protocol byte and CRC).
    frames_accepted: u32 = 0,
    /// Frames read and refused (protocol or CRC).
    bad_frames: u32 = 0,
    /// Frame reads that failed on the bus; in `update` the client's count,
    /// which also counts its failed acknowledges.
    bus_errors: u32 = 0,
    /// Restarts of the scanner the client saw (`update` only).
    restarts: u32 = 0,
    /// How long `run` took, in ms (`update`).
    update_ms: u32 = 0,
    /// Writes the probe's allow-list refused, sending nothing (`probe`
    /// only). Not 0 means some code tried to send more than the read-only
    /// frames: the LED blinks.
    refused_writes: u32 = 0,
    /// Get ID's answer, when a bootloader answered at start.
    product_id: u16 = 0,
    /// The first 8 bytes of main flash, read through the bootloader.
    flash_head: [8]u8 = @splat(0),
    /// 8 bytes read at `option_bytes_address`, if the bootloader allowed it.
    option_bytes_raw: [8]u8 = @splat(0),
    /// The four detent counters (ENC1-4), from the same source as `keys`.
    enc: [proto.encoder_count]u8 = @splat(0),
    /// Which image runs.
    mode: Mode = build_mode,
    /// The firmware number of the scanner image of this build: an
    /// application reporting another one (or `trial`) is what `update`
    /// replaces.
    want_fw: u8 = scanner_fw,
    /// `I2C_Device.init` of I2C1 worked.
    i2c_init: Check = .not_run,
    /// What answered at start (`Updater.probe`), `release_wait_ms` after
    /// `seed.init`. This example never asserts NRST at start: the C031 runs
    /// whatever it was running, or what it started at power-on.
    presence: Presence = .not_run,
    /// An application or a bootloader answered at start. In `update` a
    /// `.fail` here stays (and the LED blinks) even when `run` then got
    /// to the bootloader through the strap entry: nothing answering is a
    /// fault worth seeing.
    found: Check = .not_run,
    /// The application's `fw` and `trial` flag at start.
    app_fw: u8 = 0,
    app_trial: bool = false,
    /// INT (D27) read low at start: `seed.init`, `release_wait_ms`, then
    /// `int_pullup`'s millisecond and one more, before any bus transfer.
    /// NRST is never asserted here, so the C031 was not reset by this
    /// example. An application holds INT low from its start until its first
    /// acknowledge; one that was acknowledged before a Daisy-only reset has
    /// released it and reads high, as a bootloader or nothing does (the
    /// pull-up holds it high).
    int_low_at_start: bool = false,
    /// A bootloader at start: Get ID answered with the C031's 0x453.
    bootloader_id: Check = .not_run,
    /// A bootloader at start: the first 8 bytes of flash were read.
    flash_read: Check = .not_run,
    /// Why `bootloader_id` or `flash_read` failed.
    probe_error: ErrorCode = .none,
    /// `.pass` when the option bytes were read, `.not_run` when the
    /// bootloader refused (with the error in `option_bytes_error`): a
    /// refusal is no failure.
    option_bytes: Check = .not_run,
    option_bytes_error: ErrorCode = .none,
    /// `run` returned `.updated` or `.up_to_date`.
    update: Check = .not_run,
    outcome: Outcome = .not_run,
    /// `run`'s step at the end: the step that failed, or `.done`.
    step: panel_update.Step = .none,
    update_error: ErrorCode = .none,
    /// `.fail` when `run` reached `run_deadline_ms` and bus calls were refused.
    deadline: Check = .not_run,
    /// After a deadline at `commit`, `start` or `reset_proof`: `.pass`
    /// when the bootloader answered and `uncommit` worked; `.fail` with
    /// the reason (`NoBootloader` when none answered). `NoBootloader` here
    /// is not always a failed clean-up: when nothing needed uncommitting
    /// (the deadline came inside `start`'s proof, which then ended in
    /// `StartNotCleared`, or the updater's `StartSilent` limit left the
    /// tried image committed and running), no bootloader answers either.
    /// Read it with `update_error` and `presence` from a later `probe`.
    deadline_uncommit: Check = .not_run,
    deadline_uncommit_error: ErrorCode = .none,
    /// The strap test (`update`, on request): `.pass` when the bootloader
    /// answered after the strap entry.
    strap_test: Check = .not_run,
    strap_presence: Presence = .not_run,
    /// A frame was accepted; then the last one's `fw` and `trial` flag.
    frame_seen: bool = false,
    frame_fw: u8 = 0,
    frame_trial: bool = false,
    /// The last accepted frame's `booted` flag and `seq` (`probe` only). As
    /// `probe` never acknowledges, `booted` stays set there.
    frame_booted: bool = false,
    frame_seq: u8 = 0,
    /// INT (D27) read low at the last frame poll: in `probe` it stays low
    /// while an application runs, as nothing acknowledges.
    int_low: bool = false,
    /// The board's 10 kOhm pull-up on INT, measured at start, in both
    /// images, before the bus or anything else drives or reads D27 for the
    /// C031 (`intPulledUp`): D27 an input with the Daisy's own pull-down
    /// (about 40 kOhm) for 1 ms, read, then a plain input again. A read,
    /// not a write: no bus, no allow-list.
    /// - `.pass`: the line read high against the pull-down: the pull-up is
    ///   there.
    /// - `.fail`: it read low with nothing that should hold it low: the
    ///   pull-up is missing or open, or the line is held low. Meaningful
    ///   when the C031 does not drive INT: a chip in its ROM (a blank
    ///   board, rung 1), or nothing answering (but a hung application can
    ///   hold INT low too: look at `found`).
    /// - `.not_run`: it read low while an application answered, which
    ///   holds INT low from its start until its first acknowledge: a good
    ///   reason, so the reading says nothing. An application that was
    ///   acknowledged before a Daisy-only reset has released INT, and then
    ///   reads `.pass` as a ROM does.
    int_pullup: Check = .not_run,
    /// The two option-byte bits whose expected value is certain, decoded
    /// from `option_bytes_raw` as FLASH_OPTR, little-endian (the first
    /// word at `option_bytes_address`: the G0's layout, not verified for
    /// the C0): `.pass` when the read-out protection byte (bits 7:0) is
    /// 0xAA, level 0, and IWDG_SW (bit 16) is 1, no hardware watchdog
    /// (the scanner never feeds one); `.fail` otherwise; `.not_run` while
    /// `option_bytes` is. A `.fail` means stop before rung 2 and read
    /// FLASH_OPTR (0x4002_2020) over SWD.
    option_bytes_safe: Check = .not_run,
    /// NRST_MODE (FLASH_OPTR bits 28:27) and nBOOT_SEL (bit 24) from the
    /// same word, recorded as read, with no verdict: write them down at
    /// rung 1 (expected values in the bring-up list).
    optr_nrst_mode: u8 = 0,
    optr_nboot_sel: u8 = 0,
    reserved: [2]u8 = @splat(0),
};

comptime {
    std.debug.assert(@sizeOf(Report) == 88);
    std.debug.assert(@offsetOf(Report, "refused_writes") == 28);
    std.debug.assert(@offsetOf(Report, "mode") == 54);
    std.debug.assert(@offsetOf(Report, "step") == 69);
    std.debug.assert(@offsetOf(Report, "int_low") == 81);
    std.debug.assert(@offsetOf(Report, "int_pullup") == 82);
    std.debug.assert(@offsetOf(Report, "option_bytes_safe") == 83);
    std.debug.assert(@offsetOf(Report, "optr_nrst_mode") == 84);
    std.debug.assert(@offsetOf(Report, "optr_nboot_sel") == 85);
    std.debug.assert(@offsetOf(Report, "reserved") == 86);
}

pub var report: Report = .{}; // read it with a debugger

// Exported, so the optimizer keeps `report` whole, under its own name.
comptime {
    @export(&report, .{ .name = "report" });
}

/// Set it to a value other than 0 with a debugger (`update` only) to make
/// one strap entry from the frame loop (bring-up rung 5). Not in the
/// `probe` image at all.
var strap_request: u8 = 0;

comptime {
    if (build_mode == .update) @export(&strap_request, .{ .name = "strap_request" });
}

/// The option bytes of the C031, as a secondary source gives them (RM0490
/// Table 18 read through a third-party mirror, through [BOOT]; not checked
/// against ST's PDF until rung 1 reads them): read only, which cannot
/// change the chip.
const option_bytes_address: u32 = 0x1FFF_7800;

/// How long NRST is held low by `resetPulse`.
const reset_pulse_ms: u32 = 10;

/// The wait after `seed.init` before the first look: time for a C031 that
/// powered up with the Daisy to start. NRST is never pulsed at start.
const release_wait_ms: u32 = 50;

/// The overall deadline for one `run`. A healthy update at 100 kHz takes
/// about 6 to 9 s: `stage` about 1.1 s, `goTrial` about 3.3 s (all 32 KB
/// read back), `commit` about 1.1 s, and the frame and bootloader waits
/// (up to 1 s each at `enter` and `trial_return`) the rest, all estimated
/// (rung 2 measures `update_ms`). 60 s is 7 to 10 times that, so only a
/// bootloader that answers BUSY over and over (the host's bounds allow
/// about 40 minutes at 1 ms a poll, up to twice that on this `Io`) or a
/// bus far slower than it should be reaches it.
const run_deadline_ms: u32 = 60_000;

/// How long the strap test waits for an answer after the strap entry.
const strap_answer_ms: u32 = 1000;

/// The frame loop's pause between polls: well under the scanner's 5 ms
/// debounce, so no key change is missed between two polls.
const poll_period_ms: u32 = 2;

/// The LED's half period when a check failed: 2 Hz.
const blink_half_period_ms: u32 = 250;

/// `update`: waiting this long in `UpdateIo.delayMs` toggles the LED, a
/// 5 Hz flicker while the update waits on the chip.
const progress_toggle_ms: u32 = 100;

/// I2C1: the scanner, its bootloader and the charger. At file scope: the
/// target and the bus views keep pointers to it.
var bus: hal.i2c.I2C_Device = undefined;
/// The same bus at 400 kHz, for the `update` image's client only; naming
/// it in `probe` does not compile.
var panel_speed: if (build_mode == .update) hal.i2c.Target else @compileError("panel_speed is the update image's client bus") = undefined;

var seed: zmetal.Seed = .{};

// ============================================================================
// The two lines to the C031. The only places D26 and D27 are configured;
// each has `open_drain = true` written into it.

/// D26's handle: kept in `update` for `UpdateIo.resetPulse`; `void` in
/// `probe`, which keeps nothing it could drive NRST low with.
const Nrst = if (build_mode == .update) hal.Gpio else void;

/// D26 (PD11), the C031's NRST: an open-drain output with its latch high,
/// so it is released (the C031's own pull-up holds NRST high) and can only
/// ever be driven low (`UpdateIo.resetPulse`). Called once, first thing.
fn nrstReleased() Nrst {
    const pin = hal.Gpio.init(zmetal.pins.D26, .{ .mode = .output, .open_drain = true, .initial = .high });
    return if (build_mode == .update) pin else {};
}

/// D27 (PG9), the scanner's INT: an input. Open-drain is kept set in the
/// output type, so a later switch to output can never drive it high.
fn intReleased() void {
    _ = hal.Gpio.init(zmetal.pins.D27, .{ .mode = .input, .open_drain = true });
}

/// D27 driven low: an open-drain output whose latch is written low
/// before the mode. `update` only (`UpdateIo.strap`): a strap entry makes
/// a committed application erase its first flash page.
fn intHeldLow() void {
    if (build_mode != .update) @compileError("intHeldLow drives INT: update image only");
    _ = hal.Gpio.init(zmetal.pins.D27, .{ .mode = .output, .open_drain = true, .initial = .low });
}

fn intIsLow() bool {
    return !hal.Gpio.handle(zmetal.pins.D27).read();
}

/// How long D27 has its pull-down on before `intPulledUp` reads it: far
/// longer than the line needs (about 40 kOhm on tens of pF, a few us).
const pullup_settle_ms: u32 = 1;

/// The measurement behind `int_pullup`: D27 an input with the Daisy's own
/// pull-down, read after `pullup_settle_ms`, then a plain input again
/// (`intReleased`). True when the line reads high, so something pulls it
/// up harder than the pull-down: the board's 10 kOhm. A read: nothing is
/// driven, the bus is not touched.
fn intPulledUp() bool {
    _ = hal.Gpio.init(zmetal.pins.D27, .{ .mode = .input, .pull = .down, .open_drain = true });
    zmetal.time.delayMs(pullup_settle_ms);
    const high = hal.Gpio.handle(zmetal.pins.D27).read();
    intReleased();
    return high;
}

/// `int_pullup`, once `presence` is known: a low reading is `.not_run`
/// when an application answered (it holds INT low until acknowledged),
/// `.fail` otherwise.
fn judgeIntPullup(high: bool) void {
    report.int_pullup = if (high) .pass else if (report.presence == .application) .not_run else .fail;
}

// ============================================================================
// The `Io` of the updater and of the bootloader host, and the `Boot`.

// What `probe` may send: each frame below, byte for byte, to the
// bootloader at 0x63, and nothing else to anyone. Together they make Get ID
// and a Read Memory of 8 bytes at the two addresses `readBootloader` reads.

/// Get ID's command and its complement (AN4221 2.3).
const get_id_frame = [_]u8{ 0x02, 0xFD };
/// Read Memory's command and its complement (AN4221 2.4).
const read_memory_frame = [_]u8{ 0x11, 0xEE };
/// Read Memory's address 0x0800_0000 (the flash base), MSB first, and the
/// XOR of the four bytes.
const flash_base_address_frame = [_]u8{ 0x08, 0x00, 0x00, 0x00, 0x08 };
/// Read Memory's address 0x1FFF_7800 (the option bytes) and its XOR.
const option_bytes_address_frame = [_]u8{ 0x1F, 0xFF, 0x78, 0x00, 0x98 };
/// Read Memory's byte count: N - 1 = 7, for 8 bytes, and its complement.
const read_8_bytes_frame = [_]u8{ 0x07, 0xF8 };

const probe_frames = [_][]const u8{
    &get_id_frame,
    &read_memory_frame,
    &flash_base_address_frame,
    &option_bytes_address_frame,
    &read_8_bytes_frame,
};

/// Whether `probe` may send `bytes` to `address`: only to the bootloader,
/// and only a frame equal to one of `probe_frames`. Never to the
/// application at 0x42. A shape is not enough: a 2-page erase list
/// (`hi lo hi lo xor`) has the shape of an address frame.
fn probeMaySend(address: u7, bytes: []const u8) bool {
    if (address != stm32_i2c_boot.c031.address) return false;
    for (probe_frames) |frame| {
        if (std.mem.eql(u8, bytes, frame)) return true;
    }
    return false;
}

comptime {
    @setEvalBranchQuota(100_000);
    const eql = std.mem.eql;
    const assert = std.debug.assert;
    const boot_address = stm32_i2c_boot.c031.address;
    // The address frames are the ones the host builds, so they cannot drift
    // from what `readMemory` sends.
    assert(eql(u8, &stm32_i2c_boot.addressFrame(stm32_i2c_boot.flash_base), &flash_base_address_frame));
    assert(eql(u8, &stm32_i2c_boot.addressFrame(option_bytes_address), &option_bytes_address_frame));
    // The list, checked with the function `ProbeIo.write` runs.
    for (probe_frames) |frame| assert(probeMaySend(boot_address, frame));
    // Every other `{op, ~op}`, Go (0x21), Write (0x31, 0x32), Erase (0x43,
    // 0x44, 0x45) and the protection commands among them, is refused.
    for (0..256) |i| {
        const op: u8 = i;
        if (op == 0x02 or op == 0x11 or op == 0x07) continue;
        assert(!probeMaySend(boot_address, &.{ op, ~op }));
    }
    // Nothing to the application, not even its read-only frames' twins.
    assert(!probeMaySend(proto.address, &.{0x01}));
    assert(!probeMaySend(proto.address, &.{ 0x02, 0x00 }));
    assert(!probeMaySend(proto.address, &.{ 0xB0, 0x07, 0x5A }));
    assert(!probeMaySend(proto.address, &get_id_frame));
    // An erase list of pages 0 and 1, an empty write, a longer frame.
    assert(!probeMaySend(boot_address, &.{ 0x00, 0x00, 0x00, 0x01, 0x01 }));
    assert(!probeMaySend(boot_address, &.{}));
    assert(!probeMaySend(boot_address, &(get_id_frame ++ [_]u8{0x00})));
}

/// `probe`'s `Io`: the bus at 100 kHz behind the allow-list, and pauses.
/// It has no `resetPulse` and no `strap`, so `Updater.run` does not
/// compile over it.
const ProbeIo = struct {
    bus: I2cBus,

    pub const Error = i2c_bus.Error || error{RefusedInProbe};

    pub fn read(self: *ProbeIo, address: u7, rx: []u8) Error!void {
        return self.bus.read(address, rx);
    }

    /// The barrier: a write not allowed by `probeMaySend` is refused before
    /// the bus is touched, `error.RefusedInProbe`, and counted in
    /// `report.refused_writes`.
    pub fn write(self: *ProbeIo, address: u7, bytes: []const u8) Error!void {
        if (!probeMaySend(address, bytes)) {
            report.refused_writes +|= 1;
            return error.RefusedInProbe;
        }
        return self.bus.write(address, bytes);
    }

    pub fn delayMs(_: *ProbeIo, ms: u32) void {
        zmetal.time.delayMs(ms);
    }
};

/// `update`'s `Io`: the bus at 100 kHz behind the deadline, pauses, and
/// the NRST pulse and INT strap. The deadline stops bus calls only.
/// Naming it in `probe` does not compile: a bootloader host on it would
/// reach the bus with no allow-list.
const UpdateIo = if (build_mode == .update) struct {
    bus: I2cBus,
    /// D26, from `nrstReleased`.
    nrst: hal.Gpio,
    armed: bool = false,
    /// `nowMs()` when `arm` was called.
    armed_at: u32 = 0,
    /// A bus call was refused because the deadline had passed.
    hit: bool = false,
    /// Milliseconds waited in `delayMs` since the LED was last toggled.
    waited_ms: u32 = 0,

    pub const Error = i2c_bus.Error || error{DeadlinePassed};

    /// From now, bus calls fail once `run_deadline_ms` has passed.
    fn arm(self: *UpdateIo) void {
        self.armed_at = zmetal.time.nowMs();
        self.armed = true;
        self.hit = false;
    }

    fn disarm(self: *UpdateIo) void {
        self.armed = false;
    }

    fn expired(self: *UpdateIo) bool {
        if (!self.armed or zmetal.time.nowMs() -% self.armed_at < run_deadline_ms) return false;
        self.hit = true;
        return true;
    }

    pub fn read(self: *UpdateIo, address: u7, rx: []u8) Error!void {
        if (self.expired()) return error.DeadlinePassed;
        return self.bus.read(address, rx);
    }

    pub fn write(self: *UpdateIo, address: u7, bytes: []const u8) Error!void {
        if (self.expired()) return error.DeadlinePassed;
        return self.bus.write(address, bytes);
    }

    /// A pause, and the LED's progress flicker: every `progress_toggle_ms`
    /// of waiting (counted as asked, not as measured) toggles the LED, a
    /// plain GPIO write. The updater and the bootloader host wait here for
    /// every frame, every bootloader answer and every BUSY, so the LED
    /// flickers while an update waits on the chip; during a bus transfer
    /// with no wait it keeps its last state.
    pub fn delayMs(self: *UpdateIo, ms: u32) void {
        zmetal.time.delayMs(ms);
        self.waited_ms += ms;
        while (self.waited_ms >= progress_toggle_ms) {
            self.waited_ms -= progress_toggle_ms;
            seed.toggleLed();
        }
    }

    /// NRST low for `reset_pulse_ms`, then released. D26 is open-drain
    /// (`nrstReleased`): `write(false)` drives it low, `write(true)`
    /// releases it; nothing drives it high. `update` only.
    pub fn resetPulse(self: *UpdateIo) void {
        if (build_mode != .update) @compileError("resetPulse pulses NRST: update image only");
        self.nrst.write(false);
        zmetal.time.delayMs(reset_pulse_ms);
        self.nrst.write(true);
    }

    /// INT driven low (open-drain), or back to an input. `update` only.
    pub fn strap(_: *UpdateIo, held: bool) void {
        if (build_mode != .update) @compileError("strap drives INT: update image only");
        if (held) intHeldLow() else intReleased();
    }
} else @compileError("UpdateIo writes to the C031 with no allow-list: update image only");

const Io = if (build_mode == .update) UpdateIo else ProbeIo;

/// The bootloader host with its writing methods: `update` only. In `probe`
/// naming it does not compile; `ProbeBoot` is the probe's way in.
const Host = if (build_mode == .update)
    stm32_i2c_boot.Bootloader(*UpdateIo)
else
    @compileError("the bootloader host can write: the probe image uses ProbeBoot");

/// `probe`'s `Boot`: the bootloader host's two methods that only read.
/// It keeps no host: each call makes one on `io` and drops it, so nothing
/// in `probe` holds a value with the host's writing methods. (A host made
/// on `io` anyway still meets the allow-list.)
const ProbeBoot = struct {
    io: *ProbeIo,

    pub const Failure = stm32_i2c_boot.Error || ProbeIo.Error;

    pub fn productId(self: ProbeBoot) Failure!u16 {
        return stm32_i2c_boot.Bootloader(*ProbeIo).init(self.io, stm32_i2c_boot.c031).productId();
    }

    pub fn readMemory(self: ProbeBoot, addr: u32, rx: []u8) Failure!void {
        return stm32_i2c_boot.Bootloader(*ProbeIo).init(self.io, stm32_i2c_boot.c031).readMemory(addr, rx);
    }
};

const Boot = if (build_mode == .update) Host else ProbeBoot;
const Updater = panel_update.Updater(Boot, *Io);
/// The client, which acknowledges frames and clears `booted`: `update`
/// only; naming it in `probe` does not compile.
const Client = if (build_mode == .update)
    panel_client.PanelClient(I2cBus)
else
    @compileError("PanelClient writes to the scanner: update image only");

var io: Io = undefined;
var updater: Updater = undefined;

// ============================================================================

pub fn main() !void {
    // First: NRST released, INT an input, before anything touches the bus
    // (`I2C_Device.init`'s bus recovery may clock SCL).
    const nrst = nrstReleased();
    intReleased();

    try seed.init(.{ .sdram = false, .qspi = false });

    zmetal.time.delayMs(release_wait_ms);
    // INT's pull-up first, before anything else reads or drives D27; its
    // verdict waits for `presence` (`judgeIntPullup`).
    const int_pulled_up = intPulledUp();
    zmetal.time.delayMs(pullup_settle_ms); // the pull-up has the line again
    report.int_low_at_start = intIsLow();

    bus = hal.i2c.I2C_Device.init(.I2C1, .{
        .speed = .I2C_100KHZ,
        .min_start_gap_us = 90,
        .min_bus_free_us = 68,
    }) catch {
        report.i2c_init = .fail;
        idle();
    };
    report.i2c_init = .pass;

    const slow: I2cBus = .{ .dev = bus.i2c_device() };
    if (comptime build_mode == .update) {
        panel_speed = bus.target(.I2C_400KHZ);
        io = .{ .bus = slow, .nrst = nrst };
        updater = Updater.init(Host.init(&io, stm32_i2c_boot.c031), &io);
    } else {
        io = .{ .bus = slow };
        updater = Updater.init(.{ .io = &io }, &io);
    }

    checkPresence();
    judgeIntPullup(int_pulled_up);
    if (comptime build_mode == .update) {
        runUpdate();
        mirrorFrames();
    } else {
        if (report.presence == .application) watchFrames();
        idle();
    }
}

fn verdict(ok: bool) Check {
    return if (ok) .pass else .fail;
}

fn anyFail() bool {
    if (report.refused_writes != 0) return true;
    inline for (@typeInfo(Report).@"struct".field_names) |name| {
        if (@FieldType(Report, name) == Check) {
            if (@field(report, name) == .fail) return true;
        }
    }
    return false;
}

/// The LED: solid while no check failed, 2 Hz once one did. Timed on
/// `nowMs`, so the frame loop keeps running.
fn showVerdict() void {
    const on = if (anyFail()) (zmetal.time.nowMs() / blink_half_period_ms) % 2 == 0 else true;
    seed.setLed(on);
}

fn idle() noreturn {
    while (true) {
        showVerdict();
        zmetal.time.delayMs(10);
    }
}

fn presenceOf(p: panel_update.Presence) Presence {
    return switch (p) {
        .application => .application,
        .bootloader => .bootloader,
        .nothing => .nothing,
    };
}

/// `presence`, `found`, `app_fw`, `app_trial`: `Updater.probe`, which only
/// reads. A bootloader is then read further (`readBootloader`).
fn checkPresence() void {
    const p = updater.probe();
    report.presence = presenceOf(p);
    report.found = verdict(report.presence != .nothing);
    switch (p) {
        .application => |app| {
            report.app_fw = app.fw;
            report.app_trial = app.trial;
        },
        .bootloader => readBootloader(),
        .nothing => {},
    }
}

/// `bootloader_id`: Get ID gives 0x453. `flash_read`: the first 8 bytes of
/// flash (`flash_head`), all 0xFF on a blank chip. `option_bytes`: 8 bytes
/// at 0x1FFF_7800; the bootloader may refuse, which is recorded, not
/// failed. Read Memory only: nothing here can change the chip.
fn readBootloader() void {
    const id = updater.boot.productId() catch |err| {
        report.bootloader_id = .fail;
        report.probe_error = errorCode(err);
        return;
    };
    report.product_id = id;
    report.bootloader_id = verdict(id == stm32_i2c_boot.c031.product_id);

    if (updater.boot.readMemory(stm32_i2c_boot.flash_base, &report.flash_head)) {
        report.flash_read = .pass;
    } else |err| {
        report.flash_read = .fail;
        report.probe_error = errorCode(err);
    }

    if (updater.boot.readMemory(option_bytes_address, &report.option_bytes_raw)) {
        report.option_bytes = .pass;
        const bits = decodeOptr(report.option_bytes_raw);
        report.option_bytes_safe = verdict(bits.safe);
        report.optr_nrst_mode = bits.nrst_mode;
        report.optr_nboot_sel = bits.nboot_sel;
    } else |err| {
        report.option_bytes_error = errorCode(err); // refused: stays .not_run
    }
}

/// What `option_bytes_safe`, `optr_nrst_mode` and `optr_nboot_sel` take
/// from the option bytes.
const OptionBits = struct { safe: bool, nrst_mode: u8, nboot_sel: u8 };

/// FLASH_OPTR as the first little-endian word of `raw`, the 8 bytes read
/// at `option_bytes_address` (the G0's layout, not verified for the C0).
/// Bit positions from stm32c031xx.h through the facts file: RDP 7:0,
/// IWDG_SW 16, nBOOT_SEL 24, NRST_MODE 28:27. `safe` judges only the two
/// whose expected value is certain: RDP 0xAA (level 0) and IWDG_SW 1.
fn decodeOptr(raw: [8]u8) OptionBits {
    const optr = std.mem.readInt(u32, raw[0..4], .little);
    const rdp: u8 = @truncate(optr);
    const iwdg_sw = (optr >> 16) & 1;
    return .{
        .safe = rdp == 0xAA and iwdg_sw == 1,
        .nrst_mode = @truncate((optr >> 27) & 0b11),
        .nboot_sel = @truncate((optr >> 24) & 1),
    };
}

comptime {
    // Bytes written out by hand, low byte first. 0xFFFF_FEAA, the G0's
    // factory word: RDP 0xAA, IWDG_SW 1, nBOOT_SEL 1, NRST_MODE 3.
    const g0 = decodeOptr(.{ 0xAA, 0xFE, 0xFF, 0xFF, 0, 0, 0, 0 });
    std.debug.assert(g0.safe and g0.nrst_mode == 3 and g0.nboot_sel == 1);
    // RDP 0xBB, level 1.
    std.debug.assert(!decodeOptr(.{ 0xBB, 0xFE, 0xFF, 0xFF, 0, 0, 0, 0 }).safe);
    // IWDG_SW 0 (byte 2 bit 0), a hardware watchdog.
    std.debug.assert(!decodeOptr(.{ 0xAA, 0xFE, 0xFE, 0xFF, 0, 0, 0, 0 }).safe);
    // Byte 3 = 0xF6: NRST_MODE (bits 4:3) 10 = 2, nBOOT_SEL (bit 0) 0; no
    // verdict on either.
    const odd = decodeOptr(.{ 0xAA, 0xFE, 0xFF, 0xF6, 0, 0, 0, 0 });
    std.debug.assert(odd.safe and odd.nrst_mode == 2 and odd.nboot_sel == 0);
    // The other four bytes are not read.
    std.debug.assert(decodeOptr(.{ 0xAA, 0xFE, 0xFF, 0xFF, 0x55, 0x01, 0x00, 0x00 }).safe);
}

/// `update`: `run` with the embedded image and its firmware number, under
/// the deadline. Records `outcome`, `step`, `update_error`, `update_ms` and
/// `deadline`; after a deadline that may have cut the updater's own
/// uncommit, `uncommitAfterDeadline`. The LED flickers meanwhile, from the
/// waits (`UpdateIo.delayMs`).
fn runUpdate() void {
    io.arm();
    const start = zmetal.time.nowMs();
    const result = updater.run(scanner_image, scanner_fw);
    report.update_ms = zmetal.time.nowMs() -% start;
    io.disarm();

    report.step = updater.step();
    report.deadline = verdict(!io.hit);
    if (result) |outcome| {
        report.outcome = switch (outcome) {
            .up_to_date => .up_to_date,
            .updated => .updated,
        };
        report.update = .pass;
    } else |err| {
        report.outcome = .failed;
        report.update = .fail;
        report.update_error = errorCode(err);
    }

    if (io.hit) uncommitAfterDeadline();
}

/// After a deadline that stopped `run` at `commit`, `start` or
/// `reset_proof`: the updater's uncommit through the bootloader, which the
/// deadline refused, done here with the deadline lifted.
///
/// The updater would have made it whenever the bootloader answered: after
/// a failed commit, after a refused Go, or after a strap entry, which
/// `run` still made, as the strap needs no bus. Here: up to
/// `boot_attempts` Get IDs `boot_gap_ms` apart, as the updater waits; if
/// one answers, `uncommit` once. Before `commit` the chip is uncommitted
/// already (or untouched), so nothing is done. Nothing either after
/// `ResetIntoBootloader`: the updater left the tried image committed on
/// purpose (a deadline can only have cut its Go, which leaves the chip
/// committed in its ROM, and a power cycle starts the image).
///
/// Time: a few milliseconds and one page erase when the bootloader
/// behaves. At the host's bounds, with this `Io`'s polls of up to about
/// 2.3 ms (see the file comment):
/// - a Get ID that fails waits for up to two answers, 2 x 1 000 polls,
///   about 4.6 s;
/// - `uncommit` makes about 26 000 polls (its erase, the mass erase it
///   falls back to, and the read-back), about 60 s.
///
/// So the worst case, 49 failed Get IDs, then one that answers, then the
/// uncommit, is about 5 minutes; it is about 2.5 minutes by the host's own
/// 1 ms a poll.
fn uncommitAfterDeadline() void {
    switch (report.step) {
        .commit, .start, .reset_proof => {},
        else => return,
    }
    if (report.update_error == .ResetIntoBootloader) return;
    for (0..panel_update.boot_attempts) |i| {
        if (i != 0) zmetal.time.delayMs(panel_update.boot_gap_ms);
        _ = updater.boot.productId() catch continue;
        if (updater.boot.uncommit()) {
            report.deadline_uncommit = .pass;
        } else |err| {
            report.deadline_uncommit = .fail;
            report.deadline_uncommit_error = errorCode(err);
        }
        return;
    }
    report.deadline_uncommit = .fail;
    report.deadline_uncommit_error = .NoBootloader;
}

/// `probe`'s frame loop: every `poll_period_ms` one 16-byte read at 0x42
/// through `io`, decoded here with `panel_proto.decode`, the last accepted
/// frame copied into `report` (`keys`, `enc`, `frame_*`), and INT's level
/// into `int_low`. It writes nothing: no acknowledge and no `clear_booted`,
/// so the application keeps INT low and `booted` set.
fn watchFrames() noreturn {
    while (true) {
        var raw: [proto.frame_len]u8 = undefined;
        if (io.read(proto.address, &raw)) {
            if (proto.decode(&raw)) |f| {
                report.frames_accepted +%= 1;
                report.keys = f.keys;
                report.enc = f.enc;
                report.frame_seen = true;
                report.frame_fw = f.fw;
                report.frame_trial = f.trial;
                report.frame_booted = f.booted;
                report.frame_seq = f.seq;
            } else |_| report.bad_frames +%= 1;
        } else |_| report.bus_errors +%= 1;
        report.int_low = intIsLow();

        showVerdict();
        zmetal.time.delayMs(poll_period_ms);
    }
}

/// The client over the 400 kHz target, `update` only: it acknowledges
/// frames and clears `booted`, writes `probe` must not make. Made only
/// after `run` has finished (the updater needs the scanner to itself), and
/// again after a strap test, as the scanner then runs from a fresh start.
fn newClient() Client {
    if (build_mode != .update) @compileError("PanelClient writes to the scanner: update image only");
    return Client.init(.{ .dev = panel_speed.i2c_device() });
}

/// `update`'s frame loop: polls the client every `poll_period_ms` and
/// mirrors its state into `report`; makes the strap test on request.
fn mirrorFrames() noreturn {
    var client = newClient();
    // Enough for any one poll: every key and encoder changed, or every key
    // released and `restarted`.
    var events: [64]panel_client.Event = undefined;
    comptime std.debug.assert(events.len >= proto.key_count + proto.encoder_count + 1);

    while (true) {
        const refused_before = client.stats().bad_frames;
        if (client.poll(&events)) |_| {
            if (client.stats().bad_frames == refused_before) report.frames_accepted +%= 1;
        } else |_| {} // counted in the client's `bus_errors`
        mirror(&client);
        report.int_low = intIsLow();

        if (strapRequested()) {
            strapTest();
            client = newClient();
        }

        showVerdict();
        zmetal.time.delayMs(poll_period_ms);
    }
}

fn mirror(client: *const Client) void {
    report.keys = client.keys;
    report.enc = client.enc;
    const s = client.stats();
    report.bad_frames = s.bad_frames;
    report.bus_errors = s.bus_errors;
    report.restarts = s.restarts;
    if (client.firmware()) |fw| {
        report.frame_seen = true;
        report.frame_fw = fw;
        report.frame_trial = client.trial() orelse false;
    }
}

/// `strap_request` was set; it is cleared, so each request makes one
/// strap entry.
fn strapRequested() bool {
    const flag: *volatile u8 = &strap_request;
    if (flag.* == 0) return false;
    flag.* = 0;
    return true;
}

/// `strap_test`, `strap_presence`: one strap entry, then `Updater.probe`
/// until something answers or `strap_answer_ms` has passed (the
/// application samples INT for 10 ms, erases its first page and resets
/// before the ROM can answer). `.pass` when the bootloader answers.
fn strapTest() void {
    io.strap(true);
    io.resetPulse();
    zmetal.time.delayMs(panel_update.strap_hold_ms);
    io.strap(false);
    zmetal.time.delayMs(panel_update.strap_settle_ms);

    const start = zmetal.time.nowMs();
    var p = presenceOf(updater.probe());
    while (p == .nothing and zmetal.time.nowMs() -% start < strap_answer_ms) {
        zmetal.time.delayMs(panel_update.boot_gap_ms);
        p = presenceOf(updater.probe());
    }
    report.strap_presence = p;
    report.strap_test = verdict(p == .bootloader);
}
