/*
 * The panel scanner's sections. microzig generates the MEMORY block above
 * this from `scanner_memory` in build.zig: BANK_1 is the C031's 32 KB of
 * flash less its last 8 bytes (the trial vector), SRAM its 12 KB.
 *
 * The same layout as microzig's generated sections, with three changes:
 * the vector table is the scanner's own (`.vectors`, scanner/hal/start.zig),
 * there is no heap, and the stack's room is checked.
 */

ENTRY(_start)

/* The initial stack pointer: the end of SRAM. The vector table's first word
 * and the reset path's first instruction both take it from here. */
_estack = ORIGIN(SRAM) + LENGTH(SRAM);

SECTIONS
{
  .vectors :
  {
    KEEP(*(.vectors))
  } > BANK_1

  .text :
  {
    *(.text*)
    *(.srodata*)
    *(.rodata*)
  } > BANK_1

  .ARM.extab : {
    *(.ARM.extab* .gnu.linkonce.armextab.*)
  } > BANK_1

  .ARM.exidx : {
    *(.ARM.exidx* .gnu.linkonce.armexidx.*)
  } > BANK_1

  /* Copied from flash by the reset path. `.ram_text` is microzig's section
   * for code that runs from RAM: scanner/hal/uncommit.zig puts the page-0
   * erase there, so nothing runs from flash while flash is erased. */
  .data :
  {
    . = ALIGN(4);
    microzig_data_start = .;
    *(.sdata*)
    *(.data*)
    KEEP(*(.ram_text))
    . = ALIGN(4);
    microzig_data_end = .;
  } > SRAM AT> BANK_1

  .bss (NOLOAD) :
  {
    . = ALIGN(4);
    microzig_bss_start = .;
    *(.sbss*)
    *(.bss*)
    *(COMMON)
    . = ALIGN(4);
    microzig_bss_end = .;
  } > SRAM

  microzig_data_load_start = LOADADDR(.data);
}

ASSERT(ADDR(.vectors) == ORIGIN(BANK_1), "scanner: the vector table must start the image")
ASSERT(microzig_bss_end + 2048 <= _estack, "scanner: less than 2 KB of RAM is left for the stack")
