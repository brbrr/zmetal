// TODO:
// - test current code: play around with lower values of reload Reg
// - Test that val reg is incrementing correctly
// - test that COUNTFLAG is flipped at all

const std = @import("std");

const microzig = @import("microzig");
const cpu = microzig.cpu;
const chip = microzig.chip;

// microzig now requires the root source file to explicitly export the startup logic
// (defines the `microzig_main` symbol the reset handler jumps to).
comptime {
    _ = microzig.export_startup();
}

const chip_peri = chip.peripherals;
const RCC = chip_peri.RCC;
const time = microzig.drivers.time;

// Import the HAL from microzig.hal (now provided by build system)
pub const hal = microzig.hal;
const errors = hal.errors;
pub const panic = errors.panic;

// Daisy board support
const ssai = hal.sai;
const SaiDriver = ssai.SaiDriver;

const osc = @import("dsp/osc.zig");
const keyboard = @import("hid/keyboard.zig");
const ili9341 = @import("drivers/ili9341.zig");

// INTERNAL_ADDRESS = 0x08000000
// FLASH_ADDRESS ?= $(INTERNAL_ADDRESS)
// dfu-util -a 0 -s 0x08000000:leave -D zig-out/firmware/blinky.bin -d ,0483:df11
// openocd -s /usr/local/share/openocd/scripts -f interface/stlink.cfg -f target/stm32h7x.cfg -c "program ./zig-out/firmware/blinky.elf verify reset exit"

pub const microzig_options: microzig.Options = .{
    .interrupts = .{
        .SysTick = .{ .c = sys_tick_handler },
        .HardFault = .{ .c = hw_handler },
        .NMI = .{ .c = nmi_handler },
        .MemManageFault = .{ .c = mem_manage_fault_handler },
        .BusFault = .{ .c = bus_fault_handler },
        .UsageFault = .{ .c = usage_fault_handler },
        .SVCall = .{ .c = sv_call_handler },
        .PendSV = .{ .c = hw_handler },

        .DMA1_STR0 = .{ .c = ssai.dma1_0_handler },
        .DMA1_STR1 = .{ .c = ssai.dma1_1_handler },
        .SAI1 = .{ .c = ssai.SaiDriver.sai1_irq_handler },

        .SPI1 = .{ .c = hal.spi.spi1_irq_handler },
        // SPI TX
        .DMA2_STR3 = .{ .c = hal.spi.tx_dma_irq_handler },
        // SPI RX
        // .DMA2_STR2 = .{ .c = hal.spi.dma1_str3_handler },
    },
};

// Logging moved out of microzig.Options into the standard Zig `std_options`.
// microzig.std_options() builds an embedded-friendly std.Options from the given overrides.
pub const std_options = microzig.std_options(.{ .logFn = hal.uart.log });

fn hw_handler() callconv(.c) void {
    @breakpoint();
    @panic("HardFault");
}
fn nmi_handler() callconv(.c) void {
    @breakpoint();
    @panic("NMI");
}
fn mem_manage_fault_handler() callconv(.c) void {
    @breakpoint();
    @panic("MemManageFault");
}
fn bus_fault_handler() callconv(.c) void {
    @breakpoint();
    @panic("BusFault");
}
fn usage_fault_handler() callconv(.c) void {
    @breakpoint();
    @panic("UsageFault");
}
fn sv_call_handler() callconv(.c) void {
    @breakpoint();
    @panic("SVCall");
}

fn sys_tick_handler() callconv(.c) void {
    hal.clock.inc_tick();
}

pub fn init() void {
    // FIXME: For SRAM build, no need to call below
    hal.init_vector_table();
}

var hw: hal.daisy.Daisy = hal.daisy.Daisy.create() catch unreachable;

// var sine = osc.SineOsc.init(440, 48000, 0.02);
// var lfo = osc.SineOsc.init(2.0, 48000, 1); // 5 Hz LFO
var sine = osc.WavetableOsc.init(440, 48000, 0.02);
// var square = osc.SquareOsc.init(440.0, 48000, 0.02);

// I2C device for keyboard (must be global/static for pointer stability)
// var kbd_i2c: hal.i2c.I2C_Device = undefined;
// Keyboard type generated at comptime with embedded I2C reference
// const KeyboardType = keyboard.KeyboardBuilder(kbd_i2c.i2c_device());
// var kbd: KeyboardType = undefined;

const display_spi_config = hal.spi.Config{
    .mode = .Mode0,
    .baud_prescaler = .PS_2,
    .chip_select = .Software,
    .direction = .FullDuplex,
};

