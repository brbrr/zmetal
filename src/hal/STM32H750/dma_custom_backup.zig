const std = @import("std");
const assert = std.debug.assert;

const microzig = @import("microzig");
const hal = microzig.hal;
const utils = @import("dma_utils.zig");
const regs = microzig.chip.peripherals;
const DMA1 = regs.DMA1;
const DMA2 = regs.DMA2;

pub const dmat = microzig.chip.types.peripherals.DMA;

// 7 x 2
const num_channels = 16;
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
    enable_interrupts: bool = true,
};

var chan_handlers: [num_channels]ChHandlers = [_]ChHandlers{ChHandlers{}} ** num_channels;

pub const DmaState = enum {
    ready,
    busy,
    abort,
    error_state,
};

pub const ChHandlers = struct {
    complete: ?*const fn (ch: Channel, ctx: *anyopaque) void = null,
    half_complete: ?*const fn (ch: Channel, ctx: *anyopaque) void = null,
    m1_complete: ?*const fn (ch: Channel, ctx: *anyopaque) void = null,
    m1_half_complete: ?*const fn (ch: Channel, ctx: *anyopaque) void = null,
    error_cb: ?*const fn (ch: Channel, ctx: *anyopaque, err: DmaError) void = null,
    abort: ?*const fn (ch: Channel, ctx: *anyopaque) void = null,
    state: DmaState = .ready,
    error_code: DmaError = .none,
    ctx: ?*anyopaque = null,
};

pub const DmaError = packed struct(u8) {
    te: bool = false, // transfer error
    fe: bool = false, // fifo error
    dme: bool = false, // direct mode error
    _pad: u5 = 0,

    pub const none = DmaError{};
    pub fn any(e: DmaError) bool {
        return e.te or e.fe or e.dme;
    }
};

pub inline fn write_one_to_clear(
    addr: anytype,
    comptime field_name: []const u8,
) void {
    const PackedT = @TypeOf(addr.*).underlying_type;

    // var v: PackedT = .{};
    var v: PackedT = @bitCast(@as(u32, 0));
    @field(v, field_name) = 1;

    addr.write(v);
}

pub fn dma_irq_handler(comptime chan: Channel) void {
    const info = comptime chan.info();
    const dma = if (info.per_id == 1) DMA2 else DMA1;
    const ch_regs = chan.get_regs();
    const handlers = chan.handlers();

    var ISR = if (info.is_high) &dma.HISR else &dma.LISR;
    const IFCR = if (comptime info.is_high) &dma.HIFCR else &dma.LIFCR;

    const status = ISR.read();

    const feif = @field(status, "FEIF" ++ info.suffix);
    const dmeif = @field(status, "DMEIF" ++ info.suffix);
    const teif = @field(status, "TEIF" ++ info.suffix);
    const htif = @field(status, "HTIF" ++ info.suffix);
    const tcif = @field(status, "TCIF" ++ info.suffix);

    // -------------------------------------------------------------------------
    // Transfer Error
    // -------------------------------------------------------------------------
    if (teif == 1) {
        // Check IT source enabled
        if (ch_regs.CR.read().TEIE == 1) {
            ch_regs.CR.modify_one("TEIE", 0); // disable TE interrupt
            write_one_to_clear(IFCR, "CTEIF" ++ info.suffix);
            handlers.error_code.te = true;
        }
    }

    // -------------------------------------------------------------------------
    // FIFO Error
    // -------------------------------------------------------------------------
    if (feif == 1) {
        if (ch_regs.FCR.read().FEIE == 1) {
            write_one_to_clear(IFCR, "CFEIF" ++ info.suffix);
            handlers.error_code.fe = true;
        }
    }

    // -------------------------------------------------------------------------
    // Direct Mode Error
    // -------------------------------------------------------------------------
    if (dmeif == 1) {
        if (ch_regs.CR.read().DMEIE == 1) {
            write_one_to_clear(IFCR, "CDMEIF" ++ info.suffix);
            handlers.error_code.dme = true;
        }
    }

    // -------------------------------------------------------------------------
    // Half Transfer
    // -------------------------------------------------------------------------
    if (htif == 1) {
        if (ch_regs.CR.read().HTIE == 1) {
            write_one_to_clear(IFCR, "CHTIF" ++ info.suffix);

            const cr = ch_regs.CR.read();

            if (cr.DBM == 1) {
                // Double buffer mode: callbacks are swapped relative to CT bit
                if (cr.CT == .Memory0) {
                    // Currently filling Memory0 → half of Memory1 done
                    if (handlers.half_complete) |cb|
                        cb(chan, handlers.ctx.?);
                } else {
                    // Currently filling Memory1 → half of Memory0 done
                    if (handlers.m1_half_complete) |cb|
                        cb(chan, handlers.ctx.?);
                }
            } else {
                // Non-circular: disable HT interrupt after firing
                if (cr.CIRC == 0) {
                    ch_regs.CR.modify_one("HTIE", 0);
                }
                if (handlers.half_complete) |cb|
                    cb(chan, handlers.ctx.?);
            }
        }
    }

    // -------------------------------------------------------------------------
    // Transfer Complete
    // -------------------------------------------------------------------------
    if (tcif == 1) {
        if (ch_regs.CR.read().TCIE == 1) {
            write_one_to_clear(IFCR, "CTCIF" ++ info.suffix);

            // Abort flow
            if (handlers.state == .abort) {
                // Disable all interrupts
                ch_regs.CR.modify(.{
                    .TCIE = 0,
                    .TEIE = 0,
                    .DMEIE = 0,
                    .HTIE = 0,
                });
                ch_regs.FCR.modify_one("FEIE", 0);

                // Clear all flags
                chan.clear_flags();

                handlers.state = .ready;

                if (handlers.abort) |cb|
                    cb(chan, handlers.ctx.?);
                @breakpoint();
                @panic("ZZZ");
                // return;
            }

            const cr = ch_regs.CR.read();

            if (cr.DBM == 1) {
                // Double buffer: CT has already flipped by hardware at TC
                if (cr.CT == .Memory0) {
                    // Memory1 just finished (CT flipped to 0 meaning now filling Mem0)
                    if (handlers.m1_complete) |cb|
                        cb(chan, handlers.ctx.?);
                } else {
                    // Memory0 just finished
                    if (handlers.complete) |cb|
                        cb(chan, handlers.ctx.?);
                }
            } else {
                if (cr.CIRC == 0) {
                    // One-shot: disable TC, mark ready
                    ch_regs.CR.modify_one("TCIE", 0);
                    handlers.state = .ready;
                }
                if (handlers.complete) |cb|
                    cb(chan, handlers.ctx.?);
            }
        }
    }

    // -------------------------------------------------------------------------
    // Error dispatch (after TC/HT so callbacks fire in the right order)
    // -------------------------------------------------------------------------
    if (handlers.error_code.any()) {
        if (handlers.error_code.te) {
            handlers.state = .abort;

            // Disable the stream
            ch_regs.CR.modify_one("EN", 0);

            // Spin until EN clears (with crude timeout)
            var timeout: u32 = hal.clock.SystemCoreClock / 9600;
            while (ch_regs.CR.read().EN != 0) {
                if (timeout == 0) break;
                timeout -= 1;
            }

            handlers.state = if (ch_regs.CR.read().EN == 0)
                .ready
            else
                .error_state;
        }

        if (handlers.error_cb) |cb|
            cb(chan, handlers.ctx.?, handlers.error_code);

        handlers.error_code = DmaError.none;

        @breakpoint();
        @panic("ZZZ");
    }
}

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

