const std = @import("std");

const microzig = @import("microzig");
const peripherals = microzig.peripherals;
const cpu = microzig.cpu;
const chip = microzig.chip;

const systick = cpu.peripherals.systick;
const scb = cpu.peripherals.scb;
const rcc = chip.peripherals.RCC;

const chip_peri = chip.types.peripherals;
const FLASH = chip_peri.Flash;

const hal = @import("hal.zig");
const stm32 = hal;
const rcc_hal = stm32.rcc;
const uart = hal.uart;
const Pin = hal.gpio.Pin;

const Config = struct {
    //** Specifies whether the interface will operate in master or slave mode. */
    const Mode = enum {
        I2C_MASTER,
        I2C_SLAVE,
    };

    //** Specifices the internal peripheral to use (these are mapped to different pins on the hardware). */
    const Peripheral = enum(u2) {
        I2C_1 = 0,
        I2C_2,
        I2C_3,
        I2C_4,
    };

    // /** Rate at which the clock/data will be sent/received. The device being used will have maximum speeds.
    //  *  1MHZ Mode is currently 886kHz
    const Speed = enum {
        I2C_100KHZ,
        I2C_400KHZ,
        I2C_1MHZ,
    };

    const pin_config = struct {
        scl: Pin,
        sda: Pin,
    };

    periph: Peripheral,

    speed: Speed,
    mode: Mode,
    // 0x10 is chosen as a default to avoid conflicts with reserved addresses
    address: u8 = 0x10,
};

const Result = enum {
    Ok,
    Error,
};

const Direction = enum {
    Transmit,
    Receive,
};
