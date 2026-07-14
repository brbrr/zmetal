# Daisy Seed Dual-Mode Build System

The firmware can be built in two different modes depending on your development workflow.

## Build Modes

### Default: `zig build`

**Builds**: SRAM mode (same as `zig build sram`)
**Output**: `zig-out/firmware/blinky-sram.elf`
**Use for**: Production firmware with Daisy bootloader

### 1. SRAM Mode (Bootloader)

**Commands**: `zig build` or `zig build sram`
**Use for**: Production firmware, DFU flashing via USB
**Output**: `zig-out/firmware/blinky-sram.elf`

- Firmware runs from SRAM (0x24000000)
- Requires Daisy bootloader
- Flash to QSPI: `dfu-util -a 0 -s 0x90040000:leave -D blinky-sram.bin`
- Bootloader copies from QSPI → SRAM and executes

### 2. Flash Mode (Direct)

**Use for**: Development, debugging with SWD/JTAG
**Command**: `zig build flash`
**Output**: `zig-out/firmware/blinky-flash.elf`

- Firmware runs from internal flash (0x08000000)
- No bootloader required
- Flash via OpenOCD/ST-Link
- **WARNING**: Overwrites bootloader if flashed to 0x08000000!

## Quick Reference

```bash
# Build for bootloader (SRAM mode) - DEFAULT
zig build          # Builds SRAM mode, shows memory report
zig build sram     # Explicit SRAM mode (same as above)

# Build for direct flash
zig build flash    # Shows flash memory usage
```

## Memory Usage Report

After each build, you'll see a memory usage report similar to libdaisy:

```
=== Memory Usage Report: blinky-sram ===
Memory region      Used Size   Region Size   %age Used
----------------------------------------------------------
FLASH                    0 B        128 KB       0.00%
DTCMRAM                832 B        128 KB       0.63%
SRAM                   92 KB        480 KB      19.14%
RAM_D2_DMA             32 KB        192 KB      16.67%
RAM_D2                   0 B         96 KB       0.00%
RAM_D3                   0 B         64 KB       0.00%
BACKUP_SRAM              0 B          4 KB       0.00%
ITCMRAM                  0 B         64 KB       0.00%
SDRAM                    0 B      64.00 MB       0.00%
QSPIFLASH                0 B       7.75 MB       0.00%
----------------------------------------------------------
```

**Note**: The report shows where code executes from:

- SRAM mode: Code in SRAM, data in DTCMRAM
- Flash mode: Code in FLASH, data in DTCMRAM

**Implementation**: The memory regions are parsed directly from the linker script's `MEMORY` section, ensuring the report always matches the actual memory layout used by the linker.

## VS Code Tasks

### SRAM Mode (Bootloader)

- `build-sram` - Build firmware
- `create-bin-sram` - Build and create .bin file
- `program-sram-dfu` - Flash via DFU to QSPI (0x90040000)
- `program-sram-openocd` - Flash via debugger

### Flash Mode (Direct)

- `build-flash` - Build firmware
- `create-bin-flash` - Build and create .bin file
- `program-flash-dfu` - Flash via DFU to internal flash (⚠️ overwrites bootloader!)
- `program-flash-openocd` - Flash via debugger

## Memory Layout Comparison

### SRAM Mode (Bootloader)

```
Vector Table:  0x24000000 (SRAM)
Code:          0x24000298 (SRAM)
Data/BSS:      0x20000000 (DTCMRAM)
Storage:       0x90040000 (QSPI Flash)
```

### Flash Mode (Direct)

```
Vector Table:  0x08000000 (Internal Flash)
Code:          0x08000298 (Internal Flash)
Data/BSS:      0x20000000 (DTCMRAM)
```

## Linker Scripts

- **SRAM Mode**: `src/ld/sram.ld` - Vector table in SRAM
- **Flash Mode**: `src/ld/flash.ld` - Vector table in Flash

## Verification

Check which mode a binary is built for:

```bash
# Should show 0x24000000 for SRAM mode
llvm-objdump -h blinky-sram.elf | grep isr_vector

# Should show 0x08000000 for Flash mode
llvm-objdump -h blinky-flash.elf | grep isr_vector
```

## When to Use Each Mode

**SRAM Mode (Bootloader)**:

- ✅ Production/release builds
- ✅ Firmware updates via USB
- ✅ Maximum available flash space (QSPI ~8MB)
- ✅ Fast boot (already in RAM)

**Flash Mode (Direct)**:

- ✅ Development/debugging
- ✅ No bootloader dependency
- ✅ Direct debugging via SWD
- ⚠️ Limited to 128KB internal flash
- ⚠️ Overwrites bootloader if not careful
