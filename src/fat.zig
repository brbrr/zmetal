//! FatFs filesystem on the SD card: a `fatfs.Disk` backed by the SDMMC block
//! driver, plus a small facade over zfat (mount + read/write helpers).
//!
//! `sdmmc.init()` must succeed before `mount()` — the disk `initialize` callback
//! assumes an identified card. Paths are drive-qualified, e.g. `"0:/DIR/FILE.TXT"`.

const std = @import("std");
const fatfs = @import("zfat");
const sdmmc = @import("microzig").hal.sdmmc;

/// Re-exports for callers that need the full zfat API (seeking, directories,
/// incremental I/O) beyond the `readFile`/`writeFile` helpers below.
pub const Path = fatfs.Path;
pub const File = fatfs.File;
pub const Dir = fatfs.Dir;

// --- Disk adapter (SDMMC block driver -> fatfs.Disk) ------------------------

fn diskStatus(_: *fatfs.Disk) fatfs.Disk.Status {
    const present = sdmmc.blockCount() != 0;
    return .{ .initialized = present, .disk_present = present, .write_protected = false };
}

fn diskInitialize(self: *fatfs.Disk) fatfs.Disk.Error!fatfs.Disk.Status {
    // The card is identified by sdmmc.init() during board bring-up; here we only
    // report its state.
    if (sdmmc.blockCount() == 0) return fatfs.Disk.Error.DiskNotReady;
    return diskStatus(self);
}

fn diskRead(_: *fatfs.Disk, buff: [*]u8, sector: u32, count: u32) fatfs.Disk.Error!void {
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        const dst: *[512]u8 = @ptrCast(buff + i * 512);
        sdmmc.readBlock(sector + i, dst) catch return fatfs.Disk.Error.IoError;
    }
}

fn diskWrite(_: *fatfs.Disk, buff: [*]const u8, sector: u32, count: u32) fatfs.Disk.Error!void {
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        const src: *const [512]u8 = @ptrCast(buff + i * 512);
        sdmmc.writeBlock(sector + i, src) catch return fatfs.Disk.Error.IoError;
    }
}

fn diskIoctl(_: *fatfs.Disk, cmd: fatfs.IoCtl, buff: [*]u8) fatfs.Disk.Error!void {
    switch (cmd) {
        .sync => {}, // writeBlock waits out card programming; nothing is cached
        .get_sector_count => @as(*align(1) fatfs.LBA, @ptrCast(buff)).* = sdmmc.blockCount(),
        .get_sector_size => @as(*align(1) u16, @ptrCast(buff)).* = 512,
        .get_block_size => @as(*align(1) u32, @ptrCast(buff)).* = 1, // erase-block size unknown
        else => return fatfs.Disk.Error.InvalidParameter,
    }
}

var disk: fatfs.Disk = .{
    .getStatusFn = diskStatus,
    .initializeFn = diskInitialize,
    .readFn = diskRead,
    .writeFn = diskWrite,
    .ioctlFn = diskIoctl,
};

var fs: fatfs.FileSystem = undefined;
var mounted = false;

// --- Filesystem facade ------------------------------------------------------

/// Register the SD block device and mount volume 0. Idempotent.
/// `sdmmc.init()` must have succeeded first.
pub fn mount() !void {
    if (mounted) return;
    fatfs.disks[0] = &disk;
    try fs.mount("0:", true);
    mounted = true;
}

/// Unmount volume 0.
pub fn unmount() !void {
    if (!mounted) return;
    try fatfs.FileSystem.unmount("0:");
    mounted = false;
}

/// Open `path` read-only, read up to `dst.len` bytes, close. Returns bytes read.
pub fn readFile(path: Path, dst: []u8) !usize {
    var file = try File.openRead(path);
    defer file.close();
    return try file.read(dst);
}

/// Create (truncating any existing file) `path`, write `bytes`, close (which
/// flushes the FAT + directory entry). Returns bytes written.
pub fn writeFile(path: Path, bytes: []const u8) !usize {
    var file = try File.create(path);
    defer file.close();
    return try file.write(bytes);
}

// --- Debug self-test --------------------------------------------------------
//
// On-demand bring-up aid: wire `fat.selfTest()` into main after `mount()` and
// read `fat.last_selftest` over SWD. Both are stripped from the image unless
// `selfTest` is actually referenced, so they cost nothing in normal builds.

pub const SelfTest = struct {
    written: u32 = 0,
    read: u32 = 0,
    match: bool = false, // readback == payload
    readback: [32]u8 = @splat(0),
};
pub var last_selftest: SelfTest = .{};

/// Round-trip create -> write -> reopen -> read -> verify on `0:/ZMETAL.TXT`,
/// recording the outcome in `last_selftest`. Faults on any I/O error. Requires a
/// successful `mount()`.
pub fn selfTest() !void {
    const path: Path = "0:/ZMETAL.TXT";
    const payload = "zmetal fatfs selftest 42";
    var r: SelfTest = .{};
    r.written = @intCast(try writeFile(path, payload));
    r.read = @intCast(try readFile(path, &r.readback));
    r.match = std.mem.eql(u8, r.readback[0..r.read], payload);
    last_selftest = r;
}
