const mmio = @import("mmio");
const types = @import("../../types.zig");

/// Single Wire Protocol Master Interface
pub const SWPMI = extern struct {
    /// SWPMI Configuration/Control register
    /// offset: 0x00
    CR: mmio.Mmio(packed struct(u32) {
        /// Reception DMA enable
        RXDMA: u1,
        /// Transmission DMA enable
        TXDMA: u1,
        /// Reception buffering mode
        RXMODE: u1,
        /// Transmission buffering mode
        TXMODE: u1,
        /// Loopback mode enable
        LPBK: u1,
        /// Single wire protocol master interface activate
        SWPACT: u1,
        reserved10: u4 = 0,
        /// Single wire protocol master interface deactivate
        DEACT: u1,
        /// Single wire protocol master transceiver enable
        SWPTEN: u1,
        padding: u20 = 0,
    }),
    /// SWPMI Bitrate register
    /// offset: 0x04
    BRR: mmio.Mmio(packed struct(u32) {
        /// Bitrate prescaler
        BR: u8,
        padding: u24 = 0,
    }),
    /// offset: 0x08
    reserved8: [4]u8,
    /// SWPMI Interrupt and Status register
    /// offset: 0x0c
    ISR: mmio.Mmio(packed struct(u32) {
        /// Receive buffer full flag
        RXBFF: u1,
        /// Transmit buffer empty flag
        TXBEF: u1,
        /// Receive CRC error flag
        RXBERF: u1,
        /// Receive overrun error flag
        RXOVRF: u1,
        /// Transmit underrun error flag
        TXUNRF: u1,
        /// Receive data register not empty
        RXNE: u1,
        /// Transmit data register empty
        TXE: u1,
        /// Transfer complete flag
        TCF: u1,
        /// Slave resume flag
        SRF: u1,
        /// SUSPEND flag
        SUSP: u1,
        /// DEACTIVATED flag
        DEACTF: u1,
        /// transceiver ready flag
        RDYF: u1,
        padding: u20 = 0,
    }),
    /// SWPMI Interrupt Flag Clear register
    /// offset: 0x10
    ICR: mmio.Mmio(packed struct(u32) {
        /// Clear receive buffer full flag
        CRXBFF: u1,
        /// Clear transmit buffer empty flag
        CTXBEF: u1,
        /// Clear receive CRC error flag
        CRXBERF: u1,
        /// Clear receive overrun error flag
        CRXOVRF: u1,
        /// Clear transmit underrun error flag
        CTXUNRF: u1,
        reserved7: u2 = 0,
        /// Clear transfer complete flag
        CTCF: u1,
        /// Clear slave resume flag
        CSRF: u1,
        reserved11: u2 = 0,
        /// Clear transceiver ready flag
        CRDYF: u1,
        padding: u20 = 0,
    }),
    /// SWPMI Interrupt Enable register
    /// offset: 0x14
    IER: mmio.Mmio(packed struct(u32) {
        /// Receive buffer full interrupt enable
        RXBFIE: u1,
        /// Transmit buffer empty interrupt enable
        TXBEIE: u1,
        /// Receive CRC error interrupt enable
        RXBERIE: u1,
        /// Receive overrun error interrupt enable
        RXOVRIE: u1,
        /// Transmit underrun error interrupt enable
        TXUNRIE: u1,
        /// Receive interrupt enable
        RIE: u1,
        /// Transmit interrupt enable
        TIE: u1,
        /// Transmit complete interrupt enable
        TCIE: u1,
        /// Slave resume interrupt enable
        SRIE: u1,
        reserved11: u2 = 0,
        /// Transceiver ready interrupt enable
        RDYIE: u1,
        padding: u20 = 0,
    }),
    /// SWPMI Receive Frame Length register
    /// offset: 0x18
    RFL: mmio.Mmio(packed struct(u32) {
        /// Receive frame length
        RFL: u5,
        padding: u27 = 0,
    }),
    /// SWPMI Transmit data register
    /// offset: 0x1c
    TDR: mmio.Mmio(packed struct(u32) {
        /// Transmit data
        TD: u32,
    }),
    /// SWPMI Receive data register
    /// offset: 0x20
    RDR: mmio.Mmio(packed struct(u32) {
        /// received data
        RD: u32,
    }),
    /// SWPMI Option register
    /// offset: 0x24
    OR: mmio.Mmio(packed struct(u32) {
        /// SWP transceiver bypass
        SWP_TBYP: u1,
        /// SWP class selection
        SWP_CLASS: u1,
        padding: u30 = 0,
    }),
};
