const mmio = @import("mmio");
const types = @import("../../types.zig");

/// Digital filter for sigma delta modulators
pub const DFSDM = extern struct {
    /// channel configuration y register
    /// offset: 0x00
    CH0CFGR1: mmio.Mmio(packed struct(u32) {
        /// SITP
        SITP: u2,
        /// SPICKSEL
        SPICKSEL: u2,
        reserved5: u1 = 0,
        /// SCDEN
        SCDEN: u1,
        /// CKABEN
        CKABEN: u1,
        /// CHEN
        CHEN: u1,
        /// CHINSEL
        CHINSEL: u1,
        reserved12: u3 = 0,
        /// DATMPX
        DATMPX: u2,
        /// DATPACK
        DATPACK: u2,
        /// CKOUTDIV
        CKOUTDIV: u8,
        reserved30: u6 = 0,
        /// CKOUTSRC
        CKOUTSRC: u1,
        /// DFSDMEN
        DFSDMEN: u1,
    }),
    /// channel configuration y register
    /// offset: 0x04
    CH0CFGR2: mmio.Mmio(packed struct(u32) {
        reserved3: u3 = 0,
        /// DTRBS
        DTRBS: u5,
        /// OFFSET
        OFFSET: u24,
    }),
    /// analog watchdog and short-circuit detector register
    /// offset: 0x08
    CH0AWSCDR: mmio.Mmio(packed struct(u32) {
        /// SCDT
        SCDT: u8,
        reserved12: u4 = 0,
        /// BKSCD
        BKSCD: u4,
        /// AWFOSR
        AWFOSR: u5,
        reserved22: u1 = 0,
        /// AWFORD
        AWFORD: u2,
        padding: u8 = 0,
    }),
    /// channel watchdog filter data register
    /// offset: 0x0c
    CH0WDATR: mmio.Mmio(packed struct(u32) {
        /// WDATA
        WDATA: u16,
        padding: u16 = 0,
    }),
    /// channel data input register
    /// offset: 0x10
    CH0DATINR: mmio.Mmio(packed struct(u32) {
        /// INDAT0
        INDAT0: u16,
        /// INDAT1
        INDAT1: u16,
    }),
    /// channel y delay register
    /// offset: 0x14
    CH0DLYR: mmio.Mmio(packed struct(u32) {
        /// PLSSKP
        PLSSKP: u6,
        padding: u26 = 0,
    }),
    /// offset: 0x18
    reserved24: [8]u8,
    /// CH1CFGR1
    /// offset: 0x20
    CH1CFGR1: mmio.Mmio(packed struct(u32) {
        /// SITP
        SITP: u2,
        /// SPICKSEL
        SPICKSEL: u2,
        reserved5: u1 = 0,
        /// SCDEN
        SCDEN: u1,
        /// CKABEN
        CKABEN: u1,
        /// CHEN
        CHEN: u1,
        /// CHINSEL
        CHINSEL: u1,
        reserved12: u3 = 0,
        /// DATMPX
        DATMPX: u2,
        /// DATPACK
        DATPACK: u2,
        padding: u16 = 0,
    }),
    /// CH1CFGR2
    /// offset: 0x24
    CH1CFGR2: mmio.Mmio(packed struct(u32) {
        reserved3: u3 = 0,
        /// DTRBS
        DTRBS: u5,
        /// OFFSET
        OFFSET: u24,
    }),
    /// CH1AWSCDR
    /// offset: 0x28
    CH1AWSCDR: mmio.Mmio(packed struct(u32) {
        /// SCDT
        SCDT: u8,
        reserved12: u4 = 0,
        /// BKSCD
        BKSCD: u4,
        /// AWFOSR
        AWFOSR: u5,
        reserved22: u1 = 0,
        /// AWFORD
        AWFORD: u2,
        padding: u8 = 0,
    }),
    /// CH1WDATR
    /// offset: 0x2c
    CH1WDATR: mmio.Mmio(packed struct(u32) {
        /// WDATA
        WDATA: u16,
        padding: u16 = 0,
    }),
    /// CH1DATINR
    /// offset: 0x30
    CH1DATINR: mmio.Mmio(packed struct(u32) {
        /// INDAT0
        INDAT0: u16,
        /// INDAT1
        INDAT1: u16,
    }),
    /// channel y delay register
    /// offset: 0x34
    CH1DLYR: mmio.Mmio(packed struct(u32) {
        /// PLSSKP
        PLSSKP: u6,
        padding: u26 = 0,
    }),
    /// offset: 0x38
    reserved56: [8]u8,
    /// CH2CFGR1
    /// offset: 0x40
    CH2CFGR1: mmio.Mmio(packed struct(u32) {
        /// SITP
        SITP: u2,
        /// SPICKSEL
        SPICKSEL: u2,
        reserved5: u1 = 0,
        /// SCDEN
        SCDEN: u1,
        /// CKABEN
        CKABEN: u1,
        /// CHEN
        CHEN: u1,
        /// CHINSEL
        CHINSEL: u1,
        reserved12: u3 = 0,
        /// DATMPX
        DATMPX: u2,
        /// DATPACK
        DATPACK: u2,
        padding: u16 = 0,
    }),
    /// CH2CFGR2
    /// offset: 0x44
    CH2CFGR2: mmio.Mmio(packed struct(u32) {
        reserved3: u3 = 0,
        /// DTRBS
        DTRBS: u5,
        /// OFFSET
        OFFSET: u24,
    }),
    /// CH2AWSCDR
    /// offset: 0x48
    CH2AWSCDR: mmio.Mmio(packed struct(u32) {
        /// SCDT
        SCDT: u8,
        reserved12: u4 = 0,
        /// BKSCD
        BKSCD: u4,
        /// AWFOSR
        AWFOSR: u5,
        reserved22: u1 = 0,
        /// AWFORD
        AWFORD: u2,
        padding: u8 = 0,
    }),
    /// CH2WDATR
    /// offset: 0x4c
    CH2WDATR: mmio.Mmio(packed struct(u32) {
        /// WDATA
        WDATA: u16,
        padding: u16 = 0,
    }),
    /// CH2DATINR
    /// offset: 0x50
    CH2DATINR: mmio.Mmio(packed struct(u32) {
        /// INDAT0
        INDAT0: u16,
        /// INDAT1
        INDAT1: u16,
    }),
    /// channel y delay register
    /// offset: 0x54
    CH2DLYR: mmio.Mmio(packed struct(u32) {
        /// PLSSKP
        PLSSKP: u6,
        padding: u26 = 0,
    }),
    /// offset: 0x58
    reserved88: [8]u8,
    /// CH3CFGR1
    /// offset: 0x60
    CH3CFGR1: mmio.Mmio(packed struct(u32) {
        /// SITP
        SITP: u2,
        /// SPICKSEL
        SPICKSEL: u2,
        reserved5: u1 = 0,
        /// SCDEN
        SCDEN: u1,
        /// CKABEN
        CKABEN: u1,
        /// CHEN
        CHEN: u1,
        /// CHINSEL
        CHINSEL: u1,
        reserved12: u3 = 0,
        /// DATMPX
        DATMPX: u2,
        /// DATPACK
        DATPACK: u2,
        padding: u16 = 0,
    }),
    /// CH3CFGR2
    /// offset: 0x64
    CH3CFGR2: mmio.Mmio(packed struct(u32) {
        reserved3: u3 = 0,
        /// DTRBS
        DTRBS: u5,
        /// OFFSET
        OFFSET: u24,
    }),
    /// CH3AWSCDR
    /// offset: 0x68
    CH3AWSCDR: mmio.Mmio(packed struct(u32) {
        /// SCDT
        SCDT: u8,
        reserved12: u4 = 0,
        /// BKSCD
        BKSCD: u4,
        /// AWFOSR
        AWFOSR: u5,
        reserved22: u1 = 0,
        /// AWFORD
        AWFORD: u2,
        padding: u8 = 0,
    }),
    /// CH3WDATR
    /// offset: 0x6c
    CH3WDATR: mmio.Mmio(packed struct(u32) {
        /// WDATA
        WDATA: u16,
        padding: u16 = 0,
    }),
    /// CH3DATINR
    /// offset: 0x70
    CH3DATINR: mmio.Mmio(packed struct(u32) {
        /// INDAT0
        INDAT0: u16,
        /// INDAT1
        INDAT1: u16,
    }),
    /// channel y delay register
    /// offset: 0x74
    CH3DLYR: mmio.Mmio(packed struct(u32) {
        /// PLSSKP
        PLSSKP: u6,
        padding: u26 = 0,
    }),
    /// offset: 0x78
    reserved120: [8]u8,
    /// CH4CFGR1
    /// offset: 0x80
    CH4CFGR1: mmio.Mmio(packed struct(u32) {
        /// SITP
        SITP: u2,
        /// SPICKSEL
        SPICKSEL: u2,
        reserved5: u1 = 0,
        /// SCDEN
        SCDEN: u1,
        /// CKABEN
        CKABEN: u1,
        /// CHEN
        CHEN: u1,
        /// CHINSEL
        CHINSEL: u1,
        reserved12: u3 = 0,
        /// DATMPX
        DATMPX: u2,
        /// DATPACK
        DATPACK: u2,
        padding: u16 = 0,
    }),
    /// CH4CFGR2
    /// offset: 0x84
    CH4CFGR2: mmio.Mmio(packed struct(u32) {
        reserved3: u3 = 0,
        /// DTRBS
        DTRBS: u5,
        /// OFFSET
        OFFSET: u24,
    }),
    /// CH4AWSCDR
    /// offset: 0x88
    CH4AWSCDR: mmio.Mmio(packed struct(u32) {
        /// SCDT
        SCDT: u8,
        reserved12: u4 = 0,
        /// BKSCD
        BKSCD: u4,
        /// AWFOSR
        AWFOSR: u5,
        reserved22: u1 = 0,
        /// AWFORD
        AWFORD: u2,
        padding: u8 = 0,
    }),
    /// CH4WDATR
    /// offset: 0x8c
    CH4WDATR: mmio.Mmio(packed struct(u32) {
        /// WDATA
        WDATA: u16,
        padding: u16 = 0,
    }),
    /// CH4DATINR
    /// offset: 0x90
    CH4DATINR: mmio.Mmio(packed struct(u32) {
        /// INDAT0
        INDAT0: u16,
        /// INDAT1
        INDAT1: u16,
    }),
    /// channel y delay register
    /// offset: 0x94
    CH4DLYR: mmio.Mmio(packed struct(u32) {
        /// PLSSKP
        PLSSKP: u6,
        padding: u26 = 0,
    }),
    /// offset: 0x98
    reserved152: [8]u8,
    /// CH5CFGR1
    /// offset: 0xa0
    CH5CFGR1: mmio.Mmio(packed struct(u32) {
        /// SITP
        SITP: u2,
        /// SPICKSEL
        SPICKSEL: u2,
        reserved5: u1 = 0,
        /// SCDEN
        SCDEN: u1,
        /// CKABEN
        CKABEN: u1,
        /// CHEN
        CHEN: u1,
        /// CHINSEL
        CHINSEL: u1,
        reserved12: u3 = 0,
        /// DATMPX
        DATMPX: u2,
        /// DATPACK
        DATPACK: u2,
        padding: u16 = 0,
    }),
    /// CH5CFGR2
    /// offset: 0xa4
    CH5CFGR2: mmio.Mmio(packed struct(u32) {
        reserved3: u3 = 0,
        /// DTRBS
        DTRBS: u5,
        /// OFFSET
        OFFSET: u24,
    }),
    /// CH5AWSCDR
    /// offset: 0xa8
    CH5AWSCDR: mmio.Mmio(packed struct(u32) {
        /// SCDT
        SCDT: u8,
        reserved12: u4 = 0,
        /// BKSCD
        BKSCD: u4,
        /// AWFOSR
        AWFOSR: u5,
        reserved22: u1 = 0,
        /// AWFORD
        AWFORD: u2,
        padding: u8 = 0,
    }),
    /// CH5WDATR
    /// offset: 0xac
    CH5WDATR: mmio.Mmio(packed struct(u32) {
        /// WDATA
        WDATA: u16,
        padding: u16 = 0,
    }),
    /// CH5DATINR
    /// offset: 0xb0
    CH5DATINR: mmio.Mmio(packed struct(u32) {
        /// INDAT0
        INDAT0: u16,
        /// INDAT1
        INDAT1: u16,
    }),
    /// channel y delay register
    /// offset: 0xb4
    CH5DLYR: mmio.Mmio(packed struct(u32) {
        /// PLSSKP
        PLSSKP: u6,
        padding: u26 = 0,
    }),
    /// offset: 0xb8
    reserved184: [8]u8,
    /// CH6CFGR1
    /// offset: 0xc0
    CH6CFGR1: mmio.Mmio(packed struct(u32) {
        /// SITP
        SITP: u2,
        /// SPICKSEL
        SPICKSEL: u2,
        reserved5: u1 = 0,
        /// SCDEN
        SCDEN: u1,
        /// CKABEN
        CKABEN: u1,
        /// CHEN
        CHEN: u1,
        /// CHINSEL
        CHINSEL: u1,
        reserved12: u3 = 0,
        /// DATMPX
        DATMPX: u2,
        /// DATPACK
        DATPACK: u2,
        padding: u16 = 0,
    }),
    /// CH6CFGR2
    /// offset: 0xc4
    CH6CFGR2: mmio.Mmio(packed struct(u32) {
        reserved3: u3 = 0,
        /// DTRBS
        DTRBS: u5,
        /// OFFSET
        OFFSET: u24,
    }),
    /// CH6AWSCDR
    /// offset: 0xc8
    CH6AWSCDR: mmio.Mmio(packed struct(u32) {
        /// SCDT
        SCDT: u8,
        reserved12: u4 = 0,
        /// BKSCD
        BKSCD: u4,
        /// AWFOSR
        AWFOSR: u5,
        reserved22: u1 = 0,
        /// AWFORD
        AWFORD: u2,
        padding: u8 = 0,
    }),
    /// CH6WDATR
    /// offset: 0xcc
    CH6WDATR: mmio.Mmio(packed struct(u32) {
        /// WDATA
        WDATA: u16,
        padding: u16 = 0,
    }),
    /// CH6DATINR
    /// offset: 0xd0
    CH6DATINR: mmio.Mmio(packed struct(u32) {
        /// INDAT0
        INDAT0: u16,
        /// INDAT1
        INDAT1: u16,
    }),
    /// channel y delay register
    /// offset: 0xd4
    CH6DLYR: mmio.Mmio(packed struct(u32) {
        /// PLSSKP
        PLSSKP: u6,
        padding: u26 = 0,
    }),
    /// offset: 0xd8
    reserved216: [8]u8,
    /// CH7CFGR1
    /// offset: 0xe0
    CH7CFGR1: mmio.Mmio(packed struct(u32) {
        /// SITP
        SITP: u2,
        /// SPICKSEL
        SPICKSEL: u2,
        reserved5: u1 = 0,
        /// SCDEN
        SCDEN: u1,
        /// CKABEN
        CKABEN: u1,
        /// CHEN
        CHEN: u1,
        /// CHINSEL
        CHINSEL: u1,
        reserved12: u3 = 0,
        /// DATMPX
        DATMPX: u2,
        /// DATPACK
        DATPACK: u2,
        padding: u16 = 0,
    }),
    /// CH7CFGR2
    /// offset: 0xe4
    CH7CFGR2: mmio.Mmio(packed struct(u32) {
        reserved3: u3 = 0,
        /// DTRBS
        DTRBS: u5,
        /// OFFSET
        OFFSET: u24,
    }),
    /// CH7AWSCDR
    /// offset: 0xe8
    CH7AWSCDR: mmio.Mmio(packed struct(u32) {
        /// SCDT
        SCDT: u8,
        reserved12: u4 = 0,
        /// BKSCD
        BKSCD: u4,
        /// AWFOSR
        AWFOSR: u5,
        reserved22: u1 = 0,
        /// AWFORD
        AWFORD: u2,
        padding: u8 = 0,
    }),
    /// CH7WDATR
    /// offset: 0xec
    CH7WDATR: mmio.Mmio(packed struct(u32) {
        /// WDATA
        WDATA: u16,
        padding: u16 = 0,
    }),
    /// CH7DATINR
    /// offset: 0xf0
    CH7DATINR: mmio.Mmio(packed struct(u32) {
        /// INDAT0
        INDAT0: u16,
        /// INDAT1
        INDAT1: u16,
    }),
    /// channel y delay register
    /// offset: 0xf4
    CH7DLYR: mmio.Mmio(packed struct(u32) {
        /// PLSSKP
        PLSSKP: u6,
        padding: u26 = 0,
    }),
    /// offset: 0xf8
    reserved248: [8]u8,
    /// control register 1
    /// offset: 0x100
    DFSDM_FLT0CR1: mmio.Mmio(packed struct(u32) {
        /// DFSDM enable
        DFEN: u1,
        /// Start a conversion of the injected group of channels
        JSWSTART: u1,
        reserved3: u1 = 0,
        /// Launch an injected conversion synchronously with the DFSDM0 JSWSTART trigger
        JSYNC: u1,
        /// Scanning conversion mode for injected conversions
        JSCAN: u1,
        /// DMA channel enabled to read data for the injected channel group
        JDMAEN: u1,
        reserved8: u2 = 0,
        /// Trigger signal selection for launching injected conversions
        JEXTSEL: u3,
        reserved13: u2 = 0,
        /// Trigger enable and trigger edge selection for injected conversions
        JEXTEN: u2,
        reserved17: u2 = 0,
        /// Software start of a conversion on the regular channel
        RSWSTART: u1,
        /// Continuous mode selection for regular conversions
        RCONT: u1,
        /// Launch regular conversion synchronously with DFSDM0
        RSYNC: u1,
        reserved21: u1 = 0,
        /// DMA channel enabled to read data for the regular conversion
        RDMAEN: u1,
        reserved24: u2 = 0,
        /// Regular channel selection
        RCH: u3,
        reserved29: u2 = 0,
        /// Fast conversion mode selection for regular conversions
        FAST: u1,
        /// Analog watchdog fast mode select
        AWFSEL: u1,
        padding: u1 = 0,
    }),
    /// control register 2
    /// offset: 0x104
    DFSDM_FLT0CR2: mmio.Mmio(packed struct(u32) {
        /// Injected end of conversion interrupt enable
        JEOCIE: u1,
        /// Regular end of conversion interrupt enable
        REOCIE: u1,
        /// Injected data overrun interrupt enable
        JOVRIE: u1,
        /// Regular data overrun interrupt enable
        ROVRIE: u1,
        /// Analog watchdog interrupt enable
        AWDIE: u1,
        /// Short-circuit detector interrupt enable
        SCDIE: u1,
        /// Clock absence interrupt enable
        CKABIE: u1,
        reserved8: u1 = 0,
        /// Extremes detector channel selection
        EXCH: u8,
        /// Analog watchdog channel selection
        AWDCH: u8,
        padding: u8 = 0,
    }),
    /// interrupt and status register
    /// offset: 0x108
    DFSDM_FLT0ISR: mmio.Mmio(packed struct(u32) {
        /// End of injected conversion flag
        JEOCF: u1,
        /// End of regular conversion flag
        REOCF: u1,
        /// Injected conversion overrun flag
        JOVRF: u1,
        /// Regular conversion overrun flag
        ROVRF: u1,
        /// Analog watchdog
        AWDF: u1,
        reserved13: u8 = 0,
        /// Injected conversion in progress status
        JCIP: u1,
        /// Regular conversion in progress status
        RCIP: u1,
        reserved16: u1 = 0,
        /// Clock absence flag
        CKABF: u8,
        /// short-circuit detector flag
        SCDF: u8,
    }),
    /// interrupt flag clear register
    /// offset: 0x10c
    DFSDM_FLT0ICR: mmio.Mmio(packed struct(u32) {
        reserved2: u2 = 0,
        /// Clear the injected conversion overrun flag
        CLRJOVRF: u1,
        /// Clear the regular conversion overrun flag
        CLRROVRF: u1,
        reserved16: u12 = 0,
        /// Clear the clock absence flag
        CLRCKABF: u8,
        /// Clear the short-circuit detector flag
        CLRSCDF: u8,
    }),
    /// injected channel group selection register
    /// offset: 0x110
    DFSDM_FLT0JCHGR: mmio.Mmio(packed struct(u32) {
        /// Injected channel group selection
        JCHG: u8,
        padding: u24 = 0,
    }),
    /// filter control register
    /// offset: 0x114
    DFSDM_FLT0FCR: mmio.Mmio(packed struct(u32) {
        /// Integrator oversampling ratio (averaging length)
        IOSR: u8,
        reserved16: u8 = 0,
        /// Sinc filter oversampling ratio (decimation rate)
        FOSR: u10,
        reserved29: u3 = 0,
        /// Sinc filter order
        FORD: u3,
    }),
    /// data register for injected group
    /// offset: 0x118
    DFSDM_FLT0JDATAR: mmio.Mmio(packed struct(u32) {
        /// Injected channel most recently converted
        JDATACH: u3,
        reserved8: u5 = 0,
        /// Injected group conversion data
        JDATA: u24,
    }),
    /// data register for the regular channel
    /// offset: 0x11c
    DFSDM_FLT0RDATAR: mmio.Mmio(packed struct(u32) {
        /// Regular channel most recently converted
        RDATACH: u3,
        reserved4: u1 = 0,
        /// Regular channel pending data
        RPEND: u1,
        reserved8: u3 = 0,
        /// Regular channel conversion data
        RDATA: u24,
    }),
    /// analog watchdog high threshold register
    /// offset: 0x120
    DFSDM_FLT0AWHTR: mmio.Mmio(packed struct(u32) {
        /// Break signal assignment to analog watchdog high threshold event
        BKAWH: u4,
        reserved8: u4 = 0,
        /// Analog watchdog high threshold
        AWHT: u24,
    }),
    /// analog watchdog low threshold register
    /// offset: 0x124
    DFSDM_FLT0AWLTR: mmio.Mmio(packed struct(u32) {
        /// Break signal assignment to analog watchdog low threshold event
        BKAWL: u4,
        reserved8: u4 = 0,
        /// Analog watchdog low threshold
        AWLT: u24,
    }),
    /// analog watchdog status register
    /// offset: 0x128
    DFSDM_FLT0AWSR: mmio.Mmio(packed struct(u32) {
        /// Analog watchdog low threshold flag
        AWLTF: u8,
        /// Analog watchdog high threshold flag
        AWHTF: u8,
        padding: u16 = 0,
    }),
    /// analog watchdog clear flag register
    /// offset: 0x12c
    DFSDM_FLT0AWCFR: mmio.Mmio(packed struct(u32) {
        /// Clear the analog watchdog low threshold flag
        CLRAWLTF: u8,
        /// Clear the analog watchdog high threshold flag
        CLRAWHTF: u8,
        padding: u16 = 0,
    }),
    /// Extremes detector maximum register
    /// offset: 0x130
    DFSDM_FLT0EXMAX: mmio.Mmio(packed struct(u32) {
        /// Extremes detector maximum data channel
        EXMAXCH: u3,
        reserved8: u5 = 0,
        /// Extremes detector maximum value
        EXMAX: u24,
    }),
    /// Extremes detector minimum register
    /// offset: 0x134
    DFSDM_FLT0EXMIN: mmio.Mmio(packed struct(u32) {
        /// Extremes detector minimum data channel
        EXMINCH: u3,
        reserved8: u5 = 0,
        /// EXMIN
        EXMIN: u24,
    }),
    /// conversion timer register
    /// offset: 0x138
    DFSDM_FLT0CNVTIMR: mmio.Mmio(packed struct(u32) {
        reserved4: u4 = 0,
        /// 28-bit timer counting conversion time t = CNVCNT[27:0] / fDFSDM_CKIN
        CNVCNT: u28,
    }),
    /// offset: 0x13c
    reserved316: [68]u8,
    /// control register 1
    /// offset: 0x180
    DFSDM_FLT1CR1: mmio.Mmio(packed struct(u32) {
        /// DFSDM enable
        DFEN: u1,
        /// Start a conversion of the injected group of channels
        JSWSTART: u1,
        reserved3: u1 = 0,
        /// Launch an injected conversion synchronously with the DFSDM0 JSWSTART trigger
        JSYNC: u1,
        /// Scanning conversion mode for injected conversions
        JSCAN: u1,
        /// DMA channel enabled to read data for the injected channel group
        JDMAEN: u1,
        reserved8: u2 = 0,
        /// Trigger signal selection for launching injected conversions
        JEXTSEL: u3,
        reserved13: u2 = 0,
        /// Trigger enable and trigger edge selection for injected conversions
        JEXTEN: u2,
        reserved17: u2 = 0,
        /// Software start of a conversion on the regular channel
        RSWSTART: u1,
        /// Continuous mode selection for regular conversions
        RCONT: u1,
        /// Launch regular conversion synchronously with DFSDM0
        RSYNC: u1,
        reserved21: u1 = 0,
        /// DMA channel enabled to read data for the regular conversion
        RDMAEN: u1,
        reserved24: u2 = 0,
        /// Regular channel selection
        RCH: u3,
        reserved29: u2 = 0,
        /// Fast conversion mode selection for regular conversions
        FAST: u1,
        /// Analog watchdog fast mode select
        AWFSEL: u1,
        padding: u1 = 0,
    }),
    /// control register 2
    /// offset: 0x184
    DFSDM_FLT1CR2: mmio.Mmio(packed struct(u32) {
        /// Injected end of conversion interrupt enable
        JEOCIE: u1,
        /// Regular end of conversion interrupt enable
        REOCIE: u1,
        /// Injected data overrun interrupt enable
        JOVRIE: u1,
        /// Regular data overrun interrupt enable
        ROVRIE: u1,
        /// Analog watchdog interrupt enable
        AWDIE: u1,
        /// Short-circuit detector interrupt enable
        SCDIE: u1,
        /// Clock absence interrupt enable
        CKABIE: u1,
        reserved8: u1 = 0,
        /// Extremes detector channel selection
        EXCH: u8,
        /// Analog watchdog channel selection
        AWDCH: u8,
        padding: u8 = 0,
    }),
    /// interrupt and status register
    /// offset: 0x188
    DFSDM_FLT1ISR: mmio.Mmio(packed struct(u32) {
        /// End of injected conversion flag
        JEOCF: u1,
        /// End of regular conversion flag
        REOCF: u1,
        /// Injected conversion overrun flag
        JOVRF: u1,
        /// Regular conversion overrun flag
        ROVRF: u1,
        /// Analog watchdog
        AWDF: u1,
        reserved13: u8 = 0,
        /// Injected conversion in progress status
        JCIP: u1,
        /// Regular conversion in progress status
        RCIP: u1,
        reserved16: u1 = 0,
        /// Clock absence flag
        CKABF: u8,
        /// short-circuit detector flag
        SCDF: u8,
    }),
    /// interrupt flag clear register
    /// offset: 0x18c
    DFSDM_FLT1ICR: mmio.Mmio(packed struct(u32) {
        reserved2: u2 = 0,
        /// Clear the injected conversion overrun flag
        CLRJOVRF: u1,
        /// Clear the regular conversion overrun flag
        CLRROVRF: u1,
        reserved16: u12 = 0,
        /// Clear the clock absence flag
        CLRCKABF: u8,
        /// Clear the short-circuit detector flag
        CLRSCDF: u8,
    }),
    /// injected channel group selection register
    /// offset: 0x190
    DFSDM_FLT1CHGR: mmio.Mmio(packed struct(u32) {
        /// Injected channel group selection
        JCHG: u8,
        padding: u24 = 0,
    }),
    /// filter control register
    /// offset: 0x194
    DFSDM_FLT1FCR: mmio.Mmio(packed struct(u32) {
        /// Integrator oversampling ratio (averaging length)
        IOSR: u8,
        reserved16: u8 = 0,
        /// Sinc filter oversampling ratio (decimation rate)
        FOSR: u10,
        reserved29: u3 = 0,
        /// Sinc filter order
        FORD: u3,
    }),
    /// data register for injected group
    /// offset: 0x198
    DFSDM_FLT1JDATAR: mmio.Mmio(packed struct(u32) {
        /// Injected channel most recently converted
        JDATACH: u3,
        reserved8: u5 = 0,
        /// Injected group conversion data
        JDATA: u24,
    }),
    /// data register for the regular channel
    /// offset: 0x19c
    DFSDM_FLT1RDATAR: mmio.Mmio(packed struct(u32) {
        /// Regular channel most recently converted
        RDATACH: u3,
        reserved4: u1 = 0,
        /// Regular channel pending data
        RPEND: u1,
        reserved8: u3 = 0,
        /// Regular channel conversion data
        RDATA: u24,
    }),
    /// analog watchdog high threshold register
    /// offset: 0x1a0
    DFSDM_FLT1AWHTR: mmio.Mmio(packed struct(u32) {
        /// Break signal assignment to analog watchdog high threshold event
        BKAWH: u4,
        reserved8: u4 = 0,
        /// Analog watchdog high threshold
        AWHT: u24,
    }),
    /// analog watchdog low threshold register
    /// offset: 0x1a4
    DFSDM_FLT1AWLTR: mmio.Mmio(packed struct(u32) {
        /// Break signal assignment to analog watchdog low threshold event
        BKAWL: u4,
        reserved8: u4 = 0,
        /// Analog watchdog low threshold
        AWLT: u24,
    }),
    /// analog watchdog status register
    /// offset: 0x1a8
    DFSDM_FLT1AWSR: mmio.Mmio(packed struct(u32) {
        /// Analog watchdog low threshold flag
        AWLTF: u8,
        /// Analog watchdog high threshold flag
        AWHTF: u8,
        padding: u16 = 0,
    }),
    /// analog watchdog clear flag register
    /// offset: 0x1ac
    DFSDM_FLT1AWCFR: mmio.Mmio(packed struct(u32) {
        /// Clear the analog watchdog low threshold flag
        CLRAWLTF: u8,
        /// Clear the analog watchdog high threshold flag
        CLRAWHTF: u8,
        padding: u16 = 0,
    }),
    /// Extremes detector maximum register
    /// offset: 0x1b0
    DFSDM_FLT1EXMAX: mmio.Mmio(packed struct(u32) {
        /// Extremes detector maximum data channel
        EXMAXCH: u3,
        reserved8: u5 = 0,
        /// Extremes detector maximum value
        EXMAX: u24,
    }),
    /// Extremes detector minimum register
    /// offset: 0x1b4
    DFSDM_FLT1EXMIN: mmio.Mmio(packed struct(u32) {
        /// Extremes detector minimum data channel
        EXMINCH: u3,
        reserved8: u5 = 0,
        /// EXMIN
        EXMIN: u24,
    }),
    /// conversion timer register
    /// offset: 0x1b8
    DFSDM_FLT1CNVTIMR: mmio.Mmio(packed struct(u32) {
        reserved4: u4 = 0,
        /// 28-bit timer counting conversion time t = CNVCNT[27:0] / fDFSDM_CKIN
        CNVCNT: u28,
    }),
    /// offset: 0x1bc
    reserved444: [68]u8,
    /// control register 1
    /// offset: 0x200
    DFSDM_FLT2CR1: mmio.Mmio(packed struct(u32) {
        /// DFSDM enable
        DFEN: u1,
        /// Start a conversion of the injected group of channels
        JSWSTART: u1,
        reserved3: u1 = 0,
        /// Launch an injected conversion synchronously with the DFSDM0 JSWSTART trigger
        JSYNC: u1,
        /// Scanning conversion mode for injected conversions
        JSCAN: u1,
        /// DMA channel enabled to read data for the injected channel group
        JDMAEN: u1,
        reserved8: u2 = 0,
        /// Trigger signal selection for launching injected conversions
        JEXTSEL: u3,
        reserved13: u2 = 0,
        /// Trigger enable and trigger edge selection for injected conversions
        JEXTEN: u2,
        reserved17: u2 = 0,
        /// Software start of a conversion on the regular channel
        RSWSTART: u1,
        /// Continuous mode selection for regular conversions
        RCONT: u1,
        /// Launch regular conversion synchronously with DFSDM0
        RSYNC: u1,
        reserved21: u1 = 0,
        /// DMA channel enabled to read data for the regular conversion
        RDMAEN: u1,
        reserved24: u2 = 0,
        /// Regular channel selection
        RCH: u3,
        reserved29: u2 = 0,
        /// Fast conversion mode selection for regular conversions
        FAST: u1,
        /// Analog watchdog fast mode select
        AWFSEL: u1,
        padding: u1 = 0,
    }),
    /// control register 2
    /// offset: 0x204
    DFSDM_FLT2CR2: mmio.Mmio(packed struct(u32) {
        /// Injected end of conversion interrupt enable
        JEOCIE: u1,
        /// Regular end of conversion interrupt enable
        REOCIE: u1,
        /// Injected data overrun interrupt enable
        JOVRIE: u1,
        /// Regular data overrun interrupt enable
        ROVRIE: u1,
        /// Analog watchdog interrupt enable
        AWDIE: u1,
        /// Short-circuit detector interrupt enable
        SCDIE: u1,
        /// Clock absence interrupt enable
        CKABIE: u1,
        reserved8: u1 = 0,
        /// Extremes detector channel selection
        EXCH: u8,
        /// Analog watchdog channel selection
        AWDCH: u8,
        padding: u8 = 0,
    }),
    /// interrupt and status register
    /// offset: 0x208
    DFSDM_FLT2ISR: mmio.Mmio(packed struct(u32) {
        /// End of injected conversion flag
        JEOCF: u1,
        /// End of regular conversion flag
        REOCF: u1,
        /// Injected conversion overrun flag
        JOVRF: u1,
        /// Regular conversion overrun flag
        ROVRF: u1,
        /// Analog watchdog
        AWDF: u1,
        reserved13: u8 = 0,
        /// Injected conversion in progress status
        JCIP: u1,
        /// Regular conversion in progress status
        RCIP: u1,
        reserved16: u1 = 0,
        /// Clock absence flag
        CKABF: u8,
        /// short-circuit detector flag
        SCDF: u8,
    }),
    /// interrupt flag clear register
    /// offset: 0x20c
    DFSDM_FLT2ICR: mmio.Mmio(packed struct(u32) {
        reserved2: u2 = 0,
        /// Clear the injected conversion overrun flag
        CLRJOVRF: u1,
        /// Clear the regular conversion overrun flag
        CLRROVRF: u1,
        reserved16: u12 = 0,
        /// Clear the clock absence flag
        CLRCKABF: u8,
        /// Clear the short-circuit detector flag
        CLRSCDF: u8,
    }),
    /// injected channel group selection register
    /// offset: 0x210
    DFSDM_FLT2JCHGR: mmio.Mmio(packed struct(u32) {
        /// Injected channel group selection
        JCHG: u8,
        padding: u24 = 0,
    }),
    /// filter control register
    /// offset: 0x214
    DFSDM_FLT2FCR: mmio.Mmio(packed struct(u32) {
        /// Integrator oversampling ratio (averaging length)
        IOSR: u8,
        reserved16: u8 = 0,
        /// Sinc filter oversampling ratio (decimation rate)
        FOSR: u10,
        reserved29: u3 = 0,
        /// Sinc filter order
        FORD: u3,
    }),
    /// data register for injected group
    /// offset: 0x218
    DFSDM_FLT2JDATAR: mmio.Mmio(packed struct(u32) {
        /// Injected channel most recently converted
        JDATACH: u3,
        reserved8: u5 = 0,
        /// Injected group conversion data
        JDATA: u24,
    }),
    /// data register for the regular channel
    /// offset: 0x21c
    DFSDM_FLT2RDATAR: mmio.Mmio(packed struct(u32) {
        /// Regular channel most recently converted
        RDATACH: u3,
        reserved4: u1 = 0,
        /// Regular channel pending data
        RPEND: u1,
        reserved8: u3 = 0,
        /// Regular channel conversion data
        RDATA: u24,
    }),
    /// analog watchdog high threshold register
    /// offset: 0x220
    DFSDM_FLT2AWHTR: mmio.Mmio(packed struct(u32) {
        /// Break signal assignment to analog watchdog high threshold event
        BKAWH: u4,
        reserved8: u4 = 0,
        /// Analog watchdog high threshold
        AWHT: u24,
    }),
    /// analog watchdog low threshold register
    /// offset: 0x224
    DFSDM_FLT2AWLTR: mmio.Mmio(packed struct(u32) {
        /// Break signal assignment to analog watchdog low threshold event
        BKAWL: u4,
        reserved8: u4 = 0,
        /// Analog watchdog low threshold
        AWLT: u24,
    }),
    /// analog watchdog status register
    /// offset: 0x228
    DFSDM_FLT2AWSR: mmio.Mmio(packed struct(u32) {
        /// Analog watchdog low threshold flag
        AWLTF: u8,
        /// Analog watchdog high threshold flag
        AWHTF: u8,
        padding: u16 = 0,
    }),
    /// analog watchdog clear flag register
    /// offset: 0x22c
    DFSDM_FLT2AWCFR: mmio.Mmio(packed struct(u32) {
        /// Clear the analog watchdog low threshold flag
        CLRAWLTF: u8,
        /// Clear the analog watchdog high threshold flag
        CLRAWHTF: u8,
        padding: u16 = 0,
    }),
    /// Extremes detector maximum register
    /// offset: 0x230
    DFSDM_FLT2EXMAX: mmio.Mmio(packed struct(u32) {
        /// Extremes detector maximum data channel
        EXMAXCH: u3,
        reserved8: u5 = 0,
        /// Extremes detector maximum value
        EXMAX: u24,
    }),
    /// Extremes detector minimum register
    /// offset: 0x234
    DFSDM_FLT2EXMIN: mmio.Mmio(packed struct(u32) {
        /// Extremes detector minimum data channel
        EXMINCH: u3,
        reserved8: u5 = 0,
        /// EXMIN
        EXMIN: u24,
    }),
    /// conversion timer register
    /// offset: 0x238
    DFSDM_FLT2CNVTIMR: mmio.Mmio(packed struct(u32) {
        reserved4: u4 = 0,
        /// 28-bit timer counting conversion time t = CNVCNT[27:0] / fDFSDM_CKIN
        CNVCNT: u28,
    }),
    /// offset: 0x23c
    reserved572: [68]u8,
    /// control register 1
    /// offset: 0x280
    DFSDM_FLT3CR1: mmio.Mmio(packed struct(u32) {
        /// DFSDM enable
        DFEN: u1,
        /// Start a conversion of the injected group of channels
        JSWSTART: u1,
        reserved3: u1 = 0,
        /// Launch an injected conversion synchronously with the DFSDM0 JSWSTART trigger
        JSYNC: u1,
        /// Scanning conversion mode for injected conversions
        JSCAN: u1,
        /// DMA channel enabled to read data for the injected channel group
        JDMAEN: u1,
        reserved8: u2 = 0,
        /// Trigger signal selection for launching injected conversions
        JEXTSEL: u3,
        reserved13: u2 = 0,
        /// Trigger enable and trigger edge selection for injected conversions
        JEXTEN: u2,
        reserved17: u2 = 0,
        /// Software start of a conversion on the regular channel
        RSWSTART: u1,
        /// Continuous mode selection for regular conversions
        RCONT: u1,
        /// Launch regular conversion synchronously with DFSDM0
        RSYNC: u1,
        reserved21: u1 = 0,
        /// DMA channel enabled to read data for the regular conversion
        RDMAEN: u1,
        reserved24: u2 = 0,
        /// Regular channel selection
        RCH: u3,
        reserved29: u2 = 0,
        /// Fast conversion mode selection for regular conversions
        FAST: u1,
        /// Analog watchdog fast mode select
        AWFSEL: u1,
        padding: u1 = 0,
    }),
    /// control register 2
    /// offset: 0x284
    DFSDM_FLT3CR2: mmio.Mmio(packed struct(u32) {
        /// Injected end of conversion interrupt enable
        JEOCIE: u1,
        /// Regular end of conversion interrupt enable
        REOCIE: u1,
        /// Injected data overrun interrupt enable
        JOVRIE: u1,
        /// Regular data overrun interrupt enable
        ROVRIE: u1,
        /// Analog watchdog interrupt enable
        AWDIE: u1,
        /// Short-circuit detector interrupt enable
        SCDIE: u1,
        /// Clock absence interrupt enable
        CKABIE: u1,
        reserved8: u1 = 0,
        /// Extremes detector channel selection
        EXCH: u8,
        /// Analog watchdog channel selection
        AWDCH: u8,
        padding: u8 = 0,
    }),
    /// interrupt and status register
    /// offset: 0x288
    DFSDM_FLT3ISR: mmio.Mmio(packed struct(u32) {
        /// End of injected conversion flag
        JEOCF: u1,
        /// End of regular conversion flag
        REOCF: u1,
        /// Injected conversion overrun flag
        JOVRF: u1,
        /// Regular conversion overrun flag
        ROVRF: u1,
        /// Analog watchdog
        AWDF: u1,
        reserved13: u8 = 0,
        /// Injected conversion in progress status
        JCIP: u1,
        /// Regular conversion in progress status
        RCIP: u1,
        reserved16: u1 = 0,
        /// Clock absence flag
        CKABF: u8,
        /// short-circuit detector flag
        SCDF: u8,
    }),
    /// interrupt flag clear register
    /// offset: 0x28c
    DFSDM_FLT3ICR: mmio.Mmio(packed struct(u32) {
        reserved2: u2 = 0,
        /// Clear the injected conversion overrun flag
        CLRJOVRF: u1,
        /// Clear the regular conversion overrun flag
        CLRROVRF: u1,
        reserved16: u12 = 0,
        /// Clear the clock absence flag
        CLRCKABF: u8,
        /// Clear the short-circuit detector flag
        CLRSCDF: u8,
    }),
    /// injected channel group selection register
    /// offset: 0x290
    DFSDM_FLT3JCHGR: mmio.Mmio(packed struct(u32) {
        /// Injected channel group selection
        JCHG: u8,
        padding: u24 = 0,
    }),
    /// filter control register
    /// offset: 0x294
    DFSDM_FLT3FCR: mmio.Mmio(packed struct(u32) {
        /// Integrator oversampling ratio (averaging length)
        IOSR: u8,
        reserved16: u8 = 0,
        /// Sinc filter oversampling ratio (decimation rate)
        FOSR: u10,
        reserved29: u3 = 0,
        /// Sinc filter order
        FORD: u3,
    }),
    /// data register for injected group
    /// offset: 0x298
    DFSDM_FLT3JDATAR: mmio.Mmio(packed struct(u32) {
        /// Injected channel most recently converted
        JDATACH: u3,
        reserved8: u5 = 0,
        /// Injected group conversion data
        JDATA: u24,
    }),
    /// data register for the regular channel
    /// offset: 0x29c
    DFSDM_FLT3RDATAR: mmio.Mmio(packed struct(u32) {
        /// Regular channel most recently converted
        RDATACH: u3,
        reserved4: u1 = 0,
        /// Regular channel pending data
        RPEND: u1,
        reserved8: u3 = 0,
        /// Regular channel conversion data
        RDATA: u24,
    }),
    /// analog watchdog high threshold register
    /// offset: 0x2a0
    DFSDM_FLT3AWHTR: mmio.Mmio(packed struct(u32) {
        /// Break signal assignment to analog watchdog high threshold event
        BKAWH: u4,
        reserved8: u4 = 0,
        /// Analog watchdog high threshold
        AWHT: u24,
    }),
    /// analog watchdog low threshold register
    /// offset: 0x2a4
    DFSDM_FLT3AWLTR: mmio.Mmio(packed struct(u32) {
        /// Break signal assignment to analog watchdog low threshold event
        BKAWL: u4,
        reserved8: u4 = 0,
        /// Analog watchdog low threshold
        AWLT: u24,
    }),
    /// analog watchdog status register
    /// offset: 0x2a8
    DFSDM_FLT3AWSR: mmio.Mmio(packed struct(u32) {
        /// Analog watchdog low threshold flag
        AWLTF: u8,
        /// Analog watchdog high threshold flag
        AWHTF: u8,
        padding: u16 = 0,
    }),
    /// analog watchdog clear flag register
    /// offset: 0x2ac
    DFSDM_FLT3AWCFR: mmio.Mmio(packed struct(u32) {
        /// Clear the analog watchdog low threshold flag
        CLRAWLTF: u8,
        /// Clear the analog watchdog high threshold flag
        CLRAWHTF: u8,
        padding: u16 = 0,
    }),
    /// Extremes detector maximum register
    /// offset: 0x2b0
    DFSDM_FLT3EXMAX: mmio.Mmio(packed struct(u32) {
        /// Extremes detector maximum data channel
        EXMAXCH: u3,
        reserved8: u5 = 0,
        /// Extremes detector maximum value
        EXMAX: u24,
    }),
    /// Extremes detector minimum register
    /// offset: 0x2b4
    DFSDM_FLT3EXMIN: mmio.Mmio(packed struct(u32) {
        /// Extremes detector minimum data channel
        EXMINCH: u3,
        reserved8: u5 = 0,
        /// EXMIN
        EXMIN: u24,
    }),
    /// conversion timer register
    /// offset: 0x2b8
    DFSDM_FLT3CNVTIMR: mmio.Mmio(packed struct(u32) {
        reserved4: u4 = 0,
        /// 28-bit timer counting conversion time t = CNVCNT[27:0] / fDFSDM_CKIN
        CNVCNT: u28,
    }),
};
