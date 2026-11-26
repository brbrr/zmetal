//! A host for the STM32 ROM bootloader's I2C protocol (ST AN4221 Rev 5,
//! protocol v1.1), to program an STM32C031 from another microcontroller
//! through the C031's built-in bootloader. std only: it builds the frames
//! and reads the answers through an `Io`, and never touches hardware.
//!
//! ## What it guarantees
//!
//! A chip whose first 8 bytes of main flash read erased is *uncommitted*:
//! the C031 starts its ROM bootloader at power-on while they do ([BOOT]
//! B.1 pattern 11), so it is one power cycle away from being flashable.
//! A chip whose first 8 bytes are programmed is *committed* to the image
//! there. The file keeps rules H1 to H7 of the plan's "Never unflashable":
//!
//! - H1. It changes main flash and nothing else. Every write and erase is
//!   checked against `[flash_base, flash_base + flash_size)` before
//!   anything is sent (`error.OutsideFlash`). `Opcode` holds every command
//!   the file can send, and no protection or option-byte command is among
//!   them; a test scans this file for their opcodes. Reading is allowed
//!   anywhere, as it cannot change the chip.
//! - H2. `stage` looks before it erases: `checkImage` and Get ID.
//!   `checkImage` also refuses an image whose bytes 8 to the end of page 0
//!   are all 0xFF, so that page 0 reads non-blank after staging.
//! - H3. The first change `stage` makes is an erase of page 0 alone, read
//!   back as erased. From that moment on the chip is uncommitted.
//! - H4. `stage` writes the image from byte 8 on, and its first 8 bytes at
//!   the trial vector, the last 8 bytes of flash, and reads both back.
//! - H5. `goTrial` reads all of main flash back but its first 8 bytes,
//!   and sends Go to the trial vector only if it holds the image the token
//!   `stage` returned names, by length and CRC-32, and nothing more.
//! - H6. `commit` writes the first 8 bytes only after the checks below
//!   ("What `commit` proves") have passed, and reads the whole image back
//!   after that write, the last of an update.
//! - H7. The only public erase is `uncommit`: page 0 alone, read back as
//!   erased, or the mass erase instead, with the same check, when the
//!   bootloader answers the page list with NACK (0x1F, `error.Refused`).
//!   A bus error is never taken for that answer: it is returned, and no
//!   mass erase follows.
//! - There is no public write, no public Go but `goTrial` and `start`,
//!   and no one-call "erase, write, go". `stage`, `goTrial` and `commit`
//!   hand each other a token naming the image (`Staged`, `Tried`).
//!
//! ## What `commit` proves, and what it does not
//!
//! Before it writes the first 8 bytes, `commit` has shown that:
//!
//! - the image it was given is the one its `Tried` token names, by length
//!   and CRC-32; and just before its Go, `goTrial` had read back a chip
//!   that held that image (by the same length and CRC-32) and nothing
//!   more: every other byte of main flash up to the trial vector,
//!   the padding included, read erased. So the trial ran that image;
//! - page 0 reads erased, all of it. `stage` left image bytes there (H2),
//!   so something erased page 0 after `stage`;
//! - the image past page 0, and the trial vector, read back equal to the
//!   image it was given;
//! - page 0 from byte 8 on, written again, reads back equal to it.
//!
//! It cannot show:
//!
//! - That the trial ran and passed: that the image worked, and went back
//!   to the bootloader by itself. Only the caller sees that (the updater
//!   in `panel_update.zig` watches the image's frames, its version and its
//!   return). `commit` trusts its caller to have run the trial between
//!   `goTrial` and `commit`.
//! - Who erased page 0: the image on its way back to the bootloader, or
//!   `uncommit`. Committing an untried image through `uncommit` takes
//!   `stage`, `goTrial`, `uncommit` and `commit`, in that order: a
//!   deliberate act.
//! - Byte for byte, that bytes 8 to the end of page 0 are what the trial
//!   ran: those bytes were erased by then. The CRC-32 `goTrial` took of
//!   them stands in. Two images that differ only inside page 0 and share
//!   a CRC-32 are not told apart: about 1 in 2^32 by accident, accepted
//!   (a collision built on purpose is easy, as CRC-32 is linear). A token
//!   built by hand, which Zig cannot prevent, defeats the check too.
//! - That a token is used once. A `Tried` stays valid after `commit`:
//!   `commit`, `uncommit`, then `commit` with the same token commits the
//!   same tried image again. A caller that does not want that drops the
//!   token after `commit`.
//!
//! ## What it does not cover
//!
//! - A power cut during an erase of page 0 can leave a first word that is
//!   neither erased nor valid.
//! - A power cut during `commit`'s 8-byte write at the base can leave a
//!   chip committed to first 8 bytes that are not whole. The host sees it
//!   as a bus error, as the bootloader stops answering. A write that does
//!   complete but stores wrong bytes is another case: the read-back after
//!   it reports `error.VerifyFailed`, and the chip is committed. For all
//!   three, the SWD pads remain.
//! - An uncommitted chip comes back in its bootloader after a power cycle;
//!   after a reset only if the empty flag was set, as the scanner's own
//!   uncommit does ([BOOT] B.2: the flag is read at power-on).
//! - Untried on a C031:
//!   - Go to an address other than the base (the trial vector). AN4221
//!     section 2.5 confirms only that Go jumps to the word at the address
//!     plus 4. Of the stack pointer it says only that the bootloader
//!     "initializes the user application's main stack pointer", not from
//!     where. So the image loads its own stack pointer first thing in its
//!     reset handler (the scanner's does), which removes the dependency.
//!     If the Go is refused, `goTrial` fails with the chip uncommitted.
//!   - The page-list erase over I2C. As a summary of stm32flash ticket #98
//!     reports it (secondary), the single-frame form (count and page list
//!     in one frame, one checksum) failed over I2C, and the split form
//!     AN4221 shows, which this file sends, worked on an STM32F723 and an
//!     STM32L432. The doubt left is AN4221's own Figure 27 (device side):
//!     it shows no ACK after the page count, where its text, Figure 26 and
//!     both examples do. If the C0 follows Figure 27, the one-byte answer
//!     read after the count meets a bootloader still waiting for the page
//!     list, and what the host does depends on what comes back:
//!     - the address not acknowledged, or any other bus error: the bus's
//!       error (`Nack` on the Daisy), returned at once; nothing more is
//!       sent, no mass erase, and nothing was erased;
//!     - a byte other than ACK, NACK and BUSY: `error.UnexpectedByte`,
//!       the same;
//!     - BUSY: read again, up to the bound, then `error.Busy`, the same;
//!     - NACK (0x1F): `error.Refused`, taken as the bootloader refusing
//!       the page list; the host sends the mass erase (below);
//!     - ACK: the host sends the page list, as with Figure 26.
//!     In every case but ACK, `stage` (and `uncommit`) end before any
//!     write, with the first 8 bytes as they were or erased.
//!   - The mass-erase code, which is only the fall back when the page
//!     list is answered with NACK (`error.Refused`), never after a bus
//!     error.
//!
//! ## The interface
//!
//! `Io` is a type, or a pointer to one, that provides:
//!
//! - `pub const Error`: the bus's error set. Bus errors pass through under
//!   their own names; the only errors this file adds are those in `Error`.
//! - `write(self, address: u7, bytes: []const u8) Error!void`: one I2C
//!   write transaction (START, address, the bytes, STOP).
//! - `read(self, address: u7, rx: []u8) Error!void`: one plain I2C read
//!   transaction of `rx.len` bytes (START, address, the bytes, STOP).
//! - `delayMs(self, ms: u32) void`: a pause.
//!
//! Each `write` and `read` must return in bounded time, with an error if
//! need be: every bound in this file counts calls, so an `Io` that can
//! hang (on an SCL a confused bootloader holds low, say) makes them
//! meaningless. An `Io` over a real bus uses its own timeout.
//!
//! `Bootloader` holds the `Io` by value and its methods take `self` by
//! value, so an `Io` that is not a pointer takes `self` by value or as
//! `*const`.
//!
//! How the bootloader frames things (AN4221 section 1 and figures 6, 8,
//! 10, 24, 26; [BOOT] B.3): every step is its own transaction. The host
//! writes the command byte and its complement, then reads one byte for the
//! answer. An address is a write of four bytes, MSB first, and their XOR;
//! a data block is a write of N-1, the N bytes and the XOR of all of them;
//! each is followed by a one-byte read for the answer. What the bootloader
//! sends back (the product ID, memory contents) is one read of its full
//! length, never fewer than 8 bytes. Erase and write use the No-Stretch
//! commands, which answer BUSY while the flash works instead of holding
//! SCL low.
//!
//! Every wait for an answer is bounded. It reads one byte: ACK goes on,
//! NACK is `error.Refused`, BUSY is read again after 1 ms, at most 10 000
//! times for an erase and 1 000 times for any other answer, then
//! `error.Busy`; any other byte is `error.UnexpectedByte`. A read that
//! fails on the bus (no acknowledge of the address, say) is the bus's
//! error, under the bus's name: on the Daisy that name is `Nack`, which
//! is not this file's `Refused`.
//!
//! What the bounds add up to, for the largest C031 image (32 760 bytes),
//! when the bootloader answers BUSY up to the bound at every step: `stage`
//! about 803 s, `goTrial` about 389 s (it reads all of flash, whatever the
//! image's length), `commit` about 822 s; a whole update about 2 014 s, 34
//! minutes. That counts the 1 ms pauses only: the one-byte polls add about
//! 20 % at 100 kHz, about 40 minutes in all. `uncommit` takes at most
//! about 26 s, `start` about 2 s. A caller that wants a shorter limit sets
//! its own deadline, for example with an `Io` whose `read` fails once it
//! has passed.

const std = @import("std");

/// Where main flash starts on every STM32.
pub const flash_base: u32 = 0x0800_0000;

/// What the host needs to know about the chip it programs.
pub const Part = struct {
    /// The bootloader's 7-bit I2C address.
    address: u7,
    /// What Get ID must answer.
    product_id: u16,
    /// Main flash, from `flash_base`.
    flash_size: u32,
    /// The erase unit of main flash.
    page_size: u32,
    /// RAM, from 0x2000_0000. An image's initial stack pointer lies in it.
    ram_size: u32,
};

/// The STM32C031 ([BOOT] B.1, B.2): AN2606 Table 11 gives its bootloader's
/// I2C address, Table 190 its product ID; 32 KB of flash in 2 KB pages,
/// 12 KB of RAM.
pub const c031: Part = .{
    .address = 0x63, // the I2C address 0b1100011x, not an opcode
    .product_id = 0x453,
    .flash_size = 32 * 1024,
    .page_size = 2 * 1024,
    .ram_size = 12 * 1024,
};

pub const Error = error{
    /// The bootloader answered NACK (0x1F): it refused a command, an
    /// address or a block. A device that does not acknowledge its address
    /// is the bus's error, under the bus's name (`Nack` on the Daisy's
    /// `i2c_bus`), never this one.
    Refused,
    /// An answer that is none of ACK, NACK and BUSY, or a Get ID reply
    /// with another length.
    UnexpectedByte,
    /// The bootloader was still BUSY when the bound ran out.
    Busy,
    /// Get ID did not give the part's product ID.
    WrongProduct,
    /// Flash does not hold what it should: a read-back after a write in
    /// `stage` or `commit`, `commit`'s check of the image past page 0 and
    /// of the trial vector, or `goTrial`'s read-back (another image, or
    /// anything more than the staged one).
    VerifyFailed,
    /// A write or erase not wholly inside main flash. Nothing was sent.
    OutsideFlash,
    /// `checkImage`: the bytes cannot be a program for the part.
    NotAnImage,
    /// Flash that had to read erased did not.
    NotBlank,
    /// `commit` got an image other than the one its token was made for, or
    /// `goTrial` a token no image can have. Nothing was sent.
    NotTheStagedImage,
};

/// The length and CRC-32 of an image, carried from `stage` to `commit`.
const Seal = struct { len: usize, crc: u32 };

fn sealOf(image: []const u8) Seal {
    return .{ .len = image.len, .crc = std.hash.Crc32.hash(image) };
}

/// What `stage` hands to `goTrial`: the image it staged, by length and
/// CRC-32. Made by `stage` only. Zig cannot hide a field or make a value
/// unforgeable (an anonymous literal builds one), so this is a convention
/// for callers, not a lock: a token built by hand defeats the check it
/// carries.
pub const Staged = struct { seal: Seal };

/// What `goTrial` hands to `commit`: the image the trial ran, by length
/// and CRC-32, after `goTrial` found the chip holding that image and
/// nothing more just before the Go. Made by `goTrial` only, under the
/// same convention as `Staged`. It stays valid after `commit` (see the
/// file comment).
pub const Tried = struct { seal: Seal };

// Answers (AN4221 section 1).
const ack: u8 = 0x79;
const nack: u8 = 0x1F;
const busy: u8 = 0x76;

/// Every command this file can send, each with its complement (AN4221
/// Table 2). `command` takes nothing else, so no code path can send a
/// protection or option-byte command.
const Opcode = enum(u8) {
    get_id = 0x02,
    read_memory = 0x11,
    go = 0x21,
    write_no_stretch = 0x32,
    erase_no_stretch = 0x45,
};

/// The special erase code for a global mass erase (AN4221 section 2.13).
const mass_erase: u16 = 0xFFFF;
/// Get ID's N, the number of PID bytes less one (AN4221 section 2.3).
const get_id_count: u8 = 1;
/// The most bytes one Write Memory or Read Memory moves (AN4221 sections
/// 2.4, 2.12).
const max_block = 256;
/// On the STM32C0 a flash write starts at a multiple of 8 and is a
/// multiple of 8 long (AN2606 Table 7).
const write_align = 8;
/// What erased flash reads as, and what pads a write.
const erased: u8 = 0xFF;
/// The most pages one erase command takes (AN4221 section 2.13).
const max_erase_pages = 512;
/// Where RAM starts on every STM32.
const ram_base: u32 = 0x2000_0000;

/// Most one-byte reads while an erase answers BUSY.
const erase_busy_tries: u32 = 10_000;
/// Most one-byte reads while a write chunk answers BUSY.
const write_busy_tries: u32 = 1_000;
/// Most one-byte reads for any other answer. AN4221 has BUSY only at the
/// end of a No-Stretch command, so this bound only matters to a confused
/// bootloader.
const reply_busy_tries: u32 = 1_000;
/// The pause before reading again after BUSY.
const busy_poll_ms: u32 = 1;

/// One past the highest 32-bit address.
const address_space: u64 = 1 << 32;

/// Rule H2: whether `image` can be a program for `part`, judged without
/// touching the chip. `error.NotAnImage` unless:
///
/// - its length, padded to a multiple of 8, is at least 16 and at most
///   `flash_size - 8` (the last 8 bytes of flash are kept free);
/// - its initial stack pointer (bytes 0-3, little-endian) is above
///   0x2000_0000, at most 0x2000_0000 + `ram_size`, and a multiple of 4;
/// - its reset vector (bytes 4-7) is odd (Thumb) and inside
///   `[flash_base + 8, flash_base + image.len)`, the unpadded length;
/// - its bytes from 8 to the end of page 0 (or of the image, if shorter)
///   hold at least one byte other than 0xFF. `stage` writes them, so page 0
///   reads blank after staging only if something erased it since: that is
///   what `commit`'s blank-page proof rests on. An image that leaves page 0
///   blank would make that proof say nothing.
///
/// A Daisy image, an empty file or a text file fail. The smallest image
/// that can pass is 10 bytes.
pub fn checkImage(image: []const u8, part: Part) Error!void {
    if (image.len > part.flash_size) return error.NotAnImage;
    const padded = paddedLen(@intCast(image.len));
    if (padded < 2 * write_align or padded + write_align > part.flash_size) return error.NotAnImage;
    const sp = std.mem.readInt(u32, image[0..4], .little);
    if (sp <= ram_base or sp > @as(u64, ram_base) + part.ram_size or sp % 4 != 0) return error.NotAnImage;
    const reset = std.mem.readInt(u32, image[4..8], .little);
    if (reset % 2 == 0 or reset < flash_base + write_align or reset >= @as(u64, flash_base) + image.len) return error.NotAnImage;
    const page_end = @min(image.len, part.page_size);
    if (page_end <= write_align) return error.NotAnImage;
    for (image[write_align..page_end]) |b| {
        if (b != erased) break;
    } else return error.NotAnImage;
}

