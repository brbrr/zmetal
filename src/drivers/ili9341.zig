// FIXME: refactor it. at least allcaps constants and color > tagged union
const std = @import("std");
const microzig = @import("microzig");
const hal = microzig.hal;

pub const font = @import("font.zig");
pub const Font = font.Font;

pub const WIDTH = 320;
pub const HEIGHT = 240;
const FB_SIZE = WIDTH * HEIGHT * 2; // 153,600 bytes
pub const Color = u16;

// Tile grid for checksum-diff partial flush. WIDTH/HEIGHT must divide evenly.
pub const TILE_W = 32;
pub const TILE_H = 48;
pub const TILE_COLS = WIDTH / TILE_W; // 10
pub const TILE_ROWS = HEIGHT / TILE_H; // 5
pub const TILE_COUNT = TILE_COLS * TILE_ROWS; // 50
const TILE_BYTES = TILE_W * TILE_H * 2; // 3072

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
};

pub const Orientation = enum {
    Portrait,
    Landscape,
    PortraitFlipped,
    LandscapeFlipped,
};

const Command = enum(u8) {
    SWRESET = 0x01,
    SLPOUT = 0x11,
    DISPON = 0x29,
    CASET = 0x2A,
    RASET = 0x2B,
    RAMWR = 0x2C,
    MADCTL = 0x36,
    PIXFMT = 0x3A,
    FRMCTR1 = 0xB1,
    DFUNCTR = 0xB6,
    PWCTR1 = 0xC0,
    PWCTR2 = 0xC1,
    VMCTR1 = 0xC5,
    VMCTR2 = 0xC7,
    PWCTRA = 0xCB,
    PWCTRB = 0xCF,
    DTCA = 0xE8,
    DTCB = 0xEA,
    POWER_SEQ = 0xED,
    ENABLE_3G = 0xF2,
    PUMP_RATIO = 0xF7,
    GAMMASET = 0x26,
    GMCTRP1 = 0xE0,
    GMCTRN1 = 0xE1,
};

