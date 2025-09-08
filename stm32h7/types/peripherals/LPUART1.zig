const mmio = @import("mmio");
const types = @import("../../types.zig");

/// LPUART1
pub const LPUART1 = extern struct {
    /// Control register 1
    /// offset: 0x00
    CR1: mmio.Mmio(packed struct(u32) {
        /// USART enable
        UE: u1,
        /// USART enable in Stop mode
        UESM: u1,
        /// Receiver enable
        RE: u1,
        /// Transmitter enable
        TE: u1,
        /// IDLE interrupt enable
        IDLEIE: u1,
        /// RXNE interrupt enable
        RXNEIE: u1,
        /// Transmission complete interrupt enable
        TCIE: u1,
        /// interrupt enable
        TXEIE: u1,
        /// PE interrupt enable
        PEIE: u1,
        /// Parity selection
        PS: u1,
        /// Parity control enable
        PCE: u1,
        /// Receiver wakeup method
        WAKE: u1,
        /// Word length
        M0: u1,
        /// Mute mode enable
        MME: u1,
        /// Character match interrupt enable
        CMIE: u1,
        reserved16: u1 = 0,
        /// Driver Enable deassertion time
        DEDT: u5,
        /// Driver Enable assertion time
        DEAT: u5,
        reserved28: u2 = 0,
        /// Word length
        M1: u1,
        /// FIFO mode enable
        FIFOEN: u1,
        /// TXFIFO empty interrupt enable
        TXFEIE: u1,
        /// RXFIFO Full interrupt enable
        RXFFIE: u1,
    }),
    /// Control register 2
    /// offset: 0x04
    CR2: mmio.Mmio(packed struct(u32) {
        reserved4: u4 = 0,
        /// 7-bit Address Detection/4-bit Address Detection
        ADDM7: u1,
        reserved12: u7 = 0,
        /// STOP bits
        STOP: u2,
        reserved15: u1 = 0,
        /// Swap TX/RX pins
        SWAP: u1,
        /// RX pin active level inversion
        RXINV: u1,
        /// TX pin active level inversion
        TXINV: u1,
        /// Binary data inversion
        DATAINV: u1,
        /// Most significant bit first
        MSBFIRST: u1,
        reserved24: u4 = 0,
        /// Address of the USART node
        ADD: u8,
    }),
    /// Control register 3
    /// offset: 0x08
    CR3: mmio.Mmio(packed struct(u32) {
        /// Error interrupt enable
        EIE: u1,
        reserved3: u2 = 0,
        /// Half-duplex selection
        HDSEL: u1,
        reserved6: u2 = 0,
        /// DMA enable receiver
        DMAR: u1,
        /// DMA enable transmitter
        DMAT: u1,
        /// RTS enable
        RTSE: u1,
        /// CTS enable
        CTSE: u1,
        /// CTS interrupt enable
        CTSIE: u1,
        reserved12: u1 = 0,
        /// Overrun Disable
        OVRDIS: u1,
        /// DMA Disable on Reception Error
        DDRE: u1,
        /// Driver enable mode
        DEM: u1,
        /// Driver enable polarity selection
        DEP: u1,
        reserved20: u4 = 0,
        /// Wakeup from Stop mode interrupt flag selection
        WUS: u2,
        /// Wakeup from Stop mode interrupt enable
        WUFIE: u1,
        /// TXFIFO threshold interrupt enable
        TXFTIE: u1,
        reserved25: u1 = 0,
        /// Receive FIFO threshold configuration
        RXFTCFG: u3,
        /// RXFIFO threshold interrupt enable
        RXFTIE: u1,
        /// TXFIFO threshold configuration
        TXFTCFG: u3,
    }),
    /// Baud rate register
    /// offset: 0x0c
    BRR: mmio.Mmio(packed struct(u32) {
        /// BRR
        BRR: u20,
        padding: u12 = 0,
    }),
    /// Guard time and prescaler register
    /// offset: 0x10
    GTPR: mmio.Mmio(packed struct(u32) {
        /// Prescaler value
        PSC: u8,
        /// Guard time value
        GT: u8,
        padding: u16 = 0,
    }),
    /// Receiver timeout register
    /// offset: 0x14
    RTOR: mmio.Mmio(packed struct(u32) {
        /// Receiver timeout value
        RTO: u24,
        /// Block Length
        BLEN: u8,
    }),
    /// Request register
    /// offset: 0x18
    RQR: mmio.Mmio(packed struct(u32) {
        /// Auto baud rate request
        ABRRQ: u1,
        /// Send break request
        SBKRQ: u1,
        /// Mute mode request
        MMRQ: u1,
        /// Receive data flush request
        RXFRQ: u1,
        /// Transmit data flush request
        TXFRQ: u1,
        padding: u27 = 0,
    }),
    /// Interrupt & status register
    /// offset: 0x1c
    ISR: mmio.Mmio(packed struct(u32) {
        /// PE
        PE: u1,
        /// FE
        FE: u1,
        /// NE
        NE: u1,
        /// ORE
        ORE: u1,
        /// IDLE
        IDLE: u1,
        /// RXNE
        RXNE: u1,
        /// TC
        TC: u1,
        /// TXE
        TXE: u1,
        reserved9: u1 = 0,
        /// CTSIF
        CTSIF: u1,
        /// CTS
        CTS: u1,
        reserved16: u5 = 0,
        /// BUSY
        BUSY: u1,
        /// CMF
        CMF: u1,
        /// SBKF
        SBKF: u1,
        /// RWU
        RWU: u1,
        /// WUF
        WUF: u1,
        /// TEACK
        TEACK: u1,
        /// REACK
        REACK: u1,
        /// TXFIFO Empty
        TXFE: u1,
        /// RXFIFO Full
        RXFF: u1,
        reserved26: u1 = 0,
        /// RXFIFO threshold flag
        RXFT: u1,
        /// TXFIFO threshold flag
        TXFT: u1,
        padding: u4 = 0,
    }),
    /// Interrupt flag clear register
    /// offset: 0x20
    ICR: mmio.Mmio(packed struct(u32) {
        /// Parity error clear flag
        PECF: u1,
        /// Framing error clear flag
        FECF: u1,
        /// Noise detected clear flag
        NCF: u1,
        /// Overrun error clear flag
        ORECF: u1,
        /// Idle line detected clear flag
        IDLECF: u1,
        reserved6: u1 = 0,
        /// Transmission complete clear flag
        TCCF: u1,
        reserved9: u2 = 0,
        /// CTS clear flag
        CTSCF: u1,
        reserved17: u7 = 0,
        /// Character match clear flag
        CMCF: u1,
        reserved20: u2 = 0,
        /// Wakeup from Stop mode clear flag
        WUCF: u1,
        padding: u11 = 0,
    }),
    /// Receive data register
    /// offset: 0x24
    RDR: mmio.Mmio(packed struct(u32) {
        /// Receive data value
        RDR: u9,
        padding: u23 = 0,
    }),
    /// Transmit data register
    /// offset: 0x28
    TDR: mmio.Mmio(packed struct(u32) {
        /// Transmit data value
        TDR: u9,
        padding: u23 = 0,
    }),
    /// Prescaler register
    /// offset: 0x2c
    PRESC: mmio.Mmio(packed struct(u32) {
        /// Clock prescaler
        PRESCALER: u4,
        padding: u28 = 0,
    }),
};
