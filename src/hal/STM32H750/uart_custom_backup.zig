//! UART (Universal Asynchronous Receiver/Transmitter) driver for STM32H750
//!
//! Supports USART1-3, USART6, UART4-5 peripherals on STM32H7.
//! Note: GPIO pins must be configured separately before using UART.

const std = @import("std");
const microzig = @import("microzig");
const mdf = microzig.drivers;
const peripherals = microzig.chip.peripherals;
const UART0_reg = peripherals.UART0;
const UART1_reg = peripherals.UART1;

const hal = @import("hal.zig");
const gpio = hal.gpio;
const time = @import("time.zig");
const daisy = @import("daisy.zig");

const UartReg = microzig.chip.types.peripherals.USART1;

const Uarts = [_]*volatile UartReg{
    peripherals.USART1,
    peripherals.USART2,
    peripherals.USART3,
    peripherals.USART6,
    peripherals.UART4,
    peripherals.UART5,
};

pub const StopBits = enum {
    one,
    two,
};

pub const Parity = enum {
    none,
    even,
    odd,
};

pub const FlowControl = enum {
    none,
    CTS,
    RTS,
    CTS_RTS,
};

pub const ConfigError = error{
    UnsupportedBaudRate,
};

pub const Config = struct {
    baud_rate: u32 = 115200,
    word_bits: u8 = 8,
    stop_bits: StopBits = .one,
    parity: Parity = .none,
    flow_control: FlowControl = .none,
};

pub const TransmitError = error{
    Timeout,
};

pub const ReceiveError = error{
    OverrunError,
    BreakError,
    ParityError,
    FramingError,
};

pub const ReceiveBlockingError = ReceiveError || error{Timeout};

pub const ErrorStates = packed struct(u4) {
    overrun_error: bool = false,
    break_error: bool = false,
    parity_error: bool = false,
    framing_error: bool = false,
};

fn comptime_fail_or_error(msg: []const u8, fmt_args: anytype, err: ConfigError) ConfigError {
    if (@inComptime()) {
        @compileError(std.fmt.comptimePrint(msg, fmt_args));
    } else {
        return err;
    }
}

/// Checks against datasheet settings for invalid baud rates.
///
/// Returns an error at runtime, and raises a compile error at comptime.
fn validate_baudrate(baud_rate: u32, peri_freq: u32) ConfigError!void {
    if (peri_freq < 16 * baud_rate) {
        return comptime_fail_or_error(
            "Peripheral clock: {d} too low for baudrate: {d}",
            .{ peri_freq, baud_rate },
            ConfigError.UnsupportedBaudRate,
        );
    } else if ((peri_freq / 65535) > 16 * baud_rate) {
        return comptime_fail_or_error(
            "Peripheral clock: {d} too high for baudrate: {d}",
            .{ peri_freq, baud_rate },
            ConfigError.UnsupportedBaudRate,
        );
    }
}

pub const instance = struct {
    pub const UART1: UART = @enumFromInt(1);
    pub const UART2: UART = @enumFromInt(2);
    pub fn num(n: u1) UART {
        return @enumFromInt(n);
    }
};

