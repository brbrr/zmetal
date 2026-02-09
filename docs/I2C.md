# I2C Protocol Implementation

This document describes the I2C (Inter-Integrated Circuit) implementation for the ZMetal firmware project, targeting the STM32H750 microcontroller on the Daisy Seed platform.

## Overview

The I2C implementation provides a zero-cost abstraction over microzig's `I2C_Device` framework, offering:

- **Zero-cost abstractions**: All timing calculations done at compile time
- **Type safety**: Compile-time peripheral selection and configuration
- **microzig compatibility**: Full support for microzig I2C drivers
- **Blocking operations**: Simple synchronous read/write API
- **Multiple peripherals**: Support for all 4 I2C buses (I2C1-4)
- **Flexible pin configuration**: Use default Daisy pins or custom mappings

## Architecture

### Layers

1. **Hardware (STM32H750)**: Physical I2C peripherals with memory-mapped registers
2. **microzig i2c_v2**: STM32 I2C v2 peripheral driver (automatic timing calculation)
3. **ZMetal HAL i2c.zig**: Daisy-specific wrapper with pin configuration
4. **Application**: Your firmware code using I2C devices

### Design Philosophy

Based on microzig's `I2C_Device` abstraction pattern:

```zig
// From microzig/drivers/base/I2C_Device.zig
pub const I2C_Device = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    
    pub fn write(dev: I2C_Device, address: Address, data: []const u8) Error!void;
    pub fn read(dev: I2C_Device, address: Address, buffer: []u8) Error!usize;
    pub fn write_then_read(dev: I2C_Device, address: Address, src: []const u8, dst: []u8) Error!void;
    // ...
};
```

This design allows:
- **Runtime polymorphism** via vtable for driver compatibility
- **Compile-time optimization** when peripheral is known at comptime
- **Type-safe addresses** using enum-based 7-bit addresses

## Hardware Configuration

### STM32H750 I2C Peripherals

| Peripheral | APB Bus | Clock Source | DMA Support | Default Pins (Daisy) |
|------------|---------|--------------|-------------|----------------------|
| I2C1       | APB1    | APB1 clock   | Yes (DMA1)  | PB8 (SCL), PB9 (SDA) |
| I2C2       | APB1    | APB1 clock   | Yes (DMA1)  | PB10 (SCL), PB11 (SDA) |
| I2C3       | APB1    | APB1 clock   | Yes (DMA1)  | PA8 (SCL), PC9 (SDA) |
| I2C4       | APB4    | APB4 clock   | No          | PD12 (SCL), PD13 (SDA) |

### Clock Configuration

I2C timing is automatically calculated based on:
- APB clock frequency (from RCC configuration)
- Desired I2C speed (100kHz, 400kHz, or 1MHz)
- I2C v2 timing specifications (setup/hold times, rise/fall times)

The timing calculation happens at **compile time** when the peripheral and clock configuration are known, eliminating runtime overhead.

### Pin Configuration

Pins are configured with:
- **Mode**: Alternate Function
- **Output Type**: Open-drain (required for I2C)
- **Speed**: Very High
- **Pull**: Pull-up (required for I2C)
- **Alternate Function**: AF4 for all I2C pins on H7

## API Reference

### Types

#### `I2C_Device`

Main type for I2C communication. Wraps microzig's i2c_v2 implementation.

```zig
pub const I2C_Device = struct {
    inner: i2c_v2.I2C_Device,
    
    pub fn init(comptime peripheral: Peripheral, comptime config: Config) !I2C_Device;
    pub fn apply(self: *const I2C_Device) void;
    pub fn i2c_device(self: *I2C_Device) drivers.base.I2C_Device;
    
    // Blocking I/O operations
    pub fn write(self: *I2C_Device, address: Address, data: []const u8) Error!void;
    pub fn read(self: *I2C_Device, address: Address, buffer: []u8) Error!usize;
    pub fn write_then_read(self: *I2C_Device, address: Address, write_data: []const u8, read_buffer: []u8) Error!void;
    
    // Convenience functions
    pub fn read_register(self: *I2C_Device, device_addr: Address, register_addr: u8, buffer: []u8) Error!void;
    pub fn write_register(self: *I2C_Device, device_addr: Address, register_addr: u8, data: []const u8) Error!void;
};
```