pub fn ILI9341_Transport(comptime dc_pin: hal.gpio.Pin, comptime rst_pin: hal.gpio.Pin, comptime cs_pin: ?hal.gpio.Pin) type {
    return struct {
        const Self = @This();

        spi: *const hal.spi.SPI_Device,

        pub fn init(spi: *const hal.spi.SPI_Device) !Self {
            dc_pin.configure();
            rst_pin.configure();

            if (cs_pin) |cs| {
                cs.configure();
                cs.write(.High);
            }

            return .{ .spi = spi };
        }

        pub fn init_display(self: *Self) !void {
            self.reset();

            try self.send_command(.SWRESET);
            hal.clock.delay_ms(100);

            try self.send_command(.PWCTRA);
            try self.send_data(&[_]u8{ 0x39, 0x2C, 0x00, 0x34, 0x02 });

            try self.send_command(.PWCTRB);
            try self.send_data(&[_]u8{ 0x00, 0xC1, 0x30 });

            try self.send_command(.DTCA);
            try self.send_data(&[_]u8{ 0x85, 0x00, 0x78 });

            try self.send_command(.DTCB);
            try self.send_data(&[_]u8{ 0x00, 0x00 });

            try self.send_command(.POWER_SEQ);
            try self.send_data(&[_]u8{ 0x64, 0x03, 0x12, 0x81 });

            try self.send_command(.PUMP_RATIO);
            try self.send_data(&[_]u8{0x20});

            try self.send_command(.PWCTR1);
            try self.send_data(&[_]u8{0x23});

            try self.send_command(.PWCTR2);
            try self.send_data(&[_]u8{0x10});

            try self.send_command(.VMCTR1);
            try self.send_data(&[_]u8{ 0x3E, 0x28 });

            try self.send_command(.VMCTR2);
            try self.send_data(&[_]u8{0x86});

            try self.send_command(.MADCTL);
            try self.send_data(&[_]u8{0x48});

            try self.send_command(.PIXFMT);
            try self.send_data(&[_]u8{0x55});

            try self.send_command(.FRMCTR1);
            try self.send_data(&[_]u8{ 0x00, 0x18 });

            try self.send_command(.DFUNCTR);
            try self.send_data(&[_]u8{ 0x08, 0x82, 0x27 });

            try self.send_command(.ENABLE_3G);
            try self.send_data(&[_]u8{0x00});

            try self.send_command(.GAMMASET);
            try self.send_data(&[_]u8{0x01});

            try self.send_command(.GMCTRP1);
            try self.send_data(&[_]u8{
                0x0F, 0x31, 0x2B, 0x0C, 0x0E, 0x08, 0x4E, 0xF1,
                0x37, 0x07, 0x10, 0x03, 0x0E, 0x09, 0x00,
            });

            try self.send_command(.GMCTRN1);
            try self.send_data(&[_]u8{
                0x00, 0x0E, 0x14, 0x03, 0x11, 0x07, 0x31, 0xC1,
                0x48, 0x08, 0x0F, 0x0C, 0x31, 0x36, 0x0F,
            });

            try self.send_command(.SLPOUT);
            hal.clock.delay_ms(120);

            try self.send_command(.DISPON);
            hal.clock.delay_ms(100);
        }

        inline fn select(self: *const Self) void {
            _ = self;
            if (cs_pin) |cs| {
                cs.write(.Low);
            }
        }

        inline fn deselect(self: *const Self) void {
            _ = self;
            if (cs_pin) |cs| {
                cs.write(.High);
            }
        }

        fn send_command(self: *const Self, cmd: Command) !void {
            dc_pin.write(.Low);
            self.select();
            try self.spi.write_blocking(&[_]u8{@intFromEnum(cmd)});
            self.deselect();
        }

        fn send_data(self: *const Self, data: []const u8) !void {
            dc_pin.write(.High);
            self.select();
            try self.spi.write_blocking(data);
            self.deselect();
        }

        pub fn set_orientation(self: *Self, orientation: Orientation) !void {
            const MADCTL_MY: u8 = 0x80;
            const MADCTL_MX: u8 = 0x40;
            const MADCTL_MV: u8 = 0x20;
            const MADCTL_BGR: u8 = 0x08;

            const madctl_value: u8 = switch (orientation) {
                .Portrait => MADCTL_MX | MADCTL_BGR,
                .Landscape => MADCTL_MV | MADCTL_BGR,
                .PortraitFlipped => MADCTL_MY | MADCTL_BGR,
                .LandscapeFlipped => MADCTL_MX | MADCTL_MY | MADCTL_MV | MADCTL_BGR,
            };

            try self.send_command(.MADCTL);
            try self.send_data(&[_]u8{madctl_value});
        }

        fn set_address_window(self: *const Self, x0: u16, y0: u16, x1: u16, y1: u16) !void {
            try self.send_command(.CASET);
            try self.send_data(&[_]u8{
                @intCast((x0 >> 8) & 0xFF), @intCast(x0 & 0xFF),
                @intCast((x1 >> 8) & 0xFF), @intCast(x1 & 0xFF),
            });

            try self.send_command(.RASET);
            try self.send_data(&[_]u8{
                @intCast((y0 >> 8) & 0xFF), @intCast(y0 & 0xFF),
                @intCast((y1 >> 8) & 0xFF), @intCast(y1 & 0xFF),
            });

            try self.send_command(.RAMWR);
        }

        fn reset(self: *Self) void {
            _ = self;
            rst_pin.write(.Low);
            hal.clock.delay_ms(10);
            rst_pin.write(.High);
            hal.clock.delay_ms(120);
        }
    };
}

pub var display_framebuffer: [FB_SIZE]u8 align(4) linksection(".sram1_bss") = @splat(0);

// Contiguous staging buffer for one dirty tile (partial flush).
var display_scratch: [TILE_BYTES]u8 align(4) linksection(".sram1_bss") = @splat(0);

