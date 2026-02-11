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
        // .DMA1_STR2 = .{ .c = ssai.dma1_1_handler },
        // .DMA1_STR3 = .{ .c = ssai.dma1_1_handler },
        // .DMA1_STR4 = .{ .c = ssai.dma1_1_handler },
        // .DMA1_STR5 = .{ .c = ssai.dma1_1_handler },
        // .DMA1_STR6 = .{ .c = ssai.dma1_1_handler },
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

var hw: hal.daisy.Daisy = undefined;

var sine = osc.SineOsc.init(440, 48000, 0.02);
var square = osc.SquareOsc.init(440.0, 48000, 0.02);

var kbd: keyboard.Keyboard = undefined;
var kbd_initialized = false;

pub fn main() !void {
    hw = try hal.daisy.Daisy.init();

    // Configure LED pin as output
    const RCC_peri = chip.peripherals.RCC;
    RCC_peri.AHB4ENR.modify(.{ .GPIOCEN = 1 }); // Enable GPIOC clock

    // Test toggle

    try hw.startAudio(myAudioCallback);

    try example_ili9341();

    // try example_mcp23017();

    // try example_keyboard_init();

    var tick_count: u32 = 0;
    while (true) {
        // Process keyboard every 10ms (100Hz scan rate)
        // if (kbd_initialized and tick_count % 10 == 0) {
        //     if (kbd.process()) |events| {
        //         // Handle key events
        //         for (events.slice()) |evt| {
        //             handle_key_event(evt);
        //         }
        //     } else |_| {
        //         // Ignore keyboard errors
        //     }
        // }

        hal.clock.delay_ms(1);
        tick_count += 1;
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

pub fn example_ili9341() !void {
    const ili9341 = @import("drivers/ili9341.zig");

    // Configure SPI1 for ILI9341 - MUST use FullDuplex (TWO_LINES) like WoopyOne
    var spi1_display = try hal.spi.SPI_Device.init(.SPI1, .{
        .mode = .Mode0,
        .baud_prescaler = .PS_256, // Very slow for debugging
        .chip_select = .Software,
        .direction = .FullDuplex, // ⚠️ CRITICAL: Must be FullDuplex, not TxOnly!
    });
    spi1_display.apply();

    // Test: Simple SPI write before initializing display
    hal.clock.delay_ms(100);

    // Configure control pins (comptime)
    const dc_pin = comptime hal.gpio.Pin.init("A", "3", .{
        .mode = .output,
    });
    const rst_pin = comptime hal.gpio.Pin.init("A", "5", .{
        .mode = .output,
    });

    // CS pin (PG10) - manual GPIO control, NOT SPI alternate function!
    const cs_pin = comptime hal.gpio.Pin.init("G", "10", .{
        .mode = .output,
    });

    // Create display driver with comptime pins
    const Display = ili9341.ILI9341(dc_pin, rst_pin, cs_pin);
    const display = try Display.init(&spi1_display, .Landscape);

    // Fill screen with black
    try display.fill_screen(ili9341.Colors.Black);
    hal.clock.delay_ms(500);

    // Draw some test patterns
    try display.fill_rect(10, 10, 50, 50, ili9341.Colors.Red);
    try display.fill_rect(70, 10, 50, 50, ili9341.Colors.Green);
    try display.fill_rect(130, 10, 50, 50, ili9341.Colors.Blue);

    // Draw lines
    try display.draw_line(10, 80, 180, 120, ili9341.Colors.White);
    try display.draw_line(10, 120, 180, 80, ili9341.Colors.Yellow);

    // Draw rectangles
    try display.draw_rect(200, 80, 100, 60, ili9341.Colors.Cyan);
    try display.fill_rect(210, 90, 80, 40, ili9341.Colors.Magenta);
}

pub fn example_mcp23017() !void {
    const mcp23017 = @import("drivers/mcp23017.zig");

    // Initialize I2C1
    var i2c1 = try hal.i2c.I2C_Device.init(.I2C1, .{
        .speed = .I2C_400KHZ,
    });
    i2c1.apply();

    // Get the I2C_Device interface
    const i2c_dev = i2c1.i2c_device();

    // Initialize MCP23017 at address 0x20
    var mcp = try mcp23017.MCP23017.init(i2c_dev, 0x20);

    // Configure Port A as outputs (for driving column pins)
    try mcp.setPortMode(.A, 0x00); // All outputs

    // Configure Port B as inputs with pull-ups (for reading row pins)
    try mcp.setPortMode(.B, 0xFF); // All inputs

    // Set all Port A pins high initially
    try mcp.writePort(.A, 0xFF);

    // Test: Toggle pin 0 on Port A
    try mcp.writePin(0, false);
    hal.clock.delay_ms(100);
    try mcp.writePin(0, true);

    // Test: Read Port B
    const port_b_state = try mcp.readPort(.B);
    _ = port_b_state;
}

pub fn example_keyboard_init() !void {
    // Initialize I2C2 for keyboard (separate from other I2C devices)
    var i2c2 = try hal.i2c.I2C_Device.init(.I2C2, .{
        .speed = .I2C_400KHZ,
    });
    i2c2.apply();

    const i2c_dev = i2c2.i2c_device();

    // Initialize keyboard
    kbd = try keyboard.Keyboard.init(i2c_dev);
    kbd_initialized = true;
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
