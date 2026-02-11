const std = @import("std");
const assert = std.debug.assert;

const microzig = @import("microzig");
const utils = @import("dma_utils.zig");
const regs = microzig.chip.peripherals;
const DMA1 = regs.DMA1;
const DMA2 = regs.DMA2;

pub const dmat = microzig.chip.types.peripherals.DMA;

// TODO:
// Implement some version of HAL_DMA_IRQHandler
// DMA users should register irc callbacks, and call above fnc with used channel
// HAL irc impl:
// dma struct holds func pointers to complete and half complete callbacks
// callbacks are set in perih side (transmit_dma)
// irq handler detects the dma state and calls relevant CB

// 7 x 2
const num_channels = 14;
var claimed_channels = microzig.concurrency.AtomicStaticBitSet(num_channels){};
const MaskType = std.meta.Int(.unsigned, num_channels);

pub const Direction = enum(u2) {
    perih_to_mem = 0,
    mem_to_perih,
    mem_to_mem,
};

pub const Target = struct {
    inc: u1, // DMA_PINC_DISABLE
    alignment: DataSize,
};

pub const DataSize = dmat.SIZE;

pub const Mode = enum {
    normal,
    circular,
    pfctrl,
};

pub const TransferConfig = struct {
    enable: bool,
    req: utils.DmaRequest,
    dir: Direction,
    src: Target,
    dest: Target,
    mode: Mode,
    priority: dmat.PL,
    fifo_mode: u8,
};

var chan_handlers: [num_channels]ChHandlers = [_]ChHandlers{ChHandlers{}} ** num_channels;

const FEIF_OFFSET = 0;
const DMEIF_OFFSET = 2;
const TEIF_OFFSET = 3;
const HTIF_OFFSET = 4;
const TCIF_OFFSET = 5;
const STREAM_BITS = 6; // number of bits per stream block in LISR/LIFCR

fn stream_mask(stream: u8, offset: u32) u32 {
    const shift: u32 = @as(u32, @intCast(stream)) * STREAM_BITS + offset;
    return @as(u32, 1) << @as(u5, @intCast(shift));
}
pub fn dma_irq_handler(chan: Channel) void {
    const stream: u4 = @intFromEnum(chan);

    // choose the right register (LISR/LIFCR or HISR/HIFCR)
    const is_high = stream >= 4;
    const status: u32 = if (is_high) DMA1.HISR.raw else DMA1.LISR.raw;
    const clear_reg: *volatile u32 = if (is_high) &DMA1.HIFCR.raw else &DMA1.LIFCR.raw;
    const local_stream = if (is_high) stream - 4 else stream;

    const tcif = (status & stream_mask(local_stream, TCIF_OFFSET)) != 0;
    const htif = (status & stream_mask(local_stream, HTIF_OFFSET)) != 0;
    const teif = (status & stream_mask(local_stream, TEIF_OFFSET)) != 0;
    const feif = (status & stream_mask(local_stream, FEIF_OFFSET)) != 0;

    // Handle errors first
    if (teif or feif) {
        // Clear error flags
        clear_reg.* = stream_mask(local_stream, TEIF_OFFSET) | stream_mask(local_stream, FEIF_OFFSET);
        std.log.err("DMA error on channel {} (TEIF={}, FEIF={})", .{ chan, teif, feif });
        @breakpoint();
        @panic("!!!!");
    }

    const handlers = chan.handlers();

    // Half Transfer Complete - clear flag and call callback (matches STM32 HAL)
    if (htif) {
        clear_reg.* = stream_mask(local_stream, HTIF_OFFSET);
        if (handlers.half_complete != null)
            handlers.half_complete.?(chan, handlers.ctx.?);
    }

    // Transfer Complete - clear flag and call callback (matches STM32 HAL)
    if (tcif) {
        clear_reg.* = stream_mask(local_stream, TCIF_OFFSET);
        if (handlers.complete != null)
            handlers.complete.?(chan, handlers.ctx.?);
    }
}

pub const ChHandlers = struct {
    complete: ?*const fn (ch: Channel, ctx: *anyopaque) void = null,
    half_complete: ?*const fn (ch: Channel, ctx: *anyopaque) void = null,
    ctx: ?*anyopaque = null,
};

pub fn channel(n: u4) Channel {
    assert(n < num_channels);

    return @enumFromInt(n);
}

pub fn claim_unused_channel() ?Channel {
    const ch = claimed_channels.set_first_available() catch {
        return null;
    };
    return channel(@intCast(ch));
}

pub const DMA_ReadTarget = struct {
    dreq: utils.DmaRequest,
    addr: u32,
};

