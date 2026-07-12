//! MIDI input over UART (USART1, 31250 baud, Daisy default pins PB7=RX/PB6=TX).
//!
//! Module-level singleton because the USART1 interrupt handler must be a plain
//! function that reaches the receive ring buffer. Received bytes are pushed from
//! the ISR into a lock-free single-producer/single-consumer ring; the main loop
//! drains them through the MIDI parser via `poll()`.

const std = @import("std");
const microzig = @import("microzig");
const uart = microzig.hal.usart;
const midi = @import("midi.zig");

pub const Message = midi.Message;

const MidiUart = uart.Uart(.USART1);
const UART_CONFIG = uart.Config{
    .baud_rate = 31250,
    .clock_hz = 120_000_000, // USART1 kernel clock = PCLK2 (D2PCLK2), per the daisy clock config
    .tx = .{ .port = "B", .pin = "6", .af = .af7 },
    .rx = .{ .port = "B", .pin = "7", .af = .af7 },
};

var device: MidiUart = undefined;
var parser = midi.Parser.init();

// SPSC ring buffer: producer = USART1 ISR, consumer = main loop.
const RING_SIZE = 256; // power of two
var ring: [RING_SIZE]u8 = undefined;
var head: usize = 0; // next write slot (owned by ISR)
var tail: usize = 0; // next read slot (owned by main)

pub fn init() void {
    device = MidiUart.init(UART_CONFIG);
    device.enableRxInterrupt();
    microzig.cpu.interrupt.set_priority(.USART1, .lowest);
    microzig.cpu.interrupt.enable(.USART1);
}

/// USART1 IRQ handler: drain all received bytes into the ring. Wire into
/// `microzig_options`: `.USART1 = .{ .c = midi_input.usart1_irq_handler }`.
pub fn usart1_irq_handler() callconv(.c) void {
    while (device.canRead()) {
        const byte = device.readByte();
        const next = (head + 1) & (RING_SIZE - 1);
        // Drop the byte if the consumer hasn't kept up (ring full).
        if (next != @atomicLoad(usize, &tail, .acquire)) {
            ring[head] = byte;
            @atomicStore(usize, &head, next, .release);
        }
    }
}

/// Pop the next decoded MIDI message, draining buffered bytes through the
/// parser. Returns null when no complete message is currently available.
pub fn poll() ?Message {
    while (pop()) |byte| {
        if (parser.feed(byte)) |msg| return msg;
    }
    return null;
}

fn pop() ?u8 {
    const t = tail;
    if (t == @atomicLoad(usize, &head, .acquire)) return null; // empty
    const byte = ring[t];
    @atomicStore(usize, &tail, (t + 1) & (RING_SIZE - 1), .release);
    return byte;
}
