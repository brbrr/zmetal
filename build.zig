const std = @import("std");
const microzig = @import("microzig");

const MicroBuild = microzig.MicroBuild(.{
    .stm32 = true,
});

// ============================================================================
// Build commands:
//   zig build                         -> every example (install)
//   zig build <example>               -> one example, e.g. `zig build synth -Doptimize=safe`
//   zig build test                    -> host unit tests (std-only modules)
//   -Dmemory=flash|sram               -> internal flash (default) or SRAM (Daisy bootloader)
// Artifacts: zig-out/firmware/<example>.{elf,bin}
// ============================================================================

pub const Memory = enum { flash, sram };

pub const FirmwareOptions = struct {
    name: []const u8,
    root_source_file: std.Build.LazyPath,
    memory: Memory = .flash,
    optimize: std.builtin.OptimizeMode,
    /// Optimize mode for the zmetal library + microzig/HAL. Default: .safe when
    /// the app is .debug (an all-Debug image does not fit 128 KB flash), else
    /// the app's mode.
    lib_optimize: ?std.builtin.OptimizeMode = null,
    /// Link TinyUSB (CDC + MIDI + UAC2) and install the OTG IRQ handlers.
    usb: bool = false,
    /// Link FatFs (zfat) and expose `zmetal.fat`.
    fat: bool = false,
    /// Extra options exposed to the app as `@import("build_config")`.
    build_config: ?*std.Build.Step.Options = null,
};

/// Firmware-independent inputs to addFirmware, created once in `build`.
pub const Context = struct {
    mb: *MicroBuild,
    clockhelper: *std.Build.Module,
    zfat: *std.Build.Module,
};

pub const Firmware = struct {
    fw: *MicroBuild.Firmware,
    /// Installs .elf + .bin and prints the memory report.
    step: *std.Build.Step,
};

fn addTinyUsb(b: *std.Build, mod: *std.Build.Module) void {
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
        mod.addCSourceFile(.{ .file = b.path(src), .flags = &.{
            "-std=c11",
            "-DCFG_TUSB_MCU=OPT_MCU_STM32H7",
        } });
    }
    mod.addIncludePath(b.path("lib/tinyusb/src"));
    mod.addIncludePath(b.path("lib/tinyusb_shim"));
    // TinyUSB does intentional type-punning / unaligned packed-struct access that
    // Zig's C UBSan flags; with `.trap` those become `udf` -> UsageFault(UNDEFINSTR)
    // on real hardware (e.g. in usbd.c during enumeration). `.off` disables the
    // checks entirely (no UBSan runtime either, so no size cost) — TinyUSB is a
    // mature, widely-deployed stack, so we trust it here.
    mod.sanitize_c = .off;
}

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

