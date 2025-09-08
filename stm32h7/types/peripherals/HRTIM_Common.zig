const mmio = @import("mmio");
const types = @import("../../types.zig");

/// High Resolution Timer: Common functions
pub const HRTIM_Common = extern struct {
    /// Control Register 1
    /// offset: 0x00
    CR1: mmio.Mmio(packed struct(u32) {
        /// Master Update Disable
        MUDIS: u1,
        /// Timer A Update Disable
        TAUDIS: u1,
        /// Timer B Update Disable
        TBUDIS: u1,
        /// Timer C Update Disable
        TCUDIS: u1,
        /// Timer D Update Disable
        TDUDIS: u1,
        /// Timer E Update Disable
        TEUDIS: u1,
        reserved16: u10 = 0,
        /// ADC Trigger 1 Update Source
        AD1USRC: u3,
        /// ADC Trigger 2 Update Source
        AD2USRC: u3,
        /// ADC Trigger 3 Update Source
        AD3USRC: u3,
        /// ADC Trigger 4 Update Source
        AD4USRC: u3,
        padding: u4 = 0,
    }),
    /// Control Register 2
    /// offset: 0x04
    CR2: mmio.Mmio(packed struct(u32) {
        /// Master Timer Software update
        MSWU: u1,
        /// Timer A Software update
        TASWU: u1,
        /// Timer B Software Update
        TBSWU: u1,
        /// Timer C Software Update
        TCSWU: u1,
        /// Timer D Software Update
        TDSWU: u1,
        /// Timer E Software Update
        TESWU: u1,
        reserved8: u2 = 0,
        /// Master Counter software reset
        MRST: u1,
        /// Timer A counter software reset
        TARST: u1,
        /// Timer B counter software reset
        TBRST: u1,
        /// Timer C counter software reset
        TCRST: u1,
        /// Timer D counter software reset
        TDRST: u1,
        /// Timer E counter software reset
        TERST: u1,
        padding: u18 = 0,
    }),
    /// Interrupt Status Register
    /// offset: 0x08
    ISR: mmio.Mmio(packed struct(u32) {
        /// Fault 1 Interrupt Flag
        FLT1: u1,
        /// Fault 2 Interrupt Flag
        FLT2: u1,
        /// Fault 3 Interrupt Flag
        FLT3: u1,
        /// Fault 4 Interrupt Flag
        FLT4: u1,
        /// Fault 5 Interrupt Flag
        FLT5: u1,
        /// System Fault Interrupt Flag
        SYSFLT: u1,
        reserved16: u10 = 0,
        /// DLL Ready Interrupt Flag
        DLLRDY: u1,
        /// Burst mode Period Interrupt Flag
        BMPER: u1,
        padding: u14 = 0,
    }),
    /// Interrupt Clear Register
    /// offset: 0x0c
    ICR: mmio.Mmio(packed struct(u32) {
        /// Fault 1 Interrupt Flag Clear
        FLT1C: u1,
        /// Fault 2 Interrupt Flag Clear
        FLT2C: u1,
        /// Fault 3 Interrupt Flag Clear
        FLT3C: u1,
        /// Fault 4 Interrupt Flag Clear
        FLT4C: u1,
        /// Fault 5 Interrupt Flag Clear
        FLT5C: u1,
        /// System Fault Interrupt Flag Clear
        SYSFLTC: u1,
        reserved16: u10 = 0,
        /// DLL Ready Interrupt flag Clear
        DLLRDYC: u1,
        /// Burst mode period flag Clear
        BMPERC: u1,
        padding: u14 = 0,
    }),
    /// Interrupt Enable Register
    /// offset: 0x10
    IER: mmio.Mmio(packed struct(u32) {
        /// Fault 1 Interrupt Enable
        FLT1IE: u1,
        /// Fault 2 Interrupt Enable
        FLT2IE: u1,
        /// Fault 3 Interrupt Enable
        FLT3IE: u1,
        /// Fault 4 Interrupt Enable
        FLT4IE: u1,
        /// Fault 5 Interrupt Enable
        FLT5IE: u1,
        /// System Fault Interrupt Enable
        SYSFLTE: u1,
        reserved16: u10 = 0,
        /// DLL Ready Interrupt Enable
        DLLRDYIE: u1,
        /// Burst mode period Interrupt Enable
        BMPERIE: u1,
        padding: u14 = 0,
    }),
    /// Output Enable Register
    /// offset: 0x14
    OENR: mmio.Mmio(packed struct(u32) {
        /// Timer A Output 1 Enable
        TA1OEN: u1,
        /// Timer A Output 2 Enable
        TA2OEN: u1,
        /// Timer B Output 1 Enable
        TB1OEN: u1,
        /// Timer B Output 2 Enable
        TB2OEN: u1,
        /// Timer C Output 1 Enable
        TC1OEN: u1,
        /// Timer C Output 2 Enable
        TC2OEN: u1,
        /// Timer D Output 1 Enable
        TD1OEN: u1,
        /// Timer D Output 2 Enable
        TD2OEN: u1,
        /// Timer E Output 1 Enable
        TE1OEN: u1,
        /// Timer E Output 2 Enable
        TE2OEN: u1,
        padding: u22 = 0,
    }),
    /// DISR
    /// offset: 0x18
    DISR: mmio.Mmio(packed struct(u32) {
        /// TA1ODIS
        TA1ODIS: u1,
        /// TA2ODIS
        TA2ODIS: u1,
        /// TB1ODIS
        TB1ODIS: u1,
        /// TB2ODIS
        TB2ODIS: u1,
        /// TC1ODIS
        TC1ODIS: u1,
        /// TC2ODIS
        TC2ODIS: u1,
        /// TD1ODIS
        TD1ODIS: u1,
        /// TD2ODIS
        TD2ODIS: u1,
        /// TE1ODIS
        TE1ODIS: u1,
        /// TE2ODIS
        TE2ODIS: u1,
        padding: u22 = 0,
    }),
    /// Output Disable Status Register
    /// offset: 0x1c
    ODSR: mmio.Mmio(packed struct(u32) {
        /// Timer A Output 1 disable status
        TA1ODS: u1,
        /// Timer A Output 2 disable status
        TA2ODS: u1,
        /// Timer B Output 1 disable status
        TB1ODS: u1,
        /// Timer B Output 2 disable status
        TB2ODS: u1,
        /// Timer C Output 1 disable status
        TC1ODS: u1,
        /// Timer C Output 2 disable status
        TC2ODS: u1,
        /// Timer D Output 1 disable status
        TD1ODS: u1,
        /// Timer D Output 2 disable status
        TD2ODS: u1,
        /// Timer E Output 1 disable status
        TE1ODS: u1,
        /// Timer E Output 2 disable status
        TE2ODS: u1,
        padding: u22 = 0,
    }),
    /// Burst Mode Control Register
    /// offset: 0x20
    BMCR: mmio.Mmio(packed struct(u32) {
        /// Burst Mode enable
        BME: u1,
        /// Burst Mode operating mode
        BMOM: u1,
        /// Burst Mode Clock source
        BMCLK: u4,
        /// Burst Mode Prescaler
        BMPRSC: u4,
        /// Burst Mode Preload Enable
        BMPREN: u1,
        reserved16: u5 = 0,
        /// Master Timer Burst Mode
        MTBM: u1,
        /// Timer A Burst Mode
        TABM: u1,
        /// Timer B Burst Mode
        TBBM: u1,
        /// Timer C Burst Mode
        TCBM: u1,
        /// Timer D Burst Mode
        TDBM: u1,
        /// Timer E Burst Mode
        TEBM: u1,
        reserved31: u9 = 0,
        /// Burst Mode Status
        BMSTAT: u1,
    }),
    /// BMTRG
    /// offset: 0x24
    BMTRG: mmio.Mmio(packed struct(u32) {
        /// SW
        SW: u1,
        /// MSTRST
        MSTRST: u1,
        /// MSTREP
        MSTREP: u1,
        /// MSTCMP1
        MSTCMP1: u1,
        /// MSTCMP2
        MSTCMP2: u1,
        /// MSTCMP3
        MSTCMP3: u1,
        /// MSTCMP4
        MSTCMP4: u1,
        /// TARST
        TARST: u1,
        /// TAREP
        TAREP: u1,
        /// TACMP1
        TACMP1: u1,
        /// TACMP2
        TACMP2: u1,
        /// TBRST
        TBRST: u1,
        /// TBREP
        TBREP: u1,
        /// TBCMP1
        TBCMP1: u1,
        /// TBCMP2
        TBCMP2: u1,
        /// TCRST
        TCRST: u1,
        /// TCREP
        TCREP: u1,
        /// TCCMP1
        TCCMP1: u1,
        /// TCCMP2
        TCCMP2: u1,
        /// TDRST
        TDRST: u1,
        /// TDREP
        TDREP: u1,
        /// TDCMP1
        TDCMP1: u1,
        /// TDCMP2
        TDCMP2: u1,
        /// TERST
        TERST: u1,
        /// TEREP
        TEREP: u1,
        /// TECMP1
        TECMP1: u1,
        /// TECMP2
        TECMP2: u1,
        reserved31: u4 = 0,
        /// OCHPEV
        OCHPEV: u1,
    }),
    /// BMCMPR6
    /// offset: 0x28
    BMCMPR6: mmio.Mmio(packed struct(u32) {
        /// BMCMP
        BMCMP: u16,
        padding: u16 = 0,
    }),
    /// Burst Mode Period Register
    /// offset: 0x2c
    BMPER: mmio.Mmio(packed struct(u32) {
        /// Burst mode Period
        BMPER: u16,
        padding: u16 = 0,
    }),
    /// Timer External Event Control Register 1
    /// offset: 0x30
    EECR1: mmio.Mmio(packed struct(u32) {
        /// External Event 1 Source
        EE1SRC: u2,
        /// External Event 1 Polarity
        EE1POL: u1,
        /// External Event 1 Sensitivity
        EE1SNS: u2,
        /// External Event 1 Fast mode
        EE1FAST: u1,
        /// External Event 2 Source
        EE2SRC: u2,
        /// External Event 2 Polarity
        EE2POL: u1,
        /// External Event 2 Sensitivity
        EE2SNS: u2,
        /// External Event 2 Fast mode
        EE2FAST: u1,
        /// External Event 3 Source
        EE3SRC: u2,
        /// External Event 3 Polarity
        EE3POL: u1,
        /// External Event 3 Sensitivity
        EE3SNS: u2,
        /// External Event 3 Fast mode
        EE3FAST: u1,
        /// External Event 4 Source
        EE4SRC: u2,
        /// External Event 4 Polarity
        EE4POL: u1,
        /// External Event 4 Sensitivity
        EE4SNS: u2,
        /// External Event 4 Fast mode
        EE4FAST: u1,
        /// External Event 5 Source
        EE5SRC: u2,
        /// External Event 5 Polarity
        EE5POL: u1,
        /// External Event 5 Sensitivity
        EE5SNS: u2,
        /// External Event 5 Fast mode
        EE5FAST: u1,
        padding: u2 = 0,
    }),
    /// Timer External Event Control Register 2
    /// offset: 0x34
    EECR2: mmio.Mmio(packed struct(u32) {
        /// External Event 6 Source
        EE6SRC: u2,
        /// External Event 6 Polarity
        EE6POL: u1,
        /// External Event 6 Sensitivity
        EE6SNS: u2,
        reserved6: u1 = 0,
        /// External Event 7 Source
        EE7SRC: u2,
        /// External Event 7 Polarity
        EE7POL: u1,
        /// External Event 7 Sensitivity
        EE7SNS: u2,
        reserved12: u1 = 0,
        /// External Event 8 Source
        EE8SRC: u2,
        /// External Event 8 Polarity
        EE8POL: u1,
        /// External Event 8 Sensitivity
        EE8SNS: u2,
        reserved18: u1 = 0,
        /// External Event 9 Source
        EE9SRC: u2,
        /// External Event 9 Polarity
        EE9POL: u1,
        /// External Event 9 Sensitivity
        EE9SNS: u2,
        reserved24: u1 = 0,
        /// External Event 10 Source
        EE10SRC: u2,
        /// External Event 10 Polarity
        EE10POL: u1,
        /// External Event 10 Sensitivity
        EE10SNS: u2,
        padding: u3 = 0,
    }),
    /// Timer External Event Control Register 3
    /// offset: 0x38
    EECR3: mmio.Mmio(packed struct(u32) {
        /// EE6SRC
        EE6SRC: u2,
        /// EE6POL
        EE6POL: u1,
        /// EE6SNS
        EE6SNS: u2,
        reserved6: u1 = 0,
        /// EE7SRC
        EE7SRC: u2,
        /// EE7POL
        EE7POL: u1,
        /// EE7SNS
        EE7SNS: u2,
        reserved12: u1 = 0,
        /// EE8SRC
        EE8SRC: u2,
        /// EE8POL
        EE8POL: u1,
        /// EE8SNS
        EE8SNS: u2,
        reserved18: u1 = 0,
        /// EE9SRC
        EE9SRC: u2,
        /// EE9POL
        EE9POL: u1,
        /// EE9SNS
        EE9SNS: u2,
        reserved24: u1 = 0,
        /// EE10SRC
        EE10SRC: u2,
        /// EE10POL
        EE10POL: u1,
        /// EE10SNS
        EE10SNS: u2,
        padding: u3 = 0,
    }),
    /// ADC Trigger 1 Register
    /// offset: 0x3c
    ADC1R: mmio.Mmio(packed struct(u32) {
        /// ADC trigger 1 on Master Compare 1
        AD1MC1: u1,
        /// ADC trigger 1 on Master Compare 2
        AD1MC2: u1,
        /// ADC trigger 1 on Master Compare 3
        AD1MC3: u1,
        /// ADC trigger 1 on Master Compare 4
        AD1MC4: u1,
        /// ADC trigger 1 on Master Period
        AD1MPER: u1,
        /// ADC trigger 1 on External Event 1
        AD1EEV1: u1,
        /// ADC trigger 1 on External Event 2
        AD1EEV2: u1,
        /// ADC trigger 1 on External Event 3
        AD1EEV3: u1,
        /// ADC trigger 1 on External Event 4
        AD1EEV4: u1,
        /// ADC trigger 1 on External Event 5
        AD1EEV5: u1,
        /// ADC trigger 1 on Timer A compare 2
        AD1TAC2: u1,
        /// ADC trigger 1 on Timer A compare 3
        AD1TAC3: u1,
        /// ADC trigger 1 on Timer A compare 4
        AD1TAC4: u1,
        /// ADC trigger 1 on Timer A Period
        AD1TAPER: u1,
        /// ADC trigger 1 on Timer A Reset
        AD1TARST: u1,
        /// ADC trigger 1 on Timer B compare 2
        AD1TBC2: u1,
        /// ADC trigger 1 on Timer B compare 3
        AD1TBC3: u1,
        /// ADC trigger 1 on Timer B compare 4
        AD1TBC4: u1,
        /// ADC trigger 1 on Timer B Period
        AD1TBPER: u1,
        /// ADC trigger 1 on Timer B Reset
        AD1TBRST: u1,
        /// ADC trigger 1 on Timer C compare 2
        AD1TCC2: u1,
        /// ADC trigger 1 on Timer C compare 3
        AD1TCC3: u1,
        /// ADC trigger 1 on Timer C compare 4
        AD1TCC4: u1,
        /// ADC trigger 1 on Timer C Period
        AD1TCPER: u1,
        /// ADC trigger 1 on Timer D compare 2
        AD1TDC2: u1,
        /// ADC trigger 1 on Timer D compare 3
        AD1TDC3: u1,
        /// ADC trigger 1 on Timer D compare 4
        AD1TDC4: u1,
        /// ADC trigger 1 on Timer D Period
        AD1TDPER: u1,
        /// ADC trigger 1 on Timer E compare 2
        AD1TEC2: u1,
        /// ADC trigger 1 on Timer E compare 3
        AD1TEC3: u1,
        /// ADC trigger 1 on Timer E compare 4
        AD1TEC4: u1,
        /// ADC trigger 1 on Timer E Period
        AD1TEPER: u1,
    }),
    /// ADC Trigger 2 Register
    /// offset: 0x40
    ADC2R: mmio.Mmio(packed struct(u32) {
        /// ADC trigger 2 on Master Compare 1
        AD2MC1: u1,
        /// ADC trigger 2 on Master Compare 2
        AD2MC2: u1,
        /// ADC trigger 2 on Master Compare 3
        AD2MC3: u1,
        /// ADC trigger 2 on Master Compare 4
        AD2MC4: u1,
        /// ADC trigger 2 on Master Period
        AD2MPER: u1,
        /// ADC trigger 2 on External Event 6
        AD2EEV6: u1,
        /// ADC trigger 2 on External Event 7
        AD2EEV7: u1,
        /// ADC trigger 2 on External Event 8
        AD2EEV8: u1,
        /// ADC trigger 2 on External Event 9
        AD2EEV9: u1,
        /// ADC trigger 2 on External Event 10
        AD2EEV10: u1,
        /// ADC trigger 2 on Timer A compare 2
        AD2TAC2: u1,
        /// ADC trigger 2 on Timer A compare 3
        AD2TAC3: u1,
        /// ADC trigger 2 on Timer A compare 4
        AD2TAC4: u1,
        /// ADC trigger 2 on Timer A Period
        AD2TAPER: u1,
        /// ADC trigger 2 on Timer B compare 2
        AD2TBC2: u1,
        /// ADC trigger 2 on Timer B compare 3
        AD2TBC3: u1,
        /// ADC trigger 2 on Timer B compare 4
        AD2TBC4: u1,
        /// ADC trigger 2 on Timer B Period
        AD2TBPER: u1,
        /// ADC trigger 2 on Timer C compare 2
        AD2TCC2: u1,
        /// ADC trigger 2 on Timer C compare 3
        AD2TCC3: u1,
        /// ADC trigger 2 on Timer C compare 4
        AD2TCC4: u1,
        /// ADC trigger 2 on Timer C Period
        AD2TCPER: u1,
        /// ADC trigger 2 on Timer C Reset
        AD2TCRST: u1,
        /// ADC trigger 2 on Timer D compare 2
        AD2TDC2: u1,
        /// ADC trigger 2 on Timer D compare 3
        AD2TDC3: u1,
        /// ADC trigger 2 on Timer D compare 4
        AD2TDC4: u1,
        /// ADC trigger 2 on Timer D Period
        AD2TDPER: u1,
        /// ADC trigger 2 on Timer D Reset
        AD2TDRST: u1,
        /// ADC trigger 2 on Timer E compare 2
        AD2TEC2: u1,
        /// ADC trigger 2 on Timer E compare 3
        AD2TEC3: u1,
        /// ADC trigger 2 on Timer E compare 4
        AD2TEC4: u1,
        /// ADC trigger 2 on Timer E Reset
        AD2TERST: u1,
    }),
    /// ADC Trigger 3 Register
    /// offset: 0x44
    ADC3R: mmio.Mmio(packed struct(u32) {
        /// AD1MC1
        AD1MC1: u1,
        /// AD1MC2
        AD1MC2: u1,
        /// AD1MC3
        AD1MC3: u1,
        /// AD1MC4
        AD1MC4: u1,
        /// AD1MPER
        AD1MPER: u1,
        /// AD1EEV1
        AD1EEV1: u1,
        /// AD1EEV2
        AD1EEV2: u1,
        /// AD1EEV3
        AD1EEV3: u1,
        /// AD1EEV4
        AD1EEV4: u1,
        /// AD1EEV5
        AD1EEV5: u1,
        /// AD1TAC2
        AD1TAC2: u1,
        /// AD1TAC3
        AD1TAC3: u1,
        /// AD1TAC4
        AD1TAC4: u1,
        /// AD1TAPER
        AD1TAPER: u1,
        /// AD1TARST
        AD1TARST: u1,
        /// AD1TBC2
        AD1TBC2: u1,
        /// AD1TBC3
        AD1TBC3: u1,
        /// AD1TBC4
        AD1TBC4: u1,
        /// AD1TBPER
        AD1TBPER: u1,
        /// AD1TBRST
        AD1TBRST: u1,
        /// AD1TCC2
        AD1TCC2: u1,
        /// AD1TCC3
        AD1TCC3: u1,
        /// AD1TCC4
        AD1TCC4: u1,
        /// AD1TCPER
        AD1TCPER: u1,
        /// AD1TDC2
        AD1TDC2: u1,
        /// AD1TDC3
        AD1TDC3: u1,
        /// AD1TDC4
        AD1TDC4: u1,
        /// AD1TDPER
        AD1TDPER: u1,
        /// AD1TEC2
        AD1TEC2: u1,
        /// AD1TEC3
        AD1TEC3: u1,
        /// AD1TEC4
        AD1TEC4: u1,
        /// AD1TEPER
        AD1TEPER: u1,
    }),
    /// ADC Trigger 4 Register
    /// offset: 0x48
    ADC4R: mmio.Mmio(packed struct(u32) {
        /// AD2MC1
        AD2MC1: u1,
        /// AD2MC2
        AD2MC2: u1,
        /// AD2MC3
        AD2MC3: u1,
        /// AD2MC4
        AD2MC4: u1,
        /// AD2MPER
        AD2MPER: u1,
        /// AD2EEV6
        AD2EEV6: u1,
        /// AD2EEV7
        AD2EEV7: u1,
        /// AD2EEV8
        AD2EEV8: u1,
        /// AD2EEV9
        AD2EEV9: u1,
        /// AD2EEV10
        AD2EEV10: u1,
        /// AD2TAC2
        AD2TAC2: u1,
        /// AD2TAC3
        AD2TAC3: u1,
        /// AD2TAC4
        AD2TAC4: u1,
        /// AD2TAPER
        AD2TAPER: u1,
        /// AD2TBC2
        AD2TBC2: u1,
        /// AD2TBC3
        AD2TBC3: u1,
        /// AD2TBC4
        AD2TBC4: u1,
        /// AD2TBPER
        AD2TBPER: u1,
        /// AD2TCC2
        AD2TCC2: u1,
        /// AD2TCC3
        AD2TCC3: u1,
        /// AD2TCC4
        AD2TCC4: u1,
        /// AD2TCPER
        AD2TCPER: u1,
        /// AD2TCRST
        AD2TCRST: u1,
        /// AD2TDC2
        AD2TDC2: u1,
        /// AD2TDC3
        AD2TDC3: u1,
        /// AD2TDC4
        AD2TDC4: u1,
        /// AD2TDPER
        AD2TDPER: u1,
        /// AD2TDRST
        AD2TDRST: u1,
        /// AD2TEC2
        AD2TEC2: u1,
        /// AD2TEC3
        AD2TEC3: u1,
        /// AD2TEC4
        AD2TEC4: u1,
        /// AD2TERST
        AD2TERST: u1,
    }),
    /// DLL Control Register
    /// offset: 0x4c
    DLLCR: mmio.Mmio(packed struct(u32) {
        /// DLL Calibration Start
        CAL: u1,
        /// DLL Calibration Enable
        CALEN: u1,
        /// DLL Calibration rate
        CALRTE: u2,
        padding: u28 = 0,
    }),
    /// HRTIM Fault Input Register 1
    /// offset: 0x50
    FLTINR1: mmio.Mmio(packed struct(u32) {
        /// FLT1E
        FLT1E: u1,
        /// FLT1P
        FLT1P: u1,
        /// FLT1SRC
        FLT1SRC: u1,
        /// FLT1F
        FLT1F: u4,
        /// FLT1LCK
        FLT1LCK: u1,
        /// FLT2E
        FLT2E: u1,
        /// FLT2P
        FLT2P: u1,
        /// FLT2SRC
        FLT2SRC: u1,
        /// FLT2F
        FLT2F: u4,
        /// FLT2LCK
        FLT2LCK: u1,
        /// FLT3E
        FLT3E: u1,
        /// FLT3P
        FLT3P: u1,
        /// FLT3SRC
        FLT3SRC: u1,
        /// FLT3F
        FLT3F: u4,
        /// FLT3LCK
        FLT3LCK: u1,
        /// FLT4E
        FLT4E: u1,
        /// FLT4P
        FLT4P: u1,
        /// FLT4SRC
        FLT4SRC: u1,
        /// FLT4F
        FLT4F: u4,
        /// FLT4LCK
        FLT4LCK: u1,
    }),
    /// HRTIM Fault Input Register 2
    /// offset: 0x54
    FLTINR2: mmio.Mmio(packed struct(u32) {
        /// FLT5E
        FLT5E: u1,
        /// FLT5P
        FLT5P: u1,
        /// FLT5SRC
        FLT5SRC: u1,
        /// FLT5F
        FLT5F: u4,
        /// FLT5LCK
        FLT5LCK: u1,
        reserved24: u16 = 0,
        /// FLTSD
        FLTSD: u2,
        padding: u6 = 0,
    }),
    /// BDMUPDR
    /// offset: 0x58
    BDMUPDR: mmio.Mmio(packed struct(u32) {
        /// MCR
        MCR: u1,
        /// MICR
        MICR: u1,
        /// MDIER
        MDIER: u1,
        /// MCNT
        MCNT: u1,
        /// MPER
        MPER: u1,
        /// MREP
        MREP: u1,
        /// MCMP1
        MCMP1: u1,
        /// MCMP2
        MCMP2: u1,
        /// MCMP3
        MCMP3: u1,
        /// MCMP4
        MCMP4: u1,
        padding: u22 = 0,
    }),
    /// Burst DMA Timerx update Register
    /// offset: 0x5c
    BDTxUPR: mmio.Mmio(packed struct(u32) {
        /// HRTIM_TIMxCR register update enable
        TIMxCR: u1,
        /// HRTIM_TIMxICR register update enable
        TIMxICR: u1,
        /// HRTIM_TIMxDIER register update enable
        TIMxDIER: u1,
        /// HRTIM_CNTxR register update enable
        TIMxCNT: u1,
        /// HRTIM_PERxR register update enable
        TIMxPER: u1,
        /// HRTIM_REPxR register update enable
        TIMxREP: u1,
        /// HRTIM_CMP1xR register update enable
        TIMxCMP1: u1,
        /// HRTIM_CMP2xR register update enable
        TIMxCMP2: u1,
        /// HRTIM_CMP3xR register update enable
        TIMxCMP3: u1,
        /// HRTIM_CMP4xR register update enable
        TIMxCMP4: u1,
        /// HRTIM_DTxR register update enable
        TIMx_DTxR: u1,
        /// HRTIM_SET1xR register update enable
        TIMxSET1R: u1,
        /// HRTIM_RST1xR register update enable
        TIMxRST1R: u1,
        /// HRTIM_SET2xR register update enable
        TIMxSET2R: u1,
        /// HRTIM_RST2xR register update enable
        TIMxRST2R: u1,
        /// HRTIM_EEFxR1 register update enable
        TIMxEEFR1: u1,
        /// HRTIM_EEFxR2 register update enable
        TIMxEEFR2: u1,
        /// HRTIM_RSTxR register update enable
        TIMxRSTR: u1,
        /// HRTIM_CHPxR register update enable
        TIMxCHPR: u1,
        /// HRTIM_OUTxR register update enable
        TIMxOUTR: u1,
        /// HRTIM_FLTxR register update enable
        TIMxFLTR: u1,
        padding: u11 = 0,
    }),
    /// Burst DMA Data Register
    /// offset: 0x60
    BDMADR: mmio.Mmio(packed struct(u32) {
        /// Burst DMA Data register
        BDMADR: u32,
    }),
};
