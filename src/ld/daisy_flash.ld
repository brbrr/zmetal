/*
 * Linker script for STM32H750IB - Direct Flash Mode (No Bootloader)
 * 
 * This script is for firmware that runs directly from internal flash
 * after being programmed via SWD/JTAG debugger (e.g., OpenOCD, ST-Link).
 * 
 * Key differences from SRAM bootloader mode:
 * - Vector table at start of FLASH (0x08000000)
 * - Code executes from FLASH
 * - .data section loaded from FLASH to RAM at startup
 * - No bootloader dependency
 */

ENTRY(microzig_main)

/* Stack pointer at end of DTCMRAM */
_estack = 0x20020000;

MEMORY
{
	FLASH       (RX)  : ORIGIN = 0x08000000, LENGTH = 128K
	DTCMRAM     (RWX) : ORIGIN = 0x20000000, LENGTH = 128K
	SRAM        (RWX) : ORIGIN = 0x24000000, LENGTH = 480K
	RAM_D2_DMA  (RWX) : ORIGIN = 0x30000000, LENGTH = 192K
	RAM_D2      (RWX) : ORIGIN = 0x30031000, LENGTH = 96K
	RAM_D3      (RWX) : ORIGIN = 0x38000000, LENGTH = 64K
	BACKUP_SRAM (RWX) : ORIGIN = 0x38800000, LENGTH = 4K
	ITCMRAM     (RWX) : ORIGIN = 0x00000000, LENGTH = 64K
	SDRAM       (RWX) : ORIGIN = 0xc0000000, LENGTH = 64M
	QSPIFLASH   (RX)  : ORIGIN = 0x90000000, LENGTH = 8M
}

