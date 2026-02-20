// TODO:
// - test current code: play around with lower values of reload Reg
// - Test that val reg is incrementing correctly
// - test that COUNTFLAG is flipped at all

const std = @import("std");

const microzig = @import("microzig");
const cpu = microzig.cpu;
const chip = microzig.chip;

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
        // .SAI1 = .{ .c = ssai.SaiDriver.sai1_irq_handler },

        // RX
        // .DMA2_STR2 = .{ .c = hal.spi.dma1_str3_handler },
        // TX
        .DMA2_STR3 = .{ .c = hal.spi.tx_dma_irq_handler },
        .SPI1 = .{ .c = hal.spi.spi1_irq_handler },
    },

    .logFn = hal.uart.log,
};

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

var count: u32 = 1;

fn sys_tick_handler() callconv(.c) void {
    hal.clock.inc_tick();
    count += 1;
    if (count == 1_000) {
        hw.led.toggle();
    } else if (count == 1100) {
        hw.led.toggle();
    } else if (count == 1200) {
        hw.led.toggle();
    } else if (count == 1300) {
        hw.led.toggle();
        count = 0;
    }
}

pub fn init() void {
    // FIXME: For SRAM build, no need to call below
    // hal.init_vector_table();
}

var hw: hal.daisy.Daisy = hal.daisy.Daisy.create() catch unreachable;

var sine = osc.SineOsc.init(10, 48000, 0.02);
var square = osc.SquareOsc.init(440.0, 48000, 0.02);

// I2C device for keyboard (must be global/static for pointer stability)
// var kbd_i2c: hal.i2c.I2C_Device = undefined;
// Keyboard type generated at comptime with embedded I2C reference
// const KeyboardType = keyboard.KeyboardBuilder(kbd_i2c.i2c_device());
// var kbd: KeyboardType = undefined;

pub fn main() !void {
    try hw.init();

    try hw.startAudio(myAudioCallback);

    // try example_ili9341_dma();

    // var kbd = try keyboard.Keyboard.init(hw.i2c.i2c_device());
    //
    // var tick_count: u32 = 0;
    while (true) {
        //     // Process keyboard every 10ms (100Hz scan rate)
        //     if (tick_count % 10 == 0) {
        //         if (kbd.process()) |events| {
        //             // Handle key events
        //             for (events.slice()) |evt| {
        //                 handle_key_event(evt);
        //             }
        //         } else |_| {
        //             // Ignore keyboard errors
        //         }
        //     }
        //
        //     hal.clock.delay_ms(1);
        //     tick_count += 1;
    }
}

fn myAudioCallback(input: []const f32, output: []f32, size: u16) void {
    _ = input;
    var i: u32 = 0;
    while (i < size) : (i += 2) {
        const samp = sine.nextSample();
        output[i] = samp;
        output[i + 1] = samp;
    }
}

// Framebuffer in DMA-safe memory (SRAM - same as SAI buffers)
// 320x240x2 = 153,600 bytes, aligned to 32-byte cache line
var display_framebuffer: [320 * 240 * 2]u8 linksection(".sram1_bss") = undefined;

pub fn example_ili9341_dma() !void {
    const ili9341 = @import("drivers/ili9341.zig");

    // Configure SPI1 for ILI9341 with DMA
    const spi_config = hal.spi.Config{
        .mode = .Mode0,
        .baud_prescaler = .PS_2,
        .chip_select = .Software,
        .direction = .FullDuplex,
    };

    // Initialize SPI with DMA support
    var spi1_display = try hal.spi.SPI_Device.init(.SPI1, spi_config);
    // defer spi1_display.deinit();
    spi1_display.apply();

    hal.clock.delay_ms(100);

    // Configure control pins (comptime)
    const dc_pin = comptime hal.gpio.Pin.init("A", "3", .{ .mode = .output, .speed = .VeryHighSpeed });
    const rst_pin = comptime hal.gpio.Pin.init("A", "5", .{ .mode = .output, .speed = .VeryHighSpeed });
    const cs_pin = comptime hal.gpio.Pin.init("G", "10", .{ .mode = .output, .speed = .VeryHighSpeed });

    // Create DMA-based display driver
    const Display = ili9341.ILI9341_DMA(dc_pin, rst_pin, cs_pin);
    var display = try Display.init(&spi1_display, &display_framebuffer);
    // defer display.deinit();

    // Set orientation
    try display.set_orientation(.Landscape);

    // Fill framebuffer with black
    display.fill_screen(ili9341.Colors.Black);

    // Draw some test patterns to framebuffer
    display.fill_rect(10, 10, 50, 50, ili9341.Colors.Red);
    display.fill_rect(70, 10, 50, 50, ili9341.Colors.Green);
    display.fill_rect(130, 10, 50, 50, ili9341.Colors.Blue);

    // Draw lines
    display.draw_line(10, 80, 180, 120, ili9341.Colors.White);
    display.draw_line(10, 120, 180, 80, ili9341.Colors.Yellow);

    // Draw rectangles
    display.draw_rect(200, 80, 100, 60, ili9341.Colors.Cyan);
    display.fill_rect(210, 90, 80, 40, ili9341.Colors.Magenta);

    // Flush framebuffer to display via DMA (blocking)
    try display.flush_wait();

    // Continuous update loop example
    var frame: u32 = 0;
    while (true) : (frame += 1) {
        // Animate something
        const x = @as(u16, @intCast((frame % 270)));
        display.fill_rect(x, 180, 50, 30, ili9341.Colors.Orange);

        // Flush and wait for DMA
        try display.flush_wait();

        // Clear the moving rectangle for next frame
        display.fill_rect(x, 180, 50, 30, ili9341.Colors.Black);

        hal.clock.delay_ms(16); // ~60 FPS
    }
}

fn handle_key_event(evt: keyboard.KeyEventData) void {
    const row = evt.key / keyboard.COLS;
    const col = evt.key % keyboard.COLS;

    switch (evt.event) {
        .pressed => {
            // Example: Toggle LED on key 0 press
            if (evt.key == 0) {
                hw.led.toggle();
            }
            // Log key press (row, col)
            _ = row;
            _ = col;
        },
        .released => {
            // Log key release (row, col)
            _ = row;
            _ = col;
        },
    }
}