pub const ChannelInfo = struct {
    global_index: u4,
    /// 0 = DMA1, 1 = DMA2
    per_id: u1,
    /// 0–6
    stream_id: u3,
    /// HISR/HIFCR
    is_high: bool,
    /// 0–3 inside ISR half
    hisr_id: u2,
    reg: *volatile dmat.DMA1,
    suffix: []const u8,
};

pub const Channel = enum(u4) {
    _,

    const Regs = dmat.ST;

    pub fn handlers(chan: Channel) *ChHandlers {
        return &chan_handlers[@intFromEnum(chan)];
    }

    pub fn dma_reg(chan: Channel) *volatile dmat.DMA1 {
        const stream_num: u4 = @intFromEnum(chan);
        const is_dma2 = stream_num > 6;

        const dma = if (is_dma2) DMA2 else DMA1;
        return dma;
    }

    pub inline fn get_regs(chan: Channel) *volatile Regs {
        const dma1_regs = @as(*volatile [num_channels / 2]Regs, @ptrCast(&DMA1.S0CR));
        const dma2_regs = @as(*volatile [num_channels / 2]Regs, @ptrCast(&DMA2.S0CR));

        var ch_id: u8 = @intFromEnum(chan);
        // [0, 7] :: [8, 13]
        if (ch_id <= 7) {
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

    pub fn clear_flags(comptime chan: Channel) void {
        const dma_r = chan.dma_reg();
        const inf = comptime chan.info();
        const stream_num: u5 = inf.stream_id;
        if (stream_num < 4) {
            // Streams 0-3 use LIFCR
            const shift: u5 = @intCast(stream_num * 6 + (if (stream_num > 1) 4 else 0));
            dma_r.LIFCR.write_raw(@as(u32, 0x3D) << shift);
        } else {
            // Streams 4-7 use HIFCR
            const shift: u5 = @intCast((stream_num - 4) * 6 + (if (stream_num > 5) 4 else 0));
            dma_r.HIFCR.write_raw(@as(u32, 0x3D) << shift);
        }
    }

    pub fn setup_transfer_raw(
        comptime chan: Channel,
        write_addr: u32,
        read_addr: u32,
        count: u32,
        config: TransferConfig,
    ) void {
        const ch_regs = chan.get_regs();

        ch_regs.CR.raw = 0;

        // Wait until disabled.
        // NOTE: add timeout
        while (ch_regs.CR.read().EN != 0) microzig.cpu.nop();

        chan.clear_flags();

        // Number of transfers (in words)
        ch_regs.NDTR.modify_one("NDT", @intCast(count));

        switch (config.dir) {
            .mem_to_perih => {
                ch_regs.PAR = write_addr;
                ch_regs.M0AR = read_addr;
                ch_regs.CR.modify(.{
                    .PINC = config.dest.inc,
                    .PSIZE = config.dest.alignment,
                    .MINC = config.src.inc,
                    .MSIZE = config.src.alignment,
                });
            },
            .perih_to_mem, .mem_to_mem => {
                ch_regs.PAR = read_addr;
                ch_regs.M0AR = write_addr;
                ch_regs.CR.modify(.{
                    .PINC = config.src.inc,
                    .PSIZE = config.src.alignment,
                    .MINC = config.dest.inc,
                    .MSIZE = config.dest.alignment,
                });
            },
        }

        ch_regs.CR.modify(.{
            // .PINC = 0, // config.src.inc,
            // .MINC = 1, //config.dest.inc,
            // .PSIZE = .Bits32,
            // .MSIZE = .Bits32,

            // .PSIZE = config.dest.alignment,
            // .MSIZE = config.src.alignment,
            //
            .DIR = @as(dmat.DIR, @enumFromInt(@intFromEnum(config.dir))),
            .CIRC = @as(u1, if (config.mode == .circular) 1 else 0),
            .PFCTRL = @as(dmat.PFCTRL, if (config.mode == .pfctrl) .Peripheral else .DMA),
            // Error interrupts always enabled
            .DMEIE = 1,
            .TEIE = 1,
            // HT/TC interrupts only when callbacks are needed
            .HTIE = @as(u1, if (config.enable_interrupts) 1 else 0),
            .TCIE = @as(u1, if (config.enable_interrupts) 1 else 0),
            .PL = config.priority,
        });

        if (config.fifo_mode == 0) {
            ch_regs.FCR.raw = 0;
        } else {
            @panic("FIFO enabled is not supported for now!");
        }

        chan.configure_dmamux(config.req);
        // regs.DMAMUX1.DMAMUX1_CSR.raw = 0;
        // regs.DMAMUX1.DMAMUX1_RGSR.raw = 0;
    }

    pub const SetupTransferConfig = struct {
        enable: bool,
        mode: Mode,
        priority: dmat.PL,
        fifo_mode: u8,
        size: ?u32,
        enable_interrupts: bool = true,
    };

    pub fn setup_transfer(
        comptime chan: Channel,
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
                .enable_interrupts = config.enable_interrupts,
            },
        );
    }

    pub fn info(comptime chan: Channel) ChannelInfo {
        const index = @intFromEnum(chan);

        // 7 streams X 2 peripherals
        const dma_index: u1 = if (index > 7) 1 else 0;
        const local: u3 = if (index > 7) index - 8 else index;

        // low [0, 3] and high [4, 6]
        const is_high = local >= 4;
        const hisr_id: u2 = if (is_high) local - 4 else local;

        const reg = if (dma_index == 0) DMA1 else DMA2;

        return .{
            .global_index = index,
            .per_id = dma_index,
            .stream_id = local,
            .is_high = is_high,
            .hisr_id = hisr_id,
            .reg = reg,
            .suffix = std.fmt.comptimePrint("{}", .{local}),
        };
    }

    fn configure_dmamux(comptime chan: Channel, request: utils.DmaRequest) void {
        const dmamux = regs.DMAMUX1;
        const inf = comptime chan.info();
        // const channel = self.stream.to_dmamux_channel(self.controller);

        // DMAMUX has 16 channels (0-7 for DMA1, 8-15 for DMA2)
        const dmamux_cr = comptime switch (inf.global_index) {
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
        };

        // Configure DMAMUX channel
        dmamux_cr.modify(.{
            .DMAREQ_ID = @intFromEnum(request),
            .SOIE = 0, // Disable synchronization overrun interrupt
            .EGE = 0, // Disable event generation
            .SE = 0, // Disable synchronization
        });
    }
};

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

/// Get interrupt enum for this channel (for enabling NVIC)
pub fn get_interrupt(chan: Channel) microzig.interrupt.Interrupt {
    return switch (@intFromEnum(chan)) {
        0 => microzig.interrupt.DMA1_STR0,
        1 => microzig.interrupt.DMA1_STR1,
        2 => microzig.interrupt.DMA1_STR2,
        3 => microzig.interrupt.DMA1_STR3,
        4 => microzig.interrupt.DMA1_STR4,
        5 => microzig.interrupt.DMA1_STR5,
        6 => microzig.interrupt.DMA1_STR6,
        7 => microzig.interrupt.DMA2_STR0,
        8 => microzig.interrupt.DMA2_STR1,
        9 => microzig.interrupt.DMA2_STR2,
        10 => microzig.interrupt.DMA2_STR3,
        11 => microzig.interrupt.DMA2_STR4,
        12 => microzig.interrupt.DMA2_STR5,
        13 => microzig.interrupt.DMA2_STR6,
        else => unreachable,
    };
}