/// ILI9341 driver with chunked DMA framebuffer transfers
pub fn ILI9341_DMA(
    comptime dc_pin: hal.gpio.Pin,
    comptime rst_pin: hal.gpio.Pin,
    comptime cs_pin: ?hal.gpio.Pin,
) type {
    return struct {
        const Self = @This();
        const Transport = ILI9341_Transport(dc_pin, rst_pin, cs_pin);
        const MAX_CHUNK_SIZE = 65535; // SPI DMA limit

        transport: Transport,
        spi: *hal.spi.SPI_Device,
        orientation: Orientation,
        framebuffer: []u8,

        // Chunking state
        chunk_remaining: usize = 0,
        chunk_offset: usize = 0,
        user_flush_callback: ?*const fn (*Self) void = null,
        done: bool = true,
        // Source the chunk engine streams from (framebuffer for a full flush,
        // scratch for a per-tile partial flush).
        dma_src: []const u8 = &.{},

        // Tile checksum-diff state (partial flush)
        tile_hash: [TILE_COUNT]u32 = @splat(0),
        hashes_valid: bool = false, // first flush_diff paints every tile
        dirty_tiles: [TILE_COUNT]u16 = undefined,
        dirty_count: usize = 0,
        pump_idx: usize = 0,
        needs_pump: bool = false,

        pub fn init(spi: *hal.spi.SPI_Device, framebuffer: []u8) !Self {
            if (framebuffer.len < FB_SIZE) {
                return error.FramebufferTooSmall;
            }

            const transport = try Transport.init(spi);

            var self = Self{
                .transport = transport,
                .spi = spi,
                .orientation = .Portrait,
                .framebuffer = framebuffer,
            };

            try self.transport.init_display();

            return self;
        }

        pub fn set_orientation(self: *Self, orientation: Orientation) !void {
            self.orientation = orientation;
            try self.transport.set_orientation(orientation);
        }

        // ============================================================
        // Drawing Operations (to framebuffer)
        // ============================================================

        pub fn fill_screen(self: *Self, color: Color) void {
            const color_bytes = [_]u8{
                @as(u8, @truncate(color >> 8)),
                @as(u8, @truncate(color & 0xFF)),
            };

            var i: usize = 0;
            while (i < self.framebuffer.len) : (i += 2) {
                self.framebuffer[i] = color_bytes[0];
                self.framebuffer[i + 1] = color_bytes[1];
            }
        }

        pub fn draw_pixel(self: *Self, x: u16, y: u16, color: Color) void {
            if (x >= WIDTH or y >= HEIGHT) return;

            const offset = (@as(usize, y) * WIDTH + @as(usize, x)) * 2;
            self.framebuffer[offset] = @as(u8, @truncate(color >> 8));
            self.framebuffer[offset + 1] = @as(u8, @truncate(color & 0xFF));
        }

        pub fn fill_rect(self: *Self, x: u16, y: u16, w: u16, h: u16, color: Color) void {
            const color_bytes = [_]u8{
                @as(u8, @truncate(color >> 8)),
                @as(u8, @truncate(color & 0xFF)),
            };

            const x_end = @min(x + w, WIDTH);
            const y_end = @min(y + h, HEIGHT);

            var row = y;
            while (row < y_end) : (row += 1) {
                var col = x;
                while (col < x_end) : (col += 1) {
                    const offset = (@as(usize, row) * WIDTH + @as(usize, col)) * 2;
                    self.framebuffer[offset] = color_bytes[0];
                    self.framebuffer[offset + 1] = color_bytes[1];
                }
            }
        }

        /// Draw a line using Bresenham's algorithm
        pub fn draw_line(self: *Self, x0: u16, y0: u16, x1: u16, y1: u16, color: Color) void {
            // Optimize for horizontal/vertical lines
            if (y0 == y1) {
                const x_start = @min(x0, x1);
                const w = @max(x0, x1) - x_start + 1;
                self.fill_rect(x_start, y0, w, 1, color);
                return;
            }
            if (x0 == x1) {
                const y_start = @min(y0, y1);
                const h = @max(y0, y1) - y_start + 1;
                self.fill_rect(x0, y_start, 1, h, color);
                return;
            }

            // Bresenham's line algorithm (corrected)
            const dx: i32 = @intCast(@abs(@as(i32, x1) - @as(i32, x0)));
            const dy: i32 = @intCast(@abs(@as(i32, y1) - @as(i32, y0)));
            const sx: i32 = if (x0 < x1) 1 else -1;
            const sy: i32 = if (y0 < y1) 1 else -1;
            var err = dx - dy; // Corrected: was dx + dy

            var x: i32 = @intCast(x0);
            var y: i32 = @intCast(y0);

            while (true) {
                // Bounds check before drawing
                if (x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT) {
                    self.draw_pixel(@intCast(x), @intCast(y), color);
                }

                if (x == x1 and y == y1) break;

                const e2 = 2 * err;
                if (e2 > -dy) { // Corrected: was e2 >= dy
                    err -= dy;
                    x += sx;
                }
                if (e2 < dx) { // Corrected: was e2 <= dx
                    err += dx;
                    y += sy;
                }
            }
        }

        /// Draw a rectangle outline
        pub fn draw_rect(self: *Self, x: u16, y: u16, w: u16, h: u16, color: Color) void {
            self.draw_hline(x, y, w, color);
            self.draw_hline(x, y + h - 1, w, color);
            self.draw_vline(x, y, h, color);
            self.draw_vline(x + w - 1, y, h, color);
        }

        fn draw_hline(self: *Self, x: u16, y: u16, w: u16, color: Color) void {
            self.fill_rect(x, y, w, 1, color);
        }

        fn draw_vline(self: *Self, x: u16, y: u16, h: u16, color: Color) void {
            self.fill_rect(x, y, 1, h, color);
        }

        // ============================================================
        // Text Rendering
        // ============================================================

        /// Draw a single character with the given font. Foreground pixels use
        /// `fg`; the rest of the glyph cell is filled with `bg` so previously
        /// drawn text at the same position is overwritten.
        pub fn draw_char(self: *Self, x: u16, y: u16, ch: u8, f: Font, fg: Color, bg: Color) void {
            if (ch < f.first) return;
            const glyph = (@as(usize, ch - f.first)) * f.height;
            if (glyph + f.height > f.data.len) return;

            var row: u16 = 0;
            while (row < f.height) : (row += 1) {
                const bits = f.data[glyph + row];
                var col: u16 = 0;
                while (col < f.width) : (col += 1) {
                    const on = (bits << @intCast(col)) & 0x8000 != 0;
                    self.draw_pixel(x + col, y + row, if (on) fg else bg);
                }
            }
        }

        /// Draw a string starting at (x, y), advancing by the font width per
        /// character. Returns the x coordinate just past the last glyph.
        pub fn draw_string(self: *Self, x: u16, y: u16, str: []const u8, f: Font, fg: Color, bg: Color) u16 {
            var cx = x;
            for (str) |ch| {
                self.draw_char(cx, y, ch, f, fg, bg);
                cx += f.width;
            }
            return cx;
        }

        // ============================================================
        // Chunked DMA Transfer (following libdaisy pattern)
        // ============================================================

        /// Start chunked DMA transfer of framebuffer
        pub fn flush(self: *Self, callback: ?*const fn (*Self) void) !void {
            if (self.spi.is_dma_busy()) {
                return error.FlushInProgress;
            }

            self.done = false;
            // Setup address window for full screen
            try self.transport.set_address_window(0, 0, WIDTH - 1, HEIGHT - 1);

            // Set data mode and chip select
            dc_pin.write(.High);
            if (cs_pin) |cs| {
                cs.write(.Low);
            }

            // Initialize chunking state (single run over the whole framebuffer)
            self.dma_src = self.framebuffer;
            self.dirty_count = 0; // single run: finish on completion
            self.pump_idx = 0;
            self.chunk_offset = 0;
            self.chunk_remaining = self.framebuffer.len;
            self.user_flush_callback = callback;

            // Start first chunk
            try self.send_next_chunk();
        }

        /// Send next chunk (called from the DMA-completion ISR or foreground start).
        fn send_next_chunk(self: *Self) !void {
            if (self.chunk_remaining == 0) {
                // Current run (whole framebuffer, or one tile) finished.
                if (cs_pin) |cs| {
                    cs.write(.High);
                }

                // More dirty tiles queued? Defer the next one to the foreground
                // pump — we must not issue SPI commands from this ISR context.
                if (self.pump_idx + 1 < self.dirty_count) {
                    self.needs_pump = true;
                    return;
                }

                self.done = true;

                if (self.user_flush_callback) |cb| {
                    self.user_flush_callback = null;
                    cb(self);
                }
                return;
            }

            // Calculate chunk size
            const chunk_size = @min(self.chunk_remaining, MAX_CHUNK_SIZE);
            const chunk_data = self.dma_src[self.chunk_offset..][0..chunk_size];

            // Update state for next chunk
            self.chunk_offset += chunk_size;
            self.chunk_remaining -= chunk_size;

            // Start DMA transfer with our callback
            try self.spi.write_dma(chunk_data, chunk_complete_callback, self);
        }

        /// DMA completion callback - sends next chunk or finishes
        fn chunk_complete_callback(ctx: ?*anyopaque) void {
            var self: *Self = @ptrCast(@alignCast(ctx.?));
            self.send_next_chunk() catch {
                // Error - cleanup
                if (cs_pin) |cs| {
                    cs.write(.High);
                }
                self.chunk_remaining = 0;
                self.dirty_count = 0;
                self.needs_pump = false;
                self.done = true;
                if (self.user_flush_callback) |cb| {
                    self.user_flush_callback = null;
                    cb(self);
                }
            };
        }

        // ============================================================
        // Tile checksum-diff partial flush
        // ============================================================

        /// FNV-1a hash of one tile, read directly from the framebuffer (rows are
        /// strided by the full screen width).
        fn hash_tile(self: *Self, tx: u16, ty: u16) u32 {
            const x0 = @as(usize, tx) * TILE_W;
            const y0 = @as(usize, ty) * TILE_H;
            var h: u32 = 2166136261;
            var r: usize = 0;
            while (r < TILE_H) : (r += 1) {
                const off = ((y0 + r) * WIDTH + x0) * 2;
                const row = self.framebuffer[off..][0 .. TILE_W * 2];
                var i: usize = 0;
                while (i < row.len) : (i += 4) {
                    const w = std.mem.readInt(u32, row[i..][0..4], .little);
                    h = (h ^ w) *% 16777619;
                }
            }
            return h;
        }

        /// Copy a tile's strided rows into the contiguous scratch buffer, set the
        /// panel window to the tile, and kick the async DMA. Foreground only.
        fn start_tile(self: *Self, tile_idx: u16) !void {
            const tx: u16 = tile_idx % TILE_COLS;
            const ty: u16 = tile_idx / TILE_COLS;
            const x0: usize = @as(usize, tx) * TILE_W;
            const y0: usize = @as(usize, ty) * TILE_H;

            var r: usize = 0;
            while (r < TILE_H) : (r += 1) {
                const src_off = ((y0 + r) * WIDTH + x0) * 2;
                const dst_off = r * TILE_W * 2;
                @memcpy(
                    display_scratch[dst_off..][0 .. TILE_W * 2],
                    self.framebuffer[src_off..][0 .. TILE_W * 2],
                );
            }

            try self.transport.set_address_window(
                @intCast(x0),
                @intCast(y0),
                @intCast(x0 + TILE_W - 1),
                @intCast(y0 + TILE_H - 1),
            );
            dc_pin.write(.High);
            if (cs_pin) |cs| {
                cs.write(.Low);
            }

            self.dma_src = &display_scratch;
            self.chunk_offset = 0;
            self.chunk_remaining = TILE_BYTES;
            try self.send_next_chunk();
        }

        /// Partial flush: hash every tile, transmit only the ones that changed
        /// since the last flush. Async — sequenced across tiles by `pump`.
        pub fn flush_diff(self: *Self, callback: ?*const fn (*Self) void) !void {
            if (self.spi.is_dma_busy()) {
                return error.FlushInProgress;
            }

            self.dirty_count = 0;
            var idx: u16 = 0;
            var ty: u16 = 0;
            while (ty < TILE_ROWS) : (ty += 1) {
                var tx: u16 = 0;
                while (tx < TILE_COLS) : (tx += 1) {
                    const h = self.hash_tile(tx, ty);
                    if (!self.hashes_valid or h != self.tile_hash[idx]) {
                        self.tile_hash[idx] = h;
                        self.dirty_tiles[self.dirty_count] = idx;
                        self.dirty_count += 1;
                    }
                    idx += 1;
                }
            }
            self.hashes_valid = true;
            self.user_flush_callback = callback;
            self.needs_pump = false;
            self.pump_idx = 0;

            if (self.dirty_count == 0) {
                self.done = true;
                if (callback) |cb| {
                    self.user_flush_callback = null;
                    cb(self);
                }
                return;
            }

            self.done = false;
            try self.start_tile(self.dirty_tiles[0]);
        }

        /// Advance a multi-tile flush to the next dirty tile. Call from the
        /// foreground loop (never the ISR) whenever a flush is in progress.
        pub fn pump(self: *Self) void {
            if (!self.needs_pump) return;
            self.needs_pump = false;
            self.pump_idx += 1;
            self.start_tile(self.dirty_tiles[self.pump_idx]) catch {
                if (cs_pin) |cs| {
                    cs.write(.High);
                }
                self.dirty_count = 0;
                self.done = true;
                if (self.user_flush_callback) |cb| {
                    self.user_flush_callback = null;
                    cb(self);
                }
            };
        }

        /// Blocking flush - waits for all chunks to complete
        pub fn flush_wait(self: *Self) !void {
            self.done = false;
            try self.flush(struct {
                fn callback(s: *Self) void {
                    s.done = true;
                }
            }.callback);

            while (!self.done) {
                microzig.cpu.nop();
            }
        }

        /// Check if flush is complete
        pub fn is_flush_complete(self: *const Self) bool {
            return !self.spi.is_dma_busy() and self.chunk_remaining == 0;
        }

        pub fn rgb565(r: u8, g: u8, b: u8) Color {
            return (@as(u16, r & 0xF8) << 8) |
                (@as(u16, g & 0xFC) << 3) |
                (@as(u16, b) >> 3);
        }
    };
}
