//! UART driver for STM32H750 (usart_v4 registers).
//!
//! microzig ships only a `uart_v3` HAL, which hardcodes the `usart_v3` register
//! layout and is therefore incompatible with the H750 (whose USARTs are
//! `usart_v4`). This is a small self-contained driver over the chip's `usart_v4`
//! peripheral: 8-N-1 config, optional TX/RX pin inversion, blocking/poll RX,
//! and interrupt-driven RX (RXNEIE) and TX (TXEIE) paths for asynchronous
//! byte streams like MIDI.
//!
//! The receiver runs with the hardware FIFO on (CR1.FIFOEN). The RX FIFO is
//! 16 bytes deep (DS12556 Table 5 "Tx/Rx FIFO size"; ST HAL `RX_FIFO_DEPTH`):
//! at 31250 baud (DIN MIDI, 320 us a byte) the receive interrupt can be about
//! 5 ms late before a byte is lost. `UartStream` clears and counts overruns
//! and framing/noise errors (`rxStats`).

const std = @import("std");
const microzig = @import("microzig");

const stm32_common = @import("stm32_common");
const enums = stm32_common.enums;
const rcc = microzig.hal.rcc;
const USART = microzig.chip.types.peripherals.usart_v4.USART;

const gpio = @import("gpio.zig");
const ByteRing = @import("byte_ring.zig").ByteRing;

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

pub const PinSpec = gpio.AfPin;