pub fn Bootloader(comptime Io: type) type {
    return struct {
        const Self = @This();

        /// The bus's errors.
        pub const BusError = switch (@typeInfo(Io)) {
            .pointer => |p| p.child.Error,
            else => Io.Error,
        };
        /// What a method can fail with: the bus's errors and `Error`.
        pub const Failure = Error || BusError;

        io: Io,
        part: Part,

        /// A host for the bootloader of `part` (`c031` for an STM32C031).
        /// A `part` whose page size is below 16 or not a multiple of 8, does not
        /// divide the flash size, gives fewer than 2 or more than 512
        /// pages, or whose flash runs past 4 GiB is a caller error,
        /// asserted here before anything can be sent.
        pub fn init(io: Io, part: Part) Self {
            std.debug.assert(partIsValid(part));
            return .{ .io = io, .part = part };
        }

        /// Get ID (AN4221 section 2.3, figure 6): command, ACK, then N and
        /// the two PID bytes in one read, then ACK.
        pub fn productId(self: Self) Failure!u16 {
            try self.command(.get_id);
            var rx: [3]u8 = undefined;
            try self.io.read(self.part.address, &rx);
            if (rx[0] != get_id_count) return error.UnexpectedByte;
            try self.waitAnswer(reply_busy_tries);
            return @as(u16, rx[1]) << 8 | rx[2];
        }

        /// Put `image` on the chip, leaving it uncommitted. In order:
        ///
        /// 1. H2: `checkImage` (`error.NotAnImage`, nothing sent); Get ID,
        ///    which must give the part's product ID (`error.WrongProduct`).
        ///    Nothing has changed yet.
        /// 2. H3: `erasePages` of the whole flash: page 0 alone first, read
        ///    back as erased (`error.NotBlank`), then the others.
        /// 3. H4: write the image from byte 8 on at `flash_base + 8` and
        ///    read it back; write its first 8 bytes at the trial vector,
        ///    the last 8 bytes of flash, and read them back
        ///    (`error.VerifyFailed`).
        ///
        /// It never writes the first 8 bytes of flash. From the moment page
        /// 0 reads erased (step 2) the chip is uncommitted, whatever happens
        /// next; a failure before that (`error.NotBlank`, say) leaves it as
        /// it was, committed if it was, and intact. It returns the `Staged`
        /// token for `goTrial`, which is next.
        ///
        /// Time: every wait is bounded (see the file comment). The bounds
        /// add up to about 3 s for every 256 bytes written and again for
        /// every 256 read back, plus under a minute: about 803 s (13.4
        /// minutes) for the largest image when the bootloader answers BUSY
        /// up to the bound at every step, pauses only; the one-byte polls
        /// add about 20 % at 100 kHz. A whole update (`stage`, `goTrial`,
        /// `commit`) takes about 34 minutes at the bounds, 40 with the
        /// polls: see the file comment.
        pub fn stage(self: Self, image: []const u8) Failure!Staged {
            try checkImage(image, self.part);
            if (try self.productId() != self.part.product_id) return error.WrongProduct;
            try self.erasePages(0, self.pageCount());
            try self.write(flash_base + write_align, image[write_align..]);
            try self.verify(flash_base + write_align, image[write_align..]);
            try self.write(trialVector(self.part), image[0..write_align]);
            try self.verify(trialVector(self.part), image[0..write_align]);
            return .{ .seal = sealOf(image) };
        }

        /// H5: Go to the trial vector (AN4221 section 2.5). The bootloader
        /// jumps to the word after it, the staged image's reset vector, so
        /// the image runs while its first 8 bytes, and with them the chip,
        /// stay uncommitted. AN4221 does not say where the stack pointer
        /// then comes from, so the image loads its own (see the file
        /// comment). The caller then watches it work and sends it back to
        /// the bootloader (the image erases page 0 to get there); `commit`
        /// is next.
        ///
        /// Before the Go it reads all of main flash back but the first 8
        /// bytes: the trial vector, then everything from byte 8 up to the
        /// trial vector. The image's bytes must have the token's length
        /// and CRC-32, and every other byte, the padding included, must
        /// read erased. Otherwise `error.VerifyFailed`, and no Go: the chip
        /// holds another image, or more than the staged one (a later
        /// `stage` of a longer image, say, or anything `stage`'s erase of
        /// the later pages left behind). So the `Tried` token it returns
        /// names the image this trial runs, short of a CRC-32 collision
        /// (see the file comment). A token whose length no image can have
        /// is `error.NotTheStagedImage`, nothing sent.
        ///
        /// Time: the read-back is always all of flash, 129 reads for a C031
        /// (the trial vector, then 128 up to it), each of three bounded
        /// answers, plus the Go's two: about 389 s (6.5 minutes) at the
        /// bounds, pauses only, 20 % more with the polls; about a second
        /// at 400 kHz when the bootloader answers at once.
        pub fn goTrial(self: Self, staged: Staged) Failure!Tried {
            const len = staged.seal.len;
            if (len <= write_align or len > self.part.flash_size - write_align) return error.NotTheStagedImage;
            const now = try self.readStagedSeal(len);
            if (now.crc != staged.seal.crc) return error.VerifyFailed;
            try self.go(trialVector(self.part));
            return .{ .seal = staged.seal };
        }

        /// `goTrial`'s read-back: all of main flash but its first 8 bytes.
        /// Returns the seal of the image of `len` bytes the chip holds as
        /// staged (its first 8 bytes at the trial vector, the rest from
        /// `flash_base + 8`), after checking that every other byte up to
        /// the trial vector, the padding included, reads erased
        /// (`error.VerifyFailed` otherwise). Every read is a whole multiple
        /// of 8 bytes.
        fn readStagedSeal(self: Self, len: usize) Failure!Seal {
            var crc = std.hash.Crc32.init();
            var buf: [max_block]u8 = undefined;
            const vector = trialVector(self.part);
            try self.readChunk(vector, buf[0..write_align]);
            crc.update(buf[0..write_align]);
            const end: usize = vector - flash_base; // a multiple of 8
            var offset: usize = write_align;
            while (offset < end) {
                const n = @min(end - offset, max_block); // a multiple of 8
                try self.readChunk(flash_base + @as(u32, @intCast(offset)), buf[0..n]);
                const in_image = if (offset < len) @min(len - offset, n) else 0;
                crc.update(buf[0..in_image]);
                for (buf[in_image..n]) |b| if (b != erased) return error.VerifyFailed;
                offset += n;
            }
            return .{ .len = len, .crc = crc.final() };
        }

        /// H6: commit the image `stage` put on the chip, after its trial.
        /// In order, each step only if the one before it passed:
        ///
        /// 1. `checkImage`, and `image` must be the one `tried` names, by
        ///    length and CRC-32 (`error.NotTheStagedImage`). Nothing sent.
        /// 2. Page 0 reads erased, all of it (`error.NotBlank`). `stage`
        ///    left image bytes there, so something erased it since: the
        ///    image on its way back to the bootloader, if the caller ran
        ///    the trial and did not `uncommit` meanwhile.
        /// 3. The image past page 0 and the trial vector read back equal
        ///    to `image` (`error.VerifyFailed`).
        /// 4. Write page 0 from byte 8 on, and read it back.
        /// 5. Write the first 8 bytes at `flash_base`, and read the whole
        ///    image back.
        ///
        /// Until step 5 the chip is uncommitted. Step 5's 8-byte write is
        /// the one operation during which a power cut can leave it
        /// committed to first 8 bytes that are not whole (seen here as a
        /// bus error). A write that completes with wrong bytes is found by
        /// the read-back after it: `error.VerifyFailed`, on a committed
        /// chip. What this proves and what it cannot is in the file
        /// comment.
        ///
        /// Time: bounded as `stage`: about 822 s (13.7 minutes) for the
        /// largest image at the bounds, pauses only, 20 % more with the
        /// polls. The whole update's figure is in the file comment.
        pub fn commit(self: Self, tried: Tried, image: []const u8) Failure!void {
            try checkImage(image, self.part);
            if (!std.meta.eql(sealOf(image), tried.seal)) return error.NotTheStagedImage;
            const page = self.part.page_size;
            try self.expectBlank(flash_base, page);
            if (image.len > page) try self.verify(flash_base + page, image[page..]);
            try self.verify(trialVector(self.part), image[0..write_align]);
            const page_end = @min(image.len, page);
            try self.write(flash_base + write_align, image[write_align..page_end]);
            try self.verify(flash_base + write_align, image[write_align..page_end]);
            try self.write(flash_base, image[0..write_align]);
            try self.verify(flash_base, image);
        }

        /// Rule H7: uncommit the chip. Erase page 0 alone and read its first
        /// 8 bytes back as erased (`error.NotBlank` otherwise); when the
        /// bootloader answers the page list with NACK (`error.Refused`), the
        /// mass erase instead, with the same check. A bus error is returned
        /// as it is, with no mass erase. The only public erase, and only
        /// ever towards an uncommitted chip: the updater calls it to clean
        /// up after a committed image fails to start, and then drops that
        /// image's `Tried` token, which would commit it again. Called between
        /// `goTrial` and `commit`, it stands in for the trial's own erase of
        /// page 0, which `commit` cannot tell apart: that takes `stage`,
        /// `goTrial`, `uncommit` and `commit` in that order, a deliberate
        /// act.
        pub fn uncommit(self: Self) Failure!void {
            try self.erasePages(0, 1);
        }

        /// Go to `flash_base` (AN4221 section 2.5): start the committed image.
        pub fn start(self: Self) Failure!void {
            try self.go(flash_base);
        }

        /// No-Stretch Erase of the whole flash by the mass erase code
        /// (AN4221 section 2.13): command, ACK, FF FF 00, then BUSY until
        /// ACK. Only `erasePageZero` calls it, as H3's fall back after a
        /// NACK to the page list.
        fn massErase(self: Self) Failure!void {
            try self.command(.erase_no_stretch);
            const hi: u8 = mass_erase >> 8;
            const lo: u8 = mass_erase & 0xFF;
            try self.io.write(self.part.address, &[3]u8{ hi, lo, hi ^ lo });
            try self.waitAnswer(erase_busy_tries);
        }

        /// Erase `count` pages of main flash from page `first`, by the
        /// page-list form of the No-Stretch Erase (AN4221 section 2.13,
        /// [BOOT] B.3): command, ACK; N-1 as two bytes MSB first and their
        /// XOR, ACK; the page numbers as two bytes each MSB first and the
        /// XOR of all of them, then BUSY until ACK.
        ///
        /// Not public: `uncommit` (page 0 alone) is the only public erase,
        /// and `stage` erases the whole flash through this function.
        ///
        /// `error.OutsideFlash`, with nothing sent, unless every page lies
        /// in main flash; `count` 0 sends nothing. And it keeps rule H3
        /// itself, so that no call can leave a chip committed to an image
        /// it has gutted:
        ///
        /// - A range that starts at page 0 erases page 0 alone first and
        ///   reads its first 8 bytes back as erased (`error.NotBlank`
        ///   otherwise, nothing else erased); only then the rest of the
        ///   range. If the bootloader answers that page list with NACK
        ///   (0x1F, to the page count or to the list), it erased nothing it
        ///   was asked to: the whole flash is mass-erased instead, with the
        ///   same check. Any other failure, a bus error at either answer
        ///   read included, is returned as it is, and nothing follows it.
        /// - A range that starts above page 0 first reads the first 8
        ///   bytes, and is refused with `error.NotBlank`, nothing erased,
        ///   while they are programmed.
        fn erasePages(self: Self, first: u16, count: u16) Failure!void {
            if (@as(u32, first) + count > self.pageCount()) return error.OutsideFlash;
            if (count == 0) return;
            if (first == 0) {
                if (try self.erasePageZero()) return; // the mass erase did them all
                if (count > 1) try self.erasePageList(1, count - 1);
            } else {
                try self.expectBlank(flash_base, write_align);
                try self.erasePageList(first, count);
            }
        }

        /// Rule H3: page 0 alone, then its first 8 bytes read back as
        /// erased; the mass erase when the bootloader answers the page list
        /// with NACK, and only then. True when the mass erase ran: every
        /// page is then erased.
        fn erasePageZero(self: Self) Failure!bool {
            var mass = false;
            self.sendPageList(0, 1) catch |e| switch (e) {
                error.PageListRefused => {
                    try self.massErase();
                    mass = true;
                },
                else => |other| return other,
            };
            try self.expectBlank(flash_base, write_align);
            return mass;
        }

        fn erasePageList(self: Self, first: u16, count: u16) Failure!void {
            self.sendPageList(first, count) catch |e| return switch (e) {
                error.PageListRefused => error.Refused,
                else => |other| other,
            };
        }

        /// One page-list erase. `error.PageListRefused` when the bootloader
        /// answers the page count or the page list with NACK (0x1F,
        /// `error.Refused`), and only then: a bus error at either answer
        /// read, a device that does not acknowledge its address included,
        /// is returned under its own name.
        fn sendPageList(self: Self, first: u16, count: u16) (Failure || error{PageListRefused})!void {
            std.debug.assert(count >= 1 and count <= max_erase_pages);
            try self.command(.erase_no_stretch);
            const n = count - 1;
            const hi: u8 = @intCast(n >> 8);
            const lo: u8 = @truncate(n);
            try self.io.write(self.part.address, &[3]u8{ hi, lo, hi ^ lo });
            self.waitAnswer(reply_busy_tries) catch |e| return if (e == error.Refused) error.PageListRefused else e;
            var list: [2 * max_erase_pages + 1]u8 = undefined;
            for (0..count) |i| std.mem.writeInt(u16, list[2 * i ..][0..2], @intCast(first + i), .big);
            const len = 2 * @as(usize, count);
            list[len] = xorAll(list[0..len]);
            try self.io.write(self.part.address, list[0 .. len + 1]);
            self.waitAnswer(erase_busy_tries) catch |e| return if (e == error.Refused) error.PageListRefused else e;
        }

        /// `error.NotBlank` unless `len` bytes from `addr` read erased.
        fn expectBlank(self: Self, addr: u32, len: usize) Failure!void {
            std.debug.assert(len % write_align == 0); // so every read is 8 bytes or more
            var got: [max_block]u8 = undefined;
            var offset: usize = 0;
            while (offset < len) {
                const n = @min(len - offset, max_block);
                try self.readChunk(addr + @as(u32, @intCast(offset)), got[0..n]);
                for (got[0..n]) |b| if (b != erased) return error.NotBlank;
                offset += n;
            }
        }

        fn pageCount(self: Self) u16 {
            return @intCast(self.part.flash_size / self.part.page_size);
        }

        /// No-Stretch Write Memory of `data` from `addr` (AN4221 section
        /// 2.12), in address order, in chunks of at most 256 bytes; the last
        /// chunk is padded with 0xFF to a multiple of 8. Each chunk is:
        /// command, ACK, address, ACK, data block, then BUSY until ACK.
        ///
        /// Not public: a write at `flash_base` commits the chip, so only
        /// `stage` and `commit` write. `error.OutsideFlash`, with nothing
        /// sent, unless all of `data`, padded, lies inside main flash (rule
        /// H1). `addr` must be a multiple of 8, and stays an assertion:
        /// only this file computes write addresses, and on the C0 a
        /// misaligned write fails and so does every write after it (AN2606
        /// Table 7). An empty `data` sends nothing.
        fn write(self: Self, addr: u32, data: []const u8) Failure!void {
            if (!insideFlash(self.part, addr, data.len)) return error.OutsideFlash;
            std.debug.assert(addr % write_align == 0);
            var block: [max_block]u8 = undefined;
            var frame: [max_block + 2]u8 = undefined;
            var offset: usize = 0;
            while (offset < data.len) {
                const n = @min(data.len - offset, max_block);
                const padded = n + (write_align - n % write_align) % write_align; // <= max_block
                @memcpy(block[0..n], data[offset..][0..n]);
                @memset(block[n..padded], erased);
                try self.command(.write_no_stretch);
                try self.sendAddress(addr + @as(u32, @intCast(offset)));
                try self.io.write(self.part.address, dataFrame(&frame, block[0..padded]));
                try self.waitAnswer(write_busy_tries);
                offset += n;
            }
        }

        /// Read Memory (AN4221 section 2.4, figure 8) of `rx.len` bytes from
        /// `addr`, at any address: reading cannot change the chip. In
        /// chunks of at most 256, each: command, ACK, address, ACK, N-1 and
        /// its complement, ACK, then the N bytes in one read. An empty `rx`
        /// sends nothing. A range that runs past 4 GiB is a caller error,
        /// asserted.
        ///
        /// It never asks for fewer than 8 bytes, as AN4221's "(0 < N ≤
        /// 255)" leaves a 1-byte read in doubt: a tail shorter than 8 is
        /// read as the last 8 bytes of the range, and a request shorter
        /// than 8 reads 8 from `addr` and keeps the first `rx.len`, so the
        /// 8 bytes from `addr` must then all be readable.
        pub fn readMemory(self: Self, addr: u32, rx: []u8) Failure!void {
            std.debug.assert(rx.len <= address_space - addr);
            var eight: [write_align]u8 = undefined;
            if (rx.len > 0 and rx.len < write_align) {
                std.debug.assert(write_align <= address_space - addr);
                try self.readChunk(addr, &eight);
                @memcpy(rx, eight[0..rx.len]);
                return;
            }
            var offset: usize = 0;
            while (offset < rx.len) {
                const n = @min(rx.len - offset, max_block);
                if (n >= write_align) {
                    try self.readChunk(addr + @as(u32, @intCast(offset)), rx[offset..][0..n]);
                } else {
                    // The last 8 bytes of the range; the ones before the
                    // tail were read already.
                    const last = rx.len - write_align;
                    try self.readChunk(addr + @as(u32, @intCast(last)), &eight);
                    @memcpy(rx[offset..], eight[write_align - n ..]);
                }
                offset += n;
            }
        }

        /// Read Memory of `data.len` bytes from `addr`, padded to a multiple
        /// of 8 with 0xFF as `write` pads, compared chunk by chunk:
        /// `error.VerifyFailed` at the first chunk that differs. Every read
        /// is a whole multiple of 8 bytes, never fewer than 8.
        fn verify(self: Self, addr: u32, data: []const u8) Failure!void {
            std.debug.assert(data.len <= address_space - addr);
            var got: [max_block]u8 = undefined;
            var offset: usize = 0;
            while (offset < data.len) {
                const n = @min(data.len - offset, max_block);
                const padded = n + (write_align - n % write_align) % write_align; // <= max_block
                try self.readChunk(addr + @as(u32, @intCast(offset)), got[0..padded]);
                if (!std.mem.eql(u8, got[0..n], data[offset..][0..n])) return error.VerifyFailed;
                for (got[n..padded]) |b| if (b != erased) return error.VerifyFailed;
                offset += n;
            }
        }

        /// Go (AN4221 section 2.5): command, ACK, address, ACK. The
        /// bootloader then "initializes the user application's main stack
        /// pointer" (from where, AN4221 does not say) and jumps to the
        /// reset handler whose address is the word at `addr + 4`, and
        /// answers no more. Not public: `goTrial` and `start` are the two
        /// places to go.
        fn go(self: Self, addr: u32) Failure!void {
            try self.command(.go);
            try self.sendAddress(addr);
        }

        fn command(self: Self, op: Opcode) Failure!void {
            const b = @backingInt(op);
            try self.io.write(self.part.address, &[2]u8{ b, ~b });
            try self.waitAnswer(reply_busy_tries);
        }

        fn sendAddress(self: Self, addr: u32) Failure!void {
            try self.io.write(self.part.address, &addressFrame(addr));
            try self.waitAnswer(reply_busy_tries);
        }

        /// One Read Memory of 8 to 256 bytes into `rx`.
        fn readChunk(self: Self, addr: u32, rx: []u8) Failure!void {
            std.debug.assert(rx.len >= write_align and rx.len <= max_block);
            try self.command(.read_memory);
            try self.sendAddress(addr);
            const count: u8 = @intCast(rx.len - 1);
            try self.io.write(self.part.address, &[2]u8{ count, ~count });
            try self.waitAnswer(reply_busy_tries);
            try self.io.read(self.part.address, rx);
        }

        /// Read one-byte answers until ACK, at most `tries` of them.
        fn waitAnswer(self: Self, tries: u32) Failure!void {
            var left = tries;
            while (left > 0) : (left -= 1) {
                var answer: [1]u8 = undefined;
                try self.io.read(self.part.address, &answer);
                switch (answer[0]) {
                    ack => return,
                    nack => return error.Refused,
                    busy => self.io.delayMs(busy_poll_ms),
                    else => return error.UnexpectedByte,
                }
            }
            return error.Busy;
        }
    };
}

