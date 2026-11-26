//! The Daisy-side updater of the panel scanner (an STM32C031), std only so
//! the host tests it. It never makes the chip unflashable: the chip is
//! committed to a new image only after this chip has run that image and
//! the image has returned to the bootloader by its own command.
//!
//! The proof has two parts:
//! - The updater proves that the image ran from the trial vector (frames
//!   with the wanted `fw` and `trial` set) and that a bootloader answered
//!   after the bootloader command.
//! - The host's `commit` proves that the image got there by its own
//!   command path: `commit` first requires all of page 0 to read blank.
//!   `stage` leaves page 0 programmed from byte 8 on, and the updater holds
//!   no strap between `stage` and `commit`, so only the image's own
//!   uncommit (S4) blanks it.
//!
//! A `commit` refused because page 0 is not blank therefore means "the
//! trial image did not uncommit itself".
//!
//! **The scanner to itself.** Nothing else may talk to the scanner while
//! `run` executes: a `PanelClient` polling meanwhile writes `clear_booted`
//! and acknowledges, which can turn a real reset into `ResetNotSeen`. After
//! any `run` the scanner may run another image, restarted, with `booted`
//! clear and its counters at 0. Create a new `PanelClient` before polling
//! again: the old one's copy of the state no longer matches.
//!
//! **`.up_to_date` is judged by the `fw` number and the `trial` flag
//! only.** The image's contents are not compared, because that would need
//! the bootloader, which uncommits. `want_fw` must therefore change with
//! every image.
//!
//! A chip whose first 8 bytes of flash read erased is *uncommitted*: at
//! power-on the ROM starts its bootloader. `run` takes these steps in order;
//! `step()` names the one reached, which is the one that failed, or `done`:
//!
//! | step           | what happens                                              | state if it fails                       |
//! |----------------|-----------------------------------------------------------|-----------------------------------------|
//! | `find`         | up to 3 frame reads at 0x42; else up to 3 Get IDs at 0x63 | -                                       |
//! | `enter`        | an application that is not the wanted committed one: the | unchanged or uncommitted                |
//! |                | bootloader command, then wait for the bootloader; if it   | (`NoBootloader`: power-cycle, run again) |
//! |                | does not come, or nothing answered at all, strap entry    |                                         |
//! | `stage`        | `Boot.stage`: check, uncommit, write, trial vector        | uncommitted                             |
//! | `trial_start`  | `Boot.goTrial`; 3 frames in a row, the wanted `fw`,       | strap entry first; uncommitted          |
//! |                | `trial` set                                               | (`TrialSilent`, `TrialWrongFirmware`,   |
//! |                |                                                           | `TrialNotTrial`, or `goTrial`'s error)  |
//! | `trial_return` | the bootloader command; the bootloader must answer        | strap entry first; uncommitted          |
//! |                |                                                           | (`TrialNoReturn`)                       |
//! | `commit`       | `Boot.commit`                                             | `commit`'s error: `Boot.uncommit` first |
//! |                |                                                           | (the bootloader still runs); uncommitted|
//! |                |                                                           | unless that fails too                   |
//! | `start`        | `Boot.start` (Go to the flash base); 3 frames in a row,   | `StartSilent` (no usable frames):       |
//! |                | the wanted `fw`, `trial` clear, `booted` set; then `0x01` | strap entry, then `Boot.uncommit` if    |
//! |                | until a frame shows `booted` clear                        | the bootloader came;                    |
//! |                |                                                           | `start`'s error: if the bootloader      |
//! |                |                                                           | answers (50 tries), `Boot.uncommit`;    |
//! |                |                                                           | else unless frames show the committed   |
//! |                |                                                           | image just started (as in `start`),     |
//! |                |                                                           | strap entry, then `Boot.uncommit` if it |
//! |                |                                                           | came; else left as is, see Limits;      |
//! |                |                                                           | `StartNotCleared`: committed to an      |
//! |                |                                                           | image that runs and passed the trial    |
//! | `reset_proof`  | `NRST` pulse; 3 frames in a row, the wanted `fw`, `trial` | `ResetNotSeen` (frames, `booted` clear: |
//! |                | clear, `booted` set                                       | the pulse did nothing), committed;      |
//! |                |                                                           | no frames: one Get ID; if the ROM       |
//! |                |                                                           | answers, `Boot.start` again and         |
//! |                |                                                           | `ResetIntoBootloader`, committed (not   |
//! |                |                                                           | uncommitted: the image is the tried     |
//! |                |                                                           | one); else, or frames that are wrong,   |
//! |                |                                                           | `DeadAfterReset`: strap entry, then     |
//! |                |                                                           | `Boot.uncommit` if the bootloader came  |
//!
//! `ResetIntoBootloader` is the first board's evidence about the empty
//! flag: the flag `start`'s S3 cleared did not survive the `NRST` pulse
//! (or the ROM cleared nothing and the flag is still set), so every reset
//! starts the ROM until a power cycle, which starts the image from a real
//! reset. The chip is left committed to the image that passed its trial
//! and its start, running again after a Go; a later `run` reports
//! `up_to_date`, without the reset proof.
//!
//! `run` calls `Boot.commit` only after `trial_start` and `trial_return`
//! both passed in the same call: every earlier failure returns before it.
//!
//! **Strap entry** (works without the application's I2C code): hold `INT`
//! low, pulse `NRST`, keep `INT` low 50 ms more, release it, wait 20 ms,
//! then look for the bootloader. Every failure between `stage` and
//! `commit` makes it, so that, given a working `NRST` line, the image
//! under trial is never left running. With a dead line the strap entry
//! cannot reset the chip (see Limits).
//!
//! Where the strap's reset lands depends on the empty flag, and what the
//! ROM does to that flag when it starts is not known for the C031 (the
//! G0's bootloader clears it). A trial image sets the flag (S3) and its
//! uncommit sets it (S4), so a trial image that got that far is one reset
//! away from the ROM either way. But a chip that sits in its ROM,
//! uncommitted, when the pulse comes (nothing answered at `find`, or
//! `goTrial` failed before its Go) is back in its ROM after the pulse only
//! if the ROM has left the flag set. If the ROM cleared it, the core boots
//! erased vectors and stays dark until a power cycle, which gives the ROM
//! again (`NoBootloader` at `enter`: power-cycle and run again).
//!
//! After the commit, `StartSilent`, `DeadAfterReset` and an error from
//! `start` after which no fresh start is seen make the strap entry, then
//! uncommit through the bootloader if it came. If the ROM has left the
//! flag set (not known for the C031), the commit leaves it set: for an
//! image that never ran from the base the reset starts the ROM, the
//! image's own strap check never runs, and that uncommit is what undoes
//! the commit. If the ROM cleared it, the reset starts the committed image
//! and only the image's own strap check (S2) can uncommit it. Neither the
//! strap's outcome nor the uncommit's error ever replaces the step's
//! error.
//!
//! **Waits**, all bounded: after a Go or a reset the application gets
//! 100 ms before the first frame read and up to 20 further reads 10 ms
//! apart; "frames arrive" means 3 accepted frames (right `proto` and CRC)
//! in a row. The bootloader gets up to 50 Get ID attempts 20 ms apart
//! (the first at once). `find` reads up to 3 frames 10 ms apart, so a
//! single bus error does not take a working application for absent, and
//! then sends up to 3 Get IDs 20 ms apart, so a single lost transaction
//! does not take a bootloader for absent and send it the strap entry's
//! NRST pulse.
//!
//! **Limits.**
//! - A rerun after `StartNotCleared`, `ResetNotSeen` or
//!   `ResetIntoBootloader` finds the wanted committed image and reports
//!   `up_to_date`: the missing proof is not retried.
//! - The same holds after a Go at `start` whose acknowledge was lost while
//!   the image did start. `start` returns the host's error. The bootloader
//!   does not answer, and frames arrive that show the committed image just
//!   started (the wanted `fw`, `trial` clear, `booted` set: the `start`
//!   step's own check). So nothing is uncommitted and the image stays
//!   committed and running: it passed its trial, but the start and reset
//!   proofs never ran. A later `run` reports `up_to_date`.
//! - The same holds after `StartSilent`, or after an error from `start`
//!   whose frames fail the check (the Go happened and the image answers,
//!   but not as just started: another `fw`, `trial` set or `booted`
//!   clear), when the strap entry did not reach the ROM (the image had
//!   cleared the empty flag, or the ROM had, and the image ignores its
//!   strap) but the image then runs from that reset. It stays committed,
//!   `start`'s error or `StartSilent` is returned, and a later `run`
//!   reports `up_to_date` without the start or reset proof.
//! - What the ROM does to the empty flag is not known for the C031 (see
//!   Strap entry). If it clears it: a strap at `enter` after nothing
//!   answered, or after a `goTrial` error before the Go, leaves an
//!   uncommitted chip dark until a power cycle; and a committed image that
//!   never started from the base and ignores its strap is not uncommitted
//!   but runs from the strap's reset (the bullet above).
//! - Everything above relies on a working `NRST` line. With a dead one the
//!   strap entry cannot reset the chip. After a failed trial the image
//!   under trial keeps running uncommitted, and a misreporting image (one
//!   that says `trial` clear) is then taken for the wanted committed one:
//!   a later `run` reports `up_to_date`. A power cycle still gives the
//!   bootloader.
//!
//! `Boot` (a type or a pointer to one) is the bootloader host of
//! `stm32_i2c_boot.zig`: `productId() !u16`, `stage(image) !Staged`,
//! `goTrial(staged) !Tried`, `commit(tried, image) !void` (it refuses an
//! image other than the staged one), `start() !void` and `uncommit()
//! !void` (erase page 0 and prove it blank). The errors of `stage`,
//! `goTrial`, `commit` and `start` pass through `run` unchanged;
//! `productId`'s only mean "no bootloader answered", and `uncommit`'s
//! are dropped, so neither is ever returned.
//!
//! `Staged` and `Tried` are the host's own token types, which `run` only
//! holds and passes on, never names or builds: since `commit` needs the
//! `Tried` that `goTrial` returned in the same run, a commit without a
//! trial call cannot even be written in `run`.
//!
//! `Io` (a type or a pointer to one) has `pub const Error`,
//! `read(address: u7, rx: []u8) Error!void`, `write(address: u7, bytes:
//! []const u8) Error!void`, `delayMs(ms: u32) void`, `resetPulse() void`
//! (`NRST` low for 10 ms, then released) and `strap(held: bool) void`
//! (drive `INT` low, or release it). Its errors are not returned: a read
//! that fails is a frame that did not arrive, a command whose write fails
//! is one that was not obeyed.

const std = @import("std");
const proto = @import("panel_proto.zig");

pub const Step = enum(u8) { none, find, enter, stage, trial_start, trial_return, commit, start, reset_proof, done };
pub const Outcome = enum { up_to_date, updated };
pub const Presence = union(enum) { application: struct { fw: u8, trial: bool }, bootloader, nothing };
pub const Error = error{ NoBootloader, TrialSilent, TrialWrongFirmware, TrialNotTrial, TrialNoReturn, StartSilent, StartNotCleared, ResetNotSeen, DeadAfterReset, ResetIntoBootloader };

