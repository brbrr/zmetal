const std = @import("std");
const microzig = @import("microzig");
const hal = @import("hal/STM32H750/hal.zig");
const stm32 = hal;
const rcc = stm32.rcc;

// INTERNAL_ADDRESS = 0x08000000
// FLASH_ADDRESS ?= $(INTERNAL_ADDRESS)
// dfu-util -a 0 -s 0x08000000:leave -D zig-out/firmware/blinky.elf -d ,0483:df11

fn delay() void {
    var i: u32 = 0;
    while (i < 800_000) {
        asm volatile ("nop");
        i += 1;
    }
}

const clk_config = stm32.rcc.Config{
    .PLLSource = .RCC_PLLSOURCE_HSE,
    .HSEDivPLL = .RCC_HSE_PREDIV_DIV2,
    .PLLMUL = .RCC_PLL_MUL2,
    .SysClkSource = .RCC_SYSCLKSOURCE_PLLCLK,
    .APB1Prescaler = .RCC_HCLK_DIV1,
    .MCOMult = .RCC_MCO1SOURCE_SYSCLK,
};

// constexpr GPIOPort SEED_LED_PORT = PORTC;
// constexpr uint8_t  SEED_LED_PIN  = 7;

pub fn main() !void {
    try rcc.apply_clock(clk_config);

    // rcc.enable_clock(.GPIOA);
    // rcc.enable_clock(.AFIO);
    // rcc.enable_clock(.USART1);
    const pins, const all_leds = res: {
        const pins = (stm32.pins.GlobalConfiguration{ .GPIOC = .{
            .PC7 = .{ .name = "led", .mode = .{ .output = .push_pull } },
        } }).apply();
        const all_leds = .{
            pins.led,
        };
        break :res .{ pins, all_leds };
    };
    _ = pins;

    // const led_pin = stm32.parse_pin("PC7");
    while (true) {
        delay();
        // stm32.gpio.write(led_pin, .high);
        // delay();
        // stm32.gpio.write(led_pin, .low);
        // pub fn write(comptime pin: type, state: microzig.gpio.State) void {
        for (0..all_leds.len) |k| {
            switch (@as(u3, @intCast(k))) {
                inline else => |i| {
                    if (i >= all_leds.len) unreachable;
                    all_leds[i].toggle();
                },
            }
        }
    }
}

// const rp2xxx = microzig.hal;
// const time = rp2xxx.time;
//
// // Compile-time pin configuration
// const pin_config = rp2xxx.pins.GlobalConfiguration{
//     // For Frood. Default iw 25
//     .GPIO17 = .{
//         .name = "led",
//         .direction = .out,
//     },
// };
//
// const pins = pin_config.pins();
//
// pub fn main() !void {
//     pin_config.apply();
//
//     while (true) {
//         pins.led.toggle();
//         time.sleep_ms(250);
//     }
// }
//
//