pub const DMA_WriteTarget = struct {
    dreq: utils.DmaRequest,
    addr: u32,
};

pub const ChannelError = error{AlreadyClaimed};

fn stream_id(ch: Channel) comptime_int {
    var ch_id: u8 = @intFromEnum(ch);
    // [0, 6] :: [7, 13]
    if (ch_id > 6) {
        ch_id -= num_channels / 2;
    }
    return ch_id;
}

fn per_id(ch: Channel) comptime_int {
    if (@intFromEnum(ch) > 6) {
        return 2;
    }
    return 1;
}

pub const Channel = enum(u4) {
    _,

    const Regs = dmat.ST;
    const s_id = stream_id(@This());
    const p_id = per_id(@This());

    pub fn handlers(chan: Channel) *ChHandlers {
        return &chan_handlers[@intFromEnum(chan)];
    }

    pub inline fn get_regs(chan: Channel) *volatile Regs {
        const dma1_regs = @as(*volatile [num_channels / 2]Regs, @ptrCast(&DMA1.S0CR));
        const dma2_regs = @as(*volatile [num_channels / 2]Regs, @ptrCast(&DMA2.S0CR));

        var ch_id: u8 = @intFromEnum(chan);
        // [0, 6] :: [7, 13]
        if (ch_id < 7) {
            return &dma1_regs[ch_id];
        } else {
            ch_id -= num_channels / 2;
            return &dma2_regs[ch_id];
        }
    }

    pub fn claim(chan: Channel) ChannelError!void {
        if (!claimed_channels.set(@intFromEnum(chan)))
            return ChannelError.AlreadyClaimed;
    }

    pub fn unclaim(chan: Channel) void {
        const result = claimed_channels.reset(@intFromEnum(chan));
        std.debug.assert(result);
    }

    pub fn is_claimed(chan: Channel) bool {
        return claimed_channels.test_bit(@intFromEnum(chan)) == 1;
    }

    pub fn mask(chan: Channel) MaskType {
        return @as(MaskType, 1) << @intFromEnum(chan);
    }

    pub fn setup_transfer_raw(
        chan: Channel,
        write_addr: u32,
        read_addr: u32,
        count: u32,
        config: TransferConfig,
    ) void {
        const ch_regs = chan.get_regs();

        ch_regs.CR.raw = 0;

        // Wait until disabled. NOTE: add timeout
        while (ch_regs.CR.read().EN != 0) microzig.cpu.nop();

        switch (config.dir) {
            .perih_to_mem, .mem_to_mem => {
                ch_regs.PAR = read_addr;
                ch_regs.M0AR = write_addr;
                // ch_regs.CR.modify(.{
                //     .PINC = 0, // config.src.inc,
                //     .PSIZE = config.src.alignment,
                //     .MINC = 1, //config.dest.inc,
                //     .MSIZE = config.dest.alignment,
                // });
            },
            .mem_to_perih => {
                ch_regs.M0AR = read_addr;
                ch_regs.PAR = write_addr;
                // ch_regs.CR.modify(.{
                //     // .PINC = config.dest.inc,
                //     .PSIZE = config.dest.alignment,
                //     // .MINC = config.src.inc,
                //     .MSIZE = config.src.alignment,
                // });
            },
        }

        ch_regs.CR.modify(.{
            .PINC = 0, // config.src.inc,
            .MINC = 1, //config.dest.inc,
            .PSIZE = .Bits32,
            .MSIZE = .Bits32,
            //
            .DIR = @as(dmat.DIR, @enumFromInt(@intFromEnum(config.dir))),
            .CIRC = @as(u1, if (config.mode == .circular) 1 else 0),
            .PFCTRL = @as(dmat.PFCTRL, if (config.mode == .pfctrl) .Peripheral else .DMA),
            // Direct mode error interrupt enable
            .DMEIE = 1,
            // Transfer error interrupt enable
            .TEIE = 1,
            // Half transfer interrupt enable
            .HTIE = 1,
            // Transfer complete interrupt enable
            .TCIE = 1,
            .PL = config.priority,
        });

        if (config.fifo_mode == 0) {
            ch_regs.FCR.raw = 0;
        } else {
            @panic("FIFO enabled is not supported for now!");
        }

        switch (@intFromEnum(chan)) {
            // hdma->DMAmuxChannel->CCR = (hdma->Init.Request & DMAMUX_CxCR_DMAREQ_ID);
            0 => {
                regs.DMAMUX1.DMAMUX1_C0CR.modify(.{ .DMAREQ_ID = @intFromEnum(config.req) });
                regs.DMAMUX1.DMAMUX1_RG0CR.raw = 0;
            },
            1 => {
                regs.DMAMUX1.DMAMUX1_C1CR.modify(.{ .DMAREQ_ID = @intFromEnum(config.req) });
                regs.DMAMUX1.DMAMUX1_RG1CR.raw = 0;
            },
            else => @panic("!!!!"),
        }

        regs.DMAMUX1.DMAMUX1_CSR.raw = 0;
        regs.DMAMUX1.DMAMUX1_RGSR.raw = 0;

        // Number of transfers (in words)
        ch_regs.NDTR.raw = count;
        ch_regs.CR.modify_one("EN", 1);
    }

    pub const SetupTransferConfig = struct {
        enable: bool,
        mode: Mode,
        priority: dmat.PL,
        fifo_mode: u8,
        size: ?u32,
    };

    pub fn setup_transfer(
        chan: Channel,
        write: anytype,
        read: anytype,
        config: SetupTransferConfig,
    ) !void {
        const H = struct {
            fn is_peripheral(Type: type) bool {
                return Type == DMA_ReadTarget or Type == DMA_WriteTarget;
            }

            fn validate_type(Type: type) void {
                const Info = @typeInfo(Type);
                switch (Info) {
                    .@"struct" => {
                        if (!is_peripheral(Type))
                            @compileError("only peripherals and pointers are supported");
                    },
                    .pointer => {
                        if (get_data_size(Type) == null)
                            @compileError("only pointers/slices/arrays of u8/u16/u32 are supported");
                    },
                    else => @compileError(std.fmt.comptimePrint("unsupported type {}", .{Type})),
                }
            }

            inline fn get_addr(value: anytype) u32 {
                const Type = @TypeOf(value);
                const Info = @typeInfo(Type);
                switch (Info) {
                    .@"struct" => {
                        return value.addr;
                    },
                    .pointer => {
                        if (Info.pointer.size == .slice) {
                            return @intFromPtr(&value[0]);
                        }

                        return @intFromPtr(value);
                    },
                    else => comptime unreachable,
                }
            }

            inline fn get_dreq(value: anytype) utils.DmaRequest {
                const Type = @TypeOf(value);
                const Info = @typeInfo(Type);
                switch (Info) {
                    .@"struct" => {
                        return value.dreq;
                    },
                    .pointer => {
                        return .MEM2MEM;
                    },
                    else => comptime unreachable,
                }
            }

            inline fn get_count(value: anytype) u32 {
                const Type = @TypeOf(value);
                const Info = @typeInfo(Type);
                switch (Info) {
                    .pointer => |ptr| {
                        switch (ptr.size) {
                            .one => switch (@typeInfo(ptr.child)) {
                                .array => |array| {
                                    return array.len;
                                },
                                else => return 1,
                            },
                            .many, .slice => return value.len,
                            .c => unreachable,
                        }
                    },
                    else => unreachable,
                }
            }

            inline fn get_increment(Type: type) bool {
                const Info = @typeInfo(Type);
                return switch (Info) {
                    .pointer => |ptr| switch (ptr.size) {
                        .one => switch (@typeInfo(ptr.child)) {
                            .array => true,
                            else => false,
                        },
                        .many, .slice => true,
                        .c => unreachable,
                    },
                    else => comptime if (is_peripheral(Type)) false else unreachable,
                };
            }

            fn type_to_data_size(Type: type) ?DataSize {
                return switch (Type) {
                    u8, i8 => .Bits8,
                    u16, i16 => .Bits16,
                    u32, i32 => .Bits32,
                    else => null,
                };
            }

            fn get_data_size(Type: type) ?DataSize {
                // at this point we are guarnteed that we have pointer type
                const Info = @typeInfo(Type);
                const ChildType = Info.pointer.child;
                return switch (@typeInfo(ChildType)) {
                    .array => |array| type_to_data_size(array.child),
                    .int => type_to_data_size(ChildType),
                    else => null,
                };
            }
        };

        const WriteType = @TypeOf(write);
        const ReadType = @TypeOf(read);

        comptime H.validate_type(WriteType);
        comptime H.validate_type(ReadType);

        const write_addr = H.get_addr(write);
        const read_addr = H.get_addr(read);

        comptime if (H.is_peripheral(ReadType) and H.is_peripheral(WriteType))
            @compileError("cross peripheral dma is unsupported");

        const data_size = comptime if (H.is_peripheral(WriteType))
            H.get_data_size(ReadType).?
        else
            H.get_data_size(WriteType).?;

        const direction = comptime if (H.is_peripheral(ReadType))
            .perih_to_mem
        else if (H.is_peripheral(WriteType)) .mem_to_perih else .mem_to_mem;

        const dreq = if (comptime H.is_peripheral(WriteType)) H.get_dreq(write) else H.get_dreq(read);

        const count = blk: {
            if (config.size) |size| {
                break :blk size;
            } else if (comptime H.is_peripheral(WriteType))
                break :blk H.get_count(read)
            else if (comptime H.is_peripheral(ReadType))
                break :blk H.get_count(write)
            else {
                const write_count = H.get_count(write);
                const read_count = H.get_count(read);

                // OPTIMIZATION: do this check at comptime, so we can avoid the read_count call
                if (read_count == 1) // handle memset
                    break :blk write_count
                else if (read_count == write_count)
                    break :blk read_count
                else
                    return error.LengthMismatch;
            }
        };

        std.log.warn("channel: {}, write_addr: {} read_addr: {} dreq: {s} count: {} data_size: {}", .{
            chan,
            write_addr,
            read_addr,
            @tagName(dreq),
            count,
            data_size,
        });

        chan.setup_transfer_raw(
            write_addr,
            read_addr,
            count,
            .{
                .enable = config.enable,
                .src = .{
                    .inc = if (comptime H.get_increment(ReadType)) 1 else 0,
                    .alignment = data_size,
                },
                .dest = .{
                    .inc = if (comptime H.get_increment(WriteType)) 1 else 0,
                    .alignment = data_size,
                },
                .req = dreq,
                .dir = direction,
                .mode = config.mode,
                .priority = config.priority,
                .fifo_mode = config.fifo_mode,
            },
        );
    }

    pub fn set_irq0_enabled(chan: Channel, enabled: bool) void {
        const int = chan.int;

        // if (enabled) {
        //     const inte0_set = hw.set_alias_raw(&DMA.INTE0);
        //     inte0_set.* = @as(u32, 1) << @intFromEnum(chan);
        // } else {
        //     const inte0_clear = hw.clear_alias_raw(&DMA.INTE0);
        //     inte0_clear.* = @as(u32, 1) << @intFromEnum(chan);
        // }
        if (enabled) {
            microzig.cpu.interrupt.enable(int);
        } else {
            microzig.cpu.interrupt.disable(int);
        }
    }

    pub fn acknowledge_irq0(chan: Channel) void {
        _ = chan;
        // const ints0_set = hw.set_alias_raw(&DMA.INTS0);
        // ints0_set.* = @as(u32, 1) << @intFromEnum(chan);
    }

    pub fn is_busy(chan: Channel) bool {
        _ = chan;
        @panic("Not implemented");
        // const regs = chan.get_regs();
        // return regs.ctrl_trig.read().BUSY == 1;
    }

    pub fn wait_for_finish_blocking(chan: Channel) void {
        while (chan.is_busy()) {
            microzig.cpu.nop();
        }
    }
};

