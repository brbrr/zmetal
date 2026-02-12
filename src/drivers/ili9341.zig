//! ILI9341 TFT LCD Display Driver
//!
//! This driver supports the ILI9341 320x240 RGB565 TFT display controller.
//! Communication is via SPI with additional DC (Data/Command) and RST (Reset) control pins.
//!
//! Features:
//! - Blocking SPI communication
//! - Direct-to-display rendering (no framebuffer)
//! - Multiple orientation modes
//! - Basic drawing primitives (pixel, line, rectangle, fill)
//! - RGB565 color format
//!
//! Pin Configuration (WoopyOne reference):
//! - SPI1: PG11 (SCLK), PB5 (MOSI), PG10 (CS)
//! - DC: D16 (Data/Command select)
//! - RST: D22 (Reset)
//!
//! Example usage:
//! ```zig
//! const display = try ILI9341.init(spi1, .{
//!     .dc_pin = dc_pin,
//!     .rst_pin = rst_pin,
//! });
//! try display.fill_screen(Colors.Black);
//! try display.draw_rect(10, 10, 50, 50, Colors.Red);
//! ```

const std = @import("std");
const microzig = @import("microzig");
const hal = microzig.hal;

/// Display dimensions
pub const WIDTH = 320;
pub const HEIGHT = 240;

/// RGB565 color representation (16-bit: 5R, 6G, 5B)
pub const Color = u16;

/// Common colors in RGB565 format
pub const Colors = struct {
    pub const Black: Color = 0x0000;
    pub const White: Color = 0xFFFF;
    pub const Red: Color = 0xF800;
    pub const Green: Color = 0x07E0;
    pub const Blue: Color = 0x001F;
    pub const Yellow: Color = 0xFFE0;
    pub const Cyan: Color = 0x07FF;
    pub const Magenta: Color = 0xF81F;
    pub const Orange: Color = 0xFD20;
    pub const Gray: Color = 0x8410;
    pub const DarkGray: Color = 0x4208;
    pub const LightGray: Color = 0xC618;
};

/// Display orientation modes
pub const Orientation = enum {
    /// Portrait: 240x320 (0°)
    Portrait,
    /// Landscape: 320x240 (90° right)
    Landscape,
    /// Portrait flipped: 240x320 (180°)
    PortraitFlipped,
    /// Landscape flipped: 320x240 (270° right / 90° left)
    LandscapeFlipped,
};

/// ILI9341 command codes
const Command = enum(u8) {
    NOP = 0x00,
    SWRESET = 0x01,
    RDDID = 0x04,
    RDDST = 0x09,
    SLPIN = 0x10,
    SLPOUT = 0x11,
    PTLON = 0x12,
    NORON = 0x13,
    INVOFF = 0x20,
    INVON = 0x21,
    GAMMASET = 0x26,
    DISPOFF = 0x28,
    DISPON = 0x29,
    CASET = 0x2A,
    RASET = 0x2B,
    RAMWR = 0x2C,
    RAMRD = 0x2E,
    PTLAR = 0x30,
    MADCTL = 0x36,
    PIXFMT = 0x3A,
    FRMCTR1 = 0xB1,
    FRMCTR2 = 0xB2,
    FRMCTR3 = 0xB3,
    INVCTR = 0xB4,
    DFUNCTR = 0xB6,
    PWCTR1 = 0xC0,
    PWCTR2 = 0xC1,
    PWCTR3 = 0xC2,
    PWCTR4 = 0xC3,
    PWCTR5 = 0xC4,
    VMCTR1 = 0xC5,
    VMCTR2 = 0xC7,
    PWCTRA = 0xCB,
    PWCTRB = 0xCF,
    RDID1 = 0xDA,
    RDID2 = 0xDB,
    RDID3 = 0xDC,
    RDID4 = 0xDD,
    GMCTRP1 = 0xE0,
    GMCTRN1 = 0xE1,
    DTCA = 0xE8,
    DTCB = 0xEA,
    POWER_SEQ = 0xED,
    ENABLE_3G = 0xF2,
    PUMP_RATIO = 0xF7,
};