/// After a Go or a reset: the wait before the first frame read.
pub const app_settle_ms: u32 = 100;
/// After a Go or a reset: reads after the first one, and their spacing.
pub const app_more_reads = 20;
pub const app_read_gap_ms: u32 = 10;
/// Accepted frames in a row that count as "frames arrive".
pub const frames_in_a_row = 3;
/// Get ID attempts while waiting for the bootloader, and their spacing.
///
/// This wait is load-bearing. Two sequences send the bootloader command
/// and fall back to the strap entry when no bootloader answers: at
/// `enter`, and at `trial_return` (the strap after `TrialNoReturn`). In
/// both, this wait is all that separates the command from the strap's
/// `NRST` pulse: 49 gaps of 20 ms, about 1 s, plus the Get ID transfers.
///
/// It must stay well above the application's page-0 erase plus its reset
/// (S4, tens of ms). At `enter` a pulse during that erase can leave a
/// first word that is neither erased nor valid. At `trial_return` the risk
/// is milder, because page 0's first word is already erased during a trial.
pub const boot_attempts = 50;
pub const boot_gap_ms: u32 = 20;
/// Strap entry: `INT` held this long after the reset pulse, then this wait.
///
/// The scanner's side (`strapHeld` in scanner/hal/start.zig): right after
/// its start it samples `INT` 10 times, 1 ms apart, and takes the strap
/// only if all ten read low. The chip leaves reset about 3 to 7 ms after
/// `NRST` is released (the board's 100 nF on `NRST`, charged by the C031's
/// own pull-up; an estimate), and its tenth sample comes about 9 ms after
/// that: about 12 to 16 ms after the release, against the 50 ms held here,
/// a margin of about three times. The numbers are not shared constants:
/// a change on either side needs the comment on both.
pub const strap_hold_ms: u32 = 50;
pub const strap_settle_ms: u32 = 20;
/// Frame reads, `app_read_gap_ms` apart, before `find` concludes there is
/// no application.
pub const find_reads = 3;
/// Get IDs, `boot_gap_ms` apart, before `find` concludes that no bootloader
/// answers either. More than one for the same reason as `find_reads`: a
/// single lost transaction must not send the strap entry's NRST pulse to a
/// chip that sits in its bootloader, which takes it out of the bootloader
/// until a power cycle if the ROM has cleared the empty flag.
pub const find_boot_attempts = 3;

pub fn Updater(comptime Boot: type, comptime Io: type) type {
    return struct {
        const Self = @This();

        boot: Boot,
        io: Io,
        reached: Step = .none,

        pub fn init(boot: Boot, io: Io) Self {
            return .{ .boot = boot, .io = io };
        }

        /// What answers: an application at 0x42 (up to `find_reads` frame
        /// reads), else a bootloader at 0x63 (up to `find_boot_attempts`
        /// Get IDs). Reads only.
        pub fn probe(self: *Self) Presence {
            for (0..find_reads) |i| {
                if (i != 0) self.io.delayMs(app_read_gap_ms);
                if (self.readFrame()) |f| return .{ .application = .{ .fw = f.fw, .trial = f.trial } };
            }
            for (0..find_boot_attempts) |i| {
                if (i != 0) self.io.delayMs(boot_gap_ms);
                if (self.bootloaderAnswers()) return .bootloader;
            }
            return .nothing;
        }

        /// The step the last `run` reached: the one that failed, or `done`.
        pub fn step(self: *const Self) Step {
            return self.reached;
        }

        /// Brings the scanner to `image`, which reports `want_fw`, through
        /// the steps of the table above. `.up_to_date` when an application
        /// reports `want_fw` with `trial` clear (the number and the flag
        /// only, not the contents); nothing is changed then.
        pub fn run(self: *Self, image: []const u8, want_fw: u8) !Outcome {
            self.reached = .find;
            const found = self.probe();

            self.reached = .enter;
            switch (found) {
                .application => |app| {
                    if (app.fw == want_fw and !app.trial) {
                        self.reached = .done;
                        return .up_to_date;
                    }
                    self.send(.enter_bootloader);
                    if (!self.awaitBootloader() and !self.strapEntry()) return error.NoBootloader;
                },
                .bootloader => {},
                .nothing => if (!self.strapEntry()) return error.NoBootloader,
            }

            self.reached = .stage;
            const staged = try self.boot.stage(image);

            // From here until the commit, every failure makes the strap
            // entry before it returns, so that, given a working `NRST`
            // line, the image under trial is never left running and the
            // next `run` starts again from `find` (a dead line: Limits).
            // After a `goTrial` error before the Go the chip is still in
            // its ROM, uncommitted; the strap's reset keeps it there only
            // if the ROM has left the empty flag set, not known for the
            // C031 (else dark until a power cycle; see Strap entry).
            self.reached = .trial_start;
            const tried = self.boot.goTrial(staged) catch |err| {
                _ = self.strapEntry();
                return err;
            };
            const trial = self.awaitFrames() orelse return self.strapThen(error.TrialSilent);
            for (trial) |f| if (f.fw != want_fw) return self.strapThen(error.TrialWrongFirmware);
            for (trial) |f| if (!f.trial) return self.strapThen(error.TrialNotTrial);

            self.reached = .trial_return;
            self.send(.enter_bootloader);
            if (!self.awaitBootloader()) return self.strapThen(error.TrialNoReturn);

            // Only here: the image has run on this chip from the trial vector,
            // and a bootloader answered after its command. `Boot.commit`
            // completes the proof that the image's own command path got it
            // there: it refuses unless all of page 0 reads blank.
            self.reached = .commit;
            // Any error: page 0 erased again before returning it. The
            // bootloader still runs (no Go yet), so no strap is needed. If
            // the last 8-byte write was not reached this is harmless; if it
            // was, it keeps an unverified image from booting at power-on.
            self.boot.commit(tried, image) catch |err| {
                self.boot.uncommit() catch {};
                return err;
            };

            // From here on, a failure that ends with the bootloader
            // answering uncommits through it, so the chip is not left
            // committed to an image that has just failed to start.
            self.reached = .start;
            self.boot.start() catch |err| {
                // Whether the Go happened is unknown: look at the chip.
                if (self.awaitBootloader()) {
                    // A bootloader answers: the Go was refused, or it
                    // happened and the image reset into the ROM before S3.
                    self.boot.uncommit() catch {};
                } else if (!freshStart(self.awaitFrames(), want_fw)) {
                    // No bootloader and no frames that show the committed
                    // image just started: the Go most likely happened and
                    // the image hung or misbehaves (or the Get IDs were
                    // all lost). Strap entry, then uncommit if the
                    // bootloader came. The reset reaches the ROM through
                    // the image's own strap check, or through the empty
                    // flag for an image that never got to S3 if the ROM
                    // has left the flag set (not known for the C031).
                    if (self.strapEntry()) self.boot.uncommit() catch {};
                } // else the image started and only the acknowledge was lost (a limit)
                return err;
            };
            try self.startProof(want_fw);

            self.reached = .reset_proof;
            self.io.resetPulse();
            const after = self.awaitFrames() orelse return self.silentAfterReset();
            for (after) |f| if (f.fw != want_fw or f.trial) return self.strapUncommit(error.DeadAfterReset);
            for (after) |f| if (!f.booted) return error.ResetNotSeen;

            self.reached = .done;
            return .updated;
        }

        /// `reset_proof` when no frames came after the pulse. One Get ID
        /// first, before any strap. If the ROM answers, the pulse started
        /// the ROM and not the image: the empty flag `start`'s S3 cleared
        /// did not hold across the reset (or the ROM cleared nothing and
        /// the flag is still set). The image is the tried one and intact
        /// (the commit verified it, and it answered from the base), so it
        /// is not uncommitted: Go to the base starts it again, and the
        /// error is `ResetIntoBootloader`, with the chip committed. A
        /// refused Go is dropped: the chip is committed either way, in
        /// its ROM or running, and a power cycle starts the image from a
        /// real reset (page 0 programmed: power-on clears the flag).
        ///
        /// If the ROM does not answer, the strap entry and the uncommit
        /// follow, and `DeadAfterReset`. That includes a ROM that is there
        /// but whose one Get ID is lost, or that is not up yet after the
        /// 300 ms of frame reads: the good image is then erased, the safe
        /// direction.
        fn silentAfterReset(self: *Self) Error {
            if (self.bootloaderAnswers()) {
                self.boot.start() catch {};
                return error.ResetIntoBootloader;
            }
            return self.strapUncommit(error.DeadAfterReset);
        }

        /// After the Go to the flash base: the committed image answers, and
        /// clears `booted` on command, so that `reset_proof` can tell a
        /// reset by `booted` coming back.
        fn startProof(self: *Self, want_fw: u8) Error!void {
            if (!freshStart(self.awaitFrames(), want_fw)) return self.strapUncommit(error.StartSilent);

            self.send(.clear_booted);
            var answered = false;
            for (0..app_more_reads) |_| {
                self.io.delayMs(app_read_gap_ms);
                const f = self.readFrame() orelse continue;
                if (f.fw != want_fw or f.trial) continue;
                if (!f.booted) return;
                answered = true;
                self.send(.clear_booted); // again: the last write may have been lost
            }
            return if (answered) error.StartNotCleared else self.strapUncommit(error.StartSilent);
        }

        /// Whether `frames` (from `awaitFrames`) show the committed image
        /// just started by a Go: the wanted `fw`, `trial` clear and
        /// `booted` set. `booted` matters: without it `reset_proof` would
        /// later blame a working reset line. No frames is no start.
        fn freshStart(frames: ?[frames_in_a_row]proto.Frame, want_fw: u8) bool {
            const got = frames orelse return false;
            for (got) |f| if (f.fw != want_fw or f.trial or !f.booted) return false;
            return true;
        }

        /// One frame read at 0x42; null for a bus error or a refused frame.
        fn readFrame(self: *Self) ?proto.Frame {
            var raw: [proto.frame_len]u8 = undefined;
            self.io.read(proto.address, &raw) catch return null;
            return proto.decode(&raw) catch null;
        }

        /// After a Go or a reset: `frames_in_a_row` accepted frames in a
        /// row within the read budget, or null.
        fn awaitFrames(self: *Self) ?[frames_in_a_row]proto.Frame {
            self.io.delayMs(app_settle_ms);
            var got: [frames_in_a_row]proto.Frame = undefined;
            var n: usize = 0;
            for (0..1 + app_more_reads) |i| {
                if (i != 0) self.io.delayMs(app_read_gap_ms);
                if (self.readFrame()) |f| {
                    got[n] = f;
                    n += 1;
                    if (n == frames_in_a_row) return got;
                } else n = 0;
            }
            return null;
        }

        /// A command write to the application. Its outcome is observed
        /// afterwards, so a failed write is not an error here.
        fn send(self: *Self, c: proto.Command) void {
            var buf: [proto.max_command_len]u8 = undefined;
            self.io.write(proto.address, proto.encodeCommand(c, &buf)) catch {};
        }

        fn bootloaderAnswers(self: *Self) bool {
            _ = self.boot.productId() catch return false;
            return true;
        }

        /// Up to `boot_attempts` Get IDs, `boot_gap_ms` apart, the first at once.
        fn awaitBootloader(self: *Self) bool {
            for (0..boot_attempts) |i| {
                if (i != 0) self.io.delayMs(boot_gap_ms);
                if (self.bootloaderAnswers()) return true;
            }
            return false;
        }

        /// Hold `INT` low through a reset so that the application uncommits
        /// itself (an uncommitted chip starts its bootloader if the empty
        /// flag is set: see Strap entry in the file comment), then look for
        /// the bootloader.
        fn strapEntry(self: *Self) bool {
            self.io.strap(true);
            self.io.resetPulse();
            self.io.delayMs(strap_hold_ms);
            self.io.strap(false);
            self.io.delayMs(strap_settle_ms);
            return self.awaitBootloader();
        }

        /// Strap entry, then `err` whether or not the bootloader came.
        fn strapThen(self: *Self, err: Error) Error {
            _ = self.strapEntry();
            return err;
        }

        /// After the commit: strap entry, and if the bootloader comes,
        /// page 0 erased through it. If the ROM has left the empty flag set
        /// (not known for the C031), a commit leaves it set, so for an image
        /// that never ran from the base the strap's reset starts the ROM,
        /// the image's own strap check never runs, and this uncommit is
        /// what undoes the commit. If the ROM cleared it, the reset starts
        /// the image, and only its own strap check can. Then `err`,
        /// whatever happened: the uncommit's error is dropped.
        fn strapUncommit(self: *Self, err: Error) Error {
            if (self.strapEntry()) self.boot.uncommit() catch {};
            return err;
        }
    };
}