// Now SAI will fetch samples via DMA automatically

// .{ .name = "DMA_STR0", .index = 11, .description = "DMA1 Stream0" },
// .{ .name = "DMA_STR1", .index = 12, .description = "DMA1 Stream1" },
// .{ .name = "DMA_STR2", .index = 13, .description = "DMA1 Stream2" },
// .{ .name = "DMA_STR3", .index = 14, .description = "DMA1 Stream3" },
// .{ .name = "DMA_STR4", .index = 15, .description = "DMA1 Stream4" },
// .{ .name = "DMA_STR5", .index = 16, .description = "DMA1 Stream5" },
// .{ .name = "DMA_STR6", .index = 17, .description = "DMA1 Stream6" },
// .{ .name = "DMA1_STR7", .index = 47, .description = "DMA1 Stream7" },

// .{ .name = "DMA2_STR0", .index = 56, .description = "DMA2 Stream0 interrupt" },
// .{ .name = "DMA2_STR1", .index = 57, .description = "DMA2 Stream1 interrupt" },
// .{ .name = "DMA2_STR2", .index = 58, .description = "DMA2 Stream2 interrupt" },
// .{ .name = "DMA2_STR3", .index = 59, .description = "DMA2 Stream3 interrupt" },
// .{ .name = "DMA2_STR4", .index = 60, .description = "DMA2 Stream4 interrupt" },
// .{ .name = "DMA2_STR5", .index = 68, .description = "DMA2 Stream5 interrupt" },
// .{ .name = "DMA2_STR6", .index = 69, .description = "DMA2 Stream6 interrupt" },
// .{ .name = "DMA2_STR7", .index = 70, .description = "DMA2 Stream7 interrupt" },
