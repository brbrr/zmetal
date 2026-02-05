#!/usr/bin/env python3
"""
Memory usage report for Daisy Seed firmware
Parses ELF sections and displays memory usage by region
Memory regions are parsed from the linker script's MEMORY section
"""

import sys
import subprocess
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

def get_section_info(elf_file: str) -> List[Tuple[str, int, int]]:
    """Get section name, size, and VMA from ELF file"""
    result = subprocess.run(
        ['llvm-objdump', '-h', elf_file],
        capture_output=True,
        text=True
    )
    
    sections = []
    for line in result.stdout.splitlines():
        # Parse: Idx Name Size VMA LMA Type
        match = re.match(r'\s+\d+\s+(\.[\w.]+)\s+([0-9a-f]+)\s+([0-9a-f]+)\s+([0-9a-f]+)\s+(\w+)', line)
        if match:
            name = match.group(1)
            size = int(match.group(2), 16)
            vma = int(match.group(3), 16)
            type_flags = match.group(5)
            
            # Only count allocated sections (DATA, TEXT, BSS)
            if type_flags in ('DATA', 'TEXT', 'BSS') and size > 0:
                sections.append((name, size, vma))
    
    return sections

def calculate_usage(sections: List[Tuple[str, int, int]], memory_regions: List[Tuple[str, int, int]]) -> Dict[str, int]:
    """Calculate memory usage per region"""
    usage = {name: 0 for name, _, _ in memory_regions}
    
    for section_name, size, vma in sections:
        # Map section VMA to memory region
        for region_name, region_start, region_size in memory_regions:
            region_end = region_start + region_size
            if region_start <= vma < region_end:
                usage[region_name] += size
                break
    
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
        sections = get_section_info(elf_file)
        usage = calculate_usage(sections, memory_regions)
        print_report(usage, memory_regions, target_name)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
