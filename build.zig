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

const common_memory_regions = [_]microzig.MemoryRegion{
    .{ .name = "FLASH", .tag = .flash, .offset = 0x08000000, .length = 0x20000, .access = .rx },
    .{ .name = "SRAM", .tag = .ram, .offset = 0x24000000, .length = 0x80000, .access = .rwx },
    .{ .name = "RAM_D2", .tag = .ram, .offset = 0x30000000, .length = 0x48000, .access = .rwx },
    .{ .name = "RAM_D3", .tag = .ram, .offset = 0x38000000, .length = 0x10000, .access = .rwx },
    .{ .name = "BACKUP_SRAM", .tag = .ram, .offset = 0x38800000, .length = 0x1000, .access = .rwx },
    .{ .name = "DTCMRAM", .tag = .ram, .offset = 0x20000000, .length = 0x20000, .access = .rwx },
    .{ .name = "ITCMRAM", .tag = .ram, .offset = 0x00000000, .length = 0x10000, .access = .rwx },
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
    config: TargetConfig,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step {
    const stm32_common_mod = b.createModule(.{
        .root_source_file = b.path("lib/microzig/port/stmicro/stm32/src/hals/common.zig"),
    });

    const target = createSTM32Target(b, mz_dep, config.linker_script, stm32_common_mod, clockhelper_dep);

    _ = optimize;
    const firmware = mb.add_firmware(.{
        .name = config.name,
        .target = target,
        .optimize = .ReleaseFast,
        .root_source_file = b.path("src/main.zig"),
    });

    const install = mb.add_install_firmware(firmware, .{ .format = .elf });
    stm32_common_mod.addImport("microzig", firmware.core_mod);

    const report = b.addSystemCommand(&.{
        "python3",
        "build_tools/memory_report.py",
    });
    report.addFileArg(firmware.get_emitted_elf());
    report.addArg(config.name);
    report.addArg(config.linker_script);
    report.step.dependOn(&install.step);

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

    const sram_report = buildTargetVariant(b, mb, mz_dep, clockhelper_dep, .{
        .name = "blinky-sram",
        .linker_script = "src/ld/daisy_sram.ld",
        .step_name = "sram",
        .step_description = "Build firmware for SRAM (bootloader mode)",
    }, optimize);

    _ = buildTargetVariant(b, mb, mz_dep, clockhelper_dep, .{
        .name = "blinky-flash",
        .linker_script = "src/ld/daisy_flash.ld",
        .step_name = "flash",
        .step_description = "Build firmware for internal flash (direct mode)",
    }, optimize);

    b.getInstallStep().dependOn(sram_report);
}