/// The trial vector of `part`: the last 8 bytes of its main flash, where
/// `stage` puts an image's first 8 bytes and `goTrial` starts it from.
pub fn trialVector(part: Part) u32 {
    return flash_base + (part.flash_size - write_align);
}

/// An address frame (AN4221 section 2.4): the four bytes of `addr`, MSB
/// first, and their XOR.
pub fn addressFrame(addr: u32) [5]u8 {
    var f: [5]u8 = undefined;
    std.mem.writeInt(u32, f[0..4], addr, .big);
    f[4] = xorAll(f[0..4]);
    return f;
}

/// A data block (AN4221 section 2.12) built in `buf`: N-1, the N bytes of
/// `data`, and the XOR of all of them. `data` holds 1 to 256 bytes.
pub fn dataFrame(buf: *[max_block + 2]u8, data: []const u8) []const u8 {
    std.debug.assert(data.len >= 1 and data.len <= max_block);
    buf[0] = @intCast(data.len - 1);
    @memcpy(buf[1..][0..data.len], data);
    const end = data.len + 1;
    buf[end] = xorAll(buf[0..end]);
    return buf[0 .. end + 1];
}

fn xorAll(bytes: []const u8) u8 {
    var x: u8 = 0;
    for (bytes) |b| x ^= b;
    return x;
}

/// `len` rounded up to a multiple of 8.
fn paddedLen(len: u32) u64 {
    return (@as(u64, len) + write_align - 1) / write_align * write_align;
}

/// Whether `len` bytes from `addr`, padded to a multiple of 8, lie wholly
/// inside the main flash of `part`.
fn insideFlash(part: Part, addr: u32, len: usize) bool {
    if (addr < flash_base or len > part.flash_size) return false;
    return @as(u64, addr - flash_base) + paddedLen(@intCast(len)) <= part.flash_size;
}

fn partIsValid(part: Part) bool {
    // Pages of at least 16 bytes: page 0 then holds image bytes past the
    // first 8, which `checkImage` requires.
    if (part.page_size < 2 * write_align or part.page_size % write_align != 0) return false;
    if (part.flash_size % part.page_size != 0) return false;
    const pages = part.flash_size / part.page_size;
    return pages >= 2 and pages <= max_erase_pages and
        // Below 4 GiB, end included: the trial vector and every range
        // end stay representable in a u32.
        @as(u64, flash_base) + part.flash_size < address_space and part.ram_size != 0;
}

// ============================================================================

const testing = std.testing;

/// What the fake's flash holds before the first erase: an older
/// application, so a host that writes without erasing is caught.
const old_content: u8 = 0x5A;
/// Where the C031's option bytes are; the fake lets them be read, never
/// written ([BOOT] B.2).
const option_bytes_base: u32 = 0x1FFF_7800;

/// A model of the C031's ROM bootloader on its I2C side ([BOOT] B.3,
/// AN4221 sections 2.3, 2.4, 2.5, 2.12, 2.13), one transaction at a time.
/// It answers as the real one does: NACK after a bad complement, checksum,
/// address or length, BUSY while it erases or programs. And it is strict:
/// every frame the real one would NACK is also recorded as a violation,
/// and a transaction the protocol has no place for fails at once with
/// `error.ProtocolViolation`. Every test that uses it ends with
/// `expectClean`.
const FakeBootloader = struct {
    /// `Nack` is a device that does not acknowledge its address: the name
    /// the real bus gives it (`i2c_bus.Error.Nack`), so a test sees what a
    /// host on the Daisy sees.
    pub const Error = error{ Nack, ProtocolViolation };

    pub const Violation = enum {
        wrong_device,
        complement,
        unknown_command,
        address_checksum,
        bad_address,
        misaligned_address,
        count_complement,
        /// A Read Memory of fewer than 8 bytes: AN4221's "(0 < N ≤ 255)"
        /// leaves a 1-byte read in doubt, and this host never asks for one.
        short_read,
        read_past_end,
        data_checksum,
        misaligned_length,
        write_past_end,
        not_erased,
        erase_checksum,
        too_many_pages,
        page_list_checksum,
        bad_page,
        /// This host only ever lists consecutive pages in ascending order.
        page_order,
        frame_shape,
        wrong_read_length,
        out_of_place,
        after_go,
    };

    /// Which answer an `Override` replaces: the one to the command, the
    /// one to the address (or to the page count of an erase), or the last
    /// one of the command (after the data of a write, the mass erase code,
    /// the page list, the read count, the Get ID data).
    const Stage = enum { command, address, final };
    /// Answer `byte` instead, at `stage` of the `skip + 1`-th `op`.
    const Override = struct { op: Opcode, stage: Stage, skip: u32 = 0, byte: u8 = nack };
    const Chunk = struct { addr: u32, len: usize };
    const Tx = struct { read: bool, len: usize, head: [5]u8 = @splat(0) };
    /// What happened to the chip, in order: every change, every Read
    /// Memory and every Go.
    const Event = union(enum) {
        mass_erase,
        erase: struct { first: u16, count: u16 },
        write: Chunk,
        read: Chunk,
        go: u32,
    };
    const pages = c031.flash_size / c031.page_size;

    const Phase = enum {
        command, // waiting for an opcode and its complement
        answer, // the host reads one byte: BUSY while `busy_left`, then `reply`
        id_data, // the host reads N, PID MSB, PID LSB
        address, // waiting for the address frame of `op`
        read_count, // Read Memory: waiting for N-1 and its complement
        read_data, // Read Memory: the host reads `count` bytes at `addr`
        write_data, // No-Stretch Write: waiting for N-1, the bytes, the XOR
        erase_code, // No-Stretch Erase: waiting for FF FF 00, or N-1 and its XOR
        erase_list, // No-Stretch Erase: waiting for `count` page numbers and their XOR
        gone, // after Go: the bootloader has jumped to the application
    };

    // Switches.
    address: u7 = c031.address,
    product_id: u16 = c031.product_id,
    id_count: u8 = 1,
    /// BUSY answers before the last answer of every erase and write.
    busy_answers: u32 = 2,
    busy_forever: bool = false,
    override: ?Override = null,
    /// Answer BUSY forever at this answer (its `byte` is not used): where
    /// AN4221 has no BUSY at all, the command, address and count answers.
    stall: ?Override = null,
    /// A flash address whose stored byte comes out wrong when programmed.
    corrupt_at: ?u32 = null,
    /// Transactions served before the device stops answering its address.
    silent_after: ?u32 = null,
    /// NACK the page count of every page-list erase: a bootloader that
    /// does not take the page list. It erases nothing.
    refuse_page_list: bool = false,
    /// Every erase answers ACK but leaves page 0 as it was.
    erase_skips_page_0: bool = false,

    // The device.
    mem: [c031.flash_size]u8 = @splat(old_content),
    option_bytes: [128]u8 = @splat(0xAA),
    phase: Phase = .command,
    op: u8 = 0,
    addr: u32 = 0,
    count: usize = 0,
    reply: u8 = ack,
    after: Phase = .command,
    busy_left: ?u32 = 0,

    // The record.
    violation: ?Violation = null,
    transactions: u32 = 0,
    /// Erases done, of either form, and how many of them were mass erases.
    erases: u32 = 0,
    mass_erases: u32 = 0,
    events: [1024]Event = undefined,
    event_count: usize = 0,
    chunks: [160]Chunk = undefined,
    chunk_count: usize = 0,
    go_to: ?u32 = null,
    gos: u32 = 0,
    /// What the CPU loaded at the latest Go: the stack pointer and the
    /// reset vector at the address given.
    go_vectors: ?[8]u8 = null,
    /// Bytes sent back by Read Memory, and how many of them had been sent
    /// when a chunk at the flash base was programmed.
    read_bytes: usize = 0,
    read_bytes_at_base_write: ?usize = null,
    /// One-byte reads in the latest answer.
    answer_reads: u32 = 0,
    delayed_ms: u64 = 0,
    trace: [64]Tx = undefined,
    trace_len: usize = 0,

    fn is(b: u8, op: Opcode) bool {
        return b == @backingInt(op);
    }

    pub fn write(self: *FakeBootloader, address: u7, bytes: []const u8) FakeBootloader.Error!void {
        try self.begin(address, false, bytes.len, bytes);
        switch (self.phase) {
            .command => {
                if (bytes.len != 2) return self.violate(.frame_shape);
                self.op = bytes[0];
                if (bytes[1] != ~bytes[0]) return self.refuse(.complement);
                const next: Phase = switch (bytes[0]) {
                    @backingInt(Opcode.get_id) => .id_data,
                    @backingInt(Opcode.read_memory), @backingInt(Opcode.go), @backingInt(Opcode.write_no_stretch) => .address,
                    @backingInt(Opcode.erase_no_stretch) => .erase_code,
                    else => return self.refuse(.unknown_command),
                };
                if (self.overridden(.command)) |b| return self.answer(b, .command, 0);
                self.answer(ack, next, self.stalled(.command));
            },
            .address => {
                if (bytes.len != 5) return self.violate(.frame_shape);
                if (xorAll(bytes) != 0) return self.refuse(.address_checksum);
                const a = std.mem.readInt(u32, bytes[0..4], .big);
                const readable = is(self.op, .read_memory) and inOptionBytes(a, 1);
                if (!inFlash(a, 1) and !readable) return self.refuse(.bad_address);
                if (is(self.op, .write_no_stretch) and a % write_align != 0) return self.refuse(.misaligned_address);
                if (self.overridden(.address)) |b| return self.answer(b, .command, 0);
                self.addr = a;
                if (is(self.op, .read_memory)) {
                    self.answer(ack, .read_count, self.stalled(.address));
                } else if (is(self.op, .write_no_stretch)) {
                    self.answer(ack, .write_data, self.stalled(.address));
                } else {
                    self.go_to = a;
                    self.gos += 1;
                    self.go_vectors = self.mem[a - flash_base ..][0..8].*;
                    self.record(.{ .go = a });
                    self.answer(ack, .gone, self.stalled(.address));
                }
            },
            .read_count => {
                if (bytes.len != 2) return self.violate(.frame_shape);
                if (bytes[1] != ~bytes[0]) return self.refuse(.count_complement);
                const n = @as(usize, bytes[0]) + 1;
                if (n < write_align) return self.refuse(.short_read);
                if (!inFlash(self.addr, n) and !inOptionBytes(self.addr, n)) return self.refuse(.read_past_end);
                if (self.overridden(.final)) |b| return self.answer(b, .command, 0);
                self.count = n;
                self.answer(ack, .read_data, self.stalled(.final));
            },
            .write_data => {
                if (bytes.len < 2 or bytes.len != @as(usize, bytes[0]) + 3) return self.violate(.frame_shape);
                const data = bytes[1 .. bytes.len - 1];
                if (xorAll(bytes) != 0) return self.refuse(.data_checksum);
                if (data.len % write_align != 0) return self.refuse(.misaligned_length);
                if (!inFlash(self.addr, data.len)) return self.refuse(.write_past_end);
                const at = self.addr - flash_base;
                for (self.mem[at..][0..data.len]) |m| if (m != 0xFF) return self.refuse(.not_erased);
                if (self.overridden(.final)) |b| return self.answer(b, .command, self.busyCount());
                for (self.mem[at..][0..data.len], data) |*m, d| m.* &= d;
                if (self.corrupt_at) |c| {
                    if (c >= self.addr and c - self.addr < data.len) self.mem[c - flash_base] ^= 0x01;
                }
                if (self.chunk_count < self.chunks.len) self.chunks[self.chunk_count] = .{ .addr = self.addr, .len = data.len };
                self.chunk_count += 1;
                self.record(.{ .write = .{ .addr = self.addr, .len = data.len } });
                if (self.addr == flash_base) self.read_bytes_at_base_write = self.read_bytes;
                self.answer(ack, .command, self.busyCount());
            },
            .erase_code => {
                if (bytes.len != 3) return self.violate(.frame_shape);
                if (xorAll(bytes) != 0) return self.refuse(.erase_checksum);
                const code = std.mem.readInt(u16, bytes[0..2], .big);
                if (code == mass_erase) {
                    if (self.overridden(.final)) |b| return self.answer(b, .command, self.busyCount());
                    self.erasePages(0, pages);
                    self.mass_erases += 1;
                    self.record(.mass_erase);
                    return self.answer(ack, .command, self.busyCount());
                }
                // The other special codes (bank erases, reserved) are
                // never this host's business.
                if (code >= 0xFFF0) return self.violate(.frame_shape);
                const n = @as(usize, code) + 1;
                if (n > max_erase_pages) return self.refuse(.too_many_pages);
                if (self.refuse_page_list) return self.answer(nack, .command, 0);
                if (self.overridden(.address)) |b| return self.answer(b, .command, 0);
                self.count = n;
                self.answer(ack, .erase_list, self.stalled(.address));
            },
            .erase_list => {
                if (bytes.len != 2 * self.count + 1) return self.violate(.frame_shape);
                if (xorAll(bytes) != 0) return self.refuse(.page_list_checksum);
                const first = std.mem.readInt(u16, bytes[0..2], .big);
                for (0..self.count) |i| {
                    const p = std.mem.readInt(u16, bytes[2 * i ..][0..2], .big);
                    if (p >= pages) return self.refuse(.bad_page);
                    if (p != first + i) return self.violate(.page_order);
                }
                if (self.overridden(.final)) |b| return self.answer(b, .command, self.busyCount());
                self.erasePages(first, self.count);
                self.record(.{ .erase = .{ .first = first, .count = @intCast(self.count) } });
                self.answer(ack, .command, self.busyCount());
            },
            .answer, .id_data, .read_data => return self.violate(.out_of_place),
            .gone => return self.violate(.after_go),
        }
    }

    pub fn read(self: *FakeBootloader, address: u7, rx: []u8) FakeBootloader.Error!void {
        try self.begin(address, true, rx.len, &.{});
        switch (self.phase) {
            .answer => {
                if (rx.len != 1) return self.violate(.wrong_read_length);
                self.answer_reads += 1;
                if (self.busy_left) |*left| {
                    if (left.* > 0) {
                        left.* -= 1;
                        rx[0] = busy;
                        return;
                    }
                } else {
                    rx[0] = busy;
                    return;
                }
                rx[0] = self.reply;
                self.phase = self.after;
            },
            .id_data => {
                if (rx.len != 3) return self.violate(.wrong_read_length);
                rx[0..3].* = .{ self.id_count, @truncate(self.product_id >> 8), @truncate(self.product_id) };
                self.answer(self.overridden(.final) orelse ack, .command, self.stalled(.final));
            },
            .read_data => {
                if (rx.len != self.count) return self.violate(.wrong_read_length);
                if (inFlash(self.addr, rx.len)) {
                    @memcpy(rx, self.mem[self.addr - flash_base ..][0..rx.len]);
                } else {
                    @memcpy(rx, self.option_bytes[self.addr - option_bytes_base ..][0..rx.len]);
                }
                self.read_bytes += rx.len;
                self.record(.{ .read = .{ .addr = self.addr, .len = rx.len } });
                self.phase = .command;
            },
            .command, .address, .read_count, .write_data, .erase_code, .erase_list => return self.violate(.out_of_place),
            .gone => return self.violate(.after_go),
        }
    }

    pub fn delayMs(self: *FakeBootloader, ms: u32) void {
        self.delayed_ms += ms;
    }

    fn begin(self: *FakeBootloader, address: u7, is_read: bool, len: usize, bytes: []const u8) FakeBootloader.Error!void {
        if (address != self.address) return self.violate(.wrong_device);
        self.transactions += 1;
        if (self.trace_len < self.trace.len) {
            var tx: Tx = .{ .read = is_read, .len = len };
            const n = @min(bytes.len, tx.head.len);
            @memcpy(tx.head[0..n], bytes[0..n]);
            self.trace[self.trace_len] = tx;
        }
        self.trace_len += 1;
        if (self.silent_after) |n| if (self.transactions > n) return error.Nack;
    }

    /// Play the application's part after a Go: erase `erased_pages` (an
    /// image that returns to the bootloader as it should erases page 0),
    /// then reset into the bootloader.
    fn appRan(self: *FakeBootloader, erased_pages: []const u16) !void {
        if (self.phase != .gone) return error.TestUnexpectedResult;
        for (erased_pages) |p| @memset(self.mem[@as(usize, p) * c031.page_size ..][0..c031.page_size], 0xFF);
        self.phase = .command;
    }

    /// Whether any write since event `from` was at the flash base.
    fn wroteBase(self: *const FakeBootloader, from: usize) bool {
        for (self.events[from..@min(self.event_count, self.events.len)]) |e| switch (e) {
            .write => |w| if (w.addr == flash_base) return true,
            else => {},
        };
        return false;
    }

    fn record(self: *FakeBootloader, e: Event) void {
        if (self.event_count < self.events.len) self.events[self.event_count] = e;
        self.event_count += 1;
    }

    /// Erase `n` pages from `first`, page 0 excepted while
    /// `erase_skips_page_0` is set.
    fn erasePages(self: *FakeBootloader, first: usize, n: usize) void {
        for (first..first + n) |p| {
            if (p == 0 and self.erase_skips_page_0) continue;
            @memset(self.mem[p * c031.page_size ..][0..c031.page_size], 0xFF);
        }
        self.erases += 1;
    }

    fn expectEvents(self: *const FakeBootloader, expected: []const Event) !void {
        try testing.expectEqual(expected.len, self.event_count);
        for (expected, self.events[0..expected.len]) |e, got| try testing.expectEqualDeep(e, got);
    }

    fn answer(self: *FakeBootloader, reply: u8, after: Phase, busy_count: ?u32) void {
        self.phase = .answer;
        self.reply = reply;
        self.after = after;
        self.busy_left = busy_count;
        self.answer_reads = 0;
    }

    fn busyCount(self: *const FakeBootloader) ?u32 {
        return if (self.busy_forever) null else self.busy_answers;
    }

    /// The BUSY answers before this answer: none, or forever when `stall`
    /// names it.
    fn stalled(self: *FakeBootloader, stage: Stage) ?u32 {
        const o = self.stall orelse return 0;
        if (!is(self.op, o.op) or o.stage != stage) return 0;
        if (o.skip > 0) {
            self.stall.?.skip -= 1;
            return 0;
        }
        self.stall = null;
        return null;
    }

    fn overridden(self: *FakeBootloader, stage: Stage) ?u8 {
        const o = self.override orelse return null;
        if (!is(self.op, o.op) or o.stage != stage) return null;
        if (o.skip > 0) {
            self.override.?.skip -= 1;
            return null;
        }
        self.override = null;
        return o.byte;
    }

    /// What the real bootloader would NACK: record it, then NACK.
    fn refuse(self: *FakeBootloader, v: Violation) void {
        if (self.violation == null) self.violation = v;
        self.answer(nack, .command, 0);
    }

    /// What has no place in the protocol: record it and fail the transaction.
    fn violate(self: *FakeBootloader, v: Violation) error{ProtocolViolation} {
        if (self.violation == null) self.violation = v;
        return error.ProtocolViolation;
    }

    fn inFlash(a: u32, len: usize) bool {
        return a >= flash_base and @as(u64, a - flash_base) + @as(u64, len) <= c031.flash_size;
    }

    fn inOptionBytes(a: u32, len: usize) bool {
        return a >= option_bytes_base and @as(u64, a - option_bytes_base) + @as(u64, len) <= 128;
    }

    fn expectClean(self: *const FakeBootloader) !void {
        if (self.violation) |v| {
            std.debug.print("fake bootloader: protocol violation {s}\n", .{@tagName(v)});
            return error.TestUnexpectedResult;
        }
    }

    fn clearTrace(self: *FakeBootloader) void {
        self.trace_len = 0;
    }

    fn expectTrace(self: *const FakeBootloader, expected: []const Tx) !void {
        try testing.expectEqual(expected.len, self.trace_len);
        for (expected, self.trace[0..expected.len]) |e, got| try testing.expectEqualDeep(e, got);
    }
};

