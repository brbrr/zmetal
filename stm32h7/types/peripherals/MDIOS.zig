const mmio = @import("mmio");
const types = @import("../../types.zig");

/// Management data input/output slave
pub const MDIOS = extern struct {
    /// MDIOS configuration register
    /// offset: 0x00
    MDIOS_CR: mmio.Mmio(packed struct(u32) {
        /// Peripheral enable
        EN: u1,
        /// Register write interrupt enable
        WRIE: u1,
        /// Register Read Interrupt Enable
        RDIE: u1,
        /// Error interrupt enable
        EIE: u1,
        reserved7: u3 = 0,
        /// Disable Preamble Check
        DPC: u1,
        /// Slaves's address
        PORT_ADDRESS: u5,
        padding: u19 = 0,
    }),
    /// MDIOS write flag register
    /// offset: 0x04
    MDIOS_WRFR: mmio.Mmio(packed struct(u32) {
        /// Write flags for MDIO registers 0 to 31
        WRF: u32,
    }),
    /// MDIOS clear write flag register
    /// offset: 0x08
    MDIOS_CWRFR: mmio.Mmio(packed struct(u32) {
        /// Clear the write flag
        CWRF: u32,
    }),
    /// MDIOS read flag register
    /// offset: 0x0c
    MDIOS_RDFR: mmio.Mmio(packed struct(u32) {
        /// Read flags for MDIO registers 0 to 31
        RDF: u32,
    }),
    /// MDIOS clear read flag register
    /// offset: 0x10
    MDIOS_CRDFR: mmio.Mmio(packed struct(u32) {
        /// Clear the read flag
        CRDF: u32,
    }),
    /// MDIOS status register
    /// offset: 0x14
    MDIOS_SR: mmio.Mmio(packed struct(u32) {
        /// Preamble error flag
        PERF: u1,
        /// Start error flag
        SERF: u1,
        /// Turnaround error flag
        TERF: u1,
        padding: u29 = 0,
    }),
    /// MDIOS clear flag register
    /// offset: 0x18
    MDIOS_CLRFR: mmio.Mmio(packed struct(u32) {
        /// Clear the preamble error flag
        CPERF: u1,
        /// Clear the start error flag
        CSERF: u1,
        /// Clear the turnaround error flag
        CTERF: u1,
        padding: u29 = 0,
    }),
    /// MDIOS input data register 0
    /// offset: 0x1c
    MDIOS_DINR0: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN0: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 1
    /// offset: 0x20
    MDIOS_DINR1: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN1: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 2
    /// offset: 0x24
    MDIOS_DINR2: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN2: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 3
    /// offset: 0x28
    MDIOS_DINR3: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN3: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 4
    /// offset: 0x2c
    MDIOS_DINR4: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN4: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 5
    /// offset: 0x30
    MDIOS_DINR5: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN5: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 6
    /// offset: 0x34
    MDIOS_DINR6: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN6: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 7
    /// offset: 0x38
    MDIOS_DINR7: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN7: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 8
    /// offset: 0x3c
    MDIOS_DINR8: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN8: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 9
    /// offset: 0x40
    MDIOS_DINR9: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN9: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 10
    /// offset: 0x44
    MDIOS_DINR10: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN10: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 11
    /// offset: 0x48
    MDIOS_DINR11: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN11: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 12
    /// offset: 0x4c
    MDIOS_DINR12: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN12: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 13
    /// offset: 0x50
    MDIOS_DINR13: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN13: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 14
    /// offset: 0x54
    MDIOS_DINR14: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN14: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 15
    /// offset: 0x58
    MDIOS_DINR15: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN15: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 16
    /// offset: 0x5c
    MDIOS_DINR16: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN16: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 17
    /// offset: 0x60
    MDIOS_DINR17: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN17: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 18
    /// offset: 0x64
    MDIOS_DINR18: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN18: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 19
    /// offset: 0x68
    MDIOS_DINR19: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN19: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 20
    /// offset: 0x6c
    MDIOS_DINR20: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN20: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 21
    /// offset: 0x70
    MDIOS_DINR21: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN21: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 22
    /// offset: 0x74
    MDIOS_DINR22: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN22: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 23
    /// offset: 0x78
    MDIOS_DINR23: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN23: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 24
    /// offset: 0x7c
    MDIOS_DINR24: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN24: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 25
    /// offset: 0x80
    MDIOS_DINR25: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN25: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 26
    /// offset: 0x84
    MDIOS_DINR26: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN26: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 27
    /// offset: 0x88
    MDIOS_DINR27: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN27: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 28
    /// offset: 0x8c
    MDIOS_DINR28: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN28: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 29
    /// offset: 0x90
    MDIOS_DINR29: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN29: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 30
    /// offset: 0x94
    MDIOS_DINR30: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN30: u16,
        padding: u16 = 0,
    }),
    /// MDIOS input data register 31
    /// offset: 0x98
    MDIOS_DINR31: mmio.Mmio(packed struct(u32) {
        /// Input data received from MDIO Master during write frames
        DIN31: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 0
    /// offset: 0x9c
    MDIOS_DOUTR0: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT0: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 1
    /// offset: 0xa0
    MDIOS_DOUTR1: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT1: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 2
    /// offset: 0xa4
    MDIOS_DOUTR2: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT2: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 3
    /// offset: 0xa8
    MDIOS_DOUTR3: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT3: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 4
    /// offset: 0xac
    MDIOS_DOUTR4: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT4: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 5
    /// offset: 0xb0
    MDIOS_DOUTR5: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT5: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 6
    /// offset: 0xb4
    MDIOS_DOUTR6: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT6: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 7
    /// offset: 0xb8
    MDIOS_DOUTR7: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT7: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 8
    /// offset: 0xbc
    MDIOS_DOUTR8: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT8: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 9
    /// offset: 0xc0
    MDIOS_DOUTR9: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT9: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 10
    /// offset: 0xc4
    MDIOS_DOUTR10: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT10: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 11
    /// offset: 0xc8
    MDIOS_DOUTR11: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT11: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 12
    /// offset: 0xcc
    MDIOS_DOUTR12: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT12: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 13
    /// offset: 0xd0
    MDIOS_DOUTR13: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT13: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 14
    /// offset: 0xd4
    MDIOS_DOUTR14: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT14: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 15
    /// offset: 0xd8
    MDIOS_DOUTR15: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT15: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 16
    /// offset: 0xdc
    MDIOS_DOUTR16: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT16: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 17
    /// offset: 0xe0
    MDIOS_DOUTR17: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT17: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 18
    /// offset: 0xe4
    MDIOS_DOUTR18: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT18: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 19
    /// offset: 0xe8
    MDIOS_DOUTR19: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT19: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 20
    /// offset: 0xec
    MDIOS_DOUTR20: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT20: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 21
    /// offset: 0xf0
    MDIOS_DOUTR21: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT21: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 22
    /// offset: 0xf4
    MDIOS_DOUTR22: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT22: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 23
    /// offset: 0xf8
    MDIOS_DOUTR23: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT23: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 24
    /// offset: 0xfc
    MDIOS_DOUTR24: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT24: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 25
    /// offset: 0x100
    MDIOS_DOUTR25: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT25: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 26
    /// offset: 0x104
    MDIOS_DOUTR26: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT26: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 27
    /// offset: 0x108
    MDIOS_DOUTR27: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT27: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 28
    /// offset: 0x10c
    MDIOS_DOUTR28: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT28: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 29
    /// offset: 0x110
    MDIOS_DOUTR29: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT29: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 30
    /// offset: 0x114
    MDIOS_DOUTR30: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT30: u16,
        padding: u16 = 0,
    }),
    /// MDIOS output data register 31
    /// offset: 0x118
    MDIOS_DOUTR31: mmio.Mmio(packed struct(u32) {
        /// Output data sent to MDIO Master during read frames
        DOUT31: u16,
        padding: u16 = 0,
    }),
};
