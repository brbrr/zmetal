const mmio = @import("mmio");
const types = @import("../../types.zig");

/// MDMA
pub const MDMA = extern struct {
    /// MDMA Global Interrupt/Status Register
    /// offset: 0x00
    MDMA_GISR0: mmio.Mmio(packed struct(u32) {
        /// Channel x global interrupt flag (x=...) This bit is set and reset by hardware. It is a logical OR of all the Channel x interrupt flags (CTCIFx, BTIFx, BRTIFx, TEIFx) which are enabled in the interrupt mask register (CTCIEx, BTIEx, BRTIEx, TEIEx)
        GIF0: u1,
        /// Channel x global interrupt flag (x=...) This bit is set and reset by hardware. It is a logical OR of all the Channel x interrupt flags (CTCIFx, BTIFx, BRTIFx, TEIFx) which are enabled in the interrupt mask register (CTCIEx, BTIEx, BRTIEx, TEIEx)
        GIF1: u1,
        /// Channel x global interrupt flag (x=...) This bit is set and reset by hardware. It is a logical OR of all the Channel x interrupt flags (CTCIFx, BTIFx, BRTIFx, TEIFx) which are enabled in the interrupt mask register (CTCIEx, BTIEx, BRTIEx, TEIEx)
        GIF2: u1,
        /// Channel x global interrupt flag (x=...) This bit is set and reset by hardware. It is a logical OR of all the Channel x interrupt flags (CTCIFx, BTIFx, BRTIFx, TEIFx) which are enabled in the interrupt mask register (CTCIEx, BTIEx, BRTIEx, TEIEx)
        GIF3: u1,
        /// Channel x global interrupt flag (x=...) This bit is set and reset by hardware. It is a logical OR of all the Channel x interrupt flags (CTCIFx, BTIFx, BRTIFx, TEIFx) which are enabled in the interrupt mask register (CTCIEx, BTIEx, BRTIEx, TEIEx)
        GIF4: u1,
        /// Channel x global interrupt flag (x=...) This bit is set and reset by hardware. It is a logical OR of all the Channel x interrupt flags (CTCIFx, BTIFx, BRTIFx, TEIFx) which are enabled in the interrupt mask register (CTCIEx, BTIEx, BRTIEx, TEIEx)
        GIF5: u1,
        /// Channel x global interrupt flag (x=...) This bit is set and reset by hardware. It is a logical OR of all the Channel x interrupt flags (CTCIFx, BTIFx, BRTIFx, TEIFx) which are enabled in the interrupt mask register (CTCIEx, BTIEx, BRTIEx, TEIEx)
        GIF6: u1,
        /// Channel x global interrupt flag (x=...) This bit is set and reset by hardware. It is a logical OR of all the Channel x interrupt flags (CTCIFx, BTIFx, BRTIFx, TEIFx) which are enabled in the interrupt mask register (CTCIEx, BTIEx, BRTIEx, TEIEx)
        GIF7: u1,
        /// Channel x global interrupt flag (x=...) This bit is set and reset by hardware. It is a logical OR of all the Channel x interrupt flags (CTCIFx, BTIFx, BRTIFx, TEIFx) which are enabled in the interrupt mask register (CTCIEx, BTIEx, BRTIEx, TEIEx)
        GIF8: u1,
        /// Channel x global interrupt flag (x=...) This bit is set and reset by hardware. It is a logical OR of all the Channel x interrupt flags (CTCIFx, BTIFx, BRTIFx, TEIFx) which are enabled in the interrupt mask register (CTCIEx, BTIEx, BRTIEx, TEIEx)
        GIF9: u1,
        /// Channel x global interrupt flag (x=...) This bit is set and reset by hardware. It is a logical OR of all the Channel x interrupt flags (CTCIFx, BTIFx, BRTIFx, TEIFx) which are enabled in the interrupt mask register (CTCIEx, BTIEx, BRTIEx, TEIEx)
        GIF10: u1,
        /// Channel x global interrupt flag (x=...) This bit is set and reset by hardware. It is a logical OR of all the Channel x interrupt flags (CTCIFx, BTIFx, BRTIFx, TEIFx) which are enabled in the interrupt mask register (CTCIEx, BTIEx, BRTIEx, TEIEx)
        GIF11: u1,
        /// Channel x global interrupt flag (x=...) This bit is set and reset by hardware. It is a logical OR of all the Channel x interrupt flags (CTCIFx, BTIFx, BRTIFx, TEIFx) which are enabled in the interrupt mask register (CTCIEx, BTIEx, BRTIEx, TEIEx)
        GIF12: u1,
        /// Channel x global interrupt flag (x=...) This bit is set and reset by hardware. It is a logical OR of all the Channel x interrupt flags (CTCIFx, BTIFx, BRTIFx, TEIFx) which are enabled in the interrupt mask register (CTCIEx, BTIEx, BRTIEx, TEIEx)
        GIF13: u1,
        /// Channel x global interrupt flag (x=...) This bit is set and reset by hardware. It is a logical OR of all the Channel x interrupt flags (CTCIFx, BTIFx, BRTIFx, TEIFx) which are enabled in the interrupt mask register (CTCIEx, BTIEx, BRTIEx, TEIEx)
        GIF14: u1,
        /// Channel x global interrupt flag (x=...) This bit is set and reset by hardware. It is a logical OR of all the Channel x interrupt flags (CTCIFx, BTIFx, BRTIFx, TEIFx) which are enabled in the interrupt mask register (CTCIEx, BTIEx, BRTIEx, TEIEx)
        GIF15: u1,
        padding: u16 = 0,
    }),
    /// offset: 0x04
    reserved4: [60]u8,
    /// MDMA channel x interrupt/status register
    /// offset: 0x40
    MDMA_C0ISR: mmio.Mmio(packed struct(u32) {
        /// Channel x transfer error interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        TEIF0: u1,
        /// Channel x Channel Transfer Complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register. CTC is set when the last block was transferred and the channel has been automatically disabled. CTC is also set when the channel is suspended, as a result of writing EN bit to 0.
        CTCIF0: u1,
        /// Channel x block repeat transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BRTIF0: u1,
        /// Channel x block transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BTIF0: u1,
        /// channel x buffer transfer complete
        TCIF0: u1,
        reserved16: u11 = 0,
        /// channel x request active flag
        CRQA0: u1,
        padding: u15 = 0,
    }),
    /// MDMA channel x interrupt flag clear register
    /// offset: 0x44
    MDMA_C0IFCR: mmio.Mmio(packed struct(u32) {
        /// Channel x clear transfer error interrupt flag Writing a 1 into this bit clears TEIFx in the MDMA_ISRy register
        CTEIF0: u1,
        /// Clear Channel transfer complete interrupt flag for channel x Writing a 1 into this bit clears CTCIFx in the MDMA_ISRy register
        CCTCIF0: u1,
        /// Channel x clear block repeat transfer complete interrupt flag Writing a 1 into this bit clears BRTIFx in the MDMA_ISRy register
        CBRTIF0: u1,
        /// Channel x Clear block transfer complete interrupt flag Writing a 1 into this bit clears BTIFx in the MDMA_ISRy register
        CBTIF0: u1,
        /// CLear buffer Transfer Complete Interrupt Flag for channel x Writing a 1 into this bit clears TCIFx in the MDMA_ISRy register
        CLTCIF0: u1,
        padding: u27 = 0,
    }),
    /// MDMA Channel x error status register
    /// offset: 0x48
    MDMA_C0ESR: mmio.Mmio(packed struct(u32) {
        /// Transfer Error Address These bits are set and cleared by HW, in case of an MDMA data transfer error. It is used in conjunction with TED. This field indicates the 7 LSBits of the address which generated a transfer/access error. It may be used by SW to retrieve the failing address, by adding this value (truncated to the buffer transfer length size) to the current SAR/DAR value. Note: The SAR/DAR current value doesnt reflect this last address due to the FIFO management system. The SAR/DAR are only updated at the end of a (buffer) transfer (of TLEN+1 bytes). Note: It is not set in case of a link data error.
        TEA: u7,
        /// Transfer Error Direction These bit is set and cleared by HW, in case of an MDMA data transfer error.
        TED: u1,
        /// Transfer Error Link Data These bit is set by HW, in case of a transfer error while reading the block link data structure. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TELD: u1,
        /// Transfer Error Mask Data These bit is set by HW, in case of a transfer error while writing the Mask Data. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TEMD: u1,
        /// Address/Size Error These bit is set by HW, when the programmed address is not aligned with the data size. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        ASE: u1,
        /// Block Size Error These bit is set by HW, when the block size is not an integer multiple of the data size either for source or destination. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        BSE: u1,
        padding: u20 = 0,
    }),
    /// This register is used to control the concerned channel.
    /// offset: 0x4c
    MDMA_C0CR: mmio.Mmio(packed struct(u32) {
        /// channel enable
        EN: u1,
        /// Transfer error interrupt enable This bit is set and cleared by software.
        TEIE: u1,
        /// Channel Transfer Complete interrupt enable This bit is set and cleared by software.
        CTCIE: u1,
        /// Block Repeat transfer interrupt enable This bit is set and cleared by software.
        BRTIE: u1,
        /// Block Transfer interrupt enable This bit is set and cleared by software.
        BTIE: u1,
        /// buffer Transfer Complete interrupt enable This bit is set and cleared by software.
        TCIE: u1,
        /// Priority level These bits are set and cleared by software. These bits are protected and can be written only if EN is 0.
        PL: u2,
        reserved12: u4 = 0,
        /// byte Endianness exchange
        BEX: u1,
        /// Half word Endianes exchange
        HEX: u1,
        /// Word Endianness exchange
        WEX: u1,
        reserved16: u1 = 0,
        /// SW ReQuest Writing a 1 into this bit sets the CRQAx in MDMA_ISRy register, activating the request on Channel x Note: Either the whole CxCR register or the 8-bit/16-bit register @ Address offset: 0x4E + 0x40 chn may be used for SWRQ activation. In case of a SW request, acknowledge is not generated (neither HW signal, nor CxMAR write access).
        SWRQ: u1,
        padding: u15 = 0,
    }),
    /// This register is used to configure the concerned channel.
    /// offset: 0x50
    MDMA_C0TCR: mmio.Mmio(packed struct(u32) {
        /// Source increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When source is AHB (SBUS=1), SINC = 00 is forbidden. In Linked List Mode, at the end of a block (single or last block in repeated block transfer mode), this register will be loaded from memory (from address given by current LAR[31:0] + 0x00).
        SINC: u2,
        /// Destination increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When destination is AHB (DBUS=1), DINC = 00 is forbidden.
        DINC: u2,
        /// Source data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If SINCOS &lt; SSIZE and SINC &#8800; 00, the result will be unpredictable. Note: SSIZE = 11 (double-word) is forbidden when source is TCM/AHB bus (SBUS=1).
        SSIZE: u2,
        /// Destination data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0. Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If DINCOS &lt; DSIZE and DINC &#8800; 00, the result will be unpredictable. Note: DSIZE = 11 (double-word) is forbidden when destination is TCM/AHB bus (DBUS=1).
        DSIZE: u2,
        /// source increment offset size
        SINCOS: u2,
        /// Destination increment offset
        DINCOS: u2,
        /// source burst transfer configuration
        SBURST: u3,
        /// Destination burst transfer configuration
        DBURST: u3,
        /// buffer transfer lengh
        TLEN: u7,
        /// PacK Enable These bit is set and cleared by software. If the Source Size is smaller than the destination, it will be padded according to the PAM value. If the Source data size is larger than the destination one, it will be truncated. The alignment will be done according to the PAM[0] value. This bit is protected and can be written only if EN is 0
        PKE: u1,
        /// Padding/Alignement Mode These bits are set and cleared by software. Case 1: Source data size smaller than destination data size - 3 options are valid. Case 2: Source data size larger than destination data size. The remainder part is discarded. When PKE = 1 or DSIZE=SSIZE, these bits are ignored. These bits are protected and can be written only if EN is 0
        PAM: u2,
        /// Trigger Mode These bits are set and cleared by software. Note: If TRGM is 11 for the current block, all the values loaded at the end of the current block through the linked list mechanism must keep the same value (TRGM=11) and the same SWRM value, otherwise the result is undefined. These bits are protected and can be written only if EN is 0.
        TRGM: u2,
        /// SW Request Mode This bit is set and cleared by software. If a HW or SW request is currently active, the bit change will be delayed until the current transfer is completed. If the CxMAR contains a valid address, the CxMDR value will also be written @ CxMAR address. This bit is protected and can be written only if EN is 0.
        SWRM: u1,
        /// Bufferable Write Mode This bit is set and cleared by software. This bit is protected and can be written only if EN is 0. Note: All MDMA destination accesses are non-cacheable.
        BWM: u1,
    }),
    /// MDMA Channel x block number of data register
    /// offset: 0x54
    MDMA_C0BNDTR: mmio.Mmio(packed struct(u32) {
        /// block number of data to transfer
        BNDT: u17,
        reserved18: u1 = 0,
        /// Block Repeat Source address Update Mode These bits are protected and can be written only if EN is 0.
        BRSUM: u1,
        /// Block Repeat Destination address Update Mode These bits are protected and can be written only if EN is 0.
        BRDUM: u1,
        /// Block Repeat Count This field contains the number of repetitions of the current block (0 to 4095). When the channel is enabled, this register is read-only, indicating the remaining number of blocks, excluding the current one. This register decrements after each complete block transfer. Once the last block transfer has completed, this register can either stay at zero or be reloaded automatically from memory (in Linked List mode - i.e. Link Address valid). These bits are protected and can be written only if EN is 0.
        BRC: u12,
    }),
    /// MDMA channel x source address register
    /// offset: 0x58
    MDMA_C0SAR: mmio.Mmio(packed struct(u32) {
        /// source adr base
        SAR: u32,
    }),
    /// MDMA channel x destination address register
    /// offset: 0x5c
    MDMA_C0DAR: mmio.Mmio(packed struct(u32) {
        /// Destination adr base
        DAR: u32,
    }),
    /// MDMA channel x Block Repeat address Update register
    /// offset: 0x60
    MDMA_C0BRUR: mmio.Mmio(packed struct(u32) {
        /// source adresse update value
        SUV: u16,
        /// destination address update
        DUV: u16,
    }),
    /// MDMA channel x Link Address register
    /// offset: 0x64
    MDMA_C0LAR: mmio.Mmio(packed struct(u32) {
        /// Link address register
        LAR: u32,
    }),
    /// MDMA channel x Trigger and Bus selection Register
    /// offset: 0x68
    MDMA_C0TBR: mmio.Mmio(packed struct(u32) {
        /// Trigger selection
        TSEL: u6,
        reserved16: u10 = 0,
        /// Source BUS select This bit is protected and can be written only if EN is 0.
        SBUS: u1,
        /// Destination BUS slect This bit is protected and can be written only if EN is 0.
        DBUS: u1,
        padding: u14 = 0,
    }),
    /// offset: 0x6c
    reserved108: [4]u8,
    /// MDMA channel x Mask address register
    /// offset: 0x70
    MDMA_C0MAR: mmio.Mmio(packed struct(u32) {
        /// Mask address
        MAR: u32,
    }),
    /// MDMA channel x Mask Data register
    /// offset: 0x74
    MDMA_C0MDR: mmio.Mmio(packed struct(u32) {
        /// Mask data
        MDR: u32,
    }),
    /// offset: 0x78
    reserved120: [8]u8,
    /// MDMA channel x interrupt/status register
    /// offset: 0x80
    MDMA_C1ISR: mmio.Mmio(packed struct(u32) {
        /// Channel x transfer error interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        TEIF1: u1,
        /// Channel x Channel Transfer Complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register. CTC is set when the last block was transferred and the channel has been automatically disabled. CTC is also set when the channel is suspended, as a result of writing EN bit to 0.
        CTCIF1: u1,
        /// Channel x block repeat transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BRTIF1: u1,
        /// Channel x block transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BTIF1: u1,
        /// channel x buffer transfer complete
        TCIF1: u1,
        reserved16: u11 = 0,
        /// channel x request active flag
        CRQA1: u1,
        padding: u15 = 0,
    }),
    /// MDMA channel x interrupt flag clear register
    /// offset: 0x84
    MDMA_C1IFCR: mmio.Mmio(packed struct(u32) {
        /// Channel x clear transfer error interrupt flag Writing a 1 into this bit clears TEIFx in the MDMA_ISRy register
        CTEIF1: u1,
        /// Clear Channel transfer complete interrupt flag for channel x Writing a 1 into this bit clears CTCIFx in the MDMA_ISRy register
        CCTCIF1: u1,
        /// Channel x clear block repeat transfer complete interrupt flag Writing a 1 into this bit clears BRTIFx in the MDMA_ISRy register
        CBRTIF1: u1,
        /// Channel x Clear block transfer complete interrupt flag Writing a 1 into this bit clears BTIFx in the MDMA_ISRy register
        CBTIF1: u1,
        /// CLear buffer Transfer Complete Interrupt Flag for channel x Writing a 1 into this bit clears TCIFx in the MDMA_ISRy register
        CLTCIF1: u1,
        padding: u27 = 0,
    }),
    /// MDMA Channel x error status register
    /// offset: 0x88
    MDMA_C1ESR: mmio.Mmio(packed struct(u32) {
        /// Transfer Error Address These bits are set and cleared by HW, in case of an MDMA data transfer error. It is used in conjunction with TED. This field indicates the 7 LSBits of the address which generated a transfer/access error. It may be used by SW to retrieve the failing address, by adding this value (truncated to the buffer transfer length size) to the current SAR/DAR value. Note: The SAR/DAR current value doesnt reflect this last address due to the FIFO management system. The SAR/DAR are only updated at the end of a (buffer) transfer (of TLEN+1 bytes). Note: It is not set in case of a link data error.
        TEA: u7,
        /// Transfer Error Direction These bit is set and cleared by HW, in case of an MDMA data transfer error.
        TED: u1,
        /// Transfer Error Link Data These bit is set by HW, in case of a transfer error while reading the block link data structure. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TELD: u1,
        /// Transfer Error Mask Data These bit is set by HW, in case of a transfer error while writing the Mask Data. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TEMD: u1,
        /// Address/Size Error These bit is set by HW, when the programmed address is not aligned with the data size. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        ASE: u1,
        /// Block Size Error These bit is set by HW, when the block size is not an integer multiple of the data size either for source or destination. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        BSE: u1,
        padding: u20 = 0,
    }),
    /// This register is used to control the concerned channel.
    /// offset: 0x8c
    MDMA_C1CR: mmio.Mmio(packed struct(u32) {
        /// channel enable
        EN: u1,
        /// Transfer error interrupt enable This bit is set and cleared by software.
        TEIE: u1,
        /// Channel Transfer Complete interrupt enable This bit is set and cleared by software.
        CTCIE: u1,
        /// Block Repeat transfer interrupt enable This bit is set and cleared by software.
        BRTIE: u1,
        /// Block Transfer interrupt enable This bit is set and cleared by software.
        BTIE: u1,
        /// buffer Transfer Complete interrupt enable This bit is set and cleared by software.
        TCIE: u1,
        /// Priority level These bits are set and cleared by software. These bits are protected and can be written only if EN is 0.
        PL: u2,
        reserved12: u4 = 0,
        /// byte Endianness exchange
        BEX: u1,
        /// Half word Endianes exchange
        HEX: u1,
        /// Word Endianness exchange
        WEX: u1,
        reserved16: u1 = 0,
        /// SW ReQuest Writing a 1 into this bit sets the CRQAx in MDMA_ISRy register, activating the request on Channel x Note: Either the whole CxCR register or the 8-bit/16-bit register @ Address offset: 0x4E + 0x40 chn may be used for SWRQ activation. In case of a SW request, acknowledge is not generated (neither HW signal, nor CxMAR write access).
        SWRQ: u1,
        padding: u15 = 0,
    }),
    /// This register is used to configure the concerned channel.
    /// offset: 0x90
    MDMA_C1TCR: mmio.Mmio(packed struct(u32) {
        /// Source increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When source is AHB (SBUS=1), SINC = 00 is forbidden. In Linked List Mode, at the end of a block (single or last block in repeated block transfer mode), this register will be loaded from memory (from address given by current LAR[31:0] + 0x00).
        SINC: u2,
        /// Destination increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When destination is AHB (DBUS=1), DINC = 00 is forbidden.
        DINC: u2,
        /// Source data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If SINCOS &lt; SSIZE and SINC &#8800; 00, the result will be unpredictable. Note: SSIZE = 11 (double-word) is forbidden when source is TCM/AHB bus (SBUS=1).
        SSIZE: u2,
        /// Destination data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0. Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If DINCOS &lt; DSIZE and DINC &#8800; 00, the result will be unpredictable. Note: DSIZE = 11 (double-word) is forbidden when destination is TCM/AHB bus (DBUS=1).
        DSIZE: u2,
        /// source increment offset size
        SINCOS: u2,
        /// Destination increment offset
        DINCOS: u2,
        /// source burst transfer configuration
        SBURST: u3,
        /// Destination burst transfer configuration
        DBURST: u3,
        /// buffer transfer lengh
        TLEN: u7,
        /// PacK Enable These bit is set and cleared by software. If the Source Size is smaller than the destination, it will be padded according to the PAM value. If the Source data size is larger than the destination one, it will be truncated. The alignment will be done according to the PAM[0] value. This bit is protected and can be written only if EN is 0
        PKE: u1,
        /// Padding/Alignement Mode These bits are set and cleared by software. Case 1: Source data size smaller than destination data size - 3 options are valid. Case 2: Source data size larger than destination data size. The remainder part is discarded. When PKE = 1 or DSIZE=SSIZE, these bits are ignored. These bits are protected and can be written only if EN is 0
        PAM: u2,
        /// Trigger Mode These bits are set and cleared by software. Note: If TRGM is 11 for the current block, all the values loaded at the end of the current block through the linked list mechanism must keep the same value (TRGM=11) and the same SWRM value, otherwise the result is undefined. These bits are protected and can be written only if EN is 0.
        TRGM: u2,
        /// SW Request Mode This bit is set and cleared by software. If a HW or SW request is currently active, the bit change will be delayed until the current transfer is completed. If the CxMAR contains a valid address, the CxMDR value will also be written @ CxMAR address. This bit is protected and can be written only if EN is 0.
        SWRM: u1,
        /// Bufferable Write Mode This bit is set and cleared by software. This bit is protected and can be written only if EN is 0. Note: All MDMA destination accesses are non-cacheable.
        BWM: u1,
    }),
    /// MDMA Channel x block number of data register
    /// offset: 0x94
    MDMA_C1BNDTR: mmio.Mmio(packed struct(u32) {
        /// block number of data to transfer
        BNDT: u17,
        reserved18: u1 = 0,
        /// Block Repeat Source address Update Mode These bits are protected and can be written only if EN is 0.
        BRSUM: u1,
        /// Block Repeat Destination address Update Mode These bits are protected and can be written only if EN is 0.
        BRDUM: u1,
        /// Block Repeat Count This field contains the number of repetitions of the current block (0 to 4095). When the channel is enabled, this register is read-only, indicating the remaining number of blocks, excluding the current one. This register decrements after each complete block transfer. Once the last block transfer has completed, this register can either stay at zero or be reloaded automatically from memory (in Linked List mode - i.e. Link Address valid). These bits are protected and can be written only if EN is 0.
        BRC: u12,
    }),
    /// MDMA channel x source address register
    /// offset: 0x98
    MDMA_C1SAR: mmio.Mmio(packed struct(u32) {
        /// source adr base
        SAR: u32,
    }),
    /// MDMA channel x destination address register
    /// offset: 0x9c
    MDMA_C1DAR: mmio.Mmio(packed struct(u32) {
        /// Destination adr base
        DAR: u32,
    }),
    /// MDMA channel x Block Repeat address Update register
    /// offset: 0xa0
    MDMA_C1BRUR: mmio.Mmio(packed struct(u32) {
        /// source adresse update value
        SUV: u16,
        /// destination address update
        DUV: u16,
    }),
    /// MDMA channel x Link Address register
    /// offset: 0xa4
    MDMA_C1LAR: mmio.Mmio(packed struct(u32) {
        /// Link address register
        LAR: u32,
    }),
    /// MDMA channel x Trigger and Bus selection Register
    /// offset: 0xa8
    MDMA_C1TBR: mmio.Mmio(packed struct(u32) {
        /// Trigger selection
        TSEL: u6,
        reserved16: u10 = 0,
        /// Source BUS select This bit is protected and can be written only if EN is 0.
        SBUS: u1,
        /// Destination BUS slect This bit is protected and can be written only if EN is 0.
        DBUS: u1,
        padding: u14 = 0,
    }),
    /// offset: 0xac
    reserved172: [4]u8,
    /// MDMA channel x Mask address register
    /// offset: 0xb0
    MDMA_C1MAR: mmio.Mmio(packed struct(u32) {
        /// Mask address
        MAR: u32,
    }),
    /// MDMA channel x Mask Data register
    /// offset: 0xb4
    MDMA_C1MDR: mmio.Mmio(packed struct(u32) {
        /// Mask data
        MDR: u32,
    }),
    /// offset: 0xb8
    reserved184: [8]u8,
    /// MDMA channel x interrupt/status register
    /// offset: 0xc0
    MDMA_C2ISR: mmio.Mmio(packed struct(u32) {
        /// Channel x transfer error interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        TEIF2: u1,
        /// Channel x Channel Transfer Complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register. CTC is set when the last block was transferred and the channel has been automatically disabled. CTC is also set when the channel is suspended, as a result of writing EN bit to 0.
        CTCIF2: u1,
        /// Channel x block repeat transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BRTIF2: u1,
        /// Channel x block transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BTIF2: u1,
        /// channel x buffer transfer complete
        TCIF2: u1,
        reserved16: u11 = 0,
        /// channel x request active flag
        CRQA2: u1,
        padding: u15 = 0,
    }),
    /// MDMA channel x interrupt flag clear register
    /// offset: 0xc4
    MDMA_C2IFCR: mmio.Mmio(packed struct(u32) {
        /// Channel x clear transfer error interrupt flag Writing a 1 into this bit clears TEIFx in the MDMA_ISRy register
        CTEIF2: u1,
        /// Clear Channel transfer complete interrupt flag for channel x Writing a 1 into this bit clears CTCIFx in the MDMA_ISRy register
        CCTCIF2: u1,
        /// Channel x clear block repeat transfer complete interrupt flag Writing a 1 into this bit clears BRTIFx in the MDMA_ISRy register
        CBRTIF2: u1,
        /// Channel x Clear block transfer complete interrupt flag Writing a 1 into this bit clears BTIFx in the MDMA_ISRy register
        CBTIF2: u1,
        /// CLear buffer Transfer Complete Interrupt Flag for channel x Writing a 1 into this bit clears TCIFx in the MDMA_ISRy register
        CLTCIF2: u1,
        padding: u27 = 0,
    }),
    /// MDMA Channel x error status register
    /// offset: 0xc8
    MDMA_C2ESR: mmio.Mmio(packed struct(u32) {
        /// Transfer Error Address These bits are set and cleared by HW, in case of an MDMA data transfer error. It is used in conjunction with TED. This field indicates the 7 LSBits of the address which generated a transfer/access error. It may be used by SW to retrieve the failing address, by adding this value (truncated to the buffer transfer length size) to the current SAR/DAR value. Note: The SAR/DAR current value doesnt reflect this last address due to the FIFO management system. The SAR/DAR are only updated at the end of a (buffer) transfer (of TLEN+1 bytes). Note: It is not set in case of a link data error.
        TEA: u7,
        /// Transfer Error Direction These bit is set and cleared by HW, in case of an MDMA data transfer error.
        TED: u1,
        /// Transfer Error Link Data These bit is set by HW, in case of a transfer error while reading the block link data structure. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TELD: u1,
        /// Transfer Error Mask Data These bit is set by HW, in case of a transfer error while writing the Mask Data. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TEMD: u1,
        /// Address/Size Error These bit is set by HW, when the programmed address is not aligned with the data size. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        ASE: u1,
        /// Block Size Error These bit is set by HW, when the block size is not an integer multiple of the data size either for source or destination. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        BSE: u1,
        padding: u20 = 0,
    }),
    /// This register is used to control the concerned channel.
    /// offset: 0xcc
    MDMA_C2CR: mmio.Mmio(packed struct(u32) {
        /// channel enable
        EN: u1,
        /// Transfer error interrupt enable This bit is set and cleared by software.
        TEIE: u1,
        /// Channel Transfer Complete interrupt enable This bit is set and cleared by software.
        CTCIE: u1,
        /// Block Repeat transfer interrupt enable This bit is set and cleared by software.
        BRTIE: u1,
        /// Block Transfer interrupt enable This bit is set and cleared by software.
        BTIE: u1,
        /// buffer Transfer Complete interrupt enable This bit is set and cleared by software.
        TCIE: u1,
        /// Priority level These bits are set and cleared by software. These bits are protected and can be written only if EN is 0.
        PL: u2,
        reserved12: u4 = 0,
        /// byte Endianness exchange
        BEX: u1,
        /// Half word Endianes exchange
        HEX: u1,
        /// Word Endianness exchange
        WEX: u1,
        reserved16: u1 = 0,
        /// SW ReQuest Writing a 1 into this bit sets the CRQAx in MDMA_ISRy register, activating the request on Channel x Note: Either the whole CxCR register or the 8-bit/16-bit register @ Address offset: 0x4E + 0x40 chn may be used for SWRQ activation. In case of a SW request, acknowledge is not generated (neither HW signal, nor CxMAR write access).
        SWRQ: u1,
        padding: u15 = 0,
    }),
    /// This register is used to configure the concerned channel.
    /// offset: 0xd0
    MDMA_C2TCR: mmio.Mmio(packed struct(u32) {
        /// Source increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When source is AHB (SBUS=1), SINC = 00 is forbidden. In Linked List Mode, at the end of a block (single or last block in repeated block transfer mode), this register will be loaded from memory (from address given by current LAR[31:0] + 0x00).
        SINC: u2,
        /// Destination increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When destination is AHB (DBUS=1), DINC = 00 is forbidden.
        DINC: u2,
        /// Source data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If SINCOS &lt; SSIZE and SINC &#8800; 00, the result will be unpredictable. Note: SSIZE = 11 (double-word) is forbidden when source is TCM/AHB bus (SBUS=1).
        SSIZE: u2,
        /// Destination data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0. Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If DINCOS &lt; DSIZE and DINC &#8800; 00, the result will be unpredictable. Note: DSIZE = 11 (double-word) is forbidden when destination is TCM/AHB bus (DBUS=1).
        DSIZE: u2,
        /// source increment offset size
        SINCOS: u2,
        /// Destination increment offset
        DINCOS: u2,
        /// source burst transfer configuration
        SBURST: u3,
        /// Destination burst transfer configuration
        DBURST: u3,
        /// buffer transfer lengh
        TLEN: u7,
        /// PacK Enable These bit is set and cleared by software. If the Source Size is smaller than the destination, it will be padded according to the PAM value. If the Source data size is larger than the destination one, it will be truncated. The alignment will be done according to the PAM[0] value. This bit is protected and can be written only if EN is 0
        PKE: u1,
        /// Padding/Alignement Mode These bits are set and cleared by software. Case 1: Source data size smaller than destination data size - 3 options are valid. Case 2: Source data size larger than destination data size. The remainder part is discarded. When PKE = 1 or DSIZE=SSIZE, these bits are ignored. These bits are protected and can be written only if EN is 0
        PAM: u2,
        /// Trigger Mode These bits are set and cleared by software. Note: If TRGM is 11 for the current block, all the values loaded at the end of the current block through the linked list mechanism must keep the same value (TRGM=11) and the same SWRM value, otherwise the result is undefined. These bits are protected and can be written only if EN is 0.
        TRGM: u2,
        /// SW Request Mode This bit is set and cleared by software. If a HW or SW request is currently active, the bit change will be delayed until the current transfer is completed. If the CxMAR contains a valid address, the CxMDR value will also be written @ CxMAR address. This bit is protected and can be written only if EN is 0.
        SWRM: u1,
        /// Bufferable Write Mode This bit is set and cleared by software. This bit is protected and can be written only if EN is 0. Note: All MDMA destination accesses are non-cacheable.
        BWM: u1,
    }),
    /// MDMA Channel x block number of data register
    /// offset: 0xd4
    MDMA_C2BNDTR: mmio.Mmio(packed struct(u32) {
        /// block number of data to transfer
        BNDT: u17,
        reserved18: u1 = 0,
        /// Block Repeat Source address Update Mode These bits are protected and can be written only if EN is 0.
        BRSUM: u1,
        /// Block Repeat Destination address Update Mode These bits are protected and can be written only if EN is 0.
        BRDUM: u1,
        /// Block Repeat Count This field contains the number of repetitions of the current block (0 to 4095). When the channel is enabled, this register is read-only, indicating the remaining number of blocks, excluding the current one. This register decrements after each complete block transfer. Once the last block transfer has completed, this register can either stay at zero or be reloaded automatically from memory (in Linked List mode - i.e. Link Address valid). These bits are protected and can be written only if EN is 0.
        BRC: u12,
    }),
    /// MDMA channel x source address register
    /// offset: 0xd8
    MDMA_C2SAR: mmio.Mmio(packed struct(u32) {
        /// source adr base
        SAR: u32,
    }),
    /// MDMA channel x destination address register
    /// offset: 0xdc
    MDMA_C2DAR: mmio.Mmio(packed struct(u32) {
        /// Destination adr base
        DAR: u32,
    }),
    /// MDMA channel x Block Repeat address Update register
    /// offset: 0xe0
    MDMA_C2BRUR: mmio.Mmio(packed struct(u32) {
        /// source adresse update value
        SUV: u16,
        /// destination address update
        DUV: u16,
    }),
    /// MDMA channel x Link Address register
    /// offset: 0xe4
    MDMA_C2LAR: mmio.Mmio(packed struct(u32) {
        /// Link address register
        LAR: u32,
    }),
    /// MDMA channel x Trigger and Bus selection Register
    /// offset: 0xe8
    MDMA_C2TBR: mmio.Mmio(packed struct(u32) {
        /// Trigger selection
        TSEL: u6,
        reserved16: u10 = 0,
        /// Source BUS select This bit is protected and can be written only if EN is 0.
        SBUS: u1,
        /// Destination BUS slect This bit is protected and can be written only if EN is 0.
        DBUS: u1,
        padding: u14 = 0,
    }),
    /// offset: 0xec
    reserved236: [4]u8,
    /// MDMA channel x Mask address register
    /// offset: 0xf0
    MDMA_C2MAR: mmio.Mmio(packed struct(u32) {
        /// Mask address
        MAR: u32,
    }),
    /// MDMA channel x Mask Data register
    /// offset: 0xf4
    MDMA_C2MDR: mmio.Mmio(packed struct(u32) {
        /// Mask data
        MDR: u32,
    }),
    /// offset: 0xf8
    reserved248: [8]u8,
    /// MDMA channel x interrupt/status register
    /// offset: 0x100
    MDMA_C3ISR: mmio.Mmio(packed struct(u32) {
        /// Channel x transfer error interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        TEIF3: u1,
        /// Channel x Channel Transfer Complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register. CTC is set when the last block was transferred and the channel has been automatically disabled. CTC is also set when the channel is suspended, as a result of writing EN bit to 0.
        CTCIF3: u1,
        /// Channel x block repeat transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BRTIF3: u1,
        /// Channel x block transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BTIF3: u1,
        /// channel x buffer transfer complete
        TCIF3: u1,
        reserved16: u11 = 0,
        /// channel x request active flag
        CRQA3: u1,
        padding: u15 = 0,
    }),
    /// MDMA channel x interrupt flag clear register
    /// offset: 0x104
    MDMA_C3IFCR: mmio.Mmio(packed struct(u32) {
        /// Channel x clear transfer error interrupt flag Writing a 1 into this bit clears TEIFx in the MDMA_ISRy register
        CTEIF3: u1,
        /// Clear Channel transfer complete interrupt flag for channel x Writing a 1 into this bit clears CTCIFx in the MDMA_ISRy register
        CCTCIF3: u1,
        /// Channel x clear block repeat transfer complete interrupt flag Writing a 1 into this bit clears BRTIFx in the MDMA_ISRy register
        CBRTIF3: u1,
        /// Channel x Clear block transfer complete interrupt flag Writing a 1 into this bit clears BTIFx in the MDMA_ISRy register
        CBTIF3: u1,
        /// CLear buffer Transfer Complete Interrupt Flag for channel x Writing a 1 into this bit clears TCIFx in the MDMA_ISRy register
        CLTCIF3: u1,
        padding: u27 = 0,
    }),
    /// MDMA Channel x error status register
    /// offset: 0x108
    MDMA_C3ESR: mmio.Mmio(packed struct(u32) {
        /// Transfer Error Address These bits are set and cleared by HW, in case of an MDMA data transfer error. It is used in conjunction with TED. This field indicates the 7 LSBits of the address which generated a transfer/access error. It may be used by SW to retrieve the failing address, by adding this value (truncated to the buffer transfer length size) to the current SAR/DAR value. Note: The SAR/DAR current value doesnt reflect this last address due to the FIFO management system. The SAR/DAR are only updated at the end of a (buffer) transfer (of TLEN+1 bytes). Note: It is not set in case of a link data error.
        TEA: u7,
        /// Transfer Error Direction These bit is set and cleared by HW, in case of an MDMA data transfer error.
        TED: u1,
        /// Transfer Error Link Data These bit is set by HW, in case of a transfer error while reading the block link data structure. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TELD: u1,
        /// Transfer Error Mask Data These bit is set by HW, in case of a transfer error while writing the Mask Data. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TEMD: u1,
        /// Address/Size Error These bit is set by HW, when the programmed address is not aligned with the data size. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        ASE: u1,
        /// Block Size Error These bit is set by HW, when the block size is not an integer multiple of the data size either for source or destination. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        BSE: u1,
        padding: u20 = 0,
    }),
    /// This register is used to control the concerned channel.
    /// offset: 0x10c
    MDMA_C3CR: mmio.Mmio(packed struct(u32) {
        /// channel enable
        EN: u1,
        /// Transfer error interrupt enable This bit is set and cleared by software.
        TEIE: u1,
        /// Channel Transfer Complete interrupt enable This bit is set and cleared by software.
        CTCIE: u1,
        /// Block Repeat transfer interrupt enable This bit is set and cleared by software.
        BRTIE: u1,
        /// Block Transfer interrupt enable This bit is set and cleared by software.
        BTIE: u1,
        /// buffer Transfer Complete interrupt enable This bit is set and cleared by software.
        TCIE: u1,
        /// Priority level These bits are set and cleared by software. These bits are protected and can be written only if EN is 0.
        PL: u2,
        reserved12: u4 = 0,
        /// byte Endianness exchange
        BEX: u1,
        /// Half word Endianes exchange
        HEX: u1,
        /// Word Endianness exchange
        WEX: u1,
        reserved16: u1 = 0,
        /// SW ReQuest Writing a 1 into this bit sets the CRQAx in MDMA_ISRy register, activating the request on Channel x Note: Either the whole CxCR register or the 8-bit/16-bit register @ Address offset: 0x4E + 0x40 chn may be used for SWRQ activation. In case of a SW request, acknowledge is not generated (neither HW signal, nor CxMAR write access).
        SWRQ: u1,
        padding: u15 = 0,
    }),
    /// This register is used to configure the concerned channel.
    /// offset: 0x110
    MDMA_C3TCR: mmio.Mmio(packed struct(u32) {
        /// Source increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When source is AHB (SBUS=1), SINC = 00 is forbidden. In Linked List Mode, at the end of a block (single or last block in repeated block transfer mode), this register will be loaded from memory (from address given by current LAR[31:0] + 0x00).
        SINC: u2,
        /// Destination increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When destination is AHB (DBUS=1), DINC = 00 is forbidden.
        DINC: u2,
        /// Source data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If SINCOS &lt; SSIZE and SINC &#8800; 00, the result will be unpredictable. Note: SSIZE = 11 (double-word) is forbidden when source is TCM/AHB bus (SBUS=1).
        SSIZE: u2,
        /// Destination data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0. Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If DINCOS &lt; DSIZE and DINC &#8800; 00, the result will be unpredictable. Note: DSIZE = 11 (double-word) is forbidden when destination is TCM/AHB bus (DBUS=1).
        DSIZE: u2,
        /// source increment offset size
        SINCOS: u2,
        /// Destination increment offset
        DINCOS: u2,
        /// source burst transfer configuration
        SBURST: u3,
        /// Destination burst transfer configuration
        DBURST: u3,
        /// buffer transfer lengh
        TLEN: u7,
        /// PacK Enable These bit is set and cleared by software. If the Source Size is smaller than the destination, it will be padded according to the PAM value. If the Source data size is larger than the destination one, it will be truncated. The alignment will be done according to the PAM[0] value. This bit is protected and can be written only if EN is 0
        PKE: u1,
        /// Padding/Alignement Mode These bits are set and cleared by software. Case 1: Source data size smaller than destination data size - 3 options are valid. Case 2: Source data size larger than destination data size. The remainder part is discarded. When PKE = 1 or DSIZE=SSIZE, these bits are ignored. These bits are protected and can be written only if EN is 0
        PAM: u2,
        /// Trigger Mode These bits are set and cleared by software. Note: If TRGM is 11 for the current block, all the values loaded at the end of the current block through the linked list mechanism must keep the same value (TRGM=11) and the same SWRM value, otherwise the result is undefined. These bits are protected and can be written only if EN is 0.
        TRGM: u2,
        /// SW Request Mode This bit is set and cleared by software. If a HW or SW request is currently active, the bit change will be delayed until the current transfer is completed. If the CxMAR contains a valid address, the CxMDR value will also be written @ CxMAR address. This bit is protected and can be written only if EN is 0.
        SWRM: u1,
        /// Bufferable Write Mode This bit is set and cleared by software. This bit is protected and can be written only if EN is 0. Note: All MDMA destination accesses are non-cacheable.
        BWM: u1,
    }),
    /// MDMA Channel x block number of data register
    /// offset: 0x114
    MDMA_C3BNDTR: mmio.Mmio(packed struct(u32) {
        /// block number of data to transfer
        BNDT: u17,
        reserved18: u1 = 0,
        /// Block Repeat Source address Update Mode These bits are protected and can be written only if EN is 0.
        BRSUM: u1,
        /// Block Repeat Destination address Update Mode These bits are protected and can be written only if EN is 0.
        BRDUM: u1,
        /// Block Repeat Count This field contains the number of repetitions of the current block (0 to 4095). When the channel is enabled, this register is read-only, indicating the remaining number of blocks, excluding the current one. This register decrements after each complete block transfer. Once the last block transfer has completed, this register can either stay at zero or be reloaded automatically from memory (in Linked List mode - i.e. Link Address valid). These bits are protected and can be written only if EN is 0.
        BRC: u12,
    }),
    /// MDMA channel x source address register
    /// offset: 0x118
    MDMA_C3SAR: mmio.Mmio(packed struct(u32) {
        /// source adr base
        SAR: u32,
    }),
    /// MDMA channel x destination address register
    /// offset: 0x11c
    MDMA_C3DAR: mmio.Mmio(packed struct(u32) {
        /// Destination adr base
        DAR: u32,
    }),
    /// MDMA channel x Block Repeat address Update register
    /// offset: 0x120
    MDMA_C3BRUR: mmio.Mmio(packed struct(u32) {
        /// source adresse update value
        SUV: u16,
        /// destination address update
        DUV: u16,
    }),
    /// MDMA channel x Link Address register
    /// offset: 0x124
    MDMA_C3LAR: mmio.Mmio(packed struct(u32) {
        /// Link address register
        LAR: u32,
    }),
    /// MDMA channel x Trigger and Bus selection Register
    /// offset: 0x128
    MDMA_C3TBR: mmio.Mmio(packed struct(u32) {
        /// Trigger selection
        TSEL: u6,
        reserved16: u10 = 0,
        /// Source BUS select This bit is protected and can be written only if EN is 0.
        SBUS: u1,
        /// Destination BUS slect This bit is protected and can be written only if EN is 0.
        DBUS: u1,
        padding: u14 = 0,
    }),
    /// offset: 0x12c
    reserved300: [4]u8,
    /// MDMA channel x Mask address register
    /// offset: 0x130
    MDMA_C3MAR: mmio.Mmio(packed struct(u32) {
        /// Mask address
        MAR: u32,
    }),
    /// MDMA channel x Mask Data register
    /// offset: 0x134
    MDMA_C3MDR: mmio.Mmio(packed struct(u32) {
        /// Mask data
        MDR: u32,
    }),
    /// offset: 0x138
    reserved312: [8]u8,
    /// MDMA channel x interrupt/status register
    /// offset: 0x140
    MDMA_C4ISR: mmio.Mmio(packed struct(u32) {
        /// Channel x transfer error interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        TEIF4: u1,
        /// Channel x Channel Transfer Complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register. CTC is set when the last block was transferred and the channel has been automatically disabled. CTC is also set when the channel is suspended, as a result of writing EN bit to 0.
        CTCIF4: u1,
        /// Channel x block repeat transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BRTIF4: u1,
        /// Channel x block transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BTIF4: u1,
        /// channel x buffer transfer complete
        TCIF4: u1,
        reserved16: u11 = 0,
        /// channel x request active flag
        CRQA4: u1,
        padding: u15 = 0,
    }),
    /// MDMA channel x interrupt flag clear register
    /// offset: 0x144
    MDMA_C4IFCR: mmio.Mmio(packed struct(u32) {
        /// Channel x clear transfer error interrupt flag Writing a 1 into this bit clears TEIFx in the MDMA_ISRy register
        CTEIF4: u1,
        /// Clear Channel transfer complete interrupt flag for channel x Writing a 1 into this bit clears CTCIFx in the MDMA_ISRy register
        CCTCIF4: u1,
        /// Channel x clear block repeat transfer complete interrupt flag Writing a 1 into this bit clears BRTIFx in the MDMA_ISRy register
        CBRTIF4: u1,
        /// Channel x Clear block transfer complete interrupt flag Writing a 1 into this bit clears BTIFx in the MDMA_ISRy register
        CBTIF4: u1,
        /// CLear buffer Transfer Complete Interrupt Flag for channel x Writing a 1 into this bit clears TCIFx in the MDMA_ISRy register
        CLTCIF4: u1,
        padding: u27 = 0,
    }),
    /// MDMA Channel x error status register
    /// offset: 0x148
    MDMA_C4ESR: mmio.Mmio(packed struct(u32) {
        /// Transfer Error Address These bits are set and cleared by HW, in case of an MDMA data transfer error. It is used in conjunction with TED. This field indicates the 7 LSBits of the address which generated a transfer/access error. It may be used by SW to retrieve the failing address, by adding this value (truncated to the buffer transfer length size) to the current SAR/DAR value. Note: The SAR/DAR current value doesnt reflect this last address due to the FIFO management system. The SAR/DAR are only updated at the end of a (buffer) transfer (of TLEN+1 bytes). Note: It is not set in case of a link data error.
        TEA: u7,
        /// Transfer Error Direction These bit is set and cleared by HW, in case of an MDMA data transfer error.
        TED: u1,
        /// Transfer Error Link Data These bit is set by HW, in case of a transfer error while reading the block link data structure. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TELD: u1,
        /// Transfer Error Mask Data These bit is set by HW, in case of a transfer error while writing the Mask Data. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TEMD: u1,
        /// Address/Size Error These bit is set by HW, when the programmed address is not aligned with the data size. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        ASE: u1,
        /// Block Size Error These bit is set by HW, when the block size is not an integer multiple of the data size either for source or destination. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        BSE: u1,
        padding: u20 = 0,
    }),
    /// This register is used to control the concerned channel.
    /// offset: 0x14c
    MDMA_C4CR: mmio.Mmio(packed struct(u32) {
        /// channel enable
        EN: u1,
        /// Transfer error interrupt enable This bit is set and cleared by software.
        TEIE: u1,
        /// Channel Transfer Complete interrupt enable This bit is set and cleared by software.
        CTCIE: u1,
        /// Block Repeat transfer interrupt enable This bit is set and cleared by software.
        BRTIE: u1,
        /// Block Transfer interrupt enable This bit is set and cleared by software.
        BTIE: u1,
        /// buffer Transfer Complete interrupt enable This bit is set and cleared by software.
        TCIE: u1,
        /// Priority level These bits are set and cleared by software. These bits are protected and can be written only if EN is 0.
        PL: u2,
        reserved12: u4 = 0,
        /// byte Endianness exchange
        BEX: u1,
        /// Half word Endianes exchange
        HEX: u1,
        /// Word Endianness exchange
        WEX: u1,
        reserved16: u1 = 0,
        /// SW ReQuest Writing a 1 into this bit sets the CRQAx in MDMA_ISRy register, activating the request on Channel x Note: Either the whole CxCR register or the 8-bit/16-bit register @ Address offset: 0x4E + 0x40 chn may be used for SWRQ activation. In case of a SW request, acknowledge is not generated (neither HW signal, nor CxMAR write access).
        SWRQ: u1,
        padding: u15 = 0,
    }),
    /// This register is used to configure the concerned channel.
    /// offset: 0x150
    MDMA_C4TCR: mmio.Mmio(packed struct(u32) {
        /// Source increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When source is AHB (SBUS=1), SINC = 00 is forbidden. In Linked List Mode, at the end of a block (single or last block in repeated block transfer mode), this register will be loaded from memory (from address given by current LAR[31:0] + 0x00).
        SINC: u2,
        /// Destination increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When destination is AHB (DBUS=1), DINC = 00 is forbidden.
        DINC: u2,
        /// Source data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If SINCOS &lt; SSIZE and SINC &#8800; 00, the result will be unpredictable. Note: SSIZE = 11 (double-word) is forbidden when source is TCM/AHB bus (SBUS=1).
        SSIZE: u2,
        /// Destination data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0. Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If DINCOS &lt; DSIZE and DINC &#8800; 00, the result will be unpredictable. Note: DSIZE = 11 (double-word) is forbidden when destination is TCM/AHB bus (DBUS=1).
        DSIZE: u2,
        /// source increment offset size
        SINCOS: u2,
        /// Destination increment offset
        DINCOS: u2,
        /// source burst transfer configuration
        SBURST: u3,
        /// Destination burst transfer configuration
        DBURST: u3,
        /// buffer transfer lengh
        TLEN: u7,
        /// PacK Enable These bit is set and cleared by software. If the Source Size is smaller than the destination, it will be padded according to the PAM value. If the Source data size is larger than the destination one, it will be truncated. The alignment will be done according to the PAM[0] value. This bit is protected and can be written only if EN is 0
        PKE: u1,
        /// Padding/Alignement Mode These bits are set and cleared by software. Case 1: Source data size smaller than destination data size - 3 options are valid. Case 2: Source data size larger than destination data size. The remainder part is discarded. When PKE = 1 or DSIZE=SSIZE, these bits are ignored. These bits are protected and can be written only if EN is 0
        PAM: u2,
        /// Trigger Mode These bits are set and cleared by software. Note: If TRGM is 11 for the current block, all the values loaded at the end of the current block through the linked list mechanism must keep the same value (TRGM=11) and the same SWRM value, otherwise the result is undefined. These bits are protected and can be written only if EN is 0.
        TRGM: u2,
        /// SW Request Mode This bit is set and cleared by software. If a HW or SW request is currently active, the bit change will be delayed until the current transfer is completed. If the CxMAR contains a valid address, the CxMDR value will also be written @ CxMAR address. This bit is protected and can be written only if EN is 0.
        SWRM: u1,
        /// Bufferable Write Mode This bit is set and cleared by software. This bit is protected and can be written only if EN is 0. Note: All MDMA destination accesses are non-cacheable.
        BWM: u1,
    }),
    /// MDMA Channel x block number of data register
    /// offset: 0x154
    MDMA_C4BNDTR: mmio.Mmio(packed struct(u32) {
        /// block number of data to transfer
        BNDT: u17,
        reserved18: u1 = 0,
        /// Block Repeat Source address Update Mode These bits are protected and can be written only if EN is 0.
        BRSUM: u1,
        /// Block Repeat Destination address Update Mode These bits are protected and can be written only if EN is 0.
        BRDUM: u1,
        /// Block Repeat Count This field contains the number of repetitions of the current block (0 to 4095). When the channel is enabled, this register is read-only, indicating the remaining number of blocks, excluding the current one. This register decrements after each complete block transfer. Once the last block transfer has completed, this register can either stay at zero or be reloaded automatically from memory (in Linked List mode - i.e. Link Address valid). These bits are protected and can be written only if EN is 0.
        BRC: u12,
    }),
    /// MDMA channel x source address register
    /// offset: 0x158
    MDMA_C4SAR: mmio.Mmio(packed struct(u32) {
        /// source adr base
        SAR: u32,
    }),
    /// MDMA channel x destination address register
    /// offset: 0x15c
    MDMA_C4DAR: mmio.Mmio(packed struct(u32) {
        /// Destination adr base
        DAR: u32,
    }),
    /// MDMA channel x Block Repeat address Update register
    /// offset: 0x160
    MDMA_C4BRUR: mmio.Mmio(packed struct(u32) {
        /// source adresse update value
        SUV: u16,
        /// destination address update
        DUV: u16,
    }),
    /// MDMA channel x Link Address register
    /// offset: 0x164
    MDMA_C4LAR: mmio.Mmio(packed struct(u32) {
        /// Link address register
        LAR: u32,
    }),
    /// MDMA channel x Trigger and Bus selection Register
    /// offset: 0x168
    MDMA_C4TBR: mmio.Mmio(packed struct(u32) {
        /// Trigger selection
        TSEL: u6,
        reserved16: u10 = 0,
        /// Source BUS select This bit is protected and can be written only if EN is 0.
        SBUS: u1,
        /// Destination BUS slect This bit is protected and can be written only if EN is 0.
        DBUS: u1,
        padding: u14 = 0,
    }),
    /// offset: 0x16c
    reserved364: [4]u8,
    /// MDMA channel x Mask address register
    /// offset: 0x170
    MDMA_C4MAR: mmio.Mmio(packed struct(u32) {
        /// Mask address
        MAR: u32,
    }),
    /// MDMA channel x Mask Data register
    /// offset: 0x174
    MDMA_C4MDR: mmio.Mmio(packed struct(u32) {
        /// Mask data
        MDR: u32,
    }),
    /// offset: 0x178
    reserved376: [8]u8,
    /// MDMA channel x interrupt/status register
    /// offset: 0x180
    MDMA_C5ISR: mmio.Mmio(packed struct(u32) {
        /// Channel x transfer error interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        TEIF5: u1,
        /// Channel x Channel Transfer Complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register. CTC is set when the last block was transferred and the channel has been automatically disabled. CTC is also set when the channel is suspended, as a result of writing EN bit to 0.
        CTCIF5: u1,
        /// Channel x block repeat transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BRTIF5: u1,
        /// Channel x block transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BTIF5: u1,
        /// channel x buffer transfer complete
        TCIF5: u1,
        reserved16: u11 = 0,
        /// channel x request active flag
        CRQA5: u1,
        padding: u15 = 0,
    }),
    /// MDMA channel x interrupt flag clear register
    /// offset: 0x184
    MDMA_C5IFCR: mmio.Mmio(packed struct(u32) {
        /// Channel x clear transfer error interrupt flag Writing a 1 into this bit clears TEIFx in the MDMA_ISRy register
        CTEIF5: u1,
        /// Clear Channel transfer complete interrupt flag for channel x Writing a 1 into this bit clears CTCIFx in the MDMA_ISRy register
        CCTCIF5: u1,
        /// Channel x clear block repeat transfer complete interrupt flag Writing a 1 into this bit clears BRTIFx in the MDMA_ISRy register
        CBRTIF5: u1,
        /// Channel x Clear block transfer complete interrupt flag Writing a 1 into this bit clears BTIFx in the MDMA_ISRy register
        CBTIF5: u1,
        /// CLear buffer Transfer Complete Interrupt Flag for channel x Writing a 1 into this bit clears TCIFx in the MDMA_ISRy register
        CLTCIF5: u1,
        padding: u27 = 0,
    }),
    /// MDMA Channel x error status register
    /// offset: 0x188
    MDMA_C5ESR: mmio.Mmio(packed struct(u32) {
        /// Transfer Error Address These bits are set and cleared by HW, in case of an MDMA data transfer error. It is used in conjunction with TED. This field indicates the 7 LSBits of the address which generated a transfer/access error. It may be used by SW to retrieve the failing address, by adding this value (truncated to the buffer transfer length size) to the current SAR/DAR value. Note: The SAR/DAR current value doesnt reflect this last address due to the FIFO management system. The SAR/DAR are only updated at the end of a (buffer) transfer (of TLEN+1 bytes). Note: It is not set in case of a link data error.
        TEA: u7,
        /// Transfer Error Direction These bit is set and cleared by HW, in case of an MDMA data transfer error.
        TED: u1,
        /// Transfer Error Link Data These bit is set by HW, in case of a transfer error while reading the block link data structure. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TELD: u1,
        /// Transfer Error Mask Data These bit is set by HW, in case of a transfer error while writing the Mask Data. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TEMD: u1,
        /// Address/Size Error These bit is set by HW, when the programmed address is not aligned with the data size. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        ASE: u1,
        /// Block Size Error These bit is set by HW, when the block size is not an integer multiple of the data size either for source or destination. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        BSE: u1,
        padding: u20 = 0,
    }),
    /// This register is used to control the concerned channel.
    /// offset: 0x18c
    MDMA_C5CR: mmio.Mmio(packed struct(u32) {
        /// channel enable
        EN: u1,
        /// Transfer error interrupt enable This bit is set and cleared by software.
        TEIE: u1,
        /// Channel Transfer Complete interrupt enable This bit is set and cleared by software.
        CTCIE: u1,
        /// Block Repeat transfer interrupt enable This bit is set and cleared by software.
        BRTIE: u1,
        /// Block Transfer interrupt enable This bit is set and cleared by software.
        BTIE: u1,
        /// buffer Transfer Complete interrupt enable This bit is set and cleared by software.
        TCIE: u1,
        /// Priority level These bits are set and cleared by software. These bits are protected and can be written only if EN is 0.
        PL: u2,
        reserved12: u4 = 0,
        /// byte Endianness exchange
        BEX: u1,
        /// Half word Endianes exchange
        HEX: u1,
        /// Word Endianness exchange
        WEX: u1,
        reserved16: u1 = 0,
        /// SW ReQuest Writing a 1 into this bit sets the CRQAx in MDMA_ISRy register, activating the request on Channel x Note: Either the whole CxCR register or the 8-bit/16-bit register @ Address offset: 0x4E + 0x40 chn may be used for SWRQ activation. In case of a SW request, acknowledge is not generated (neither HW signal, nor CxMAR write access).
        SWRQ: u1,
        padding: u15 = 0,
    }),
    /// This register is used to configure the concerned channel.
    /// offset: 0x190
    MDMA_C5TCR: mmio.Mmio(packed struct(u32) {
        /// Source increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When source is AHB (SBUS=1), SINC = 00 is forbidden. In Linked List Mode, at the end of a block (single or last block in repeated block transfer mode), this register will be loaded from memory (from address given by current LAR[31:0] + 0x00).
        SINC: u2,
        /// Destination increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When destination is AHB (DBUS=1), DINC = 00 is forbidden.
        DINC: u2,
        /// Source data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If SINCOS &lt; SSIZE and SINC &#8800; 00, the result will be unpredictable. Note: SSIZE = 11 (double-word) is forbidden when source is TCM/AHB bus (SBUS=1).
        SSIZE: u2,
        /// Destination data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0. Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If DINCOS &lt; DSIZE and DINC &#8800; 00, the result will be unpredictable. Note: DSIZE = 11 (double-word) is forbidden when destination is TCM/AHB bus (DBUS=1).
        DSIZE: u2,
        /// source increment offset size
        SINCOS: u2,
        /// Destination increment offset
        DINCOS: u2,
        /// source burst transfer configuration
        SBURST: u3,
        /// Destination burst transfer configuration
        DBURST: u3,
        /// buffer transfer lengh
        TLEN: u7,
        /// PacK Enable These bit is set and cleared by software. If the Source Size is smaller than the destination, it will be padded according to the PAM value. If the Source data size is larger than the destination one, it will be truncated. The alignment will be done according to the PAM[0] value. This bit is protected and can be written only if EN is 0
        PKE: u1,
        /// Padding/Alignement Mode These bits are set and cleared by software. Case 1: Source data size smaller than destination data size - 3 options are valid. Case 2: Source data size larger than destination data size. The remainder part is discarded. When PKE = 1 or DSIZE=SSIZE, these bits are ignored. These bits are protected and can be written only if EN is 0
        PAM: u2,
        /// Trigger Mode These bits are set and cleared by software. Note: If TRGM is 11 for the current block, all the values loaded at the end of the current block through the linked list mechanism must keep the same value (TRGM=11) and the same SWRM value, otherwise the result is undefined. These bits are protected and can be written only if EN is 0.
        TRGM: u2,
        /// SW Request Mode This bit is set and cleared by software. If a HW or SW request is currently active, the bit change will be delayed until the current transfer is completed. If the CxMAR contains a valid address, the CxMDR value will also be written @ CxMAR address. This bit is protected and can be written only if EN is 0.
        SWRM: u1,
        /// Bufferable Write Mode This bit is set and cleared by software. This bit is protected and can be written only if EN is 0. Note: All MDMA destination accesses are non-cacheable.
        BWM: u1,
    }),
    /// MDMA Channel x block number of data register
    /// offset: 0x194
    MDMA_C5BNDTR: mmio.Mmio(packed struct(u32) {
        /// block number of data to transfer
        BNDT: u17,
        reserved18: u1 = 0,
        /// Block Repeat Source address Update Mode These bits are protected and can be written only if EN is 0.
        BRSUM: u1,
        /// Block Repeat Destination address Update Mode These bits are protected and can be written only if EN is 0.
        BRDUM: u1,
        /// Block Repeat Count This field contains the number of repetitions of the current block (0 to 4095). When the channel is enabled, this register is read-only, indicating the remaining number of blocks, excluding the current one. This register decrements after each complete block transfer. Once the last block transfer has completed, this register can either stay at zero or be reloaded automatically from memory (in Linked List mode - i.e. Link Address valid). These bits are protected and can be written only if EN is 0.
        BRC: u12,
    }),
    /// MDMA channel x source address register
    /// offset: 0x198
    MDMA_C5SAR: mmio.Mmio(packed struct(u32) {
        /// source adr base
        SAR: u32,
    }),
    /// MDMA channel x destination address register
    /// offset: 0x19c
    MDMA_C5DAR: mmio.Mmio(packed struct(u32) {
        /// Destination adr base
        DAR: u32,
    }),
    /// MDMA channel x Block Repeat address Update register
    /// offset: 0x1a0
    MDMA_C5BRUR: mmio.Mmio(packed struct(u32) {
        /// source adresse update value
        SUV: u16,
        /// destination address update
        DUV: u16,
    }),
    /// MDMA channel x Link Address register
    /// offset: 0x1a4
    MDMA_C5LAR: mmio.Mmio(packed struct(u32) {
        /// Link address register
        LAR: u32,
    }),
    /// MDMA channel x Trigger and Bus selection Register
    /// offset: 0x1a8
    MDMA_C5TBR: mmio.Mmio(packed struct(u32) {
        /// Trigger selection
        TSEL: u6,
        reserved16: u10 = 0,
        /// Source BUS select This bit is protected and can be written only if EN is 0.
        SBUS: u1,
        /// Destination BUS slect This bit is protected and can be written only if EN is 0.
        DBUS: u1,
        padding: u14 = 0,
    }),
    /// offset: 0x1ac
    reserved428: [4]u8,
    /// MDMA channel x Mask address register
    /// offset: 0x1b0
    MDMA_C5MAR: mmio.Mmio(packed struct(u32) {
        /// Mask address
        MAR: u32,
    }),
    /// MDMA channel x Mask Data register
    /// offset: 0x1b4
    MDMA_C5MDR: mmio.Mmio(packed struct(u32) {
        /// Mask data
        MDR: u32,
    }),
    /// offset: 0x1b8
    reserved440: [8]u8,
    /// MDMA channel x interrupt/status register
    /// offset: 0x1c0
    MDMA_C6ISR: mmio.Mmio(packed struct(u32) {
        /// Channel x transfer error interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        TEIF6: u1,
        /// Channel x Channel Transfer Complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register. CTC is set when the last block was transferred and the channel has been automatically disabled. CTC is also set when the channel is suspended, as a result of writing EN bit to 0.
        CTCIF6: u1,
        /// Channel x block repeat transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BRTIF6: u1,
        /// Channel x block transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BTIF6: u1,
        /// channel x buffer transfer complete
        TCIF6: u1,
        reserved16: u11 = 0,
        /// channel x request active flag
        CRQA6: u1,
        padding: u15 = 0,
    }),
    /// MDMA channel x interrupt flag clear register
    /// offset: 0x1c4
    MDMA_C6IFCR: mmio.Mmio(packed struct(u32) {
        /// Channel x clear transfer error interrupt flag Writing a 1 into this bit clears TEIFx in the MDMA_ISRy register
        CTEIF6: u1,
        /// Clear Channel transfer complete interrupt flag for channel x Writing a 1 into this bit clears CTCIFx in the MDMA_ISRy register
        CCTCIF6: u1,
        /// Channel x clear block repeat transfer complete interrupt flag Writing a 1 into this bit clears BRTIFx in the MDMA_ISRy register
        CBRTIF6: u1,
        /// Channel x Clear block transfer complete interrupt flag Writing a 1 into this bit clears BTIFx in the MDMA_ISRy register
        CBTIF6: u1,
        /// CLear buffer Transfer Complete Interrupt Flag for channel x Writing a 1 into this bit clears TCIFx in the MDMA_ISRy register
        CLTCIF6: u1,
        padding: u27 = 0,
    }),
    /// MDMA Channel x error status register
    /// offset: 0x1c8
    MDMA_C6ESR: mmio.Mmio(packed struct(u32) {
        /// Transfer Error Address These bits are set and cleared by HW, in case of an MDMA data transfer error. It is used in conjunction with TED. This field indicates the 7 LSBits of the address which generated a transfer/access error. It may be used by SW to retrieve the failing address, by adding this value (truncated to the buffer transfer length size) to the current SAR/DAR value. Note: The SAR/DAR current value doesnt reflect this last address due to the FIFO management system. The SAR/DAR are only updated at the end of a (buffer) transfer (of TLEN+1 bytes). Note: It is not set in case of a link data error.
        TEA: u7,
        /// Transfer Error Direction These bit is set and cleared by HW, in case of an MDMA data transfer error.
        TED: u1,
        /// Transfer Error Link Data These bit is set by HW, in case of a transfer error while reading the block link data structure. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TELD: u1,
        /// Transfer Error Mask Data These bit is set by HW, in case of a transfer error while writing the Mask Data. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TEMD: u1,
        /// Address/Size Error These bit is set by HW, when the programmed address is not aligned with the data size. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        ASE: u1,
        /// Block Size Error These bit is set by HW, when the block size is not an integer multiple of the data size either for source or destination. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        BSE: u1,
        padding: u20 = 0,
    }),
    /// This register is used to control the concerned channel.
    /// offset: 0x1cc
    MDMA_C6CR: mmio.Mmio(packed struct(u32) {
        /// channel enable
        EN: u1,
        /// Transfer error interrupt enable This bit is set and cleared by software.
        TEIE: u1,
        /// Channel Transfer Complete interrupt enable This bit is set and cleared by software.
        CTCIE: u1,
        /// Block Repeat transfer interrupt enable This bit is set and cleared by software.
        BRTIE: u1,
        /// Block Transfer interrupt enable This bit is set and cleared by software.
        BTIE: u1,
        /// buffer Transfer Complete interrupt enable This bit is set and cleared by software.
        TCIE: u1,
        /// Priority level These bits are set and cleared by software. These bits are protected and can be written only if EN is 0.
        PL: u2,
        reserved12: u4 = 0,
        /// byte Endianness exchange
        BEX: u1,
        /// Half word Endianes exchange
        HEX: u1,
        /// Word Endianness exchange
        WEX: u1,
        reserved16: u1 = 0,
        /// SW ReQuest Writing a 1 into this bit sets the CRQAx in MDMA_ISRy register, activating the request on Channel x Note: Either the whole CxCR register or the 8-bit/16-bit register @ Address offset: 0x4E + 0x40 chn may be used for SWRQ activation. In case of a SW request, acknowledge is not generated (neither HW signal, nor CxMAR write access).
        SWRQ: u1,
        padding: u15 = 0,
    }),
    /// This register is used to configure the concerned channel.
    /// offset: 0x1d0
    MDMA_C6TCR: mmio.Mmio(packed struct(u32) {
        /// Source increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When source is AHB (SBUS=1), SINC = 00 is forbidden. In Linked List Mode, at the end of a block (single or last block in repeated block transfer mode), this register will be loaded from memory (from address given by current LAR[31:0] + 0x00).
        SINC: u2,
        /// Destination increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When destination is AHB (DBUS=1), DINC = 00 is forbidden.
        DINC: u2,
        /// Source data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If SINCOS &lt; SSIZE and SINC &#8800; 00, the result will be unpredictable. Note: SSIZE = 11 (double-word) is forbidden when source is TCM/AHB bus (SBUS=1).
        SSIZE: u2,
        /// Destination data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0. Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If DINCOS &lt; DSIZE and DINC &#8800; 00, the result will be unpredictable. Note: DSIZE = 11 (double-word) is forbidden when destination is TCM/AHB bus (DBUS=1).
        DSIZE: u2,
        /// source increment offset size
        SINCOS: u2,
        /// Destination increment offset
        DINCOS: u2,
        /// source burst transfer configuration
        SBURST: u3,
        /// Destination burst transfer configuration
        DBURST: u3,
        /// buffer transfer lengh
        TLEN: u7,
        /// PacK Enable These bit is set and cleared by software. If the Source Size is smaller than the destination, it will be padded according to the PAM value. If the Source data size is larger than the destination one, it will be truncated. The alignment will be done according to the PAM[0] value. This bit is protected and can be written only if EN is 0
        PKE: u1,
        /// Padding/Alignement Mode These bits are set and cleared by software. Case 1: Source data size smaller than destination data size - 3 options are valid. Case 2: Source data size larger than destination data size. The remainder part is discarded. When PKE = 1 or DSIZE=SSIZE, these bits are ignored. These bits are protected and can be written only if EN is 0
        PAM: u2,
        /// Trigger Mode These bits are set and cleared by software. Note: If TRGM is 11 for the current block, all the values loaded at the end of the current block through the linked list mechanism must keep the same value (TRGM=11) and the same SWRM value, otherwise the result is undefined. These bits are protected and can be written only if EN is 0.
        TRGM: u2,
        /// SW Request Mode This bit is set and cleared by software. If a HW or SW request is currently active, the bit change will be delayed until the current transfer is completed. If the CxMAR contains a valid address, the CxMDR value will also be written @ CxMAR address. This bit is protected and can be written only if EN is 0.
        SWRM: u1,
        /// Bufferable Write Mode This bit is set and cleared by software. This bit is protected and can be written only if EN is 0. Note: All MDMA destination accesses are non-cacheable.
        BWM: u1,
    }),
    /// MDMA Channel x block number of data register
    /// offset: 0x1d4
    MDMA_C6BNDTR: mmio.Mmio(packed struct(u32) {
        /// block number of data to transfer
        BNDT: u17,
        reserved18: u1 = 0,
        /// Block Repeat Source address Update Mode These bits are protected and can be written only if EN is 0.
        BRSUM: u1,
        /// Block Repeat Destination address Update Mode These bits are protected and can be written only if EN is 0.
        BRDUM: u1,
        /// Block Repeat Count This field contains the number of repetitions of the current block (0 to 4095). When the channel is enabled, this register is read-only, indicating the remaining number of blocks, excluding the current one. This register decrements after each complete block transfer. Once the last block transfer has completed, this register can either stay at zero or be reloaded automatically from memory (in Linked List mode - i.e. Link Address valid). These bits are protected and can be written only if EN is 0
        BRC: u12,
    }),
    /// MDMA channel x source address register
    /// offset: 0x1d8
    MDMA_C6SAR: mmio.Mmio(packed struct(u32) {
        /// source adr base
        SAR: u32,
    }),
    /// MDMA channel x destination address register
    /// offset: 0x1dc
    MDMA_C6DAR: mmio.Mmio(packed struct(u32) {
        /// Destination adr base
        DAR: u32,
    }),
    /// MDMA channel x Block Repeat address Update register
    /// offset: 0x1e0
    MDMA_C6BRUR: mmio.Mmio(packed struct(u32) {
        /// source adresse update value
        SUV: u16,
        /// destination address update
        DUV: u16,
    }),
    /// MDMA channel x Link Address register
    /// offset: 0x1e4
    MDMA_C6LAR: mmio.Mmio(packed struct(u32) {
        /// Link address register
        LAR: u32,
    }),
    /// MDMA channel x Trigger and Bus selection Register
    /// offset: 0x1e8
    MDMA_C6TBR: mmio.Mmio(packed struct(u32) {
        /// Trigger selection
        TSEL: u6,
        reserved16: u10 = 0,
        /// Source BUS select This bit is protected and can be written only if EN is 0.
        SBUS: u1,
        /// Destination BUS slect This bit is protected and can be written only if EN is 0.
        DBUS: u1,
        padding: u14 = 0,
    }),
    /// offset: 0x1ec
    reserved492: [4]u8,
    /// MDMA channel x Mask address register
    /// offset: 0x1f0
    MDMA_C6MAR: mmio.Mmio(packed struct(u32) {
        /// Mask address
        MAR: u32,
    }),
    /// MDMA channel x Mask Data register
    /// offset: 0x1f4
    MDMA_C6MDR: mmio.Mmio(packed struct(u32) {
        /// Mask data
        MDR: u32,
    }),
    /// offset: 0x1f8
    reserved504: [8]u8,
    /// MDMA channel x interrupt/status register
    /// offset: 0x200
    MDMA_C7ISR: mmio.Mmio(packed struct(u32) {
        /// Channel x transfer error interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        TEIF7: u1,
        /// Channel x Channel Transfer Complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register. CTC is set when the last block was transferred and the channel has been automatically disabled. CTC is also set when the channel is suspended, as a result of writing EN bit to 0.
        CTCIF7: u1,
        /// Channel x block repeat transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BRTIF7: u1,
        /// Channel x block transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BTIF7: u1,
        /// channel x buffer transfer complete
        TCIF7: u1,
        reserved16: u11 = 0,
        /// channel x request active flag
        CRQA7: u1,
        padding: u15 = 0,
    }),
    /// MDMA channel x interrupt flag clear register
    /// offset: 0x204
    MDMA_C7IFCR: mmio.Mmio(packed struct(u32) {
        /// Channel x clear transfer error interrupt flag Writing a 1 into this bit clears TEIFx in the MDMA_ISRy register
        CTEIF7: u1,
        /// Clear Channel transfer complete interrupt flag for channel x Writing a 1 into this bit clears CTCIFx in the MDMA_ISRy register
        CCTCIF7: u1,
        /// Channel x clear block repeat transfer complete interrupt flag Writing a 1 into this bit clears BRTIFx in the MDMA_ISRy register
        CBRTIF7: u1,
        /// Channel x Clear block transfer complete interrupt flag Writing a 1 into this bit clears BTIFx in the MDMA_ISRy register
        CBTIF7: u1,
        /// CLear buffer Transfer Complete Interrupt Flag for channel x Writing a 1 into this bit clears TCIFx in the MDMA_ISRy register
        CLTCIF7: u1,
        padding: u27 = 0,
    }),
    /// MDMA Channel x error status register
    /// offset: 0x208
    MDMA_C7ESR: mmio.Mmio(packed struct(u32) {
        /// Transfer Error Address These bits are set and cleared by HW, in case of an MDMA data transfer error. It is used in conjunction with TED. This field indicates the 7 LSBits of the address which generated a transfer/access error. It may be used by SW to retrieve the failing address, by adding this value (truncated to the buffer transfer length size) to the current SAR/DAR value. Note: The SAR/DAR current value doesnt reflect this last address due to the FIFO management system. The SAR/DAR are only updated at the end of a (buffer) transfer (of TLEN+1 bytes). Note: It is not set in case of a link data error.
        TEA: u7,
        /// Transfer Error Direction These bit is set and cleared by HW, in case of an MDMA data transfer error.
        TED: u1,
        /// Transfer Error Link Data These bit is set by HW, in case of a transfer error while reading the block link data structure. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TELD: u1,
        /// Transfer Error Mask Data These bit is set by HW, in case of a transfer error while writing the Mask Data. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TEMD: u1,
        /// Address/Size Error These bit is set by HW, when the programmed address is not aligned with the data size. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        ASE: u1,
        /// Block Size Error These bit is set by HW, when the block size is not an integer multiple of the data size either for source or destination. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        BSE: u1,
        padding: u20 = 0,
    }),
    /// This register is used to control the concerned channel.
    /// offset: 0x20c
    MDMA_C7CR: mmio.Mmio(packed struct(u32) {
        /// channel enable
        EN: u1,
        /// Transfer error interrupt enable This bit is set and cleared by software.
        TEIE: u1,
        /// Channel Transfer Complete interrupt enable This bit is set and cleared by software.
        CTCIE: u1,
        /// Block Repeat transfer interrupt enable This bit is set and cleared by software.
        BRTIE: u1,
        /// Block Transfer interrupt enable This bit is set and cleared by software.
        BTIE: u1,
        /// buffer Transfer Complete interrupt enable This bit is set and cleared by software.
        TCIE: u1,
        /// Priority level These bits are set and cleared by software. These bits are protected and can be written only if EN is 0.
        PL: u2,
        reserved12: u4 = 0,
        /// byte Endianness exchange
        BEX: u1,
        /// Half word Endianes exchange
        HEX: u1,
        /// Word Endianness exchange
        WEX: u1,
        reserved16: u1 = 0,
        /// SW ReQuest Writing a 1 into this bit sets the CRQAx in MDMA_ISRy register, activating the request on Channel x Note: Either the whole CxCR register or the 8-bit/16-bit register @ Address offset: 0x4E + 0x40 chn may be used for SWRQ activation. In case of a SW request, acknowledge is not generated (neither HW signal, nor CxMAR write access).
        SWRQ: u1,
        padding: u15 = 0,
    }),
    /// This register is used to configure the concerned channel.
    /// offset: 0x210
    MDMA_C7TCR: mmio.Mmio(packed struct(u32) {
        /// Source increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When source is AHB (SBUS=1), SINC = 00 is forbidden. In Linked List Mode, at the end of a block (single or last block in repeated block transfer mode), this register will be loaded from memory (from address given by current LAR[31:0] + 0x00).
        SINC: u2,
        /// Destination increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When destination is AHB (DBUS=1), DINC = 00 is forbidden.
        DINC: u2,
        /// Source data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If SINCOS &lt; SSIZE and SINC &#8800; 00, the result will be unpredictable. Note: SSIZE = 11 (double-word) is forbidden when source is TCM/AHB bus (SBUS=1).
        SSIZE: u2,
        /// Destination data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0. Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If DINCOS &lt; DSIZE and DINC &#8800; 00, the result will be unpredictable. Note: DSIZE = 11 (double-word) is forbidden when destination is TCM/AHB bus (DBUS=1).
        DSIZE: u2,
        /// source increment offset size
        SINCOS: u2,
        /// Destination increment offset
        DINCOS: u2,
        /// source burst transfer configuration
        SBURST: u3,
        /// Destination burst transfer configuration
        DBURST: u3,
        /// buffer transfer lengh
        TLEN: u7,
        /// PacK Enable These bit is set and cleared by software. If the Source Size is smaller than the destination, it will be padded according to the PAM value. If the Source data size is larger than the destination one, it will be truncated. The alignment will be done according to the PAM[0] value. This bit is protected and can be written only if EN is 0
        PKE: u1,
        /// Padding/Alignement Mode These bits are set and cleared by software. Case 1: Source data size smaller than destination data size - 3 options are valid. Case 2: Source data size larger than destination data size. The remainder part is discarded. When PKE = 1 or DSIZE=SSIZE, these bits are ignored. These bits are protected and can be written only if EN is 0
        PAM: u2,
        /// Trigger Mode These bits are set and cleared by software. Note: If TRGM is 11 for the current block, all the values loaded at the end of the current block through the linked list mechanism must keep the same value (TRGM=11) and the same SWRM value, otherwise the result is undefined. These bits are protected and can be written only if EN is 0.
        TRGM: u2,
        /// SW Request Mode This bit is set and cleared by software. If a HW or SW request is currently active, the bit change will be delayed until the current transfer is completed. If the CxMAR contains a valid address, the CxMDR value will also be written @ CxMAR address. This bit is protected and can be written only if EN is 0.
        SWRM: u1,
        /// Bufferable Write Mode This bit is set and cleared by software. This bit is protected and can be written only if EN is 0. Note: All MDMA destination accesses are non-cacheable.
        BWM: u1,
    }),
    /// MDMA Channel x block number of data register
    /// offset: 0x214
    MDMA_C7BNDTR: mmio.Mmio(packed struct(u32) {
        /// block number of data to transfer
        BNDT: u17,
        reserved18: u1 = 0,
        /// Block Repeat Source address Update Mode These bits are protected and can be written only if EN is 0.
        BRSUM: u1,
        /// Block Repeat Destination address Update Mode These bits are protected and can be written only if EN is 0.
        BRDUM: u1,
        /// Block Repeat Count This field contains the number of repetitions of the current block (0 to 4095). When the channel is enabled, this register is read-only, indicating the remaining number of blocks, excluding the current one. This register decrements after each complete block transfer. Once the last block transfer has completed, this register can either stay at zero or be reloaded automatically from memory (in Linked List mode - i.e. Link Address valid). These bits are protected and can be written only if EN is 0.
        BRC: u12,
    }),
    /// MDMA channel x source address register
    /// offset: 0x218
    MDMA_C7SAR: mmio.Mmio(packed struct(u32) {
        /// source adr base
        SAR: u32,
    }),
    /// MDMA channel x destination address register
    /// offset: 0x21c
    MDMA_C7DAR: mmio.Mmio(packed struct(u32) {
        /// Destination adr base
        DAR: u32,
    }),
    /// MDMA channel x Block Repeat address Update register
    /// offset: 0x220
    MDMA_C7BRUR: mmio.Mmio(packed struct(u32) {
        /// source adresse update value
        SUV: u16,
        /// destination address update
        DUV: u16,
    }),
    /// MDMA channel x Link Address register
    /// offset: 0x224
    MDMA_C7LAR: mmio.Mmio(packed struct(u32) {
        /// Link address register
        LAR: u32,
    }),
    /// MDMA channel x Trigger and Bus selection Register
    /// offset: 0x228
    MDMA_C7TBR: mmio.Mmio(packed struct(u32) {
        /// Trigger selection
        TSEL: u6,
        reserved16: u10 = 0,
        /// Source BUS select This bit is protected and can be written only if EN is 0.
        SBUS: u1,
        /// Destination BUS slect This bit is protected and can be written only if EN is 0.
        DBUS: u1,
        padding: u14 = 0,
    }),
    /// offset: 0x22c
    reserved556: [4]u8,
    /// MDMA channel x Mask address register
    /// offset: 0x230
    MDMA_C7MAR: mmio.Mmio(packed struct(u32) {
        /// Mask address
        MAR: u32,
    }),
    /// MDMA channel x Mask Data register
    /// offset: 0x234
    MDMA_C7MDR: mmio.Mmio(packed struct(u32) {
        /// Mask data
        MDR: u32,
    }),
    /// offset: 0x238
    reserved568: [8]u8,
    /// MDMA channel x interrupt/status register
    /// offset: 0x240
    MDMA_C8ISR: mmio.Mmio(packed struct(u32) {
        /// Channel x transfer error interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        TEIF8: u1,
        /// Channel x Channel Transfer Complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register. CTC is set when the last block was transferred and the channel has been automatically disabled. CTC is also set when the channel is suspended, as a result of writing EN bit to 0.
        CTCIF8: u1,
        /// Channel x block repeat transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BRTIF8: u1,
        /// Channel x block transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BTIF8: u1,
        /// channel x buffer transfer complete
        TCIF8: u1,
        reserved16: u11 = 0,
        /// channel x request active flag
        CRQA8: u1,
        padding: u15 = 0,
    }),
    /// MDMA channel x interrupt flag clear register
    /// offset: 0x244
    MDMA_C8IFCR: mmio.Mmio(packed struct(u32) {
        /// Channel x clear transfer error interrupt flag Writing a 1 into this bit clears TEIFx in the MDMA_ISRy register
        CTEIF8: u1,
        /// Clear Channel transfer complete interrupt flag for channel x Writing a 1 into this bit clears CTCIFx in the MDMA_ISRy register
        CCTCIF8: u1,
        /// Channel x clear block repeat transfer complete interrupt flag Writing a 1 into this bit clears BRTIFx in the MDMA_ISRy register
        CBRTIF8: u1,
        /// Channel x Clear block transfer complete interrupt flag Writing a 1 into this bit clears BTIFx in the MDMA_ISRy register
        CBTIF8: u1,
        /// CLear buffer Transfer Complete Interrupt Flag for channel x Writing a 1 into this bit clears TCIFx in the MDMA_ISRy register
        CLTCIF8: u1,
        padding: u27 = 0,
    }),
    /// MDMA Channel x error status register
    /// offset: 0x248
    MDMA_C8ESR: mmio.Mmio(packed struct(u32) {
        /// Transfer Error Address These bits are set and cleared by HW, in case of an MDMA data transfer error. It is used in conjunction with TED. This field indicates the 7 LSBits of the address which generated a transfer/access error. It may be used by SW to retrieve the failing address, by adding this value (truncated to the buffer transfer length size) to the current SAR/DAR value. Note: The SAR/DAR current value doesnt reflect this last address due to the FIFO management system. The SAR/DAR are only updated at the end of a (buffer) transfer (of TLEN+1 bytes). Note: It is not set in case of a link data error.
        TEA: u7,
        /// Transfer Error Direction These bit is set and cleared by HW, in case of an MDMA data transfer error.
        TED: u1,
        /// Transfer Error Link Data These bit is set by HW, in case of a transfer error while reading the block link data structure. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TELD: u1,
        /// Transfer Error Mask Data These bit is set by HW, in case of a transfer error while writing the Mask Data. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TEMD: u1,
        /// Address/Size Error These bit is set by HW, when the programmed address is not aligned with the data size. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        ASE: u1,
        /// Block Size Error These bit is set by HW, when the block size is not an integer multiple of the data size either for source or destination. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        BSE: u1,
        padding: u20 = 0,
    }),
    /// This register is used to control the concerned channel.
    /// offset: 0x24c
    MDMA_C8CR: mmio.Mmio(packed struct(u32) {
        /// channel enable
        EN: u1,
        /// Transfer error interrupt enable This bit is set and cleared by software.
        TEIE: u1,
        /// Channel Transfer Complete interrupt enable This bit is set and cleared by software.
        CTCIE: u1,
        /// Block Repeat transfer interrupt enable This bit is set and cleared by software.
        BRTIE: u1,
        /// Block Transfer interrupt enable This bit is set and cleared by software.
        BTIE: u1,
        /// buffer Transfer Complete interrupt enable This bit is set and cleared by software.
        TCIE: u1,
        /// Priority level These bits are set and cleared by software. These bits are protected and can be written only if EN is 0.
        PL: u2,
        reserved12: u4 = 0,
        /// byte Endianness exchange
        BEX: u1,
        /// Half word Endianes exchange
        HEX: u1,
        /// Word Endianness exchange
        WEX: u1,
        reserved16: u1 = 0,
        /// SW ReQuest Writing a 1 into this bit sets the CRQAx in MDMA_ISRy register, activating the request on Channel x Note: Either the whole CxCR register or the 8-bit/16-bit register @ Address offset: 0x4E + 0x40 chn may be used for SWRQ activation. In case of a SW request, acknowledge is not generated (neither HW signal, nor CxMAR write access).
        SWRQ: u1,
        padding: u15 = 0,
    }),
    /// This register is used to configure the concerned channel.
    /// offset: 0x250
    MDMA_C8TCR: mmio.Mmio(packed struct(u32) {
        /// Source increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When source is AHB (SBUS=1), SINC = 00 is forbidden. In Linked List Mode, at the end of a block (single or last block in repeated block transfer mode), this register will be loaded from memory (from address given by current LAR[31:0] + 0x00).
        SINC: u2,
        /// Destination increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When destination is AHB (DBUS=1), DINC = 00 is forbidden.
        DINC: u2,
        /// Source data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If SINCOS &lt; SSIZE and SINC &#8800; 00, the result will be unpredictable. Note: SSIZE = 11 (double-word) is forbidden when source is TCM/AHB bus (SBUS=1).
        SSIZE: u2,
        /// Destination data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0. Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If DINCOS &lt; DSIZE and DINC &#8800; 00, the result will be unpredictable. Note: DSIZE = 11 (double-word) is forbidden when destination is TCM/AHB bus (DBUS=1).
        DSIZE: u2,
        /// source increment offset size
        SINCOS: u2,
        /// Destination increment offset
        DINCOS: u2,
        /// source burst transfer configuration
        SBURST: u3,
        /// Destination burst transfer configuration
        DBURST: u3,
        /// buffer transfer lengh
        TLEN: u7,
        /// PacK Enable These bit is set and cleared by software. If the Source Size is smaller than the destination, it will be padded according to the PAM value. If the Source data size is larger than the destination one, it will be truncated. The alignment will be done according to the PAM[0] value. This bit is protected and can be written only if EN is 0
        PKE: u1,
        /// Padding/Alignement Mode These bits are set and cleared by software. Case 1: Source data size smaller than destination data size - 3 options are valid. Case 2: Source data size larger than destination data size. The remainder part is discarded. When PKE = 1 or DSIZE=SSIZE, these bits are ignored. These bits are protected and can be written only if EN is 0
        PAM: u2,
        /// Trigger Mode These bits are set and cleared by software. Note: If TRGM is 11 for the current block, all the values loaded at the end of the current block through the linked list mechanism must keep the same value (TRGM=11) and the same SWRM value, otherwise the result is undefined. These bits are protected and can be written only if EN is 0.
        TRGM: u2,
        /// SW Request Mode This bit is set and cleared by software. If a HW or SW request is currently active, the bit change will be delayed until the current transfer is completed. If the CxMAR contains a valid address, the CxMDR value will also be written @ CxMAR address. This bit is protected and can be written only if EN is 0.
        SWRM: u1,
        /// Bufferable Write Mode This bit is set and cleared by software. This bit is protected and can be written only if EN is 0. Note: All MDMA destination accesses are non-cacheable.
        BWM: u1,
    }),
    /// MDMA Channel x block number of data register
    /// offset: 0x254
    MDMA_C8BNDTR: mmio.Mmio(packed struct(u32) {
        /// block number of data to transfer
        BNDT: u17,
        reserved18: u1 = 0,
        /// Block Repeat Source address Update Mode These bits are protected and can be written only if EN is 0.
        BRSUM: u1,
        /// Block Repeat Destination address Update Mode These bits are protected and can be written only if EN is 0.
        BRDUM: u1,
        /// Block Repeat Count This field contains the number of repetitions of the current block (0 to 4095). When the channel is enabled, this register is read-only, indicating the remaining number of blocks, excluding the current one. This register decrements after each complete block transfer. Once the last block transfer has completed, this register can either stay at zero or be reloaded automatically from memory (in Linked List mode - i.e. Link Address valid). These bits are protected and can be written only if EN is 0.
        BRC: u12,
    }),
    /// MDMA channel x source address register
    /// offset: 0x258
    MDMA_C8SAR: mmio.Mmio(packed struct(u32) {
        /// source adr base
        SAR: u32,
    }),
    /// MDMA channel x destination address register
    /// offset: 0x25c
    MDMA_C8DAR: mmio.Mmio(packed struct(u32) {
        /// Destination adr base
        DAR: u32,
    }),
    /// MDMA channel x Block Repeat address Update register
    /// offset: 0x260
    MDMA_C8BRUR: mmio.Mmio(packed struct(u32) {
        /// source adresse update value
        SUV: u16,
        /// destination address update
        DUV: u16,
    }),
    /// MDMA channel x Link Address register
    /// offset: 0x264
    MDMA_C8LAR: mmio.Mmio(packed struct(u32) {
        /// Link address register
        LAR: u32,
    }),
    /// MDMA channel x Trigger and Bus selection Register
    /// offset: 0x268
    MDMA_C8TBR: mmio.Mmio(packed struct(u32) {
        /// Trigger selection
        TSEL: u6,
        reserved16: u10 = 0,
        /// Source BUS select This bit is protected and can be written only if EN is 0.
        SBUS: u1,
        /// Destination BUS slect This bit is protected and can be written only if EN is 0.
        DBUS: u1,
        padding: u14 = 0,
    }),
    /// offset: 0x26c
    reserved620: [4]u8,
    /// MDMA channel x Mask address register
    /// offset: 0x270
    MDMA_C8MAR: mmio.Mmio(packed struct(u32) {
        /// Mask address
        MAR: u32,
    }),
    /// MDMA channel x Mask Data register
    /// offset: 0x274
    MDMA_C8MDR: mmio.Mmio(packed struct(u32) {
        /// Mask data
        MDR: u32,
    }),
    /// offset: 0x278
    reserved632: [8]u8,
    /// MDMA channel x interrupt/status register
    /// offset: 0x280
    MDMA_C9ISR: mmio.Mmio(packed struct(u32) {
        /// Channel x transfer error interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        TEIF9: u1,
        /// Channel x Channel Transfer Complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register. CTC is set when the last block was transferred and the channel has been automatically disabled. CTC is also set when the channel is suspended, as a result of writing EN bit to 0.
        CTCIF9: u1,
        /// Channel x block repeat transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BRTIF9: u1,
        /// Channel x block transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BTIF9: u1,
        /// channel x buffer transfer complete
        TCIF9: u1,
        reserved16: u11 = 0,
        /// channel x request active flag
        CRQA9: u1,
        padding: u15 = 0,
    }),
    /// MDMA channel x interrupt flag clear register
    /// offset: 0x284
    MDMA_C9IFCR: mmio.Mmio(packed struct(u32) {
        /// Channel x clear transfer error interrupt flag Writing a 1 into this bit clears TEIFx in the MDMA_ISRy register
        CTEIF9: u1,
        /// Clear Channel transfer complete interrupt flag for channel x Writing a 1 into this bit clears CTCIFx in the MDMA_ISRy register
        CCTCIF9: u1,
        /// Channel x clear block repeat transfer complete interrupt flag Writing a 1 into this bit clears BRTIFx in the MDMA_ISRy register
        CBRTIF9: u1,
        /// Channel x Clear block transfer complete interrupt flag Writing a 1 into this bit clears BTIFx in the MDMA_ISRy register
        CBTIF9: u1,
        /// CLear buffer Transfer Complete Interrupt Flag for channel x Writing a 1 into this bit clears TCIFx in the MDMA_ISRy register
        CLTCIF9: u1,
        padding: u27 = 0,
    }),
    /// MDMA Channel x error status register
    /// offset: 0x288
    MDMA_C9ESR: mmio.Mmio(packed struct(u32) {
        /// Transfer Error Address These bits are set and cleared by HW, in case of an MDMA data transfer error. It is used in conjunction with TED. This field indicates the 7 LSBits of the address which generated a transfer/access error. It may be used by SW to retrieve the failing address, by adding this value (truncated to the buffer transfer length size) to the current SAR/DAR value. Note: The SAR/DAR current value doesnt reflect this last address due to the FIFO management system. The SAR/DAR are only updated at the end of a (buffer) transfer (of TLEN+1 bytes). Note: It is not set in case of a link data error.
        TEA: u7,
        /// Transfer Error Direction These bit is set and cleared by HW, in case of an MDMA data transfer error.
        TED: u1,
        /// Transfer Error Link Data These bit is set by HW, in case of a transfer error while reading the block link data structure. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TELD: u1,
        /// Transfer Error Mask Data These bit is set by HW, in case of a transfer error while writing the Mask Data. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TEMD: u1,
        /// Address/Size Error These bit is set by HW, when the programmed address is not aligned with the data size. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        ASE: u1,
        /// Block Size Error These bit is set by HW, when the block size is not an integer multiple of the data size either for source or destination. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        BSE: u1,
        padding: u20 = 0,
    }),
    /// This register is used to control the concerned channel.
    /// offset: 0x28c
    MDMA_C9CR: mmio.Mmio(packed struct(u32) {
        /// channel enable
        EN: u1,
        /// Transfer error interrupt enable This bit is set and cleared by software.
        TEIE: u1,
        /// Channel Transfer Complete interrupt enable This bit is set and cleared by software.
        CTCIE: u1,
        /// Block Repeat transfer interrupt enable This bit is set and cleared by software.
        BRTIE: u1,
        /// Block Transfer interrupt enable This bit is set and cleared by software.
        BTIE: u1,
        /// buffer Transfer Complete interrupt enable This bit is set and cleared by software.
        TCIE: u1,
        /// Priority level These bits are set and cleared by software. These bits are protected and can be written only if EN is 0.
        PL: u2,
        reserved12: u4 = 0,
        /// byte Endianness exchange
        BEX: u1,
        /// Half word Endianes exchange
        HEX: u1,
        /// Word Endianness exchange
        WEX: u1,
        reserved16: u1 = 0,
        /// SW ReQuest Writing a 1 into this bit sets the CRQAx in MDMA_ISRy register, activating the request on Channel x Note: Either the whole CxCR register or the 8-bit/16-bit register @ Address offset: 0x4E + 0x40 chn may be used for SWRQ activation. In case of a SW request, acknowledge is not generated (neither HW signal, nor CxMAR write access).
        SWRQ: u1,
        padding: u15 = 0,
    }),
    /// This register is used to configure the concerned channel.
    /// offset: 0x290
    MDMA_C9TCR: mmio.Mmio(packed struct(u32) {
        /// Source increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When source is AHB (SBUS=1), SINC = 00 is forbidden. In Linked List Mode, at the end of a block (single or last block in repeated block transfer mode), this register will be loaded from memory (from address given by current LAR[31:0] + 0x00).
        SINC: u2,
        /// Destination increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When destination is AHB (DBUS=1), DINC = 00 is forbidden.
        DINC: u2,
        /// Source data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If SINCOS &lt; SSIZE and SINC &#8800; 00, the result will be unpredictable. Note: SSIZE = 11 (double-word) is forbidden when source is TCM/AHB bus (SBUS=1).
        SSIZE: u2,
        /// Destination data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0. Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If DINCOS &lt; DSIZE and DINC &#8800; 00, the result will be unpredictable. Note: DSIZE = 11 (double-word) is forbidden when destination is TCM/AHB bus (DBUS=1).
        DSIZE: u2,
        /// source increment offset size
        SINCOS: u2,
        /// Destination increment offset
        DINCOS: u2,
        /// source burst transfer configuration
        SBURST: u3,
        /// Destination burst transfer configuration
        DBURST: u3,
        /// buffer transfer lengh
        TLEN: u7,
        /// PacK Enable These bit is set and cleared by software. If the Source Size is smaller than the destination, it will be padded according to the PAM value. If the Source data size is larger than the destination one, it will be truncated. The alignment will be done according to the PAM[0] value. This bit is protected and can be written only if EN is 0
        PKE: u1,
        /// Padding/Alignement Mode These bits are set and cleared by software. Case 1: Source data size smaller than destination data size - 3 options are valid. Case 2: Source data size larger than destination data size. The remainder part is discarded. When PKE = 1 or DSIZE=SSIZE, these bits are ignored. These bits are protected and can be written only if EN is 0
        PAM: u2,
        /// Trigger Mode These bits are set and cleared by software. Note: If TRGM is 11 for the current block, all the values loaded at the end of the current block through the linked list mechanism must keep the same value (TRGM=11) and the same SWRM value, otherwise the result is undefined. These bits are protected and can be written only if EN is 0.
        TRGM: u2,
        /// SW Request Mode This bit is set and cleared by software. If a HW or SW request is currently active, the bit change will be delayed until the current transfer is completed. If the CxMAR contains a valid address, the CxMDR value will also be written @ CxMAR address. This bit is protected and can be written only if EN is 0.
        SWRM: u1,
        /// Bufferable Write Mode This bit is set and cleared by software. This bit is protected and can be written only if EN is 0. Note: All MDMA destination accesses are non-cacheable.
        BWM: u1,
    }),
    /// MDMA Channel x block number of data register
    /// offset: 0x294
    MDMA_C9BNDTR: mmio.Mmio(packed struct(u32) {
        /// block number of data to transfer
        BNDT: u17,
        reserved18: u1 = 0,
        /// Block Repeat Source address Update Mode These bits are protected and can be written only if EN is 0.
        BRSUM: u1,
        /// Block Repeat Destination address Update Mode These bits are protected and can be written only if EN is 0.
        BRDUM: u1,
        /// Block Repeat Count This field contains the number of repetitions of the current block (0 to 4095). When the channel is enabled, this register is read-only, indicating the remaining number of blocks, excluding the current one. This register decrements after each complete block transfer. Once the last block transfer has completed, this register can either stay at zero or be reloaded automatically from memory (in Linked List mode - i.e. Link Address valid). These bits are protected and can be written only if EN is 0.
        BRC: u12,
    }),
    /// MDMA channel x source address register
    /// offset: 0x298
    MDMA_C9SAR: mmio.Mmio(packed struct(u32) {
        /// source adr base
        SAR: u32,
    }),
    /// MDMA channel x destination address register
    /// offset: 0x29c
    MDMA_C9DAR: mmio.Mmio(packed struct(u32) {
        /// Destination adr base
        DAR: u32,
    }),
    /// MDMA channel x Block Repeat address Update register
    /// offset: 0x2a0
    MDMA_C9BRUR: mmio.Mmio(packed struct(u32) {
        /// source adresse update value
        SUV: u16,
        /// destination address update
        DUV: u16,
    }),
    /// MDMA channel x Link Address register
    /// offset: 0x2a4
    MDMA_C9LAR: mmio.Mmio(packed struct(u32) {
        /// Link address register
        LAR: u32,
    }),
    /// MDMA channel x Trigger and Bus selection Register
    /// offset: 0x2a8
    MDMA_C9TBR: mmio.Mmio(packed struct(u32) {
        /// Trigger selection
        TSEL: u6,
        reserved16: u10 = 0,
        /// Source BUS select This bit is protected and can be written only if EN is 0.
        SBUS: u1,
        /// Destination BUS slect This bit is protected and can be written only if EN is 0.
        DBUS: u1,
        padding: u14 = 0,
    }),
    /// offset: 0x2ac
    reserved684: [4]u8,
    /// MDMA channel x Mask address register
    /// offset: 0x2b0
    MDMA_C9MAR: mmio.Mmio(packed struct(u32) {
        /// Mask address
        MAR: u32,
    }),
    /// MDMA channel x Mask Data register
    /// offset: 0x2b4
    MDMA_C9MDR: mmio.Mmio(packed struct(u32) {
        /// Mask data
        MDR: u32,
    }),
    /// offset: 0x2b8
    reserved696: [8]u8,
    /// MDMA channel x interrupt/status register
    /// offset: 0x2c0
    MDMA_C10ISR: mmio.Mmio(packed struct(u32) {
        /// Channel x transfer error interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        TEIF10: u1,
        /// Channel x Channel Transfer Complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register. CTC is set when the last block was transferred and the channel has been automatically disabled. CTC is also set when the channel is suspended, as a result of writing EN bit to 0.
        CTCIF10: u1,
        /// Channel x block repeat transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BRTIF10: u1,
        /// Channel x block transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BTIF10: u1,
        /// channel x buffer transfer complete
        TCIF10: u1,
        reserved16: u11 = 0,
        /// channel x request active flag
        CRQA10: u1,
        padding: u15 = 0,
    }),
    /// MDMA channel x interrupt flag clear register
    /// offset: 0x2c4
    MDMA_C10IFCR: mmio.Mmio(packed struct(u32) {
        /// Channel x clear transfer error interrupt flag Writing a 1 into this bit clears TEIFx in the MDMA_ISRy register
        CTEIF10: u1,
        /// Clear Channel transfer complete interrupt flag for channel x Writing a 1 into this bit clears CTCIFx in the MDMA_ISRy register
        CCTCIF10: u1,
        /// Channel x clear block repeat transfer complete interrupt flag Writing a 1 into this bit clears BRTIFx in the MDMA_ISRy register
        CBRTIF10: u1,
        /// Channel x Clear block transfer complete interrupt flag Writing a 1 into this bit clears BTIFx in the MDMA_ISRy register
        CBTIF10: u1,
        /// CLear buffer Transfer Complete Interrupt Flag for channel x Writing a 1 into this bit clears TCIFx in the MDMA_ISRy register
        CLTCIF10: u1,
        padding: u27 = 0,
    }),
    /// MDMA Channel x error status register
    /// offset: 0x2c8
    MDMA_C10ESR: mmio.Mmio(packed struct(u32) {
        /// Transfer Error Address These bits are set and cleared by HW, in case of an MDMA data transfer error. It is used in conjunction with TED. This field indicates the 7 LSBits of the address which generated a transfer/access error. It may be used by SW to retrieve the failing address, by adding this value (truncated to the buffer transfer length size) to the current SAR/DAR value. Note: The SAR/DAR current value doesnt reflect this last address due to the FIFO management system. The SAR/DAR are only updated at the end of a (buffer) transfer (of TLEN+1 bytes). Note: It is not set in case of a link data error.
        TEA: u7,
        /// Transfer Error Direction These bit is set and cleared by HW, in case of an MDMA data transfer error.
        TED: u1,
        /// Transfer Error Link Data These bit is set by HW, in case of a transfer error while reading the block link data structure. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TELD: u1,
        /// Transfer Error Mask Data These bit is set by HW, in case of a transfer error while writing the Mask Data. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TEMD: u1,
        /// Address/Size Error These bit is set by HW, when the programmed address is not aligned with the data size. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        ASE: u1,
        /// Block Size Error These bit is set by HW, when the block size is not an integer multiple of the data size either for source or destination. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        BSE: u1,
        padding: u20 = 0,
    }),
    /// This register is used to control the concerned channel.
    /// offset: 0x2cc
    MDMA_C10CR: mmio.Mmio(packed struct(u32) {
        /// channel enable
        EN: u1,
        /// Transfer error interrupt enable This bit is set and cleared by software.
        TEIE: u1,
        /// Channel Transfer Complete interrupt enable This bit is set and cleared by software.
        CTCIE: u1,
        /// Block Repeat transfer interrupt enable This bit is set and cleared by software.
        BRTIE: u1,
        /// Block Transfer interrupt enable This bit is set and cleared by software.
        BTIE: u1,
        /// buffer Transfer Complete interrupt enable This bit is set and cleared by software.
        TCIE: u1,
        /// Priority level These bits are set and cleared by software. These bits are protected and can be written only if EN is 0.
        PL: u2,
        reserved12: u4 = 0,
        /// byte Endianness exchange
        BEX: u1,
        /// Half word Endianes exchange
        HEX: u1,
        /// Word Endianness exchange
        WEX: u1,
        reserved16: u1 = 0,
        /// SW ReQuest Writing a 1 into this bit sets the CRQAx in MDMA_ISRy register, activating the request on Channel x Note: Either the whole CxCR register or the 8-bit/16-bit register @ Address offset: 0x4E + 0x40 chn may be used for SWRQ activation. In case of a SW request, acknowledge is not generated (neither HW signal, nor CxMAR write access).
        SWRQ: u1,
        padding: u15 = 0,
    }),
    /// This register is used to configure the concerned channel.
    /// offset: 0x2d0
    MDMA_C10TCR: mmio.Mmio(packed struct(u32) {
        /// Source increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When source is AHB (SBUS=1), SINC = 00 is forbidden. In Linked List Mode, at the end of a block (single or last block in repeated block transfer mode), this register will be loaded from memory (from address given by current LAR[31:0] + 0x00).
        SINC: u2,
        /// Destination increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When destination is AHB (DBUS=1), DINC = 00 is forbidden.
        DINC: u2,
        /// Source data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If SINCOS &lt; SSIZE and SINC &#8800; 00, the result will be unpredictable. Note: SSIZE = 11 (double-word) is forbidden when source is TCM/AHB bus (SBUS=1).
        SSIZE: u2,
        /// Destination data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0. Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If DINCOS &lt; DSIZE and DINC &#8800; 00, the result will be unpredictable. Note: DSIZE = 11 (double-word) is forbidden when destination is TCM/AHB bus (DBUS=1).
        DSIZE: u2,
        /// source increment offset size
        SINCOS: u2,
        /// Destination increment offset
        DINCOS: u2,
        /// source burst transfer configuration
        SBURST: u3,
        /// Destination burst transfer configuration
        DBURST: u3,
        /// buffer transfer lengh
        TLEN: u7,
        /// PacK Enable These bit is set and cleared by software. If the Source Size is smaller than the destination, it will be padded according to the PAM value. If the Source data size is larger than the destination one, it will be truncated. The alignment will be done according to the PAM[0] value. This bit is protected and can be written only if EN is 0
        PKE: u1,
        /// Padding/Alignement Mode These bits are set and cleared by software. Case 1: Source data size smaller than destination data size - 3 options are valid. Case 2: Source data size larger than destination data size. The remainder part is discarded. When PKE = 1 or DSIZE=SSIZE, these bits are ignored. These bits are protected and can be written only if EN is 0
        PAM: u2,
        /// Trigger Mode These bits are set and cleared by software. Note: If TRGM is 11 for the current block, all the values loaded at the end of the current block through the linked list mechanism must keep the same value (TRGM=11) and the same SWRM value, otherwise the result is undefined. These bits are protected and can be written only if EN is 0.
        TRGM: u2,
        /// SW Request Mode This bit is set and cleared by software. If a HW or SW request is currently active, the bit change will be delayed until the current transfer is completed. If the CxMAR contains a valid address, the CxMDR value will also be written @ CxMAR address. This bit is protected and can be written only if EN is 0.
        SWRM: u1,
        /// Bufferable Write Mode This bit is set and cleared by software. This bit is protected and can be written only if EN is 0. Note: All MDMA destination accesses are non-cacheable.
        BWM: u1,
    }),
    /// MDMA Channel x block number of data register
    /// offset: 0x2d4
    MDMA_C10BNDTR: mmio.Mmio(packed struct(u32) {
        /// block number of data to transfer
        BNDT: u17,
        reserved18: u1 = 0,
        /// Block Repeat Source address Update Mode These bits are protected and can be written only if EN is 0.
        BRSUM: u1,
        /// Block Repeat Destination address Update Mode These bits are protected and can be written only if EN is 0.
        BRDUM: u1,
        /// Block Repeat Count This field contains the number of repetitions of the current block (0 to 4095). When the channel is enabled, this register is read-only, indicating the remaining number of blocks, excluding the current one. This register decrements after each complete block transfer. Once the last block transfer has completed, this register can either stay at zero or be reloaded automatically from memory (in Linked List mode - i.e. Link Address valid). These bits are protected and can be written only if EN is 0.
        BRC: u12,
    }),
    /// MDMA channel x source address register
    /// offset: 0x2d8
    MDMA_C10SAR: mmio.Mmio(packed struct(u32) {
        /// source adr base
        SAR: u32,
    }),
    /// MDMA channel x destination address register
    /// offset: 0x2dc
    MDMA_C10DAR: mmio.Mmio(packed struct(u32) {
        /// Destination adr base
        DAR: u32,
    }),
    /// MDMA channel x Block Repeat address Update register
    /// offset: 0x2e0
    MDMA_C10BRUR: mmio.Mmio(packed struct(u32) {
        /// source adresse update value
        SUV: u16,
        /// destination address update
        DUV: u16,
    }),
    /// MDMA channel x Link Address register
    /// offset: 0x2e4
    MDMA_C10LAR: mmio.Mmio(packed struct(u32) {
        /// Link address register
        LAR: u32,
    }),
    /// MDMA channel x Trigger and Bus selection Register
    /// offset: 0x2e8
    MDMA_C10TBR: mmio.Mmio(packed struct(u32) {
        /// Trigger selection
        TSEL: u6,
        reserved16: u10 = 0,
        /// Source BUS select This bit is protected and can be written only if EN is 0.
        SBUS: u1,
        /// Destination BUS slect This bit is protected and can be written only if EN is 0.
        DBUS: u1,
        padding: u14 = 0,
    }),
    /// offset: 0x2ec
    reserved748: [4]u8,
    /// MDMA channel x Mask address register
    /// offset: 0x2f0
    MDMA_C10MAR: mmio.Mmio(packed struct(u32) {
        /// Mask address
        MAR: u32,
    }),
    /// MDMA channel x Mask Data register
    /// offset: 0x2f4
    MDMA_C10MDR: mmio.Mmio(packed struct(u32) {
        /// Mask data
        MDR: u32,
    }),
    /// offset: 0x2f8
    reserved760: [8]u8,
    /// MDMA channel x interrupt/status register
    /// offset: 0x300
    MDMA_C11ISR: mmio.Mmio(packed struct(u32) {
        /// Channel x transfer error interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        TEIF11: u1,
        /// Channel x Channel Transfer Complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register. CTC is set when the last block was transferred and the channel has been automatically disabled. CTC is also set when the channel is suspended, as a result of writing EN bit to 0.
        CTCIF11: u1,
        /// Channel x block repeat transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BRTIF11: u1,
        /// Channel x block transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BTIF11: u1,
        /// channel x buffer transfer complete
        TCIF11: u1,
        reserved16: u11 = 0,
        /// channel x request active flag
        CRQA11: u1,
        padding: u15 = 0,
    }),
    /// MDMA channel x interrupt flag clear register
    /// offset: 0x304
    MDMA_C11IFCR: mmio.Mmio(packed struct(u32) {
        /// Channel x clear transfer error interrupt flag Writing a 1 into this bit clears TEIFx in the MDMA_ISRy register
        CTEIF11: u1,
        /// Clear Channel transfer complete interrupt flag for channel x Writing a 1 into this bit clears CTCIFx in the MDMA_ISRy register
        CCTCIF11: u1,
        /// Channel x clear block repeat transfer complete interrupt flag Writing a 1 into this bit clears BRTIFx in the MDMA_ISRy register
        CBRTIF11: u1,
        /// Channel x Clear block transfer complete interrupt flag Writing a 1 into this bit clears BTIFx in the MDMA_ISRy register
        CBTIF11: u1,
        /// CLear buffer Transfer Complete Interrupt Flag for channel x Writing a 1 into this bit clears TCIFx in the MDMA_ISRy register
        CLTCIF11: u1,
        padding: u27 = 0,
    }),
    /// MDMA Channel x error status register
    /// offset: 0x308
    MDMA_C11ESR: mmio.Mmio(packed struct(u32) {
        /// Transfer Error Address These bits are set and cleared by HW, in case of an MDMA data transfer error. It is used in conjunction with TED. This field indicates the 7 LSBits of the address which generated a transfer/access error. It may be used by SW to retrieve the failing address, by adding this value (truncated to the buffer transfer length size) to the current SAR/DAR value. Note: The SAR/DAR current value doesnt reflect this last address due to the FIFO management system. The SAR/DAR are only updated at the end of a (buffer) transfer (of TLEN+1 bytes). Note: It is not set in case of a link data error.
        TEA: u7,
        /// Transfer Error Direction These bit is set and cleared by HW, in case of an MDMA data transfer error.
        TED: u1,
        /// Transfer Error Link Data These bit is set by HW, in case of a transfer error while reading the block link data structure. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TELD: u1,
        /// Transfer Error Mask Data These bit is set by HW, in case of a transfer error while writing the Mask Data. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TEMD: u1,
        /// Address/Size Error These bit is set by HW, when the programmed address is not aligned with the data size. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        ASE: u1,
        /// Block Size Error These bit is set by HW, when the block size is not an integer multiple of the data size either for source or destination. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        BSE: u1,
        padding: u20 = 0,
    }),
    /// This register is used to control the concerned channel.
    /// offset: 0x30c
    MDMA_C11CR: mmio.Mmio(packed struct(u32) {
        /// channel enable
        EN: u1,
        /// Transfer error interrupt enable This bit is set and cleared by software.
        TEIE: u1,
        /// Channel Transfer Complete interrupt enable This bit is set and cleared by software.
        CTCIE: u1,
        /// Block Repeat transfer interrupt enable This bit is set and cleared by software.
        BRTIE: u1,
        /// Block Transfer interrupt enable This bit is set and cleared by software.
        BTIE: u1,
        /// buffer Transfer Complete interrupt enable This bit is set and cleared by software.
        TCIE: u1,
        /// Priority level These bits are set and cleared by software. These bits are protected and can be written only if EN is 0.
        PL: u2,
        reserved12: u4 = 0,
        /// byte Endianness exchange
        BEX: u1,
        /// Half word Endianes exchange
        HEX: u1,
        /// Word Endianness exchange
        WEX: u1,
        reserved16: u1 = 0,
        /// SW ReQuest Writing a 1 into this bit sets the CRQAx in MDMA_ISRy register, activating the request on Channel x Note: Either the whole CxCR register or the 8-bit/16-bit register @ Address offset: 0x4E + 0x40 chn may be used for SWRQ activation. In case of a SW request, acknowledge is not generated (neither HW signal, nor CxMAR write access).
        SWRQ: u1,
        padding: u15 = 0,
    }),
    /// This register is used to configure the concerned channel.
    /// offset: 0x310
    MDMA_C11TCR: mmio.Mmio(packed struct(u32) {
        /// Source increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When source is AHB (SBUS=1), SINC = 00 is forbidden. In Linked List Mode, at the end of a block (single or last block in repeated block transfer mode), this register will be loaded from memory (from address given by current LAR[31:0] + 0x00).
        SINC: u2,
        /// Destination increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When destination is AHB (DBUS=1), DINC = 00 is forbidden.
        DINC: u2,
        /// Source data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If SINCOS &lt; SSIZE and SINC &#8800; 00, the result will be unpredictable. Note: SSIZE = 11 (double-word) is forbidden when source is TCM/AHB bus (SBUS=1).
        SSIZE: u2,
        /// Destination data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0. Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If DINCOS &lt; DSIZE and DINC &#8800; 00, the result will be unpredictable. Note: DSIZE = 11 (double-word) is forbidden when destination is TCM/AHB bus (DBUS=1).
        DSIZE: u2,
        /// source increment offset size
        SINCOS: u2,
        /// Destination increment offset
        DINCOS: u2,
        /// source burst transfer configuration
        SBURST: u3,
        /// Destination burst transfer configuration
        DBURST: u3,
        /// buffer transfer lengh
        TLEN: u7,
        /// PacK Enable These bit is set and cleared by software. If the Source Size is smaller than the destination, it will be padded according to the PAM value. If the Source data size is larger than the destination one, it will be truncated. The alignment will be done according to the PAM[0] value. This bit is protected and can be written only if EN is 0
        PKE: u1,
        /// Padding/Alignement Mode These bits are set and cleared by software. Case 1: Source data size smaller than destination data size - 3 options are valid. Case 2: Source data size larger than destination data size. The remainder part is discarded. When PKE = 1 or DSIZE=SSIZE, these bits are ignored. These bits are protected and can be written only if EN is 0
        PAM: u2,
        /// Trigger Mode These bits are set and cleared by software. Note: If TRGM is 11 for the current block, all the values loaded at the end of the current block through the linked list mechanism must keep the same value (TRGM=11) and the same SWRM value, otherwise the result is undefined. These bits are protected and can be written only if EN is 0.
        TRGM: u2,
        /// SW Request Mode This bit is set and cleared by software. If a HW or SW request is currently active, the bit change will be delayed until the current transfer is completed. If the CxMAR contains a valid address, the CxMDR value will also be written @ CxMAR address. This bit is protected and can be written only if EN is 0.
        SWRM: u1,
        /// Bufferable Write Mode This bit is set and cleared by software. This bit is protected and can be written only if EN is 0. Note: All MDMA destination accesses are non-cacheable.
        BWM: u1,
    }),
    /// MDMA Channel x block number of data register
    /// offset: 0x314
    MDMA_C11BNDTR: mmio.Mmio(packed struct(u32) {
        /// block number of data to transfer
        BNDT: u17,
        reserved18: u1 = 0,
        /// Block Repeat Source address Update Mode These bits are protected and can be written only if EN is 0.
        BRSUM: u1,
        /// Block Repeat Destination address Update Mode These bits are protected and can be written only if EN is 0.
        BRDUM: u1,
        /// Block Repeat Count This field contains the number of repetitions of the current block (0 to 4095). When the channel is enabled, this register is read-only, indicating the remaining number of blocks, excluding the current one. This register decrements after each complete block transfer. Once the last block transfer has completed, this register can either stay at zero or be reloaded automatically from memory (in Linked List mode - i.e. Link Address valid). These bits are protected and can be written only if EN is 0.
        BRC: u12,
    }),
    /// MDMA channel x source address register
    /// offset: 0x318
    MDMA_C11SAR: mmio.Mmio(packed struct(u32) {
        /// source adr base
        SAR: u32,
    }),
    /// MDMA channel x destination address register
    /// offset: 0x31c
    MDMA_C11DAR: mmio.Mmio(packed struct(u32) {
        /// Destination adr base
        DAR: u32,
    }),
    /// MDMA channel x Block Repeat address Update register
    /// offset: 0x320
    MDMA_C11BRUR: mmio.Mmio(packed struct(u32) {
        /// source adresse update value
        SUV: u16,
        /// destination address update
        DUV: u16,
    }),
    /// MDMA channel x Link Address register
    /// offset: 0x324
    MDMA_C11LAR: mmio.Mmio(packed struct(u32) {
        /// Link address register
        LAR: u32,
    }),
    /// MDMA channel x Trigger and Bus selection Register
    /// offset: 0x328
    MDMA_C11TBR: mmio.Mmio(packed struct(u32) {
        /// Trigger selection
        TSEL: u6,
        reserved16: u10 = 0,
        /// Source BUS select This bit is protected and can be written only if EN is 0.
        SBUS: u1,
        /// Destination BUS slect This bit is protected and can be written only if EN is 0.
        DBUS: u1,
        padding: u14 = 0,
    }),
    /// offset: 0x32c
    reserved812: [4]u8,
    /// MDMA channel x Mask address register
    /// offset: 0x330
    MDMA_C11MAR: mmio.Mmio(packed struct(u32) {
        /// Mask address
        MAR: u32,
    }),
    /// MDMA channel x Mask Data register
    /// offset: 0x334
    MDMA_C11MDR: mmio.Mmio(packed struct(u32) {
        /// Mask data
        MDR: u32,
    }),
    /// offset: 0x338
    reserved824: [8]u8,
    /// MDMA channel x interrupt/status register
    /// offset: 0x340
    MDMA_C12ISR: mmio.Mmio(packed struct(u32) {
        /// Channel x transfer error interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        TEIF12: u1,
        /// Channel x Channel Transfer Complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register. CTC is set when the last block was transferred and the channel has been automatically disabled. CTC is also set when the channel is suspended, as a result of writing EN bit to 0.
        CTCIF12: u1,
        /// Channel x block repeat transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BRTIF12: u1,
        /// Channel x block transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BTIF12: u1,
        /// channel x buffer transfer complete
        TCIF12: u1,
        reserved16: u11 = 0,
        /// channel x request active flag
        CRQA12: u1,
        padding: u15 = 0,
    }),
    /// MDMA channel x interrupt flag clear register
    /// offset: 0x344
    MDMA_C12IFCR: mmio.Mmio(packed struct(u32) {
        /// Channel x clear transfer error interrupt flag Writing a 1 into this bit clears TEIFx in the MDMA_ISRy register
        CTEIF12: u1,
        /// Clear Channel transfer complete interrupt flag for channel x Writing a 1 into this bit clears CTCIFx in the MDMA_ISRy register
        CCTCIF12: u1,
        /// Channel x clear block repeat transfer complete interrupt flag Writing a 1 into this bit clears BRTIFx in the MDMA_ISRy register
        CBRTIF12: u1,
        /// Channel x Clear block transfer complete interrupt flag Writing a 1 into this bit clears BTIFx in the MDMA_ISRy register
        CBTIF12: u1,
        /// CLear buffer Transfer Complete Interrupt Flag for channel x Writing a 1 into this bit clears TCIFx in the MDMA_ISRy register
        CLTCIF12: u1,
        padding: u27 = 0,
    }),
    /// MDMA Channel x error status register
    /// offset: 0x348
    MDMA_C12ESR: mmio.Mmio(packed struct(u32) {
        /// Transfer Error Address These bits are set and cleared by HW, in case of an MDMA data transfer error. It is used in conjunction with TED. This field indicates the 7 LSBits of the address which generated a transfer/access error. It may be used by SW to retrieve the failing address, by adding this value (truncated to the buffer transfer length size) to the current SAR/DAR value. Note: The SAR/DAR current value doesnt reflect this last address due to the FIFO management system. The SAR/DAR are only updated at the end of a (buffer) transfer (of TLEN+1 bytes). Note: It is not set in case of a link data error.
        TEA: u7,
        /// Transfer Error Direction These bit is set and cleared by HW, in case of an MDMA data transfer error.
        TED: u1,
        /// Transfer Error Link Data These bit is set by HW, in case of a transfer error while reading the block link data structure. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TELD: u1,
        /// Transfer Error Mask Data These bit is set by HW, in case of a transfer error while writing the Mask Data. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TEMD: u1,
        /// Address/Size Error These bit is set by HW, when the programmed address is not aligned with the data size. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        ASE: u1,
        /// Block Size Error These bit is set by HW, when the block size is not an integer multiple of the data size either for source or destination. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        BSE: u1,
        padding: u20 = 0,
    }),
    /// This register is used to control the concerned channel.
    /// offset: 0x34c
    MDMA_C12CR: mmio.Mmio(packed struct(u32) {
        /// channel enable
        EN: u1,
        /// Transfer error interrupt enable This bit is set and cleared by software.
        TEIE: u1,
        /// Channel Transfer Complete interrupt enable This bit is set and cleared by software.
        CTCIE: u1,
        /// Block Repeat transfer interrupt enable This bit is set and cleared by software.
        BRTIE: u1,
        /// Block Transfer interrupt enable This bit is set and cleared by software.
        BTIE: u1,
        /// buffer Transfer Complete interrupt enable This bit is set and cleared by software.
        TCIE: u1,
        /// Priority level These bits are set and cleared by software. These bits are protected and can be written only if EN is 0.
        PL: u2,
        reserved12: u4 = 0,
        /// byte Endianness exchange
        BEX: u1,
        /// Half word Endianes exchange
        HEX: u1,
        /// Word Endianness exchange
        WEX: u1,
        reserved16: u1 = 0,
        /// SW ReQuest Writing a 1 into this bit sets the CRQAx in MDMA_ISRy register, activating the request on Channel x Note: Either the whole CxCR register or the 8-bit/16-bit register @ Address offset: 0x4E + 0x40 chn may be used for SWRQ activation. In case of a SW request, acknowledge is not generated (neither HW signal, nor CxMAR write access).
        SWRQ: u1,
        padding: u15 = 0,
    }),
    /// This register is used to configure the concerned channel.
    /// offset: 0x350
    MDMA_C12TCR: mmio.Mmio(packed struct(u32) {
        /// Source increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When source is AHB (SBUS=1), SINC = 00 is forbidden. In Linked List Mode, at the end of a block (single or last block in repeated block transfer mode), this register will be loaded from memory (from address given by current LAR[31:0] + 0x00).
        SINC: u2,
        /// Destination increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When destination is AHB (DBUS=1), DINC = 00 is forbidden.
        DINC: u2,
        /// Source data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If SINCOS &lt; SSIZE and SINC &#8800; 00, the result will be unpredictable. Note: SSIZE = 11 (double-word) is forbidden when source is TCM/AHB bus (SBUS=1).
        SSIZE: u2,
        /// Destination data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0. Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If DINCOS &lt; DSIZE and DINC &#8800; 00, the result will be unpredictable. Note: DSIZE = 11 (double-word) is forbidden when destination is TCM/AHB bus (DBUS=1).
        DSIZE: u2,
        /// source increment offset size
        SINCOS: u2,
        /// Destination increment offset
        DINCOS: u2,
        /// source burst transfer configuration
        SBURST: u3,
        /// Destination burst transfer configuration
        DBURST: u3,
        /// buffer transfer lengh
        TLEN: u7,
        /// PacK Enable These bit is set and cleared by software. If the Source Size is smaller than the destination, it will be padded according to the PAM value. If the Source data size is larger than the destination one, it will be truncated. The alignment will be done according to the PAM[0] value. This bit is protected and can be written only if EN is 0
        PKE: u1,
        /// Padding/Alignement Mode These bits are set and cleared by software. Case 1: Source data size smaller than destination data size - 3 options are valid. Case 2: Source data size larger than destination data size. The remainder part is discarded. When PKE = 1 or DSIZE=SSIZE, these bits are ignored. These bits are protected and can be written only if EN is 0
        PAM: u2,
        /// Trigger Mode These bits are set and cleared by software. Note: If TRGM is 11 for the current block, all the values loaded at the end of the current block through the linked list mechanism must keep the same value (TRGM=11) and the same SWRM value, otherwise the result is undefined. These bits are protected and can be written only if EN is 0.
        TRGM: u2,
        /// SW Request Mode This bit is set and cleared by software. If a HW or SW request is currently active, the bit change will be delayed until the current transfer is completed. If the CxMAR contains a valid address, the CxMDR value will also be written @ CxMAR address. This bit is protected and can be written only if EN is 0.
        SWRM: u1,
        /// Bufferable Write Mode This bit is set and cleared by software. This bit is protected and can be written only if EN is 0. Note: All MDMA destination accesses are non-cacheable.
        BWM: u1,
    }),
    /// MDMA Channel x block number of data register
    /// offset: 0x354
    MDMA_C12BNDTR: mmio.Mmio(packed struct(u32) {
        /// block number of data to transfer
        BNDT: u17,
        reserved18: u1 = 0,
        /// Block Repeat Source address Update Mode These bits are protected and can be written only if EN is 0.
        BRSUM: u1,
        /// Block Repeat Destination address Update Mode These bits are protected and can be written only if EN is 0.
        BRDUM: u1,
        /// Block Repeat Count This field contains the number of repetitions of the current block (0 to 4095). When the channel is enabled, this register is read-only, indicating the remaining number of blocks, excluding the current one. This register decrements after each complete block transfer. Once the last block transfer has completed, this register can either stay at zero or be reloaded automatically from memory (in Linked List mode - i.e. Link Address valid). These bits are protected and can be written only if EN is 0.
        BRC: u12,
    }),
    /// MDMA channel x source address register
    /// offset: 0x358
    MDMA_C12SAR: mmio.Mmio(packed struct(u32) {
        /// source adr base
        SAR: u32,
    }),
    /// MDMA channel x destination address register
    /// offset: 0x35c
    MDMA_C12DAR: mmio.Mmio(packed struct(u32) {
        /// Destination adr base
        DAR: u32,
    }),
    /// MDMA channel x Block Repeat address Update register
    /// offset: 0x360
    MDMA_C12BRUR: mmio.Mmio(packed struct(u32) {
        /// source adresse update value
        SUV: u16,
        /// destination address update
        DUV: u16,
    }),
    /// MDMA channel x Link Address register
    /// offset: 0x364
    MDMA_C12LAR: mmio.Mmio(packed struct(u32) {
        /// Link address register
        LAR: u32,
    }),
    /// MDMA channel x Trigger and Bus selection Register
    /// offset: 0x368
    MDMA_C12TBR: mmio.Mmio(packed struct(u32) {
        /// Trigger selection
        TSEL: u6,
        reserved16: u10 = 0,
        /// Source BUS select This bit is protected and can be written only if EN is 0.
        SBUS: u1,
        /// Destination BUS slect This bit is protected and can be written only if EN is 0.
        DBUS: u1,
        padding: u14 = 0,
    }),
    /// offset: 0x36c
    reserved876: [4]u8,
    /// MDMA channel x Mask address register
    /// offset: 0x370
    MDMA_C12MAR: mmio.Mmio(packed struct(u32) {
        /// Mask address
        MAR: u32,
    }),
    /// MDMA channel x Mask Data register
    /// offset: 0x374
    MDMA_C12MDR: mmio.Mmio(packed struct(u32) {
        /// Mask data
        MDR: u32,
    }),
    /// offset: 0x378
    reserved888: [8]u8,
    /// MDMA channel x interrupt/status register
    /// offset: 0x380
    MDMA_C13ISR: mmio.Mmio(packed struct(u32) {
        /// Channel x transfer error interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        TEIF13: u1,
        /// Channel x Channel Transfer Complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register. CTC is set when the last block was transferred and the channel has been automatically disabled. CTC is also set when the channel is suspended, as a result of writing EN bit to 0.
        CTCIF13: u1,
        /// Channel x block repeat transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BRTIF13: u1,
        /// Channel x block transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BTIF13: u1,
        /// channel x buffer transfer complete
        TCIF13: u1,
        reserved16: u11 = 0,
        /// channel x request active flag
        CRQA13: u1,
        padding: u15 = 0,
    }),
    /// MDMA channel x interrupt flag clear register
    /// offset: 0x384
    MDMA_C13IFCR: mmio.Mmio(packed struct(u32) {
        /// Channel x clear transfer error interrupt flag Writing a 1 into this bit clears TEIFx in the MDMA_ISRy register
        CTEIF13: u1,
        /// Clear Channel transfer complete interrupt flag for channel x Writing a 1 into this bit clears CTCIFx in the MDMA_ISRy register
        CCTCIF13: u1,
        /// Channel x clear block repeat transfer complete interrupt flag Writing a 1 into this bit clears BRTIFx in the MDMA_ISRy register
        CBRTIF13: u1,
        /// Channel x Clear block transfer complete interrupt flag Writing a 1 into this bit clears BTIFx in the MDMA_ISRy register
        CBTIF13: u1,
        /// CLear buffer Transfer Complete Interrupt Flag for channel x Writing a 1 into this bit clears TCIFx in the MDMA_ISRy register
        CLTCIF13: u1,
        padding: u27 = 0,
    }),
    /// MDMA Channel x error status register
    /// offset: 0x388
    MDMA_C13ESR: mmio.Mmio(packed struct(u32) {
        /// Transfer Error Address These bits are set and cleared by HW, in case of an MDMA data transfer error. It is used in conjunction with TED. This field indicates the 7 LSBits of the address which generated a transfer/access error. It may be used by SW to retrieve the failing address, by adding this value (truncated to the buffer transfer length size) to the current SAR/DAR value. Note: The SAR/DAR current value doesnt reflect this last address due to the FIFO management system. The SAR/DAR are only updated at the end of a (buffer) transfer (of TLEN+1 bytes). Note: It is not set in case of a link data error.
        TEA: u7,
        /// Transfer Error Direction These bit is set and cleared by HW, in case of an MDMA data transfer error.
        TED: u1,
        /// Transfer Error Link Data These bit is set by HW, in case of a transfer error while reading the block link data structure. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TELD: u1,
        /// Transfer Error Mask Data These bit is set by HW, in case of a transfer error while writing the Mask Data. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TEMD: u1,
        /// Address/Size Error These bit is set by HW, when the programmed address is not aligned with the data size. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        ASE: u1,
        /// Block Size Error These bit is set by HW, when the block size is not an integer multiple of the data size either for source or destination. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        BSE: u1,
        padding: u20 = 0,
    }),
    /// This register is used to control the concerned channel.
    /// offset: 0x38c
    MDMA_C13CR: mmio.Mmio(packed struct(u32) {
        /// channel enable
        EN: u1,
        /// Transfer error interrupt enable This bit is set and cleared by software.
        TEIE: u1,
        /// Channel Transfer Complete interrupt enable This bit is set and cleared by software.
        CTCIE: u1,
        /// Block Repeat transfer interrupt enable This bit is set and cleared by software.
        BRTIE: u1,
        /// Block Transfer interrupt enable This bit is set and cleared by software.
        BTIE: u1,
        /// buffer Transfer Complete interrupt enable This bit is set and cleared by software.
        TCIE: u1,
        /// Priority level These bits are set and cleared by software. These bits are protected and can be written only if EN is 0.
        PL: u2,
        reserved12: u4 = 0,
        /// byte Endianness exchange
        BEX: u1,
        /// Half word Endianes exchange
        HEX: u1,
        /// Word Endianness exchange
        WEX: u1,
        reserved16: u1 = 0,
        /// SW ReQuest Writing a 1 into this bit sets the CRQAx in MDMA_ISRy register, activating the request on Channel x Note: Either the whole CxCR register or the 8-bit/16-bit register @ Address offset: 0x4E + 0x40 chn may be used for SWRQ activation. In case of a SW request, acknowledge is not generated (neither HW signal, nor CxMAR write access).
        SWRQ: u1,
        padding: u15 = 0,
    }),
    /// This register is used to configure the concerned channel.
    /// offset: 0x390
    MDMA_C13TCR: mmio.Mmio(packed struct(u32) {
        /// Source increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When source is AHB (SBUS=1), SINC = 00 is forbidden. In Linked List Mode, at the end of a block (single or last block in repeated block transfer mode), this register will be loaded from memory (from address given by current LAR[31:0] + 0x00).
        SINC: u2,
        /// Destination increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When destination is AHB (DBUS=1), DINC = 00 is forbidden.
        DINC: u2,
        /// Source data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If SINCOS &lt; SSIZE and SINC &#8800; 00, the result will be unpredictable. Note: SSIZE = 11 (double-word) is forbidden when source is TCM/AHB bus (SBUS=1).
        SSIZE: u2,
        /// Destination data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0. Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If DINCOS &lt; DSIZE and DINC &#8800; 00, the result will be unpredictable. Note: DSIZE = 11 (double-word) is forbidden when destination is TCM/AHB bus (DBUS=1).
        DSIZE: u2,
        /// source increment offset size
        SINCOS: u2,
        /// Destination increment offset
        DINCOS: u2,
        /// source burst transfer configuration
        SBURST: u3,
        /// Destination burst transfer configuration
        DBURST: u3,
        /// buffer transfer lengh
        TLEN: u7,
        /// PacK Enable These bit is set and cleared by software. If the Source Size is smaller than the destination, it will be padded according to the PAM value. If the Source data size is larger than the destination one, it will be truncated. The alignment will be done according to the PAM[0] value. This bit is protected and can be written only if EN is 0
        PKE: u1,
        /// Padding/Alignement Mode These bits are set and cleared by software. Case 1: Source data size smaller than destination data size - 3 options are valid. Case 2: Source data size larger than destination data size. The remainder part is discarded. When PKE = 1 or DSIZE=SSIZE, these bits are ignored. These bits are protected and can be written only if EN is 0
        PAM: u2,
        /// Trigger Mode These bits are set and cleared by software. Note: If TRGM is 11 for the current block, all the values loaded at the end of the current block through the linked list mechanism must keep the same value (TRGM=11) and the same SWRM value, otherwise the result is undefined. These bits are protected and can be written only if EN is 0.
        TRGM: u2,
        /// SW Request Mode This bit is set and cleared by software. If a HW or SW request is currently active, the bit change will be delayed until the current transfer is completed. If the CxMAR contains a valid address, the CxMDR value will also be written @ CxMAR address. This bit is protected and can be written only if EN is 0.
        SWRM: u1,
        /// Bufferable Write Mode This bit is set and cleared by software. This bit is protected and can be written only if EN is 0. Note: All MDMA destination accesses are non-cacheable.
        BWM: u1,
    }),
    /// MDMA Channel x block number of data register
    /// offset: 0x394
    MDMA_C13BNDTR: mmio.Mmio(packed struct(u32) {
        /// block number of data to transfer
        BNDT: u17,
        reserved18: u1 = 0,
        /// Block Repeat Source address Update Mode These bits are protected and can be written only if EN is 0.
        BRSUM: u1,
        /// Block Repeat Destination address Update Mode These bits are protected and can be written only if EN is 0.
        BRDUM: u1,
        /// Block Repeat Count This field contains the number of repetitions of the current block (0 to 4095). When the channel is enabled, this register is read-only, indicating the remaining number of blocks, excluding the current one. This register decrements after each complete block transfer. Once the last block transfer has completed, this register can either stay at zero or be reloaded automatically from memory (in Linked List mode - i.e. Link Address valid). These bits are protected and can be written only if EN is 0.
        BRC: u12,
    }),
    /// MDMA channel x source address register
    /// offset: 0x398
    MDMA_C13SAR: mmio.Mmio(packed struct(u32) {
        /// source adr base
        SAR: u32,
    }),
    /// MDMA channel x destination address register
    /// offset: 0x39c
    MDMA_C13DAR: mmio.Mmio(packed struct(u32) {
        /// Destination adr base
        DAR: u32,
    }),
    /// MDMA channel x Block Repeat address Update register
    /// offset: 0x3a0
    MDMA_C13BRUR: mmio.Mmio(packed struct(u32) {
        /// source adresse update value
        SUV: u16,
        /// destination address update
        DUV: u16,
    }),
    /// MDMA channel x Link Address register
    /// offset: 0x3a4
    MDMA_C13LAR: mmio.Mmio(packed struct(u32) {
        /// Link address register
        LAR: u32,
    }),
    /// MDMA channel x Trigger and Bus selection Register
    /// offset: 0x3a8
    MDMA_C13TBR: mmio.Mmio(packed struct(u32) {
        /// Trigger selection
        TSEL: u6,
        reserved16: u10 = 0,
        /// Source BUS select This bit is protected and can be written only if EN is 0.
        SBUS: u1,
        /// Destination BUS slect This bit is protected and can be written only if EN is 0.
        DBUS: u1,
        padding: u14 = 0,
    }),
    /// offset: 0x3ac
    reserved940: [4]u8,
    /// MDMA channel x Mask address register
    /// offset: 0x3b0
    MDMA_C13MAR: mmio.Mmio(packed struct(u32) {
        /// Mask address
        MAR: u32,
    }),
    /// MDMA channel x Mask Data register
    /// offset: 0x3b4
    MDMA_C13MDR: mmio.Mmio(packed struct(u32) {
        /// Mask data
        MDR: u32,
    }),
    /// offset: 0x3b8
    reserved952: [8]u8,
    /// MDMA channel x interrupt/status register
    /// offset: 0x3c0
    MDMA_C14ISR: mmio.Mmio(packed struct(u32) {
        /// Channel x transfer error interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        TEIF14: u1,
        /// Channel x Channel Transfer Complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register. CTC is set when the last block was transferred and the channel has been automatically disabled. CTC is also set when the channel is suspended, as a result of writing EN bit to 0.
        CTCIF14: u1,
        /// Channel x block repeat transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BRTIF14: u1,
        /// Channel x block transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BTIF14: u1,
        /// channel x buffer transfer complete
        TCIF14: u1,
        reserved16: u11 = 0,
        /// channel x request active flag
        CRQA14: u1,
        padding: u15 = 0,
    }),
    /// MDMA channel x interrupt flag clear register
    /// offset: 0x3c4
    MDMA_C14IFCR: mmio.Mmio(packed struct(u32) {
        /// Channel x clear transfer error interrupt flag Writing a 1 into this bit clears TEIFx in the MDMA_ISRy register
        CTEIF14: u1,
        /// Clear Channel transfer complete interrupt flag for channel x Writing a 1 into this bit clears CTCIFx in the MDMA_ISRy register
        CCTCIF14: u1,
        /// Channel x clear block repeat transfer complete interrupt flag Writing a 1 into this bit clears BRTIFx in the MDMA_ISRy register
        CBRTIF14: u1,
        /// Channel x Clear block transfer complete interrupt flag Writing a 1 into this bit clears BTIFx in the MDMA_ISRy register
        CBTIF14: u1,
        /// CLear buffer Transfer Complete Interrupt Flag for channel x Writing a 1 into this bit clears TCIFx in the MDMA_ISRy register
        CLTCIF14: u1,
        padding: u27 = 0,
    }),
    /// MDMA Channel x error status register
    /// offset: 0x3c8
    MDMA_C14ESR: mmio.Mmio(packed struct(u32) {
        /// Transfer Error Address These bits are set and cleared by HW, in case of an MDMA data transfer error. It is used in conjunction with TED. This field indicates the 7 LSBits of the address which generated a transfer/access error. It may be used by SW to retrieve the failing address, by adding this value (truncated to the buffer transfer length size) to the current SAR/DAR value. Note: The SAR/DAR current value doesnt reflect this last address due to the FIFO management system. The SAR/DAR are only updated at the end of a (buffer) transfer (of TLEN+1 bytes). Note: It is not set in case of a link data error.
        TEA: u7,
        /// Transfer Error Direction These bit is set and cleared by HW, in case of an MDMA data transfer error.
        TED: u1,
        /// Transfer Error Link Data These bit is set by HW, in case of a transfer error while reading the block link data structure. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TELD: u1,
        /// Transfer Error Mask Data These bit is set by HW, in case of a transfer error while writing the Mask Data. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TEMD: u1,
        /// Address/Size Error These bit is set by HW, when the programmed address is not aligned with the data size. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        ASE: u1,
        /// Block Size Error These bit is set by HW, when the block size is not an integer multiple of the data size either for source or destination. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        BSE: u1,
        padding: u20 = 0,
    }),
    /// This register is used to control the concerned channel.
    /// offset: 0x3cc
    MDMA_C14CR: mmio.Mmio(packed struct(u32) {
        /// channel enable
        EN: u1,
        /// Transfer error interrupt enable This bit is set and cleared by software.
        TEIE: u1,
        /// Channel Transfer Complete interrupt enable This bit is set and cleared by software.
        CTCIE: u1,
        /// Block Repeat transfer interrupt enable This bit is set and cleared by software.
        BRTIE: u1,
        /// Block Transfer interrupt enable This bit is set and cleared by software.
        BTIE: u1,
        /// buffer Transfer Complete interrupt enable This bit is set and cleared by software.
        TCIE: u1,
        /// Priority level These bits are set and cleared by software. These bits are protected and can be written only if EN is 0.
        PL: u2,
        reserved12: u4 = 0,
        /// byte Endianness exchange
        BEX: u1,
        /// Half word Endianes exchange
        HEX: u1,
        /// Word Endianness exchange
        WEX: u1,
        reserved16: u1 = 0,
        /// SW ReQuest Writing a 1 into this bit sets the CRQAx in MDMA_ISRy register, activating the request on Channel x Note: Either the whole CxCR register or the 8-bit/16-bit register @ Address offset: 0x4E + 0x40 chn may be used for SWRQ activation. In case of a SW request, acknowledge is not generated (neither HW signal, nor CxMAR write access).
        SWRQ: u1,
        padding: u15 = 0,
    }),
    /// This register is used to configure the concerned channel.
    /// offset: 0x3d0
    MDMA_C14TCR: mmio.Mmio(packed struct(u32) {
        /// Source increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When source is AHB (SBUS=1), SINC = 00 is forbidden. In Linked List Mode, at the end of a block (single or last block in repeated block transfer mode), this register will be loaded from memory (from address given by current LAR[31:0] + 0x00).
        SINC: u2,
        /// Destination increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When destination is AHB (DBUS=1), DINC = 00 is forbidden.
        DINC: u2,
        /// Source data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If SINCOS &lt; SSIZE and SINC &#8800; 00, the result will be unpredictable. Note: SSIZE = 11 (double-word) is forbidden when source is TCM/AHB bus (SBUS=1).
        SSIZE: u2,
        /// Destination data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0. Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If DINCOS &lt; DSIZE and DINC &#8800; 00, the result will be unpredictable. Note: DSIZE = 11 (double-word) is forbidden when destination is TCM/AHB bus (DBUS=1).
        DSIZE: u2,
        /// source increment offset size
        SINCOS: u2,
        /// Destination increment offset
        DINCOS: u2,
        /// source burst transfer configuration
        SBURST: u3,
        /// Destination burst transfer configuration
        DBURST: u3,
        /// buffer transfer lengh
        TLEN: u7,
        /// PacK Enable These bit is set and cleared by software. If the Source Size is smaller than the destination, it will be padded according to the PAM value. If the Source data size is larger than the destination one, it will be truncated. The alignment will be done according to the PAM[0] value. This bit is protected and can be written only if EN is 0
        PKE: u1,
        /// Padding/Alignement Mode These bits are set and cleared by software. Case 1: Source data size smaller than destination data size - 3 options are valid. Case 2: Source data size larger than destination data size. The remainder part is discarded. When PKE = 1 or DSIZE=SSIZE, these bits are ignored. These bits are protected and can be written only if EN is 0
        PAM: u2,
        /// Trigger Mode These bits are set and cleared by software. Note: If TRGM is 11 for the current block, all the values loaded at the end of the current block through the linked list mechanism must keep the same value (TRGM=11) and the same SWRM value, otherwise the result is undefined. These bits are protected and can be written only if EN is 0.
        TRGM: u2,
        /// SW Request Mode This bit is set and cleared by software. If a HW or SW request is currently active, the bit change will be delayed until the current transfer is completed. If the CxMAR contains a valid address, the CxMDR value will also be written @ CxMAR address. This bit is protected and can be written only if EN is 0.
        SWRM: u1,
        /// Bufferable Write Mode This bit is set and cleared by software. This bit is protected and can be written only if EN is 0. Note: All MDMA destination accesses are non-cacheable.
        BWM: u1,
    }),
    /// MDMA Channel x block number of data register
    /// offset: 0x3d4
    MDMA_C14BNDTR: mmio.Mmio(packed struct(u32) {
        /// block number of data to transfer
        BNDT: u17,
        reserved18: u1 = 0,
        /// Block Repeat Source address Update Mode These bits are protected and can be written only if EN is 0.
        BRSUM: u1,
        /// Block Repeat Destination address Update Mode These bits are protected and can be written only if EN is 0.
        BRDUM: u1,
        /// Block Repeat Count This field contains the number of repetitions of the current block (0 to 4095). When the channel is enabled, this register is read-only, indicating the remaining number of blocks, excluding the current one. This register decrements after each complete block transfer. Once the last block transfer has completed, this register can either stay at zero or be reloaded automatically from memory (in Linked List mode - i.e. Link Address valid). These bits are protected and can be written only if EN is 0.
        BRC: u12,
    }),
    /// MDMA channel x source address register
    /// offset: 0x3d8
    MDMA_C14SAR: mmio.Mmio(packed struct(u32) {
        /// source adr base
        SAR: u32,
    }),
    /// MDMA channel x destination address register
    /// offset: 0x3dc
    MDMA_C14DAR: mmio.Mmio(packed struct(u32) {
        /// Destination adr base
        DAR: u32,
    }),
    /// MDMA channel x Block Repeat address Update register
    /// offset: 0x3e0
    MDMA_C14BRUR: mmio.Mmio(packed struct(u32) {
        /// source adresse update value
        SUV: u16,
        /// destination address update
        DUV: u16,
    }),
    /// MDMA channel x Link Address register
    /// offset: 0x3e4
    MDMA_C14LAR: mmio.Mmio(packed struct(u32) {
        /// Link address register
        LAR: u32,
    }),
    /// MDMA channel x Trigger and Bus selection Register
    /// offset: 0x3e8
    MDMA_C14TBR: mmio.Mmio(packed struct(u32) {
        /// Trigger selection
        TSEL: u6,
        reserved16: u10 = 0,
        /// Source BUS select This bit is protected and can be written only if EN is 0.
        SBUS: u1,
        /// Destination BUS slect This bit is protected and can be written only if EN is 0.
        DBUS: u1,
        padding: u14 = 0,
    }),
    /// offset: 0x3ec
    reserved1004: [4]u8,
    /// MDMA channel x Mask address register
    /// offset: 0x3f0
    MDMA_C14MAR: mmio.Mmio(packed struct(u32) {
        /// Mask address
        MAR: u32,
    }),
    /// MDMA channel x Mask Data register
    /// offset: 0x3f4
    MDMA_C14MDR: mmio.Mmio(packed struct(u32) {
        /// Mask data
        MDR: u32,
    }),
    /// offset: 0x3f8
    reserved1016: [8]u8,
    /// MDMA channel x interrupt/status register
    /// offset: 0x400
    MDMA_C15ISR: mmio.Mmio(packed struct(u32) {
        /// Channel x transfer error interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        TEIF15: u1,
        /// Channel x Channel Transfer Complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register. CTC is set when the last block was transferred and the channel has been automatically disabled. CTC is also set when the channel is suspended, as a result of writing EN bit to 0.
        CTCIF15: u1,
        /// Channel x block repeat transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BRTIF15: u1,
        /// Channel x block transfer complete interrupt flag This bit is set by hardware. It is cleared by software writing 1 to the corresponding bit in the DMA_IFCRy register.
        BTIF15: u1,
        /// channel x buffer transfer complete
        TCIF15: u1,
        reserved16: u11 = 0,
        /// channel x request active flag
        CRQA15: u1,
        padding: u15 = 0,
    }),
    /// MDMA channel x interrupt flag clear register
    /// offset: 0x404
    MDMA_C15IFCR: mmio.Mmio(packed struct(u32) {
        /// Channel x clear transfer error interrupt flag Writing a 1 into this bit clears TEIFx in the MDMA_ISRy register
        CTEIF15: u1,
        /// Clear Channel transfer complete interrupt flag for channel x Writing a 1 into this bit clears CTCIFx in the MDMA_ISRy register
        CCTCIF15: u1,
        /// Channel x clear block repeat transfer complete interrupt flag Writing a 1 into this bit clears BRTIFx in the MDMA_ISRy register
        CBRTIF15: u1,
        /// Channel x Clear block transfer complete interrupt flag Writing a 1 into this bit clears BTIFx in the MDMA_ISRy register
        CBTIF15: u1,
        /// CLear buffer Transfer Complete Interrupt Flag for channel x Writing a 1 into this bit clears TCIFx in the MDMA_ISRy register
        CLTCIF15: u1,
        padding: u27 = 0,
    }),
    /// MDMA Channel x error status register
    /// offset: 0x408
    MDMA_C15ESR: mmio.Mmio(packed struct(u32) {
        /// Transfer Error Address These bits are set and cleared by HW, in case of an MDMA data transfer error. It is used in conjunction with TED. This field indicates the 7 LSBits of the address which generated a transfer/access error. It may be used by SW to retrieve the failing address, by adding this value (truncated to the buffer transfer length size) to the current SAR/DAR value. Note: The SAR/DAR current value doesnt reflect this last address due to the FIFO management system. The SAR/DAR are only updated at the end of a (buffer) transfer (of TLEN+1 bytes). Note: It is not set in case of a link data error.
        TEA: u7,
        /// Transfer Error Direction These bit is set and cleared by HW, in case of an MDMA data transfer error.
        TED: u1,
        /// Transfer Error Link Data These bit is set by HW, in case of a transfer error while reading the block link data structure. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TELD: u1,
        /// Transfer Error Mask Data These bit is set by HW, in case of a transfer error while writing the Mask Data. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        TEMD: u1,
        /// Address/Size Error These bit is set by HW, when the programmed address is not aligned with the data size. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        ASE: u1,
        /// Block Size Error These bit is set by HW, when the block size is not an integer multiple of the data size either for source or destination. TED will indicate whether the problem is on the source or destination. It is cleared by software writing 1 to the CTEIFx bit in the DMA_IFCRy register.
        BSE: u1,
        padding: u20 = 0,
    }),
    /// This register is used to control the concerned channel.
    /// offset: 0x40c
    MDMA_C15CR: mmio.Mmio(packed struct(u32) {
        /// channel enable
        EN: u1,
        /// Transfer error interrupt enable This bit is set and cleared by software.
        TEIE: u1,
        /// Channel Transfer Complete interrupt enable This bit is set and cleared by software.
        CTCIE: u1,
        /// Block Repeat transfer interrupt enable This bit is set and cleared by software.
        BRTIE: u1,
        /// Block Transfer interrupt enable This bit is set and cleared by software.
        BTIE: u1,
        /// buffer Transfer Complete interrupt enable This bit is set and cleared by software.
        TCIE: u1,
        /// Priority level These bits are set and cleared by software. These bits are protected and can be written only if EN is 0.
        PL: u2,
        reserved12: u4 = 0,
        /// byte Endianness exchange
        BEX: u1,
        /// Half word Endianes exchange
        HEX: u1,
        /// Word Endianness exchange
        WEX: u1,
        reserved16: u1 = 0,
        /// SW ReQuest Writing a 1 into this bit sets the CRQAx in MDMA_ISRy register, activating the request on Channel x Note: Either the whole CxCR register or the 8-bit/16-bit register @ Address offset: 0x4E + 0x40 chn may be used for SWRQ activation. In case of a SW request, acknowledge is not generated (neither HW signal, nor CxMAR write access).
        SWRQ: u1,
        padding: u15 = 0,
    }),
    /// This register is used to configure the concerned channel.
    /// offset: 0x410
    MDMA_C15TCR: mmio.Mmio(packed struct(u32) {
        /// Source increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When source is AHB (SBUS=1), SINC = 00 is forbidden. In Linked List Mode, at the end of a block (single or last block in repeated block transfer mode), this register will be loaded from memory (from address given by current LAR[31:0] + 0x00).
        SINC: u2,
        /// Destination increment mode These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: When destination is AHB (DBUS=1), DINC = 00 is forbidden.
        DINC: u2,
        /// Source data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0 Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If SINCOS &lt; SSIZE and SINC &#8800; 00, the result will be unpredictable. Note: SSIZE = 11 (double-word) is forbidden when source is TCM/AHB bus (SBUS=1).
        SSIZE: u2,
        /// Destination data size These bits are set and cleared by software. These bits are protected and can be written only if EN is 0. Note: If a value of 11 is programmed for the TCM access/AHB port, a transfer error will occur (TEIF bit set) If DINCOS &lt; DSIZE and DINC &#8800; 00, the result will be unpredictable. Note: DSIZE = 11 (double-word) is forbidden when destination is TCM/AHB bus (DBUS=1).
        DSIZE: u2,
        /// source increment offset size
        SINCOS: u2,
        /// Destination increment offset
        DINCOS: u2,
        /// source burst transfer configuration
        SBURST: u3,
        /// Destination burst transfer configuration
        DBURST: u3,
        /// buffer transfer lengh
        TLEN: u7,
        /// PacK Enable These bit is set and cleared by software. If the Source Size is smaller than the destination, it will be padded according to the PAM value. If the Source data size is larger than the destination one, it will be truncated. The alignment will be done according to the PAM[0] value. This bit is protected and can be written only if EN is 0
        PKE: u1,
        /// Padding/Alignement Mode These bits are set and cleared by software. Case 1: Source data size smaller than destination data size - 3 options are valid. Case 2: Source data size larger than destination data size. The remainder part is discarded. When PKE = 1 or DSIZE=SSIZE, these bits are ignored. These bits are protected and can be written only if EN is 0
        PAM: u2,
        /// Trigger Mode These bits are set and cleared by software. Note: If TRGM is 11 for the current block, all the values loaded at the end of the current block through the linked list mechanism must keep the same value (TRGM=11) and the same SWRM value, otherwise the result is undefined. These bits are protected and can be written only if EN is 0.
        TRGM: u2,
        /// SW Request Mode This bit is set and cleared by software. If a HW or SW request is currently active, the bit change will be delayed until the current transfer is completed. If the CxMAR contains a valid address, the CxMDR value will also be written @ CxMAR address. This bit is protected and can be written only if EN is 0.
        SWRM: u1,
        /// Bufferable Write Mode This bit is set and cleared by software. This bit is protected and can be written only if EN is 0. Note: All MDMA destination accesses are non-cacheable.
        BWM: u1,
    }),
    /// MDMA Channel x block number of data register
    /// offset: 0x414
    MDMA_C15BNDTR: mmio.Mmio(packed struct(u32) {
        /// block number of data to transfer
        BNDT: u17,
        reserved18: u1 = 0,
        /// Block Repeat Source address Update Mode These bits are protected and can be written only if EN is 0.
        BRSUM: u1,
        /// Block Repeat Destination address Update Mode These bits are protected and can be written only if EN is 0.
        BRDUM: u1,
        /// Block Repeat Count This field contains the number of repetitions of the current block (0 to 4095). When the channel is enabled, this register is read-only, indicating the remaining number of blocks, excluding the current one. This register decrements after each complete block transfer. Once the last block transfer has completed, this register can either stay at zero or be reloaded automatically from memory (in Linked List mode - i.e. Link Address valid). These bits are protected and can be written only if EN is 0.
        BRC: u12,
    }),
    /// MDMA channel x source address register
    /// offset: 0x418
    MDMA_C15SAR: mmio.Mmio(packed struct(u32) {
        /// source adr base
        SAR: u32,
    }),
    /// MDMA channel x destination address register
    /// offset: 0x41c
    MDMA_C15DAR: mmio.Mmio(packed struct(u32) {
        /// Destination adr base
        DAR: u32,
    }),
    /// MDMA channel x Block Repeat address Update register
    /// offset: 0x420
    MDMA_C15BRUR: mmio.Mmio(packed struct(u32) {
        /// source adresse update value
        SUV: u16,
        /// destination address update
        DUV: u16,
    }),
    /// MDMA channel x Link Address register
    /// offset: 0x424
    MDMA_C15LAR: mmio.Mmio(packed struct(u32) {
        /// Link address register
        LAR: u32,
    }),
    /// MDMA channel x Trigger and Bus selection Register
    /// offset: 0x428
    MDMA_C15TBR: mmio.Mmio(packed struct(u32) {
        /// Trigger selection
        TSEL: u6,
        reserved16: u10 = 0,
        /// Source BUS select This bit is protected and can be written only if EN is 0.
        SBUS: u1,
        /// Destination BUS slect This bit is protected and can be written only if EN is 0.
        DBUS: u1,
        padding: u14 = 0,
    }),
    /// offset: 0x42c
    reserved1068: [4]u8,
    /// MDMA channel x Mask address register
    /// offset: 0x430
    MDMA_C15MAR: mmio.Mmio(packed struct(u32) {
        /// Mask address
        MAR: u32,
    }),
    /// MDMA channel x Mask Data register
    /// offset: 0x434
    MDMA_C15MDR: mmio.Mmio(packed struct(u32) {
        /// Mask data
        MDR: u32,
    }),
};