const display_dc_pin = hal.gpio.Pin.init("A", "3", .{ .mode = .output, .speed = .VeryHighSpeed });
const display_rst_pin = hal.gpio.Pin.init("A", "5", .{ .mode = .output, .speed = .VeryHighSpeed });
const display_cs_pin = hal.gpio.Pin.init("G", "10", .{ .mode = .output, .speed = .VeryHighSpeed });
const Display = ili9341.ILI9341_DMA(display_dc_pin, display_rst_pin, display_cs_pin);

var display_spi: hal.spi.SPI_Device = undefined;
var display: Display = undefined;
var display_ready = false;
var display_frame: u32 = 0;
var display_prev_x: u16 = 0;

// FPS counter state (measures display flushes per second)
var fps_frame_count: u32 = 0;
var fps_window_start: u32 = 0;
var fps_value: u32 = 0;

pub fn main() !void {
    try hw.init();
    try hw.startAudio(&myAudioCallback);
    try initDisplay();

    // var kbd = try keyboard.Keyboard.init(hw.i2c.i2c_device());
    // var tick_count: u32 = 0;
    while (true) {
        // Process keyboard every 10ms (100Hz scan rate)
        // if (tick_count % 10 == 0) {
        //     if (kbd.process()) |events| {
        //         for (events.slice()) |evt| {
        //             handle_key_event(evt);
        //         }
        //     } else |_| {
        //         // Ignore keyboard errors
        //     }
        // }
        // tick_count += 1;

        serviceDisplay();
        cpu.wfi();
    }
}

fn myAudioCallback(input: []const f32, output: []f32, size: u16) void {
    _ = input;

    var i: u32 = 0;
    while (i < size) : (i += 2) {
        // const lfo_depth = 200;
        // const lfo_value = lfo.nextSample(); // -1..1
        // const mod_freq = 440.0 + lfo_value * lfo_depth;
        // sine.setFreq(mod_freq); // update frequency

        const samp = sine.nextSample();
        output[i] = 0;
        output[i + 1] = samp;
    }
}

fn initDisplay() !void {
    display_spi = try hal.spi.SPI_Device.init(.SPI1, display_spi_config);
    display_spi.apply();
    hal.clock.delay_ms(100);

    display = try Display.init(&display_spi, &ili9341.display_framebuffer);
    try display.set_orientation(.Landscape);

    display.fill_screen(ili9341.Colors.Black);
    display.fill_rect(10, 10, 50, 50, ili9341.Colors.Red);
    display.fill_rect(70, 10, 50, 50, ili9341.Colors.Green);
    display.fill_rect(130, 10, 50, 50, ili9341.Colors.Blue);
    display.draw_line(10, 80, 180, 120, ili9341.Colors.White);
    display.draw_line(10, 120, 180, 80, ili9341.Colors.Yellow);
    display.draw_rect(200, 80, 100, 60, ili9341.Colors.Cyan);
    display.fill_rect(210, 90, 80, 40, ili9341.Colors.Magenta);
    try display.flush(null);
    display_ready = true;
}

var tast_f_time: u32 = 0;
fn serviceDisplay() void {
    if (!display_ready or !display.done) {
        return;
    }

    if (hal.clock.get_tick() - tast_f_time < 16) {
        return;
    }

    const x: u16 = @intCast(display_frame % 270);
    display.fill_screen(ili9341.Colors.Green);
    display.fill_rect(display_prev_x, 180, 50, 30, ili9341.Colors.Black);
    display.fill_rect(x, 180, 50, 30, ili9341.Colors.Orange);
    display_prev_x = x;
    display_frame += 1;

    // Update FPS once per second based on flushes in the elapsed window.
    fps_frame_count += 1;
    const now = hal.clock.get_tick();
    const elapsed = now - fps_window_start;
    if (elapsed >= 1000) {
        fps_value = fps_frame_count * 1000 / elapsed;
        fps_frame_count = 0;
        fps_window_start = now;
    }

    // Draw "FPS:NNN" in the top-right corner.
    var fps_buf: [8]u8 = undefined;
    const fps_str = std.fmt.bufPrint(&fps_buf, "FPS:{d:>3}", .{fps_value}) catch "FPS:???";
    const fps_w: u16 = @intCast(fps_str.len * ili9341.font.font6x8.width);
    _ = display.draw_string(ili9341.WIDTH - fps_w - 2, 2, fps_str, ili9341.font.font6x8, ili9341.Colors.White, ili9341.Colors.Black);

    display.flush(null) catch |err| switch (err) {
        error.FlushInProgress => {},
        else => @panic("display flush failed"),
    };

    tast_f_time = now;
}

fn handle_key_event(evt: keyboard.KeyEventData) void {
    const row = evt.key / keyboard.COLS;
    const col = evt.key % keyboard.COLS;

    switch (evt.event) {
        .pressed => {
            if (evt.key == 0) {
                hw.led.toggle();
            }
            _ = row;
            _ = col;
        },
        .released => {
            _ = row;
            _ = col;
        },
    }
}
