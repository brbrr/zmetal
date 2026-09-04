const std = @import("std");
const microzig = @import("microzig");
const STM32H750x = @import("stm32h7/STM32H750x.zig");

const MicroBuild = microzig.MicroBuild(.{
    .stm32 = true,
});

fn addTinyUsb(b: *std.Build, root: *std.Build.Module) void {
    const tu = "lib/tinyusb/src/";
    const sources = [_][]const u8{
        tu ++ "tusb.c",
        tu ++ "common/tusb_fifo.c",
        tu ++ "device/usbd.c",
        tu ++ "class/cdc/cdc_device.c",
        tu ++ "class/midi/midi_device.c",
        tu ++ "class/audio/audio_device.c",
        tu ++ "portable/synopsys/dwc2/dcd_dwc2.c",
        tu ++ "portable/synopsys/dwc2/dwc2_common.c",
        "lib/tinyusb_shim/usb_glue.c",
        "lib/tinyusb_shim/usb_audio_glue.c",
    };
    for (sources) |src| {
        root.addCSourceFile(.{ .file = b.path(src), .flags = &.{
            "-std=c11",
            "-DCFG_TUSB_MCU=OPT_MCU_STM32H7",
        } });
    }
    root.addIncludePath(b.path("lib/tinyusb/src"));
    root.addIncludePath(b.path("lib/tinyusb_shim"));
    // TinyUSB does intentional type-punning / unaligned packed-struct access that
    // Zig's C UBSan flags; with `.trap` those become `udf` -> UsageFault(UNDEFINSTR)
    // on real hardware (e.g. in usbd.c during enumeration). `.off` disables the
    // checks entirely (no UBSan runtime either, so no size cost) — TinyUSB is a
    // mature, widely-deployed stack, so we trust it here.
    root.sanitize_c = .off;
}

const TargetConfig = struct {
    name: []const u8,
    linker_script: []const u8,
    step_name: []const u8,
    step_description: []const u8,
    /// Root/entry source file. Defaults to the application; test firmwares
    /// (e.g. test/usb_loopback.zig) override this with their own root.
    root_source: []const u8 = "src/main.zig",
};

/// Recursively set the optimize mode on a module and every module it imports,
/// using `visited` to break the import cycles in the microzig graph (core<->cpu,
/// etc.). Used to build the microzig framework + HAL optimized while leaving the
/// application's root module in Debug.
fn setTreeOptimize(
    mod: *std.Build.Module,
    optimize: std.builtin.OptimizeMode,
    visited: *std.AutoHashMap(*std.Build.Module, void),
) void {
    if (visited.contains(mod)) return;
    visited.put(mod, {}) catch @panic("OOM");
    mod.optimize = optimize;
    for (mod.import_table.values()) |dep| {
        setTreeOptimize(dep, optimize, visited);
    }
}

const common_memory_regions = [_]microzig.MemoryRegion{
    .{ .name = "ITCMRAM", .tag = .ram, .offset = 0x00000000, .length = 0x10000, .access = .rwx },
    .{ .name = "FLASH", .tag = .flash, .offset = 0x08000000, .length = 0x20000, .access = .rx },
    .{ .name = "DTCMRAM", .tag = .ram, .offset = 0x20000000, .length = 0x20000, .access = .rwx },
    .{ .name = "SRAM", .tag = .ram, .offset = 0x24000000, .length = 0x80000, .access = .rwx },
    .{ .name = "RAM_D2", .tag = .ram, .offset = 0x30000000, .length = 0x48000, .access = .rwx },
    .{ .name = "RAM_D3", .tag = .ram, .offset = 0x38000000, .length = 0x10000, .access = .rwx },
    .{ .name = "BACKUP_SRAM", .tag = .ram, .offset = 0x38800000, .length = 0x1000, .access = .rwx },
    .{ .name = "SDRAM", .tag = .ram, .offset = 0xc0000000, .length = 0x4000000, .access = .rwx },
    .{ .name = "QSPIFLASH", .tag = .flash, .offset = 0x90040000, .length = 0x7C0000, .access = .rx },
};

