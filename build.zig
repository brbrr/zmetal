const std = @import("std");
const microzig = @import("microzig");
const STM32H750x = @import("stm32h7/STM32H750x.zig");

const MicroBuild = microzig.MicroBuild(.{
    .stm32 = true,
});

pub fn build(b: *std.Build) void {
    const mz_dep = b.dependency("microzig", .{});
    const mb = MicroBuild.init(b, mz_dep) orelse return;

    const STM32H750IB = b.allocator.create(microzig.Target) catch @panic("out of memory");

    STM32H750IB.* = .{
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
            .memory_regions = &.{
                .{ .tag = .ram, .offset = 0x0, .length = 0x10000, .access = .rwx },
                .{ .tag = .flash, .offset = 0x8000000, .length = 0x20000, .access = .rx },
                .{ .tag = .ram, .offset = 0x20000000, .length = 0x20000, .access = .rwx },
                .{ .tag = .ram, .offset = 0x24000000, .length = 0x80000, .access = .rwx },
                .{ .tag = .ram, .offset = 0x30000000, .length = 0x48000, .access = .rwx },
                .{ .tag = .ram, .offset = 0x38000000, .length = 0x10000, .access = .rwx },
            },
        },

        // .hal = .{
        //     .root_source_file = b.path("src/hals/STM32H750/hal.zig"),
        // },
    };

    const firmware = mb.add_firmware(.{
        .name = "blinky",
        // .target = mb.ports.stm32.chips.STM32H750IB,
        .target = STM32H750IB,
        .optimize = .ReleaseSmall,
        // .optimize = .Debug,
        .root_source_file = b.path("src/main.zig"),
    });

    mb.install_firmware(firmware, .{ .format = .elf });
}