fn wr(bytes: []const u8) FakeBootloader.Tx {
    var tx: FakeBootloader.Tx = .{ .read = false, .len = bytes.len };
    const n = @min(bytes.len, tx.head.len);
    @memcpy(tx.head[0..n], bytes[0..n]);
    return tx;
}

fn rd(len: usize) FakeBootloader.Tx {
    return .{ .read = true, .len = len };
}

const TestBoot = Bootloader(*FakeBootloader);

/// Test data: no 8-byte group of it is all 0xFF, and no two 256-byte
/// blocks of it are alike, so a chunk written to the wrong place shows.
fn pattern(comptime len: usize) [len]u8 {
    var img: [len]u8 = undefined;
    for (&img, 0..) |*b, i| b.* = @truncate(i *% 7 +% (i >> 8) +% 3);
    return img;
}

/// A plausible C031 program of `len` bytes (at least 10): its stack
/// pointer at the top of the C031's RAM, its reset vector just past the
/// vectors, then `pattern`.
fn testImage(comptime len: usize) [len]u8 {
    var img = pattern(len);
    std.mem.writeInt(u32, img[0..4], ram_base + c031.ram_size, .little);
    std.mem.writeInt(u32, img[4..8], flash_base + 9, .little);
    return img;
}

fn allErased(bytes: []const u8) bool {
    for (bytes) |b| if (b != 0xFF) return false;
    return true;
}

test "address and data frames" {
    try std.testing.expectEqualSlices(u8, &.{ 0x08, 0x00, 0x00, 0x00, 0x08 }, &addressFrame(0x0800_0000));
    try std.testing.expectEqualSlices(u8, &.{ 0x08, 0x00, 0x01, 0x00, 0x09 }, &addressFrame(0x0800_0100));
    var buf: [258]u8 = undefined;
    try std.testing.expectEqualSlices(u8, &.{ 0x07, 0x00, 0x30, 0x00, 0x20, 0xC1, 0x00, 0x00, 0x08, 0xDE }, dataFrame(&buf, &.{ 0x00, 0x30, 0x00, 0x20, 0xC1, 0x00, 0x00, 0x08 }));
}

test "a data frame of 256 bytes starts with 0xFF and XORs to zero" {
    var buf: [258]u8 = undefined;
    const img = pattern(256);
    const f = dataFrame(&buf, &img);
    try testing.expectEqual(@as(usize, 258), f.len);
    try testing.expectEqual(@as(u8, 0xFF), f[0]);
    try testing.expectEqualSlices(u8, &img, f[1..257]);
    try testing.expectEqual(@as(u8, 0), xorAll(f));
}

test "productId returns 0x453" {
    var fake: FakeBootloader = .{};
    const boot = TestBoot.init(&fake, c031);
    try testing.expectEqual(@as(u16, 0x453), try boot.productId());
    try fake.expectClean();
}

test "each step is its own transaction, as AN4221 frames them" {
    var fake: FakeBootloader = .{};
    const boot = TestBoot.init(&fake, c031);

    // Get ID: command, ACK, N + PID in one read, ACK.
    _ = try boot.productId();
    try fake.expectTrace(&.{ wr(&.{ 0x02, 0xFD }), rd(1), rd(3), rd(1) });

    // No-Stretch Erase, mass erase: command, ACK, FF FF 00, BUSY BUSY ACK.
    fake.clearTrace();
    try boot.massErase();
    try fake.expectTrace(&.{ wr(&.{ 0x45, 0xBA }), rd(1), wr(&.{ 0xFF, 0xFF, 0x00 }), rd(1), rd(1), rd(1) });

    // No-Stretch Write: command, ACK, address, ACK, N-1 + data + XOR, BUSY BUSY ACK.
    const img = pattern(8);
    var buf: [258]u8 = undefined;
    fake.clearTrace();
    try boot.write(flash_base, &img);
    try fake.expectTrace(&.{
        wr(&.{ 0x32, 0xCD }),                   rd(1),
        wr(&.{ 0x08, 0x00, 0x00, 0x00, 0x08 }), rd(1),
        wr(dataFrame(&buf, &img)),              rd(1),
        rd(1),                                  rd(1),
    });
    try testing.expectEqual(@as(usize, 10), fake.trace[4].len);

    // Read Memory: command, ACK, address, ACK, N-1 + complement, ACK, N bytes in one read.
    fake.clearTrace();
    try boot.verify(flash_base, &img);
    try fake.expectTrace(&.{
        wr(&.{ 0x11, 0xEE }),                   rd(1),
        wr(&.{ 0x08, 0x00, 0x00, 0x00, 0x08 }), rd(1),
        wr(&.{ 0x07, 0xF8 }),                   rd(1),
        rd(8),
    });

    // Go: command, ACK, address, ACK.
    fake.clearTrace();
    try boot.go(flash_base);
    try fake.expectTrace(&.{ wr(&.{ 0x21, 0xDE }), rd(1), wr(&.{ 0x08, 0x00, 0x00, 0x00, 0x08 }), rd(1) });
    try fake.expectClean();
}

test "the page-list erase is framed as AN4221 section 2.13 shows it" {
    var fake: FakeBootloader = .{};
    const boot = TestBoot.init(&fake, c031);

    // Page 0: command, ACK, N-1 = 00 00 and its XOR, ACK, page 00 00 and
    // its XOR, BUSY BUSY ACK; then its first 8 bytes read back.
    try boot.erasePages(0, 1);
    try fake.expectTrace(&.{
        wr(&.{ 0x45, 0xBA }),                   rd(1),
        wr(&.{ 0x00, 0x00, 0x00 }),             rd(1),
        wr(&.{ 0x00, 0x00, 0x00 }),             rd(1),
        rd(1),                                  rd(1),
        wr(&.{ 0x11, 0xEE }),                   rd(1),
        wr(&.{ 0x08, 0x00, 0x00, 0x00, 0x08 }), rd(1),
        wr(&.{ 0x07, 0xF8 }),                   rd(1),
        rd(8),
    });

    // Pages 1 and 2, AN4221's own example ("0x45 0xBA Wait ACK 0x00 0x01
    // 0x01 Wait ACK 0x00 0x01 0x00 0x02 0x03 Wait ACK"), after the check
    // that the first 8 bytes are still erased.
    fake.clearTrace();
    try boot.erasePages(1, 2);
    try fake.expectTrace(&.{
        wr(&.{ 0x11, 0xEE }),                   rd(1),
        wr(&.{ 0x08, 0x00, 0x00, 0x00, 0x08 }), rd(1),
        wr(&.{ 0x07, 0xF8 }),                   rd(1),
        rd(8),                                  wr(&.{ 0x45, 0xBA }),
        rd(1),                                  wr(&.{ 0x00, 0x01, 0x01 }),
        rd(1),                                  wr(&.{ 0x00, 0x01, 0x00, 0x02, 0x03 }),
        rd(1),                                  rd(1),
        rd(1),
    });
    try fake.expectEvents(&.{
        .{ .erase = .{ .first = 0, .count = 1 } },
        .{ .read = .{ .addr = flash_base, .len = 8 } },
        .{ .read = .{ .addr = flash_base, .len = 8 } },
        .{ .erase = .{ .first = 1, .count = 2 } },
    });
    try testing.expect(allErased(fake.mem[0 .. 3 * c031.page_size]));
    try testing.expectEqual(old_content, fake.mem[3 * c031.page_size]);
    try fake.expectClean();
}

test "H3: the first change is an erase of page 0 alone, and the next step reads its first 8 bytes back" {
    var fake: FakeBootloader = .{};
    const img = testImage(1000);
    _ = try TestBoot.init(&fake, c031).stage(&img);
    try testing.expect(fake.event_count > 4);
    try testing.expectEqualDeep(FakeBootloader.Event{ .erase = .{ .first = 0, .count = 1 } }, fake.events[0]);
    try testing.expectEqualDeep(FakeBootloader.Event{ .read = .{ .addr = flash_base, .len = 8 } }, fake.events[1]);
    try testing.expectEqualDeep(FakeBootloader.Event{ .erase = .{ .first = 1, .count = 15 } }, fake.events[2]);
    try testing.expectEqualDeep(FakeBootloader.Event{ .write = .{ .addr = flash_base + 8, .len = 256 } }, fake.events[3]);
    try testing.expectEqual(@as(u32, 0), fake.mass_erases);
    try fake.expectClean();
}

test "H3: a page-0 erase that does not leave it blank gives error.NotBlank, and nothing else changes" {
    var fake: FakeBootloader = .{ .erase_skips_page_0 = true };
    const img = testImage(1000);
    try testing.expectError(error.NotBlank, TestBoot.init(&fake, c031).stage(&img));
    try fake.expectEvents(&.{
        .{ .erase = .{ .first = 0, .count = 1 } },
        .{ .read = .{ .addr = flash_base, .len = 8 } },
    });
    for (fake.mem) |b| try testing.expectEqual(old_content, b);
    try fake.expectClean();
}

test "H3: a NACK to the page count or the page list of page 0 falls back to the mass erase, with the same check" {
    const img = testImage(1000);
    const Case = struct { refuse: bool, override: ?FakeBootloader.Override };
    for ([_]Case{
        .{ .refuse = true, .override = null },
        .{ .refuse = false, .override = .{ .op = .erase_no_stretch, .stage = .address } },
        .{ .refuse = false, .override = .{ .op = .erase_no_stretch, .stage = .final } },
    }) |c| {
        var fake: FakeBootloader = .{ .refuse_page_list = c.refuse, .override = c.override };
        _ = try TestBoot.init(&fake, c031).stage(&img);
        try testing.expect(fake.event_count > 3);
        try testing.expectEqualDeep(FakeBootloader.Event.mass_erase, fake.events[0]);
        try testing.expectEqualDeep(FakeBootloader.Event{ .read = .{ .addr = flash_base, .len = 8 } }, fake.events[1]);
        try testing.expectEqualDeep(FakeBootloader.Event{ .write = .{ .addr = flash_base + 8, .len = 256 } }, fake.events[2]);
        try testing.expectEqual(@as(u32, 1), fake.erases); // the mass erase, and no page list after it
        try testing.expect(allErased(fake.mem[0..8]));
        try testing.expectEqualSlices(u8, img[8..], fake.mem[8..1000]);
        try fake.expectClean();
    }
    // The mass erase gets the same check.
    var fake: FakeBootloader = .{ .refuse_page_list = true, .erase_skips_page_0 = true };
    try testing.expectError(error.NotBlank, TestBoot.init(&fake, c031).stage(&img));
    try fake.expectEvents(&.{ .mass_erase, .{ .read = .{ .addr = flash_base, .len = 8 } } });
    try testing.expectEqual(@as(usize, 0), fake.chunk_count);
    try fake.expectClean();
}

