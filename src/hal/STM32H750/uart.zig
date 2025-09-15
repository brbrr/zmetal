const std = @import("std");

const microzig = @import("microzig");
const peripherals = microzig.chip.peripherals;
// const RCC = peripherals.RCC;

// const hal = @import("hal.zig");
// const Pin = hal.gpio.Pin;
// const clock = hal.clock;
const daisy = @import("daisy.zig");

pub const UartConfig = struct {
    baudrate: u32 = 115_200,
    word_length: u8 = 8, // bits: 8 or 9 typically
    stop_bits: u2 = 1, // bits: 1 or 2
    parity: enum { None, Even, Odd } = .None,
};

pub const UartInstance = enum(u8) {
    USART1 = 1,
    USART2,
    USART3,
    USART4,
    USART5,
    USART6,
};

pub const Uart = struct {
    instance: UartInstance,
    config: UartConfig,

    pub fn init(instance: UartInstance, config: UartConfig) Uart {
        return Uart{ .instance = instance, .config = config };
    }

    pub fn configure(comptime self: @This()) void {
        // FIXME: Hack since the above clock calculations are incorret for some reason
        // const sys_clk = 120_000_000;
        // const sys_clk = daisy.clock_outputs.SYS;
        const sys_clk = switch (self.instance) {
            .USART1, .USART6 => daisy.clock_outputs.USART16,
            else => daisy.clock_outputs.USART234578,
        };
        const usart = @field(peripherals, "USART" ++ self.name());

        // 1. Enable peripheral clock
        switch (self.instance) {
            .USART1 => peripherals.RCC.APB2ENR.modify_one("USART1EN", 1),
            .USART2 => peripherals.RCC.APB1LENR.modify_one("USART2EN", 1),
            .USART3 => peripherals.RCC.APB1LENR.modify_one("USART3EN", 1),
            else => @compileError("Unsupported UART instance"),
        }

        // 2. Disable USART before config
        usart.CR1.modify(.{ .UE = 0 });

        // 3. Configure word length, stop bits, parity
        usart.CR1.modify(.{
            .M0 = if (self.config.word_length == 9) 1 else 0,
            .PCE = if (self.config.parity != .None) 1 else 0,
            .PS = if (self.config.parity == .Odd) 1 else 0,
            .OVER8 = 0,
        });
        usart.CR2.modify(.{ .STOP = if (self.config.stop_bits == 2) 0b10 else 0b00 });
        // NOTE: Hardcoded UART_PRESCALER_DIV2 from dsy config
        const clock_prescaler = 1;
        usart.PRESC.modify_one("PRESCALER", clock_prescaler);

        // 4. Configure baud rate
        // const div = sys_clk / self.config.baudrate;
        // const usartdiv = @as(f32, @floatFromInt(sys_clk)) / @as(f32, @floatFromInt(self.config.baudrate));
        // const mantissa = @as(u12, @intFromFloat(@floor(usartdiv)));
        // const fraction = @as(u4, @intFromFloat(@round((usartdiv - @as(f32, @floatFromInt(mantissa))) * 16.0)));
        // usart.BRR.write(.{
        //     .BRR_4_15 = mantissa,
        //     .BRR_0_3 = fraction,
        // });

        // const usartdiv: u32 = @intCast(@divTrunc(sys_clk * 2, self.config.baudrate));

        const UARTPrescTable: [12]u32 = [_]u32{ 1, 2, 4, 6, 8, 10, 12, 16, 32, 64, 128, 256 };
        const usartdiv = ((sys_clk / UARTPrescTable[clock_prescaler]) + (self.config.baudrate / 2)) / self.config.baudrate;
        usart.BRR.raw = usartdiv;

        // 5. Enable transmitter and receiver
        usart.CR1.modify(.{ .TE = 1, .RE = 1 });

        // 6. Enable USART
        usart.CR1.modify(.{ .UE = 1 });
    }

    fn name(self: @This()) []const u8 {
        return switch (@intFromEnum(self.instance)) {
            1 => "1",
            2 => "2",
            3 => "3",
            4 => "4",
            5 => "5",
            else => "UART?",
        };
    }

    pub fn writeByte(comptime self: @This(), byte: u8) void {
        const usart = @field(peripherals, "USART" ++ self.name());
        while (usart.ISR.read().TXE == 0) {} // wait until transmit buffer empty
        usart.TDR.write(.{ .TDR = byte });
    }

    pub fn readByte(comptime self: @This()) u8 {
        const usart = @field(peripherals, "USART" ++ self.name());
        while (usart.ISR.read().RXNE == 0) {} // wait until data ready
        return @intCast(usart.RDR.read().RDR);
    }
};