// ============================================================================

const testing = std.testing;

/// How a scanner image behaves once it runs on the chip.
const Image = struct {
    fw: u8,
    /// Its I2C target serves frames and takes commands.
    answers: bool = true,
    /// `0xB0 0x07 0x5A` uncommits and starts the bootloader (S4).
    obeys_command: bool = true,
    /// `0x01` clears `booted`.
    clears_booted: bool = true,
    /// `INT` held low through a reset uncommits (S2, S4).
    honours_strap: bool = true,
    /// `trial` is reported while page 0 reads erased (S3).
    reports_trial: bool = true,
    /// It starts from a Go to the flash base and gets as far as S3.
    runs_from_base: bool = true,
    /// After an `NRST` pulse it starts (S1), passes its strap check (S2,
    /// see `honours_strap`) and gets to a working application; false
    /// models a failure after S2.
    starts_from_reset: bool = true,
    /// It sets `booted` when it starts.
    sets_booted: bool = true,
    /// After a start of kind `odd_start`, the frames from the `odd_from`-th
    /// on (counted from 0) report another `fw`, another `trial` flag, or
    /// are not served at all.
    odd_start: ?Start = null,
    odd_from: usize = 0,
    odd_fw: ?u8 = null,
    odd_trial: ?bool = null,
    odd_silent: bool = false,
};

/// How the running image was started: from the trial vector, by a Go to
/// the flash base, or by a reset (power-on included).
const Start = enum { trial, base, reset };

const Call = enum { product_id, stage, go_trial, commit, start, uncommit, cmd_enter, cmd_clear_booted, strap_on, strap_off, reset_pulse, back_from_trial };
const Entry = struct { call: Call, ms: u64 };

/// The chip as the updater sees it: what page 0 holds, what the trial
/// vector holds, the empty flag, what runs, and the call log of both
/// fakes. A blank chip (the default) runs its bootloader.
///
/// The empty flag (`FLASH_ACR.EMPTY`): set at power-on when page 0 reads
/// erased and by the application's uncommit (S4); set by an image that
/// starts with page 0 erased (S3, a trial) and cleared by one that starts
/// with page 0 programmed (S3). A reset with the flag set starts the
/// bootloader; otherwise the application at page 0 starts, and an erased
/// page 0 locks the core.
///
/// What the ROM does to the flag when it starts is not known for the
/// C031 (c031-flash-facts §1: the G0's bootloader clears it, the C031's
/// is not documented). `rom_clears_empty` picks one of the two: false,
/// the ROM leaves the flag as it found it; true, it clears it. Every test
/// whose outcome depends on what a reset does to an uncommitted or a
/// freshly committed chip runs under both, with each one's expected end.
const Chip = struct {
    /// The image page 0 commits the chip to; null while page 0 reads erased.
    committed: ?Image = null,
    /// The image at the trial vector.
    staged: ?Image = null,
    empty: bool = true,
    /// The ROM clears the empty flag whenever it starts (the G0's
    /// behaviour); false, it leaves the flag as it found it. Not known
    /// for the C031. A blank chip under it: `blankChip`.
    rom_clears_empty: bool = false,
    /// The flag as power-on set it: true for a chip that was blank then.
    power_on_empty: bool = true,
    /// A value written to the flag by software does not survive an `NRST`
    /// pulse: the reset puts the power-on value back. ST's C0 HAL says the
    /// forced value holds for every reset that does not reload the option
    /// bytes; untried on a C031, and the first board's `reset_proof` is
    /// the first test of it.
    soft_flag_lost_at_reset: bool = false,
    running: Running = .bootloader,
    booted: bool = true,
    seq: u8 = 0,
    strap_held: bool = false,
    reset_line_works: bool = true,
    /// How the image under test behaves once staged.
    new_image: Image,
    /// This `Boot` call fails: before any effect, or, with `fail_late`,
    /// after it (an acknowledge lost on the way back); with `fail_skip`,
    /// only after that many calls of it went through.
    fail: ?Call = null,
    fail_late: bool = false,
    fail_skip: usize = 0,
    /// `uncommit` fails with `error.UncommitFailed`, changing nothing.
    fail_uncommit: bool = false,
    /// After `start`, this many Get IDs are lost (they fail although the
    /// bootloader may run).
    lose_get_ids_after_start: usize = 0,
    get_ids_to_lose: usize = 0,
    /// This many reads fail before the next one is served.
    fail_reads: usize = 0,
    /// Every n-th read fails (0: none).
    read_fails_every: usize = 0,
    /// This many `0x01` writes are lost.
    drop_clear_writes: usize = 0,

    log: [512]Entry = undefined,
    log_len: usize = 0,
    ms: u64 = 0,
    reads: usize = 0,
    /// Frames served since the running image started.
    served: usize = 0,
    /// The host's tokens: the last ones issued, and what `goTrial` and
    /// `commit` were last given.
    serials: u32 = 0,
    issued_staged: ?FakeBoot.Staged = null,
    issued_tried: ?FakeBoot.Tried = null,
    trial_got: ?FakeBoot.Staged = null,
    commit_got: ?FakeBoot.Tried = null,
    bad_transfers: usize = 0, // not 16 bytes from 0x42, or not to 0x42
    trial_ran: bool = false,
    trial_returned: bool = false,
    commits: usize = 0,
    commit_without_proof: bool = false,

    const App = struct { image: Image, started_as: Start };
    const Running = union(enum) { off, bootloader, app: App };

    fn nextSerial(self: *Chip) u32 {
        self.serials += 1;
        return self.serials;
    }

    fn record(self: *Chip, call: Call) void {
        self.log[self.log_len] = .{ .call = call, .ms = self.ms };
        self.log_len += 1;
    }

    fn entries(self: *const Chip) []const Entry {
        return self.log[0..self.log_len];
    }

    fn count(self: *const Chip, call: Call) usize {
        var n: usize = 0;
        for (self.entries()) |e| n += @intFromBool(e.call == call);
        return n;
    }

    fn firstIndex(self: *const Chip, call: Call, from: usize) ?usize {
        for (self.entries()[from..], from..) |e, i| if (e.call == call) return i;
        return null;
    }

    fn startApp(self: *Chip, image: Image, started_as: Start) void {
        self.running = .{ .app = .{ .image = image, .started_as = started_as } };
        self.booted = image.sets_booted;
        self.seq = 0;
        self.served = 0;
        // S3: cleared with page 0 programmed, set with it erased (a trial).
        self.empty = self.committed == null;
    }

    /// The ROM starts: the bootloader runs, and the empty flag is cleared
    /// if this model's ROM clears it.
    fn enterRom(self: *Chip) void {
        self.running = .bootloader;
        if (self.rom_clears_empty) self.empty = false;
    }

    /// S4: erase page 0, set the empty flag, reset into the bootloader.
    fn uncommitItself(self: *Chip) void {
        self.committed = null;
        self.empty = true;
        self.enterRom();
    }

    fn app(self: *const Chip) ?App {
        return switch (self.running) {
            .app => |a| if (a.image.answers) a else null,
            else => null,
        };
    }

    /// The frame the running image serves next, or null if none.
    fn frame(self: *const Chip) ?[proto.frame_len]u8 {
        const a = self.app() orelse return null;
        const odd = if (a.image.odd_start) |s| s == a.started_as and self.served >= a.image.odd_from else false;
        if (odd and a.image.odd_silent) return null;
        return proto.encode(.{
            .fw = (if (odd) a.image.odd_fw else null) orelse a.image.fw,
            .seq = self.seq,
            .booted = self.booted,
            .trial = (if (odd) a.image.odd_trial else null) orelse (self.committed == null and a.image.reports_trial),
            .keys = 0,
            .enc = .{ 0, 0, 0, 0 },
        });
    }

    /// What an `NRST` pulse does: with the empty flag set, the bootloader;
    /// otherwise the image at page 0, which uncommits itself if the strap
    /// is held, and else starts if it can.
    fn reset(self: *Chip) void {
        if (self.soft_flag_lost_at_reset) self.empty = self.power_on_empty;
        if (self.empty) {
            self.enterRom();
            return;
        }
        const c = self.committed orelse {
            self.running = .off; // an erased vector: locked until a power cycle
            return;
        };
        if (self.strap_held and c.honours_strap) {
            self.uncommitItself();
        } else if (!c.starts_from_reset) {
            self.running = .off;
        } else {
            self.startApp(c, .reset);
        }
    }
};

