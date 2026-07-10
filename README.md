# ZMetal - Daisy Seed Firmware

Zig-based firmware for Daisy Seed (STM32H750IB).

## Quick Start

```bash
# Build for bootloader (default)
zig build

# Output shows memory usage:
# === Memory Usage Report: blinky-sram ===
# Memory region       Used Size  Region Size  %age Used
# ----------------------------------------------------------
# FLASH                   0 B       128 KB    0.00%
# DTCMRAM               832 B       128 KB    0.63%
# SRAM                  92 KB       480 KB   19.14%
# ...

# Flash via USB DFU
dfu-util -a 0 -s 0x90040000:leave -D zig-out/firmware/blinky-sram.bin -d ,0483:df11


// INTERNAL_ADDRESS = 0x08000000
// FLASH_ADDRESS ?= $(INTERNAL_ADDRESS)
// dfu-util -a 0 -s 0x08000000:leave -D zig-out/firmware/blinky.bin -d ,0483:df11
// openocd -s /usr/local/share/openocd/scripts -f interface/stlink.cfg -f target/stm32h7x.cfg -c "program ./zig-out/firmware/blinky.elf verify reset exit"

```

## Build Commands

```bash
zig build          # Default: SRAM mode (bootloader)
zig build sram     # Explicit SRAM mode
zig build flash    # Flash mode (direct, no bootloader)
zig build --help   # Show all options
```

## Documentation

- **[BUILD_MODES.md](docs/BUILD_MODES.md)** - Detailed guide on SRAM vs Flash modes

## Tasks

- Build tasks: `build-sram`, `build-flash`
- Flash tasks: `program-sram-dfu`, `program-flash-openocd`, etc.

## Architecture

- **Chip**: STM32H750IB (Cortex-M7 @ 480MHz)
- **Bootloader**: Daisy closed-source bootloader in internal flash
- **Code execution**: SRAM (0x24000000) - copied from QSPI by bootloader
- **Storage**: QSPI Flash (0x90040000) - firmware lives here

## Features

- ✅ Dual-mode build system (SRAM/Flash)
- ✅ Automatic memory usage reporting after build
- ✅ Compatible with Daisy bootloader
- ✅ Direct SWD/JTAG debugging support

See `docs/BUILD_MODES.md` for full memory layout details.
