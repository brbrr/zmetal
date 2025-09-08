const mmio = @import("mmio");
const types = @import("../../types.zig");

/// Universal synchronous asynchronous receiver transmitter
pub const USART1 = extern struct {
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
        /// Oversampling mode
        OVER8: u1,
        /// DEDT0
        DEDT0: u1,
        /// DEDT1
        DEDT1: u1,
        /// DEDT2
        DEDT2: u1,
        /// DEDT3
        DEDT3: u1,
        /// Driver Enable de-assertion time
        DEDT4: u1,
        /// DEAT0
        DEAT0: u1,
        /// DEAT1
        DEAT1: u1,
        /// DEAT2
        DEAT2: u1,
        /// DEAT3
        DEAT3: u1,
        /// Driver Enable assertion time
        DEAT4: u1,
        /// Receiver timeout interrupt enable
        RTOIE: u1,
        /// End of Block interrupt enable
        EOBIE: u1,
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
        /// Synchronous Slave mode enable
        SLVEN: u1,
        reserved3: u2 = 0,
        /// When the DSI_NSS bit is set, the NSS pin input is ignored
        DIS_NSS: u1,
        /// 7-bit Address Detection/4-bit Address Detection
        ADDM7: u1,
        /// LIN break detection length
        LBDL: u1,
        /// LIN break detection interrupt enable
        LBDIE: u1,
        reserved8: u1 = 0,
        /// Last bit clock pulse
        LBCL: u1,
        /// Clock phase
        CPHA: u1,
        /// Clock polarity
        CPOL: u1,
        /// Clock enable
        CLKEN: u1,
        /// STOP bits
        STOP: u2,
        /// LIN mode enable
        LINEN: u1,
        /// Swap TX/RX pins
        SWAP: u1,
        /// RX pin active level inversion
        RXINV: u1,
        /// TX pin active level inversion
        TXINV: u1,
        /// Binary data inversion
        TAINV: u1,
        /// Most significant bit first
        MSBFIRST: u1,
        /// Auto baud rate enable
        ABREN: u1,
        /// ABRMOD0
        ABRMOD0: u1,
        /// Auto baud rate mode
        ABRMOD1: u1,
        /// Receiver timeout enable
        RTOEN: u1,
        /// Address of the USART node
        ADD0_3: u4,
        /// Address of the USART node
        ADD4_7: u4,
    }),
    /// Control register 3
    /// offset: 0x08
    CR3: mmio.Mmio(packed struct(u32) {
        /// Error interrupt enable
        EIE: u1,
        /// Ir mode enable
        IREN: u1,
        /// Ir low-power
        IRLP: u1,
        /// Half-duplex selection
        HDSEL: u1,
        /// Smartcard NACK enable
        NACK: u1,
        /// Smartcard mode enable
        SCEN: u1,
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
        /// One sample bit method enable
        ONEBIT: u1,
        /// Overrun Disable
        OVRDIS: u1,
        /// DMA Disable on Reception Error
        DDRE: u1,
        /// Driver enable mode
        DEM: u1,
        /// Driver enable polarity selection
        DEP: u1,
        reserved17: u1 = 0,
        /// Smartcard auto-retry count
        SCARCNT: u3,
        /// Wakeup from Stop mode interrupt flag selection
        WUS: u2,
        /// Wakeup from Stop mode interrupt enable
        WUFIE: u1,
        /// TXFIFO threshold interrupt enable
        TXFTIE: u1,
        /// Transmission Complete before guard time, interrupt enable
        TCBGTIE: u1,
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
        /// DIV_Fraction
        BRR_0_3: u4,
        /// DIV_Mantissa
        BRR_4_15: u12,
        padding: u16 = 0,
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
        /// NF
        NF: u1,
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
        /// LBDF
        LBDF: u1,
        /// CTSIF
        CTSIF: u1,
        /// CTS
        CTS: u1,
        /// RTOF
        RTOF: u1,
        /// EOBF
        EOBF: u1,
        /// SPI slave underrun error flag
        UDR: u1,
        /// ABRE
        ABRE: u1,
        /// ABRF
        ABRF: u1,
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
        /// Transmission complete before guard time flag
        TCBGT: u1,
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
        /// TXFIFO empty clear flag
        TXFECF: u1,
        /// Transmission complete clear flag
        TCCF: u1,
        /// Transmission complete before Guard time clear flag
        TCBGTC: u1,
        /// LIN break detection clear flag
        LBDCF: u1,
        /// CTS clear flag
        CTSCF: u1,
        reserved11: u1 = 0,
        /// Receiver timeout clear flag
        RTOCF: u1,
        /// End of block clear flag
        EOBCF: u1,
        /// SPI slave underrun clear flag
        UDRCF: u1,
        reserved17: u3 = 0,
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
    /// USART prescaler register
    /// offset: 0x2c
    PRESC: mmio.Mmio(packed struct(u32) {
        /// Clock prescaler
        PRESCALER: u4,
        padding: u28 = 0,
    }),
};
