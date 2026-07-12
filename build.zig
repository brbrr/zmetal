const std = @import("std");
const microzig = @import("microzig");
const STM32H750x = @import("stm32h7/STM32H750x.zig");

const MicroBuild = microzig.MicroBuild(.{
    .stm32 = true,
});

const TargetConfig = struct {
    name: []const u8,
    linker_script: []const u8,
    step_name: []const u8,
    step_description: []const u8,
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

fn createSTM32Target(
    b: *std.Build,
    mz_dep: *std.Build.Dependency,
    linker_script: []const u8,
    stm32_common_mod: *std.Build.Module,
    clockhelper_dep: *std.Build.Module,
) *microzig.Target {
    const memory_regions = b.allocator.dupe(microzig.MemoryRegion, &common_memory_regions) catch @panic("out of memory");

    const hal_imports = b.allocator.alloc(std.Build.Module.Import, 2) catch @panic("out of memory");
    hal_imports[0] = .{ .name = "stm32_common", .module = stm32_common_mod };
    hal_imports[1] = .{ .name = "ClockTree", .module = clockhelper_dep };

    const target = b.allocator.create(microzig.Target) catch @panic("out of memory");
    target.* = .{
        .dep = mz_dep,
        .preferred_binary_format = .elf,
        .zig_target = .{
            .cpu_arch = .thumb,
            .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m7 },
            .os_tag = .freestanding,
            .cpu_features_add = std.Target.arm.featureSet(&.{.fp_armv8d16sp}),
            .abi = .eabihf,
        },
        .chip = .{
            .name = "STM32H750IB",
            .register_definition = .{ .zig = b.path("./stm32h7/STM32H750x.zig") },
            .memory_regions = memory_regions,
        },
        .stack = .{ .symbol_name = "_estack" },
        .linker_script = .{
            .generate = .none,
            .file = b.path(linker_script),
        },
        .hal = .{
            .root_source_file = b.path("src/hal/STM32H750/hal.zig"),
            .imports = hal_imports,
        },
    };
    return target;
}

fn buildTargetVariant(
    b: *std.Build,
    mb: *MicroBuild,
    mz_dep: *std.Build.Dependency,
    clockhelper_dep: *std.Build.Module,
    zfat_mod: *std.Build.Module,
    config: TargetConfig,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step {
    const stm32_common_mod = b.createModule(.{
        .root_source_file = b.path("lib/microzig/port/stmicro/stm32/src/hals/common.zig"),
    });

    // const target = createSTM32Target(b, mz_dep, config.linker_script, stm32_common_mod, clockhelper_dep);
    //

    _ = mz_dep;
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
        .root_source_file = b.path("src/main.zig"),
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
    // ========================================================================

    const mz_dep = b.dependency("microzig", .{});
    const mb = MicroBuild.init(b, mz_dep) orelse return;
    const clockhelper_dep = b.dependency("ClockHelper", .{}).module("clockhelper");
    const optimize = b.standardOptimizeOption(.{});

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
    zfat_mod.addCSourceFile(.{ .file = b.path("lib/zfat_shim/shim.c"), .flags = &.{"-std=c99"} });

    const flash_report = buildTargetVariant(b, mb, mz_dep, clockhelper_dep, zfat_mod, .{
        .name = "blinky-flash",
        .linker_script = "src/ld/daisy_flash.ld",
        .step_name = "flash",
        .step_description = "Build firmware for internal flash (direct mode)",
    }, optimize);

    const sram_report = buildTargetVariant(b, mb, mz_dep, clockhelper_dep, zfat_mod, .{
        .name = "blinky-sram",
        .linker_script = "src/ld/daisy_sram.ld",
        .step_name = "sram",
        .step_description = "Build firmware for SRAM (bootloader mode)",
    }, optimize);

    _ = sram_report;
    b.getInstallStep().dependOn(flash_report);
    // b.getInstallStep().dependOn(sram_report);
}