/// Build one firmware image against the zmetal library. The app root imports
/// `zmetal` (and the std-only `zmetal_dsp`); microzig, the HAL and the facade
/// are per-firmware because microzig reads `microzig_options` from the root.
pub fn addFirmware(b: *std.Build, ctx: Context, opts: FirmwareOptions) Firmware {
    const lib_optimize = opts.lib_optimize orelse if (opts.optimize == .debug) .safe else opts.optimize;
    const linker_script = switch (opts.memory) {
        .flash => "src/ld/flash.ld",
        .sram => "src/ld/sram.ld",
    };

    // Seen by the HAL (default_interrupts) and the facade (zmetal.fat).
    const zmetal_opts = b.addOptions();
    zmetal_opts.addOption(bool, "usb", opts.usb);
    zmetal_opts.addOption(bool, "fat", opts.fat);
    const zmetal_opts_mod = zmetal_opts.createModule();

    const stm32_common_mod = b.createModule(.{
        .root_source_file = b.path("lib/microzig/port/stmicro/stm32/src/hals/common.zig"),
    });
    const hal_imports = b.allocator.dupe(std.Build.Module.Import, &.{
        .{ .name = "stm32_common", .module = stm32_common_mod },
        .{ .name = "ClockTree", .module = ctx.clockhelper },
        .{ .name = "zmetal_options", .module = zmetal_opts_mod },
    }) catch @panic("OOM");

    // microzig's built-in STM32H750IB chip (register definitions) with our own
    // HAL, our self-contained linker scripts and the _estack-based stack.
    const fw = ctx.mb.add_firmware(.{
        .name = opts.name,
        .target = ctx.mb.ports.stm32.chips.STM32H750IB.derive(.{
            .hal = .{ .root_source_file = b.path("src/hal/STM32H750/hal.zig"), .imports = hal_imports },
            .linker_script = .{ .generate = .none, .file = b.path(linker_script) },
            .stack = .{ .symbol_name = "_estack" },
        }),
        .optimize = opts.optimize,
        .root_source_file = opts.root_source_file,
    });
    stm32_common_mod.addImport("microzig", fw.core_mod);

    // microzig framework + HAL (reachable from core_mod; the app root is not).
    if (lib_optimize != opts.optimize) {
        var visited = std.AutoHashMap(*std.Build.Module, void).init(b.allocator);
        setTreeOptimize(fw.core_mod, lib_optimize, &visited);
    }

    const root = fw.exe.root_module;
    const mz = root.import_table.get("microzig").?;

    const dsp_mod = b.createModule(.{
        .root_source_file = b.path("src/dsp/root.zig"),
        .target = root.resolved_target,
        .optimize = lib_optimize,
    });
    const zmetal_mod = b.createModule(.{
        .root_source_file = b.path("src/zmetal.zig"),
        .target = root.resolved_target,
        .optimize = lib_optimize,
        .imports = &.{
            .{ .name = "microzig", .module = mz },
            .{ .name = "zmetal_options", .module = zmetal_opts_mod },
            .{ .name = "zmetal_dsp", .module = dsp_mod },
        },
    });
    if (opts.fat) zmetal_mod.addImport("zfat", ctx.zfat);
    // TinyUSB's C belongs to the library, so it builds at lib_optimize.
    if (opts.usb) addTinyUsb(b, zmetal_mod);

    root.addImport("zmetal", zmetal_mod);
    root.addImport("zmetal_dsp", dsp_mod);
    if (opts.build_config) |bc| root.addOptions("build_config", bc);

    const install = ctx.mb.add_install_firmware(fw, .{ .format = .elf });
    const install_bin = ctx.mb.add_install_firmware(fw, .{ .format = .binary });
    // A lazy path, so the step works when another package's build runs it.
    const report = b.addSystemCommand(&.{"python3"});
    report.addFileArg(b.path("build_tools/memory_report.py"));
    report.addFileArg(fw.get_emitted_elf());
    report.addArg(opts.name);
    report.addFileArg(b.path(linker_script));
    report.step.dependOn(&install.step);
    report.step.dependOn(&install_bin.step);

    return .{ .fw = fw, .step = &report.step };
}

const Example = struct {
    name: []const u8,
    root: []const u8,
    usb: bool = false,
    fat: bool = false,
    /// synth only: `build_config.usb_audio` (route USB Audio to the codec).
    usb_audio: ?bool = null,
    /// False when the Debug image overflows the 128 KB internal flash: a
    /// Debug + -Dmemory=flash build then promotes this example to .safe
    /// (Debug still works with -Dmemory=sram, 480 KB).
    debug_fits_flash: bool = true,
};

const examples = [_]Example{
    .{ .name = "synth", .root = "examples/synth/main.zig", .usb = true, .fat = true, .usb_audio = false, .debug_fits_flash = false },
    .{ .name = "synth_usb_audio", .root = "examples/synth/main.zig", .usb = true, .fat = true, .usb_audio = true, .debug_fits_flash = false },
    .{ .name = "usb_loopback", .root = "examples/usb_loopback/main.zig", .usb = true },
    .{ .name = "i2c", .root = "examples/i2c/main.zig" },
};

/// What a firmware's inputs are configured with.
pub const ContextOptions = struct {
    /// Long file names in FatFs: mixed case, up to 255 bytes, one static
    /// buffer in BSS. Off keeps 8.3 names and the smallest FatFs.
    long_file_name: bool = false,
    /// exFAT volumes in FatFs, as cards over 32 GB come formatted. FatFs
    /// needs long file names for it. File sizes and offsets become 64-bit.
    exfat: bool = false,
};