#### `Peripheral`

Selects which I2C peripheral to use.

```zig
pub const Peripheral = enum {
    I2C1,
    I2C2,
    I2C3,
    I2C4,
};
```

#### `Config`

Configuration structure for I2C initialization.

```zig
pub const Config = struct {
    speed: Speed = .I2C_400KHZ,
    pin_config: ?PinConfig = null,  // null = use Daisy defaults
};
```

#### `Speed`

I2C clock speed selection.

```zig
pub const Speed = enum {
    I2C_100KHZ,   // Standard mode: 100 kHz
    I2C_400KHZ,   // Fast mode: 400 kHz (most common)
    I2C_1MHZ,     // Fast mode plus: ~886 kHz
};
```

#### `Address`

7-bit I2C device address (0x00-0x7F). From microzig's I2C_Device.

```zig
pub const Address = enum(u7) {
    _,
    
    pub fn check_reserved(addr: Address) Address.Error!void;
};

// Usage:
const device_addr: Address = @enumFromInt(0x38);
```

### Functions

#### `init()`

Initialize an I2C peripheral with configuration. Must be called before `apply()`.

```zig
pub fn init(comptime peripheral: Peripheral, comptime config: Config) !I2C_Device
```

**Parameters:**
- `peripheral`: Which I2C peripheral to use (I2C1-4)
- `config`: Configuration (speed, optional pin config)

**Returns:** Initialized I2C_Device

**Errors:**
- `error.PCLKOverflow`: APB clock frequency too high
- `error.PCLKUnderflow`: APB clock frequency too low

**Example:**
```zig
var i2c1 = try hal.i2c.I2C_Device.init(.I2C1, .{
    .speed = .I2C_400KHZ,
});
```

#### `apply()`

Enable the I2C peripheral and apply configuration. Must be called after `init()`.

```zig
pub fn apply(self: *const I2C_Device) void
```

**Example:**
```zig
i2c1.apply();
```

#### `write()`

Write data to an I2C device (blocking).

```zig
pub fn write(self: *I2C_Device, address: Address, data: []const u8) Error!void
```

**Parameters:**
- `address`: 7-bit device address
- `data`: Data to write

