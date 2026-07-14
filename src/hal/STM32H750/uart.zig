//! UART driver for STM32H750 (usart_v4 registers).
//!
//! microzig ships only a `uart_v3` HAL, which hardcodes the `usart_v3` register
//! layout and is therefore incompatible with the H750 (whose USARTs are
//! `usart_v4`). This is a small self-contained driver over the chip's `usart_v4`
//! peripheral: 8-N-1 config, blocking/poll RX, and an interrupt-driven RX path
//! (RXNEIE) required for asynchronous byte streams like MIDI.
//!
//! Currently RX-focused (MIDI IN). TX can be layered on later.

const std = @import("std");
const microzig = @import("microzig");

const stm32_common = @import("stm32_common");
const enums = stm32_common.enums;
const rcc = microzig.hal.rcc;
const USART = microzig.chip.types.peripherals.usart_v4.USART;

const gpio = @import("gpio.zig");

/// UART peripheral selection. Maps to microzig's `enums.UART_Type` by name.
pub const Peripheral = enum {
    USART1,
    USART2,
    USART3,
    USART6,
    UART4,
    UART5,

    fn toType(comptime self: Peripheral) enums.UART_Type {
        return @field(enums.UART_Type, @tagName(self));
    }

    /// USART kernel clock (Hz) for `peripheral`, read from the resolved comptime
    /// clock tree (`rcc.clock_outputs`) rather than passed in by the app — the
    /// kernel clock is board/clock-tree state. STM32H7 splits the USARTs into two
    /// kernel-clock groups (USART1/6 vs USART2/3/4/5/7/8); the tree already accounts
    /// for each group's selected source. Mirrors how SAI uses `SAI1output`.
    fn kernel_clock_hz(comptime self: Peripheral) u32 {
        return switch (self) {
            .USART1, .USART6 => @intFromFloat(rcc.clock_outputs.USART16output),
            .USART2, .USART3, .UART4, .UART5 => @intFromFloat(rcc.clock_outputs.USART234578output),
        };
    }
};

pub const PinSpec = struct {
    port: []const u8,
    pin: []const u8,
    af: gpio.AlternateFunction,
};

pub const Config = struct {
    baud_rate: u32 = 115200,
    tx: PinSpec,
    rx: PinSpec,
    // Format is fixed at 8-N-1 (what MIDI and most serial links use); this is
    // the reset state of CR1/CR2, so no explicit word/parity/stop setup needed.
};

/// A UART instance bound to `peripheral` at comptime.
pub fn Uart(comptime peripheral: Peripheral) type {
    const index = comptime peripheral.toType();
    const regs = enums.get_regs(USART, index);

    return struct {
        const Self = @This();

        pub fn init(comptime config: Config) Self {
            configure_pins(config.tx, config.rx);

            rcc.enable_clock(enums.to_peripheral(index));

            // Clear to reset state (0 = 8 data bits, no parity, 1 stop bit).
            regs.CR1.write_raw(0);
            regs.CR2.write_raw(0);
            regs.CR3.write_raw(0);

            // BRR = f_ck / baud (OVER8 = 0). f_ck is derived from the clock tree.
            const usartdiv = @divTrunc(peripheral.kernel_clock_hz(), config.baud_rate);
            regs.BRR.write(.{ .BRR = @intCast(usartdiv) });

            // Enable the peripheral, transmitter and receiver.
            regs.CR1.modify(.{ .UE = 1, .TE = 1, .RE = 1 });

            return .{};
        }

        /// Enable the RXNE interrupt so the USART fires its IRQ on each received
        /// byte. The caller must also enable the NVIC line and install a handler.
        pub fn enableRxInterrupt(_: Self) void {
            regs.CR1.modify(.{ .RXNEIE = 1 });
        }

        /// True if a received byte is waiting in RDR.
        pub fn canRead(_: Self) bool {
            return regs.ISR.read().RXNE == 1;
        }

        /// Read one received byte (clears RXNE). Only call when `canRead()`.
        pub fn readByte(_: Self) u8 {
            return @intCast(regs.RDR.read().DR & 0xFF);
        }
    };
}