test "H3: anything but a NACK to the page list of page 0 is returned as it is, without a mass erase" {
    const img = testImage(1000);
    {
        // A NACK to the erase command itself: a mass erase would get the same.
        var fake: FakeBootloader = .{ .override = .{ .op = .erase_no_stretch, .stage = .command } };
        try testing.expectError(error.Refused, TestBoot.init(&fake, c031).stage(&img));
        try testing.expectEqual(@as(u32, 0), fake.erases);
        try testing.expectEqual(@as(usize, 0), fake.event_count);
        try fake.expectClean();
    }
    {
        var fake: FakeBootloader = .{ .override = .{ .op = .erase_no_stretch, .stage = .final, .byte = 0x00 } };
        try testing.expectError(error.UnexpectedByte, TestBoot.init(&fake, c031).stage(&img));
        try testing.expectEqual(@as(u32, 0), fake.erases);
        try testing.expectEqual(@as(u32, 0), fake.mass_erases);
        try fake.expectClean();
    }
    {
        var fake: FakeBootloader = .{ .busy_forever = true };
        try testing.expectError(error.Busy, TestBoot.init(&fake, c031).erasePages(0, 1));
        try testing.expectEqual(@as(u32, 10_000), fake.answer_reads);
        try testing.expectEqual(@as(u32, 0), fake.mass_erases);
        try fake.expectClean();
    }
    {
        // Get ID 4, then command 2, count 2: the page list is transaction 9.
        var fake: FakeBootloader = .{ .silent_after = 8 };
        try testing.expectError(error.Nack, TestBoot.init(&fake, c031).stage(&img));
        try testing.expectEqual(@as(u32, 9), fake.transactions);
        try testing.expectEqual(@as(u32, 0), fake.erases);
        try fake.expectClean();
    }
    {
        // Pages 1 to 15 refused: no mass erase, as page 0 is already blank.
        var fake: FakeBootloader = .{ .override = .{ .op = .erase_no_stretch, .stage = .final, .skip = 1 } };
        try testing.expectError(error.Refused, TestBoot.init(&fake, c031).stage(&img));
        try fake.expectEvents(&.{
            .{ .erase = .{ .first = 0, .count = 1 } },
            .{ .read = .{ .addr = flash_base, .len = 8 } },
        });
        try testing.expectEqual(@as(u32, 0), fake.mass_erases);
        try fake.expectClean();
    }
}

test "a bus Nack at an answer read of the page-0 erase is the bus's error, and no mass erase follows, in stage and in uncommit" {
    // The bootloader not acknowledging its address (a ROM deaf while it
    // erases, a ROM still waiting for the page list, a glitch) is not the
    // bootloader answering 0x1F: the host returns the bus's `Nack` and
    // sends nothing more, the mass erase above all.
    //
    // The page-0 erase, transactions counted from its command: 1 `45 BA`,
    // 2 its answer, 3 the count `00 00 00`, 4 the answer to the count,
    // 5 the page list `00 00 00`, 6 and 7 BUSY (the fake's two), 8 ACK.
    // `stage` sends Get ID before it (4 transactions); `uncommit` nothing.
    const img = testImage(1000);
    const answer_reads = [_]u32{ 4, 6, 7, 8 };
    for ([_]bool{ true, false }) |in_stage| {
        const before: u32 = if (in_stage) 4 else 0;
        for (answer_reads) |answer| {
            errdefer std.debug.print("{s}, answer read {d}\n", .{ if (in_stage) "stage" else "uncommit", answer });
            // The device stops acknowledging from that read on.
            var fake: FakeBootloader = .{ .silent_after = before + answer - 1 };
            const boot = TestBoot.init(&fake, c031);
            const got: ?TestBoot.Failure = if (in_stage)
                (if (boot.stage(&img)) |_| null else |e| e)
            else
                (if (boot.uncommit()) |_| null else |e| e);
            try testing.expectEqual(@as(?TestBoot.Failure, error.Nack), got);
            // The failed read was the last transaction.
            try testing.expectEqual(before + answer, fake.transactions);
            var erase_commands: usize = 0;
            for (fake.trace[0..fake.trace_len]) |tx| {
                if (!tx.read and tx.len == 2 and tx.head[0] == 0x45 and tx.head[1] == 0xBA) erase_commands += 1;
            }
            try testing.expectEqual(@as(usize, 1), erase_commands); // no second `45 BA`
            try testing.expectEqual(@as(u32, 0), fake.mass_erases);
            try fake.expectClean();
        }
    }
}

test "erasePages refuses a range outside main flash before anything is sent" {
    var fake: FakeBootloader = .{};
    const boot = TestBoot.init(&fake, c031);
    const Range = struct { first: u16, count: u16 };
    for ([_]Range{
        .{ .first = 16, .count = 1 },
        .{ .first = 15, .count = 2 },
        .{ .first = 0, .count = 17 },
        .{ .first = 17, .count = 0 },
        .{ .first = 0xFFFF, .count = 2 },
        .{ .first = 0xFFFF, .count = 0xFFFF },
    }) |r| try testing.expectError(error.OutsideFlash, boot.erasePages(r.first, r.count));
    try boot.erasePages(5, 0); // nothing to erase
    try testing.expectEqual(@as(u32, 0), fake.transactions);
    try fake.expectClean();
}

test "erasePages beyond page 0 on a committed chip is refused with error.NotBlank, and erases nothing" {
    var fake: FakeBootloader = .{};
    const boot = TestBoot.init(&fake, c031);
    try testing.expectError(error.NotBlank, boot.erasePages(1, 15));
    try fake.expectEvents(&.{.{ .read = .{ .addr = flash_base, .len = 8 } }});
    try testing.expectEqual(@as(u32, 0), fake.erases);
    // Once page 0 is erased, any other range may be.
    try boot.erasePages(0, 1);
    try boot.erasePages(3, 2);
    try testing.expectEqualDeep(FakeBootloader.Event{ .erase = .{ .first = 3, .count = 2 } }, fake.events[fake.event_count - 1]);
    try testing.expectEqual(old_content, fake.mem[c031.page_size]);
    try testing.expect(allErased(fake.mem[3 * c031.page_size .. 5 * c031.page_size]));
    try testing.expectEqual(old_content, fake.mem[5 * c031.page_size]);
    try fake.expectClean();
}

test "erasePages of every page erases page 0 first, then the others in one command" {
    var fake: FakeBootloader = .{};
    try TestBoot.init(&fake, c031).erasePages(0, 16);
    try fake.expectEvents(&.{
        .{ .erase = .{ .first = 0, .count = 1 } },
        .{ .read = .{ .addr = flash_base, .len = 8 } },
        .{ .erase = .{ .first = 1, .count = 15 } },
    });
    try testing.expect(allErased(&fake.mem));
    try fake.expectClean();
}

test "checkImage: the length, padded to 8, is at least 16 and at most the flash size less 8" {
    const img = testImage(c031.flash_size);
    try checkImage(img[0..10], c031); // the smallest image that can pass
    try checkImage(img[0 .. c031.flash_size - 8], c031); // the largest
    try checkImage(img[0 .. c031.flash_size - 15], c031); // padded to flash_size - 8
    try testing.expectError(error.NotAnImage, checkImage(img[0..0], c031));
    try testing.expectError(error.NotAnImage, checkImage(img[0..8], c031)); // padded to 8
    try testing.expectError(error.NotAnImage, checkImage(img[0 .. c031.flash_size - 7], c031)); // padded to flash_size
    try testing.expectError(error.NotAnImage, checkImage(&img, c031));
}

test "checkImage: the initial stack pointer lies in RAM, above its first word, and is a multiple of 4" {
    var img = testImage(1000);
    const Case = struct { sp: u32, ok: bool };
    for ([_]Case{
        .{ .sp = ram_base + 4, .ok = true },
        .{ .sp = ram_base + c031.ram_size, .ok = true }, // the top of RAM
        .{ .sp = ram_base, .ok = false },
        .{ .sp = ram_base + c031.ram_size + 4, .ok = false },
        .{ .sp = ram_base + 0x1002, .ok = false },
        .{ .sp = 0x2002_0000, .ok = false }, // a Daisy's DTCM
        .{ .sp = 0x2400_0000, .ok = false },
        .{ .sp = 0, .ok = false },
        .{ .sp = 0xFFFF_FFFF, .ok = false }, // erased
    }) |c| {
        std.mem.writeInt(u32, img[0..4], c.sp, .little);
        if (c.ok) try checkImage(&img, c031) else try testing.expectError(error.NotAnImage, checkImage(&img, c031));
    }
}

test "checkImage: the reset vector is measured against the image's own length, not its padded one" {
    var img = testImage(1003); // padded to 1008
    std.mem.writeInt(u32, img[4..8], flash_base + 1001, .little);
    try checkImage(&img, c031);
    std.mem.writeInt(u32, img[4..8], flash_base + 1003, .little);
    try testing.expectError(error.NotAnImage, checkImage(&img, c031));
    std.mem.writeInt(u32, img[4..8], flash_base + 1007, .little);
    try testing.expectError(error.NotAnImage, checkImage(&img, c031));
}

test "checkImage: the reset vector is odd and inside the image, past its first 8 bytes" {
    var img = testImage(1000);
    const Case = struct { rv: u32, ok: bool };
    for ([_]Case{
        .{ .rv = flash_base + 9, .ok = true },
        .{ .rv = flash_base + 999, .ok = true }, // the last byte of the image
        .{ .rv = flash_base + 1001, .ok = false }, // just past it
        .{ .rv = flash_base + 8, .ok = false }, // even
        .{ .rv = flash_base + 0x100, .ok = false }, // even
        .{ .rv = flash_base + 7, .ok = false }, // in the vectors
        .{ .rv = flash_base + 1, .ok = false },
        .{ .rv = 0x0001_0001, .ok = false },
        .{ .rv = 0xFFFF_FFFF, .ok = false }, // erased
    }) |c| {
        std.mem.writeInt(u32, img[4..8], c.rv, .little);
        if (c.ok) try checkImage(&img, c031) else try testing.expectError(error.NotAnImage, checkImage(&img, c031));
    }
}

test "checkImage: a Daisy image, a text file, an erased image and an empty file are not C031 programs" {
    var daisy = pattern(1000);
    std.mem.writeInt(u32, daisy[0..4], 0x2002_0000, .little);
    std.mem.writeInt(u32, daisy[4..8], flash_base + 0x199, .little);
    try testing.expectError(error.NotAnImage, checkImage(&daisy, c031));
    try testing.expectError(error.NotAnImage, checkImage("This is a text file that was picked by mistake.\n", c031));
    const blank: [1000]u8 = @splat(0xFF);
    try testing.expectError(error.NotAnImage, checkImage(&blank, c031));
    try testing.expectError(error.NotAnImage, checkImage("", c031));
}

/// The review's A1b image: 4 KB whose page 0 is 0xFF from byte 8 on, its
/// reset vector in page 1.
fn blankPageZeroImage() [4096]u8 {
    var img = testImage(4096);
    @memset(img[8..c031.page_size], 0xFF);
    std.mem.writeInt(u32, img[4..8], flash_base + c031.page_size + 1, .little);
    return img;
}

/// The review's A1 image: the smallest that passed before, with 0xFF in
/// bytes 8 and 9.
fn blankTenByteImage() [10]u8 {
    var img = testImage(10);
    img[8] = 0xFF;
    img[9] = 0xFF;
    return img;
}

/// A part with 8-byte pages: page 0 is exactly the 8 bytes `stage` leaves
/// erased (the review's A11).
const part8: Part = .{ .address = c031.address, .product_id = c031.product_id, .flash_size = 4096, .page_size = 8, .ram_size = c031.ram_size };

test "checkImage: page 0 must hold an image byte other than 0xFF past the first 8, so that its erase can be seen" {
    try testing.expectError(error.NotAnImage, checkImage(&blankPageZeroImage(), c031));
    try testing.expectError(error.NotAnImage, checkImage(&blankTenByteImage(), c031));
    // The smallest image that passes is still 10 bytes, when byte 8 or 9 is
    // not 0xFF.
    var ten = testImage(10);
    try checkImage(&ten, c031);
    ten[8] = 0xFF;
    try checkImage(&ten, c031);
    ten[8] = 0x00;
    ten[9] = 0xFF;
    try checkImage(&ten, c031);
    // One byte other than 0xFF at the very end of page 0 is enough.
    var late = blankPageZeroImage();
    late[c031.page_size - 1] = 0x00;
    try checkImage(&late, c031);
    // A part whose page 0 holds nothing past the first 8 bytes takes no image.
    try testing.expectError(error.NotAnImage, checkImage(&testImage(1000), part8));
}

test "a part with pages of fewer than 16 bytes is not a valid part" {
    try testing.expect(partIsValid(c031));
    try testing.expect(!partIsValid(part8));
    var p16 = part8;
    p16.page_size = 16;
    try testing.expect(partIsValid(p16));
}

test "a part whose flash ends at 4 GiB, or that has a single page, is not a valid part" {
    // The review's A12: the trial vector would be computed past 4 GiB.
    var top = c031;
    top.flash_size = 0xF800_0000;
    top.page_size = 0x7C_0000;
    try testing.expect(!partIsValid(top));
    top.flash_size -= top.page_size;
    try testing.expect(partIsValid(top));
    try testing.expectEqual(@as(u32, 0xFFFF_FFF8 - 0x7C_0000), trialVector(top));
    var one = c031;
    one.flash_size = one.page_size;
    try testing.expect(!partIsValid(one));
}

test "stage and commit refuse an image whose page 0 would read blank after staging, before anything is sent" {
    var fake: FakeBootloader = .{};
    const boot = TestBoot.init(&fake, c031);
    const a1b = blankPageZeroImage();
    const a1 = blankTenByteImage();
    for ([_][]const u8{ &a1b, &a1 }) |img| {
        try testing.expectError(error.NotAnImage, boot.stage(img));
        try testing.expectError(error.NotAnImage, boot.commit(forged, img));
    }
    // With 8-byte pages, even past `init`'s assertion.
    const odd: TestBoot = .{ .io = &fake, .part = part8 };
    const img = testImage(1000);
    try testing.expectError(error.NotAnImage, odd.stage(&img));
    try testing.expectError(error.NotAnImage, odd.commit(forged, &img));
    try testing.expectEqual(@as(u32, 0), fake.transactions);
    try fake.expectClean();
}

test "stage and commit refuse a file that is not an image before anything is sent" {
    var fake: FakeBootloader = .{};
    const boot = TestBoot.init(&fake, c031);
    const noise = pattern(1000);
    const big = testImage(c031.flash_size);
    for ([_][]const u8{ "not a program at all, just some text", &noise, &big, "" }) |bad| {
        try testing.expectError(error.NotAnImage, boot.stage(bad));
        try testing.expectError(error.NotAnImage, boot.commit(forged, bad));
    }
    try testing.expectEqual(@as(u32, 0), fake.transactions);
    try fake.expectClean();
}

test "a write outside main flash is refused before anything is sent" {
    var fake: FakeBootloader = .{};
    const boot = TestBoot.init(&fake, c031);
    const data = pattern(16);
    const end = flash_base + c031.flash_size;
    for ([_]u32{
        option_bytes_base, // the option bytes
        0x1FFF_0000, // system memory
        ram_base,
        flash_base - 16,
        flash_base - 8, // ends inside, starts outside
        end - 8, // starts inside, ends outside
        end,
        0xFFFF_FFF0,
    }) |a| {
        try testing.expectError(error.OutsideFlash, boot.write(a, &data));
    }
    // Nine bytes at the last 8 are padded to 16: past the end.
    try testing.expectError(error.OutsideFlash, boot.write(end - 8, data[0..9]));
    try testing.expectEqual(@as(u32, 0), fake.transactions);
    try fake.expectClean();
}

test "readMemory reads anywhere, the option bytes included, in chunks of 256" {
    var fake: FakeBootloader = .{};
    const boot = TestBoot.init(&fake, c031);
    var opt: [16]u8 = undefined;
    try boot.readMemory(option_bytes_base, &opt);
    try testing.expectEqualSlices(u8, fake.option_bytes[0..16], &opt);
    var big: [300]u8 = undefined;
    try boot.readMemory(flash_base + 100, &big);
    try testing.expectEqualSlices(u8, fake.mem[100..400], &big);
    // 7 transactions per Read Memory: one for the 16 bytes, 256 + 44 for the 300.
    try testing.expectEqual(@as(u32, 3 * 7), fake.transactions);
    try boot.readMemory(flash_base, &.{});
    try testing.expectEqual(@as(u32, 3 * 7), fake.transactions);
    try fake.expectClean();
}

/// The last 8 bytes of the fake's flash.
const trial_vector = flash_base + c031.flash_size - 8;