pub fn ILI9341_Transport(comptime dc_pin: hal.gpio.Pin, comptime rst_pin: hal.gpio.Pin, comptime cs_pin: ?hal.gpio.Pin) type {
    return struct {
        const Self = @This();

        spi: *const hal.spi.SPI_Device,

        pub fn init(spi: *const hal.spi.SPI_Device) !Self {
            // Configure DC pin as output
            dc_pin.configure();

            // Configure RST pin as output
            rst_pin.configure();

            // Configure CS pin if provided
            if (cs_pin) |cs| {
                cs.configure();
                cs.write(.High); // Deselect initially
            }

            return .{ .spi = spi };
        }

        pub fn init_display(self: *Self) !void {
            self.reset();

            // Software reset
            try self.send_command(.SWRESET);
            hal.clock.delay_ms(100);

            // Power Control A
            try self.send_command(.PWCTRA);
            try self.send_data(&[_]u8{ 0x39, 0x2C, 0x00, 0x34, 0x02 });

            // Power Control B
            try self.send_command(.PWCTRB);
            try self.send_data(&[_]u8{ 0x00, 0xC1, 0x30 });

            // Driver Timing Control A
            try self.send_command(.DTCA);
            try self.send_data(&[_]u8{ 0x85, 0x00, 0x78 });

            // Driver Timing Control B
            try self.send_command(.DTCB);
            try self.send_data(&[_]u8{ 0x00, 0x00 });

            // Power on Sequence Control
            try self.send_command(.POWER_SEQ);
            try self.send_data(&[_]u8{ 0x64, 0x03, 0x12, 0x81 });

            // Pump Ratio Control
            try self.send_command(.PUMP_RATIO);
            try self.send_data(&[_]u8{0x20});

            // Power Control 1
            try self.send_command(.PWCTR1);
            try self.send_data(&[_]u8{0x23});

            // Power Control 2
            try self.send_command(.PWCTR2);
            try self.send_data(&[_]u8{0x10});

            // VCOM Control 1
            try self.send_command(.VMCTR1);
            try self.send_data(&[_]u8{ 0x3E, 0x28 });

            // VCOM Control 2
            try self.send_command(.VMCTR2);
            try self.send_data(&[_]u8{0x86});

            // Memory Access Control (will be set by set_orientation)
            try self.send_command(.MADCTL);
            try self.send_data(&[_]u8{0x48});

            // Pixel Format: 16-bit/pixel (RGB565)
            try self.send_command(.PIXFMT);
            try self.send_data(&[_]u8{0x55});

            // Frame Rate Control
            try self.send_command(.FRMCTR1);
            try self.send_data(&[_]u8{ 0x00, 0x18 });

            // Display Function Control
            try self.send_command(.DFUNCTR);
            try self.send_data(&[_]u8{ 0x08, 0x82, 0x27 });

            // 3Gamma Function Disable
            try self.send_command(.ENABLE_3G);
            try self.send_data(&[_]u8{0x00});

            // Gamma Curve Selected
            try self.send_command(.GAMMASET);
            try self.send_data(&[_]u8{0x01});

            // Positive Gamma Correction
            try self.send_command(.GMCTRP1);
            try self.send_data(&[_]u8{
                0x0F, 0x31, 0x2B, 0x0C, 0x0E, 0x08, 0x4E, 0xF1,
                0x37, 0x07, 0x10, 0x03, 0x0E, 0x09, 0x00,
            });

            // Negative Gamma Correction
            try self.send_command(.GMCTRN1);
            try self.send_data(&[_]u8{
                0x00, 0x0E, 0x14, 0x03, 0x11, 0x07, 0x31, 0xC1,
                0x48, 0x08, 0x0F, 0x0C, 0x31, 0x36, 0x0F,
            });

            // Exit Sleep
            try self.send_command(.SLPOUT);
            hal.clock.delay_ms(120);

            // Display On
            try self.send_command(.DISPON);
            hal.clock.delay_ms(100);
        }

        /// Select the display (assert CS low)
        inline fn select(self: *const Self) void {
            _ = self;
            if (cs_pin) |cs| {
                cs.write(.Low);
            }
        }

        /// Deselect the display (assert CS high)
        inline fn deselect(self: *const Self) void {
            _ = self;
            if (cs_pin) |cs| {
                cs.write(.High);
            }
        }

        /// Send a command byte
        fn send_command(self: *const Self, cmd: Command) !void {
            dc_pin.write(.Low); // Command mode
            self.select();
            try self.spi.write_blocking(&[_]u8{@intFromEnum(cmd)});
            self.deselect();
        }

        /// Send data bytes
        fn send_data(self: *const Self, data: []const u8) !void {
            dc_pin.write(.High); // Data mode
            self.select();
            try self.spi.write_blocking(data);
            self.deselect();
        }

        /// Send a single data byte
        fn send_data_byte(self: *const Self, byte: u8) !void {
            try self.send_data(&[_]u8{byte});
        }

        /// Send 16-bit data (big-endian)
        fn send_data_u16(self: *const Self, value: u16) !void {
            const bytes = [_]u8{
                @intCast((value >> 8) & 0xFF),
                @intCast(value & 0xFF),
            };
            try self.send_data(&bytes);
        }

        pub fn set_orientation(self: *Self, orientation: Orientation) !void {
            // MADCTL bits
            const MADCTL_MY: u8 = 0x80; // Row Address Order
            const MADCTL_MX: u8 = 0x40; // Column Address Order
            const MADCTL_MV: u8 = 0x20; // Row/Column Exchange
            const MADCTL_BGR: u8 = 0x08; // BGR color order

            const madctl_value: u8 = switch (orientation) {
                .Portrait => MADCTL_MX | MADCTL_BGR,
                .Landscape => MADCTL_MV | MADCTL_BGR,
                .PortraitFlipped => MADCTL_MY | MADCTL_BGR,
                .LandscapeFlipped => MADCTL_MX | MADCTL_MY | MADCTL_MV | MADCTL_BGR,
            };

            try self.send_command(.MADCTL);
            try self.send_data_byte(madctl_value);
        }

        /// Send bulk pixel data (for optimized fill operations)
        pub fn send_pixels(self: *const Self, pixels: u32, color: Color) !void {
            dc_pin.write(.High); // Data mode
            self.select();

            const color_hi: u8 = @intCast((color >> 8) & 0xFF);
            const color_lo: u8 = @intCast(color & 0xFF);
            const color_bytes = [_]u8{ color_hi, color_lo };

            var i: u32 = 0;
            while (i < pixels) : (i += 1) {
                try self.spi.write_blocking(&color_bytes);
            }

            self.deselect();
        }

        /// Set address window for drawing
        fn set_address_window(self: *const Self, x0: u16, y0: u16, x1: u16, y1: u16) !void {
            // Column Address Set
            try self.send_command(.CASET);
            try self.send_data(&[_]u8{
                @intCast((x0 >> 8) & 0xFF),
                @intCast(x0 & 0xFF),
                @intCast((x1 >> 8) & 0xFF),
                @intCast(x1 & 0xFF),
            });

            // Row Address Set
            try self.send_command(.RASET);
            try self.send_data(&[_]u8{
                @intCast((y0 >> 8) & 0xFF),
                @intCast(y0 & 0xFF),
                @intCast((y1 >> 8) & 0xFF),
                @intCast(y1 & 0xFF),
            });

            // Memory Write
            try self.send_command(.RAMWR);
        }

        /// Draw a single pixel
        pub fn draw_pixel(self: *const Self, x: u16, y: u16, color: Color) !void {
            try self.set_address_window(x, y, x, y);
            try self.send_data_u16(color);
        }

        /// Perform hardware reset
        fn reset(self: *Self) void {
            _ = self;
            rst_pin.write(.Low);
            hal.clock.delay_ms(10);
            rst_pin.write(.High);
            hal.clock.delay_ms(120);
        }
    };
}

