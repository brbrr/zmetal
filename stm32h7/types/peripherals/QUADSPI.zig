const mmio = @import("mmio");
const types = @import("../../types.zig");

/// QUADSPI
pub const QUADSPI = extern struct {
    /// QUADSPI control register
    /// offset: 0x00
    QUADSPI_CR: mmio.Mmio(packed struct(u32) {
        /// Enable Enable the QUADSPI.
        EN: u1,
        /// Abort request This bit aborts the on-going command sequence. It is automatically reset once the abort is complete. This bit stops the current transfer. In polling mode or memory-mapped mode, this bit also reset the APM bit or the DM bit.
        ABORT: u1,
        /// DMA enable In indirect mode, DMA can be used to input or output data via the QUADSPI_DR register. DMA transfers are initiated when the FIFO threshold flag, FTF, is set.
        DMAEN: u1,
        /// Timeout counter enable This bit is valid only when memory-mapped mode (FMODE = 11) is selected. Activating this bit causes the chip select (nCS) to be released (and thus reduces consumption) if there has not been an access after a certain amount of time, where this time is defined by TIMEOUT[15:0] (QUADSPI_LPTR). Enable the timeout counter. By default, the QUADSPI never stops its prefetch operation, keeping the previous read operation active with nCS maintained low, even if no access to the Flash memory occurs for a long time. Since Flash memories tend to consume more when nCS is held low, the application might want to activate the timeout counter (TCEN = 1, QUADSPI_CR[3]) so that nCS is released after a period of TIMEOUT[15:0] (QUADSPI_LPTR) cycles have elapsed without an access since when the FIFO becomes full with prefetch data. This bit can be modified only when BUSY = 0.
        TCEN: u1,
        /// Sample shift By default, the QUADSPI samples data 1/2 of a CLK cycle after the data is driven by the Flash memory. This bit allows the data is to be sampled later in order to account for external signal delays. Firmware must assure that SSHIFT = 0 when in DDR mode (when DDRM = 1). This field can be modified only when BUSY = 0.
        SSHIFT: u1,
        reserved6: u1 = 0,
        /// Dual-flash mode This bit activates dual-flash mode, where two external Flash memories are used simultaneously to double throughput and capacity. This bit can be modified only when BUSY = 0.
        DFM: u1,
        /// Flash memory selection This bit selects the Flash memory to be addressed in single flash mode (when DFM = 0). This bit can be modified only when BUSY = 0. This bit is ignored when DFM = 1.
        FSEL: u1,
        /// FIFO threshold level Defines, in indirect mode, the threshold number of bytes in the FIFO that will cause the FIFO threshold flag (FTF, QUADSPI_SR[2]) to be set. In indirect write mode (FMODE = 00): ... In indirect read mode (FMODE = 01): ... If DMAEN = 1, then the DMA controller for the corresponding channel must be disabled before changing the FTHRES value.
        FTHRES: u5,
        reserved16: u3 = 0,
        /// Transfer error interrupt enable This bit enables the transfer error interrupt.
        TEIE: u1,
        /// Transfer complete interrupt enable This bit enables the transfer complete interrupt.
        TCIE: u1,
        /// FIFO threshold interrupt enable This bit enables the FIFO threshold interrupt.
        FTIE: u1,
        /// Status match interrupt enable This bit enables the status match interrupt.
        SMIE: u1,
        /// TimeOut interrupt enable This bit enables the TimeOut interrupt.
        TOIE: u1,
        reserved22: u1 = 0,
        /// Automatic poll mode stop This bit determines if automatic polling is stopped after a match. This bit can be modified only when BUSY = 0.
        APMS: u1,
        /// Polling match mode This bit indicates which method should be used for determining a match during automatic polling mode. This bit can be modified only when BUSY = 0.
        PMM: u1,
        /// clock prescaler
        PRESCALER: u8,
    }),
    /// QUADSPI device configuration register
    /// offset: 0x04
    QUADSPI_DCR: mmio.Mmio(packed struct(u32) {
        /// indicates the level that clk takes between command
        CKMODE: u1,
        reserved8: u7 = 0,
        /// Chip select high time CSHT+1 defines the minimum number of CLK cycles which the chip select (nCS) must remain high between commands issued to the Flash memory. ... This field can be modified only when BUSY = 0.
        CSHT: u3,
        reserved16: u5 = 0,
        /// Flash memory size This field defines the size of external memory using the following formula: Number of bytes in Flash memory = 2[FSIZE+1] FSIZE+1 is effectively the number of address bits required to address the Flash memory. The Flash memory capacity can be up to 4GB (addressed using 32 bits) in indirect mode, but the addressable space in memory-mapped mode is limited to 256MB. If DFM = 1, FSIZE indicates the total capacity of the two Flash memories together. This field can be modified only when BUSY = 0.
        FSIZE: u5,
        padding: u11 = 0,
    }),
    /// QUADSPI status register
    /// offset: 0x08
    QUADSPI_SR: mmio.Mmio(packed struct(u32) {
        /// Transfer error flag This bit is set in indirect mode when an invalid address is being accessed in indirect mode. It is cleared by writing 1 to CTEF.
        TEF: u1,
        /// Transfer complete flag This bit is set in indirect mode when the programmed number of data has been transferred or in any mode when the transfer has been aborted.It is cleared by writing 1 to CTCF.
        TCF: u1,
        /// FIFO threshold flag In indirect mode, this bit is set when the FIFO threshold has been reached, or if there is any data left in the FIFO after reads from the Flash memory are complete. It is cleared automatically as soon as threshold condition is no longer true. In automatic polling mode this bit is set every time the status register is read, and the bit is cleared when the data register is read.
        FTF: u1,
        /// Status match flag This bit is set in automatic polling mode when the unmasked received data matches the corresponding bits in the match register (QUADSPI_PSMAR). It is cleared by writing 1 to CSMF.
        SMF: u1,
        /// Timeout flag This bit is set when timeout occurs. It is cleared by writing 1 to CTOF.
        TOF: u1,
        /// Busy This bit is set when an operation is on going. This bit clears automatically when the operation with the Flash memory is finished and the FIFO is empty.
        BUSY: u1,
        reserved8: u2 = 0,
        /// FIFO level This field gives the number of valid bytes which are being held in the FIFO. FLEVEL = 0 when the FIFO is empty, and 16 when it is full. In memory-mapped mode and in automatic status polling mode, FLEVEL is zero.
        FLEVEL: u6,
        padding: u18 = 0,
    }),
    /// QUADSPI flag clear register
    /// offset: 0x0c
    QUADSPI_FCR: mmio.Mmio(packed struct(u32) {
        /// Clear transfer error flag Writing 1 clears the TEF flag in the QUADSPI_SR register
        CTEF: u1,
        /// Clear transfer complete flag Writing 1 clears the TCF flag in the QUADSPI_SR register
        CTCF: u1,
        reserved3: u1 = 0,
        /// Clear status match flag Writing 1 clears the SMF flag in the QUADSPI_SR register
        CSMF: u1,
        /// Clear timeout flag Writing 1 clears the TOF flag in the QUADSPI_SR register
        CTOF: u1,
        padding: u27 = 0,
    }),
    /// QUADSPI data length register
    /// offset: 0x10
    QUADSPI_DLR: mmio.Mmio(packed struct(u32) {
        /// Data length Number of data to be retrieved (value+1) in indirect and status-polling modes. A value no greater than 3 (indicating 4 bytes) should be used for status-polling mode. All 1s in indirect mode means undefined length, where QUADSPI will continue until the end of memory, as defined by FSIZE. 0x0000_0000: 1 byte is to be transferred 0x0000_0001: 2 bytes are to be transferred 0x0000_0002: 3 bytes are to be transferred 0x0000_0003: 4 bytes are to be transferred ... 0xFFFF_FFFD: 4,294,967,294 (4G-2) bytes are to be transferred 0xFFFF_FFFE: 4,294,967,295 (4G-1) bytes are to be transferred 0xFFFF_FFFF: undefined length -- all bytes until the end of Flash memory (as defined by FSIZE) are to be transferred. Continue reading indefinitely if FSIZE = 0x1F. DL[0] is stuck at 1 in dual-flash mode (DFM = 1) even when 0 is written to this bit, thus assuring that each access transfers an even number of bytes. This field has no effect when in memory-mapped mode (FMODE = 10). This field can be written only when BUSY = 0.
        DL: u32,
    }),
    /// QUADSPI communication configuration register
    /// offset: 0x14
    QUADSPI_CCR: mmio.Mmio(packed struct(u32) {
        /// Instruction Instruction to be send to the external SPI device. This field can be written only when BUSY = 0.
        INSTRUCTION: u8,
        /// Instruction mode This field defines the instruction phase mode of operation: This field can be written only when BUSY = 0.
        IMODE: u2,
        /// Address mode This field defines the address phase mode of operation: This field can be written only when BUSY = 0.
        ADMODE: u2,
        /// Address size This bit defines address size: This field can be written only when BUSY = 0.
        ADSIZE: u2,
        /// Alternate bytes mode This field defines the alternate-bytes phase mode of operation: This field can be written only when BUSY = 0.
        ABMODE: u2,
        /// Alternate bytes size This bit defines alternate bytes size: This field can be written only when BUSY = 0.
        ABSIZE: u2,
        /// Number of dummy cycles This field defines the duration of the dummy phase. In both SDR and DDR modes, it specifies a number of CLK cycles (0-31). This field can be written only when BUSY = 0.
        DCYC: u5,
        reserved24: u1 = 0,
        /// Data mode This field defines the data phases mode of operation: This field also determines the dummy phase mode of operation. This field can be written only when BUSY = 0.
        DMODE: u2,
        /// Functional mode This field defines the QUADSPI functional mode of operation. If DMAEN = 1 already, then the DMA controller for the corresponding channel must be disabled before changing the FMODE value. This field can be written only when BUSY = 0.
        FMODE: u2,
        /// Send instruction only once mode See Section15.3.11: Sending the instruction only once on page13. This bit has no effect when IMODE = 00. This field can be written only when BUSY = 0.
        SIOO: u1,
        reserved30: u1 = 0,
        /// DDR hold Delay the data output by 1/4 of the QUADSPI output clock cycle in DDR mode: This feature is only active in DDR mode. This field can be written only when BUSY = 0.
        DHHC: u1,
        /// Double data rate mode This bit sets the DDR mode for the address, alternate byte and data phase: This field can be written only when BUSY = 0.
        DDRM: u1,
    }),
    /// QUADSPI address register
    /// offset: 0x18
    QUADSPI_AR: mmio.Mmio(packed struct(u32) {
        /// [31 0]: Address Address to be send to the external Flash memory Writes to this field are ignored when BUSY = 0 or when FMODE = 11 (memory-mapped mode). In dual flash mode, ADDRESS[0] is automatically stuck to 0 as the address should always be even
        ADDRESS: u32,
    }),
    /// QUADSPI alternate bytes registers
    /// offset: 0x1c
    QUADSPI_ABR: mmio.Mmio(packed struct(u32) {
        /// Alternate Bytes Optional data to be send to the external SPI device right after the address. This field can be written only when BUSY = 0.
        ALTERNATE: u32,
    }),
    /// QUADSPI data register
    /// offset: 0x20
    QUADSPI_DR: mmio.Mmio(packed struct(u32) {
        /// Data Data to be sent/received to/from the external SPI device. In indirect write mode, data written to this register is stored on the FIFO before it is sent to the Flash memory during the data phase. If the FIFO is too full, a write operation is stalled until the FIFO has enough space to accept the amount of data being written. In indirect read mode, reading this register gives (via the FIFO) the data which was received from the Flash memory. If the FIFO does not have as many bytes as requested by the read operation and if BUSY=1, the read operation is stalled until enough data is present or until the transfer is complete, whichever happens first. In automatic polling mode, this register contains the last data read from the Flash memory (without masking). Word, halfword, and byte accesses to this register are supported. In indirect write mode, a byte write adds 1 byte to the FIFO, a halfword write 2, and a word write 4. Similarly, in indirect read mode, a byte read removes 1 byte from the FIFO, a halfword read 2, and a word read 4. Accesses in indirect mode must be aligned to the bottom of this register: a byte read must read DATA[7:0] and a halfword read must read DATA[15:0].
        DATA: u32,
    }),
    /// QUADSPI polling status mask register
    /// offset: 0x24
    QUADSPI_PSMKR: mmio.Mmio(packed struct(u32) {
        /// Status mask Mask to be applied to the status bytes received in polling mode. For bit n: This field can be written only when BUSY = 0.
        MASK: u32,
    }),
    /// QUADSPI polling status match register
    /// offset: 0x28
    QUADSPI_PSMAR: mmio.Mmio(packed struct(u32) {
        /// Status match Value to be compared with the masked status register to get a match. This field can be written only when BUSY = 0.
        MATCH: u32,
    }),
    /// QUADSPI polling interval register
    /// offset: 0x2c
    QUADSPI_PIR: mmio.Mmio(packed struct(u32) {
        /// Polling interval Number of CLK cycles between to read during automatic polling phases. This field can be written only when BUSY = 0.
        INTERVAL: u16,
        padding: u16 = 0,
    }),
    /// QUADSPI low-power timeout register
    /// offset: 0x30
    QUADSPI_LPTR: mmio.Mmio(packed struct(u32) {
        /// Timeout period After each access in memory-mapped mode, the QUADSPI prefetches the subsequent bytes and holds these bytes in the FIFO. This field indicates how many CLK cycles the QUADSPI waits after the FIFO becomes full until it raises nCS, putting the Flash memory in a lower-consumption state. This field can be written only when BUSY = 0.
        TIMEOUT: u16,
        padding: u16 = 0,
    }),
};
