//! Display/UI layer: owns the ILI9341 panel and renders the demo scene (moving
//! rectangles + an FPS/dirty-tile counter). `init()` brings up SPI and the panel;
//! `service()` is called every main-loop iteration to advance the animation and
//! push changed tiles over the diff flush.

const std = @import("std");
const microzig = @import("microzig");
const hal = microzig.hal;
const ili9341 = @import("drivers/ili9341.zig");

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

// FPS counter state (measures display flushes per second)
var fps_frame_count: u32 = 0;
var fps_window_start: u32 = 0;
var fps_value: u32 = 0;

var tast_f_time: u32 = 0;
var last_dirty_tiles: u32 = 0;

pub fn init() !void {
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

pub fn service() void {
    if (!display_ready) return;

    // A partial flush spanning multiple tiles is advanced here, in the
    // foreground (the completion ISR only flags that more tiles are pending).
    if (!display.done) {
        display.pump();
        return;
    }

    if (hal.clock.get_tick() - tast_f_time < 16) {
        // return;
    }

    // Full immediate redraw every frame. The checksum-diff flush transmits only
    // the tiles that actually changed (the green background hashes identically
    // and is skipped), so the redraw-everything cost stays off the SPI bus.
    const box_speed = 6; // pixels per frame
    const x: u16 = @intCast((display_frame * box_speed) % 270);
    const y: u16 = @intCast((display_frame * box_speed) % 350);
    display.fill_screen(ili9341.Colors.Green);
    display.fill_rect(x, 180, 50, 30, ili9341.Colors.Orange);
    display.fill_rect(x, 100, 50, 30, ili9341.Colors.Black);

    display.fill_rect(100, y, 50, 30, ili9341.Colors.White);
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

    // Draw "FPS:NNN T:NN" (T = dirty tiles sent last frame) in the top-right.
    var fps_buf: [16]u8 = undefined;
    const fps_str = std.fmt.bufPrint(&fps_buf, "FPS:{d:>3} T:{d:>2}", .{ fps_value, last_dirty_tiles }) catch "FPS:???";
    const fps_w: u16 = @intCast(fps_str.len * ili9341.font.font6x8.width);
    _ = display.draw_string(ili9341.WIDTH - fps_w - 2, 2, fps_str, ili9341.font.font6x8, ili9341.Colors.White, ili9341.Colors.Black);

    display.flush_diff(null) catch |err| switch (err) {
        error.FlushInProgress => {},
        else => @panic("display flush failed"),
    };
    last_dirty_tiles = @intCast(display.dirty_count);

    tast_f_time = now;
}