/// A token built by hand, which nothing in Zig prevents.
const forged: Tried = .{ .seal = .{ .len = 1000, .crc = 0 } };

/// Stage `img`, start it for its trial, and play the application's part:
/// erase `erased_pages`, then return to the bootloader.
fn tryOut(fake: *FakeBootloader, img: []const u8, erased_pages: []const u16) !Tried {
    const boot = TestBoot.init(fake, c031);
    const staged = try boot.stage(img);
    const tried = try boot.goTrial(staged);
    try fake.appRan(erased_pages);
    return tried;
}

/// The writes and the bytes read since event `from`, and whether a write
/// came before the reads were over.
const Since = struct { writes: usize, erases: usize, last_write: ?FakeBootloader.Chunk, read_before_first_write: usize, read_after_last_write: usize };

fn since(fake: *const FakeBootloader, from: usize) Since {
    var s: Since = .{ .writes = 0, .erases = 0, .last_write = null, .read_before_first_write = 0, .read_after_last_write = 0 };
    for (fake.events[from..fake.event_count]) |e| switch (e) {
        .write => |w| {
            s.writes += 1;
            s.last_write = w;
            s.read_after_last_write = 0;
        },
        .read => |r| {
            if (s.writes == 0) s.read_before_first_write += r.len;
            s.read_after_last_write += r.len;
        },
        .erase, .mass_erase => s.erases += 1,
        .go => {},
    };
    return s;
}

test "H4: after stage the first 8 bytes are erased and the trial vector holds them" {
    var fake: FakeBootloader = .{};
    const img = testImage(1000);
    _ = try TestBoot.init(&fake, c031).stage(&img);
    try testing.expect(allErased(fake.mem[0..8]));
    try testing.expectEqualSlices(u8, img[8..], fake.mem[8..1000]);
    try testing.expectEqualSlices(u8, img[0..8], fake.mem[c031.flash_size - 8 ..]);
    try testing.expect(allErased(fake.mem[1000 .. c031.flash_size - 8]));
    try testing.expect(!fake.wroteBase(0));
    // The rest written and read back, then the trial vector.
    try testing.expectEqualDeep(FakeBootloader.Event{ .write = .{ .addr = trial_vector, .len = 8 } }, fake.events[fake.event_count - 2]);
    try testing.expectEqualDeep(FakeBootloader.Event{ .read = .{ .addr = trial_vector, .len = 8 } }, fake.events[fake.event_count - 1]);
    try testing.expectEqual(@as(usize, 8 + 992 + 8), fake.read_bytes);
    try testing.expectEqual(@as(u32, 0), fake.gos);
    try fake.expectClean();
}

test "H5: goTrial goes to the trial vector, so the image starts on its own vectors with its first 8 bytes erased" {
    var fake: FakeBootloader = .{};
    const img = testImage(1000);
    const boot = TestBoot.init(&fake, c031);
    const staged = try boot.stage(&img);
    const from = fake.event_count;
    _ = try boot.goTrial(staged);
    // Before the Go it reads all of main flash but the first 8 bytes: the
    // trial vector, then everything from byte 8 up to the trial vector.
    try testing.expectEqualDeep(FakeBootloader.Event{ .read = .{ .addr = trial_vector, .len = 8 } }, fake.events[from]);
    const s = since(&fake, from);
    try testing.expectEqual(@as(usize, c031.flash_size - 8), s.read_before_first_write);
    try testing.expectEqualDeep(FakeBootloader.Event{ .go = trial_vector }, fake.events[fake.event_count - 1]);
    try testing.expectEqual(@as(u32, 1), fake.gos);
    try testing.expectEqual(@as(?u32, trial_vector), fake.go_to);
    try testing.expectEqualSlices(u8, img[0..8], &fake.go_vectors.?);
    try testing.expect(allErased(fake.mem[0..8]));
    try fake.expectClean();
}

test "H6: after a trial in which the image erased page 0, commit proves it, writes the 8 bytes at the base last, and start goes there" {
    const full = testImage(5000);
    for ([_]usize{ 10, 1000, 2048, 5000 }) |len| {
        const img = full[0..len];
        var fake: FakeBootloader = .{};
        const tried = try tryOut(&fake, img, &.{0});
        const from = fake.event_count;
        const boot = TestBoot.init(&fake, c031);
        try boot.commit(tried, img);
        const s = since(&fake, from);
        // Page 0, all of it, read back first.
        for (0..8) |i| {
            try testing.expectEqualDeep(FakeBootloader.Event{ .read = .{ .addr = flash_base + @as(u32, @intCast(i)) * max_block, .len = max_block } }, fake.events[from + i]);
        }
        // Before any write: page 0, the image past page 0, the trial vector.
        try testing.expectEqual(c031.page_size + (len -| c031.page_size) + 8, s.read_before_first_write);
        try testing.expectEqual(@as(usize, 0), s.erases);
        // The last write is the first 8 bytes, then the whole image is read back.
        try testing.expectEqualDeep(FakeBootloader.Chunk{ .addr = flash_base, .len = 8 }, s.last_write.?);
        try testing.expectEqual(paddedLen(@intCast(len)), s.read_after_last_write); // with its 0xFF padding
        try testing.expectEqualSlices(u8, img, fake.mem[0..len]);

        try boot.start();
        try testing.expectEqual(@as(?u32, flash_base), fake.go_to);
        try testing.expectEqualSlices(u8, img[0..8], &fake.go_vectors.?);
        try fake.expectClean();
    }
}

test "commit refuses an image other than the one staged and tried, before anything is sent" {
    const a = testImage(1000);
    var in_page_0 = a; // the review's A2: page 0 is erased by now, so the chip cannot show it
    in_page_0[500] ^= 0x01;
    var vectors = a;
    vectors[1] ^= 0x10; // another stack pointer, still in RAM
    var at_end = a;
    at_end[999] ^= 0x01;
    const shorter = a[0..900]; // A2b: the same vectors, less image
    for ([_][]const u8{ &in_page_0, &vectors, &at_end, shorter }) |other| {
        var fake: FakeBootloader = .{};
        const tried = try tryOut(&fake, &a, &.{0});
        const before = fake.transactions;
        const boot = TestBoot.init(&fake, c031);
        try testing.expectError(error.NotTheStagedImage, boot.commit(tried, other));
        try testing.expectEqual(before, fake.transactions);
        // The token still names the staged image.
        try boot.commit(tried, &a);
        try testing.expectEqualSlices(u8, &a, fake.mem[0..1000]);
        try fake.expectClean();
    }
}

test "goTrial sends no Go for a stale token whose image a later stage extended (the re-review's N1)" {
    // stage(A), stage(B) with A a prefix of B, goTrial(A's token): before,
    // the Go ran B and the commit then wrote A's page 0, which never ran.
    const full = testImage(5000);
    const Pair = struct { a: usize, b: usize };
    for ([_]Pair{
        .{ .a = 10, .b = 16 },
        .{ .a = 1000, .b = 1003 },
        .{ .a = 1000, .b = 1008 },
        .{ .a = 1000, .b = 2000 },
        .{ .a = 1000, .b = 5000 }, // the hybrid
        // The pairs the re-review found benign (the chip ended up holding B,
        // which was tried) are refused too: a stale token is a caller bug.
        .{ .a = 2048, .b = 2056 },
        .{ .a = 4096, .b = 5000 },
    }) |p| {
        var fake: FakeBootloader = .{};
        const boot = TestBoot.init(&fake, c031);
        const staged_a = try boot.stage(full[0..p.a]);
        _ = try boot.stage(full[0..p.b]);
        try testing.expectError(error.VerifyFailed, boot.goTrial(staged_a));
        try testing.expectEqual(@as(u32, 0), fake.gos);
        try fake.expectClean();
    }
}

test "goTrial sends no Go unless flash holds the staged image and nothing more" {
    const img = testImage(1003); // padded to 1008
    // A programmed byte in the padding, in the rest of page 0, in a later
    // page, and just below the trial vector.
    for ([_]usize{ 1005, 1500, 3000, c031.flash_size - 9 }) |at| {
        var fake: FakeBootloader = .{};
        const boot = TestBoot.init(&fake, c031);
        const staged = try boot.stage(&img);
        fake.mem[at] = 0x00;
        try testing.expectError(error.VerifyFailed, boot.goTrial(staged));
        try testing.expectEqual(@as(u32, 0), fake.gos);
        try fake.expectClean();
    }
    // The largest image ends at the trial vector: nothing left to check.
    const big = testImage(c031.flash_size - 8);
    var fake: FakeBootloader = .{};
    const boot = TestBoot.init(&fake, c031);
    _ = try boot.goTrial(try boot.stage(&big));
    try testing.expectEqual(@as(u32, 1), fake.gos);
    try fake.expectClean();
}

test "goTrial reads the staged image back first, and sends no Go if the chip no longer holds it" {
    const a = testImage(1000);
    var b = a;
    b[500] ^= 0x01;
    {
        // A stale token: A staged, then B over it, then A's token.
        var fake: FakeBootloader = .{};
        const boot = TestBoot.init(&fake, c031);
        const staged_a = try boot.stage(&a);
        _ = try boot.stage(&b);
        try testing.expectError(error.VerifyFailed, boot.goTrial(staged_a));
        try testing.expectEqual(@as(u32, 0), fake.gos);
        try fake.expectClean();
    }
    // A byte that changed after `stage`: in page 0, past it, at the trial vector.
    for ([_]usize{ 500, 999, c031.flash_size - 3 }) |at| {
        var fake: FakeBootloader = .{};
        const boot = TestBoot.init(&fake, c031);
        const staged = try boot.stage(&a);
        fake.mem[at] ^= 0x01;
        try testing.expectError(error.VerifyFailed, boot.goTrial(staged));
        try testing.expectEqual(@as(u32, 0), fake.gos);
        try fake.expectClean();
    }
    {
        // A token whose length no image can have: refused, nothing sent.
        var fake: FakeBootloader = .{};
        const boot = TestBoot.init(&fake, c031);
        for ([_]usize{ 0, 8, c031.flash_size - 7, std.math.maxInt(usize) }) |len| {
            try testing.expectError(error.NotTheStagedImage, boot.goTrial(.{ .seal = .{ .len = len, .crc = 0 } }));
        }
        try testing.expectEqual(@as(u32, 0), fake.transactions);
        try fake.expectClean();
    }
}

test "H6: commit on a chip whose page 0 is not blank gives error.NotBlank and writes nothing" {
    const img = testImage(1000);
    // The image erased nothing, or another page and not page 0.
    for ([_][]const u16{ &.{}, &.{3}, &.{15} }) |pages| {
        var fake: FakeBootloader = .{};
        const tried = try tryOut(&fake, &img, pages);
        const from = fake.event_count;
        try testing.expectError(error.NotBlank, TestBoot.init(&fake, c031).commit(tried, &img));
        try testing.expectEqual(@as(usize, 0), since(&fake, from).writes);
        try testing.expect(allErased(fake.mem[0..8]));
        try fake.expectClean();
    }
}

test "H6: commit on a chip whose later pages changed gives error.VerifyFailed, with the first 8 bytes still erased" {
    const img = testImage(5000); // pages 0 to 2
    // Page 0 and a page of the image; page 0 and the page of the trial vector.
    for ([_][]const u16{ &.{ 0, 2 }, &.{ 0, 1 }, &.{ 0, 15 } }) |pages| {
        var fake: FakeBootloader = .{};
        const tried = try tryOut(&fake, &img, pages);
        const from = fake.event_count;
        try testing.expectError(error.VerifyFailed, TestBoot.init(&fake, c031).commit(tried, &img));
        try testing.expectEqual(@as(usize, 0), since(&fake, from).writes);
        try testing.expect(allErased(fake.mem[0..8]));
        try fake.expectClean();
    }
    // Page 1 changed, for every length that reaches into it: from a single
    // byte past page 0 up to a whole chunk of it, and more.
    for ([_]usize{ 2049, 2056, 2304, 4096, 5000 }) |len| {
        var fake: FakeBootloader = .{};
        const tried = try tryOut(&fake, img[0..len], &.{ 0, 1 });
        const from = fake.event_count;
        try testing.expectError(error.VerifyFailed, TestBoot.init(&fake, c031).commit(tried, img[0..len]));
        try testing.expectEqual(@as(usize, 0), since(&fake, from).writes);
        try testing.expect(allErased(fake.mem[0..8]));
        try fake.expectClean();
    }
}

test "no Read Memory is shorter than 8 bytes, whatever the length of the image" {
    const full = testImage(2049);
    for ([_]usize{ 10, 15, 257, 1025, 1793, 2049 }) |len| {
        const img = full[0..len];
        var fake: FakeBootloader = .{}; // it refuses a read of fewer than 8 bytes
        const tried = try tryOut(&fake, img, &.{0});
        try TestBoot.init(&fake, c031).commit(tried, img);
        try testing.expectEqualSlices(u8, img, fake.mem[0..len]);
        for (fake.events[0..fake.event_count]) |e| switch (e) {
            .read => |r| try testing.expect(r.len >= 8 and r.len % 8 == 0),
            else => {},
        };
        try fake.expectClean();
    }
}

test "readMemory never asks for fewer than 8 bytes: a short request reads 8, a short tail reads the last 8" {
    var fake: FakeBootloader = .{};
    const boot = TestBoot.init(&fake, c031);
    var three: [3]u8 = undefined;
    try boot.readMemory(flash_base + 100, &three);
    try testing.expectEqualSlices(u8, fake.mem[100..103], &three);
    try fake.expectEvents(&.{.{ .read = .{ .addr = flash_base + 100, .len = 8 } }});
    var odd: [257]u8 = undefined;
    try boot.readMemory(flash_base + 100, &odd);
    try testing.expectEqualSlices(u8, fake.mem[100..357], &odd);
    try testing.expectEqualDeep(FakeBootloader.Event{ .read = .{ .addr = flash_base + 100, .len = 256 } }, fake.events[1]);
    try testing.expectEqualDeep(FakeBootloader.Event{ .read = .{ .addr = flash_base + 357 - 8, .len = 8 } }, fake.events[2]);
    try fake.expectClean();
}

test "the read-back covers the 0xFF padding after the image too" {
    const img = testImage(1003); // padded to 1008
    var fake: FakeBootloader = .{ .corrupt_at = flash_base + 1005 };
    try testing.expectError(error.VerifyFailed, TestBoot.init(&fake, c031).stage(&img));
    try testing.expect(allErased(fake.mem[0..8]));
    try fake.expectClean();
}

test "a wait where AN4221 has no BUSY is bounded too, and BUSY there never leads to a mass erase" {
    const img = testImage(1000);
    const Case = struct { op: Opcode, stage: FakeBootloader.Stage, skip: u32 = 0 };
    for ([_]Case{
        .{ .op = .get_id, .stage = .command },
        .{ .op = .get_id, .stage = .final }, // the ACK after the ID
        .{ .op = .erase_no_stretch, .stage = .command },
        .{ .op = .erase_no_stretch, .stage = .address }, // the page count of page 0
        .{ .op = .erase_no_stretch, .stage = .address, .skip = 1 }, // of the others
        .{ .op = .read_memory, .stage = .command },
        .{ .op = .read_memory, .stage = .address },
        .{ .op = .read_memory, .stage = .final }, // the read count
        .{ .op = .write_no_stretch, .stage = .command },
        .{ .op = .write_no_stretch, .stage = .address },
    }) |c| {
        var fake: FakeBootloader = .{ .busy_answers = 0, .stall = .{ .op = c.op, .stage = c.stage, .skip = c.skip } };
        try testing.expectError(error.Busy, TestBoot.init(&fake, c031).stage(&img));
        try testing.expectEqual(@as(u32, 1_000), fake.answer_reads);
        try testing.expectEqual(@as(u64, 1_000), fake.delayed_ms); // 1 ms a poll
        try testing.expectEqual(@as(u32, 0), fake.mass_erases);
        try testing.expect(!fake.wroteBase(0));
        try fake.expectClean();
    }
    for ([_]FakeBootloader.Stage{ .command, .address }) |stage| {
        var fake: FakeBootloader = .{};
        const boot = TestBoot.init(&fake, c031);
        const staged = try boot.stage(&img);
        fake.delayed_ms = 0;
        fake.stall = .{ .op = .go, .stage = stage };
        try testing.expectError(error.Busy, boot.goTrial(staged));
        try testing.expectEqual(@as(u32, 1_000), fake.answer_reads);
        try testing.expectEqual(@as(u64, 1_000), fake.delayed_ms); // 1 ms a poll
        try fake.expectClean();
    }
    // A stray byte at the page count is no NACK either.
    var fake: FakeBootloader = .{ .override = .{ .op = .erase_no_stretch, .stage = .address, .byte = 0x00 } };
    try testing.expectError(error.UnexpectedByte, TestBoot.init(&fake, c031).stage(&img));
    try testing.expectEqual(@as(u32, 0), fake.mass_erases);
    try fake.expectClean();
}