/// An API for interacting with the RP2040's UART driver.
///
/// Note: Assumes proper GPIO configuration, does NOT configure GPIO pins.
///
/// Features of the peripheral that are explicitly NOT supported by this API are:
/// - CTS/RTS Hardware flow control
/// - Interrupt Driven/Asynchronous writes/reads
/// - DMA based writes/reads
pub const UART = enum(u8) {
    _,

    // NOTE: Hardcoded UART_PRESCALER_DIV2 from dsy config
    const clock_prescaler = 1;
    /// std.Io.Writer adapter over blocking UART transmit.
    /// Zig 0.16 replaced std.io.GenericWriter with the vtable-based std.Io.Writer.
    pub const Writer = struct {
        uart: UART,
        interface: std.Io.Writer,

        pub fn init(uart: UART, buffer: []u8) Writer {
            return .{
                .uart = uart,
                .interface = .{ .buffer = buffer, .vtable = &.{ .drain = drain } },
            };
        }

        fn drain(io_w: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
            const self: *Writer = @fieldParentPtr("interface", io_w);
            // Consume the internal buffer first, then each data slice in order.
            const buffered = io_w.buffer[0..io_w.end];
            if (buffered.len != 0) {
                self.uart.write_blocking(buffered, null) catch return error.WriteFailed;
                io_w.end = 0;
            }
            var written: usize = 0;
            for (data[0 .. data.len - 1]) |bytes| {
                if (bytes.len != 0)
                    self.uart.write_blocking(bytes, null) catch return error.WriteFailed;
                written += bytes.len;
            }
            // The last slice is repeated `splat` times.
            const last = data[data.len - 1];
            var n: usize = 0;
            while (n < splat) : (n += 1) {
                if (last.len != 0)
                    self.uart.write_blocking(last, null) catch return error.WriteFailed;
                written += last.len;
            }
            return written;
        }
    };

    pub fn writer(uart: UART, buffer: []u8) Writer {
        return Writer.init(uart, buffer);
    }

    pub inline fn get_reg(uart: UART) *volatile UartReg {
        const id: u8 = @intFromEnum(uart);
        if (id >= Uarts.len) {
            @panic("Invalid UART id");
        }

        return Uarts[id];
    }

    pub fn get_peri_freq(comptime uart: UART) comptime_int {
        return switch (@intFromEnum(uart)) {
            0, 5 => daisy.clock_outputs.USART16,
            else => daisy.clock_outputs.USART234578,
        };
    }

    fn apply_internal(comptime uart: UART, config: Config) void {
        const uart_reg = uart.get_reg();

        // 1. Enable peripheral clock
        switch (@intFromEnum(uart)) {
            0 => peripherals.RCC.APB2ENR.modify_one("USART1EN", 1),
            1 => peripherals.RCC.APB1LENR.modify_one("USART2EN", 1),
            2 => peripherals.RCC.APB1LENR.modify_one("USART3EN", 1),
            else => @panic("Unsupported UART instance"),
        }

        // 2. Disable USART before config
        uart_reg.CR1.modify(.{ .UE = 0 });

        // const peri_freq = config.clock_config.peri.?.frequency();
        uart.set_baudrate(config.baud_rate, uart.get_peri_freq());
        uart.set_format(config.word_bits, config.stop_bits, config.parity);
        uart.set_flow_control(config.flow_control);

        uart_reg.PRESC.modify_one("PRESCALER", clock_prescaler);

        // 5. Enable transmitter and receiver
        uart_reg.CR1.modify(.{ .TE = 1, .RE = 1 });

        // 6. Enable USART
        uart_reg.CR1.modify(.{ .UE = 1 });
    }

    /// Apply a configuration to the UART peripheral, takes in a comptime known config to enable
    /// validation of parameters at compile time. See apply_runtime() if configuration using
    /// parameters known ONLY at runtime is needed.
    pub fn apply(comptime uart: UART, comptime config: Config) void {
        comptime validate_baudrate(config.baud_rate, uart.get_peri_freq()) catch unreachable;
        uart.apply_internal(config);
    }

    /// Same as apply(), but due to parameters being runtime known, returns an error on invalid
    /// configurations.
    pub fn apply_runtime(uart: UART, config: Config) ConfigError!void {
        const peri_freq = uart.get_peri_freq();
        try validate_baudrate(config.baud_rate, peri_freq);
        uart.apply_internal(config);
    }

    /// Disable Uart transmission, pre-fill the TX FIFO as much as possible, and then re-enable to start transmission.
    fn prime_tx_fifo(uart: UART, src: []const u8) usize {
        const regs = uart.get_reg();

        // Disable transmitter (TE bit in CR1)
        regs.CR1.modify(.{ .TE = 0 });

        var tx_remaining = src.len;
        while (tx_remaining > 0 and (regs.ISR.read().TXE != 0)) {
            regs.TDR.write_raw(src[src.len - tx_remaining]);
            tx_remaining -= 1;
        }

        // Enable transmitter
        regs.CR1.modify(.{ .TE = 1 });

        return src.len - tx_remaining;
    }

    pub inline fn is_readable(uart: UART) bool {
        // RXNE: Receive data register not empty (bit 5 in ISR)
        return uart.get_reg().ISR.read().RXNE != 0;
    }

    pub inline fn is_writeable(uart: UART) bool {
        // TXE: Transmit data register empty (bit 7 in ISR)
        return (uart.get_reg().ISR.read().TXE != 0);
    }

    pub inline fn is_busy(uart: UART) bool {
        // BUSY: Busy flag (bit 16 in ISR)
        return (uart.get_reg().ISR.read().BUSY != 0);
    }

    // pub fn tx(uart: UART) dma.DMA_WriteTarget {
    //     return .{
    //         .dreq = if (@intFromEnum(uart) == 0) .uart0_tx else .uart1_tx,
    //         .addr = @intFromPtr(&uart.get_regs().UARTDR),
    //     };
    // }
    //
    // pub fn rx(uart: UART) dma.DMA_ReadTarget {
    //     return .{
    //         .dreq = if (@intFromEnum(uart) == 0) .uart0_rx else .uart1_rx,
    //         .addr = @intFromPtr(&uart.get_regs().UARTDR),
    //     };
    // }

    /// Enables/disables interrupts for a given UART.
    pub inline fn set_interrupts_enabled(uart: UART, enable: struct {
        rim: ?bool = null,
        ctsm: ?bool = null,
        dcdm: ?bool = null,
        dsrm: ?bool = null,
        rx: ?bool = null,
        tx: ?bool = null,
        rt: ?bool = null,
        fe: ?bool = null,
        pe: ?bool = null,
        be: ?bool = null,
        oe: ?bool = null,
    }) void {
        const uart_regs = uart.get_reg();
        const reg = uart_regs.UARTIMSC.read();
        uart_regs.UARTIMSC.write(.{
            .RIMIM = if (enable.rim) |e| @intFromBool(e) else reg.RIMIM,
            .CTSMIM = if (enable.ctsm) |e| @intFromBool(e) else reg.CTSMIM,
            .DCDMIM = if (enable.dcdm) |e| @intFromBool(e) else reg.DCDMIM,
            .DSRMIM = if (enable.dsrm) |e| @intFromBool(e) else reg.DSRMIM,
            .TXIM = if (enable.tx) |e| @intFromBool(e) else reg.TXIM,
            .RXIM = if (enable.rx) |e| @intFromBool(e) else reg.RXIM,
            .RTIM = if (enable.rt) |e| @intFromBool(e) else reg.RTIM,
            .FEIM = if (enable.fe) |e| @intFromBool(e) else reg.FEIM,
            .PEIM = if (enable.pe) |e| @intFromBool(e) else reg.PEIM,
            .BEIM = if (enable.be) |e| @intFromBool(e) else reg.BEIM,
            .OEIM = if (enable.oe) |e| @intFromBool(e) else reg.OEIM,
        });
    }

    /// Write bytes to uart TX line and block until transaction is complete.
    ///
    /// Note that this does NOT disable reception while this is happening,
    /// so if this takes too long the RX FIFO can potentially overflow.
    pub fn write_blocking(uart: UART, payload: []const u8, timeout: ?mdf.time.Duration) TransmitError!void {
        return try uart.writev_blocking(&.{payload}, timeout);
    }

    /// Write bytes to uart TX line and block until transaction is complete.
    ///
    /// NOTE: This function is a vectored version of `write_blocking` and takes an array of arrays.
    ///       This pattern allows one to create better zero-copy send routines as message prefixes and
    ///       suffixes won't need to be concatenated/inserted to the original buffer, but can be managed
    ///       in a separate memory.
    ///
    /// Note that this does NOT disable reception while this is happening,
    /// so if this takes too long the RX FIFO can potentially overflow.
    pub fn writev_blocking(uart: UART, payloads: []const []const u8, timeout: ?mdf.time.Duration) TransmitError!void {
        const uart_regs = uart.get_reg();
        const deadline = mdf.time.Deadline.init_relative(time.get_time_since_boot(), timeout);

        var iter = microzig.utilities.SliceVector([]const u8).init(payloads).iterator();
        while (iter.next_chunk(null)) |payload| {
            var offset: usize = uart.prime_tx_fifo(payload);
            while (offset < payload.len) {
                while (!uart.is_writeable()) {
                    try deadline.check(time.get_time_since_boot());
                }
                uart_regs.TDR.write_raw(payload[offset]);
                offset += 1;
            }
        }

        while (uart.is_busy()) {
            try deadline.check(time.get_time_since_boot());
        }
    }

    /// Returns a struct with the current status of UART errors.
    pub fn get_errors(uart: UART) ErrorStates {
        const uart_regs = uart.get_reg();
        const read_val = uart_regs.UARTRSR.read();
        return .{
            .overrun_error = read_val.OE == 1,
            .break_error = read_val.BE == 1,
            .parity_error = read_val.PE == 1,
            .framing_error = read_val.FE == 1,
        };
    }

    /// Clears all UART errors
    pub inline fn clear_errors(uart: UART) void {
        const regs = uart.get_reg();
        regs.ICR.modify(.{
            .ORECF = 1, // Overrun Error Clear Flag
            .FECF = 1, // Framing Error Clear Flag
            .PECF = 1, // Parity Error Clear Flag
            // No Break Error flag on STM32H7
        });
    }

    /// Returns the first active error encountered while reading a byte from the RX FIFO.
    fn read_rx_fifo_with_error_check(uart: UART) ReceiveError!u8 {
        const regs = uart.get_reg();
        const isr = regs.ISR.read();

        if (isr.ORE != 0) {
            return ReceiveError.OverrunError;
        } else if (isr.PE != 0) {
            return ReceiveError.ParityError;
        } else if (isr.FE != 0) {
            return ReceiveError.FramingError;
        }

        // Break error is not present in STM32H7 USART_ISR; skip if not needed.

        // return regs.RDR.read().RDR;
        return @intCast(regs.RDR.read().RDR);
    }

    /// Read bytes from uart RX line and block until transaction is complete.
    ///
    /// Returns a transaction error immediately if it occurs and doesn't
    /// complete the transaction. Errors are preserved for further inspection,
    /// so must be cleared with clear_errors() before another transaction is attempted.
    pub fn read_blocking(uart: UART, buffer: []u8, timeout: ?mdf.time.Duration) ReceiveBlockingError!void {
        return uart.readv_blocking(&.{buffer}, timeout);
    }

    /// Read bytes from uart RX line and block until transaction is complete.
    ///
    /// NOTE: This function is a vectored version of `read_blocking` and takes an array of arrays.
    ///       This pattern allows one to create better zero-copy send routines as message prefixes and
    ///       suffixes won't need to be concatenated/inserted to the original buffer, but can be managed
    ///       in a separate memory.
    ///
    /// Returns a transaction error immediately if it occurs and doesn't
    /// complete the transaction. Errors are preserved for further inspection,
    /// so must be cleared with clear_errors() before another transaction is attempted.
    pub fn readv_blocking(uart: UART, buffers: []const []u8, timeout: ?mdf.time.Duration) ReceiveBlockingError!void {
        const deadline = mdf.time.Deadline.init_relative(time.get_time_since_boot(), timeout);

        var iter = microzig.utilities.SliceVector([]u8).init(buffers).iterator();
        while (iter.next_chunk(null)) |buffer| {
            for (buffer) |*byte| {
                while (!uart.is_readable()) {
                    try deadline.check(time.get_time_since_boot());
                }
                byte.* = try uart.read_rx_fifo_with_error_check();
            }
        }
    }

    /// Convenience function for waiting for a single byte to come across the RX line.
    pub fn read_word_blocking(uart: UART, timeout: ?mdf.time.Duration) ReceiveBlockingError!u8 {
        var byte: [1]u8 = undefined;
        try uart.read_blocking(&byte, timeout);
        return byte[0];
    }

    /// Read a single byte from the RX line if available otherwise returns `null`.
    pub fn read_word(uart: UART) ReceiveError!?u8 {
        if (!uart.is_readable()) return null;
        return try uart.read_rx_fifo_with_error_check();
    }

    pub fn set_format(
        uart: UART,
        word_bits: u8,
        stop_bits: StopBits,
        parity: Parity,
    ) void {
        const usart = uart.get_reg();

        // 3. Configure word length, stop bits, parity
        usart.CR1.modify(.{
            .M0 = @as(u1, if (word_bits == 9) 1 else 0),
            .PCE = @as(u1, if (parity != .none) 1 else 0),
            .PS = @as(u1, if (parity == .odd) 1 else 0),
            .OVER8 = 0,
        });
        usart.CR2.modify(.{ .STOP = @as(u2, if (stop_bits == .two) 0b10 else 0b00) });
    }

    pub fn set_baudrate(uart: UART, baud_rate: u32, peri_freq: u32) void {
        const uart_reg = uart.get_reg();

        const UARTPrescTable: [12]u32 = [_]u32{ 1, 2, 4, 6, 8, 10, 12, 16, 32, 64, 128, 256 };
        const usartdiv = ((peri_freq / UARTPrescTable[clock_prescaler]) + (baud_rate / 2)) / baud_rate;
        uart_reg.BRR.raw = usartdiv;
    }

    pub fn set_flow_control(uart: UART, hw_fc: FlowControl) void {
        const regs = uart.get_reg();
        var ctsen: u1 = 0;
        var rtsen: u1 = 0;
        switch (hw_fc) {
            .none => {},
            .CTS => ctsen = 1,
            .RTS => rtsen = 1,
            .CTS_RTS => {
                ctsen = 1;
                rtsen = 1;
            },
        }
        regs.CR3.modify(.{
            .CTSE = ctsen,
            .RTSE = rtsen,
        });
    }
};

