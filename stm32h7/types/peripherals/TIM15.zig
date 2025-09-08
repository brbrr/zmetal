const mmio = @import("mmio");
const types = @import("../../types.zig");

/// General purpose timers
pub const TIM15 = extern struct {
    /// control register 1
    /// offset: 0x00
    CR1: mmio.Mmio(packed struct(u32) {
        /// Counter enable
        CEN: u1,
        /// Update disable
        UDIS: u1,
        /// Update request source
        URS: u1,
        /// One-pulse mode
        OPM: u1,
        reserved7: u3 = 0,
        /// Auto-reload preload enable
        ARPE: u1,
        /// Clock division
        CKD: u2,
        reserved11: u1 = 0,
        /// UIF status bit remapping
        UIFREMAP: u1,
        padding: u20 = 0,
    }),
    /// control register 2
    /// offset: 0x04
    CR2: mmio.Mmio(packed struct(u32) {
        /// Capture/compare preloaded control
        CCPC: u1,
        reserved2: u1 = 0,
        /// Capture/compare control update selection
        CCUS: u1,
        /// Capture/compare DMA selection
        CCDS: u1,
        /// Master mode selection
        MMS: u3,
        /// TI1 selection
        TI1S: u1,
        /// Output Idle state 1
        OIS1: u1,
        /// Output Idle state 1
        OIS1N: u1,
        /// Output Idle state 2
        OIS2: u1,
        padding: u21 = 0,
    }),
    /// slave mode control register
    /// offset: 0x08
    SMCR: mmio.Mmio(packed struct(u32) {
        /// Slave mode selection
        SMS: u3,
        reserved4: u1 = 0,
        /// Trigger selection
        TS_2_0: u3,
        /// Master/Slave mode
        MSM: u1,
        reserved16: u8 = 0,
        /// Slave mode selection bit 3
        SMS_3: u1,
        reserved20: u3 = 0,
        /// Trigger selection - bit 4:3
        TS_4_3: u2,
        padding: u10 = 0,
    }),
    /// DMA/Interrupt enable register
    /// offset: 0x0c
    DIER: mmio.Mmio(packed struct(u32) {
        /// Update interrupt enable
        UIE: u1,
        /// Capture/Compare 1 interrupt enable
        CC1IE: u1,
        /// Capture/Compare 2 interrupt enable
        CC2IE: u1,
        reserved5: u2 = 0,
        /// COM interrupt enable
        COMIE: u1,
        /// Trigger interrupt enable
        TIE: u1,
        /// Break interrupt enable
        BIE: u1,
        /// Update DMA request enable
        UDE: u1,
        /// Capture/Compare 1 DMA request enable
        CC1DE: u1,
        /// Capture/Compare 2 DMA request enable
        CC2DE: u1,
        reserved13: u2 = 0,
        /// COM DMA request enable
        COMDE: u1,
        /// Trigger DMA request enable
        TDE: u1,
        padding: u17 = 0,
    }),
    /// status register
    /// offset: 0x10
    SR: mmio.Mmio(packed struct(u32) {
        /// Update interrupt flag
        UIF: u1,
        /// Capture/compare 1 interrupt flag
        CC1IF: u1,
        /// Capture/Compare 2 interrupt flag
        CC2IF: u1,
        reserved5: u2 = 0,
        /// COM interrupt flag
        COMIF: u1,
        /// Trigger interrupt flag
        TIF: u1,
        /// Break interrupt flag
        BIF: u1,
        reserved9: u1 = 0,
        /// Capture/Compare 1 overcapture flag
        CC1OF: u1,
        /// Capture/compare 2 overcapture flag
        CC2OF: u1,
        padding: u21 = 0,
    }),
    /// event generation register
    /// offset: 0x14
    EGR: mmio.Mmio(packed struct(u32) {
        /// Update generation
        UG: u1,
        /// Capture/compare 1 generation
        CC1G: u1,
        /// Capture/compare 2 generation
        CC2G: u1,
        reserved5: u2 = 0,
        /// Capture/Compare control update generation
        COMG: u1,
        /// Trigger generation
        TG: u1,
        /// Break generation
        BG: u1,
        padding: u24 = 0,
    }),
    /// capture/compare mode register (output mode)
    /// offset: 0x18
    CCMR1_Output: mmio.Mmio(packed struct(u32) {
        /// Capture/Compare 1 selection
        CC1S: u2,
        /// Output Compare 1 fast enable
        OC1FE: u1,
        /// Output Compare 1 preload enable
        OC1PE: u1,
        /// Output Compare 1 mode
        OC1M: u3,
        reserved8: u1 = 0,
        /// Capture/Compare 2 selection
        CC2S: u2,
        /// Output Compare 2 fast enable
        OC2FE: u1,
        /// Output Compare 2 preload enable
        OC2PE: u1,
        /// Output Compare 2 mode
        OC2M: u3,
        reserved16: u1 = 0,
        /// Output Compare 1 mode bit 3
        OC1M_3: u1,
        reserved24: u7 = 0,
        /// Output Compare 2 mode bit 3
        OC2M_3: u1,
        padding: u7 = 0,
    }),
    /// offset: 0x1c
    reserved28: [4]u8,
    /// capture/compare enable register
    /// offset: 0x20
    CCER: mmio.Mmio(packed struct(u32) {
        /// Capture/Compare 1 output enable
        CC1E: u1,
        /// Capture/Compare 1 output Polarity
        CC1P: u1,
        /// Capture/Compare 1 complementary output enable
        CC1NE: u1,
        /// Capture/Compare 1 output Polarity
        CC1NP: u1,
        /// Capture/Compare 2 output enable
        CC2E: u1,
        /// Capture/Compare 2 output Polarity
        CC2P: u1,
        reserved7: u1 = 0,
        /// Capture/Compare 2 output Polarity
        CC2NP: u1,
        padding: u24 = 0,
    }),
    /// counter
    /// offset: 0x24
    CNT: mmio.Mmio(packed struct(u32) {
        /// counter value
        CNT: u16,
        reserved31: u15 = 0,
        /// UIF copy
        UIFCPY: u1,
    }),
    /// prescaler
    /// offset: 0x28
    PSC: mmio.Mmio(packed struct(u32) {
        /// Prescaler value
        PSC: u16,
        padding: u16 = 0,
    }),
    /// auto-reload register
    /// offset: 0x2c
    ARR: mmio.Mmio(packed struct(u32) {
        /// Auto-reload value
        ARR: u16,
        padding: u16 = 0,
    }),
    /// repetition counter register
    /// offset: 0x30
    RCR: mmio.Mmio(packed struct(u32) {
        /// Repetition counter value
        REP: u8,
        padding: u24 = 0,
    }),
    /// capture/compare register 1
    /// offset: 0x34
    CCR1: mmio.Mmio(packed struct(u32) {
        /// Capture/Compare 1 value
        CCR1: u16,
        padding: u16 = 0,
    }),
    /// capture/compare register 2
    /// offset: 0x38
    CCR2: mmio.Mmio(packed struct(u32) {
        /// Capture/Compare 2 value
        CCR2: u16,
        padding: u16 = 0,
    }),
    /// offset: 0x3c
    reserved60: [8]u8,
    /// break and dead-time register
    /// offset: 0x44
    BDTR: mmio.Mmio(packed struct(u32) {
        /// Dead-time generator setup
        DTG: u8,
        /// Lock configuration
        LOCK: u2,
        /// Off-state selection for Idle mode
        OSSI: u1,
        /// Off-state selection for Run mode
        OSSR: u1,
        /// Break enable
        BKE: u1,
        /// Break polarity
        BKP: u1,
        /// Automatic output enable
        AOE: u1,
        /// Main output enable
        MOE: u1,
        /// Break filter
        BKF: u4,
        padding: u12 = 0,
    }),
    /// DMA control register
    /// offset: 0x48
    DCR: mmio.Mmio(packed struct(u32) {
        /// DMA base address
        DBA: u5,
        reserved8: u3 = 0,
        /// DMA burst length
        DBL: u5,
        padding: u19 = 0,
    }),
    /// DMA address for full transfer
    /// offset: 0x4c
    DMAR: mmio.Mmio(packed struct(u32) {
        /// DMA register for burst accesses
        DMAB: u16,
        padding: u16 = 0,
    }),
    /// offset: 0x50
    reserved80: [16]u8,
    /// TIM15 alternate fdfsdm1_breakon register 1
    /// offset: 0x60
    AF1: mmio.Mmio(packed struct(u32) {
        /// BRK BKIN input enable
        BKINE: u1,
        /// BRK COMP1 enable
        BKCMP1E: u1,
        /// BRK COMP2 enable
        BKCMP2E: u1,
        reserved8: u5 = 0,
        /// BRK dfsdm1_break[0] enable
        BKDF1BK0E: u1,
        /// BRK BKIN input polarity
        BKINP: u1,
        /// BRK COMP1 input polarity
        BKCMP1P: u1,
        /// BRK COMP2 input polarity
        BKCMP2P: u1,
        padding: u20 = 0,
    }),
    /// offset: 0x64
    reserved100: [4]u8,
    /// TIM15 input selection register
    /// offset: 0x68
    TISEL: mmio.Mmio(packed struct(u32) {
        /// selects TI1[0] to TI1[15] input
        TI1SEL: u4,
        reserved8: u4 = 0,
        /// selects TI2[0] to TI2[15] input
        TI2SEL: u4,
        padding: u20 = 0,
    }),
};
