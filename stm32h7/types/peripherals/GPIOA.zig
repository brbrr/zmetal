const microzig = @import("microzig");
const mmio = microzig.mmio;
const types = @import("../../types.zig");

pub const IDR = enum(u1) {
    /// Input is logic low
    Low = 0x0,
    /// Input is logic high
    High = 0x1,
};

pub const MODER = enum(u2) {
    /// Input mode (reset state)
    Input = 0x0,
    /// General purpose output mode
    Output = 0x1,
    /// Alternate function mode
    Alternate = 0x2,
    /// Analog mode
    Analog = 0x3,
};

pub const ODR = enum(u1) {
    /// Set output to logic low
    Low = 0x0,
    /// Set output to logic high
    High = 0x1,
};

pub const OSPEEDR = enum(u2) {
    /// Low speed
    LowSpeed = 0x0,
    /// Medium speed
    MediumSpeed = 0x1,
    /// High speed
    HighSpeed = 0x2,
    /// Very high speed
    VeryHighSpeed = 0x3,
};

pub const OT = enum(u1) {
    /// Output push-pull (reset state)
    PushPull = 0x0,
    /// Output open-drain
    OpenDrain = 0x1,
};

pub const PUPDR = enum(u2) {
    /// No pull-up, pull-down
    Floating = 0x0,
    /// Pull-up
    PullUp = 0x1,
    /// Pull-down
    PullDown = 0x2,
    _,
};