fn buildTargetVariant(
    b: *std.Build,
    mb: *MicroBuild,
    clockhelper_dep: *std.Build.Module,
    zfat_mod: *std.Build.Module,
    config: TargetConfig,
    optimize: std.builtin.OptimizeMode,
    build_opts: *std.Build.Step.Options,
) *std.Build.Step {
    const stm32_common_mod = b.createModule(.{
        .root_source_file = b.path("lib/microzig/port/stmicro/stm32/src/hals/common.zig"),
    });

    const hal_imports = b.allocator.alloc(std.Build.Module.Import, 2) catch @panic("out of memory");
    hal_imports[0] = .{ .name = "stm32_common", .module = stm32_common_mod };
    hal_imports[1] = .{ .name = "ClockTree", .module = clockhelper_dep };

    // Use microzig's built-in STM32H750IB chip (register definitions) but keep
    // our own HAL, custom SRAM/flash linker script, and _estack-based stack.
    const firmware = mb.add_firmware(.{
        .name = config.name,
        .target = mb.ports.stm32.chips.STM32H750IB.derive(.{
            .hal = .{
                .root_source_file = b.path("src/hal/STM32H750/hal.zig"),
                .imports = hal_imports,
            },
            .linker_script = .{ .generate = .none, .file = b.path(config.linker_script) },
            .stack = .{ .symbol_name = "_estack" },
        }),
        // .target = target,
        .optimize = optimize, // was hardcoded .Debug; honor -Doptimize (test ReleaseFast for D-cache)
        .root_source_file = b.path(config.root_source),
    });

    // In Debug, keep the application (root module: main.zig + dsp/hid/drivers)
    // debuggable but build the microzig framework + HAL optimized, otherwise the
    // unoptimized firmware does not fit the 128 KB internal flash. Reachable from
    // firmware.core_mod (cpu/chip/hal/drivers); the root module is NOT in that
    // graph (root imports core, not vice versa), so it stays Debug.
    if (optimize == .Debug) {
        var visited = std.AutoHashMap(*std.Build.Module, void).init(b.allocator);
        setTreeOptimize(firmware.core_mod, .ReleaseSafe, &visited);
    }

    // FatFs bindings (zfat) for the SD card. Imported into the application root
    // module; the module carries the vendored FatFs C compilation.
    firmware.exe.root_module.addImport("zfat", zfat_mod);

    // TinyUSB device stack (CDC + MIDI) for the on-board USB port; compiled into
    // the application root module (main.zig -> hal.usb / hid.midi_io use it).
    addTinyUsb(b, firmware.exe.root_module);

    // Compile-time build config exposed to the app as `@import("build_config")`
    // (e.g. -Dusb-audio routes USB Audio to the SAI callback instead of the synth).
    firmware.exe.root_module.addOptions("build_config", build_opts);

    // Display driver (ui.zig + ili9341 + font tables) as its own module, built
    // optimized even in Debug app builds. Its pixel loops and font tables are
    // large when unoptimized; keeping them ReleaseSafe lets the Debug app + the
    // display + FatFs file I/O all fit the 128 KB internal flash. It only depends
    // on std + microzig, so it shares the app's microzig instance for ABI parity.
    const display_optimize: std.builtin.OptimizeMode = if (optimize == .Debug) .ReleaseSafe else optimize;
    const ui_mod = b.createModule(.{
        .root_source_file = b.path("src/ui.zig"),
        .target = firmware.exe.root_module.resolved_target,
        .optimize = display_optimize,
    });
    ui_mod.addImport("microzig", firmware.exe.root_module.import_table.get("microzig").?);
    firmware.exe.root_module.addImport("ui", ui_mod);

    const install = mb.add_install_firmware(firmware, .{ .format = .elf });
    const install_bin = mb.add_install_firmware(firmware, .{ .format = .binary });

    stm32_common_mod.addImport("microzig", firmware.core_mod);

    const report = b.addSystemCommand(&.{
        "python3",
        "build_tools/memory_report.py",
    });
    report.addFileArg(firmware.get_emitted_elf());
    // report.addFileArg(firmware.get_emitted_bin(.binary));
    report.addArg(config.name);
    report.addArg(config.linker_script);
    report.step.dependOn(&install.step);
    report.step.dependOn(&install_bin.step);

    const build_step = b.step(config.step_name, config.step_description);
    build_step.dependOn(&report.step);

    return &report.step;
}