// Backing buffer for the logger's std.Io.Writer. The Writer is stored in a
// global so the address of its `interface` field (used by drain via
// @fieldParentPtr) stays stable across log calls.
var log_tx_buffer: [256]u8 = undefined;
var uart_logger: ?UART.Writer = null;

/// Set a specific uart instance to be used for logging.
///
/// Allows system logging over uart via:
/// pub const std_options = microzig.std_options(.{ .logFn = hal.uart.log });
pub fn init_logger(uart: UART) void {
    uart_logger = uart.writer(&log_tx_buffer);
    if (uart_logger) |*lg| {
        lg.interface.writeAll("\r\n================ STARTING NEW LOGGER ================\r\n") catch {};
        lg.interface.flush() catch {};
    }
}

/// Disables logging via the uart instance.
pub fn deinit_logger() void {
    uart_logger = null;
}

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const level_prefix = comptime "[{}.{:0>6}] " ++ level.asText();
    const prefix = comptime level_prefix ++ switch (scope) {
        .default => ": ",
        else => " (" ++ @tagName(scope) ++ "): ",
    };

    if (uart_logger) |*lg| {
        const current_time = time.get_time_since_boot();
        const seconds = current_time.to_us() / std.time.us_per_s;
        const microseconds = current_time.to_us() % std.time.us_per_s;

        lg.interface.print(prefix ++ format ++ "\r\n", .{ seconds, microseconds } ++ args) catch {};
        lg.interface.flush() catch {};
    }
}

var log_mutex: microzig.hal.mutex.Mutex = .{};

/// This log function wraps `log` in a semaphore so that calls to it from
/// different cores or interrupts don't collide.
pub fn log_threadsafe(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    log_mutex.lock();
    log(level, scope, format, args);
    log_mutex.unlock();
}