**Errors:** See [Error Types](#error-types)

**Example:**
```zig
const cmd = [_]u8{ 0xAC, 0x33, 0x00 };
try i2c1.write(@enumFromInt(0x38), &cmd);
```

#### `read()`

Read data from an I2C device (blocking).

```zig
pub fn read(self: *I2C_Device, address: Address, buffer: []u8) Error!usize
```

**Parameters:**
- `address`: 7-bit device address
- `buffer`: Buffer to read into

**Returns:** Number of bytes read

**Errors:** See [Error Types](#error-types)

**Example:**
```zig
var data: [7]u8 = undefined;
const bytes_read = try i2c1.read(@enumFromInt(0x38), &data);
```

#### `write_then_read()`

Write then read with repeated start condition (blocking). Useful for register access.

```zig
pub fn write_then_read(
    self: *I2C_Device,
    address: Address,
    write_data: []const u8,
    read_buffer: []u8,
) Error!void
```

**Parameters:**
- `address`: 7-bit device address
- `write_data`: Data to write (typically register address)
- `read_buffer`: Buffer to read into

**Example:**
```zig
const reg_addr = [_]u8{0x00};
var reg_value: [2]u8 = undefined;
try i2c1.write_then_read(@enumFromInt(0x38), &reg_addr, &reg_value);
```

#### `read_register()`

Convenience function to read from a register address.

```zig
pub fn read_register(
    self: *I2C_Device,
    device_addr: Address,
    register_addr: u8,
    buffer: []u8,
) Error!void
```

**Example:**
```zig
var value: [2]u8 = undefined;
try i2c1.read_register(@enumFromInt(0x38), 0x00, &value);
```

#### `write_register()`

Convenience function to write to a register address.

```zig
pub fn write_register(
    self: *I2C_Device,
    device_addr: Address,
    register_addr: u8,
    data: []const u8,
) Error!void
```

**Example:**
```zig
const data = [_]u8{ 0x01, 0x02 };
try i2c1.write_register(@enumFromInt(0x38), 0x00, &data);
```

### Error Types

```zig
pub const Error = error{
    DeviceNotPresent,      // Device not responding
    NoAcknowledge,         // NACK received
    Timeout,               // Operation timed out
    TargetAddressReserved, // Address is reserved
    NoData,                // No data available
    BufferOverrun,         // Buffer overflow
    UnknownAbort,          // Unknown error
    IllegalAddress,        // Invalid address
};
```

## Usage Examples

### Basic Usage

```zig
const std = @import("std");
const microzig = @import("microzig");
const hal = microzig.hal;

pub fn main() !void {
    // Initialize I2C1 with default Daisy Seed pins
    var i2c1 = try hal.i2c.I2C_Device.init(.I2C1, .{
        .speed = .I2C_400KHZ,
    });
    i2c1.apply();
    
    // Device address
    const addr: hal.i2c.Address = @enumFromInt(0x38);
    
    // Write command
    const cmd = [_]u8{0xAC};
    try i2c1.write(addr, &cmd);
    
    // Read response
    var data: [7]u8 = undefined;
    _ = try i2c1.read(addr, &data);
}
```

### Using with microzig Drivers

```zig
const drivers = microzig.drivers;

pub fn main() !void {
    // Initialize I2C
    var i2c1 = try hal.i2c.I2C_Device.init(.I2C1, .{});
    i2c1.apply();
    
    // Get I2C_Device interface
    const i2c_dev = i2c1.i2c_device();
    
    // Use with AHT30 sensor driver
    const sensor_addr: hal.i2c.Address = @enumFromInt(0x38);
    var sensor = try drivers.sensor.AHT30.init(i2c_dev, sensor_addr);
    
    // Read sensor
    try sensor.update_readings();
    hal.time.delay_ms(80);
    const reading = try sensor.read_data();
    
    std.log.info("Temp: {d:.2}°C, Humidity: {d:.2}%", .{
        reading.temperature_c,
        reading.relative_humidity,
    });
}
```

### Custom Pin Configuration

```zig
pub fn main() !void {
    // Use custom pins instead of defaults
    var i2c1 = try hal.i2c.I2C_Device.init(.I2C1, .{
        .speed = .I2C_100KHZ,
        .pin_config = .{
            .scl = .{ .port = "B", .pin = "6", .af = 4 },
            .sda = .{ .port = "B", .pin = "7", .af = 4 },
        },
    });
    i2c1.apply();
}
```

### Multiple I2C Buses

```zig
pub fn main() !void {
    // Initialize multiple buses
    var i2c1 = try hal.i2c.I2C_Device.init(.I2C1, .{});
    var i2c2 = try hal.i2c.I2C_Device.init(.I2C2, .{});
    
    i2c1.apply();
    i2c2.apply();
    
    // Use different sensors on different buses
    const sensor1_addr: hal.i2c.Address = @enumFromInt(0x38);
    const sensor2_addr: hal.i2c.Address = @enumFromInt(0x44);
    
    var data1: [8]u8 = undefined;
    var data2: [8]u8 = undefined;
    
    _ = try i2c1.read(sensor1_addr, &data1);
    _ = try i2c2.read(sensor2_addr, &data2);
}
```

## Performance Characteristics

### Compile-Time Optimization

When the peripheral and configuration are known at compile time, the Zig compiler can:
- Inline all function calls
- Compute timing registers at compile time
- Eliminate vtable overhead for direct peripheral access
- Optimize away unused code paths

### Runtime Overhead

For a typical I2C transaction:
- **Function call overhead**: Zero (inlined)
- **Timing calculation**: Zero (done at compile time)
- **Configuration overhead**: Zero (applied once at startup)
- **Data transfer**: Hardware-limited (only register access overhead)

### Memory Footprint

- **I2C_Device struct**: ~16 bytes (pointer + timing register value)
- **Code size**: Minimal (shared microzig i2c_v2 implementation)
- **No dynamic allocation**: All memory statically allocated

## Comparison with libdaisy

### libdaisy Architecture

```cpp
class I2CHandle {
    I2C_HandleTypeDef i2c_hal_handle_;  // STM32 HAL handle
    Config config_;
    
    Result TransmitBlocking(uint16_t address, uint8_t* data, ...);
    Result ReceiveBlocking(uint16_t address, uint8_t* data, ...);
    Result TransmitDma(uint16_t address, uint8_t* data, ...);
};
```

### ZMetal Advantages

| Feature | libdaisy | ZMetal |
|---------|----------|--------|
| Timing calculation | Runtime | Compile-time |
| Type safety | Runtime errors | Compile-time errors |
| Memory safety | Manual checks | Zig compiler |
| Abstraction cost | Virtual functions | Zero (inlined) |
| Driver ecosystem | libdaisy-specific | microzig-compatible |
| Error handling | Return codes | Zig error unions |
| Multiple peripherals | Runtime dispatch | Comptime selection |

### Compatibility

ZMetal I2C can interoperate with any microzig I2C driver through the `I2C_Device` interface:

```zig
// ZMetal I2C
var i2c = try hal.i2c.I2C_Device.init(.I2C1, .{});
i2c.apply();

// microzig driver
const i2c_dev = i2c.i2c_device();
var sensor = try drivers.sensor.AHT30.init(i2c_dev, addr);
```

## Troubleshooting

### Build Errors

**Error: PCLKOverflow**
- Cause: APB clock frequency too high for desired I2C speed
- Solution: Lower APB clock frequency or use slower I2C speed

**Error: PCLKUnderflow**
- Cause: APB clock frequency too low
- Solution: Increase APB clock frequency in RCC configuration

### Runtime Errors

**Error: NoAcknowledge**
- Cause: Device not responding or wrong address
- Check: Device address, pull-up resistors, power supply

**Error: Timeout**
- Cause: Bus stuck or device not responding
- Check: Pull-up resistors, clock configuration, bus capacitance

**Error: DeviceNotPresent**
- Cause: Device not on bus
- Check: Wiring, address, device power

### Debugging Tips

1. **Check bus with logic analyzer**: Verify SCL/SDA signals
2. **Verify pull-ups**: 4.7kΩ typical for 100kHz, 2.2kΩ for 400kHz
3. **Check addresses**: Use I2C scanner to detect devices
4. **Verify clock**: Ensure APB clock is configured correctly
5. **Test with known device**: Use simple EEPROM or sensor first

## Implementation Details

### Source Files

- `src/hal/STM32H750/i2c.zig`: Main I2C implementation
- `src/hal/STM32H750/hal.zig`: HAL integration
- `src/hal/STM32H750/rcc.zig`: Clock enable/disable for I2C1-4
- `lib/microzig/port/stmicro/stm32/src/hals/common/i2c_v2.zig`: Base implementation

### Dependencies

- **microzig**: Core framework and I2C_Device abstraction
- **stm32_common**: STM32 i2c_v2 driver (timing calculation)
- **HAL modules**: gpio, pins, rcc, clock

### Future Enhancements

- [ ] DMA support for large transfers
- [ ] Interrupt-driven operation
- [ ] 10-bit addressing support
- [ ] SMBus protocol support
- [ ] Multi-master support
- [ ] Clock stretching configuration
- [ ] Error recovery mechanisms

## References

- [I2C Specification v6](https://www.nxp.com/docs/en/user-guide/UM10204.pdf)
- [STM32H7 Reference Manual](https://www.st.com/resource/en/reference_manual/dm00176879.pdf) - Chapter 48: I2C
- [microzig I2C_Device](https://github.com/ZigEmbeddedGroup/microzig/blob/main/drivers/base/I2C_Device.zig)
- [libdaisy I2C](https://github.com/electro-smith/libDaisy/blob/master/src/per/i2c.h)