/// The bootloader host of Task 7, scripted: every call is logged, and
/// `chip.fail` makes one fail, before its effect or after it.
const FakeBoot = struct {
    chip: *Chip,
    image: []const u8, // the bytes `run` must hand on

    pub const Failure = error{ Injected, Nack, WrongImage, UncommitFailed };

    /// The host's tokens, each with a serial number from the chip.
    pub const Staged = struct { serial: u32 };
    pub const Tried = struct { serial: u32, of_staged: u32 };

    fn failsHere(self: FakeBoot, call: Call, late: bool) bool {
        const f = self.chip.fail orelse return false;
        if (f != call or self.chip.fail_late != late) return false;
        if (self.chip.fail_skip > 0) {
            self.chip.fail_skip -= 1;
            return false;
        }
        return true;
    }

    fn begin(self: FakeBoot, call: Call) Failure!void {
        self.chip.record(call);
        if (self.failsHere(call, false)) return error.Injected;
        if (self.chip.running != .bootloader) return error.Nack;
    }

    fn end(self: FakeBoot, call: Call) Failure!void {
        if (self.failsHere(call, true)) return error.Injected;
    }

    fn sameImage(self: FakeBoot, image: []const u8) Failure!void {
        if (image.ptr != self.image.ptr or image.len != self.image.len) return error.WrongImage;
    }

    pub fn productId(self: FakeBoot) Failure!u16 {
        self.chip.record(.product_id);
        if (self.chip.get_ids_to_lose > 0) {
            self.chip.get_ids_to_lose -= 1;
            return error.Nack; // lost on the bus
        }
        if (self.failsHere(.product_id, false)) return error.Injected;
        if (self.chip.running != .bootloader) return error.Nack;
        try self.end(.product_id);
        return 0x453;
    }

    pub fn stage(self: FakeBoot, image: []const u8) Failure!Staged {
        try self.begin(.stage);
        try self.sameImage(image);
        self.chip.committed = null; // H3: page 0 goes first
        self.chip.staged = self.chip.new_image;
        try self.end(.stage);
        const token = Staged{ .serial = self.chip.nextSerial() };
        self.chip.issued_staged = token;
        return token;
    }

    pub fn goTrial(self: FakeBoot, staged: Staged) Failure!Tried {
        self.chip.trial_got = staged;
        try self.begin(.go_trial);
        const s = self.chip.staged orelse return error.Nack;
        self.chip.trial_ran = true;
        self.chip.trial_returned = false;
        self.chip.startApp(s, .trial);
        try self.end(.go_trial);
        const token = Tried{ .serial = self.chip.nextSerial(), .of_staged = staged.serial };
        self.chip.issued_tried = token;
        return token;
    }

    pub fn commit(self: FakeBoot, tried: Tried, image: []const u8) Failure!void {
        self.chip.commit_got = tried;
        self.chip.commits += 1;
        if (!(self.chip.trial_ran and self.chip.trial_returned)) self.chip.commit_without_proof = true;
        try self.begin(.commit);
        try self.sameImage(image);
        self.chip.committed = self.chip.staged orelse return error.Nack;
        try self.end(.commit);
    }

    pub fn start(self: FakeBoot) Failure!void {
        self.chip.get_ids_to_lose = self.chip.lose_get_ids_after_start;
        try self.begin(.start);
        const c = self.chip.committed orelse return error.Nack;
        if (c.runs_from_base) self.chip.startApp(c, .base) else self.chip.running = .off;
        try self.end(.start);
    }

    pub fn uncommit(self: FakeBoot) Failure!void {
        try self.begin(.uncommit);
        if (self.chip.fail_uncommit) return error.UncommitFailed;
        self.chip.committed = null; // page 0 erased and read back blank
        try self.end(.uncommit);
    }
};

/// The Daisy's side of the wires: the bus at 0x42, delays (counted, not
/// waited), the `NRST` pulse and the `INT` strap.
const FakeIo = struct {
    chip: *Chip,

    pub const Error = error{Nack};

    pub fn read(self: FakeIo, address: u7, rx: []u8) FakeIo.Error!void {
        const c = self.chip;
        c.reads += 1;
        if (address != proto.address or rx.len != proto.frame_len) c.bad_transfers += 1;
        if (c.fail_reads > 0) {
            c.fail_reads -= 1;
            return error.Nack;
        }
        if (c.read_fails_every != 0 and c.reads % c.read_fails_every == 0) return error.Nack;
        const f = c.frame() orelse return error.Nack;
        c.served += 1;
        @memcpy(rx, &f);
    }

    pub fn write(self: FakeIo, address: u7, bytes: []const u8) FakeIo.Error!void {
        const c = self.chip;
        if (address != proto.address) c.bad_transfers += 1;
        const command = proto.decodeCommand(bytes) orelse return;
        switch (command) {
            .enter_bootloader => c.record(.cmd_enter),
            .clear_booted => c.record(.cmd_clear_booted),
            .ack => {},
        }
        const a = c.app() orelse return error.Nack;
        switch (command) {
            .enter_bootloader => if (a.image.obeys_command) {
                c.uncommitItself();
                if (a.started_as == .trial) {
                    c.trial_returned = true;
                    c.record(.back_from_trial);
                }
            },
            .clear_booted => {
                if (c.drop_clear_writes > 0) {
                    c.drop_clear_writes -= 1;
                    return error.Nack;
                }
                if (a.image.clears_booted and c.booted) {
                    c.booted = false;
                    c.seq +%= 1;
                }
            },
            .ack => {},
        }
    }

    pub fn delayMs(self: FakeIo, ms: u32) void {
        self.chip.ms += ms;
    }

    pub fn resetPulse(self: FakeIo) void {
        self.chip.record(.reset_pulse);
        self.chip.ms += 10;
        if (self.chip.reset_line_works) self.chip.reset();
    }

    pub fn strap(self: FakeIo, held: bool) void {
        self.chip.record(if (held) .strap_on else .strap_off);
        self.chip.strap_held = held;
    }
};

const TestUpdater = Updater(FakeBoot, FakeIo);

const test_image = [_]u8{ 0x00, 0x30, 0x00, 0x20, 0xC1, 0x00, 0x00, 0x08, 1, 2, 3, 4, 5, 6, 7, 8 };
const want: u8 = 5;

fn updater(chip: *Chip) TestUpdater {
    return TestUpdater.init(.{ .chip = chip, .image = &test_image }, .{ .chip = chip });
}

/// A chip committed to `image` and running it (so S3 cleared the empty flag).
fn appChip(image: Image) Chip {
    var c = Chip{ .new_image = .{ .fw = want }, .committed = image, .empty = false, .power_on_empty = false };
    c.running = .{ .app = .{ .image = image, .started_as = .reset } };
    return c;
}

/// Both models of the ROM (`Chip.rom_clears_empty`): false first.
const both_roms = [_]bool{ false, true };

/// A blank chip in its ROM, about to run `new_image`, under the ROM model
/// `rom_clears_empty`: power-on set the empty flag (page 0 erased) and
/// started the ROM, which cleared the flag if it clears it.
fn blankChip(new_image: Image, rom_clears_empty: bool) Chip {
    return .{ .new_image = new_image, .rom_clears_empty = rom_clears_empty, .empty = !rom_clears_empty };
}

/// `appChip` under the ROM model `rom_clears_empty`.
fn appChipUnder(image: Image, rom_clears_empty: bool) Chip {
    var c = appChip(image);
    c.rom_clears_empty = rom_clears_empty;
    return c;
}

/// For `errdefer`: which ROM model a failing test ran under.
fn printRom(rom_clears_empty: bool) void {
    std.debug.print("ROM model: {s}\n", .{if (rom_clears_empty) "clears the empty flag" else "leaves the empty flag set"});
}

fn expectLog(chip: *const Chip, want_calls: []const Call) !void {
    var got: [512]Call = undefined;
    for (chip.entries(), 0..) |e, i| got[i] = e.call;
    try testing.expectEqualSlices(Call, want_calls, got[0..chip.log_len]);
}

/// The property that matters most: `commit` is called only after a trial
/// started (`goTrial`) and the trial image returned to the bootloader by
/// its own command path, in this same run.
fn expectCommitOnlyAfterTrial(chip: *const Chip) !void {
    try testing.expect(!chip.commit_without_proof);
    const c = chip.firstIndex(.commit, 0) orelse return;
    var last_trial: ?usize = null;
    for (chip.entries()[0..c], 0..) |e, i| {
        if (e.call == .go_trial) last_trial = i;
    }
    const t = last_trial orelse return error.TestUnexpectedResult;
    const back = chip.firstIndex(.back_from_trial, t) orelse return error.TestUnexpectedResult;
    try testing.expect(back < c);
}

/// The strap entry, in order: INT held, the reset pulse, INT released.
fn expectStrapAt(chip: *const Chip, from: usize) !void {
    const on = try at(chip, .strap_on, from);
    if (on + 2 >= chip.log_len) return error.TestUnexpectedResult;
    try testing.expectEqual(Call.reset_pulse, chip.entries()[on + 1].call);
    try testing.expectEqual(Call.strap_off, chip.entries()[on + 2].call);
}

/// The index of the first `call` at or after `from`; fails the test if none.
fn at(chip: *const Chip, call: Call, from: usize) !usize {
    return chip.firstIndex(call, from) orelse error.TestUnexpectedResult;
}

test "before a run the step is none" {
    var chip = Chip{ .new_image = .{ .fw = want } };
    const u = updater(&chip);
    try testing.expectEqual(Step.none, u.step());
}

test "an up-to-date committed application gives up_to_date, with no Boot call and no write" {
    var chip = appChip(.{ .fw = want });
    var u = updater(&chip);
    try testing.expectEqual(Outcome.up_to_date, try u.run(&test_image, want));
    try testing.expectEqual(Step.done, u.step());
    try expectLog(&chip, &.{}); // not even productId
    try testing.expectEqual(@as(usize, 0), chip.bad_transfers);
}

test "a blank chip is updated, with the calls in the order of the steps, under both ROM models" {
    for (both_roms) |rom_clears_empty| {
        errdefer printRom(rom_clears_empty);
        var chip = blankChip(.{ .fw = want }, rom_clears_empty);
        var u = updater(&chip);
        try testing.expectEqual(Outcome.updated, try u.run(&test_image, want));
        try testing.expectEqual(Step.done, u.step());
        try expectLog(&chip, &.{
            .product_id, // find: the bootloader answers
            .stage,
            .go_trial,
            .cmd_enter, // trial_return
            .back_from_trial,
            .product_id,
            .commit,
            .start,
            .cmd_clear_booted,
            .reset_pulse, // reset_proof
        });
        try expectCommitOnlyAfterTrial(&chip);
        try testing.expectEqual(@as(?Image, chip.new_image), chip.committed);
        const f = try proto.decode(&(chip.frame() orelse return error.TestUnexpectedResult));
        try testing.expect(f.booted and !f.trial and f.fw == want);
        try testing.expectEqual(@as(usize, 0), chip.bad_transfers);
    }
}

test "an old application gets the bootloader command first, then the update" {
    var chip = appChip(.{ .fw = want - 1 });
    var u = updater(&chip);
    try testing.expectEqual(Outcome.updated, try u.run(&test_image, want));
    try expectLog(&chip, &.{ .cmd_enter, .product_id, .stage, .go_trial, .cmd_enter, .back_from_trial, .product_id, .commit, .start, .cmd_clear_booted, .reset_pulse });
    try expectCommitOnlyAfterTrial(&chip);
    try testing.expectEqual(@as(?Image, chip.new_image), chip.committed);
}

test "a trial application found at the start is updated, not trusted, even with the wanted firmware" {
    var chip = Chip{ .new_image = .{ .fw = want }, .staged = .{ .fw = want } };
    chip.startApp(.{ .fw = want }, .trial); // page 0 erased: it reports `trial`
    var u = updater(&chip);
    try testing.expectEqual(Presence{ .application = .{ .fw = want, .trial = true } }, u.probe());
    try testing.expectEqual(Outcome.updated, try u.run(&test_image, want));
    try testing.expectEqual(@as(usize, 0), try at(&chip, .cmd_enter, 0)); // the command comes first
    try testing.expect(chip.count(.stage) == 1 and chip.count(.go_trial) == 1 and chip.count(.commit) == 1);
    try expectCommitOnlyAfterTrial(&chip);
}

