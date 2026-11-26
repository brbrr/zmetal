// FIXME: refactor it. at least allcaps constants and color > tagged union
const std = @import("std");
const microzig = @import("microzig");
const hal = microzig.hal;

pub const font = @import("font.zig");
pub const Font = font.Font;
pub const tile_diff = @import("tile_diff.zig");
/// The controller-specific part: init sequence, colour order, mirroring.
pub const panel_init = @import("panel_init.zig");

pub const WIDTH = tile_diff.WIDTH;
pub const HEIGHT = tile_diff.HEIGHT;
pub const FB_SIZE = tile_diff.FB_SIZE; // 153,600 bytes
pub const Color = u16;

// Tile grid for checksum-diff partial flush. WIDTH/HEIGHT must divide evenly.
pub const TILE_W = tile_diff.TILE_W;
pub const TILE_H = tile_diff.TILE_H;
pub const TILE_COLS = tile_diff.TILE_COLS; // 10
pub const TILE_ROWS = tile_diff.TILE_ROWS; // 5
pub const TILE_COUNT = tile_diff.TILE_COUNT; // 50
pub const TILE_BYTES = TILE_W * TILE_H * 2; // 3072

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

pub const Orientation = panel_init.Orientation;

/// The commands the driver sends itself (the same opcodes on ILI9341 and
/// ST7789). The panel's init sequence sends its own opcodes by number.
const Command = enum(u8) {
    CASET = 0x2A,
    RASET = 0x2B,
    RAMWR = 0x2C,
    MADCTL = 0x36,
    _,
};

pub fn ILI9341_Transport(comptime dc_pin: hal.gpio.Pin, comptime rst_pin: hal.gpio.Pin, comptime cs_pin: ?hal.gpio.Pin) type {
    return PanelTransport(panel_init.ili9341, dc_pin, rst_pin, cs_pin);
}

