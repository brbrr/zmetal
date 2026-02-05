const std = @import("std");
const microzig = @import("microzig");
const STM32H750x = @import("stm32h7/STM32H750x.zig");

const MicroBuild = microzig.MicroBuild(.{
    .stm32 = true,
});

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

    // Common memory regions for both targets
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

    // ========================================================================
    // Target 1: SRAM Mode (Bootloader) - `zig build sram`
    // ========================================================================

    // Create stm32_common module for SRAM target
    const stm32_common_mod_sram = b.createModule(.{
        .root_source_file = b.path("lib/microzig/port/stmicro/stm32/src/hals/common.zig"),
    });

    const STM32H750IB_sram = b.allocator.create(microzig.Target) catch @panic("out of memory");
    STM32H750IB_sram.* = .{
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
            .memory_regions = &common_memory_regions,
        },
        .stack = .{ .symbol_name = "_estack" },
        .linker_script = .{
            .generate = .none,
            .file = b.path("src/ld/daisy_sram.ld"),
        },
        .hal = .{
            .root_source_file = b.path("src/hal/STM32H750/hal.zig"),
            .imports = &.{
                .{ .name = "stm32_common", .module = stm32_common_mod_sram },
                .{ .name = "ClockTree", .module = clockhelper_dep },
            },
        },
    };

    const firmware_sram = mb.add_firmware(.{
        .name = "blinky-sram",
        .target = STM32H750IB_sram,
        .optimize = .Debug,
        .root_source_file = b.path("src/main.zig"),
    });

    const install_sram = mb.add_install_firmware(firmware_sram, .{ .format = .elf });
    stm32_common_mod_sram.addImport("microzig", firmware_sram.core_mod);

    // Add memory report step
    const sram_report = b.addSystemCommand(&.{
        "python3",
        "build_tools/memory_report.py",
    });
    sram_report.addFileArg(firmware_sram.artifact.getEmittedBin());
    sram_report.addArg("blinky-sram");
    sram_report.addArg("src/ld/daisy_sram.ld");
    sram_report.step.dependOn(&install_sram.step);

    const sram_step = b.step("sram", "Build firmware for SRAM (bootloader mode)");
    sram_step.dependOn(&sram_report.step);

    // ========================================================================
    // Target 2: Flash Mode (Direct) - `zig build flash`
    // ========================================================================

    // Create separate stm32_common module for flash target
    const stm32_common_mod_flash = b.createModule(.{
        .root_source_file = b.path("lib/microzig/port/stmicro/stm32/src/hals/common.zig"),
    });

    const STM32H750IB_flash = b.allocator.create(microzig.Target) catch @panic("out of memory");
    STM32H750IB_flash.* = .{
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
            .memory_regions = &common_memory_regions,
        },
        .stack = .{ .symbol_name = "_estack" },
        .linker_script = .{
            .generate = .none,
            .file = b.path("src/ld/daisy_flash.ld"),
        },
        .hal = .{
            .root_source_file = b.path("src/hal/STM32H750/hal.zig"),
            .imports = &.{
                .{ .name = "stm32_common", .module = stm32_common_mod_flash },
                .{ .name = "ClockTree", .module = clockhelper_dep },
            },
        },
    };

    const firmware_flash = mb.add_firmware(.{
        .name = "blinky-flash",
        .target = STM32H750IB_flash,
        .optimize = .Debug,
        .root_source_file = b.path("src/main.zig"),
    });

    const install_flash = mb.add_install_firmware(firmware_flash, .{ .format = .elf });
    stm32_common_mod_flash.addImport("microzig", firmware_flash.core_mod);

    // Add memory report step
    const flash_report = b.addSystemCommand(&.{
        "python3",
        "build_tools/memory_report.py",
    });
    flash_report.addFileArg(firmware_flash.artifact.getEmittedBin());
    flash_report.addArg("blinky-flash");
    flash_report.addArg("src/ld/daisy_flash.ld");
    flash_report.step.dependOn(&install_flash.step);

    const flash_step = b.step("flash", "Build firmware for internal flash (direct mode)");
    flash_step.dependOn(&flash_report.step);

    // Default build is SRAM mode
    b.getInstallStep().dependOn(&install_sram.step);
    b.getInstallStep().dependOn(&sram_report.step);
}