SECTIONS
{
	/* Vector table at start of FLASH */
	.isr_vector :
	{
		. = ALIGN(256);  /* ARM requires 256-byte alignment */
		KEEP(*(microzig_flash_start))
		KEEP(*(.isr_vector))
		. = ALIGN(4);
	} > FLASH

	/* Code section in FLASH */
	.text :
	{
		. = ALIGN(4);
		_stext = .;

		*(.text)
		*(.text*)
		*(.rodata)
		*(.rodata*)
		*(.glue_7)
		*(.glue_7t)
		KEEP(*(.init))
		KEEP(*(.fini))
		. = ALIGN(4);
		_etext = .;
	} > FLASH

	/* ARM exception handling */
	.ARM.extab :
	{
		. = ALIGN(4);
		*(.ARM.extab)
		*(.gnu.linkonce.armextab.*)
		. = ALIGN(4);
	} > FLASH

	.exidx :
	{
		. = ALIGN(4);
		PROVIDE(__exidx_start = .);
		*(.ARM.exidx*)
		. = ALIGN(4);
		PROVIDE(__exidx_end = .);
	} > FLASH

	.ARM.attributes 0 : { *(.ARM.attributes) }

	/* C++ init/fini arrays */
	.preinit_array :
	{
		PROVIDE_HIDDEN(__preinit_array_start = .);
		KEEP(*(.preinit_array*))
		PROVIDE_HIDDEN(__preinit_array_end = .);
	} > FLASH

	.init_array :
	{
		PROVIDE_HIDDEN(__init_array_start = .);
		KEEP(*(SORT(.init_array.*)))
		KEEP(*(.init_array*))
		PROVIDE_HIDDEN(__init_array_end = .);
	} > FLASH

	.fini_array :
	{
		PROVIDE_HIDDEN(__fini_array_start = .);
		KEEP(*(.fini_array*))
		KEEP(*(SORT(.fini_array.*)))
		PROVIDE_HIDDEN(__fini_array_end = .);
	} > FLASH

	/* DMA-capable RAM section */
	.sram1_bss (NOLOAD) :
	{
		. = ALIGN(4);
		_ssram1_bss = .;

		PROVIDE(__sram1_bss_start__ = _sram1_bss);
		*(.sram1_bss)
		*(.sram1_bss*)
		. = ALIGN(4);
		_esram1_bss = .;

		PROVIDE(__sram1_bss_end__ = _esram1_bss);
	} > RAM_D2_DMA

	/* AXI-SRAM (D1). Reachable by D1-domain DMA masters such as the SDMMC1
	 * IDMA (which cannot reach the D2 RAM_D2_DMA region). Cacheable via the
	 * default MPU map, so users must do cache maintenance around DMA. */
	.axi_sram (NOLOAD) :
	{
		. = ALIGN(32);
		*(.axi_sram)
		*(.axi_sram*)
		. = ALIGN(32);
	} > SRAM

	/* Initialized data - loaded from FLASH to DTCMRAM at startup */
	.data :
	{
		. = ALIGN(4);
		_sdata = .;
		microzig_data_start = .;

		PROVIDE(__data_start__ = _sdata);
		*(.data)
		*(.data*)
		. = ALIGN(4);
		_edata = .;
		microzig_data_end = .;

		PROVIDE(__data_end__ = _edata);
	} > DTCMRAM AT > FLASH

	_sidata = LOADADDR(.data);
	microzig_data_load_start = LOADADDR(.data);

	/* Uninitialized data in DTCMRAM */
	.bss (NOLOAD) :
	{
		. = ALIGN(4);
		_sbss = .;
		microzig_bss_start = .;

		PROVIDE(__bss_start__ = _sbss);
		*(.bss)
		*(.bss*)
		*(COMMON)
		. = ALIGN(4);
		_ebss = .;
		microzig_bss_end = .;

		PROVIDE(__bss_end__ = _ebss);
	} > DTCMRAM

	.dtcmram_bss (NOLOAD) :
	{
		. = ALIGN(4);
		_sdtcmram_bss = .;

		PROVIDE(__dtcmram_bss_start__ = _sdtcmram_bss);
		*(.dtcmram_bss)
		*(.dtcmram_bss*)
		. = ALIGN(4);
		_edtcmram_bss = .;

		PROVIDE(__dtcmram_bss_end__ = _edtcmram_bss);
	} > DTCMRAM

	/* SDRAM sections */
	.sdram_bss (NOLOAD) :
	{
		. = ALIGN(4);
		_ssdram_bss = .;

		PROVIDE(__sdram_bss_start = _ssdram_bss);
		*(.sdram_bss)
		*(.sdram_bss*)
		. = ALIGN(4);
		_esdram_bss = .;

		PROVIDE(__sdram_bss_end = _esdram_bss);
	} > SDRAM

	/* Backup SRAM */
	.backup_sram (NOLOAD) :
	{
		. = ALIGN(4);
		_sbackup_sram = .;

		PROVIDE(__backup_sram_start = _sbackup_sram);
		*(.backup_sram)
		*(.backup_sram*)
		. = ALIGN(4);
		_ebackup_sram = .;

		PROVIDE(__backup_sram_end = _ebackup_sram);
	} > BACKUP_SRAM

	/* QSPI Flash sections */
	.qspiflash_text :
	{
		. = ALIGN(4);
		_sqspiflash_text = .;

		PROVIDE(__qspiflash_text_start = _sqspiflash_text);
		*(.qspiflash_text)
		*(.qspiflash_text*)
		. = ALIGN(4);
		_eqspiflash_text = .;

		PROVIDE(__qspiflash_text_end = _eqspiflash_text);
	} > QSPIFLASH

	.qspiflash_data :
	{
		. = ALIGN(4);
		_sqspiflash_data = .;

		PROVIDE(__qspiflash_data_start = _sqspiflash_data);
		*(.qspiflash_data)
		*(.qspiflash_data*)
		. = ALIGN(4);
		_eqspiflash_data = .;

		PROVIDE(__qspiflash_data_end = _eqspiflash_data);
	} > QSPIFLASH

	.qspiflash_bss (NOLOAD) :
	{
		. = ALIGN(4);
		_sqspiflash_bss = .;

		PROVIDE(__qspiflash_bss_start = _sqspiflash_bss);
		*(.qspiflash_bss)
		*(.qspiflash_bss*)
		. = ALIGN(4);
		_eqspiflash_bss = .;

		PROVIDE(__qspiflash_bss_end = _eqspiflash_bss);
	} > QSPIFLASH

	/* Heap in RAM_D2 */
	.heap (NOLOAD) :
	{
		. = ALIGN(4);
		PROVIDE(__heap_start__ = .);
		PROVIDE(__heap_start = .);
		PROVIDE(microzig_heap_start = .);
		KEEP(*(.heap))
		. = ALIGN(4);
		PROVIDE(__heap_end = .);
		PROVIDE(__heap_end__ = .);
		PROVIDE(microzig_heap_end = .);
	} > RAM_D2

	PROVIDE(end = .);

	/* Reserved for stack in DTCMRAM */
	.reserved_for_stack (NOLOAD) :
	{
		. = ALIGN(4);
		PROVIDE(__reserved_for_stack_start__ = .);
		KEEP(*(.reserved_for_stack))
		. = ALIGN(4);
		PROVIDE(__reserved_for_stack_end__ = .);
	} > DTCMRAM

    /* Discard standard library to save space */
    /DISCARD/ :
    {
        libc.a ( * )
        libm.a ( * )
        libgcc.a ( * )
    }
}
