#!/usr/bin/env python3
"""
Memory usage report for Daisy Seed firmware
Parses ELF program headers and displays memory usage by region
Memory regions are parsed from the linker script's MEMORY section

The ELF is decoded directly rather than by scraping `llvm-objdump -h`: Zig
emits section names containing spaces and parentheses for generic
instantiations (e.g. `.text.drivers.ili9341.ILI9341_DMA(.{ ... })`), which
makes the columnar output impossible to split reliably.
"""

import sys
import struct
import re
from typing import Dict, List, Tuple

def parse_size(size_str: str) -> int:
    """Parse size string like '128K' or '64M' into bytes"""
    size_str = size_str.strip().upper()
    if size_str.endswith('M'):
        return int(size_str[:-1]) * 1024 * 1024
    elif size_str.endswith('K'):
        return int(size_str[:-1]) * 1024
    else:
        return int(size_str, 0)  # Handle hex or decimal

def parse_memory_regions(linker_script: str) -> List[Tuple[str, int, int]]:
    """
    Parse MEMORY section from linker script
    Returns list of (name, origin, length) tuples
    """
    with open(linker_script, 'r') as f:
        content = f.read()
    
    # Find MEMORY { ... } block
    memory_match = re.search(r'MEMORY\s*\{([^}]+)\}', content, re.DOTALL)
    if not memory_match:
        raise ValueError(f"No MEMORY section found in {linker_script}")
    
    memory_block = memory_match.group(1)
    regions = []
    
    # Parse each region: REGION_NAME (FLAGS) : ORIGIN = 0xADDR, LENGTH = SIZE
    pattern = r'(\w+)\s*\([^)]+\)\s*:\s*ORIGIN\s*=\s*(0x[0-9a-fA-F]+)\s*,\s*LENGTH\s*=\s*(\w+)'
    for match in re.finditer(pattern, memory_block):
        name = match.group(1)
        origin = int(match.group(2), 16)
        length = parse_size(match.group(3))
        regions.append((name, origin, length))
    
    if not regions:
        raise ValueError(f"No memory regions parsed from {linker_script}")
    
    return regions

def parse_load_segments(elf_file: str) -> List[Tuple[int, int, int, int]]:
    """
    Read PT_LOAD program headers from a 32-bit little-endian ARM ELF.
    Returns list of (vaddr, paddr, filesz, memsz) tuples.
    """
    with open(elf_file, 'rb') as f:
        data = f.read()

    if data[:4] != b'\x7fELF':
        raise ValueError(f"{elf_file} is not an ELF file")
    if data[4] != 1 or data[5] != 1:
        raise ValueError(f"{elf_file} is not 32-bit little-endian ELF")

    # Elf32_Ehdr: e_phoff at 0x1c, e_phentsize at 0x2a, e_phnum at 0x2c
    e_phoff, = struct.unpack_from('<I', data, 0x1c)
    e_phentsize, e_phnum = struct.unpack_from('<HH', data, 0x2a)

    PT_LOAD = 1
    segments = []
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        # Elf32_Phdr: type, offset, vaddr, paddr, filesz, memsz, flags, align
        p_type, _, p_vaddr, p_paddr, p_filesz, p_memsz, _, _ = \
            struct.unpack_from('<8I', data, off)
        if p_type == PT_LOAD and p_memsz > 0:
            segments.append((p_vaddr, p_paddr, p_filesz, p_memsz))

    if not segments:
        raise ValueError(f"No PT_LOAD segments found in {elf_file}")

    return segments


def find_region(addr: int, memory_regions: List[Tuple[str, int, int]]):
    """Return the name of the region containing addr, or None"""
    for region_name, region_start, region_size in memory_regions:
        if region_start <= addr < region_start + region_size:
            return region_name
    return None


def calculate_usage(segments: List[Tuple[int, int, int, int]],
                    memory_regions: List[Tuple[str, int, int]]) -> Dict[str, int]:
    """
    Calculate memory usage per region.

    Each segment occupies `memsz` bytes at its run-time address (vaddr). When
    it is loaded from somewhere else -- .data lives in RAM but its initialiser
    image is stored in flash -- the `filesz` bytes at the load address (paddr)
    are charged to that region too.
    """
    usage = {name: 0 for name, _, _ in memory_regions}

    for vaddr, paddr, filesz, memsz in segments:
        run_region = find_region(vaddr, memory_regions)
        if run_region is not None:
            usage[run_region] += memsz

        load_region = find_region(paddr, memory_regions)
        if load_region is not None and load_region != run_region:
            usage[load_region] += filesz

    return usage


def print_report(usage: Dict[str, int], memory_regions: List[Tuple[str, int, int]], target_name: str):
    """Print memory usage report"""
    print(f"\n=== Memory Usage Report: {target_name} ===")
    print(f"{'Memory region':<16}{'Used Size':>12}  {'Region Size':>12}  {'%age Used':>10}")
    print("-" * 58)
    
    for region_name, region_start, region_size in memory_regions:
        used = usage[region_name]
        if region_size >= 1024 * 1024:
            size_str = f"{region_size / (1024*1024):.2f} MB"
        elif region_size >= 1024:
            size_str = f"{region_size / 1024:>6.0f} KB"
        else:
            size_str = f"{region_size:>8} B"
        
        if used >= 1024:
            used_str = f"{used / 1024:>6.0f} KB"
        else:
            used_str = f"{used:>8} B"
        
        percentage = (used / region_size * 100) if region_size > 0 else 0
        print(f"{region_name:<16}{used_str:>12}  {size_str:>12}  {percentage:>9.2f}%")
    
    print("-" * 58)

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: memory_report.py <elf_file> <target_name> <linker_script>")
        sys.exit(1)
    
    elf_file = sys.argv[1]
    target_name = sys.argv[2]
    linker_script = sys.argv[3]
    
    try:
        memory_regions = parse_memory_regions(linker_script)
        segments = parse_load_segments(elf_file)
        usage = calculate_usage(segments, memory_regions)
        print_report(usage, memory_regions, target_name)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
