const mmio = @import("mmio");
const types = @import("../../types.zig");

/// Advanced-timers
pub const TIM1 = extern struct {
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
        /// Direction
        DIR: u1,
        /// Center-aligned mode selection
        CMS: u2,
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
        /// Output Idle state 2
        OIS2N: u1,
        /// Output Idle state 3
        OIS3: u1,
        /// Output Idle state 3
        OIS3N: u1,
        /// Output Idle state 4
        OIS4: u1,
        reserved16: u1 = 0,
        /// Output Idle state 5
        OIS5: u1,
        reserved18: u1 = 0,
        /// Output Idle state 6
        OIS6: u1,
        reserved20: u1 = 0,
        /// Master mode selection 2
        MMS2: u4,
        padding: u8 = 0,
    }),
    /// slave mode control register
    /// offset: 0x08
    SMCR: mmio.Mmio(packed struct(u32) {
        /// Slave mode selection
        SMS: u3,
        reserved4: u1 = 0,
        /// Trigger selection
        TS: u3,
        /// Master/Slave mode
        MSM: u1,
        /// External trigger filter
        ETF: u4,
        /// External trigger prescaler
        ETPS: u2,
        /// External clock enable
        ECE: u1,
        /// External trigger polarity
        ETP: u1,
        /// Slave mode selection - bit 3
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
        /// Capture/Compare 3 interrupt enable
        CC3IE: u1,
        /// Capture/Compare 4 interrupt enable
        CC4IE: u1,
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
        /// Capture/Compare 3 DMA request enable
        CC3DE: u1,
        /// Capture/Compare 4 DMA request enable
        CC4DE: u1,
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
        /// Capture/Compare 3 interrupt flag
        CC3IF: u1,
        /// Capture/Compare 4 interrupt flag
        CC4IF: u1,
        /// COM interrupt flag
        COMIF: u1,
        /// Trigger interrupt flag
        TIF: u1,
        /// Break interrupt flag
        BIF: u1,
        /// Break 2 interrupt flag
        B2IF: u1,
        /// Capture/Compare 1 overcapture flag
        CC1OF: u1,
        /// Capture/compare 2 overcapture flag
        CC2OF: u1,
        /// Capture/Compare 3 overcapture flag
        CC3OF: u1,
        /// Capture/Compare 4 overcapture flag
        CC4OF: u1,
        /// System Break interrupt flag
        SBIF: u1,
        reserved16: u2 = 0,
        /// Compare 5 interrupt flag
        CC5IF: u1,
        /// Compare 6 interrupt flag
        CC6IF: u1,
        padding: u14 = 0,
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
        /// Capture/compare 3 generation
        CC3G: u1,
        /// Capture/compare 4 generation
        CC4G: u1,
        /// Capture/Compare control update generation
        COMG: u1,
        /// Trigger generation
        TG: u1,
        /// Break generation
        BG: u1,
        /// Break 2 generation
        B2G: u1,
        padding: u23 = 0,
    }),
    /// capture/compare mode register 1 (output mode)
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
        /// Output Compare 1 clear enable
        OC1CE: u1,
        /// Capture/Compare 2 selection
        CC2S: u2,
        /// Output Compare 2 fast enable
        OC2FE: u1,
        /// Output Compare 2 preload enable
        OC2PE: u1,
        /// Output Compare 2 mode
        OC2M: u3,
        /// Output Compare 2 clear enable
        OC2CE: u1,
        /// Output Compare 1 mode - bit 3
        OC1M_3: u1,
        reserved24: u7 = 0,
        /// Output Compare 2 mode - bit 3
        OC2M_3: u1,
        padding: u7 = 0,
    }),
    /// capture/compare mode register 2 (output mode)
    /// offset: 0x1c
    CCMR2_Output: mmio.Mmio(packed struct(u32) {
        /// Capture/Compare 3 selection
        CC3S: u2,
        /// Output compare 3 fast enable
        OC3FE: u1,
        /// Output compare 3 preload enable
        OC3PE: u1,
        /// Output compare 3 mode
        OC3M: u3,
        /// Output compare 3 clear enable
        OC3CE: u1,
        /// Capture/Compare 4 selection
        CC4S: u2,
        /// Output compare 4 fast enable
        OC4FE: u1,
        /// Output compare 4 preload enable
        OC4PE: u1,
        /// Output compare 4 mode
        OC4M: u3,
        /// Output compare 4 clear enable
        OC4CE: u1,
        /// Output Compare 3 mode - bit 3
        OC3M_3: u1,
        reserved24: u7 = 0,
        /// Output Compare 4 mode - bit 3
        OC4M_4: u1,
        padding: u7 = 0,
    }),
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
        /// Capture/Compare 2 complementary output enable
        CC2NE: u1,
        /// Capture/Compare 2 output Polarity
        CC2NP: u1,
        /// Capture/Compare 3 output enable
        CC3E: u1,
        /// Capture/Compare 3 output Polarity
        CC3P: u1,
        /// Capture/Compare 3 complementary output enable
        CC3NE: u1,
        /// Capture/Compare 3 output Polarity
        CC3NP: u1,
        /// Capture/Compare 4 output enable
        CC4E: u1,
        /// Capture/Compare 3 output Polarity
        CC4P: u1,
        reserved15: u1 = 0,
        /// Capture/Compare 4 complementary output polarity
        CC4NP: u1,
        /// Capture/Compare 5 output enable
        CC5E: u1,
        /// Capture/Compare 5 output polarity
        CC5P: u1,
        reserved20: u2 = 0,
        /// Capture/Compare 6 output enable
        CC6E: u1,
        /// Capture/Compare 6 output polarity
        CC6P: u1,
        padding: u10 = 0,
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
    /// capture/compare register 3
    /// offset: 0x3c
    CCR3: mmio.Mmio(packed struct(u32) {
        /// Capture/Compare value
        CCR3: u16,
        padding: u16 = 0,
    }),
    /// capture/compare register 4
    /// offset: 0x40
    CCR4: mmio.Mmio(packed struct(u32) {
        /// Capture/Compare value
        CCR4: u16,
        padding: u16 = 0,
    }),
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
        /// Break 2 filter
        BK2F: u4,
        /// Break 2 enable
        BK2E: u1,
        /// Break 2 polarity
        BK2P: u1,
        padding: u6 = 0,
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
    reserved80: [4]u8,
    /// capture/compare mode register 3 (output mode)
    /// offset: 0x54
    CCMR3_Output: mmio.Mmio(packed struct(u32) {
        reserved2: u2 = 0,
        /// Output compare 5 fast enable
        OC5FE: u1,
        /// Output compare 5 preload enable
        OC5PE: u1,
        /// Output compare 5 mode
        OC5M: u3,
        /// Output compare 5 clear enable
        OC5CE: u1,
        reserved10: u2 = 0,
        /// Output compare 6 fast enable
        OC6FE: u1,
        /// Output compare 6 preload enable
        OC6PE: u1,
        /// Output compare 6 mode
        OC6M: u3,
        /// Output compare 6 clear enable
        OC6CE: u1,
        /// Output Compare 5 mode
        OC5M3: u1,
        reserved24: u7 = 0,
        /// Output Compare 6 mode
        OC6M3: u1,
        padding: u7 = 0,
    }),
    /// capture/compare register 5
    /// offset: 0x58
    CCR5: mmio.Mmio(packed struct(u32) {
        /// Capture/Compare 5 value
        CCR5: u16,
        reserved29: u13 = 0,
        /// Group Channel 5 and Channel 1
        GC5C1: u1,
        /// Group Channel 5 and Channel 2
        GC5C2: u1,
        /// Group Channel 5 and Channel 3
        GC5C3: u1,
    }),
    /// capture/compare register 6
    /// offset: 0x5c
    CRR6: mmio.Mmio(packed struct(u32) {
        /// Capture/Compare 6 value
        CCR6: u16,
        padding: u16 = 0,
    }),
    /// TIM1 alternate function option register 1
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
        reserved14: u2 = 0,
        /// ETR source selection
        ETRSEL: u4,
        padding: u14 = 0,
    }),
    /// TIM1 Alternate function odfsdm1_breakster 2
    /// offset: 0x64
    AF2: mmio.Mmio(packed struct(u32) {
        /// BRK2 BKIN input enable
        BK2INE: u1,
        /// BRK2 COMP1 enable
        BK2CMP1E: u1,
        /// BRK2 COMP2 enable
        BK2CMP2E: u1,
        reserved8: u5 = 0,
        /// BRK2 dfsdm1_break[1] enable
        BK2DF1BK1E: u1,
        /// BRK2 BKIN2 input polarity
        BK2INP: u1,
        /// BRK2 COMP1 input polarit
        BK2CMP1P: u1,
        /// BRK2 COMP2 input polarity
        BK2CMP2P: u1,
        padding: u20 = 0,
    }),
    /// TIM1 timer input selection register
    /// offset: 0x68
    TISEL: mmio.Mmio(packed struct(u32) {
        /// selects TI1[0] to TI1[15] input
        TI1SEL: u4,
        reserved8: u4 = 0,
        /// selects TI2[0] to TI2[15] input
        TI2SEL: u4,
        reserved16: u4 = 0,
        /// selects TI3[0] to TI3[15] input
        TI3SEL: u4,
        reserved24: u4 = 0,
        /// selects TI4[0] to TI4[15] input
        TI4SEL: u4,
        padding: u4 = 0,
    }),
};
