const mmio = @import("mmio");
const types = @import("../../types.zig");

/// LCD-TFT Controller
pub const LTDC = extern struct {
    /// offset: 0x00
    reserved0: [8]u8,
    /// Synchronization Size Configuration Register
    /// offset: 0x08
    SSCR: mmio.Mmio(packed struct(u32) {
        /// Vertical Synchronization Height (in units of horizontal scan line)
        VSH: u11,
        reserved16: u5 = 0,
        /// Horizontal Synchronization Width (in units of pixel clock period)
        HSW: u10,
        padding: u6 = 0,
    }),
    /// Back Porch Configuration Register
    /// offset: 0x0c
    BPCR: mmio.Mmio(packed struct(u32) {
        /// Accumulated Vertical back porch (in units of horizontal scan line)
        AVBP: u11,
        reserved16: u5 = 0,
        /// Accumulated Horizontal back porch (in units of pixel clock period)
        AHBP: u12,
        padding: u4 = 0,
    }),
    /// Active Width Configuration Register
    /// offset: 0x10
    AWCR: mmio.Mmio(packed struct(u32) {
        /// Accumulated Active Height (in units of horizontal scan line)
        AAH: u11,
        reserved16: u5 = 0,
        /// AAV
        AAV: u12,
        padding: u4 = 0,
    }),
    /// Total Width Configuration Register
    /// offset: 0x14
    TWCR: mmio.Mmio(packed struct(u32) {
        /// Total Height (in units of horizontal scan line)
        TOTALH: u11,
        reserved16: u5 = 0,
        /// Total Width (in units of pixel clock period)
        TOTALW: u12,
        padding: u4 = 0,
    }),
    /// Global Control Register
    /// offset: 0x18
    GCR: mmio.Mmio(packed struct(u32) {
        /// LCD-TFT controller enable bit
        LTDCEN: u1,
        reserved4: u3 = 0,
        /// Dither Blue Width
        DBW: u3,
        reserved8: u1 = 0,
        /// Dither Green Width
        DGW: u3,
        reserved12: u1 = 0,
        /// Dither Red Width
        DRW: u3,
        reserved16: u1 = 0,
        /// Dither Enable
        DEN: u1,
        reserved28: u11 = 0,
        /// Pixel Clock Polarity
        PCPOL: u1,
        /// Data Enable Polarity
        DEPOL: u1,
        /// Vertical Synchronization Polarity
        VSPOL: u1,
        /// Horizontal Synchronization Polarity
        HSPOL: u1,
    }),
    /// offset: 0x1c
    reserved28: [8]u8,
    /// Shadow Reload Configuration Register
    /// offset: 0x24
    SRCR: mmio.Mmio(packed struct(u32) {
        /// Immediate Reload
        IMR: u1,
        /// Vertical Blanking Reload
        VBR: u1,
        padding: u30 = 0,
    }),
    /// offset: 0x28
    reserved40: [4]u8,
    /// Background Color Configuration Register
    /// offset: 0x2c
    BCCR: mmio.Mmio(packed struct(u32) {
        /// Background Color Blue value
        BCBLUE: u8,
        /// Background Color Green value
        BCGREEN: u8,
        /// Background Color Red value
        BCRED: u8,
        padding: u8 = 0,
    }),
    /// offset: 0x30
    reserved48: [4]u8,
    /// Interrupt Enable Register
    /// offset: 0x34
    IER: mmio.Mmio(packed struct(u32) {
        /// Line Interrupt Enable
        LIE: u1,
        /// FIFO Underrun Interrupt Enable
        FUIE: u1,
        /// Transfer Error Interrupt Enable
        TERRIE: u1,
        /// Register Reload interrupt enable
        RRIE: u1,
        padding: u28 = 0,
    }),
    /// Interrupt Status Register
    /// offset: 0x38
    ISR: mmio.Mmio(packed struct(u32) {
        /// Line Interrupt flag
        LIF: u1,
        /// FIFO Underrun Interrupt flag
        FUIF: u1,
        /// Transfer Error interrupt flag
        TERRIF: u1,
        /// Register Reload Interrupt Flag
        RRIF: u1,
        padding: u28 = 0,
    }),
    /// Interrupt Clear Register
    /// offset: 0x3c
    ICR: mmio.Mmio(packed struct(u32) {
        /// Clears the Line Interrupt Flag
        CLIF: u1,
        /// Clears the FIFO Underrun Interrupt flag
        CFUIF: u1,
        /// Clears the Transfer Error Interrupt Flag
        CTERRIF: u1,
        /// Clears Register Reload Interrupt Flag
        CRRIF: u1,
        padding: u28 = 0,
    }),
    /// Line Interrupt Position Configuration Register
    /// offset: 0x40
    LIPCR: mmio.Mmio(packed struct(u32) {
        /// Line Interrupt Position
        LIPOS: u11,
        padding: u21 = 0,
    }),
    /// Current Position Status Register
    /// offset: 0x44
    CPSR: mmio.Mmio(packed struct(u32) {
        /// Current Y Position
        CYPOS: u16,
        /// Current X Position
        CXPOS: u16,
    }),
    /// Current Display Status Register
    /// offset: 0x48
    CDSR: mmio.Mmio(packed struct(u32) {
        /// Vertical Data Enable display Status
        VDES: u1,
        /// Horizontal Data Enable display Status
        HDES: u1,
        /// Vertical Synchronization display Status
        VSYNCS: u1,
        /// Horizontal Synchronization display Status
        HSYNCS: u1,
        padding: u28 = 0,
    }),
    /// offset: 0x4c
    reserved76: [56]u8,
    /// Layerx Control Register
    /// offset: 0x84
    L1CR: mmio.Mmio(packed struct(u32) {
        /// Layer Enable
        LEN: u1,
        /// Color Keying Enable
        COLKEN: u1,
        reserved4: u2 = 0,
        /// Color Look-Up Table Enable
        CLUTEN: u1,
        padding: u27 = 0,
    }),
    /// Layerx Window Horizontal Position Configuration Register
    /// offset: 0x88
    L1WHPCR: mmio.Mmio(packed struct(u32) {
        /// Window Horizontal Start Position
        WHSTPOS: u12,
        reserved16: u4 = 0,
        /// Window Horizontal Stop Position
        WHSPPOS: u12,
        padding: u4 = 0,
    }),
    /// Layerx Window Vertical Position Configuration Register
    /// offset: 0x8c
    L1WVPCR: mmio.Mmio(packed struct(u32) {
        /// Window Vertical Start Position
        WVSTPOS: u11,
        reserved16: u5 = 0,
        /// Window Vertical Stop Position
        WVSPPOS: u11,
        padding: u5 = 0,
    }),
    /// Layerx Color Keying Configuration Register
    /// offset: 0x90
    L1CKCR: mmio.Mmio(packed struct(u32) {
        /// Color Key Blue value
        CKBLUE: u8,
        /// Color Key Green value
        CKGREEN: u8,
        /// Color Key Red value
        CKRED: u8,
        padding: u8 = 0,
    }),
    /// Layerx Pixel Format Configuration Register
    /// offset: 0x94
    L1PFCR: mmio.Mmio(packed struct(u32) {
        /// Pixel Format
        PF: u3,
        padding: u29 = 0,
    }),
    /// Layerx Constant Alpha Configuration Register
    /// offset: 0x98
    L1CACR: mmio.Mmio(packed struct(u32) {
        /// Constant Alpha
        CONSTA: u8,
        padding: u24 = 0,
    }),
    /// Layerx Default Color Configuration Register
    /// offset: 0x9c
    L1DCCR: mmio.Mmio(packed struct(u32) {
        /// Default Color Blue
        DCBLUE: u8,
        /// Default Color Green
        DCGREEN: u8,
        /// Default Color Red
        DCRED: u8,
        /// Default Color Alpha
        DCALPHA: u8,
    }),
    /// Layerx Blending Factors Configuration Register
    /// offset: 0xa0
    L1BFCR: mmio.Mmio(packed struct(u32) {
        /// Blending Factor 2
        BF2: u3,
        reserved8: u5 = 0,
        /// Blending Factor 1
        BF1: u3,
        padding: u21 = 0,
    }),
    /// offset: 0xa4
    reserved164: [8]u8,
    /// Layerx Color Frame Buffer Address Register
    /// offset: 0xac
    L1CFBAR: mmio.Mmio(packed struct(u32) {
        /// Color Frame Buffer Start Address
        CFBADD: u32,
    }),
    /// Layerx Color Frame Buffer Length Register
    /// offset: 0xb0
    L1CFBLR: mmio.Mmio(packed struct(u32) {
        /// Color Frame Buffer Line Length
        CFBLL: u13,
        reserved16: u3 = 0,
        /// Color Frame Buffer Pitch in bytes
        CFBP: u13,
        padding: u3 = 0,
    }),
    /// Layerx ColorFrame Buffer Line Number Register
    /// offset: 0xb4
    L1CFBLNR: mmio.Mmio(packed struct(u32) {
        /// Frame Buffer Line Number
        CFBLNBR: u11,
        padding: u21 = 0,
    }),
    /// offset: 0xb8
    reserved184: [12]u8,
    /// Layerx CLUT Write Register
    /// offset: 0xc4
    L1CLUTWR: mmio.Mmio(packed struct(u32) {
        /// Blue value
        BLUE: u8,
        /// Green value
        GREEN: u8,
        /// Red value
        RED: u8,
        /// CLUT Address
        CLUTADD: u8,
    }),
    /// offset: 0xc8
    reserved200: [60]u8,
    /// Layerx Control Register
    /// offset: 0x104
    L2CR: mmio.Mmio(packed struct(u32) {
        /// Layer Enable
        LEN: u1,
        /// Color Keying Enable
        COLKEN: u1,
        reserved4: u2 = 0,
        /// Color Look-Up Table Enable
        CLUTEN: u1,
        padding: u27 = 0,
    }),
    /// Layerx Window Horizontal Position Configuration Register
    /// offset: 0x108
    L2WHPCR: mmio.Mmio(packed struct(u32) {
        /// Window Horizontal Start Position
        WHSTPOS: u12,
        reserved16: u4 = 0,
        /// Window Horizontal Stop Position
        WHSPPOS: u12,
        padding: u4 = 0,
    }),
    /// Layerx Window Vertical Position Configuration Register
    /// offset: 0x10c
    L2WVPCR: mmio.Mmio(packed struct(u32) {
        /// Window Vertical Start Position
        WVSTPOS: u11,
        reserved16: u5 = 0,
        /// Window Vertical Stop Position
        WVSPPOS: u11,
        padding: u5 = 0,
    }),
    /// Layerx Color Keying Configuration Register
    /// offset: 0x110
    L2CKCR: mmio.Mmio(packed struct(u32) {
        /// Color Key Blue value
        CKBLUE: u8,
        /// Color Key Green value
        CKGREEN: u8,
        /// Color Key Red value
        CKRED: u8,
        padding: u8 = 0,
    }),
    /// Layerx Pixel Format Configuration Register
    /// offset: 0x114
    L2PFCR: mmio.Mmio(packed struct(u32) {
        /// Pixel Format
        PF: u3,
        padding: u29 = 0,
    }),
    /// Layerx Constant Alpha Configuration Register
    /// offset: 0x118
    L2CACR: mmio.Mmio(packed struct(u32) {
        /// Constant Alpha
        CONSTA: u8,
        padding: u24 = 0,
    }),
    /// Layerx Default Color Configuration Register
    /// offset: 0x11c
    L2DCCR: mmio.Mmio(packed struct(u32) {
        /// Default Color Blue
        DCBLUE: u8,
        /// Default Color Green
        DCGREEN: u8,
        /// Default Color Red
        DCRED: u8,
        /// Default Color Alpha
        DCALPHA: u8,
    }),
    /// Layerx Blending Factors Configuration Register
    /// offset: 0x120
    L2BFCR: mmio.Mmio(packed struct(u32) {
        /// Blending Factor 2
        BF2: u3,
        reserved8: u5 = 0,
        /// Blending Factor 1
        BF1: u3,
        padding: u21 = 0,
    }),
    /// offset: 0x124
    reserved292: [8]u8,
    /// Layerx Color Frame Buffer Address Register
    /// offset: 0x12c
    L2CFBAR: mmio.Mmio(packed struct(u32) {
        /// Color Frame Buffer Start Address
        CFBADD: u32,
    }),
    /// Layerx Color Frame Buffer Length Register
    /// offset: 0x130
    L2CFBLR: mmio.Mmio(packed struct(u32) {
        /// Color Frame Buffer Line Length
        CFBLL: u13,
        reserved16: u3 = 0,
        /// Color Frame Buffer Pitch in bytes
        CFBP: u13,
        padding: u3 = 0,
    }),
    /// Layerx ColorFrame Buffer Line Number Register
    /// offset: 0x134
    L2CFBLNR: mmio.Mmio(packed struct(u32) {
        /// Frame Buffer Line Number
        CFBLNBR: u11,
        padding: u21 = 0,
    }),
    /// offset: 0x138
    reserved312: [12]u8,
    /// Layerx CLUT Write Register
    /// offset: 0x144
    L2CLUTWR: mmio.Mmio(packed struct(u32) {
        /// Blue value
        BLUE: u8,
        /// Green value
        GREEN: u8,
        /// Red value
        RED: u8,
        /// CLUT Address
        CLUTADD: u8,
    }),
};