test "nothing answers: the strap sequence, then NoBootloader, in bounded time" {
    const dead = Image{ .fw = want - 1, .answers = false, .honours_strap = false, .starts_from_reset = false };
    var chip = appChip(dead);
    chip.running = .off;
    var u = updater(&chip);
    try testing.expectError(error.NoBootloader, u.run(&test_image, want));
    try testing.expectEqual(Step.enter, u.step());
    try expectStrapAt(&chip, 0);
    const on = (try at(&chip, .strap_on, 0));
    const e = chip.entries();
    try testing.expectEqual(e[on].ms + 10 + strap_hold_ms, e[on + 2].ms); // INT held through the pulse and 50 ms after
    try testing.expectEqual(e[on + 2].ms + strap_settle_ms, e[on + 3].ms); // then 20 ms before the first Get ID
    try testing.expectEqual(@as(usize, 3 + boot_attempts), chip.count(.product_id));
    try testing.expectEqual(@as(usize, 0), chip.count(.stage) + chip.count(.commit));
    // find: 3 reads 10 ms apart, 3 Get IDs 20 ms apart; strap: 10 + 50 +
    // 20; then 49 gaps of 20 ms.
    try testing.expectEqual(@as(u64, 2 * 10 + 2 * 20 + 10 + 50 + 20 + 49 * 20), chip.ms);
    try testing.expectEqual(@as(?Image, dead), chip.committed); // unchanged
}

test "nothing answers but the strap brings the bootloader: the update goes on" {
    var chip = appChip(.{ .fw = want - 1, .answers = false });
    var u = updater(&chip);
    try testing.expectEqual(Outcome.updated, try u.run(&test_image, want));
    try expectStrapAt(&chip, 0);
    try expectCommitOnlyAfterTrial(&chip);
}

test "an application that ignores the bootloader command gets the strap, then the update" {
    var chip = appChip(.{ .fw = want - 1, .obeys_command = false });
    var u = updater(&chip);
    try testing.expectEqual(Outcome.updated, try u.run(&test_image, want));
    try testing.expectEqual(@as(usize, 0), try at(&chip, .cmd_enter, 0)); // the command comes first
    try testing.expectEqual(@as(usize, boot_attempts), (try at(&chip, .strap_on, 0)) - 1); // 50 Get IDs first
    try expectStrapAt(&chip, 0);
    try expectCommitOnlyAfterTrial(&chip);
}

test "an application that ignores the command and the strap gives NoBootloader and stays as it was" {
    const old = Image{ .fw = want - 1, .obeys_command = false, .honours_strap = false };
    var chip = appChip(old);
    var u = updater(&chip);
    try testing.expectError(error.NoBootloader, u.run(&test_image, want));
    try testing.expectEqual(Step.enter, u.step());
    try testing.expectEqual(@as(?Image, old), chip.committed);
    try testing.expectEqual(@as(usize, 0), chip.count(.stage));
}

const FailCase = struct {
    name: []const u8,
    setup: *const fn (*Chip) void,
    err: anyerror,
    step: Step,
    commits: usize,
    /// The chip is committed to the new image afterwards, under either ROM
    /// model (no row differs).
    committed_after: bool,
    /// The chip runs its bootloader afterwards, if the ROM leaves the empty
    /// flag as it found it.
    in_bootloader_after: bool,
    /// The same if the ROM clears the flag; null: as `in_bootloader_after`.
    in_bootloader_if_rom_clears: ?bool = null,
    /// A strap entry follows the `stage` call.
    strap_after_stage: bool = false,
    /// `Boot.uncommit` was called.
    uncommits: bool = false,
};

const fail_cases = [_]FailCase{
    .{ .name = "enter: nothing answers", .setup = &Setups.deadChip, .err = error.NoBootloader, .step = .enter, .commits = 0, .committed_after = false, .in_bootloader_after = false },
    .{ .name = "stage fails", .setup = &Setups.failStage, .err = error.Injected, .step = .stage, .commits = 0, .committed_after = false, .in_bootloader_after = true },
    // The Go was never made: the strap's reset meets an uncommitted chip
    // that sits in its ROM. With the flag set, the ROM again; with the flag
    // cleared by the ROM, erased vectors: the core locks, dark until a power
    // cycle, which gives the ROM (the review's state F).
    .{ .name = "goTrial fails", .setup = &Setups.failGoTrial, .err = error.Injected, .step = .trial_start, .commits = 0, .committed_after = false, .in_bootloader_after = true, .in_bootloader_if_rom_clears = false, .strap_after_stage = true },
    .{ .name = "goTrial's acknowledge lost", .setup = &Setups.goTrialAckLost, .err = error.Injected, .step = .trial_start, .commits = 0, .committed_after = false, .in_bootloader_after = true, .strap_after_stage = true },
    .{ .name = "trial silent", .setup = &Setups.silent, .err = error.TrialSilent, .step = .trial_start, .commits = 0, .committed_after = false, .in_bootloader_after = true, .strap_after_stage = true },
    .{ .name = "trial wrong firmware", .setup = &Setups.wrongFw, .err = error.TrialWrongFirmware, .step = .trial_start, .commits = 0, .committed_after = false, .in_bootloader_after = true, .strap_after_stage = true },
    .{ .name = "trial not trial", .setup = &Setups.notTrial, .err = error.TrialNotTrial, .step = .trial_start, .commits = 0, .committed_after = false, .in_bootloader_after = true, .strap_after_stage = true },
    .{ .name = "trial no return", .setup = &Setups.noReturn, .err = error.TrialNoReturn, .step = .trial_return, .commits = 0, .committed_after = false, .in_bootloader_after = true, .strap_after_stage = true },
    .{ .name = "commit fails", .setup = &Setups.failCommit, .err = error.Injected, .step = .commit, .commits = 1, .committed_after = false, .in_bootloader_after = true, .uncommits = true },
    .{ .name = "commit fails after its last write", .setup = &Setups.failCommitLate, .err = error.Injected, .step = .commit, .commits = 1, .committed_after = false, .in_bootloader_after = true, .uncommits = true },
    .{ .name = "start refused", .setup = &Setups.failStart, .err = error.Injected, .step = .start, .commits = 1, .committed_after = false, .in_bootloader_after = true, .uncommits = true },
    .{ .name = "start silent", .setup = &Setups.notFromBase, .err = error.StartSilent, .step = .start, .commits = 1, .committed_after = false, .in_bootloader_after = true, .strap_after_stage = true, .uncommits = true },
    .{ .name = "start not cleared", .setup = &Setups.keepsBooted, .err = error.StartNotCleared, .step = .start, .commits = 1, .committed_after = true, .in_bootloader_after = false },
    .{ .name = "reset not seen", .setup = &Setups.deadResetLine, .err = error.ResetNotSeen, .step = .reset_proof, .commits = 1, .committed_after = true, .in_bootloader_after = false },
    .{ .name = "dead after reset", .setup = &Setups.deadAfterReset, .err = error.DeadAfterReset, .step = .reset_proof, .commits = 1, .committed_after = true, .in_bootloader_after = false, .strap_after_stage = true },
    .{ .name = "reset into the bootloader", .setup = &Setups.softFlagLost, .err = error.ResetIntoBootloader, .step = .reset_proof, .commits = 1, .committed_after = true, .in_bootloader_after = false },
};

const Setups = struct {
    fn deadChip(c: *Chip) void {
        c.committed = .{ .fw = want - 1, .answers = false, .honours_strap = false, .starts_from_reset = false };
        c.empty = false;
        c.running = .off;
    }
    fn failStage(c: *Chip) void {
        c.fail = .stage;
    }
    fn failGoTrial(c: *Chip) void {
        c.fail = .go_trial;
    }
    fn goTrialAckLost(c: *Chip) void {
        c.fail = .go_trial;
        c.fail_late = true; // the image runs, the host hears an error
    }
    fn silent(c: *Chip) void {
        c.new_image.answers = false;
    }
    fn wrongFw(c: *Chip) void {
        c.new_image.fw = want + 1;
    }
    fn notTrial(c: *Chip) void {
        c.new_image.reports_trial = false;
    }
    fn noReturn(c: *Chip) void {
        c.new_image.obeys_command = false;
    }
    fn failCommit(c: *Chip) void {
        c.fail = .commit;
    }
    fn failCommitLate(c: *Chip) void {
        c.fail = .commit;
        c.fail_late = true; // page 0 written, then the error (a failed verify, a dropped bus)
    }
    fn failStart(c: *Chip) void {
        c.fail = .start;
    }
    fn notFromBase(c: *Chip) void {
        c.new_image.runs_from_base = false;
    }
    fn keepsBooted(c: *Chip) void {
        c.new_image.clears_booted = false;
    }
    fn deadResetLine(c: *Chip) void {
        c.reset_line_works = false;
    }
    fn deadAfterReset(c: *Chip) void {
        c.new_image.starts_from_reset = false;
        c.new_image.honours_strap = false;
    }
    fn softFlagLost(c: *Chip) void {
        c.soft_flag_lost_at_reset = true; // the pulse starts the ROM
    }
};

test "for every failing step, under both ROM models: the named error, step() names the step, and commit never comes before the trial passed" {
    for (both_roms) |rom_clears_empty| {
        for (fail_cases) |case| {
            errdefer std.debug.print("case: {s}\n", .{case.name});
            errdefer printRom(rom_clears_empty);
            var chip = blankChip(.{ .fw = want }, rom_clears_empty);
            case.setup(&chip);
            var u = updater(&chip);
            try testing.expectError(case.err, u.run(&test_image, want));
            try testing.expectEqual(case.step, u.step());
            try testing.expectEqual(case.commits, chip.commits);
            try expectCommitOnlyAfterTrial(&chip);
            if (@backingInt(case.step) < @backingInt(Step.commit)) {
                try testing.expectEqual(@as(usize, 0), chip.count(.commit));
                try testing.expectEqual(@as(usize, 0), chip.count(.start));
            }
            try testing.expectEqual(case.committed_after, chip.committed != null and std.meta.eql(chip.committed.?, chip.new_image));
            const in_bootloader = if (rom_clears_empty) case.in_bootloader_if_rom_clears orelse case.in_bootloader_after else case.in_bootloader_after;
            try testing.expectEqual(in_bootloader, chip.running == .bootloader);
            const strap_seen = if (chip.firstIndex(.stage, 0)) |si| chip.firstIndex(.strap_on, si) != null else false;
            try testing.expectEqual(case.strap_after_stage, strap_seen);
            try testing.expectEqual(case.uncommits, chip.count(.uncommit) > 0);
        }
    }
}

