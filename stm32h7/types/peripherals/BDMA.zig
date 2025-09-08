const mmio = @import("mmio");
const types = @import("../../types.zig");

/// BDMA
pub const BDMA = extern struct {
    /// DMA interrupt status register
    /// offset: 0x00
    BDMA_ISR: mmio.Mmio(packed struct(u32) {
        /// Channel x global interrupt flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        GIF1: u1,
        /// Channel x transfer complete flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        TCIF1: u1,
        /// Channel x half transfer flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        HTIF1: u1,
        /// Channel x transfer error flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        TEIF1: u1,
        /// Channel x global interrupt flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        GIF2: u1,
        /// Channel x transfer complete flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        TCIF2: u1,
        /// Channel x half transfer flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        HTIF2: u1,
        /// Channel x transfer error flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        TEIF2: u1,
        /// Channel x global interrupt flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        GIF3: u1,
        /// Channel x transfer complete flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        TCIF3: u1,
        /// Channel x half transfer flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        HTIF3: u1,
        /// Channel x transfer error flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        TEIF3: u1,
        /// Channel x global interrupt flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        GIF4: u1,
        /// Channel x transfer complete flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        TCIF4: u1,
        /// Channel x half transfer flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        HTIF4: u1,
        /// Channel x transfer error flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        TEIF4: u1,
        /// Channel x global interrupt flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        GIF5: u1,
        /// Channel x transfer complete flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        TCIF5: u1,
        /// Channel x half transfer flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        HTIF5: u1,
        /// Channel x transfer error flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        TEIF5: u1,
        /// Channel x global interrupt flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        GIF6: u1,
        /// Channel x transfer complete flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        TCIF6: u1,
        /// Channel x half transfer flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        HTIF6: u1,
        /// Channel x transfer error flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        TEIF6: u1,
        /// Channel x global interrupt flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        GIF7: u1,
        /// Channel x transfer complete flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        TCIF7: u1,
        /// Channel x half transfer flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        HTIF7: u1,
        /// Channel x transfer error flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        TEIF7: u1,
        /// Channel x global interrupt flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        GIF8: u1,
        /// Channel x transfer complete flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        TCIF8: u1,
        /// Channel x half transfer flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        HTIF8: u1,
        /// Channel x transfer error flag (x = 1..8) This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCR register.
        TEIF8: u1,
    }),
    /// DMA interrupt flag clear register
    /// offset: 0x04
    BDMA_IFCR: mmio.Mmio(packed struct(u32) {
        /// Channel x global interrupt clear This bit is set and cleared by software.
        CGIF1: u1,
        /// Channel x transfer complete clear This bit is set and cleared by software.
        CTCIF1: u1,
        /// Channel x half transfer clear This bit is set and cleared by software.
        CHTIF1: u1,
        /// Channel x transfer error clear This bit is set and cleared by software.
        CTEIF1: u1,
        /// Channel x global interrupt clear This bit is set and cleared by software.
        CGIF2: u1,
        /// Channel x transfer complete clear This bit is set and cleared by software.
        CTCIF2: u1,
        /// Channel x half transfer clear This bit is set and cleared by software.
        CHTIF2: u1,
        /// Channel x transfer error clear This bit is set and cleared by software.
        CTEIF2: u1,
        /// Channel x global interrupt clear This bit is set and cleared by software.
        CGIF3: u1,
        /// Channel x transfer complete clear This bit is set and cleared by software.
        CTCIF3: u1,
        /// Channel x half transfer clear This bit is set and cleared by software.
        CHTIF3: u1,
        /// Channel x transfer error clear This bit is set and cleared by software.
        CTEIF3: u1,
        /// Channel x global interrupt clear This bit is set and cleared by software.
        CGIF4: u1,
        /// Channel x transfer complete clear This bit is set and cleared by software.
        CTCIF4: u1,
        /// Channel x half transfer clear This bit is set and cleared by software.
        CHTIF4: u1,
        /// Channel x transfer error clear This bit is set and cleared by software.
        CTEIF4: u1,
        /// Channel x global interrupt clear This bit is set and cleared by software.
        CGIF5: u1,
        /// Channel x transfer complete clear This bit is set and cleared by software.
        CTCIF5: u1,
        /// Channel x half transfer clear This bit is set and cleared by software.
        CHTIF5: u1,
        /// Channel x transfer error clear This bit is set and cleared by software.
        CTEIF5: u1,
        /// Channel x global interrupt clear This bit is set and cleared by software.
        CGIF6: u1,
        /// Channel x transfer complete clear This bit is set and cleared by software.
        CTCIF6: u1,
        /// Channel x half transfer clear This bit is set and cleared by software.
        CHTIF6: u1,
        /// Channel x transfer error clear This bit is set and cleared by software.
        CTEIF6: u1,
        /// Channel x global interrupt clear This bit is set and cleared by software.
        CGIF7: u1,
        /// Channel x transfer complete clear This bit is set and cleared by software.
        CTCIF7: u1,
        /// Channel x half transfer clear This bit is set and cleared by software.
        CHTIF7: u1,
        /// Channel x transfer error clear This bit is set and cleared by software.
        CTEIF7: u1,
        /// Channel x global interrupt clear This bit is set and cleared by software.
        CGIF8: u1,
        /// Channel x transfer complete clear This bit is set and cleared by software.
        CTCIF8: u1,
        /// Channel x half transfer clear This bit is set and cleared by software.
        CHTIF8: u1,
        /// Channel x transfer error clear This bit is set and cleared by software.
        CTEIF8: u1,
    }),
    /// DMA channel x configuration register
    /// offset: 0x08
    BDMA_CCR1: mmio.Mmio(packed struct(u32) {
        /// Channel enable This bit is set and cleared by software.
        EN: u1,
        /// Transfer complete interrupt enable This bit is set and cleared by software.
        TCIE: u1,
        /// Half transfer interrupt enable This bit is set and cleared by software.
        HTIE: u1,
        /// Transfer error interrupt enable This bit is set and cleared by software.
        TEIE: u1,
        /// Data transfer direction This bit is set and cleared by software.
        DIR: u1,
        /// Circular mode This bit is set and cleared by software.
        CIRC: u1,
        /// Peripheral increment mode This bit is set and cleared by software.
        PINC: u1,
        /// Memory increment mode This bit is set and cleared by software.
        MINC: u1,
        /// Peripheral size These bits are set and cleared by software.
        PSIZE: u2,
        /// Memory size These bits are set and cleared by software.
        MSIZE: u2,
        /// Channel priority level These bits are set and cleared by software.
        PL: u2,
        /// Memory to memory mode This bit is set and cleared by software.
        MEM2MEM: u1,
        padding: u17 = 0,
    }),
    /// DMA channel x number of data register
    /// offset: 0x0c
    BDMA_CNDTR1: mmio.Mmio(packed struct(u32) {
        /// Number of data to transfer Number of data to be transferred (0 up to 65535). This register can only be written when the channel is disabled. Once the channel is enabled, this register is read-only, indicating the remaining bytes to be transmitted. This register decrements after each DMA transfer. Once the transfer is completed, this register can either stay at zero or be reloaded automatically by the value previously programmed if the channel is configured in auto-reload mode. If this register is zero, no transaction can be served whether the channel is enabled or not.
        NDT: u16,
        padding: u16 = 0,
    }),
    /// This register must not be written when the channel is enabled.
    /// offset: 0x10
    BDMA_CPAR1: mmio.Mmio(packed struct(u32) {
        /// Peripheral address Base address of the peripheral data register from/to which the data will be read/written. When PSIZE is 01 (16-bit), the PA[0] bit is ignored. Access is automatically aligned to a half-word address. When PSIZE is 10 (32-bit), PA[1:0] are ignored. Access is automatically aligned to a word address.
        PA: u32,
    }),
    /// This register must not be written when the channel is enabled.
    /// offset: 0x14
    BDMA_CMAR1: mmio.Mmio(packed struct(u32) {
        /// Memory address Base address of the memory area from/to which the data will be read/written. When MSIZE is 01 (16-bit), the MA[0] bit is ignored. Access is automatically aligned to a half-word address. When MSIZE is 10 (32-bit), MA[1:0] are ignored. Access is automatically aligned to a word address.
        MA: u32,
    }),
    /// offset: 0x18
    reserved24: [4]u8,
    /// DMA channel x configuration register
    /// offset: 0x1c
    BDMA_CCR2: mmio.Mmio(packed struct(u32) {
        /// Channel enable This bit is set and cleared by software.
        EN: u1,
        /// Transfer complete interrupt enable This bit is set and cleared by software.
        TCIE: u1,
        /// Half transfer interrupt enable This bit is set and cleared by software.
        HTIE: u1,
        /// Transfer error interrupt enable This bit is set and cleared by software.
        TEIE: u1,
        /// Data transfer direction This bit is set and cleared by software.
        DIR: u1,
        /// Circular mode This bit is set and cleared by software.
        CIRC: u1,
        /// Peripheral increment mode This bit is set and cleared by software.
        PINC: u1,
        /// Memory increment mode This bit is set and cleared by software.
        MINC: u1,
        /// Peripheral size These bits are set and cleared by software.
        PSIZE: u2,
        /// Memory size These bits are set and cleared by software.
        MSIZE: u2,
        /// Channel priority level These bits are set and cleared by software.
        PL: u2,
        /// Memory to memory mode This bit is set and cleared by software.
        MEM2MEM: u1,
        padding: u17 = 0,
    }),
    /// DMA channel x number of data register
    /// offset: 0x20
    BDMA_CNDTR2: mmio.Mmio(packed struct(u32) {
        /// Number of data to transfer Number of data to be transferred (0 up to 65535). This register can only be written when the channel is disabled. Once the channel is enabled, this register is read-only, indicating the remaining bytes to be transmitted. This register decrements after each DMA transfer. Once the transfer is completed, this register can either stay at zero or be reloaded automatically by the value previously programmed if the channel is configured in auto-reload mode. If this register is zero, no transaction can be served whether the channel is enabled or not.
        NDT: u16,
        padding: u16 = 0,
    }),
    /// This register must not be written when the channel is enabled.
    /// offset: 0x24
    BDMA_CPAR2: mmio.Mmio(packed struct(u32) {
        /// Peripheral address Base address of the peripheral data register from/to which the data will be read/written. When PSIZE is 01 (16-bit), the PA[0] bit is ignored. Access is automatically aligned to a half-word address. When PSIZE is 10 (32-bit), PA[1:0] are ignored. Access is automatically aligned to a word address.
        PA: u32,
    }),
    /// This register must not be written when the channel is enabled.
    /// offset: 0x28
    BDMA_CMAR2: mmio.Mmio(packed struct(u32) {
        /// Memory address Base address of the memory area from/to which the data will be read/written. When MSIZE is 01 (16-bit), the MA[0] bit is ignored. Access is automatically aligned to a half-word address. When MSIZE is 10 (32-bit), MA[1:0] are ignored. Access is automatically aligned to a word address.
        MA: u32,
    }),
    /// offset: 0x2c
    reserved44: [4]u8,
    /// DMA channel x configuration register
    /// offset: 0x30
    BDMA_CCR3: mmio.Mmio(packed struct(u32) {
        /// Channel enable This bit is set and cleared by software.
        EN: u1,
        /// Transfer complete interrupt enable This bit is set and cleared by software.
        TCIE: u1,
        /// Half transfer interrupt enable This bit is set and cleared by software.
        HTIE: u1,
        /// Transfer error interrupt enable This bit is set and cleared by software.
        TEIE: u1,
        /// Data transfer direction This bit is set and cleared by software.
        DIR: u1,
        /// Circular mode This bit is set and cleared by software.
        CIRC: u1,
        /// Peripheral increment mode This bit is set and cleared by software.
        PINC: u1,
        /// Memory increment mode This bit is set and cleared by software.
        MINC: u1,
        /// Peripheral size These bits are set and cleared by software.
        PSIZE: u2,
        /// Memory size These bits are set and cleared by software.
        MSIZE: u2,
        /// Channel priority level These bits are set and cleared by software.
        PL: u2,
        /// Memory to memory mode This bit is set and cleared by software.
        MEM2MEM: u1,
        padding: u17 = 0,
    }),
    /// DMA channel x number of data register
    /// offset: 0x34
    BDMA_CNDTR3: mmio.Mmio(packed struct(u32) {
        /// Number of data to transfer Number of data to be transferred (0 up to 65535). This register can only be written when the channel is disabled. Once the channel is enabled, this register is read-only, indicating the remaining bytes to be transmitted. This register decrements after each DMA transfer. Once the transfer is completed, this register can either stay at zero or be reloaded automatically by the value previously programmed if the channel is configured in auto-reload mode. If this register is zero, no transaction can be served whether the channel is enabled or not.
        NDT: u16,
        padding: u16 = 0,
    }),
    /// This register must not be written when the channel is enabled.
    /// offset: 0x38
    BDMA_CPAR3: mmio.Mmio(packed struct(u32) {
        /// Peripheral address Base address of the peripheral data register from/to which the data will be read/written. When PSIZE is 01 (16-bit), the PA[0] bit is ignored. Access is automatically aligned to a half-word address. When PSIZE is 10 (32-bit), PA[1:0] are ignored. Access is automatically aligned to a word address.
        PA: u32,
    }),
    /// This register must not be written when the channel is enabled.
    /// offset: 0x3c
    BDMA_CMAR3: mmio.Mmio(packed struct(u32) {
        /// Memory address Base address of the memory area from/to which the data will be read/written. When MSIZE is 01 (16-bit), the MA[0] bit is ignored. Access is automatically aligned to a half-word address. When MSIZE is 10 (32-bit), MA[1:0] are ignored. Access is automatically aligned to a word address.
        MA: u32,
    }),
    /// offset: 0x40
    reserved64: [4]u8,
    /// DMA channel x configuration register
    /// offset: 0x44
    BDMA_CCR4: mmio.Mmio(packed struct(u32) {
        /// Channel enable This bit is set and cleared by software.
        EN: u1,
        /// Transfer complete interrupt enable This bit is set and cleared by software.
        TCIE: u1,
        /// Half transfer interrupt enable This bit is set and cleared by software.
        HTIE: u1,
        /// Transfer error interrupt enable This bit is set and cleared by software.
        TEIE: u1,
        /// Data transfer direction This bit is set and cleared by software.
        DIR: u1,
        /// Circular mode This bit is set and cleared by software.
        CIRC: u1,
        /// Peripheral increment mode This bit is set and cleared by software.
        PINC: u1,
        /// Memory increment mode This bit is set and cleared by software.
        MINC: u1,
        /// Peripheral size These bits are set and cleared by software.
        PSIZE: u2,
        /// Memory size These bits are set and cleared by software.
        MSIZE: u2,
        /// Channel priority level These bits are set and cleared by software.
        PL: u2,
        /// Memory to memory mode This bit is set and cleared by software.
        MEM2MEM: u1,
        padding: u17 = 0,
    }),
    /// DMA channel x number of data register
    /// offset: 0x48
    BDMA_CNDTR4: mmio.Mmio(packed struct(u32) {
        /// Number of data to transfer Number of data to be transferred (0 up to 65535). This register can only be written when the channel is disabled. Once the channel is enabled, this register is read-only, indicating the remaining bytes to be transmitted. This register decrements after each DMA transfer. Once the transfer is completed, this register can either stay at zero or be reloaded automatically by the value previously programmed if the channel is configured in auto-reload mode. If this register is zero, no transaction can be served whether the channel is enabled or not.
        NDT: u16,
        padding: u16 = 0,
    }),
    /// This register must not be written when the channel is enabled.
    /// offset: 0x4c
    BDMA_CPAR4: mmio.Mmio(packed struct(u32) {
        /// Peripheral address Base address of the peripheral data register from/to which the data will be read/written. When PSIZE is 01 (16-bit), the PA[0] bit is ignored. Access is automatically aligned to a half-word address. When PSIZE is 10 (32-bit), PA[1:0] are ignored. Access is automatically aligned to a word address.
        PA: u32,
    }),
    /// This register must not be written when the channel is enabled.
    /// offset: 0x50
    BDMA_CMAR4: mmio.Mmio(packed struct(u32) {
        /// Memory address Base address of the memory area from/to which the data will be read/written. When MSIZE is 01 (16-bit), the MA[0] bit is ignored. Access is automatically aligned to a half-word address. When MSIZE is 10 (32-bit), MA[1:0] are ignored. Access is automatically aligned to a word address.
        MA: u32,
    }),
    /// offset: 0x54
    reserved84: [4]u8,
    /// DMA channel x configuration register
    /// offset: 0x58
    BDMA_CCR5: mmio.Mmio(packed struct(u32) {
        /// Channel enable This bit is set and cleared by software.
        EN: u1,
        /// Transfer complete interrupt enable This bit is set and cleared by software.
        TCIE: u1,
        /// Half transfer interrupt enable This bit is set and cleared by software.
        HTIE: u1,
        /// Transfer error interrupt enable This bit is set and cleared by software.
        TEIE: u1,
        /// Data transfer direction This bit is set and cleared by software.
        DIR: u1,
        /// Circular mode This bit is set and cleared by software.
        CIRC: u1,
        /// Peripheral increment mode This bit is set and cleared by software.
        PINC: u1,
        /// Memory increment mode This bit is set and cleared by software.
        MINC: u1,
        /// Peripheral size These bits are set and cleared by software.
        PSIZE: u2,
        /// Memory size These bits are set and cleared by software.
        MSIZE: u2,
        /// Channel priority level These bits are set and cleared by software.
        PL: u2,
        /// Memory to memory mode This bit is set and cleared by software.
        MEM2MEM: u1,
        padding: u17 = 0,
    }),
    /// DMA channel x number of data register
    /// offset: 0x5c
    BDMA_CNDTR5: mmio.Mmio(packed struct(u32) {
        /// Number of data to transfer Number of data to be transferred (0 up to 65535). This register can only be written when the channel is disabled. Once the channel is enabled, this register is read-only, indicating the remaining bytes to be transmitted. This register decrements after each DMA transfer. Once the transfer is completed, this register can either stay at zero or be reloaded automatically by the value previously programmed if the channel is configured in auto-reload mode. If this register is zero, no transaction can be served whether the channel is enabled or not.
        NDT: u16,
        padding: u16 = 0,
    }),
    /// This register must not be written when the channel is enabled.
    /// offset: 0x60
    BDMA_CPAR5: mmio.Mmio(packed struct(u32) {
        /// Peripheral address Base address of the peripheral data register from/to which the data will be read/written. When PSIZE is 01 (16-bit), the PA[0] bit is ignored. Access is automatically aligned to a half-word address. When PSIZE is 10 (32-bit), PA[1:0] are ignored. Access is automatically aligned to a word address.
        PA: u32,
    }),
    /// This register must not be written when the channel is enabled.
    /// offset: 0x64
    BDMA_CMAR5: mmio.Mmio(packed struct(u32) {
        /// Memory address Base address of the memory area from/to which the data will be read/written. When MSIZE is 01 (16-bit), the MA[0] bit is ignored. Access is automatically aligned to a half-word address. When MSIZE is 10 (32-bit), MA[1:0] are ignored. Access is automatically aligned to a word address.
        MA: u32,
    }),
    /// offset: 0x68
    reserved104: [4]u8,
    /// DMA channel x configuration register
    /// offset: 0x6c
    BDMA_CCR6: mmio.Mmio(packed struct(u32) {
        /// Channel enable This bit is set and cleared by software.
        EN: u1,
        /// Transfer complete interrupt enable This bit is set and cleared by software.
        TCIE: u1,
        /// Half transfer interrupt enable This bit is set and cleared by software.
        HTIE: u1,
        /// Transfer error interrupt enable This bit is set and cleared by software.
        TEIE: u1,
        /// Data transfer direction This bit is set and cleared by software.
        DIR: u1,
        /// Circular mode This bit is set and cleared by software.
        CIRC: u1,
        /// Peripheral increment mode This bit is set and cleared by software.
        PINC: u1,
        /// Memory increment mode This bit is set and cleared by software.
        MINC: u1,
        /// Peripheral size These bits are set and cleared by software.
        PSIZE: u2,
        /// Memory size These bits are set and cleared by software.
        MSIZE: u2,
        /// Channel priority level These bits are set and cleared by software.
        PL: u2,
        /// Memory to memory mode This bit is set and cleared by software.
        MEM2MEM: u1,
        padding: u17 = 0,
    }),
    /// DMA channel x number of data register
    /// offset: 0x70
    BDMA_CNDTR6: mmio.Mmio(packed struct(u32) {
        /// Number of data to transfer Number of data to be transferred (0 up to 65535). This register can only be written when the channel is disabled. Once the channel is enabled, this register is read-only, indicating the remaining bytes to be transmitted. This register decrements after each DMA transfer. Once the transfer is completed, this register can either stay at zero or be reloaded automatically by the value previously programmed if the channel is configured in auto-reload mode. If this register is zero, no transaction can be served whether the channel is enabled or not.
        NDT: u16,
        padding: u16 = 0,
    }),
    /// This register must not be written when the channel is enabled.
    /// offset: 0x74
    BDMA_CPAR6: mmio.Mmio(packed struct(u32) {
        /// Peripheral address Base address of the peripheral data register from/to which the data will be read/written. When PSIZE is 01 (16-bit), the PA[0] bit is ignored. Access is automatically aligned to a half-word address. When PSIZE is 10 (32-bit), PA[1:0] are ignored. Access is automatically aligned to a word address.
        PA: u32,
    }),
    /// This register must not be written when the channel is enabled.
    /// offset: 0x78
    BDMA_CMAR6: mmio.Mmio(packed struct(u32) {
        /// Memory address Base address of the memory area from/to which the data will be read/written. When MSIZE is 01 (16-bit), the MA[0] bit is ignored. Access is automatically aligned to a half-word address. When MSIZE is 10 (32-bit), MA[1:0] are ignored. Access is automatically aligned to a word address.
        MA: u32,
    }),
    /// offset: 0x7c
    reserved124: [4]u8,
    /// DMA channel x configuration register
    /// offset: 0x80
    BDMA_CCR7: mmio.Mmio(packed struct(u32) {
        /// Channel enable This bit is set and cleared by software.
        EN: u1,
        /// Transfer complete interrupt enable This bit is set and cleared by software.
        TCIE: u1,
        /// Half transfer interrupt enable This bit is set and cleared by software.
        HTIE: u1,
        /// Transfer error interrupt enable This bit is set and cleared by software.
        TEIE: u1,
        /// Data transfer direction This bit is set and cleared by software.
        DIR: u1,
        /// Circular mode This bit is set and cleared by software.
        CIRC: u1,
        /// Peripheral increment mode This bit is set and cleared by software.
        PINC: u1,
        /// Memory increment mode This bit is set and cleared by software.
        MINC: u1,
        /// Peripheral size These bits are set and cleared by software.
        PSIZE: u2,
        /// Memory size These bits are set and cleared by software.
        MSIZE: u2,
        /// Channel priority level These bits are set and cleared by software.
        PL: u2,
        /// Memory to memory mode This bit is set and cleared by software.
        MEM2MEM: u1,
        padding: u17 = 0,
    }),
    /// DMA channel x number of data register
    /// offset: 0x84
    BDMA_CNDTR7: mmio.Mmio(packed struct(u32) {
        /// Number of data to transfer Number of data to be transferred (0 up to 65535). This register can only be written when the channel is disabled. Once the channel is enabled, this register is read-only, indicating the remaining bytes to be transmitted. This register decrements after each DMA transfer. Once the transfer is completed, this register can either stay at zero or be reloaded automatically by the value previously programmed if the channel is configured in auto-reload mode. If this register is zero, no transaction can be served whether the channel is enabled or not.
        NDT: u16,
        padding: u16 = 0,
    }),
    /// This register must not be written when the channel is enabled.
    /// offset: 0x88
    BDMA_CPAR7: mmio.Mmio(packed struct(u32) {
        /// Peripheral address Base address of the peripheral data register from/to which the data will be read/written. When PSIZE is 01 (16-bit), the PA[0] bit is ignored. Access is automatically aligned to a half-word address. When PSIZE is 10 (32-bit), PA[1:0] are ignored. Access is automatically aligned to a word address.
        PA: u32,
    }),
    /// This register must not be written when the channel is enabled.
    /// offset: 0x8c
    BDMA_CMAR7: mmio.Mmio(packed struct(u32) {
        /// Memory address Base address of the memory area from/to which the data will be read/written. When MSIZE is 01 (16-bit), the MA[0] bit is ignored. Access is automatically aligned to a half-word address. When MSIZE is 10 (32-bit), MA[1:0] are ignored. Access is automatically aligned to a word address.
        MA: u32,
    }),
    /// offset: 0x90
    reserved144: [4]u8,
    /// DMA channel x configuration register
    /// offset: 0x94
    BDMA_CCR8: mmio.Mmio(packed struct(u32) {
        /// Channel enable This bit is set and cleared by software.
        EN: u1,
        /// Transfer complete interrupt enable This bit is set and cleared by software.
        TCIE: u1,
        /// Half transfer interrupt enable This bit is set and cleared by software.
        HTIE: u1,
        /// Transfer error interrupt enable This bit is set and cleared by software.
        TEIE: u1,
        /// Data transfer direction This bit is set and cleared by software.
        DIR: u1,
        /// Circular mode This bit is set and cleared by software.
        CIRC: u1,
        /// Peripheral increment mode This bit is set and cleared by software.
        PINC: u1,
        /// Memory increment mode This bit is set and cleared by software.
        MINC: u1,
        /// Peripheral size These bits are set and cleared by software.
        PSIZE: u2,
        /// Memory size These bits are set and cleared by software.
        MSIZE: u2,
        /// Channel priority level These bits are set and cleared by software.
        PL: u2,
        /// Memory to memory mode This bit is set and cleared by software.
        MEM2MEM: u1,
        padding: u17 = 0,
    }),
    /// DMA channel x number of data register
    /// offset: 0x98
    BDMA_CNDTR8: mmio.Mmio(packed struct(u32) {
        /// Number of data to transfer Number of data to be transferred (0 up to 65535). This register can only be written when the channel is disabled. Once the channel is enabled, this register is read-only, indicating the remaining bytes to be transmitted. This register decrements after each DMA transfer. Once the transfer is completed, this register can either stay at zero or be reloaded automatically by the value previously programmed if the channel is configured in auto-reload mode. If this register is zero, no transaction can be served whether the channel is enabled or not.
        NDT: u16,
        padding: u16 = 0,
    }),
    /// This register must not be written when the channel is enabled.
    /// offset: 0x9c
    BDMA_CPAR8: mmio.Mmio(packed struct(u32) {
        /// Peripheral address Base address of the peripheral data register from/to which the data will be read/written. When PSIZE is 01 (16-bit), the PA[0] bit is ignored. Access is automatically aligned to a half-word address. When PSIZE is 10 (32-bit), PA[1:0] are ignored. Access is automatically aligned to a word address.
        PA: u32,
    }),
    /// This register must not be written when the channel is enabled.
    /// offset: 0xa0
    BDMA_CMAR8: mmio.Mmio(packed struct(u32) {
        /// Memory address Base address of the memory area from/to which the data will be read/written. When MSIZE is 01 (16-bit), the MA[0] bit is ignored. Access is automatically aligned to a half-word address. When MSIZE is 10 (32-bit), MA[1:0] are ignored. Access is automatically aligned to a word address.
        MA: u32,
    }),
};