test "safe sequences stay safe: commit twice, commit with no stage, stage twice, stage on a committed chip" {
    const img = testImage(1000);
    {
        // Commit twice: the second finds page 0 programmed.
        var fake: FakeBootloader = .{};
        const tried = try tryOut(&fake, &img, &.{0});
        const boot = TestBoot.init(&fake, c031);
        try boot.commit(tried, &img);
        const from = fake.event_count;
        try testing.expectError(error.NotBlank, boot.commit(tried, &img));
        try testing.expectEqual(@as(usize, 0), since(&fake, from).writes);
        try fake.expectClean();
    }
    {
        // Commit with a token built by hand and no stage: on the old
        // content, then on an erased chip.
        const hand: Tried = .{ .seal = sealOf(&img) };
        var fake: FakeBootloader = .{};
        const boot = TestBoot.init(&fake, c031);
        try testing.expectError(error.NotBlank, boot.commit(hand, &img));
        @memset(&fake.mem, 0xFF);
        try testing.expectError(error.VerifyFailed, boot.commit(hand, &img));
        try testing.expectEqual(@as(usize, 0), since(&fake, 0).writes);
        try testing.expect(allErased(&fake.mem));
        try fake.expectClean();
    }
    {
        // A token built by hand for an image with other first 8 bytes: the
        // trial vector does not match.
        var other = img;
        other[1] ^= 0x10;
        var fake: FakeBootloader = .{};
        _ = try tryOut(&fake, &img, &.{0});
        const from = fake.event_count;
        try testing.expectError(error.VerifyFailed, TestBoot.init(&fake, c031).commit(.{ .seal = sealOf(&other) }, &other));
        try testing.expectEqual(@as(usize, 0), since(&fake, from).writes);
        try testing.expect(allErased(fake.mem[0..8]));
        try fake.expectClean();
    }
    {
        // Stage twice, then stage again over a committed chip: each starts
        // with page 0 alone, and leaves the chip uncommitted.
        var fake: FakeBootloader = .{};
        const boot = TestBoot.init(&fake, c031);
        _ = try boot.stage(&img);
        const tried = try tryOut(&fake, &img, &.{0});
        try boot.commit(tried, &img);
        const from = fake.event_count;
        _ = try boot.stage(&img);
        try testing.expectEqualDeep(FakeBootloader.Event{ .erase = .{ .first = 0, .count = 1 } }, fake.events[from]);
        try testing.expect(allErased(fake.mem[0..8]));
        try testing.expectEqualSlices(u8, img[0..8], fake.mem[c031.flash_size - 8 ..]);
        try fake.expectClean();
    }
}

test "H6: a byte of page 0 that comes out wrong in commit is found before the first 8 bytes are written" {
    const img = testImage(1000);
    var fake: FakeBootloader = .{};
    const tried = try tryOut(&fake, &img, &.{0});
    fake.corrupt_at = flash_base + 100;
    try testing.expectError(error.VerifyFailed, TestBoot.init(&fake, c031).commit(tried, &img));
    try testing.expect(!fake.wroteBase(0));
    try testing.expect(allErased(fake.mem[0..8]));
    try fake.expectClean();
}

test "the one window: a wrong first 8 bytes is found by commit's last read-back, after the chip is committed" {
    const img = testImage(1000);
    var fake: FakeBootloader = .{};
    const tried = try tryOut(&fake, &img, &.{0});
    fake.corrupt_at = flash_base + 3;
    try testing.expectError(error.VerifyFailed, TestBoot.init(&fake, c031).commit(tried, &img));
    try testing.expect(fake.wroteBase(0));
    try testing.expect(!allErased(fake.mem[0..8]));
    try fake.expectClean();
}

test "stage writes in chunks of at most 256 bytes at 8-byte-aligned addresses, the trial vector last" {
    var fake: FakeBootloader = .{};
    const img = testImage(1000);
    _ = try TestBoot.init(&fake, c031).stage(&img);
    try testing.expectEqual(@as(usize, 5), fake.chunk_count);
    const want = [_]FakeBootloader.Chunk{
        .{ .addr = flash_base + 8, .len = 256 },
        .{ .addr = flash_base + 264, .len = 256 },
        .{ .addr = flash_base + 520, .len = 256 },
        .{ .addr = flash_base + 776, .len = 224 },
        .{ .addr = trial_vector, .len = 8 },
    };
    for (want, fake.chunks[0..5]) |w, c| try testing.expectEqualDeep(w, c);
    try fake.expectClean();
}

test "an image whose length is not a multiple of 8 is padded with 0xFF" {
    var fake: FakeBootloader = .{};
    const img = testImage(1003);
    const tried = try tryOut(&fake, &img, &.{0});
    // 1003 - 8 - 768 = 227 bytes, padded to 232. The fake programs by AND,
    // so padding of anything but 0xFF would show.
    try testing.expectEqualDeep(FakeBootloader.Chunk{ .addr = flash_base + 776, .len = 232 }, fake.chunks[3]);
    try TestBoot.init(&fake, c031).commit(tried, &img);
    try testing.expectEqualSlices(u8, &img, fake.mem[0..1003]);
    try testing.expect(allErased(fake.mem[1003 .. c031.flash_size - 8]));
    try fake.expectClean();
}

test "an image of 10 to 16 bytes: a tail chunk padded with 0xFF, the trial vector, then in commit the tail again and the first 8 bytes" {
    for (10..17) |len| {
        var fake: FakeBootloader = .{};
        const full = testImage(16);
        const img = full[0..len];
        const tried = try tryOut(&fake, img, &.{0});
        try TestBoot.init(&fake, c031).commit(tried, img);
        try testing.expectEqual(@as(usize, 4), fake.chunk_count);
        try testing.expectEqualDeep(FakeBootloader.Chunk{ .addr = flash_base + 8, .len = 8 }, fake.chunks[0]);
        try testing.expectEqualDeep(FakeBootloader.Chunk{ .addr = trial_vector, .len = 8 }, fake.chunks[1]);
        try testing.expectEqualDeep(FakeBootloader.Chunk{ .addr = flash_base + 8, .len = 8 }, fake.chunks[2]);
        try testing.expectEqualDeep(FakeBootloader.Chunk{ .addr = flash_base, .len = 8 }, fake.chunks[3]);
        try testing.expectEqualSlices(u8, img, fake.mem[0..len]);
        try testing.expect(allErased(fake.mem[len .. c031.flash_size - 8]));
        try fake.expectClean();
    }
}

test "the largest image is staged, tried and committed whole" {
    const len = c031.flash_size - 8;
    const img = testImage(len);
    var fake: FakeBootloader = .{};
    const tried = try tryOut(&fake, &img, &.{0});
    try TestBoot.init(&fake, c031).commit(tried, &img);
    try testing.expectEqualSlices(u8, &img, fake.mem[0..len]);
    try testing.expectEqualDeep(FakeBootloader.Chunk{ .addr = flash_base, .len = 8 }, fake.chunks[fake.chunk_count - 1]);
    try fake.expectClean();

    var bad: FakeBootloader = .{ .corrupt_at = flash_base + len - 1 };
    try testing.expectError(error.VerifyFailed, TestBoot.init(&bad, c031).stage(&img));
    try testing.expect(allErased(bad.mem[0..8]));
    try bad.expectClean();
}

test "a stage that fails partway leaves the first 8 bytes erased, so the chip comes back in its bootloader" {
    const img = testImage(1000);
    // Writes 0 to 3 are the image from byte 8; write 4 is the trial vector.
    for (0..5) |w| {
        const skip: u32 = @intCast(w);
        var nacked: FakeBootloader = .{ .override = .{ .op = .write_no_stretch, .stage = .final, .skip = skip } };
        try testing.expectError(error.Refused, TestBoot.init(&nacked, c031).stage(&img));
        try testing.expectEqual(@as(usize, w), nacked.chunk_count);
        try testing.expect(allErased(nacked.mem[0..8]));
        try nacked.expectClean();

        // Get ID 4, erase of page 0 8, its check 7, erase of the others 8,
        // a chunk 8: the data frame of write `w` is transaction
        // 27 + 8 * w + 5.
        var silent: FakeBootloader = .{ .silent_after = 27 + 8 * skip + 4 };
        try testing.expectError(error.Nack, TestBoot.init(&silent, c031).stage(&img));
        try testing.expectEqual(@as(usize, w), silent.chunk_count);
        try testing.expect(allErased(silent.mem[0..8]));
        try silent.expectClean();
    }
}

test "a wrong product ID stops stage before the erase" {
    var fake: FakeBootloader = .{ .product_id = 0x443 }; // the C011's
    const img = testImage(1000);
    try testing.expectError(error.WrongProduct, TestBoot.init(&fake, c031).stage(&img));
    try testing.expectEqual(@as(u32, 0), fake.erases);
    try testing.expectEqual(@as(usize, 0), fake.chunk_count);
    try testing.expectEqual(@as(u32, 4), fake.transactions); // Get ID only
    try testing.expectEqual(old_content, fake.mem[0]);
    try fake.expectClean();
}

test "a Get ID answer with another byte count is an unexpected byte" {
    var fake: FakeBootloader = .{ .id_count = 2 };
    try testing.expectError(error.UnexpectedByte, TestBoot.init(&fake, c031).productId());
    try fake.expectClean();
}

test "a byte that comes out wrong in stage gives error.VerifyFailed, with the first 8 bytes erased" {
    const img = testImage(1000);
    for ([_]u32{ flash_base + 8, flash_base + 263, flash_base + 264, flash_base + 500, flash_base + 999, trial_vector, trial_vector + 7 }) |at| {
        var fake: FakeBootloader = .{ .corrupt_at = at };
        try testing.expectError(error.VerifyFailed, TestBoot.init(&fake, c031).stage(&img));
        try testing.expect(allErased(fake.mem[0..8]));
        try testing.expect(!fake.wroteBase(0));
        try fake.expectClean();
    }
}

test "BUSY forever gives error.Busy after the bound, not a hang" {
    {
        var fake: FakeBootloader = .{ .busy_forever = true };
        try testing.expectError(error.Busy, TestBoot.init(&fake, c031).massErase());
        try testing.expectEqual(@as(u32, 10_000), fake.answer_reads);
        try testing.expectEqual(@as(u64, 10_000), fake.delayed_ms); // 1 ms a poll
        try fake.expectClean();
    }
    {
        var fake: FakeBootloader = .{};
        const boot = TestBoot.init(&fake, c031);
        try boot.massErase();
        fake.busy_forever = true;
        fake.delayed_ms = 0;
        try testing.expectError(error.Busy, boot.write(flash_base, &pattern(16)));
        try testing.expectEqual(@as(u32, 1_000), fake.answer_reads);
        try testing.expectEqual(@as(u64, 1_000), fake.delayed_ms); // 1 ms a poll
        try fake.expectClean();
    }
    {
        var fake: FakeBootloader = .{ .busy_forever = true };
        const img = testImage(1000);
        try testing.expectError(error.Busy, TestBoot.init(&fake, c031).stage(&img));
        try fake.expectClean();
    }
    {
        var fake: FakeBootloader = .{};
        const img = testImage(1000);
        const tried = try tryOut(&fake, &img, &.{0});
        fake.busy_forever = true;
        try testing.expectError(error.Busy, TestBoot.init(&fake, c031).commit(tried, &img));
        try testing.expectEqual(@as(u32, 1_000), fake.answer_reads);
        try testing.expect(allErased(fake.mem[0..8]));
        try fake.expectClean();
    }
}

test "BUSY one answer short of the bound still succeeds, and exactly the bound fails" {
    var fake: FakeBootloader = .{ .busy_answers = erase_busy_tries - 1 };
    const boot = TestBoot.init(&fake, c031);
    try boot.massErase();
    try testing.expectEqual(@as(u32, 10_000), fake.answer_reads);

    fake.busy_answers = write_busy_tries - 1;
    try boot.write(flash_base, &pattern(8));
    try testing.expectEqual(@as(u32, 1_000), fake.answer_reads);

    fake.busy_answers = write_busy_tries;
    try testing.expectError(error.Busy, boot.write(flash_base + 8, &pattern(8)));
    try testing.expectEqual(@as(u32, 1_000), fake.answer_reads);
    try fake.expectClean();

    var fake2: FakeBootloader = .{ .busy_answers = erase_busy_tries };
    try testing.expectError(error.Busy, TestBoot.init(&fake2, c031).massErase());
    try testing.expectEqual(@as(u32, 10_000), fake2.answer_reads);
    try fake2.expectClean();
}

test "a NACK anywhere in stage stops it with error.Refused, the first 8 bytes never written" {
    const img = testImage(1000);
    const cases = [_]FakeBootloader.Override{
        .{ .op = .get_id, .stage = .command },
        .{ .op = .erase_no_stretch, .stage = .command },
        .{ .op = .erase_no_stretch, .stage = .command, .skip = 1 }, // pages 1 to 15
        .{ .op = .erase_no_stretch, .stage = .address, .skip = 1 },
        .{ .op = .erase_no_stretch, .stage = .final, .skip = 1 },
        .{ .op = .read_memory, .stage = .command }, // the check of page 0
        .{ .op = .write_no_stretch, .stage = .command, .skip = 1 },
        .{ .op = .write_no_stretch, .stage = .address, .skip = 2 },
        .{ .op = .write_no_stretch, .stage = .final, .skip = 3 },
        .{ .op = .read_memory, .stage = .command, .skip = 2 },
        .{ .op = .read_memory, .stage = .address, .skip = 3 },
        .{ .op = .read_memory, .stage = .final, .skip = 4 },
        .{ .op = .write_no_stretch, .stage = .final, .skip = 4 }, // the trial vector
        .{ .op = .read_memory, .stage = .final, .skip = 5 }, // its read-back
    };
    for (cases) |o| {
        var fake: FakeBootloader = .{ .override = o };
        try testing.expectError(error.Refused, TestBoot.init(&fake, c031).stage(&img));
        try testing.expectEqual(@as(?FakeBootloader.Override, null), fake.override); // it fired
        try testing.expect(!fake.wroteBase(0));
        try fake.expectClean();
    }
}

test "a NACK anywhere in commit before its last write leaves the first 8 bytes erased" {
    const img = testImage(1000);
    const cases = [_]FakeBootloader.Override{
        .{ .op = .read_memory, .stage = .command }, // the first read of page 0
        .{ .op = .read_memory, .stage = .final, .skip = 7 }, // the last read of page 0
        .{ .op = .read_memory, .stage = .final, .skip = 8 }, // the trial vector
        .{ .op = .write_no_stretch, .stage = .command },
        .{ .op = .write_no_stretch, .stage = .final, .skip = 3 },
        .{ .op = .read_memory, .stage = .final, .skip = 12 }, // the read-back of page 0
        .{ .op = .write_no_stretch, .stage = .final, .skip = 4 }, // the first 8 bytes
    };
    for (cases) |o| {
        var fake: FakeBootloader = .{};
        const tried = try tryOut(&fake, &img, &.{0});
        fake.override = o;
        try testing.expectError(error.Refused, TestBoot.init(&fake, c031).commit(tried, &img));
        try testing.expectEqual(@as(?FakeBootloader.Override, null), fake.override); // it fired
        try testing.expect(allErased(fake.mem[0..8]));
        try fake.expectClean();
    }
}

test "any answer other than ACK, NACK or BUSY is error.UnexpectedByte" {
    const img = testImage(1000);
    for ([_]u8{ 0x00, 0xFF, 0x7F }) |b| {
        var fake: FakeBootloader = .{ .override = .{ .op = .write_no_stretch, .stage = .final, .skip = 1, .byte = b } };
        try testing.expectError(error.UnexpectedByte, TestBoot.init(&fake, c031).stage(&img));
        try testing.expect(!fake.wroteBase(0));
        try fake.expectClean();
    }
}

test "a bootloader that goes silent at any point of stage: the bus error passes through, nothing follows, the chip stays uncommitted" {
    const img = testImage(300);
    var clean: FakeBootloader = .{};
    _ = try TestBoot.init(&clean, c031).stage(&img);
    try clean.expectClean();
    const total = clean.transactions;
    try testing.expect(total > 50);

    var k: u32 = 0;
    while (k < total) : (k += 1) {
        var fake: FakeBootloader = .{ .silent_after = k };
        try testing.expectError(error.Nack, TestBoot.init(&fake, c031).stage(&img));
        try testing.expectEqual(k + 1, fake.transactions);
        try testing.expect(!fake.wroteBase(0));
        if (fake.erases >= 1) try testing.expect(allErased(fake.mem[0..8]));
        try fake.expectClean();
    }
}

