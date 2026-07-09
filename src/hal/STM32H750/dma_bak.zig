//! DMA (Direct Memory Access) driver for STM32H750
//!
//! This module provides DMA support with the following features:
//! - DMA1 and DMA2 controllers (8 streams each)
//! - DMAMUX for flexible peripheral-to-stream routing
//! - Non-blocking transfers with callback support
//! - Job queue system for managing multiple concurrent transfers
//! - Automatic chunking for large transfers (>65535 bytes)
//! - Cache coherency management for STM32H7
//!
//! Architecture:
//! - Each DMA controller has 8 streams (independent transfer engines)
//! - DMAMUX routes peripheral DMA requests to streams
//! - Streams generate interrupts on transfer complete, half-transfer, and errors
//!
//! Example usage:
//! ```zig
//! // Configure stream for SPI1 TX
//! var stream = try dma.Stream.init(.DMA2, .Stream3);
//! try stream.configure(.{
//!     .direction = .MemoryToPeripheral,
//!     .peripheral_address = @intFromPtr(&chip.peripherals.SPI1.TXDR),
//!     .memory_address = @intFromPtr(buffer.ptr),
//!     .data_size = buffer.len,
//!     .priority = .VeryHigh,
//!     .dmamux_request = .SPI1_TX,
//! });
//! try stream.start(transfer_complete_callback);
//! ```

const std = @import("std");
const microzig = @import("microzig");
const chip = microzig.chip;
const rcc = @import("rcc.zig");
const cache = @import("cache.zig");
const dma_utils = @import("dma_utils.zig");

// Peripheral types
const DMA_Peripheral = chip.types.peripherals.DMA1;
const DMAMUX_Peripheral = chip.types.peripherals.DMAMUX1;

/// DMA controller selection
pub const Controller = enum {
    DMA1,
    DMA2,

    fn get_registers(self: Controller) *volatile DMA_Peripheral {
        return switch (self) {
            .DMA1 => chip.peripherals.DMA1,
            .DMA2 => chip.peripherals.DMA2,
        };
    }

    fn to_rcc_peripheral(self: Controller) rcc.RccPeriferals {
        return switch (self) {
            .DMA1 => .DMA1,
            .DMA2 => .DMA2,
        };
    }
};

/// DMA stream selection (0-7 for each controller)
pub const StreamNumber = enum(u3) {
    Stream0 = 0,
    Stream1 = 1,
    Stream2 = 2,
    Stream3 = 3,
    Stream4 = 4,
    Stream5 = 5,
    Stream6 = 6,
    Stream7 = 7,

    fn to_dmamux_channel(self: StreamNumber, controller: Controller) u8 {
        const base: u8 = switch (controller) {
            .DMA1 => 0,
            .DMA2 => 8,
        };
        return base + @intFromEnum(self);
    }
};

/// Transfer direction
pub const Direction = enum(u2) {
    PeripheralToMemory = 0,
    MemoryToPeripheral = 1,
    MemoryToMemory = 2,
};

/// Transfer priority
pub const Priority = enum(u2) {
    Low = 0,
    Medium = 1,
    High = 2,
    VeryHigh = 3,
};

/// Data size for transfers
pub const DataSize = enum(u2) {
    Byte = 0,      // 8-bit
    HalfWord = 1,  // 16-bit
    Word = 2,      // 32-bit
};

/// Burst transfer mode
pub const BurstMode = enum(u2) {
    Single = 0,     // Single transfer
    Incr4 = 1,      // Incremental burst of 4 beats
    Incr8 = 2,      // Incremental burst of 8 beats
    Incr16 = 3,     // Incremental burst of 16 beats
};

/// FIFO threshold level
pub const FifoThreshold = enum(u2) {
    Quarter = 0,    // 1/4 full
    Half = 1,       // 1/2 full
    ThreeQuarters = 2, // 3/4 full
    Full = 3,       // Full
};

/// Transfer status
pub const TransferStatus = enum {
    Complete,
    HalfComplete,
    Error,
    FifoError,
    DirectModeError,
};

/// Transfer completion callback
pub const TransferCallback = *const fn (status: TransferStatus) void;