/// GPIO
pub const GPIOA = extern struct {
    /// GPIO port mode register
    /// offset: 0x00
    MODER: mmio.Mmio(packed struct(u32) {
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O mode.
        MODE0: MODER,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O mode.
        MODE1: MODER,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O mode.
        MODE2: MODER,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O mode.
        MODE3: MODER,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O mode.
        MODE4: MODER,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O mode.
        MODE5: MODER,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O mode.
        MODE6: MODER,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O mode.
        MODE7: MODER,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O mode.
        MODE8: MODER,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O mode.
        MODE9: MODER,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O mode.
        MODE10: MODER,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O mode.
        MODE11: MODER,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O mode.
        MODE12: MODER,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O mode.
        MODE13: MODER,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O mode.
        MODE14: MODER,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O mode.
        MODE15: MODER,
    }),
    /// GPIO port output type register
    /// offset: 0x04
    OTYPER: mmio.Mmio(packed struct(u32) {
        /// Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output type.
        OT0: OT,
        /// Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output type.
        OT1: OT,
        /// Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output type.
        OT2: OT,
        /// Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output type.
        OT3: OT,
        /// Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output type.
        OT4: OT,
        /// Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output type.
        OT5: OT,
        /// Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output type.
        OT6: OT,
        /// Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output type.
        OT7: OT,
        /// Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output type.
        OT8: OT,
        /// Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output type.
        OT9: OT,
        /// Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output type.
        OT10: OT,
        /// Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output type.
        OT11: OT,
        /// Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output type.
        OT12: OT,
        /// Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output type.
        OT13: OT,
        /// Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output type.
        OT14: OT,
        /// Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output type.
        OT15: OT,
        padding: u16 = 0,
    }),
    /// GPIO port output speed register
    /// offset: 0x08
    OSPEEDR: mmio.Mmio(packed struct(u32) {
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output speed. Note: Refer to the device datasheet for the frequency specifications and the power supply and load conditions for each speed.
        OSPEED0: OSPEEDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output speed. Note: Refer to the device datasheet for the frequency specifications and the power supply and load conditions for each speed.
        OSPEED1: OSPEEDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output speed. Note: Refer to the device datasheet for the frequency specifications and the power supply and load conditions for each speed.
        OSPEED2: OSPEEDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output speed. Note: Refer to the device datasheet for the frequency specifications and the power supply and load conditions for each speed.
        OSPEED3: OSPEEDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output speed. Note: Refer to the device datasheet for the frequency specifications and the power supply and load conditions for each speed.
        OSPEED4: OSPEEDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output speed. Note: Refer to the device datasheet for the frequency specifications and the power supply and load conditions for each speed.
        OSPEED5: OSPEEDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output speed. Note: Refer to the device datasheet for the frequency specifications and the power supply and load conditions for each speed.
        OSPEED6: OSPEEDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output speed. Note: Refer to the device datasheet for the frequency specifications and the power supply and load conditions for each speed.
        OSPEED7: OSPEEDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output speed. Note: Refer to the device datasheet for the frequency specifications and the power supply and load conditions for each speed.
        OSPEED8: OSPEEDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output speed. Note: Refer to the device datasheet for the frequency specifications and the power supply and load conditions for each speed.
        OSPEED9: OSPEEDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output speed. Note: Refer to the device datasheet for the frequency specifications and the power supply and load conditions for each speed.
        OSPEED10: OSPEEDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output speed. Note: Refer to the device datasheet for the frequency specifications and the power supply and load conditions for each speed.
        OSPEED11: OSPEEDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output speed. Note: Refer to the device datasheet for the frequency specifications and the power supply and load conditions for each speed.
        OSPEED12: OSPEEDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output speed. Note: Refer to the device datasheet for the frequency specifications and the power supply and load conditions for each speed.
        OSPEED13: OSPEEDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output speed. Note: Refer to the device datasheet for the frequency specifications and the power supply and load conditions for each speed.
        OSPEED14: OSPEEDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O output speed. Note: Refer to the device datasheet for the frequency specifications and the power supply and load conditions for each speed.
        OSPEED15: OSPEEDR,
    }),
    /// GPIO port pull-up/pull-down register
    /// offset: 0x0c
    PUPDR: mmio.Mmio(packed struct(u32) {
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O pull-up or pull-down
        PUPD0: PUPDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O pull-up or pull-down
        PUPD1: PUPDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O pull-up or pull-down
        PUPD2: PUPDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O pull-up or pull-down
        PUPD3: PUPDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O pull-up or pull-down
        PUPD4: PUPDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O pull-up or pull-down
        PUPD5: PUPDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O pull-up or pull-down
        PUPD6: PUPDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O pull-up or pull-down
        PUPD7: PUPDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O pull-up or pull-down
        PUPD8: PUPDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O pull-up or pull-down
        PUPD9: PUPDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O pull-up or pull-down
        PUPD10: PUPDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O pull-up or pull-down
        PUPD11: PUPDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O pull-up or pull-down
        PUPD12: PUPDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O pull-up or pull-down
        PUPD13: PUPDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O pull-up or pull-down
        PUPD14: PUPDR,
        /// [1:0]: Port x configuration bits (y = 0..15) These bits are written by software to configure the I/O pull-up or pull-down
        PUPD15: PUPDR,
    }),
    /// GPIO port input data register
    /// offset: 0x10
    IDR: mmio.Mmio(packed struct(u32) {
        /// Port input data bit (y = 0..15) These bits are read-only. They contain the input value of the corresponding I/O port.
        ID0: IDR,
        /// Port input data bit (y = 0..15) These bits are read-only. They contain the input value of the corresponding I/O port.
        ID1: IDR,
        /// Port input data bit (y = 0..15) These bits are read-only. They contain the input value of the corresponding I/O port.
        ID2: IDR,
        /// Port input data bit (y = 0..15) These bits are read-only. They contain the input value of the corresponding I/O port.
        ID3: IDR,
        /// Port input data bit (y = 0..15) These bits are read-only. They contain the input value of the corresponding I/O port.
        ID4: IDR,
        /// Port input data bit (y = 0..15) These bits are read-only. They contain the input value of the corresponding I/O port.
        ID5: IDR,
        /// Port input data bit (y = 0..15) These bits are read-only. They contain the input value of the corresponding I/O port.
        ID6: IDR,
        /// Port input data bit (y = 0..15) These bits are read-only. They contain the input value of the corresponding I/O port.
        ID7: IDR,
        /// Port input data bit (y = 0..15) These bits are read-only. They contain the input value of the corresponding I/O port.
        ID8: IDR,
        /// Port input data bit (y = 0..15) These bits are read-only. They contain the input value of the corresponding I/O port.
        ID9: IDR,
        /// Port input data bit (y = 0..15) These bits are read-only. They contain the input value of the corresponding I/O port.
        ID10: IDR,
        /// Port input data bit (y = 0..15) These bits are read-only. They contain the input value of the corresponding I/O port.
        ID11: IDR,
        /// Port input data bit (y = 0..15) These bits are read-only. They contain the input value of the corresponding I/O port.
        ID12: IDR,
        /// Port input data bit (y = 0..15) These bits are read-only. They contain the input value of the corresponding I/O port.
        ID13: IDR,
        /// Port input data bit (y = 0..15) These bits are read-only. They contain the input value of the corresponding I/O port.
        ID14: IDR,
        /// Port input data bit (y = 0..15) These bits are read-only. They contain the input value of the corresponding I/O port.
        ID15: IDR,
        padding: u16 = 0,
    }),
    /// GPIO port output data register
    /// offset: 0x14
    ODR: mmio.Mmio(packed struct(u32) {
        /// Port output data bit These bits can be read and written by software. Note: For atomic bit set/reset, the OD bits can be individually set and/or reset by writing to the GPIOx_BSRR or GPIOx_BRR registers (x = A..F).
        OD0: ODR,
        /// Port output data bit These bits can be read and written by software. Note: For atomic bit set/reset, the OD bits can be individually set and/or reset by writing to the GPIOx_BSRR or GPIOx_BRR registers (x = A..F).
        OD1: ODR,
        /// Port output data bit These bits can be read and written by software. Note: For atomic bit set/reset, the OD bits can be individually set and/or reset by writing to the GPIOx_BSRR or GPIOx_BRR registers (x = A..F).
        OD2: ODR,
        /// Port output data bit These bits can be read and written by software. Note: For atomic bit set/reset, the OD bits can be individually set and/or reset by writing to the GPIOx_BSRR or GPIOx_BRR registers (x = A..F).
        OD3: ODR,
        /// Port output data bit These bits can be read and written by software. Note: For atomic bit set/reset, the OD bits can be individually set and/or reset by writing to the GPIOx_BSRR or GPIOx_BRR registers (x = A..F).
        OD4: ODR,
        /// Port output data bit These bits can be read and written by software. Note: For atomic bit set/reset, the OD bits can be individually set and/or reset by writing to the GPIOx_BSRR or GPIOx_BRR registers (x = A..F).
        OD5: ODR,
        /// Port output data bit These bits can be read and written by software. Note: For atomic bit set/reset, the OD bits can be individually set and/or reset by writing to the GPIOx_BSRR or GPIOx_BRR registers (x = A..F).
        OD6: ODR,
        /// Port output data bit These bits can be read and written by software. Note: For atomic bit set/reset, the OD bits can be individually set and/or reset by writing to the GPIOx_BSRR or GPIOx_BRR registers (x = A..F).
        OD7: ODR,
        /// Port output data bit These bits can be read and written by software. Note: For atomic bit set/reset, the OD bits can be individually set and/or reset by writing to the GPIOx_BSRR or GPIOx_BRR registers (x = A..F).
        OD8: ODR,
        /// Port output data bit These bits can be read and written by software. Note: For atomic bit set/reset, the OD bits can be individually set and/or reset by writing to the GPIOx_BSRR or GPIOx_BRR registers (x = A..F).
        OD9: ODR,
        /// Port output data bit These bits can be read and written by software. Note: For atomic bit set/reset, the OD bits can be individually set and/or reset by writing to the GPIOx_BSRR or GPIOx_BRR registers (x = A..F).
        OD10: ODR,
        /// Port output data bit These bits can be read and written by software. Note: For atomic bit set/reset, the OD bits can be individually set and/or reset by writing to the GPIOx_BSRR or GPIOx_BRR registers (x = A..F).
        OD11: ODR,
        /// Port output data bit These bits can be read and written by software. Note: For atomic bit set/reset, the OD bits can be individually set and/or reset by writing to the GPIOx_BSRR or GPIOx_BRR registers (x = A..F).
        OD12: ODR,
        /// Port output data bit These bits can be read and written by software. Note: For atomic bit set/reset, the OD bits can be individually set and/or reset by writing to the GPIOx_BSRR or GPIOx_BRR registers (x = A..F).
        OD13: ODR,
        /// Port output data bit These bits can be read and written by software. Note: For atomic bit set/reset, the OD bits can be individually set and/or reset by writing to the GPIOx_BSRR or GPIOx_BRR registers (x = A..F).
        OD14: ODR,
        /// Port output data bit These bits can be read and written by software. Note: For atomic bit set/reset, the OD bits can be individually set and/or reset by writing to the GPIOx_BSRR or GPIOx_BRR registers (x = A..F).
        OD15: ODR,
        padding: u16 = 0,
    }),
    /// GPIO port bit set/reset register
    /// offset: 0x18
    BSRR: mmio.Mmio(packed struct(u32) {
        /// Port x set bit y (y= 0..15) These bits are write-only. A read to these bits returns the value 0x0000.
        BS0: u1,
        /// Port x set bit y (y= 0..15) These bits are write-only. A read to these bits returns the value 0x0000.
        BS1: u1,
        /// Port x set bit y (y= 0..15) These bits are write-only. A read to these bits returns the value 0x0000.
        BS2: u1,
        /// Port x set bit y (y= 0..15) These bits are write-only. A read to these bits returns the value 0x0000.
        BS3: u1,
        /// Port x set bit y (y= 0..15) These bits are write-only. A read to these bits returns the value 0x0000.
        BS4: u1,
        /// Port x set bit y (y= 0..15) These bits are write-only. A read to these bits returns the value 0x0000.
        BS5: u1,
        /// Port x set bit y (y= 0..15) These bits are write-only. A read to these bits returns the value 0x0000.
        BS6: u1,
        /// Port x set bit y (y= 0..15) These bits are write-only. A read to these bits returns the value 0x0000.
        BS7: u1,
        /// Port x set bit y (y= 0..15) These bits are write-only. A read to these bits returns the value 0x0000.
        BS8: u1,
        /// Port x set bit y (y= 0..15) These bits are write-only. A read to these bits returns the value 0x0000.
        BS9: u1,
        /// Port x set bit y (y= 0..15) These bits are write-only. A read to these bits returns the value 0x0000.
        BS10: u1,
        /// Port x set bit y (y= 0..15) These bits are write-only. A read to these bits returns the value 0x0000.
        BS11: u1,
        /// Port x set bit y (y= 0..15) These bits are write-only. A read to these bits returns the value 0x0000.
        BS12: u1,
        /// Port x set bit y (y= 0..15) These bits are write-only. A read to these bits returns the value 0x0000.
        BS13: u1,
        /// Port x set bit y (y= 0..15) These bits are write-only. A read to these bits returns the value 0x0000.
        BS14: u1,
        /// Port x set bit y (y= 0..15) These bits are write-only. A read to these bits returns the value 0x0000.
        BS15: u1,
        /// Port x reset bit y (y = 0..15) These bits are write-only. A read to these bits returns the value 0x0000. Note: If both BSx and BRx are set, BSx has priority.
        BR0: u1,
        /// Port x reset bit y (y = 0..15) These bits are write-only. A read to these bits returns the value 0x0000. Note: If both BSx and BRx are set, BSx has priority.
        BR1: u1,
        /// Port x reset bit y (y = 0..15) These bits are write-only. A read to these bits returns the value 0x0000. Note: If both BSx and BRx are set, BSx has priority.
        BR2: u1,
        /// Port x reset bit y (y = 0..15) These bits are write-only. A read to these bits returns the value 0x0000. Note: If both BSx and BRx are set, BSx has priority.
        BR3: u1,
        /// Port x reset bit y (y = 0..15) These bits are write-only. A read to these bits returns the value 0x0000. Note: If both BSx and BRx are set, BSx has priority.
        BR4: u1,
        /// Port x reset bit y (y = 0..15) These bits are write-only. A read to these bits returns the value 0x0000. Note: If both BSx and BRx are set, BSx has priority.
        BR5: u1,
        /// Port x reset bit y (y = 0..15) These bits are write-only. A read to these bits returns the value 0x0000. Note: If both BSx and BRx are set, BSx has priority.
        BR6: u1,
        /// Port x reset bit y (y = 0..15) These bits are write-only. A read to these bits returns the value 0x0000. Note: If both BSx and BRx are set, BSx has priority.
        BR7: u1,
        /// Port x reset bit y (y = 0..15) These bits are write-only. A read to these bits returns the value 0x0000. Note: If both BSx and BRx are set, BSx has priority.
        BR8: u1,
        /// Port x reset bit y (y = 0..15) These bits are write-only. A read to these bits returns the value 0x0000. Note: If both BSx and BRx are set, BSx has priority.
        BR9: u1,
        /// Port x reset bit y (y = 0..15) These bits are write-only. A read to these bits returns the value 0x0000. Note: If both BSx and BRx are set, BSx has priority.
        BR10: u1,
        /// Port x reset bit y (y = 0..15) These bits are write-only. A read to these bits returns the value 0x0000. Note: If both BSx and BRx are set, BSx has priority.
        BR11: u1,
        /// Port x reset bit y (y = 0..15) These bits are write-only. A read to these bits returns the value 0x0000. Note: If both BSx and BRx are set, BSx has priority.
        BR12: u1,
        /// Port x reset bit y (y = 0..15) These bits are write-only. A read to these bits returns the value 0x0000. Note: If both BSx and BRx are set, BSx has priority.
        BR13: u1,
        /// Port x reset bit y (y = 0..15) These bits are write-only. A read to these bits returns the value 0x0000. Note: If both BSx and BRx are set, BSx has priority.
        BR14: u1,
        /// Port x reset bit y (y = 0..15) These bits are write-only. A read to these bits returns the value 0x0000. Note: If both BSx and BRx are set, BSx has priority.
        BR15: u1,
    }),
    /// This register is used to lock the configuration of the port bits when a correct write sequence is applied to bit 16 (LCKK). The value of bits [15:0] is used to lock the configuration of the GPIO. During the write sequence, the value of LCKR[15:0] must not change. When the LOCK sequence has been applied on a port bit, the value of this port bit can no longer be modified until the next MCU reset or peripheral reset.A specific write sequence is used to write to the GPIOx_LCKR register. Only word access (32-bit long) is allowed during this locking sequence.Each lock bit freezes a specific configuration register (control and alternate function registers).
    /// offset: 0x1c
    LCKR: mmio.Mmio(packed struct(u32) {
        /// Port x lock bit y (y= 0..15) These bits are read/write but can only be written when the LCKK bit is 0.
        LCK0: u1,
        /// Port x lock bit y (y= 0..15) These bits are read/write but can only be written when the LCKK bit is 0.
        LCK1: u1,
        /// Port x lock bit y (y= 0..15) These bits are read/write but can only be written when the LCKK bit is 0.
        LCK2: u1,
        /// Port x lock bit y (y= 0..15) These bits are read/write but can only be written when the LCKK bit is 0.
        LCK3: u1,
        /// Port x lock bit y (y= 0..15) These bits are read/write but can only be written when the LCKK bit is 0.
        LCK4: u1,
        /// Port x lock bit y (y= 0..15) These bits are read/write but can only be written when the LCKK bit is 0.
        LCK5: u1,
        /// Port x lock bit y (y= 0..15) These bits are read/write but can only be written when the LCKK bit is 0.
        LCK6: u1,
        /// Port x lock bit y (y= 0..15) These bits are read/write but can only be written when the LCKK bit is 0.
        LCK7: u1,
        /// Port x lock bit y (y= 0..15) These bits are read/write but can only be written when the LCKK bit is 0.
        LCK8: u1,
        /// Port x lock bit y (y= 0..15) These bits are read/write but can only be written when the LCKK bit is 0.
        LCK9: u1,
        /// Port x lock bit y (y= 0..15) These bits are read/write but can only be written when the LCKK bit is 0.
        LCK10: u1,
        /// Port x lock bit y (y= 0..15) These bits are read/write but can only be written when the LCKK bit is 0.
        LCK11: u1,
        /// Port x lock bit y (y= 0..15) These bits are read/write but can only be written when the LCKK bit is 0.
        LCK12: u1,
        /// Port x lock bit y (y= 0..15) These bits are read/write but can only be written when the LCKK bit is 0.
        LCK13: u1,
        /// Port x lock bit y (y= 0..15) These bits are read/write but can only be written when the LCKK bit is 0.
        LCK14: u1,
        /// Port x lock bit y (y= 0..15) These bits are read/write but can only be written when the LCKK bit is 0.
        LCK15: u1,
        /// Lock key This bit can be read any time. It can only be modified using the lock key write sequence. LOCK key write sequence: WR LCKR[16] = 1 + LCKR[15:0] WR LCKR[16] = 0 + LCKR[15:0] WR LCKR[16] = 1 + LCKR[15:0] RD LCKR RD LCKR[16] = 1 (this read operation is optional but it confirms that the lock is active) Note: During the LOCK key write sequence, the value of LCK[15:0] must not change. Any error in the lock sequence aborts the lock. After the first lock sequence on any bit of the port, any read access on the LCKK bit will return 1 until the next MCU reset or peripheral reset.
        LCKK: u1,
        padding: u15 = 0,
    }),
    /// GPIO alternate function low register
    /// offset: 0x20
    AFRL: mmio.Mmio(packed struct(u32) {
        /// [3:0]: Alternate function selection for port x pin y (y = 0..7) These bits are written by software to configure alternate function I/Os AFSELy selection:
        AFSEL0: u4,
        /// [3:0]: Alternate function selection for port x pin y (y = 0..7) These bits are written by software to configure alternate function I/Os AFSELy selection:
        AFSEL1: u4,
        /// [3:0]: Alternate function selection for port x pin y (y = 0..7) These bits are written by software to configure alternate function I/Os AFSELy selection:
        AFSEL2: u4,
        /// [3:0]: Alternate function selection for port x pin y (y = 0..7) These bits are written by software to configure alternate function I/Os AFSELy selection:
        AFSEL3: u4,
        /// [3:0]: Alternate function selection for port x pin y (y = 0..7) These bits are written by software to configure alternate function I/Os AFSELy selection:
        AFSEL4: u4,
        /// [3:0]: Alternate function selection for port x pin y (y = 0..7) These bits are written by software to configure alternate function I/Os AFSELy selection:
        AFSEL5: u4,
        /// [3:0]: Alternate function selection for port x pin y (y = 0..7) These bits are written by software to configure alternate function I/Os AFSELy selection:
        AFSEL6: u4,
        /// [3:0]: Alternate function selection for port x pin y (y = 0..7) These bits are written by software to configure alternate function I/Os AFSELy selection:
        AFSEL7: u4,
    }),
    /// GPIO alternate function high register
    /// offset: 0x24
    AFRH: mmio.Mmio(packed struct(u32) {
        /// [3:0]: Alternate function selection for port x pin y (y = 8..15) These bits are written by software to configure alternate function I/Os
        AFSEL8: u4,
        /// [3:0]: Alternate function selection for port x pin y (y = 8..15) These bits are written by software to configure alternate function I/Os
        AFSEL9: u4,
        /// [3:0]: Alternate function selection for port x pin y (y = 8..15) These bits are written by software to configure alternate function I/Os
        AFSEL10: u4,
        /// [3:0]: Alternate function selection for port x pin y (y = 8..15) These bits are written by software to configure alternate function I/Os
        AFSEL11: u4,
        /// [3:0]: Alternate function selection for port x pin y (y = 8..15) These bits are written by software to configure alternate function I/Os
        AFSEL12: u4,
        /// [3:0]: Alternate function selection for port x pin y (y = 8..15) These bits are written by software to configure alternate function I/Os
        AFSEL13: u4,
        /// [3:0]: Alternate function selection for port x pin y (y = 8..15) These bits are written by software to configure alternate function I/Os
        AFSEL14: u4,
        /// [3:0]: Alternate function selection for port x pin y (y = 8..15) These bits are written by software to configure alternate function I/Os
        AFSEL15: u4,
    }),
};