/// ILI9341 Display Driver
/// Generic over GPIO pin types to support comptime pin configuration
pub fn ILI9341(comptime dc_pin: hal.gpio.Pin, comptime rst_pin: hal.gpio.Pin, comptime cs_pin: ?hal.gpio.Pin) type {
    return struct {
        const Self = @This();

        spi: *const hal.spi.SPI_Device,
        height: u16,
        width: u16,
        orientation: Orientation,

        tr: ILI9341_Transport(dc_pin, rst_pin, cs_pin),

        /// Initialize the ILI9341 display
        pub fn init(spi: *const hal.spi.SPI_Device, orientation: Orientation) !Self {
            const Transport = ILI9341_Transport(dc_pin, rst_pin, cs_pin);

            var display = Self{
                .spi = spi,
                .width = WIDTH,
                .height = HEIGHT,
                .orientation = orientation,
                .tr = try Transport.init(spi),
            };

            // Initialize display
            try display.tr.init_display();

            // Set orientation
            try display.set_orientation(orientation);

            return display;
        }

        /// Set display orientation
        pub fn set_orientation(self: *Self, orientation: Orientation) !void {
            self.orientation = orientation;

            // Update dimensions based on orientation
            switch (orientation) {
                .Portrait, .PortraitFlipped => {
                    self.width = 240;
                    self.height = 320;
                },
                .Landscape, .LandscapeFlipped => {
                    self.width = 320;
                    self.height = 240;
                },
            }

            try self.tr.set_orientation(orientation);
        }

        /// Fill entire screen with a color
        pub fn fill_screen(self: *const Self, color: Color) !void {
            try self.fill_rect(0, 0, self.width, self.height, color);
        }

        /// Fill a rectangle with a color
        pub fn fill_rect(self: *const Self, x: u16, y: u16, w: u16, h: u16, color: Color) !void {
            if (x >= self.width or y >= self.height) return;

            const x1 = @min(x + w - 1, self.width - 1);
            const y1 = @min(y + h - 1, self.height - 1);

            try self.tr.set_address_window(x, y, x1, y1);

            // Send color data for all pixels
            const pixels = (@as(u32, x1) - x + 1) * (@as(u32, y1) - y + 1);
            try self.tr.send_pixels(pixels, color);
        }

        /// Draw a single pixel
        pub fn draw_pixel(self: *const Self, x: u16, y: u16, color: Color) !void {
            if (x >= self.width or y >= self.height) return;
            try self.tr.draw_pixel(x, y, color);
        }

        /// Draw a line using Bresenham's algorithm
        pub fn draw_line(self: *const Self, x0: u16, y0: u16, x1: u16, y1: u16, color: Color) !void {
            // Optimize for horizontal/vertical lines
            if (y0 == y1) {
                const x_start = @min(x0, x1);
                const w = @max(x0, x1) - x_start + 1;
                return self.draw_hline(x_start, y0, w, color);
            }
            if (x0 == x1) {
                const y_start = @min(y0, y1);
                const h = @max(y0, y1) - y_start + 1;
                return self.draw_vline(x0, y_start, h, color);
            }

            // Bresenham's line algorithm
            const dx: i32 = @intCast(@abs(@as(i32, x1) - @as(i32, x0)));
            const dy: i32 = @intCast(@abs(@as(i32, y1) - @as(i32, y0)));
            const sx: i32 = if (x0 < x1) 1 else -1;
            const sy: i32 = if (y0 < y1) 1 else -1;
            var err = dx - dy;

            var x: i32 = @intCast(x0);
            var y: i32 = @intCast(y0);

            while (true) {
                try self.draw_pixel(@intCast(x), @intCast(y), color);

                if (x == x1 and y == y1) break;

                const e2 = 2 * err;
                if (e2 > -dy) {
                    err -= dy;
                    x += sx;
                }
                if (e2 < dx) {
                    err += dx;
                    y += sy;
                }
            }
        }

        /// Draw a rectangle outline
        pub fn draw_rect(self: *const Self, x: u16, y: u16, w: u16, h: u16, color: Color) !void {
            try self.draw_hline(x, y, w, color); // Top
            try self.draw_hline(x, y + h - 1, w, color); // Bottom
            try self.draw_vline(x, y, h, color); // Left
            try self.draw_vline(x + w - 1, y, h, color); // Right
        }

        /// Convert RGB888 to RGB565
        pub fn rgb565(r: u8, g: u8, b: u8) Color {
            return (@as(u16, r & 0xF8) << 8) |
                (@as(u16, g & 0xFC) << 3) |
                (@as(u16, b) >> 3);
        }

        /// Draw a horizontal line
        fn draw_hline(self: *const Self, x: u16, y: u16, w: u16, color: Color) !void {
            try self.fill_rect(x, y, w, 1, color);
        }

        /// Draw a vertical line
        fn draw_vline(self: *const Self, x: u16, y: u16, h: u16, color: Color) !void {
            try self.fill_rect(x, y, 1, h, color);
        }
    };
}