/// The inputs every firmware shares: microzig, the clock helper, FatFs.
/// Another package calls this with the zmetal dependency's builder, then
/// `addFirmware` with the same builder. Null when microzig is not ready.
pub fn context(b: *std.Build, opts: ContextOptions) ?Context {
    if (opts.exfat and !opts.long_file_name) @panic("zmetal: exFAT needs long_file_name");
    const mz_dep = b.dependency("microzig", .{});
    const mb = MicroBuild.init(b, mz_dep) orelse return null;

    // FatFs bindings; the module compiles the vendored FatFs C for the firmware
    // target when imported. Config is spelled out rather than left to defaults:
    //   - ReleaseSafe keeps the FatFs C compact.
    //   - static RTC: the board has no wall clock, and it keeps zfat off the
    //     removed std.time.timestamp() path (get_fattime returns a fixed date).
    //   - long_file_name: off by default (8.3 only, no Unicode tables).
    //   - no mkfs/find/chmod: unused APIs, kept out of flash. exFAT on request.
    const zfat_mod = b.dependency("zfat", .{
        .optimize = .safe,
        .@"static-rtc" = @as([]const u8, "2026-01-01"),
        .read_only = false, // we create/write files
        .long_file_name = opts.long_file_name,
        .mkfs = false, // no on-device formatting
        .exfat = opts.exfat, // FAT/FAT32, and exFAT when asked
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

    return .{
        .mb = mb,
        .clockhelper = b.dependency("ClockHelper", .{}).module("clockhelper"),
        .zfat = zfat_mod,
    };
}

pub fn build(b: *std.Build) void {
    const ctx = context(b, .{}) orelse return;
    const optimize = b.standardOptimizeOption(.{});
    const memory = b.option(Memory, "memory", "flash (default) or sram (Daisy bootloader)") orelse .flash;

    for (examples) |ex| {
        const bc: ?*std.Build.Step.Options = if (ex.usb_audio) |ua| blk: {
            const o = b.addOptions();
            o.addOption(bool, "usb_audio", ua);
            break :blk o;
        } else null;
        const fw = addFirmware(b, ctx, .{
            .name = ex.name,
            .root_source_file = b.path(ex.root),
            .memory = memory,
            .optimize = if (optimize == .debug and memory == .flash and !ex.debug_fits_flash) .safe else optimize,
            .usb = ex.usb,
            .fat = ex.fat,
            .build_config = bc,
        });
        b.step(ex.name, b.fmt("Build the {s} example", .{ex.name})).dependOn(fw.step);
        b.getInstallStep().dependOn(fw.step);
    }

    // Host unit tests: std-only library modules (no microzig), plus the synth
    // example's Program, which only needs the std-only DSP module.
    const host = b.graph.host;
    const test_step = b.step("test", "Run host unit tests (std-only modules)");
    const host_dsp = b.createModule(.{ .root_source_file = b.path("src/dsp/root.zig"), .target = host });
    const test_roots = [_][]const u8{
        "src/hid/midi.zig",
        "src/hid/midi_port.zig",
        "src/hid/encoder.zig",
        "src/hal/STM32H750/usb/pcm.zig",
        "src/hal/STM32H750/usb/resampler.zig",
        "src/hal/STM32H750/dma_index.zig",
        "src/hal/STM32H750/sai_math.zig",
        "src/hal/STM32H750/i2c_seg.zig",
        "src/hal/STM32H750/i2c_recovery.zig",
        "src/hal/STM32H750/tick_math.zig",
        "src/hal/STM32H750/pin_name.zig",
        "src/hal/STM32H750/usb/descriptors.zig",
        "src/hal/STM32H750/cpu_load.zig",
        "src/hal/STM32H750/stack_guard.zig",
        "src/drivers/tile_diff.zig",
        "src/drivers/mcp23017_setup.zig",
        "src/hid/matrix_scan.zig",
    };
    for (test_roots) |path| {
        const t = b.addTest(.{ .root_module = b.createModule(.{ .root_source_file = b.path(path), .target = host }) });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = host_dsp })).step);
    const program_mod = b.createModule(.{
        .root_source_file = b.path("examples/synth/program.zig"),
        .target = host,
        .imports = &.{.{ .name = "zmetal_dsp", .module = host_dsp }},
    });
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = program_mod })).step);
}