test "a bootloader that goes silent at any point of commit: a named error, and the first 8 bytes erased until their own write" {
    const img = testImage(3000);
    var after_trial: FakeBootloader = .{};
    const tried = try tryOut(&after_trial, &img, &.{0});
    const t0 = after_trial.transactions;
    const e0 = after_trial.event_count;
    var clean = after_trial;
    try TestBoot.init(&clean, c031).commit(tried, &img);
    try clean.expectClean();
    const total = clean.transactions - t0;
    try testing.expect(total > 50);

    var k: u32 = 0;
    while (k < total) : (k += 1) {
        var fake = after_trial;
        fake.silent_after = t0 + k;
        try testing.expectError(error.Nack, TestBoot.init(&fake, c031).commit(tried, &img));
        try testing.expectEqual(t0 + k + 1, fake.transactions);
        if (!fake.wroteBase(e0)) try testing.expect(allErased(fake.mem[0..8]));
        try fake.expectClean();
    }
}

test "a bootloader that goes silent in the middle of a chunk" {
    const img = testImage(1000);
    // Get ID 4, the two erases and the check 23, one chunk 5 + 3 answers:
    // the data frame of the second chunk written (at base + 264) is
    // transaction 27 + 8 + 5.
    var fake: FakeBootloader = .{ .silent_after = 27 + 8 + 4 };
    try testing.expectError(error.Nack, TestBoot.init(&fake, c031).stage(&img));
    try testing.expectEqual(@as(usize, 1), fake.chunk_count);
    var buf: [258]u8 = undefined;
    try testing.expectEqualDeep(wr(dataFrame(&buf, img[264..520])), fake.trace[27 + 8 + 4]); // the data frame failed
    try testing.expectEqual(@as(usize, 258), fake.trace[27 + 8 + 4].len);
    try testing.expect(allErased(fake.mem[0..8]));
    try testing.expectEqual(@as(usize, 27 + 8 + 5), fake.trace_len);
    try fake.expectClean();
}

test "the public interface has no way to write the first 8 bytes but commit, and no erase but uncommit" {
    // No `flash`, no `eraseAll`, no public `write`, `go`, `verify` or
    // `erasePages`.
    const want = [_][]const u8{ "BusError", "Failure", "init", "productId", "readMemory", "stage", "goTrial", "commit", "start", "uncommit" };
    const got = @typeInfo(TestBoot).@"struct".decl_names;
    try testing.expectEqual(want.len, got.len);
    inline for (want) |w| try testing.expect(@hasDecl(TestBoot, w));
    // And at file level: the frames of the first brief, which cannot reach
    // a bus, and the rest of the interface.
    const file = [_][]const u8{ "flash_base", "Part", "c031", "Error", "Staged", "Tried", "checkImage", "trialVector", "Bootloader", "addressFrame", "dataFrame" };
    const file_got = @typeInfo(@This()).@"struct".decl_names;
    try testing.expectEqual(file.len, file_got.len);
    inline for (file) |w| try testing.expect(@hasDecl(@This(), w));
    try testing.expectEqual(trial_vector, trialVector(c031));
}

test "H7: uncommit erases page 0 alone and reads its first 8 bytes back, and leaves the rest" {
    const img = testImage(5000);
    var fake: FakeBootloader = .{};
    const tried = try tryOut(&fake, &img, &.{0});
    const boot = TestBoot.init(&fake, c031);
    try boot.commit(tried, &img);
    const from = fake.event_count;
    try boot.uncommit();
    try testing.expectEqualDeep(FakeBootloader.Event{ .erase = .{ .first = 0, .count = 1 } }, fake.events[from]);
    try testing.expectEqualDeep(FakeBootloader.Event{ .read = .{ .addr = flash_base, .len = 8 } }, fake.events[from + 1]);
    try testing.expectEqual(from + 2, fake.event_count);
    try testing.expect(allErased(fake.mem[0..c031.page_size]));
    try testing.expectEqualSlices(u8, img[c031.page_size..], fake.mem[c031.page_size..5000]);
    try fake.expectClean();
}

test "H7: an uncommit that does not take is error.NotBlank; a refused page list falls back to the mass erase" {
    {
        var fake: FakeBootloader = .{ .erase_skips_page_0 = true };
        try testing.expectError(error.NotBlank, TestBoot.init(&fake, c031).uncommit());
        try testing.expectEqual(old_content, fake.mem[0]);
        try fake.expectClean();
    }
    {
        var fake: FakeBootloader = .{ .refuse_page_list = true };
        try TestBoot.init(&fake, c031).uncommit();
        try fake.expectEvents(&.{ .mass_erase, .{ .read = .{ .addr = flash_base, .len = 8 } } });
        try testing.expect(allErased(&fake.mem));
        try fake.expectClean();
    }
}

test "the documented limit: an uncommit between goTrial and commit stands in for the trial's own erase" {
    // The review's A3 now takes stage, goTrial, uncommit and commit in that
    // order: a deliberate act, which `commit` cannot tell from a trial.
    const img = testImage(1000);
    var fake: FakeBootloader = .{};
    const boot = TestBoot.init(&fake, c031);
    const staged = try boot.stage(&img);
    const tried = try boot.goTrial(staged);
    try fake.appRan(&.{}); // the image did nothing at all
    try boot.uncommit();
    try boot.commit(tried, &img);
    try testing.expectEqualSlices(u8, &img, fake.mem[0..1000]);
    try fake.expectClean();
}

test "write and verify of nothing send nothing" {
    var fake: FakeBootloader = .{};
    const boot = TestBoot.init(&fake, c031);
    try boot.write(flash_base, &.{});
    try boot.verify(flash_base, &.{});
    try testing.expectEqual(@as(u32, 0), fake.transactions);
    try fake.expectClean();
}

test "the fake bootloader NACKs and flags what the real one would refuse" {
    const a = c031.address;
    const get_id = @backingInt(Opcode.get_id);
    const go_op = @backingInt(Opcode.go);
    const write_op = @backingInt(Opcode.write_no_stretch);
    var b: [1]u8 = undefined;
    var buf: [258]u8 = undefined;
    {
        var f: FakeBootloader = .{};
        try f.write(a, &.{ get_id, 0x00 });
        try f.read(a, &b);
        try testing.expectEqual(nack, b[0]);
        try testing.expectEqual(@as(?FakeBootloader.Violation, .complement), f.violation);
    }
    {
        // A command this host has no business sending: Get Version.
        var f: FakeBootloader = .{};
        try f.write(a, &.{ 0x01, 0xFE });
        try f.read(a, &b);
        try testing.expectEqual(nack, b[0]);
        try testing.expectEqual(@as(?FakeBootloader.Violation, .unknown_command), f.violation);
    }
    {
        var f: FakeBootloader = .{};
        try f.write(a, &.{ go_op, ~go_op });
        try f.read(a, &b);
        var frame = addressFrame(flash_base);
        frame[4] ^= 0x01;
        try f.write(a, &frame);
        try f.read(a, &b);
        try testing.expectEqual(nack, b[0]);
        try testing.expectEqual(@as(?FakeBootloader.Violation, .address_checksum), f.violation);
    }
    {
        // A write to the option bytes.
        var f: FakeBootloader = .{};
        try f.write(a, &.{ write_op, ~write_op });
        try f.read(a, &b);
        try f.write(a, &addressFrame(option_bytes_base));
        try f.read(a, &b);
        try testing.expectEqual(nack, b[0]);
        try testing.expectEqual(@as(?FakeBootloader.Violation, .bad_address), f.violation);
    }
    {
        var f: FakeBootloader = .{};
        try f.write(a, &.{ write_op, ~write_op });
        try f.read(a, &b);
        try f.write(a, &addressFrame(flash_base + 4));
        try f.read(a, &b);
        try testing.expectEqual(nack, b[0]);
        try testing.expectEqual(@as(?FakeBootloader.Violation, .misaligned_address), f.violation);
    }
    {
        var f: FakeBootloader = .{ .busy_answers = 0 };
        try f.write(a, &.{ write_op, ~write_op });
        try f.read(a, &b);
        try f.write(a, &addressFrame(flash_base));
        try f.read(a, &b);
        try f.write(a, dataFrame(&buf, &.{ 1, 2, 3, 4 }));
        try f.read(a, &b);
        try testing.expectEqual(nack, b[0]);
        try testing.expectEqual(@as(?FakeBootloader.Violation, .misaligned_length), f.violation);
    }
    {
        var f: FakeBootloader = .{ .busy_answers = 0 };
        try f.write(a, &.{ write_op, ~write_op });
        try f.read(a, &b);
        try f.write(a, &addressFrame(flash_base));
        try f.read(a, &b);
        var frame = dataFrame(&buf, &pattern(8));
        buf[frame.len - 1] ^= 0x01;
        frame = buf[0..frame.len];
        try f.write(a, frame);
        try f.read(a, &b);
        try testing.expectEqual(nack, b[0]);
        try testing.expectEqual(@as(?FakeBootloader.Violation, .data_checksum), f.violation);
    }
    {
        // Programming flash that was not erased.
        var f: FakeBootloader = .{ .busy_answers = 0 };
        try f.write(a, &.{ write_op, ~write_op });
        try f.read(a, &b);
        try f.write(a, &addressFrame(flash_base));
        try f.read(a, &b);
        try f.write(a, dataFrame(&buf, &pattern(8)));
        try f.read(a, &b);
        try testing.expectEqual(nack, b[0]);
        try testing.expectEqual(@as(?FakeBootloader.Violation, .not_erased), f.violation);
    }
    {
        // Page-list erases: each frame's checksum, the page range, the
        // count limit, and (this host's own rule) consecutive pages.
        const erase_op = @backingInt(Opcode.erase_no_stretch);
        const Case = struct { count: []const u8, list: ?[]const u8, v: FakeBootloader.Violation };
        for ([_]Case{
            .{ .count = &.{ 0x00, 0x00, 0x01 }, .list = null, .v = .erase_checksum },
            .{ .count = &.{ 0x02, 0x00, 0x02 }, .list = null, .v = .too_many_pages }, // 513 pages
            .{ .count = &.{ 0x00, 0x00, 0x00 }, .list = &.{ 0x00, 0x00, 0x01 }, .v = .page_list_checksum },
            .{ .count = &.{ 0x00, 0x00, 0x00 }, .list = &.{ 0x00, 0x10, 0x10 }, .v = .bad_page }, // page 16
        }) |c| {
            var f: FakeBootloader = .{ .busy_answers = 0 };
            try f.write(a, &.{ erase_op, ~erase_op });
            try f.read(a, &b);
            try f.write(a, c.count);
            try f.read(a, &b);
            if (c.list) |list| {
                try testing.expectEqual(ack, b[0]);
                try f.write(a, list);
                try f.read(a, &b);
            }
            try testing.expectEqual(nack, b[0]);
            try testing.expectEqual(@as(?FakeBootloader.Violation, c.v), f.violation);
            try testing.expectEqual(@as(u32, 0), f.erases);
        }
        var f: FakeBootloader = .{};
        try f.write(a, &.{ erase_op, ~erase_op });
        try f.read(a, &b);
        try f.write(a, &.{ 0x00, 0x01, 0x01 });
        try f.read(a, &b);
        try testing.expectError(error.ProtocolViolation, f.write(a, &.{ 0x00, 0x02, 0x00, 0x01, 0x03 }));
        try testing.expectEqual(@as(?FakeBootloader.Violation, .page_order), f.violation);
    }
    {
        // Get ID answers three bytes, read in one go.
        var f: FakeBootloader = .{};
        try f.write(a, &.{ get_id, ~get_id });
        try f.read(a, &b);
        var two: [2]u8 = undefined;
        try testing.expectError(error.ProtocolViolation, f.read(a, &two));
        try testing.expectEqual(@as(?FakeBootloader.Violation, .wrong_read_length), f.violation);
    }
    {
        // A read where the bootloader waits for a command.
        var f: FakeBootloader = .{};
        try testing.expectError(error.ProtocolViolation, f.read(a, &b));
        try testing.expectEqual(@as(?FakeBootloader.Violation, .out_of_place), f.violation);
    }
    {
        // A frame while the bootloader has an answer to give.
        var f: FakeBootloader = .{};
        try f.write(a, &.{ get_id, ~get_id });
        try testing.expectError(error.ProtocolViolation, f.write(a, &.{ get_id, ~get_id }));
        try testing.expectEqual(@as(?FakeBootloader.Violation, .out_of_place), f.violation);
    }
    {
        // A transaction to another address.
        var f: FakeBootloader = .{};
        try testing.expectError(error.ProtocolViolation, f.write(0x42, &.{ get_id, ~get_id }));
        try testing.expectEqual(@as(?FakeBootloader.Violation, .wrong_device), f.violation);
    }
}

/// Write Protect, No-Stretch Write Protect, Write Unprotect and its twin,
/// Readout Protect and its twin, Readout Unprotect and its twin (AN4221
/// Table 2), spelled in decimal so that the scan below does not find this
/// list.
const forbidden_opcodes = [_]u8{ 99, 100, 115, 116, 130, 131, 146, 147 };
/// A line holding a forbidden value that is not an opcode says so with
/// these words, as the I2C address line of `c031` does.
const not_an_opcode = "not an opcode";

/// Hex literals in `source` whose value is a forbidden opcode or its
/// complement, on lines that do not say they are not an opcode.
fn forbiddenLiterals(source: []const u8, report: bool) usize {
    var found: usize = 0;
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |line| {
        if (std.mem.indexOf(u8, line, not_an_opcode) != null) continue;
        var i: usize = 0;
        while (i < line.len) {
            if (!isWordByte(line[i])) {
                i += 1;
                continue;
            }
            const start = i;
            while (i < line.len and isWordByte(line[i])) i += 1;
            const token = line[start..i];
            if (token.len < 3 or token[0] != '0' or (token[1] != 'x' and token[1] != 'X')) continue;
            const value = std.fmt.parseInt(u64, token[2..], 16) catch continue;
            for (forbidden_opcodes) |op| {
                if (value == op or value == ~op) {
                    if (report) std.debug.print("forbidden opcode literal: {s}\n", .{line});
                    found += 1;
                }
            }
        }
    }
    return found;
}

fn isWordByte(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_';
}

test "no protection or option-byte command can be sent, and the file names none" {
    // `command` takes an `Opcode`, and none of its values is forbidden.
    inline for (@typeInfo(Opcode).@"enum".field_values) |v| {
        for (forbidden_opcodes) |op| try testing.expect(v != op);
    }
    // The scan finds one when there is one, in either case, with digit
    // separators, and as a complement; a line that says it is not an
    // opcode is let through. (The samples are split so that the scan of
    // this file does not find them.)
    try testing.expectEqual(@as(usize, 1), forbiddenLiterals("const cmd_readout_protect: u8 = 0" ++ "x82;", false));
    try testing.expectEqual(@as(usize, 1), forbiddenLiterals("try self.io.write(a, &.{ 0" ++ "x9c, 0x00 });", false));
    try testing.expectEqual(@as(usize, 2), forbiddenLiterals("const x = .{ 0" ++ "x0_93, 0" ++ "X7D };", false));
    try testing.expectEqual(@as(usize, 0), forbiddenLiterals("address: u7 = 0" ++ "x63, // " ++ not_an_opcode, false));
    try testing.expectEqual(@as(usize, 0), forbiddenLiterals("const base: u32 = 0" ++ "x0800_0093;", false));
    // And this file has none.
    try testing.expectEqual(@as(usize, 0), forbiddenLiterals(@embedFile("stm32_i2c_boot.zig"), true));
}

/// An `Io` held by value, as a bus adapter that wraps a pointer would be.
const ByValue = struct {
    fake: *FakeBootloader,

    pub const Error = FakeBootloader.Error;

    pub fn write(self: ByValue, address: u7, bytes: []const u8) FakeBootloader.Error!void {
        return self.fake.write(address, bytes);
    }
    pub fn read(self: ByValue, address: u7, rx: []u8) FakeBootloader.Error!void {
        return self.fake.read(address, rx);
    }
    pub fn delayMs(self: ByValue, ms: u32) void {
        self.fake.delayMs(ms);
    }
};

test "an Io held by value works as well as a pointer, and bus errors keep their names" {
    var fake: FakeBootloader = .{};
    const boot = Bootloader(ByValue).init(.{ .fake = &fake }, c031);
    try testing.expectEqual(@as(u16, 0x453), try boot.productId());
    try fake.expectClean();

    // The bus's errors and this file's, under their own names.
    const E = Bootloader(ByValue).Failure;
    inline for (.{ "Nack", "ProtocolViolation", "Refused", "UnexpectedByte", "Busy", "WrongProduct", "VerifyFailed", "OutsideFlash", "NotAnImage", "NotBlank" }) |name| {
        try testing.expect(comptime hasError(E, name));
        try testing.expect(comptime hasError(TestBoot.Failure, name));
    }
    // The bootloader's NACK has a name of its own, so it can never merge
    // with a bus's `Nack` (Zig error names are global).
    try testing.expect(comptime !hasError(Error, "Nack"));
}

fn hasError(comptime E: type, comptime name: []const u8) bool {
    for (@typeInfo(E).error_set.error_names.?) |n| if (std.mem.eql(u8, n, name)) return true;
    return false;
}