test "a failed trial leaves the chip in its bootloader: a second run stages again and is never up_to_date" {
    // The image reports `trial` clear while uncommitted: before the strap
    // after a failed trial, the next run found it "committed". Under both
    // ROM models the same end: the trial image ran S3 with page 0 erased,
    // so it set the empty flag, and the strap's reset starts the ROM even
    // if the ROM cleared the flag before the Go.
    for (both_roms) |rom_clears_empty| {
        errdefer printRom(rom_clears_empty);
        var chip = blankChip(.{ .fw = want, .reports_trial = false }, rom_clears_empty);
        var u = updater(&chip);
        try testing.expectError(error.TrialNotTrial, u.run(&test_image, want));
        try expectStrapAt(&chip, try at(&chip, .go_trial, 0));
        try testing.expect(chip.committed == null and chip.running == .bootloader);

        try testing.expectError(error.TrialNotTrial, u.run(&test_image, want));
        try testing.expectEqual(@as(usize, 2), chip.count(.stage));
        try testing.expectEqual(@as(usize, 0), chip.commits);
        // The second strap, too, ends in the ROM: a reset into the ROM that
        // cleared the flag (and an S3 that did not set it again) would
        // lock the core here.
        try testing.expect(chip.committed == null and chip.running == .bootloader);

        // The same image after goTrial's acknowledge was lost.
        var chip2 = blankChip(.{ .fw = want, .reports_trial = false }, rom_clears_empty);
        chip2.fail = .go_trial;
        chip2.fail_late = true;
        var second = updater(&chip2);
        try testing.expectError(error.Injected, second.run(&test_image, want));
        try testing.expect(chip2.running == .bootloader);
        chip2.fail = null;
        try testing.expectError(error.TrialNotTrial, second.run(&test_image, want));
        try testing.expectEqual(@as(usize, 2), chip2.count(.stage));
        try testing.expect(chip2.committed == null and chip2.running == .bootloader);
    }
}

test "a run passes the host's stage and trial tokens through to the commit unchanged" {
    // A first run fails at the trial; the second, with a fixed image,
    // must commit with its own tokens, not the first run's.
    var chip = Chip{ .new_image = .{ .fw = want, .reports_trial = false } };
    var u = updater(&chip);
    try testing.expectError(error.TrialNotTrial, u.run(&test_image, want));
    const first_staged = chip.issued_staged.?;
    try testing.expectEqual(@as(?FakeBoot.Staged, first_staged), chip.trial_got);
    try testing.expectEqual(@as(?FakeBoot.Tried, null), chip.commit_got);

    chip.new_image.reports_trial = true;
    try testing.expectEqual(Outcome.updated, try u.run(&test_image, want));
    const staged = chip.issued_staged.?;
    const tried = chip.issued_tried.?;
    try testing.expect(staged.serial != first_staged.serial);
    try testing.expectEqual(@as(?FakeBoot.Staged, staged), chip.trial_got); // goTrial got stage's token
    try testing.expectEqual(staged.serial, tried.of_staged);
    try testing.expectEqual(@as(?FakeBoot.Tried, tried), chip.commit_got); // commit got goTrial's token
}

test "a commit that fails after writing the base is uncommitted again, and commit's error is returned" {
    var chip = Chip{ .new_image = .{ .fw = want }, .fail = .commit, .fail_late = true };
    var u = updater(&chip);
    try testing.expectError(error.Injected, u.run(&test_image, want));
    try testing.expectEqual(Step.commit, u.step());
    const c = try at(&chip, .commit, 0);
    try testing.expectEqual(c + 1, try at(&chip, .uncommit, c)); // straight after, no strap: the bootloader still runs
    try testing.expectEqual(@as(usize, 0), chip.count(.strap_on));
    try testing.expect(chip.committed == null and chip.running == .bootloader);
    try testing.expectEqual(@as(usize, 0), chip.count(.start));
}

test "a commit failure is returned even when the uncommit after it fails too" {
    var chip = Chip{ .new_image = .{ .fw = want }, .fail = .commit, .fail_late = true, .fail_uncommit = true };
    var u = updater(&chip);
    try testing.expectError(error.Injected, u.run(&test_image, want)); // commit's, not error.UncommitFailed
    try testing.expectEqual(@as(usize, 1), chip.count(.uncommit));
    try testing.expectEqual(@as(usize, 0), chip.count(.start));
}

test "a refused Go whose first Get IDs are lost: the 50-try wait finds the bootloader, which uncommits, with no strap" {
    var chip = Chip{ .new_image = .{ .fw = want }, .fail = .start, .lose_get_ids_after_start = 3 };
    var u = updater(&chip);
    try testing.expectError(error.Injected, u.run(&test_image, want));
    try testing.expectEqual(Step.start, u.step());
    const s = try at(&chip, .start, 0);
    try testing.expectEqual(s + 1 + 4, try at(&chip, .uncommit, s)); // 3 lost Get IDs, the 4th answers
    try testing.expectEqual(@as(usize, 0), chip.count(.strap_on));
    try testing.expect(chip.committed == null and chip.running == .bootloader);
}

test "a Go that happened while the image hung: no bootloader, no frames, so the strap, and the uncommit" {
    // The acknowledge is lost, and the image never gets to S3 from the
    // base. The same end under both ROM models, by two ways:
    // - the ROM left the flag set: it is still set from the trial image's
    //   S4, so the strap's reset starts the ROM, and the updater's
    //   uncommit erases page 0;
    // - the ROM cleared it: the reset starts the committed image, whose own
    //   strap check (S2) uncommits it (S4), and the updater's uncommit
    //   then finds page 0 erased already.
    for (both_roms) |rom_clears_empty| {
        errdefer printRom(rom_clears_empty);
        var chip = blankChip(.{ .fw = want, .runs_from_base = false }, rom_clears_empty);
        chip.fail = .start;
        chip.fail_late = true;
        var u = updater(&chip);
        try testing.expectError(error.Injected, u.run(&test_image, want)); // start's own error
        try testing.expectEqual(Step.start, u.step());
        const s = try at(&chip, .start, 0);
        const strap = try at(&chip, .strap_on, s);
        try testing.expectEqual(@as(usize, boot_attempts), strap - s - 1); // the 50-try wait came first
        try expectStrapAt(&chip, s);
        _ = try at(&chip, .uncommit, strap);
        try testing.expect(chip.committed == null and chip.running == .bootloader);
    }
}

test "frames of another firmware after a failed start command count as no start: the strap, the uncommit, start's error" {
    // The Go happened and an image answers, but not as the committed one.
    // It ran S3 from the base, so the flag is clear under both ROM models,
    // and its own strap check uncommits it.
    for (both_roms) |rom_clears_empty| {
        errdefer printRom(rom_clears_empty);
        var chip = blankChip(.{ .fw = want, .odd_start = .base, .odd_fw = want + 1 }, rom_clears_empty);
        chip.fail = .start;
        chip.fail_late = true;
        var u = updater(&chip);
        try testing.expectError(error.Injected, u.run(&test_image, want));
        try testing.expectEqual(Step.start, u.step());
        const strap = try at(&chip, .strap_on, try at(&chip, .start, 0));
        try expectStrapAt(&chip, strap);
        _ = try at(&chip, .uncommit, strap);
        try testing.expect(chip.committed == null and chip.running == .bootloader);
    }
}

// The ROM model decides these two. The chip starts committed (flag clear),
// so only the S4s of the update (the old image's, then the trial image's)
// set the flag; the new image never runs S3 from the base and ignores its
// strap. So:
// - if the ROM has left the flag set (not known for the C031), the strap's
//   reset starts the ROM and the updater's uncommit leaves the chip
//   uncommitted;
// - if the ROM cleared it, the commit leaves it clear, the strap's reset
//   starts the committed image, which ignores the strap and runs: no
//   bootloader answers, nothing is uncommitted, and the chip stays
//   committed to an image that never answered from the base (the Limits'
//   `StartSilent` case). Its start from a reset is all that works.

test "if the ROM has left the flag set (not known for the C031), an image that neither starts from the base nor honours its strap is uncommitted through the ROM; if the ROM cleared it, it runs from the strap's reset, committed" {
    for (both_roms) |rom_clears_empty| {
        errdefer printRom(rom_clears_empty);
        var chip = appChipUnder(.{ .fw = want - 1 }, rom_clears_empty);
        chip.new_image = .{ .fw = want, .runs_from_base = false, .honours_strap = false };
        var u = updater(&chip);
        try testing.expectError(error.StartSilent, u.run(&test_image, want));
        const strap = try at(&chip, .strap_on, try at(&chip, .start, 0));
        if (rom_clears_empty) {
            try testing.expectEqual(@as(?usize, null), chip.firstIndex(.uncommit, strap));
            try testing.expectEqual(@as(?Image, chip.new_image), chip.committed);
            try testing.expect(chip.running == .app and chip.running.app.started_as == .reset);
        } else {
            _ = try at(&chip, .uncommit, strap);
            try testing.expect(chip.committed == null and chip.running == .bootloader);
        }
    }
}

test "if the ROM has left the flag set (not known for the C031), the same image after a Go whose acknowledge was lost is uncommitted through the ROM too; if the ROM cleared it, it runs from the strap's reset, committed" {
    for (both_roms) |rom_clears_empty| {
        errdefer printRom(rom_clears_empty);
        var chip = appChipUnder(.{ .fw = want - 1 }, rom_clears_empty);
        chip.new_image = .{ .fw = want, .runs_from_base = false, .honours_strap = false };
        chip.fail = .start;
        chip.fail_late = true;
        var u = updater(&chip);
        try testing.expectError(error.Injected, u.run(&test_image, want));
        const strap = try at(&chip, .strap_on, try at(&chip, .start, 0));
        if (rom_clears_empty) {
            try testing.expectEqual(@as(?usize, null), chip.firstIndex(.uncommit, strap));
            try testing.expectEqual(@as(?Image, chip.new_image), chip.committed);
            try testing.expect(chip.running == .app and chip.running.app.started_as == .reset);
        } else {
            _ = try at(&chip, .uncommit, strap);
            try testing.expect(chip.committed == null and chip.running == .bootloader);
        }
    }
}

test "known limit: a Go whose acknowledge was lost while the image started leaves it committed and unproven, and a later run reports up_to_date" {
    var chip = Chip{ .new_image = .{ .fw = want }, .fail = .start, .fail_late = true };
    var u = updater(&chip);
    try testing.expectError(error.Injected, u.run(&test_image, want));
    try testing.expectEqual(Step.start, u.step());
    try testing.expectEqual(@as(usize, 0), chip.count(.uncommit)); // no Get ID answers: the image runs
    try testing.expectEqual(@as(?Image, chip.new_image), chip.committed);
    try testing.expect(chip.running == .app);
    try testing.expectEqual(@as(usize, 0), chip.count(.cmd_clear_booted) + chip.count(.reset_pulse)); // neither proof ran

    chip.fail = null;
    try testing.expectEqual(Outcome.up_to_date, try u.run(&test_image, want));
    try testing.expectEqual(@as(usize, 0), chip.count(.reset_pulse));
}