pub const Config = struct {
    baud_rate: u32 = 115200,
    tx: PinSpec,
    rx: PinSpec,
    /// CR2.TXINV: the TX line idles low and data levels are inverted.
    invert_tx: bool = false,
    /// CR2.RXINV: the RX line idles low and data levels are inverted. The
    /// RX pin is then pulled down instead of up.
    invert_rx: bool = false,
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
            rcc.enable_clock(enums.to_peripheral(index));

            // Clear to reset state (0 = 8 data bits, no parity, 1 stop bit).
            regs.CR1.write_raw(0);
            regs.CR2.write_raw(0);
            regs.CR3.write_raw(0);

            // Pin inversion, written while UE = 0 (ST's HAL_UART_Init
            // disables the USART before it sets TXINV/RXINV).
            regs.CR2.modify(.{
                .TXINV = @intFromBool(config.invert_tx),
                .RXINV = @intFromBool(config.invert_rx),
            });

            // BRR = f_ck / baud (OVER8 = 0). f_ck is derived from the clock tree.
            const usartdiv = (peripheral.kernel_clock_hz() + config.baud_rate / 2) / config.baud_rate; // rounded
            regs.BRR.write(.{ .BRR = @intCast(usartdiv) });

            // The RX pin before the receiver: in its reset (analog) mode the
            // pin feeds the USART a constant 0, so the receiver would start
            // on a line that is not at its idle level. Pulled to the idle
            // level, the line is idle from the moment RE is set.
            configureRxPin(config.rx, config.invert_rx);

            // Enable the peripheral, transmitter and receiver, FIFO mode on.
            // FIFOEN is written while UE is still 0, as ST's
            // HAL_UARTEx_EnableFifoMode does.
            regs.CR1.modify(.{ .UE = 1, .TE = 1, .RE = 1, .FIFOEN = 1 });

            // The TX pin last, when the transmitter already drives its idle
            // level. With `invert_tx` the TX pin must never idle high: on the
            // v3 board a high level switches the MIDI-out FET on, and the
            // receiver sees a start bit.
            configureTxPin(config.tx);

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
/// from the RX interrupt into a lock-free SPSC ring and bytes to send into
/// another that the TX interrupt drains, exposing the uniform `read`/`write`
/// stream contract (see `StreamDevice`) so it can plug into generics like
/// `hid.midi_port.MidiPort`.
pub fn UartStream(comptime peripheral: Peripheral) type {
    return struct {
        const Self = @This();
        const Dev = Uart(peripheral);
        const regs = enums.get_regs(USART, peripheral.toType());
        const ICR = @FieldType(USART, "ICR").underlying_type;

        var dev: Dev = undefined;

        // SPSC byte ring: producer = ISR, consumer = read() on the main loop.
        var rx: ByteRing(256) = .{};
        // SPSC byte ring: producer = write() on the main loop, consumer = ISR.
        var tx: ByteRing(256) = .{};

        /// Receive events since boot, each counter wrapping at 2^32.
        pub const RxStats = struct { overruns: u32 = 0, line_errors: u32 = 0, dropped: u32 = 0 };

        // Stored only by `irqHandler`, loaded only by `rxStats`.
        var stats: RxStats = .{};

        /// The receive counters: `overruns` = ORE events (received bytes lost
        /// in the USART), `line_errors` = framing + noise errors, `dropped` =
        /// bytes that found the ring full. Each counter is read whole; the
        /// three are not one snapshot.
        pub fn rxStats() RxStats {
            return .{
                .overruns = @atomicLoad(u32, &stats.overruns, .monotonic),
                .line_errors = @atomicLoad(u32, &stats.line_errors, .monotonic),
                .dropped = @atomicLoad(u32, &stats.dropped, .monotonic),
            };
        }

        // Handler-side increment. The handler is the only writer, so a plain
        // load and store suffice (no read-modify-write instruction).
        fn count(counter: *u32) void {
            @atomicStore(u32, counter, @atomicLoad(u32, counter, .monotonic) +% 1, .monotonic);
        }

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

        /// IRQ handler: count and clear receive errors, drain the RX FIFO
        /// into the ring, and feed the TX FIFO from the ring. Wire into
        /// `microzig_options`, e.g.
        /// `.USART1 = .{ .c = UartStream(.USART1).irqHandler }`.
        pub fn irqHandler() callconv(.c) void {
            // With RXNEIE set, ORE keeps the interrupt pending until ICR
            // clears it; reading RDR does not.
            const isr = regs.ISR.read();
            if (isr.ORE == 1 or isr.FE == 1 or isr.NE == 1) {
                if (isr.ORE == 1) count(&stats.overruns);
                if (isr.FE == 1) count(&stats.line_errors);
                if (isr.NE == 1) count(&stats.line_errors);
                var clear: ICR = @bitCast(@as(u32, 0));
                clear.ORE = isr.ORE;
                clear.FE = isr.FE;
                clear.NE = isr.NE;
                regs.ICR.write(clear);
            }
            // In FIFO mode RXNE means "RX FIFO not empty". Every byte is read
            // out of RDR, kept or not, so the loop ends with the FIFO empty.
            while (dev.canRead()) {
                if (!rx.push(dev.readByte())) count(&stats.dropped);
            }
            // In FIFO mode TXE means "TX FIFO not full", so it is set nearly
            // always: act on it only while TXEIE is on. Only this handler
            // clears TXEIE, and only when the ring is empty; `write` sets it
            // after it queues.
            if (regs.CR1.read().TXEIE == 1) {
                while (regs.ISR.read().TXE == 1) {
                    const b = tx.pop() orelse {
                        regs.CR1.modify(.{ .TXEIE = 0 });
                        break;
                    };
                    regs.TDR.write(.{ .DR = b });
                }
            }
        }

        pub fn read(_: Self, buf: []u8) StreamDevice.ReadError!usize {
            var n: usize = 0;
            while (n < buf.len) : (n += 1) buf[n] = rx.pop() orelse break;
            return n;
        }

        /// Queue `bytes` for the TX interrupt, all or nothing: returns
        /// `bytes.len` when every byte is queued, 0 when the 256-byte ring
        /// (255 usable) lacks room, and then nothing is queued, so a MIDI
        /// message never goes out cut short. Never blocks.
        ///
        /// The ring's single producer: call it from thread mode only. NVIC
        /// masking cannot hold off a handler that is already running, so a
        /// call from a higher-priority interrupt could land between the
        /// handler finding the ring empty and its clearing TXEIE, and leave
        /// the bytes stuck.
        pub fn write(_: Self, bytes: []const u8) StreamDevice.WriteError!usize {
            if (bytes.len == 0) return 0;
            if (!tx.pushSlice(bytes)) return 0;
            // The handler clears TXEIE in CR1 as well: mask this USART's
            // line around the read-modify-write. DSB + ISB make the mask
            // take effect before CR1 is read (CMSIS __NVIC_DisableIRQ).
            interrupt.disable(comptime irq(peripheral));
            microzig.cpu.dsb();
            microzig.cpu.isb();
            regs.CR1.modify(.{ .TXEIE = 1 });
            interrupt.enable(comptime irq(peripheral));
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

fn configureTxPin(comptime tx: PinSpec) void {
    const tx_pin = comptime gpio.Pin.from(tx.pin, .{
        .mode = .{ .alternate = tx.af },
        .otype = .PushPull,
        .speed = .VeryHighSpeed,
        .pull = .Floating,
    });
    tx_pin.configure();
}

/// The pull holds an unconnected line at its idle level: high, or low when
/// the line is inverted.
fn configureRxPin(comptime rx: PinSpec, comptime inverted: bool) void {
    const rx_pin = comptime gpio.Pin.from(rx.pin, .{
        .mode = .{ .alternate = rx.af },
        .speed = .VeryHighSpeed,
        .pull = if (inverted) .PullDown else .PullUp,
    });
    rx_pin.configure();
}
