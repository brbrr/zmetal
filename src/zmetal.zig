//! zmetal — Daisy Seed (STM32H750) library. Public root for applications.
//!
//! Apps import this as `@import("zmetal")`; firmware is built with
//! `addFirmware` in build.zig, which wires the per-firmware microzig, HAL,
//! and optional TinyUSB/FatFs pieces. The HAL's `init` and its interrupt
//! handlers (`hal.default_interrupts`) are installed automatically.
//!
//! DMA-visible buffers: anything a DMA stream reads or writes must live in
//! `linksection(".sram1_bss")` (D2 SRAM, non-cacheable via the MPU); DMA1/2
//! cannot reach DTCM. The section is NOLOAD and is NOT zero-initialized —
//! `@memset` buffers before use, and write them as whole words first: a byte or
//! halfword store to never-written D2 SRAM can raise an ECC BusFault.
const microzig = @import("microzig");
const options = @import("zmetal_options");

pub const hal = microzig.hal;
pub const board = hal.daisy;
/// The Daisy Seed board: `var seed: zmetal.Seed = .{}; try seed.init(.{});`
pub const Seed = board.Daisy;
/// Seed header pin names: `zmetal.pins.D7`, `zmetal.pins.A0`, `zmetal.pins.LED`.
pub const pins = board.seed;
pub const dsp = @import("zmetal_dsp");
pub const time = @import("time.zig");

pub const drivers = struct {
    pub const ili9341 = @import("drivers/ili9341.zig");
    /// Display controllers for `ili9341.PanelDMA`: `panel_init.ili9341`, `panel_init.st7789`.
    pub const panel_init = ili9341.panel_init;
    pub const i2c_bus = @import("drivers/i2c_bus.zig");
    pub const mcp23017 = @import("drivers/mcp23017.zig");
    pub const bq25628 = @import("drivers/bq25628.zig");
    pub const max17048 = @import("drivers/max17048.zig");
    /// A host for the STM32 ROM bootloader over I2C: programs the panel scanner (STM32C031).
    pub const stm32_i2c_boot = @import("drivers/stm32_i2c_boot.zig");
    pub const font = ili9341.font;
};

pub const hid = struct {
    pub const midi = @import("hid/midi.zig");
    pub const midi_port = @import("hid/midi_port.zig");
    pub const encoder = @import("hid/encoder.zig");
    pub const encoders = @import("hid/encoders.zig");
    pub const keyboard = @import("hid/keyboard.zig");
    pub const debounce = @import("hid/debounce.zig");
    pub const mcp_digital_io = @import("hid/mcp_digital_io.zig");
    /// The v3 panel scanner's wire protocol, the Daisy-side client, and the updater
    /// that decides when a scanner image may be committed.
    pub const panel_proto = @import("hid/panel_proto.zig");
    pub const panel_client = @import("hid/panel_client.zig");
    pub const panel_update = @import("hid/panel_update.zig");
};

pub const audio = struct {
    pub const AudioIO = dsp.AudioIO;
    pub const AudioInterface = @import("audio/interface.zig").AudioInterface;
    pub const InterfaceOptions = @import("audio/interface.zig").Options;
};

/// FatFs on the SD card. `void` unless the firmware is built with `.fat = true`.
pub const fat = if (options.fat) @import("fat.zig") else void;