test "an error from uncommit never replaces the step's error" {
    for (both_roms) |rom_clears_empty| {
        errdefer printRom(rom_clears_empty);
        var chip = blankChip(.{ .fw = want, .runs_from_base = false }, rom_clears_empty);
        chip.fail_uncommit = true;
        var u = updater(&chip);
        try testing.expectError(error.StartSilent, u.run(&test_image, want));
        try testing.expectEqual(@as(usize, 1), chip.count(.uncommit));
        try testing.expect(chip.running == .bootloader);
        // The ends differ. Flag left set: the strap's reset starts the ROM
        // and the failed uncommit leaves the chip committed in its ROM
        // (the review's state E). Flag cleared by the ROM: the reset starts
        // the committed image, whose strap check uncommits it before the
        // updater's uncommit fails.
        if (rom_clears_empty) {
            try testing.expectEqual(@as(?Image, null), chip.committed);
        } else {
            try testing.expectEqual(@as(?Image, chip.new_image), chip.committed);
        }

        // A refused Go: no reset at all, the same end under both.
        var chip2 = blankChip(.{ .fw = want }, rom_clears_empty);
        chip2.fail = .start;
        chip2.fail_uncommit = true;
        var second = updater(&chip2);
        try testing.expectError(error.Injected, second.run(&test_image, want)); // the start's, not error.UncommitFailed
        try testing.expectEqual(@as(usize, 1), chip2.count(.uncommit));
        try testing.expect(chip2.running == .bootloader);
        try testing.expectEqual(@as(?Image, chip2.new_image), chip2.committed);
    }
}

test "after start's error, an error from the uncommit that follows the strap never replaces start's error" {
    // The Go happened (its acknowledge lost) and the image hung before S3:
    // no bootloader, no frames, so the strap entry, the bootloader comes,
    // and its uncommit fails. Under both ROM models the strap reaches the
    // ROM (through the flag, or through the image's own strap check).
    for (both_roms) |rom_clears_empty| {
        errdefer printRom(rom_clears_empty);
        var chip = blankChip(.{ .fw = want, .runs_from_base = false }, rom_clears_empty);
        chip.fail = .start;
        chip.fail_late = true;
        chip.fail_uncommit = true;
        var u = updater(&chip);
        try testing.expectError(error.Injected, u.run(&test_image, want)); // start's, not error.UncommitFailed
        try testing.expectEqual(Step.start, u.step());
        const strap = try at(&chip, .strap_on, try at(&chip, .start, 0));
        _ = try at(&chip, .uncommit, strap);
        try testing.expectEqual(@as(usize, 1), chip.count(.uncommit));
    }
}

test "after start's error, frames with trial set or booted clear are no fresh start: the strap, the uncommit, start's error" {
    // The check after a failed Go is the `start` step's own: the wanted
    // `fw`, `trial` clear and `booted` set. A wrong `fw` is pinned above;
    // these two pin the other two conditions. Each image ran S3 from the
    // base, so under both ROM models its own strap check uncommits it.
    for ([_]Image{
        .{ .fw = want, .odd_start = .base, .odd_trial = true },
        .{ .fw = want, .sets_booted = false },
    }) |image| {
        for (both_roms) |rom_clears_empty| {
            errdefer printRom(rom_clears_empty);
            var chip = blankChip(image, rom_clears_empty);
            chip.fail = .start;
            chip.fail_late = true;
            var u = updater(&chip);
            try testing.expectError(error.Injected, u.run(&test_image, want));
            try testing.expectEqual(Step.start, u.step());
            const strap = try at(&chip, .strap_on, try at(&chip, .start, 0));
            try expectStrapAt(&chip, strap);
            _ = try at(&chip, .uncommit, strap);
            try testing.expect(chip.committed == null and chip.running == .bootloader);
        }
    }
}

test "the trial is classified in order: a wrong firmware before a missing trial flag" {
    var chip = Chip{ .new_image = .{ .fw = want + 1, .reports_trial = false } };
    var u = updater(&chip);
    try testing.expectError(error.TrialWrongFirmware, u.run(&test_image, want));
    try testing.expectEqual(@as(usize, 0), chip.commits);
}

test "a silent trial takes 21 reads and 300 ms, no more" {
    var chip = Chip{ .new_image = .{ .fw = want, .answers = false } };
    var u = updater(&chip);
    try testing.expectError(error.TrialSilent, u.run(&test_image, want));
    const at_go = chip.entries()[(try at(&chip, .go_trial, 0))].ms;
    const at_strap = chip.entries()[(try at(&chip, .strap_on, 0))].ms;
    try testing.expectEqual(@as(usize, find_reads + 1 + app_more_reads), chip.reads); // find's, then the trial's
    try testing.expectEqual(@as(u64, app_settle_ms + app_more_reads * app_read_gap_ms), at_strap - at_go);
}

test "one or two bad frames in the trial are tolerated; 3 accepted in a row are needed" {
    var chip = Chip{ .new_image = .{ .fw = want } };
    var u = updater(&chip);
    // A blank chip: find's 3 reads find nothing anyway, so the last 2
    // failures land in trial_start.
    chip.fail_reads = 3 + 2;
    try testing.expectEqual(Outcome.updated, try u.run(&test_image, want));
    try testing.expectEqual(@as(usize, 1), chip.commits);
    try expectCommitOnlyAfterTrial(&chip);

    // Every third read failing never gives 3 accepted frames in a row.
    var chip2 = Chip{ .new_image = .{ .fw = want }, .read_fails_every = 3 };
    var second = updater(&chip2);
    try testing.expectError(error.TrialSilent, second.run(&test_image, want));
    try testing.expectEqual(@as(usize, 0), chip2.commits);
}

test "an application that ignores the command in the trial gives TrialNoReturn after 50 Get IDs, the strap, and no commit" {
    // The same end under both ROM models: the trial image set the flag
    // (S3, page 0 erased), so the strap's reset starts the ROM.
    for (both_roms) |rom_clears_empty| {
        errdefer printRom(rom_clears_empty);
        var chip = blankChip(.{ .fw = want, .obeys_command = false }, rom_clears_empty);
        var u = updater(&chip);
        try testing.expectError(error.TrialNoReturn, u.run(&test_image, want));
        const cmd = (try at(&chip, .cmd_enter, 0));
        const strap = (try at(&chip, .strap_on, cmd));
        try testing.expectEqual(@as(usize, boot_attempts), strap - cmd - 1); // only Get IDs between
        try expectStrapAt(&chip, cmd);
        try testing.expectEqual(@as(usize, 0), chip.commits);
        try testing.expect(chip.committed == null and chip.running == .bootloader); // the trial image is not left running
    }
}

test "dead after the reset: the strap sequence, then DeadAfterReset, uncommitted again when the strap works" {
    // The same end under both ROM models: the image cleared the flag at
    // `start` (S3), and its own strap check uncommits it.
    for (both_roms) |rom_clears_empty| {
        errdefer printRom(rom_clears_empty);
        var chip = blankChip(.{ .fw = want, .starts_from_reset = false }, rom_clears_empty);
        var u = updater(&chip);
        try testing.expectError(error.DeadAfterReset, u.run(&test_image, want));
        try testing.expectEqual(Step.reset_proof, u.step());
        try expectCommitOnlyAfterTrial(&chip);
        const pulse = (try at(&chip, .reset_pulse, 0)); // reset_proof's own pulse
        // No frames: one Get ID first, which nothing answers, then the strap.
        try testing.expectEqual(Call.product_id, chip.entries()[pulse + 1].call);
        try testing.expectEqual(pulse + 2, try at(&chip, .strap_on, pulse));
        try expectStrapAt(&chip, pulse + 1);
        try testing.expect(chip.committed == null);
        try testing.expect(chip.running == .bootloader);
        _ = try at(&chip, .uncommit, pulse + 1); // the bootloader came, so page 0 is erased through it too
    }
}

/// The run of a blank chip whose software-cleared empty flag does not
/// survive `reset_proof`'s pulse, so the ROM answers instead of the image.
fn resetIntoRomChip(rom_clears_empty: bool) Chip {
    var chip = blankChip(.{ .fw = want }, rom_clears_empty);
    chip.soft_flag_lost_at_reset = true;
    return chip;
}

test "a reset proof that finds the bootloader instead of the image: one Get ID, the tried image started again, left committed, ResetIntoBootloader" {
    // The same end under both ROM models: the image is the tried one and
    // intact, so it is not uncommitted; Go to the base starts it again.
    for (both_roms) |rom_clears_empty| {
        errdefer printRom(rom_clears_empty);
        var chip = resetIntoRomChip(rom_clears_empty);
        var u = updater(&chip);
        try testing.expectError(error.ResetIntoBootloader, u.run(&test_image, want));
        try testing.expectEqual(Step.reset_proof, u.step());
        try expectCommitOnlyAfterTrial(&chip);
        try testing.expectEqual(@as(usize, 1), chip.commits);
        const pulse = try at(&chip, .reset_pulse, 0);
        // After the pulse: one Get ID, which the ROM answers, then the Go
        // to the base, and nothing else: no strap, no uncommit.
        try testing.expectEqual(pulse + 3, chip.log_len);
        try testing.expectEqual(Call.product_id, chip.entries()[pulse + 1].call);
        try testing.expectEqual(Call.start, chip.entries()[pulse + 2].call);
        try testing.expectEqual(@as(usize, 0), chip.count(.uncommit) + chip.count(.strap_on));
        try testing.expectEqual(@as(?Image, chip.new_image), chip.committed);
        try testing.expect(chip.running == .app and chip.running.app.started_as == .base);

        // A later run finds the committed image and reports up_to_date.
        try testing.expectEqual(Outcome.up_to_date, try u.run(&test_image, want));
    }
}

test "a reset proof that finds the bootloader, and whose Go then fails: ResetIntoBootloader all the same, committed in the ROM, nothing uncommitted" {
    for (both_roms) |rom_clears_empty| {
        errdefer printRom(rom_clears_empty);
        var chip = resetIntoRomChip(rom_clears_empty);
        chip.fail = .start;
        chip.fail_skip = 1; // the `start` step's Go goes through; reset_proof's fails
        var u = updater(&chip);
        try testing.expectError(error.ResetIntoBootloader, u.run(&test_image, want));
        try expectCommitOnlyAfterTrial(&chip);
        try testing.expectEqual(@as(usize, 2), chip.count(.start));
        try testing.expectEqual(@as(usize, 0), chip.count(.uncommit) + chip.count(.strap_on));
        // Committed, in the ROM: a power cycle starts the image (page 0 is
        // programmed, so power-on clears the flag).
        try testing.expectEqual(@as(?Image, chip.new_image), chip.committed);
        try testing.expect(chip.running == .bootloader);
    }
}

test "a reset proof whose one Get ID is lost: the strap and the uncommit, DeadAfterReset, uncommitted (the safe direction)" {
    // The chip is in its ROM, but the Get ID that would tell is lost on
    // the bus: the old path follows, and a good image is erased.
    for (both_roms) |rom_clears_empty| {
        errdefer printRom(rom_clears_empty);
        var chip = resetIntoRomChip(rom_clears_empty);
        chip.lose_get_ids_after_start = 1; // the first Get ID after `start`: reset_proof's
        var u = updater(&chip);
        try testing.expectError(error.DeadAfterReset, u.run(&test_image, want));
        try expectCommitOnlyAfterTrial(&chip);
        const pulse = try at(&chip, .reset_pulse, 0);
        try expectStrapAt(&chip, pulse + 1);
        _ = try at(&chip, .uncommit, pulse + 1);
        try testing.expect(chip.committed == null and chip.running == .bootloader);
    }
}