/// DMA stream configuration
pub const StreamConfig = struct {
    direction: Direction,
    peripheral_address: u32,
    memory_address: u32,
    data_size: u32,  // Number of data items to transfer
    priority: Priority = .High,
    dmamux_request: dma_utils.DmaRequest,
    
    // Data sizes
    peripheral_data_size: DataSize = .Byte,
    memory_data_size: DataSize = .Byte,
    
    // Increment modes
    peripheral_increment: bool = false,
    memory_increment: bool = true,
    
    // Circular mode
    circular: bool = false,
    
    // Burst mode
    peripheral_burst: BurstMode = .Single,
    memory_burst: BurstMode = .Single,
    
    // FIFO mode
    fifo_mode: bool = true,
    fifo_threshold: FifoThreshold = .Full,
    
    // Double buffer mode
    double_buffer: bool = false,
    memory1_address: u32 = 0,
};

/// Stream state
const StreamState = enum {
    Idle,
    Busy,
    Error,
};

/// DMA Stream
pub const Stream = struct {
    controller: Controller,
    stream: StreamNumber,
    state: StreamState,
    callback: ?TransferCallback,
    
    // For chunked transfers
    chunk_remaining: u32,
    chunk_mem_addr: u32,
    
    pub fn init(controller: Controller, stream: StreamNumber) !Stream {
        // Enable DMA controller clock
        rcc.enable_clock(controller.to_rcc_peripheral());
        
        // Enable DMAMUX clock
        rcc.enable_clock(.DMAMUX1);
        
        return Stream{
            .controller = controller,
            .stream = stream,
            .state = .Idle,
            .callback = null,
            .chunk_remaining = 0,
            .chunk_mem_addr = 0,
        };
    }
    
    pub fn configure(self: *Stream, config: StreamConfig) !void {
        if (self.state == .Busy) {
            return error.StreamBusy;
        }
        
        const regs = self.controller.get_registers();
        
        // Disable stream before configuration
        self.disable_stream();
        
        // Wait for stream to be disabled
        while (self.is_enabled()) {}
        
        // Clear all interrupt flags
        self.clear_flags();
        
        // Configure DMAMUX to route peripheral request to this stream
        self.configure_dmamux(config.dmamux_request);
        
        // Configure stream based on stream number
        switch (self.stream) {
            .Stream0 => self.configure_stream_regs(&regs.S0CR, &regs.S0NDTR, &regs.S0PAR, &regs.S0M0AR, &regs.S0M1AR, &regs.S0FCR, config),
            .Stream1 => self.configure_stream_regs(&regs.S1CR, &regs.S1NDTR, &regs.S1PAR, &regs.S1M0AR, &regs.S1M1AR, &regs.S1FCR, config),
            .Stream2 => self.configure_stream_regs(&regs.S2CR, &regs.S2NDTR, &regs.S2PAR, &regs.S2M0AR, &regs.S2M1AR, &regs.S2FCR, config),
            .Stream3 => self.configure_stream_regs(&regs.S3CR, &regs.S3NDTR, &regs.S3PAR, &regs.S3M0AR, &regs.S3M1AR, &regs.S3FCR, config),
            .Stream4 => self.configure_stream_regs(&regs.S4CR, &regs.S4NDTR, &regs.S4PAR, &regs.S4M0AR, &regs.S4M1AR, &regs.S4FCR, config),
            .Stream5 => self.configure_stream_regs(&regs.S5CR, &regs.S5NDTR, &regs.S5PAR, &regs.S5M0AR, &regs.S5M1AR, &regs.S5FCR, config),
            .Stream6 => self.configure_stream_regs(&regs.S6CR, &regs.S6NDTR, &regs.S6PAR, &regs.S6M0AR, &regs.S6M1AR, &regs.S6FCR, config),
            .Stream7 => self.configure_stream_regs(&regs.S7CR, &regs.S7NDTR, &regs.S7PAR, &regs.S7M0AR, &regs.S7M1AR, &regs.S7FCR, config),
        }
    }
    
    fn configure_stream_regs(
        self: *Stream,
        cr: anytype,
        ndtr: anytype,
        par: anytype,
        m0ar: anytype,
        m1ar: anytype,
        fcr: anytype,
        config: StreamConfig,
    ) void {
        // Set peripheral address
        par.write_raw(@as(u32, @intCast(config.peripheral_address)));
        
        // Set memory address (ensure cache coherency)
        const mem_addr = config.memory_address;
        cache.clean_dcache_by_addr(mem_addr, config.data_size);
        m0ar.write_raw(@as(u32, @intCast(mem_addr)));
        
        if (config.double_buffer) {
            cache.clean_dcache_by_addr(config.memory1_address, config.data_size);
            m1ar.write_raw(@as(u32, @intCast(config.memory1_address)));
        }
        
        // Set number of data items (max 65535 per transfer)
        const chunk_size = @min(config.data_size, 65535);
        ndtr.write_raw(@as(u32, @intCast(chunk_size)));
        
        // Store chunking info if needed
        if (config.data_size > 65535) {
            self.chunk_remaining = config.data_size - chunk_size;
            self.chunk_mem_addr = mem_addr + chunk_size;
        } else {
            self.chunk_remaining = 0;
            self.chunk_mem_addr = 0;
        }
        
        // Configure control register
        cr.modify(.{
            .DIR = @intFromEnum(config.direction),
            .PINC = @intFromBool(config.peripheral_increment),
            .MINC = @intFromBool(config.memory_increment),
            .PSIZE = @intFromEnum(config.peripheral_data_size),
            .MSIZE = @intFromEnum(config.memory_data_size),
            .CIRC = @intFromBool(config.circular),
            .PL = @intFromEnum(config.priority),
            .DBM = @intFromBool(config.double_buffer),
            .PBURST = @intFromEnum(config.peripheral_burst),
            .MBURST = @intFromEnum(config.memory_burst),
            // Enable interrupts
            .TCIE = 1,  // Transfer complete interrupt
            .TEIE = 1,  // Transfer error interrupt
            .DMEIE = 1, // Direct mode error interrupt
        });
        
        // Configure FIFO
        if (config.fifo_mode) {
            fcr.modify(.{
                .DMDIS = 1,  // Disable direct mode (enable FIFO)
                .FTH = @intFromEnum(config.fifo_threshold),
                .FEIE = 1,   // FIFO error interrupt enable
            });
        } else {
            fcr.modify(.{
                .DMDIS = 0,  // Enable direct mode
                .FEIE = 0,
            });
        }
    }
    
    fn configure_dmamux(self: *Stream, request: dma_utils.DmaRequest) void {
        const dmamux = chip.peripherals.DMAMUX1;
        const channel = self.stream.to_dmamux_channel(self.controller);
        
        // DMAMUX has 16 channels (0-7 for DMA1, 8-15 for DMA2)
        const dmamux_cr = switch (channel) {
            0 => &dmamux.DMAMUX1_C0CR,
            1 => &dmamux.DMAMUX1_C1CR,
            2 => &dmamux.DMAMUX1_C2CR,
            3 => &dmamux.DMAMUX1_C3CR,
            4 => &dmamux.DMAMUX1_C4CR,
            5 => &dmamux.DMAMUX1_C5CR,
            6 => &dmamux.DMAMUX1_C6CR,
            7 => &dmamux.DMAMUX1_C7CR,
            8 => &dmamux.DMAMUX1_C8CR,
            9 => &dmamux.DMAMUX1_C9CR,
            10 => &dmamux.DMAMUX1_C10CR,
            11 => &dmamux.DMAMUX1_C11CR,
            12 => &dmamux.DMAMUX1_C12CR,
            13 => &dmamux.DMAMUX1_C13CR,
            14 => &dmamux.DMAMUX1_C14CR,
            15 => &dmamux.DMAMUX1_C15CR,
            else => unreachable,
        };
        
        // Configure DMAMUX channel
        dmamux_cr.modify(.{
            .DMAREQ_ID = @intFromEnum(request),
            .SOIE = 0,  // Disable synchronization overrun interrupt
            .EGE = 0,   // Disable event generation
            .SE = 0,    // Disable synchronization
        });
    }
    
    pub fn start(self: *Stream, callback: ?TransferCallback) !void {
        if (self.state == .Busy) {
            return error.StreamBusy;
        }
        
        self.callback = callback;
        self.state = .Busy;
        
        // Enable stream
        self.enable_stream();
    }
    
    pub fn stop(self: *Stream) void {
        self.disable_stream();
        self.state = .Idle;
        self.callback = null;
    }
    
    pub fn is_busy(self: *const Stream) bool {
        return self.state == .Busy;
    }
    
    fn enable_stream(self: *Stream) void {
        const regs = self.controller.get_registers();
        switch (self.stream) {
            .Stream0 => regs.S0CR.modify(.{ .EN = 1 }),
            .Stream1 => regs.S1CR.modify(.{ .EN = 1 }),
            .Stream2 => regs.S2CR.modify(.{ .EN = 1 }),
            .Stream3 => regs.S3CR.modify(.{ .EN = 1 }),
            .Stream4 => regs.S4CR.modify(.{ .EN = 1 }),
            .Stream5 => regs.S5CR.modify(.{ .EN = 1 }),
            .Stream6 => regs.S6CR.modify(.{ .EN = 1 }),
            .Stream7 => regs.S7CR.modify(.{ .EN = 1 }),
        }
    }
    
    fn disable_stream(self: *Stream) void {
        const regs = self.controller.get_registers();
        switch (self.stream) {
            .Stream0 => regs.S0CR.modify(.{ .EN = 0 }),
            .Stream1 => regs.S1CR.modify(.{ .EN = 0 }),
            .Stream2 => regs.S2CR.modify(.{ .EN = 0 }),
            .Stream3 => regs.S3CR.modify(.{ .EN = 0 }),
            .Stream4 => regs.S4CR.modify(.{ .EN = 0 }),
            .Stream5 => regs.S5CR.modify(.{ .EN = 0 }),
            .Stream6 => regs.S6CR.modify(.{ .EN = 0 }),
            .Stream7 => regs.S7CR.modify(.{ .EN = 0 }),
        }
    }
    
    fn is_enabled(self: *const Stream) bool {
        const regs = self.controller.get_registers();
        return switch (self.stream) {
            .Stream0 => regs.S0CR.read().EN == 1,
            .Stream1 => regs.S1CR.read().EN == 1,
            .Stream2 => regs.S2CR.read().EN == 1,
            .Stream3 => regs.S3CR.read().EN == 1,
            .Stream4 => regs.S4CR.read().EN == 1,
            .Stream5 => regs.S5CR.read().EN == 1,
            .Stream6 => regs.S6CR.read().EN == 1,
            .Stream7 => regs.S7CR.read().EN == 1,
        };
    }
    
    fn clear_flags(self: *Stream) void {
        const regs = self.controller.get_registers();
        const stream_num = @intFromEnum(self.stream);
        
        if (stream_num < 4) {
            // Streams 0-3 use LIFCR
            const shift: u5 = @intCast(stream_num * 6 + (if (stream_num > 1) 4 else 0));
            regs.LIFCR.write_raw(@as(u32, 0x3D) << shift);
        } else {
            // Streams 4-7 use HIFCR
            const shift: u5 = @intCast((stream_num - 4) * 6 + (if (stream_num > 5) 4 else 0));
            regs.HIFCR.write_raw(@as(u32, 0x3D) << shift);
        }
    }
    
    /// Get interrupt flags for this stream
    pub fn get_flags(self: *const Stream) InterruptFlags {
        const regs = self.controller.get_registers();
        const stream_num = @intFromEnum(self.stream);
        
        const flags = if (stream_num < 4) blk: {
            const shift: u5 = @intCast(stream_num * 6 + (if (stream_num > 1) 4 else 0));
            const lisr = regs.LISR.read();
            const raw = @as(u32, @bitCast(lisr)) >> shift;
            break :blk raw;
        } else blk: {
            const shift: u5 = @intCast((stream_num - 4) * 6 + (if (stream_num > 5) 4 else 0));
            const hisr = regs.HISR.read();
            const raw = @as(u32, @bitCast(hisr)) >> shift;
            break :blk raw;
        };
        
        return .{
            .transfer_complete = (flags & 0x20) != 0,
            .half_transfer = (flags & 0x10) != 0,
            .transfer_error = (flags & 0x08) != 0,
            .direct_mode_error = (flags & 0x04) != 0,
            .fifo_error = (flags & 0x01) != 0,
        };
    }
    
    /// Handle interrupt for this stream
    pub fn handle_interrupt(self: *Stream) void {
        const flags = self.get_flags();
        self.clear_flags();
        
        if (flags.transfer_complete) {
            // Check if we need to continue chunked transfer
            if (self.chunk_remaining > 0) {
                // Start next chunk
                self.continue_chunked_transfer();
            } else {
                // Transfer complete
                self.state = .Idle;
                if (self.callback) |cb| {
                    cb(.Complete);
                }
                self.callback = null;
            }
        } else if (flags.transfer_error) {
            self.state = .Error;
            if (self.callback) |cb| {
                cb(.Error);
            }
            self.callback = null;
        } else if (flags.fifo_error) {
            self.state = .Error;
            if (self.callback) |cb| {
                cb(.FifoError);
            }
            self.callback = null;
        } else if (flags.direct_mode_error) {
            self.state = .Error;
            if (self.callback) |cb| {
                cb(.DirectModeError);
            }
            self.callback = null;
        } else if (flags.half_transfer) {
            if (self.callback) |cb| {
                cb(.HalfComplete);
            }
        }
    }
    
    fn continue_chunked_transfer(self: *Stream) void {
        const regs = self.controller.get_registers();
        
        // Disable stream
        self.disable_stream();
        while (self.is_enabled()) {}
        
        // Calculate next chunk size
        const chunk_size = @min(self.chunk_remaining, 65535);
        
        // Update memory address and count
        cache.clean_dcache_by_addr(self.chunk_mem_addr, chunk_size);
        
        switch (self.stream) {
            .Stream0 => {
                regs.S0M0AR.write_raw(@as(u32, @intCast(self.chunk_mem_addr)));
                regs.S0NDTR.write_raw(@as(u32, @intCast(chunk_size)));
            },
            .Stream1 => {
                regs.S1M0AR.write_raw(@as(u32, @intCast(self.chunk_mem_addr)));
                regs.S1NDTR.write_raw(@as(u32, @intCast(chunk_size)));
            },
            .Stream2 => {
                regs.S2M0AR.write_raw(@as(u32, @intCast(self.chunk_mem_addr)));
                regs.S2NDTR.write_raw(@as(u32, @intCast(chunk_size)));
            },
            .Stream3 => {
                regs.S3M0AR.write_raw(@as(u32, @intCast(self.chunk_mem_addr)));
                regs.S3NDTR.write_raw(@as(u32, @intCast(chunk_size)));
            },
            .Stream4 => {
                regs.S4M0AR.write_raw(@as(u32, @intCast(self.chunk_mem_addr)));
                regs.S4NDTR.write_raw(@as(u32, @intCast(chunk_size)));
            },
            .Stream5 => {
                regs.S5M0AR.write_raw(@as(u32, @intCast(self.chunk_mem_addr)));
                regs.S5NDTR.write_raw(@as(u32, @intCast(chunk_size)));
            },
            .Stream6 => {
                regs.S6M0AR.write_raw(@as(u32, @intCast(self.chunk_mem_addr)));
                regs.S6NDTR.write_raw(@as(u32, @intCast(chunk_size)));
            },
            .Stream7 => {
                regs.S7M0AR.write_raw(@as(u32, @intCast(self.chunk_mem_addr)));
                regs.S7NDTR.write_raw(@as(u32, @intCast(chunk_size)));
            },
        }
        
        // Update chunk tracking
        self.chunk_remaining -= chunk_size;
        self.chunk_mem_addr += chunk_size;
        
        // Re-enable stream
        self.enable_stream();
    }
};

/// Interrupt flags
pub const InterruptFlags = struct {
    transfer_complete: bool,
    half_transfer: bool,
    transfer_error: bool,
    direct_mode_error: bool,
    fifo_error: bool,
};

/// Global stream registry for interrupt handlers
var stream_registry: [16]?*Stream = [_]?*Stream{null} ** 16;

/// Register a stream for interrupt handling
pub fn register_stream(stream: *Stream) void {
    const index: usize = @intCast(@intFromEnum(stream.stream) + 
        (if (stream.controller == .DMA2) 8 else 0));
    stream_registry[index] = stream;
}

/// Unregister a stream
pub fn unregister_stream(stream: *Stream) void {
    const index: usize = @intCast(@intFromEnum(stream.stream) + 
        (if (stream.controller == .DMA2) 8 else 0));
    stream_registry[index] = null;
}

/// Dispatch interrupt to registered stream
pub fn dispatch_interrupt(controller: Controller, stream: StreamNumber) void {
    const index: usize = @intCast(@intFromEnum(stream) + 
        (if (controller == .DMA2) 8 else 0));
    
    if (stream_registry[index]) |s| {
        s.handle_interrupt();
    }
}
