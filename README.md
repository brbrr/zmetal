# zmetal — Daisy Seed library for Zig

A Zig library for the Electrosmith Daisy Seed (STM32H750IB), in the spirit of
libDaisy, built on [microzig](https://github.com/ZigEmbeddedGroup/microzig).
Examples live in `examples/` and are built by `zig build`.

## Build

```bash
zig build -Doptimize=safe                  # every example
zig build synth -Doptimize=safe            # one example
zig build synth -Doptimize=safe -Dmemory=sram   # SRAM image for the Daisy bootloader
zig build test                             # host unit tests (std-only modules)
zig build --help                           # all steps and options
```

Artifacts land in `zig-out/firmware/<example>.{elf,bin}`, and each build
prints a memory usage report. Use `-Doptimize=safe`: the synth example's
Debug build does not fit the 128 KB internal flash.

### Examples

| Example | What it shows |
|---|---|
| `synth` | Mono synth: keyboard + encoders (MCP23017), ILI9341 display, DIN/USB MIDI, SD card |
| `synth_usb_audio` | Same, with USB Audio (UAC2) routed through the codec |
| `usb_loopback` | USB CDC + MIDI echo device |
| `i2c` | AHT30 temperature/humidity sensor over I2C1 |

### Flashing

```bash
# Internal flash over SWD (default -Dmemory=flash)
openocd -f interface/stlink.cfg -f target/stm32h7x.cfg \
  -c "program zig-out/firmware/synth.elf verify reset exit"

# SRAM image via the Daisy bootloader (-Dmemory=sram)
dfu-util -a 0 -s 0x90040000:leave -D zig-out/firmware/synth.bin -d ,0483:df11
```

## Using the library

An application root imports `zmetal`. The HAL's early init and its interrupt
handlers (SysTick, faults, audio DMA/SAI, display SPI, MIDI UART, USB) are
installed automatically, so a minimal audio app is:

```zig
const microzig = @import("microzig");
const zmetal = @import("zmetal");

comptime {
    _ = microzig.export_startup();
}
pub const panic = microzig.panic;
pub const std_options = microzig.std_options(.{});

var seed: zmetal.Seed = .{}; // module scope: audio DMA keeps pointers into it

fn audio(in: []const f32, out: []f32) void {
    @memcpy(out, in); // interleaved stereo passthrough; `out` arrives zeroed
}

pub fn main() !void {
    try seed.init(.{}); // .audio = sample rate/bit depth/block size, .sdram, .qspi
    try seed.startAudio(audio); // or seed.startAudioCtx(&state, State.process)

    const button = zmetal.hal.Gpio.init(zmetal.pins.D7, .{ .mode = .input, .pull = .up });
    while (true) {
        seed.setLed(!button.read());
        zmetal.time.delayMs(1);
    }
}
```

What's in `zmetal`:

| | |
|---|---|
| `zmetal.Seed` | board: `init(config)`, `startAudio`/`startAudioCtx`, `setLed`/`toggleLed`, `cpuLoad` |
| `zmetal.pins` | header pin names `D0..D32`, `A0..A13`, `LED` |
| `zmetal.hal` | drivers: `Gpio`, `pin("PC7")`, `i2c`, `spi`, `usart`, `sdmmc`, `sdram`, `qspi`, `usb` (`init`/`initWithAudio`, identity), `clock.frequencies()` |
| `zmetal.time` | `nowMs`, `nowUs`, `delayMs`, `delayUs` |
| `zmetal.drivers` | ILI9341 display, MCP23017 I/O expander |
| `zmetal.hid` | MIDI parser/ports, `McpMatrixKeyboard`, `McpEncoders`, debounce |
| `zmetal.dsp` | oscillators, mono voice, `midiToFreq` (std-only, host-testable) |
| `zmetal.audio` | `AudioInterface(Program, .{ .usb })` patchbay |
| `zmetal.fat` | FatFs on the SD card (firmware built with `.fat = true`) |

New firmware is added to the `examples` table in `build.zig`, or built with
`addFirmware(b, ctx, .{ .name, .root_source_file, .usb, .fat, ... })`.

## Layout

```
src/zmetal.zig        public facade: hal, board, drivers, hid, dsp, audio, fat
src/hal/STM32H750/    HAL (injected as microzig's chip hal) + Daisy board init
src/drivers/          ILI9341 display, MCP23017 I/O expander
src/hid/              MIDI, encoders, keyboard matrix, debounce
src/dsp/              std-only DSP (zmetal_dsp module, host-testable)
src/audio/            audio interface / Program patchbay
src/ld/               flash.ld, sram.ld
examples/             example firmwares
lib/                  microzig, tinyusb, zfat submodules + C shims
```