/// The SPI transport for the controller `panel` describes: DC, CS and RST,
/// the commands, the init sequence and MADCTL.
pub fn PanelTransport(comptime panel: panel_init.Panel, comptime dc_pin: hal.gpio.Pin, comptime rst_pin: hal.gpio.Pin, comptime cs_pin: ?hal.gpio.Pin) type {
    if (!panel_init.madctlAgrees(panel)) @compileError("the panel's init table must set MADCTL to " ++
        "panel_init.madctl(panel, .Portrait), the orientation recorded after init: " ++
        "a table copied with `bgr` or `mirror_x` changed needs its MADCTL step changed too");
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

        /// The hardware reset, then the panel's init sequence.
        pub fn init_display(self: *Self) !void {
            self.reset();
            try panel_init.run(panel.init, InitSink{ .transport = self });
        }

        /// `panel_init.run`'s sink: the writes and waits of the sequence.
        const InitSink = struct {
            transport: *const Self,

            pub fn command(s: InitSink, op: u8) !void {
                try s.transport.send_command(@enumFromInt(op));
            }
            pub fn data(s: InitSink, params: []const u8) !void {
                try s.transport.send_data(params);
            }
            pub fn delayMs(_: InitSink, ms: u16) void {
                hal.clock.delay_ms(ms);
            }
        };

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
            try self.send_command(.MADCTL);
            try self.send_data(&[_]u8{panel_init.madctl(panel, orientation)});
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


/// ILI9341 driver with chunked DMA framebuffer transfers
pub fn ILI9341_DMA(
    comptime dc_pin: hal.gpio.Pin,
    comptime rst_pin: hal.gpio.Pin,
    comptime cs_pin: ?hal.gpio.Pin,
) type {
    return PanelDMA(panel_init.ili9341, dc_pin, rst_pin, cs_pin);
}

/// Driver with chunked DMA framebuffer transfers for the 320x240 RGB565
/// controller `panel` describes (`panel_init.ili9341`, `panel_init.st7789`).
pub fn PanelDMA(
    comptime panel: panel_init.Panel,
    comptime dc_pin: hal.gpio.Pin,
    comptime rst_pin: hal.gpio.Pin,
    comptime cs_pin: ?hal.gpio.Pin,
) type {
    return struct {
        const Self = @This();
        const Transport = PanelTransport(panel, dc_pin, rst_pin, cs_pin);
        const MAX_CHUNK_SIZE = 65535; // SPI DMA limit

        transport: Transport,
        spi: *hal.spi.SPI_Device,
        orientation: Orientation,
        framebuffer: []u8,
        /// The buffer that a run of dirty tiles is copied to (partial
        /// flush). A run is at most as many tiles wide as it holds.
        scratch: []u8,

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
        /// The first dirty tile that no run took yet.
        pump_idx: usize = 0,
        needs_pump: bool = false,

        /// `framebuffer` (>= FB_SIZE) and `scratch` (>= TILE_BYTES) are owned by
        /// the caller and read by DMA: place them in `linksection(".sram1_bss")`,
        /// word-aligned. They are not zero-initialized — `@memset` them first.
        /// A scratch of `n * TILE_BYTES` lets a partial flush send up to `n`
        /// tiles of one row in one transfer; more than `TILE_COLS - 1` is
        /// not used.
        pub fn init(spi: *hal.spi.SPI_Device, framebuffer: []u8, scratch: []u8) !Self {
            if (framebuffer.len < FB_SIZE) {
                return error.FramebufferTooSmall;
            }
            if (scratch.len < TILE_BYTES) {
                return error.ScratchTooSmall;
            }

            const transport = try Transport.init(spi);

            var self = Self{
                .transport = transport,
                .spi = spi,
                .orientation = .Portrait,
                // Exact sizes: flush streams framebuffer.len bytes, so a larger
                // caller buffer would overrun the 320x240 window.
                .framebuffer = framebuffer[0..FB_SIZE],
                .scratch = scratch[0 .. @as(usize, @min(scratch.len / TILE_BYTES, TILE_COLS - 1)) * TILE_BYTES],
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
            if (w == 0 or h == 0) return; // `+ h - 1` / `+ w - 1` would underflow
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
            errdefer self.done = true; // a failed start must not look in-flight forever
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

        /// Sends the whole framebuffer with polled SPI writes, after it stops
        /// any DMA flush in flight. For a halt path with interrupts off: it
        /// needs no DMA interrupt to finish. The next `flush_diff` sends
        /// every tile.
        pub fn flush_blocking(self: *Self) !void {
            self.spi.abort_dma();
            self.chunk_remaining = 0;
            self.dirty_count = 0;
            self.needs_pump = false;
            self.user_flush_callback = null;
            if (cs_pin) |cs| cs.write(.High);
            try self.transport.set_address_window(0, 0, WIDTH - 1, HEIGHT - 1);
            dc_pin.write(.High);
            if (cs_pin) |cs| cs.write(.Low);
            defer if (cs_pin) |cs| cs.write(.High);
            // An even chunk size keeps every pixel's two bytes in one write.
            const chunk: usize = MAX_CHUNK_SIZE - 1;
            var off: usize = 0;
            while (off < self.framebuffer.len) {
                const n = @min(self.framebuffer.len - off, chunk);
                try self.spi.write_blocking(self.framebuffer[off..][0..n]);
                off += n;
            }
            self.hashes_valid = false;
            self.done = true;
        }

        /// Send next chunk (called from the DMA-completion ISR or foreground start).
        fn send_next_chunk(self: *Self) anyerror!void {
            if (self.chunk_remaining == 0) {
                // Current run (whole framebuffer, or a run of tiles) finished.
                if (cs_pin) |cs| {
                    cs.write(.High);
                }

                // More dirty tiles queued: start their run here. The SPI is
                // idle once its end-of-transfer interrupt has run, so the
                // window commands' polled writes are safe in this context;
                // they and the copy of a run take some tens of microseconds.
                // A foreground pump per run would tie the frame rate to the
                // main loop's pass rate.
                if (self.pump_idx < self.dirty_count) {
                    try self.start_run();
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
                // The tiles not sent already carry their new hashes: the
                // next flush must send every tile.
                self.hashes_valid = false;
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

        /// Takes the next run of dirty tiles (`tile_diff.firstRun`), sets the
        /// panel window to it, and starts the DMA. The audio interrupt is
        /// above the two interrupts that end a transfer, so each transfer
        /// can wait for one audio block: a run makes the transfers few.
        ///
        /// A run of whole tile rows is one part of the framebuffer, and the
        /// DMA reads it there. A shorter run has a gap after each of its
        /// pixel rows, so its rows are copied into the scratch first.
        fn start_run(self: *Self) anyerror!void {
            const run = tile_diff.firstRun(self.dirty_tiles[self.pump_idx..self.dirty_count], self.scratch.len / TILE_BYTES);
            self.pump_idx += run.tiles();
            const x0: usize = @as(usize, run.tx) * TILE_W;
            const y0: usize = @as(usize, run.ty) * TILE_H;
            const row_bytes: usize = @as(usize, run.cols) * TILE_W * 2;
            const rows: usize = @as(usize, run.rows) * TILE_H;

            if (run.cols == TILE_COLS) {
                self.dma_src = self.framebuffer[y0 * WIDTH * 2 ..][0 .. rows * row_bytes];
            } else {
                var r: usize = 0;
                while (r < rows) : (r += 1) {
                    const src_off = ((y0 + r) * WIDTH + x0) * 2;
                    @memcpy(
                        self.scratch[r * row_bytes ..][0..row_bytes],
                        self.framebuffer[src_off..][0..row_bytes],
                    );
                }
                self.dma_src = self.scratch[0 .. rows * row_bytes];
            }

            try self.transport.set_address_window(
                @intCast(x0),
                @intCast(y0),
                @intCast(x0 + row_bytes / 2 - 1),
                @intCast(y0 + rows - 1),
            );
            dc_pin.write(.High);
            if (cs_pin) |cs| {
                cs.write(.Low);
            }

            self.chunk_offset = 0;
            self.chunk_remaining = self.dma_src.len;
            try self.send_next_chunk();
        }

        /// Partial flush: hash every tile, transmit only the ones that changed
        /// since the last flush. Async — the completion interrupt chains the runs.
        pub fn flush_diff(self: *Self, callback: ?*const fn (*Self) void) !void {
            return self.flush_tiles(tile_diff.all_tiles, callback);
        }

        /// `flush_diff` over the tiles in `mask` only (bit i is tile i,
        /// row-major). A caller that knows which part of the frame it drew
        /// skips the hash of the rest. A tile outside the mask keeps its
        /// hash, so a change there is sent by a later flush that masks it.
        pub fn flush_tiles(self: *Self, mask: tile_diff.Mask, callback: ?*const fn (*Self) void) !void {
            if (self.spi.is_dma_busy()) {
                return error.FlushInProgress;
            }

            self.dirty_count = tile_diff.collect(self.framebuffer, &self.tile_hash, self.hashes_valid, mask, &self.dirty_tiles);
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
            errdefer {
                self.done = true; // a failed start must not look in-flight forever
                self.hashes_valid = false; // and the unsent tiles must go next time
            }
            try self.start_run();
        }

        /// Advance a multi-tile flush to the next run of dirty tiles. The
        /// completion interrupt now chains the runs itself, so this does
        /// nothing unless a caller set `needs_pump`; it stays for callers
        /// that pump.
        pub fn pump(self: *Self) void {
            if (!self.needs_pump) return;
            self.needs_pump = false;
            self.start_run() catch {
                if (cs_pin) |cs| {
                    cs.write(.High);
                }
                self.dirty_count = 0;
                self.hashes_valid = false;
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

            // `done` is set from the DMA/SPI completion ISR: atomic load so the
            // read cannot be hoisted out of the loop.
            while (!@atomicLoad(bool, &self.done, .acquire)) {
                microzig.cpu.nop();
            }
        }

        /// Check if flush is complete
        pub fn is_flush_complete(self: *const Self) bool {
            // `done` covers the whole flush, including diff tiles still waiting
            // to be pumped (DMA idle + chunk_remaining == 0 is true between tiles).
            return @atomicLoad(bool, &self.done, .acquire);
        }

        pub fn rgb565(r: u8, g: u8, b: u8) Color {
            return (@as(u16, r & 0xF8) << 8) |
                (@as(u16, g & 0xFC) << 3) |
                (@as(u16, b) >> 3);
        }
    };
}