test "a reset line that does nothing gives ResetNotSeen, never updated, and no strap" {
    var chip = Chip{ .new_image = .{ .fw = want }, .reset_line_works = false };
    var u = updater(&chip);
    try testing.expectError(error.ResetNotSeen, u.run(&test_image, want));
    try testing.expectEqual(Step.reset_proof, u.step());
    try testing.expectEqual(@as(usize, 0), chip.count(.strap_on));
    try testing.expectEqual(@as(?Image, chip.new_image), chip.committed); // still the image that passed the trial
}

test "an application that keeps booted set gives StartNotCleared and no strap" {
    var chip = Chip{ .new_image = .{ .fw = want, .clears_booted = false } };
    var u = updater(&chip);
    try testing.expectError(error.StartNotCleared, u.run(&test_image, want));
    try testing.expectEqual(Step.start, u.step());
    try testing.expectEqual(@as(usize, 0), chip.count(.strap_on));
    try testing.expectEqual(@as(usize, 0), chip.count(.reset_pulse));
    try testing.expectEqual(@as(usize, 1 + app_more_reads), chip.count(.cmd_clear_booted)); // sent again after each frame still booted
}

test "a lost clear_booted write is sent again" {
    var chip = Chip{ .new_image = .{ .fw = want }, .drop_clear_writes = 1 };
    var u = updater(&chip);
    try testing.expectEqual(Outcome.updated, try u.run(&test_image, want));
    try testing.expectEqual(@as(usize, 2), chip.count(.cmd_clear_booted));
}

test "after StartSilent the strap follows, the bootloader uncommits, and StartSilent is returned whether or not the bootloader shows up" {
    for (both_roms) |rom_clears_empty| {
        errdefer printRom(rom_clears_empty);
        // The image never got to S3 from the base. The same end under both
        // ROM models, by two ways: if the ROM has left the flag set (not
        // known for the C031), it is still set from the trial, the strap's
        // reset starts the ROM, the image's strap check never runs, and
        // only the uncommit through the bootloader keeps the chip from
        // being left committed to it; if the ROM cleared it, the reset
        // starts the image, whose own strap check uncommits it.
        var chip = blankChip(.{ .fw = want, .runs_from_base = false }, rom_clears_empty);
        var u = updater(&chip);
        try testing.expectError(error.StartSilent, u.run(&test_image, want));
        const strap = try at(&chip, .strap_on, try at(&chip, .start, 0));
        try expectStrapAt(&chip, strap);
        _ = try at(&chip, .uncommit, strap);
        try testing.expect(chip.committed == null and chip.running == .bootloader);

        // The image ran S3 from the base (the flag is clear under both)
        // but answers wrongly, and neither its strap check nor its start
        // from reset works: no bootloader, the same error.
        var chip2 = blankChip(.{ .fw = want, .odd_start = .base, .odd_fw = want + 1, .honours_strap = false, .starts_from_reset = false }, rom_clears_empty);
        var second = updater(&chip2);
        try testing.expectError(error.StartSilent, second.run(&test_image, want));
        try expectStrapAt(&chip2, (try at(&chip2, .start, 0)));
        try testing.expectEqual(@as(usize, boot_attempts), chip2.count(.product_id) - 2); // find and trial_return took one each
        try testing.expectEqual(@as(usize, 0), chip2.count(.uncommit));
        try testing.expect(chip2.running == .off);
    }
}

test "frames of another firmware after the start count as no frames: StartSilent and the strap" {
    for (both_roms) |rom_clears_empty| {
        errdefer printRom(rom_clears_empty);
        var chip = blankChip(.{ .fw = want, .odd_start = .base, .odd_fw = want + 1 }, rom_clears_empty);
        var u = updater(&chip);
        try testing.expectError(error.StartSilent, u.run(&test_image, want));
        try expectStrapAt(&chip, (try at(&chip, .start, 0)));
        try testing.expectEqual(@as(usize, 0), chip.count(.cmd_clear_booted));
        try testing.expectEqual(@as(usize, 1), chip.count(.uncommit));
        try testing.expect(chip.committed == null);
    }
}

/// A run that fails at `start` with `StartSilent`, the strap and the
/// uncommit, and wrote `0x01` `clears` times; under both ROM models, from
/// a blank chip that runs `image`. Every image here ran S3 from the base,
/// so the flag is clear under both, and its own strap check uncommits it.
fn expectStartSilent(image: Image, clears: usize) !void {
    for (both_roms) |rom_clears_empty| {
        errdefer printRom(rom_clears_empty);
        var chip = blankChip(image, rom_clears_empty);
        var u = updater(&chip);
        try testing.expectError(error.StartSilent, u.run(&test_image, want));
        try testing.expectEqual(Step.start, u.step());
        try testing.expectEqual(clears, chip.count(.cmd_clear_booted));
        try expectStrapAt(&chip, try at(&chip, .start, 0));
        _ = try at(&chip, .uncommit, try at(&chip, .strap_on, 0));
        try testing.expect(chip.committed == null and chip.running == .bootloader);
        try testing.expectEqual(@as(usize, 1), chip.count(.reset_pulse)); // only the strap's own pulse
    }
}

test "start frames that stop after the first 3 give StartSilent, the strap and the uncommit" {
    try expectStartSilent(.{ .fw = want, .odd_start = .base, .odd_from = 3, .odd_silent = true }, 1);
}

test "after the clear, start frames of another firmware or with trial set are no frames: StartSilent" {
    try expectStartSilent(.{ .fw = want, .odd_start = .base, .odd_from = 3, .odd_fw = want + 1 }, 1);
    try expectStartSilent(.{ .fw = want, .odd_start = .base, .odd_from = 3, .odd_trial = true }, 1);
}

test "start frames with trial set are refused before any 0x01" {
    try expectStartSilent(.{ .fw = want, .odd_start = .base, .odd_trial = true }, 0);
}

test "an image that does not set booted at its start gives StartSilent before any 0x01, not ResetNotSeen later" {
    // `expectStartSilent` also checks that the strap's pulse is the only one.
    try expectStartSilent(.{ .fw = want, .sets_booted = false }, 0);
}

test "after the reset, frames with trial set or of another firmware give DeadAfterReset" {
    for ([_]Image{
        .{ .fw = want, .odd_start = .reset, .odd_trial = true },
        .{ .fw = want, .odd_start = .reset, .odd_fw = want + 1 },
    }) |image| {
        // The image ran from the reset, so the flag is clear under both
        // ROM models, and its own strap check uncommits it.
        for (both_roms) |rom_clears_empty| {
            errdefer printRom(rom_clears_empty);
            var chip = blankChip(image, rom_clears_empty);
            var u = updater(&chip);
            try testing.expectError(error.DeadAfterReset, u.run(&test_image, want));
            try testing.expectEqual(Step.reset_proof, u.step());
            const pulse = try at(&chip, .reset_pulse, 0);
            try expectStrapAt(&chip, pulse + 1);
            _ = try at(&chip, .uncommit, pulse + 1);
            try testing.expect(chip.committed == null and chip.running == .bootloader);
        }
    }
}

test "a trial whose later frames differ from its first is refused" {
    var chip = Chip{ .new_image = .{ .fw = want, .odd_start = .trial, .odd_from = 1, .odd_fw = want + 1 } };
    var u = updater(&chip);
    try testing.expectError(error.TrialWrongFirmware, u.run(&test_image, want));
    try testing.expectEqual(@as(usize, 0), chip.commits);

    var chip2 = Chip{ .new_image = .{ .fw = want, .odd_start = .trial, .odd_from = 2, .odd_trial = false } };
    var second = updater(&chip2);
    try testing.expectError(error.TrialNotTrial, second.run(&test_image, want));
    try testing.expectEqual(@as(usize, 0), chip2.commits);
}

test "probe only reads" {
    var app = appChip(.{ .fw = 9 });
    var ua = updater(&app);
    try testing.expectEqual(Presence{ .application = .{ .fw = 9, .trial = false } }, ua.probe());

    var blank = Chip{ .new_image = .{ .fw = want } };
    var ub = updater(&blank);
    try testing.expectEqual(Presence.bootloader, ub.probe());

    var dead = appChip(.{ .fw = 9, .answers = false });
    dead.running = .off;
    var ud = updater(&dead);
    try testing.expectEqual(Presence.nothing, ud.probe());

    for ([_]*const Chip{ &app, &blank, &dead }) |c| {
        for (c.entries()) |e| try testing.expectEqual(Call.product_id, e.call);
    }
}

test "one or two Get IDs lost while finding do not take a bootloader for absent: no strap pulse, under both ROM models" {
    // A strap pulse here would meet an uncommitted chip in its ROM: if the
    // ROM cleared the empty flag, the core would lock until a power cycle.
    for (both_roms) |rom_clears_empty| {
        errdefer printRom(rom_clears_empty);
        for ([_]usize{ 1, 2 }) |lost| {
            errdefer std.debug.print("Get IDs lost: {d}\n", .{lost});
            var chip = blankChip(.{ .fw = want }, rom_clears_empty);
            chip.get_ids_to_lose = lost;
            var u = updater(&chip);
            try testing.expectEqual(Outcome.updated, try u.run(&test_image, want));
            try testing.expectEqual(@as(usize, 0), chip.count(.strap_on));
            try testing.expectEqual(@as(usize, 1), chip.count(.reset_pulse)); // reset_proof's own
        }
    }
}

test "find asks for the bootloader 3 times, 20 ms apart, before it concludes that nothing answers" {
    var chip = blankChip(.{ .fw = want }, false);
    chip.get_ids_to_lose = 3;
    var u = updater(&chip);
    try testing.expectEqual(Presence.nothing, u.probe());
    try testing.expectEqual(@as(usize, 3), chip.count(.product_id));
    try testing.expectEqual(@as(usize, find_boot_attempts), chip.count(.product_id));
    // 3 frame reads 10 ms apart, then 3 Get IDs 20 ms apart.
    try testing.expectEqual(@as(u64, 2 * 10 + 2 * 20), chip.ms);
}

test "one failed read while finding does not take a working application for absent" {
    var chip = appChip(.{ .fw = want });
    chip.fail_reads = 2;
    var u = updater(&chip);
    try testing.expectEqual(Outcome.up_to_date, try u.run(&test_image, want));
    try testing.expectEqual(@as(usize, 0), chip.count(.strap_on));
}

test "a Boot and an Io passed as pointers work too" {
    var chip = Chip{ .new_image = .{ .fw = want } };
    var boot = FakeBoot{ .chip = &chip, .image = &test_image };
    var io = FakeIo{ .chip = &chip };
    var u = Updater(*FakeBoot, *FakeIo).init(&boot, &io);
    try testing.expectEqual(Outcome.updated, try u.run(&test_image, want));
    try testing.expectEqual(Step.done, u.step());
    try testing.expectEqual(@as(usize, 1), chip.commits);
    try expectCommitOnlyAfterTrial(&chip);
}