pub fn build(b: *std.Build) void {
    // ========================================================================
    // Build Commands:
    //   zig build       -> SRAM mode (bootloader) [DEFAULT]
    //   zig build sram  -> SRAM mode (bootloader) [explicit]
    //   zig build flash -> Flash mode (direct, no bootloader)
    //   zig build hwtest -Dtest=<name> -> one HW test from src/test/<name>.zig
    // ========================================================================

    const mz_dep = b.dependency("microzig", .{});
    const mb = MicroBuild.init(b, mz_dep) orelse return;
    const clockhelper_dep = b.dependency("ClockHelper", .{}).module("clockhelper");
    const optimize = b.standardOptimizeOption(.{});

    const usb_audio = b.option(bool, "usb-audio", "Route USB Audio (UAC2) to the SAI codec instead of the synth") orelse false;
    const build_opts = b.addOptions();
    build_opts.addOption(bool, "usb_audio", usb_audio);

    // FatFs bindings; the module compiles the vendored FatFs C for the firmware
    // target when imported. Config is spelled out rather than left to defaults:
    //   - ReleaseSafe keeps the FatFs C compact.
    //   - static RTC: the board has no wall clock, and it keeps zfat off the
    //     removed std.time.timestamp() path (get_fattime returns a fixed date).
    //   - long_file_name = false: 8.3 names only.
    //   - no mkfs/exfat/find/chmod: unused APIs, kept out of flash.
    const zfat_mod = b.dependency("zfat", .{
        .optimize = .ReleaseSafe,
        .@"static-rtc" = @as([]const u8, "2026-01-01"),
        .read_only = false, // we create/write files
        .long_file_name = false, // 8.3 only — no Unicode tables
        .mkfs = false, // no on-device formatting
        .exfat = false, // FAT/FAT32 only
        .find = false, // no f_findfirst/next
    }).module("zfat");
    // Trap on C UB instead of linking the UBSan runtime (see zfat/build.zig):
    // the runtime's value formatter would drag ~90 KB of float formatting into
    // the 128 KB internal flash. `.trap` keeps UB detection at ~zero size.
    zfat_mod.sanitize_c = .trap;
    // Freestanding (no libc): supply the <string.h> + strchr/strlen the FatFs C
    // needs. mem* come from compiler_rt; malloc/free aren't used at FF_USE_LFN=0.
    zfat_mod.addIncludePath(b.path("lib/zfat_shim"));
    zfat_mod.addCSourceFile(.{ .file = b.path("lib/zfat_shim/shim.c"), .flags = &.{"-std=c11"} });

    const flash_report = buildTargetVariant(b, mb, clockhelper_dep, zfat_mod, .{
        .name = "blinky-flash",
        .linker_script = "src/ld/flash.ld",
        .step_name = "flash",
        .step_description = "Build firmware for internal flash (direct mode)",
    }, optimize, build_opts);

    const sram_report = buildTargetVariant(b, mb, clockhelper_dep, zfat_mod, .{
        .name = "blinky-sram",
        .linker_script = "src/ld/sram.ld",
        .step_name = "sram",
        .step_description = "Build firmware for SRAM (bootloader mode)",
    }, optimize, build_opts);

    _ = sram_report;

    // On-hardware test firmwares live in `src/test/<name>.zig`, each its own
    // entry point. `zig build hwtest -Dtest=<name>` builds exactly one, forced
    // ReleaseSafe so it fits the 128 KB internal flash. Artifact:
    // `zig-out/firmware/<name>.elf`. Defaults to usb_loopback.
    const hwtest_name = b.option([]const u8, "test", "HW test to build from src/test/<name>.zig (e.g. -Dtest=usb_loopback)") orelse "usb_loopback";
    _ = buildTargetVariant(b, mb, clockhelper_dep, zfat_mod, .{
        .name = hwtest_name,
        .linker_script = "src/ld/flash.ld",
        .step_name = "hwtest",
        .step_description = "Build one HW test firmware: zig build hwtest -Dtest=<name>",
        .root_source = b.fmt("src/test/{s}.zig", .{hwtest_name}),
    }, .ReleaseSafe, build_opts);

    b.getInstallStep().dependOn(flash_report);
    // b.getInstallStep().dependOn(sram_report);
}