const StreamDevice = microzig.drivers.base.StreamDevice;
const interrupt = microzig.cpu.interrupt;

/// A byte-stream wrapper around `Uart(peripheral)`: buffers received bytes
/// from the RX interrupt into a lock-free SPSC ring, exposing the uniform
/// `read`/`write` stream contract (see `StreamDevice`) so it can plug into
/// generics like `hid.midi_port.MidiPort`. TX is currently accept-and-drop
/// (DIN MIDI OUT is not wired on this board).
pub fn UartStream(comptime peripheral: Peripheral) type {
    return struct {
        const Self = @This();
        const Dev = Uart(peripheral);

        var dev: Dev = undefined;

        // SPSC byte ring: producer = ISR, consumer = read() on the main loop.
        const RING = 256; // power of two
        var ring: [RING]u8 = undefined;
        var head: usize = 0; // next write slot (owned by ISR)
        var tail: usize = 0; // next read slot (owned by the reader)

        /// Bring up the underlying UART and enable its RX interrupt. The
        /// caller must still wire `irqHandler` into `microzig_options` for
        /// this peripheral's IRQ line; NVIC priority/enable is done here.
        pub fn init(comptime config: Config) Self {
            dev = Dev.init(config);
            dev.enableRxInterrupt();
            interrupt.set_priority(comptime irq(peripheral), .lowest);
            interrupt.enable(comptime irq(peripheral));
            return .{};
        }

        /// IRQ handler: drain received bytes into the ring. Wire into
        /// `microzig_options`, e.g. `.USART1 = .{ .c = UartStream(.USART1).irqHandler }`.
        pub fn irqHandler() callconv(.c) void {
            while (dev.canRead()) {
                const b = dev.readByte();
                const next = (head + 1) & (RING - 1);
                // Drop the byte if the consumer hasn't kept up (ring full).
                if (next != @atomicLoad(usize, &tail, .acquire)) {
                    ring[head] = b;
                    @atomicStore(usize, &head, next, .release);
                }
            }
        }

        pub fn read(_: Self, buf: []u8) StreamDevice.ReadError!usize {
            var n: usize = 0;
            while (n < buf.len) {
                const t = tail;
                if (t == @atomicLoad(usize, &head, .acquire)) break; // empty
                buf[n] = ring[t];
                @atomicStore(usize, &tail, (t + 1) & (RING - 1), .release);
                n += 1;
            }
            return n;
        }

        /// DIN MIDI TX is not wired; accept-and-drop so callers treat every
        /// send as delivered (matches the old midi_io behavior of not
        /// supporting DIN OUT at all).
        pub fn write(_: Self, bytes: []const u8) StreamDevice.WriteError!usize {
            return bytes.len;
        }
    };
}

/// Maps a `Peripheral` tag to its NVIC interrupt enum literal. Only the tags
/// actually used need to be listed here; add more as needed.
fn irq(comptime peripheral: Peripheral) @TypeOf(.enum_literal) {
    return switch (peripheral) {
        .USART1 => .USART1,
        .USART2 => .USART2,
        .USART3 => .USART3,
        .USART6 => .USART6,
        .UART4 => .UART4,
        .UART5 => .UART5,
    };
}

fn configure_pins(comptime tx: PinSpec, comptime rx: PinSpec) void {
    const tx_pin = comptime gpio.Pin.init(tx.port, tx.pin, .{
        .mode = .{ .alternate = tx.af },
        .otype = .PushPull,
        .speed = .VeryHighSpeed,
        .pull = .Floating,
    });
    tx_pin.configure();

    const rx_pin = comptime gpio.Pin.init(rx.port, rx.pin, .{
        .mode = .{ .alternate = rx.af },
        .speed = .VeryHighSpeed,
        .pull = .PullUp, // idle-high line
    });
    rx_pin.configure();
}
