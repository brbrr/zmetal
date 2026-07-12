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
};

pub const PinSpec = struct {
    port: []const u8,
    pin: []const u8,
    af: gpio.AlternateFunction,
};

pub const Config = struct {
    baud_rate: u32 = 115200,
    /// USART kernel clock in Hz, used to compute BRR. Passed explicitly because
    /// this project's ClockTree doesn't expose per-USART clock outputs. For
    /// USART1/6 this is PCLK2 (D2PCLK2); the others use PCLK1.
    clock_hz: u32,
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

            // Reset config (raw 0 = 8 data bits, no parity, 1 stop bit).
            regs.CR1.raw = 0;
            regs.CR2.raw = 0;
            regs.CR3.raw = 0;

            // BRR = f_ck / baud (OVER8 = 0).
            const usartdiv = @divTrunc(config.clock_hz, config.baud_rate);
            regs.BRR.raw = @intCast(usartdiv);

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
