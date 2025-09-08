const mmio = @import("mmio");
const types = @import("../../types.zig");

/// High Resolution Timer: TIMC
pub const HRTIM_TIMC = extern struct {
    /// Timerx Control Register
    /// offset: 0x00
    TIMCCR: mmio.Mmio(packed struct(u32) {
        /// HRTIM Timer x Clock prescaler
        CK_PSCx: u3,
        /// Continuous mode
        CONT: u1,
        /// Re-triggerable mode
        RETRIG: u1,
        /// Half mode enable
        HALF: u1,
        /// Push-Pull mode enable
        PSHPLL: u1,
        reserved10: u3 = 0,
        /// Synchronization Resets Timer x
        SYNCRSTx: u1,
        /// Synchronization Starts Timer x
        SYNCSTRTx: u1,
        /// Delayed CMP2 mode
        DELCMP2: u2,
        /// Delayed CMP4 mode
        DELCMP4: u2,
        reserved17: u1 = 0,
        /// Timer x Repetition update
        TxREPU: u1,
        /// Timerx reset update
        TxRSTU: u1,
        reserved20: u1 = 0,
        /// TBU
        TBU: u1,
        /// TCU
        TCU: u1,
        /// TDU
        TDU: u1,
        /// TEU
        TEU: u1,
        /// Master Timer update
        MSTU: u1,
        /// AC Synchronization
        DACSYNC: u2,
        /// Preload enable
        PREEN: u1,
        /// Update Gating
        UPDGAT: u4,
    }),
    /// Timerx Interrupt Status Register
    /// offset: 0x04
    TIMCISR: mmio.Mmio(packed struct(u32) {
        /// Compare 1 Interrupt Flag
        CMP1: u1,
        /// Compare 2 Interrupt Flag
        CMP2: u1,
        /// Compare 3 Interrupt Flag
        CMP3: u1,
        /// Compare 4 Interrupt Flag
        CMP4: u1,
        /// Repetition Interrupt Flag
        REP: u1,
        reserved6: u1 = 0,
        /// Update Interrupt Flag
        UPD: u1,
        /// Capture1 Interrupt Flag
        CPT1: u1,
        /// Capture2 Interrupt Flag
        CPT2: u1,
        /// Output 1 Set Interrupt Flag
        SETx1: u1,
        /// Output 1 Reset Interrupt Flag
        RSTx1: u1,
        /// Output 2 Set Interrupt Flag
        SETx2: u1,
        /// Output 2 Reset Interrupt Flag
        RSTx2: u1,
        /// Reset Interrupt Flag
        RST: u1,
        /// Delayed Protection Flag
        DLYPRT: u1,
        reserved16: u1 = 0,
        /// Current Push Pull Status
        CPPSTAT: u1,
        /// Idle Push Pull Status
        IPPSTAT: u1,
        /// Output 1 State
        O1STAT: u1,
        /// Output 2 State
        O2STAT: u1,
        padding: u12 = 0,
    }),
    /// Timerx Interrupt Clear Register
    /// offset: 0x08
    TIMCICR: mmio.Mmio(packed struct(u32) {
        /// Compare 1 Interrupt flag Clear
        CMP1C: u1,
        /// Compare 2 Interrupt flag Clear
        CMP2C: u1,
        /// Compare 3 Interrupt flag Clear
        CMP3C: u1,
        /// Compare 4 Interrupt flag Clear
        CMP4C: u1,
        /// Repetition Interrupt flag Clear
        REPC: u1,
        reserved6: u1 = 0,
        /// Update Interrupt flag Clear
        UPDC: u1,
        /// Capture1 Interrupt flag Clear
        CPT1C: u1,
        /// Capture2 Interrupt flag Clear
        CPT2C: u1,
        /// Output 1 Set flag Clear
        SET1xC: u1,
        /// Output 1 Reset flag Clear
        RSTx1C: u1,
        /// Output 2 Set flag Clear
        SET2xC: u1,
        /// Output 2 Reset flag Clear
        RSTx2C: u1,
        /// Reset Interrupt flag Clear
        RSTC: u1,
        /// Delayed Protection Flag Clear
        DLYPRTC: u1,
        padding: u17 = 0,
    }),
    /// TIMxDIER5
    /// offset: 0x0c
    TIMCDIER5: mmio.Mmio(packed struct(u32) {
        /// CMP1IE
        CMP1IE: u1,
        /// CMP2IE
        CMP2IE: u1,
        /// CMP3IE
        CMP3IE: u1,
        /// CMP4IE
        CMP4IE: u1,
        /// REPIE
        REPIE: u1,
        reserved6: u1 = 0,
        /// UPDIE
        UPDIE: u1,
        /// CPT1IE
        CPT1IE: u1,
        /// CPT2IE
        CPT2IE: u1,
        /// SET1xIE
        SET1xIE: u1,
        /// RSTx1IE
        RSTx1IE: u1,
        /// SETx2IE
        SETx2IE: u1,
        /// RSTx2IE
        RSTx2IE: u1,
        /// RSTIE
        RSTIE: u1,
        /// DLYPRTIE
        DLYPRTIE: u1,
        reserved16: u1 = 0,
        /// CMP1DE
        CMP1DE: u1,
        /// CMP2DE
        CMP2DE: u1,
        /// CMP3DE
        CMP3DE: u1,
        /// CMP4DE
        CMP4DE: u1,
        /// REPDE
        REPDE: u1,
        reserved22: u1 = 0,
        /// UPDDE
        UPDDE: u1,
        /// CPT1DE
        CPT1DE: u1,
        /// CPT2DE
        CPT2DE: u1,
        /// SET1xDE
        SET1xDE: u1,
        /// RSTx1DE
        RSTx1DE: u1,
        /// SETx2DE
        SETx2DE: u1,
        /// RSTx2DE
        RSTx2DE: u1,
        /// RSTDE
        RSTDE: u1,
        /// DLYPRTDE
        DLYPRTDE: u1,
        padding: u1 = 0,
    }),
    /// Timerx Counter Register
    /// offset: 0x10
    CNTCR: mmio.Mmio(packed struct(u32) {
        /// Timerx Counter value
        CNTx: u16,
        padding: u16 = 0,
    }),
    /// Timerx Period Register
    /// offset: 0x14
    PERCR: mmio.Mmio(packed struct(u32) {
        /// Timerx Period value
        PERx: u16,
        padding: u16 = 0,
    }),
    /// Timerx Repetition Register
    /// offset: 0x18
    REPCR: mmio.Mmio(packed struct(u32) {
        /// Timerx Repetition counter value
        REPx: u8,
        padding: u24 = 0,
    }),
    /// Timerx Compare 1 Register
    /// offset: 0x1c
    CMP1CR: mmio.Mmio(packed struct(u32) {
        /// Timerx Compare 1 value
        CMP1x: u16,
        padding: u16 = 0,
    }),
    /// Timerx Compare 1 Compound Register
    /// offset: 0x20
    CMP1CCR: mmio.Mmio(packed struct(u32) {
        /// Timerx Compare 1 value
        CMP1x: u16,
        /// Timerx Repetition value (aliased from HRTIM_REPx register)
        REPx: u8,
        padding: u8 = 0,
    }),
    /// Timerx Compare 2 Register
    /// offset: 0x24
    CMP2CR: mmio.Mmio(packed struct(u32) {
        /// Timerx Compare 2 value
        CMP2x: u16,
        padding: u16 = 0,
    }),
    /// Timerx Compare 3 Register
    /// offset: 0x28
    CMP3CR: mmio.Mmio(packed struct(u32) {
        /// Timerx Compare 3 value
        CMP3x: u16,
        padding: u16 = 0,
    }),
    /// Timerx Compare 4 Register
    /// offset: 0x2c
    CMP4CR: mmio.Mmio(packed struct(u32) {
        /// Timerx Compare 4 value
        CMP4x: u16,
        padding: u16 = 0,
    }),
    /// Timerx Capture 1 Register
    /// offset: 0x30
    CPT1CR: mmio.Mmio(packed struct(u32) {
        /// Timerx Capture 1 value
        CPT1x: u16,
        padding: u16 = 0,
    }),
    /// Timerx Capture 2 Register
    /// offset: 0x34
    CPT2CR: mmio.Mmio(packed struct(u32) {
        /// Timerx Capture 2 value
        CPT2x: u16,
        padding: u16 = 0,
    }),
    /// Timerx Deadtime Register
    /// offset: 0x38
    DTCR: mmio.Mmio(packed struct(u32) {
        /// Deadtime Rising value
        DTRx: u9,
        /// Sign Deadtime Rising value
        SDTRx: u1,
        /// Deadtime Prescaler
        DTPRSC: u3,
        reserved14: u1 = 0,
        /// Deadtime Rising Sign Lock
        DTRSLKx: u1,
        /// Deadtime Rising Lock
        DTRLKx: u1,
        /// Deadtime Falling value
        DTFx: u9,
        /// Sign Deadtime Falling value
        SDTFx: u1,
        reserved30: u4 = 0,
        /// Deadtime Falling Sign Lock
        DTFSLKx: u1,
        /// Deadtime Falling Lock
        DTFLKx: u1,
    }),
    /// Timerx Output1 Set Register
    /// offset: 0x3c
    SETC1R: mmio.Mmio(packed struct(u32) {
        /// Software Set trigger
        SST: u1,
        /// Timer A resynchronizaton
        RESYNC: u1,
        /// Timer A Period
        PER: u1,
        /// Timer A compare 1
        CMP1: u1,
        /// Timer A compare 2
        CMP2: u1,
        /// Timer A compare 3
        CMP3: u1,
        /// Timer A compare 4
        CMP4: u1,
        /// Master Period
        MSTPER: u1,
        /// Master Compare 1
        MSTCMP1: u1,
        /// Master Compare 2
        MSTCMP2: u1,
        /// Master Compare 3
        MSTCMP3: u1,
        /// Master Compare 4
        MSTCMP4: u1,
        /// Timer Event 1
        TIMEVNT1: u1,
        /// Timer Event 2
        TIMEVNT2: u1,
        /// Timer Event 3
        TIMEVNT3: u1,
        /// Timer Event 4
        TIMEVNT4: u1,
        /// Timer Event 5
        TIMEVNT5: u1,
        /// Timer Event 6
        TIMEVNT6: u1,
        /// Timer Event 7
        TIMEVNT7: u1,
        /// Timer Event 8
        TIMEVNT8: u1,
        /// Timer Event 9
        TIMEVNT9: u1,
        /// External Event 1
        EXTEVNT1: u1,
        /// External Event 2
        EXTEVNT2: u1,
        /// External Event 3
        EXTEVNT3: u1,
        /// External Event 4
        EXTEVNT4: u1,
        /// External Event 5
        EXTEVNT5: u1,
        /// External Event 6
        EXTEVNT6: u1,
        /// External Event 7
        EXTEVNT7: u1,
        /// External Event 8
        EXTEVNT8: u1,
        /// External Event 9
        EXTEVNT9: u1,
        /// External Event 10
        EXTEVNT10: u1,
        /// Registers update (transfer preload to active)
        UPDATE: u1,
    }),
    /// Timerx Output1 Reset Register
    /// offset: 0x40
    RSTC1R: mmio.Mmio(packed struct(u32) {
        /// SRT
        SRT: u1,
        /// RESYNC
        RESYNC: u1,
        /// PER
        PER: u1,
        /// CMP1
        CMP1: u1,
        /// CMP2
        CMP2: u1,
        /// CMP3
        CMP3: u1,
        /// CMP4
        CMP4: u1,
        /// MSTPER
        MSTPER: u1,
        /// MSTCMP1
        MSTCMP1: u1,
        /// MSTCMP2
        MSTCMP2: u1,
        /// MSTCMP3
        MSTCMP3: u1,
        /// MSTCMP4
        MSTCMP4: u1,
        /// TIMEVNT1
        TIMEVNT1: u1,
        /// TIMEVNT2
        TIMEVNT2: u1,
        /// TIMEVNT3
        TIMEVNT3: u1,
        /// TIMEVNT4
        TIMEVNT4: u1,
        /// TIMEVNT5
        TIMEVNT5: u1,
        /// TIMEVNT6
        TIMEVNT6: u1,
        /// TIMEVNT7
        TIMEVNT7: u1,
        /// TIMEVNT8
        TIMEVNT8: u1,
        /// TIMEVNT9
        TIMEVNT9: u1,
        /// EXTEVNT1
        EXTEVNT1: u1,
        /// EXTEVNT2
        EXTEVNT2: u1,
        /// EXTEVNT3
        EXTEVNT3: u1,
        /// EXTEVNT4
        EXTEVNT4: u1,
        /// EXTEVNT5
        EXTEVNT5: u1,
        /// EXTEVNT6
        EXTEVNT6: u1,
        /// EXTEVNT7
        EXTEVNT7: u1,
        /// EXTEVNT8
        EXTEVNT8: u1,
        /// EXTEVNT9
        EXTEVNT9: u1,
        /// EXTEVNT10
        EXTEVNT10: u1,
        /// UPDATE
        UPDATE: u1,
    }),
    /// Timerx Output2 Set Register
    /// offset: 0x44
    SETC2R: mmio.Mmio(packed struct(u32) {
        /// SST
        SST: u1,
        /// RESYNC
        RESYNC: u1,
        /// PER
        PER: u1,
        /// CMP1
        CMP1: u1,
        /// CMP2
        CMP2: u1,
        /// CMP3
        CMP3: u1,
        /// CMP4
        CMP4: u1,
        /// MSTPER
        MSTPER: u1,
        /// MSTCMP1
        MSTCMP1: u1,
        /// MSTCMP2
        MSTCMP2: u1,
        /// MSTCMP3
        MSTCMP3: u1,
        /// MSTCMP4
        MSTCMP4: u1,
        /// TIMEVNT1
        TIMEVNT1: u1,
        /// TIMEVNT2
        TIMEVNT2: u1,
        /// TIMEVNT3
        TIMEVNT3: u1,
        /// TIMEVNT4
        TIMEVNT4: u1,
        /// TIMEVNT5
        TIMEVNT5: u1,
        /// TIMEVNT6
        TIMEVNT6: u1,
        /// TIMEVNT7
        TIMEVNT7: u1,
        /// TIMEVNT8
        TIMEVNT8: u1,
        /// TIMEVNT9
        TIMEVNT9: u1,
        /// EXTEVNT1
        EXTEVNT1: u1,
        /// EXTEVNT2
        EXTEVNT2: u1,
        /// EXTEVNT3
        EXTEVNT3: u1,
        /// EXTEVNT4
        EXTEVNT4: u1,
        /// EXTEVNT5
        EXTEVNT5: u1,
        /// EXTEVNT6
        EXTEVNT6: u1,
        /// EXTEVNT7
        EXTEVNT7: u1,
        /// EXTEVNT8
        EXTEVNT8: u1,
        /// EXTEVNT9
        EXTEVNT9: u1,
        /// EXTEVNT10
        EXTEVNT10: u1,
        /// UPDATE
        UPDATE: u1,
    }),
    /// Timerx Output2 Reset Register
    /// offset: 0x48
    RSTC2R: mmio.Mmio(packed struct(u32) {
        /// SRT
        SRT: u1,
        /// RESYNC
        RESYNC: u1,
        /// PER
        PER: u1,
        /// CMP1
        CMP1: u1,
        /// CMP2
        CMP2: u1,
        /// CMP3
        CMP3: u1,
        /// CMP4
        CMP4: u1,
        /// MSTPER
        MSTPER: u1,
        /// MSTCMP1
        MSTCMP1: u1,
        /// MSTCMP2
        MSTCMP2: u1,
        /// MSTCMP3
        MSTCMP3: u1,
        /// MSTCMP4
        MSTCMP4: u1,
        /// TIMEVNT1
        TIMEVNT1: u1,
        /// TIMEVNT2
        TIMEVNT2: u1,
        /// TIMEVNT3
        TIMEVNT3: u1,
        /// TIMEVNT4
        TIMEVNT4: u1,
        /// TIMEVNT5
        TIMEVNT5: u1,
        /// TIMEVNT6
        TIMEVNT6: u1,
        /// TIMEVNT7
        TIMEVNT7: u1,
        /// TIMEVNT8
        TIMEVNT8: u1,
        /// TIMEVNT9
        TIMEVNT9: u1,
        /// EXTEVNT1
        EXTEVNT1: u1,
        /// EXTEVNT2
        EXTEVNT2: u1,
        /// EXTEVNT3
        EXTEVNT3: u1,
        /// EXTEVNT4
        EXTEVNT4: u1,
        /// EXTEVNT5
        EXTEVNT5: u1,
        /// EXTEVNT6
        EXTEVNT6: u1,
        /// EXTEVNT7
        EXTEVNT7: u1,
        /// EXTEVNT8
        EXTEVNT8: u1,
        /// EXTEVNT9
        EXTEVNT9: u1,
        /// EXTEVNT10
        EXTEVNT10: u1,
        /// UPDATE
        UPDATE: u1,
    }),
    /// Timerx External Event Filtering Register 1
    /// offset: 0x4c
    EEFCR1: mmio.Mmio(packed struct(u32) {
        /// External Event 1 latch
        EE1LTCH: u1,
        /// External Event 1 filter
        EE1FLTR: u4,
        reserved6: u1 = 0,
        /// External Event 2 latch
        EE2LTCH: u1,
        /// External Event 2 filter
        EE2FLTR: u4,
        reserved12: u1 = 0,
        /// External Event 3 latch
        EE3LTCH: u1,
        /// External Event 3 filter
        EE3FLTR: u4,
        reserved18: u1 = 0,
        /// External Event 4 latch
        EE4LTCH: u1,
        /// External Event 4 filter
        EE4FLTR: u4,
        reserved24: u1 = 0,
        /// External Event 5 latch
        EE5LTCH: u1,
        /// External Event 5 filter
        EE5FLTR: u4,
        padding: u3 = 0,
    }),
    /// Timerx External Event Filtering Register 2
    /// offset: 0x50
    EEFCR2: mmio.Mmio(packed struct(u32) {
        /// External Event 6 latch
        EE6LTCH: u1,
        /// External Event 6 filter
        EE6FLTR: u4,
        reserved6: u1 = 0,
        /// External Event 7 latch
        EE7LTCH: u1,
        /// External Event 7 filter
        EE7FLTR: u4,
        reserved12: u1 = 0,
        /// External Event 8 latch
        EE8LTCH: u1,
        /// External Event 8 filter
        EE8FLTR: u4,
        reserved18: u1 = 0,
        /// External Event 9 latch
        EE9LTCH: u1,
        /// External Event 9 filter
        EE9FLTR: u4,
        reserved24: u1 = 0,
        /// External Event 10 latch
        EE10LTCH: u1,
        /// External Event 10 filter
        EE10FLTR: u4,
        padding: u3 = 0,
    }),
    /// TimerA Reset Register
    /// offset: 0x54
    RSTCR: mmio.Mmio(packed struct(u32) {
        reserved1: u1 = 0,
        /// Timer A Update reset
        UPDT: u1,
        /// Timer A compare 2 reset
        CMP2: u1,
        /// Timer A compare 4 reset
        CMP4: u1,
        /// Master timer Period
        MSTPER: u1,
        /// Master compare 1
        MSTCMP1: u1,
        /// Master compare 2
        MSTCMP2: u1,
        /// Master compare 3
        MSTCMP3: u1,
        /// Master compare 4
        MSTCMP4: u1,
        /// External Event 1
        EXTEVNT1: u1,
        /// External Event 2
        EXTEVNT2: u1,
        /// External Event 3
        EXTEVNT3: u1,
        /// External Event 4
        EXTEVNT4: u1,
        /// External Event 5
        EXTEVNT5: u1,
        /// External Event 6
        EXTEVNT6: u1,
        /// External Event 7
        EXTEVNT7: u1,
        /// External Event 8
        EXTEVNT8: u1,
        /// External Event 9
        EXTEVNT9: u1,
        /// External Event 10
        EXTEVNT10: u1,
        /// Timer A Compare 1
        TIMACMP1: u1,
        /// Timer A Compare 2
        TIMACMP2: u1,
        /// Timer A Compare 4
        TIMACMP4: u1,
        /// Timer B Compare 1
        TIMBCMP1: u1,
        /// Timer B Compare 2
        TIMBCMP2: u1,
        /// Timer B Compare 4
        TIMBCMP4: u1,
        /// Timer D Compare 1
        TIMDCMP1: u1,
        /// Timer D Compare 2
        TIMDCMP2: u1,
        /// Timer D Compare 4
        TIMDCMP4: u1,
        /// Timer E Compare 1
        TIMECMP1: u1,
        /// Timer E Compare 2
        TIMECMP2: u1,
        /// Timer E Compare 4
        TIMECMP4: u1,
        padding: u1 = 0,
    }),
    /// Timerx Chopper Register
    /// offset: 0x58
    CHPCR: mmio.Mmio(packed struct(u32) {
        /// Timerx carrier frequency value
        CHPFRQ: u4,
        /// Timerx chopper duty cycle value
        CHPDTY: u3,
        /// STRTPW
        STRTPW: u4,
        padding: u21 = 0,
    }),
    /// Timerx Capture 2 Control Register
    /// offset: 0x5c
    CPT1CCR: mmio.Mmio(packed struct(u32) {
        /// Software Capture
        SWCPT: u1,
        /// Update Capture
        UDPCPT: u1,
        /// External Event 1 Capture
        EXEV1CPT: u1,
        /// External Event 2 Capture
        EXEV2CPT: u1,
        /// External Event 3 Capture
        EXEV3CPT: u1,
        /// External Event 4 Capture
        EXEV4CPT: u1,
        /// External Event 5 Capture
        EXEV5CPT: u1,
        /// External Event 6 Capture
        EXEV6CPT: u1,
        /// External Event 7 Capture
        EXEV7CPT: u1,
        /// External Event 8 Capture
        EXEV8CPT: u1,
        /// External Event 9 Capture
        EXEV9CPT: u1,
        /// External Event 10 Capture
        EXEV10CPT: u1,
        /// Timer A output 1 Set
        TA1SET: u1,
        /// Timer A output 1 Reset
        TA1RST: u1,
        /// Timer A Compare 1
        TACMP1: u1,
        /// Timer A Compare 2
        TACMP2: u1,
        /// Timer B output 1 Set
        TB1SET: u1,
        /// Timer B output 1 Reset
        TB1RST: u1,
        /// Timer B Compare 1
        TBCMP1: u1,
        /// Timer B Compare 2
        TBCMP2: u1,
        reserved24: u4 = 0,
        /// Timer D output 1 Set
        TD1SET: u1,
        /// Timer D output 1 Reset
        TD1RST: u1,
        /// Timer D Compare 1
        TDCMP1: u1,
        /// Timer D Compare 2
        TDCMP2: u1,
        /// Timer E output 1 Set
        TE1SET: u1,
        /// Timer E output 1 Reset
        TE1RST: u1,
        /// Timer E Compare 1
        TECMP1: u1,
        /// Timer E Compare 2
        TECMP2: u1,
    }),
    /// CPT2xCR
    /// offset: 0x60
    CPT2CCR: mmio.Mmio(packed struct(u32) {
        /// Software Capture
        SWCPT: u1,
        /// Update Capture
        UDPCPT: u1,
        /// External Event 1 Capture
        EXEV1CPT: u1,
        /// External Event 2 Capture
        EXEV2CPT: u1,
        /// External Event 3 Capture
        EXEV3CPT: u1,
        /// External Event 4 Capture
        EXEV4CPT: u1,
        /// External Event 5 Capture
        EXEV5CPT: u1,
        /// External Event 6 Capture
        EXEV6CPT: u1,
        /// External Event 7 Capture
        EXEV7CPT: u1,
        /// External Event 8 Capture
        EXEV8CPT: u1,
        /// External Event 9 Capture
        EXEV9CPT: u1,
        /// External Event 10 Capture
        EXEV10CPT: u1,
        /// Timer A output 1 Set
        TA1SET: u1,
        /// Timer A output 1 Reset
        TA1RST: u1,
        /// Timer A Compare 1
        TACMP1: u1,
        /// Timer A Compare 2
        TACMP2: u1,
        /// Timer B output 1 Set
        TB1SET: u1,
        /// Timer B output 1 Reset
        TB1RST: u1,
        /// Timer B Compare 1
        TBCMP1: u1,
        /// Timer B Compare 2
        TBCMP2: u1,
        reserved24: u4 = 0,
        /// Timer D output 1 Set
        TD1SET: u1,
        /// Timer D output 1 Reset
        TD1RST: u1,
        /// Timer D Compare 1
        TDCMP1: u1,
        /// Timer D Compare 2
        TDCMP2: u1,
        /// Timer E output 1 Set
        TE1SET: u1,
        /// Timer E output 1 Reset
        TE1RST: u1,
        /// Timer E Compare 1
        TECMP1: u1,
        /// Timer E Compare 2
        TECMP2: u1,
    }),
    /// Timerx Output Register
    /// offset: 0x64
    OUTCR: mmio.Mmio(packed struct(u32) {
        reserved1: u1 = 0,
        /// Output 1 polarity
        POL1: u1,
        /// Output 1 Idle mode
        IDLEM1: u1,
        /// Output 1 Idle State
        IDLES1: u1,
        /// Output 1 Fault state
        FAULT1: u2,
        /// Output 1 Chopper enable
        CHP1: u1,
        /// Output 1 Deadtime upon burst mode Idle entry
        DIDL1: u1,
        /// Deadtime enable
        DTEN: u1,
        /// Delayed Protection Enable
        DLYPRTEN: u1,
        /// Delayed Protection
        DLYPRT: u3,
        reserved17: u4 = 0,
        /// Output 2 polarity
        POL2: u1,
        /// Output 2 Idle mode
        IDLEM2: u1,
        /// Output 2 Idle State
        IDLES2: u1,
        /// Output 2 Fault state
        FAULT2: u2,
        /// Output 2 Chopper enable
        CHP2: u1,
        /// Output 2 Deadtime upon burst mode Idle entry
        DIDL2: u1,
        padding: u8 = 0,
    }),
    /// Timerx Fault Register
    /// offset: 0x68
    FLTCR: mmio.Mmio(packed struct(u32) {
        /// Fault 1 enable
        FLT1EN: u1,
        /// Fault 2 enable
        FLT2EN: u1,
        /// Fault 3 enable
        FLT3EN: u1,
        /// Fault 4 enable
        FLT4EN: u1,
        /// Fault 5 enable
        FLT5EN: u1,
        reserved31: u26 = 0,
        /// Fault sources Lock
        FLTLCK: u1,
    }),
};
