const mmio = @import("mmio");
const types = @import("../../types.zig");

/// RTC
pub const RTC = extern struct {
    /// The RTC_TR is the calendar time shadow register. This register must be written in initialization mode only. Refer to Calendar initialization and configuration on page9 and Reading the calendar on page10.This register is write protected. The write access procedure is described in RTC register write protection on page9.
    /// offset: 0x00
    RTC_TR: mmio.Mmio(packed struct(u32) {
        /// Second units in BCD format
        SU: u4,
        /// Second tens in BCD format
        ST: u3,
        reserved8: u1 = 0,
        /// Minute units in BCD format
        MNU: u4,
        /// Minute tens in BCD format
        MNT: u3,
        reserved16: u1 = 0,
        /// Hour units in BCD format
        HU: u4,
        /// Hour tens in BCD format
        HT: u2,
        /// AM/PM notation
        PM: u1,
        padding: u9 = 0,
    }),
    /// The RTC_DR is the calendar date shadow register. This register must be written in initialization mode only. Refer to Calendar initialization and configuration on page9 and Reading the calendar on page10.This register is write protected. The write access procedure is described in RTC register write protection on page9.
    /// offset: 0x04
    RTC_DR: mmio.Mmio(packed struct(u32) {
        /// Date units in BCD format
        DU: u4,
        /// Date tens in BCD format
        DT: u2,
        reserved8: u2 = 0,
        /// Month units in BCD format
        MU: u4,
        /// Month tens in BCD format
        MT: u1,
        /// Week day units
        WDU: u3,
        /// Year units in BCD format
        YU: u4,
        /// Year tens in BCD format
        YT: u4,
        padding: u8 = 0,
    }),
    /// RTC control register
    /// offset: 0x08
    RTC_CR: mmio.Mmio(packed struct(u32) {
        /// Wakeup clock selection
        WUCKSEL: u3,
        /// Time-stamp event active edge TSE must be reset when TSEDGE is changed to avoid unwanted TSF setting.
        TSEDGE: u1,
        /// RTC_REFIN reference clock detection enable (50 or 60Hz) Note: PREDIV_S must be 0x00FF.
        REFCKON: u1,
        /// Bypass the shadow registers Note: If the frequency of the APB clock is less than seven times the frequency of RTCCLK, BYPSHAD must be set to 1.
        BYPSHAD: u1,
        /// Hour format
        FMT: u1,
        reserved8: u1 = 0,
        /// Alarm A enable
        ALRAE: u1,
        /// Alarm B enable
        ALRBE: u1,
        /// Wakeup timer enable
        WUTE: u1,
        /// timestamp enable
        TSE: u1,
        /// Alarm A interrupt enable
        ALRAIE: u1,
        /// Alarm B interrupt enable
        ALRBIE: u1,
        /// Wakeup timer interrupt enable
        WUTIE: u1,
        /// Time-stamp interrupt enable
        TSIE: u1,
        /// Add 1 hour (summer time change) When this bit is set outside initialization mode, 1 hour is added to the calendar time. This bit is always read as 0.
        ADD1H: u1,
        /// Subtract 1 hour (winter time change) When this bit is set outside initialization mode, 1 hour is subtracted to the calendar time if the current hour is not 0. This bit is always read as 0. Setting this bit has no effect when current hour is 0.
        SUB1H: u1,
        /// Backup This bit can be written by the user to memorize whether the daylight saving time change has been performed or not.
        BKP: u1,
        /// Calibration output selection When COE=1, this bit selects which signal is output on RTC_CALIB. These frequencies are valid for RTCCLK at 32.768 kHz and prescalers at their default values (PREDIV_A=127 and PREDIV_S=255). Refer to Section24.3.15: Calibration clock output
        COSEL: u1,
        /// Output polarity This bit is used to configure the polarity of RTC_ALARM output
        POL: u1,
        /// Output selection These bits are used to select the flag to be routed to RTC_ALARM output
        OSEL: u2,
        /// Calibration output enable This bit enables the RTC_CALIB output
        COE: u1,
        /// timestamp on internal event enable
        ITSE: u1,
        padding: u7 = 0,
    }),
    /// This register is write protected (except for RTC_ISR[13:8] bits). The write access procedure is described in RTC register write protection on page9.
    /// offset: 0x0c
    RTC_ISR: mmio.Mmio(packed struct(u32) {
        /// Alarm A write flag This bit is set by hardware when Alarm A values can be changed, after the ALRAE bit has been set to 0 in RTC_CR. It is cleared by hardware in initialization mode.
        ALRAWF: u1,
        /// Alarm B write flag This bit is set by hardware when Alarm B values can be changed, after the ALRBE bit has been set to 0 in RTC_CR. It is cleared by hardware in initialization mode.
        ALRBWF: u1,
        /// Wakeup timer write flag This bit is set by hardware up to 2 RTCCLK cycles after the WUTE bit has been set to 0 in RTC_CR, and is cleared up to 2 RTCCLK cycles after the WUTE bit has been set to 1. The wakeup timer values can be changed when WUTE bit is cleared and WUTWF is set.
        WUTWF: u1,
        /// Shift operation pending This flag is set by hardware as soon as a shift operation is initiated by a write to the RTC_SHIFTR register. It is cleared by hardware when the corresponding shift operation has been executed. Writing to the SHPF bit has no effect.
        SHPF: u1,
        /// Initialization status flag This bit is set by hardware when the calendar year field is different from 0 (Backup domain reset state).
        INITS: u1,
        /// Registers synchronization flag This bit is set by hardware each time the calendar registers are copied into the shadow registers (RTC_SSRx, RTC_TRx and RTC_DRx). This bit is cleared by hardware in initialization mode, while a shift operation is pending (SHPF=1), or when in bypass shadow register mode (BYPSHAD=1). This bit can also be cleared by software. It is cleared either by software or by hardware in initialization mode.
        RSF: u1,
        /// Initialization flag When this bit is set to 1, the RTC is in initialization state, and the time, date and prescaler registers can be updated.
        INITF: u1,
        /// Initialization mode
        INIT: u1,
        /// Alarm A flag This flag is set by hardware when the time/date registers (RTC_TR and RTC_DR) match the Alarm A register (RTC_ALRMAR). This flag is cleared by software by writing 0.
        ALRAF: u1,
        /// Alarm B flag This flag is set by hardware when the time/date registers (RTC_TR and RTC_DR) match the Alarm B register (RTC_ALRMBR). This flag is cleared by software by writing 0.
        ALRBF: u1,
        /// Wakeup timer flag This flag is set by hardware when the wakeup auto-reload counter reaches 0. This flag is cleared by software by writing 0. This flag must be cleared by software at least 1.5 RTCCLK periods before WUTF is set to 1 again.
        WUTF: u1,
        /// Time-stamp flag This flag is set by hardware when a time-stamp event occurs. This flag is cleared by software by writing 0.
        TSF: u1,
        /// Time-stamp overflow flag This flag is set by hardware when a time-stamp event occurs while TSF is already set. This flag is cleared by software by writing 0. It is recommended to check and then clear TSOVF only after clearing the TSF bit. Otherwise, an overflow might not be noticed if a time-stamp event occurs immediately before the TSF bit is cleared.
        TSOVF: u1,
        /// RTC_TAMP1 detection flag This flag is set by hardware when a tamper detection event is detected on the RTC_TAMP1 input. It is cleared by software writing 0
        TAMP1F: u1,
        /// RTC_TAMP2 detection flag This flag is set by hardware when a tamper detection event is detected on the RTC_TAMP2 input. It is cleared by software writing 0
        TAMP2F: u1,
        /// RTC_TAMP3 detection flag This flag is set by hardware when a tamper detection event is detected on the RTC_TAMP3 input. It is cleared by software writing 0
        TAMP3F: u1,
        /// Recalibration pending Flag The RECALPF status flag is automatically set to 1 when software writes to the RTC_CALR register, indicating that the RTC_CALR register is blocked. When the new calibration settings are taken into account, this bit returns to 0. Refer to Re-calibration on-the-fly.
        RECALPF: u1,
        /// Internal tTime-stamp flag
        ITSF: u1,
        padding: u14 = 0,
    }),
    /// This register must be written in initialization mode only. The initialization must be performed in two separate write accesses. Refer to Calendar initialization and configuration on page9.This register is write protected. The write access procedure is described in RTC register write protection on page9.
    /// offset: 0x10
    RTC_PRER: mmio.Mmio(packed struct(u32) {
        /// Synchronous prescaler factor This is the synchronous division factor: ck_spre frequency = ck_apre frequency/(PREDIV_S+1)
        PREDIV_S: u15,
        reserved16: u1 = 0,
        /// Asynchronous prescaler factor This is the asynchronous division factor: ck_apre frequency = RTCCLK frequency/(PREDIV_A+1)
        PREDIV_A: u7,
        padding: u9 = 0,
    }),
    /// This register can be written only when WUTWF is set to 1 in RTC_ISR.This register is write protected. The write access procedure is described in RTC register write protection on page9.
    /// offset: 0x14
    RTC_WUTR: mmio.Mmio(packed struct(u32) {
        /// Wakeup auto-reload value bits When the wakeup timer is enabled (WUTE set to 1), the WUTF flag is set every (WUT[15:0] + 1) ck_wut cycles. The ck_wut period is selected through WUCKSEL[2:0] bits of the RTC_CR register When WUCKSEL[2] = 1, the wakeup timer becomes 17-bits and WUCKSEL[1] effectively becomes WUT[16] the most-significant bit to be reloaded into the timer. The first assertion of WUTF occurs (WUT+1) ck_wut cycles after WUTE is set. Setting WUT[15:0] to 0x0000 with WUCKSEL[2:0] =011 (RTCCLK/2) is forbidden.
        WUT: u16,
        padding: u16 = 0,
    }),
    /// offset: 0x18
    reserved24: [4]u8,
    /// This register can be written only when ALRAWF is set to 1 in RTC_ISR, or in initialization mode.This register is write protected. The write access procedure is described in RTC register write protection on page9.
    /// offset: 0x1c
    RTC_ALRMAR: mmio.Mmio(packed struct(u32) {
        /// Second units in BCD format.
        SU: u4,
        /// Second tens in BCD format.
        ST: u3,
        /// Alarm A seconds mask
        MSK1: u1,
        /// Minute units in BCD format.
        MNU: u4,
        /// Minute tens in BCD format.
        MNT: u3,
        /// Alarm A minutes mask
        MSK2: u1,
        /// Hour units in BCD format.
        HU: u4,
        /// Hour tens in BCD format.
        HT: u2,
        /// AM/PM notation
        PM: u1,
        /// Alarm A hours mask
        MSK3: u1,
        /// Date units or day in BCD format.
        DU: u4,
        /// Date tens in BCD format.
        DT: u2,
        /// Week day selection
        WDSEL: u1,
        /// Alarm A date mask
        MSK4: u1,
    }),
    /// This register can be written only when ALRBWF is set to 1 in RTC_ISR, or in initialization mode.This register is write protected. The write access procedure is described in RTC register write protection on page9.
    /// offset: 0x20
    RTC_ALRMBR: mmio.Mmio(packed struct(u32) {
        /// Second units in BCD format
        SU: u4,
        /// Second tens in BCD format
        ST: u3,
        /// Alarm B seconds mask
        MSK1: u1,
        /// Minute units in BCD format
        MNU: u4,
        /// Minute tens in BCD format
        MNT: u3,
        /// Alarm B minutes mask
        MSK2: u1,
        /// Hour units in BCD format
        HU: u4,
        /// Hour tens in BCD format
        HT: u2,
        /// AM/PM notation
        PM: u1,
        /// Alarm B hours mask
        MSK3: u1,
        /// Date units or day in BCD format
        DU: u4,
        /// Date tens in BCD format
        DT: u2,
        /// Week day selection
        WDSEL: u1,
        /// Alarm B date mask
        MSK4: u1,
    }),
    /// RTC write protection register
    /// offset: 0x24
    RTC_WPR: mmio.Mmio(packed struct(u32) {
        /// Write protection key This byte is written by software. Reading this byte always returns 0x00. Refer to RTC register write protection for a description of how to unlock RTC register write protection.
        KEY: u8,
        padding: u24 = 0,
    }),
    /// RTC sub second register
    /// offset: 0x28
    RTC_SSR: mmio.Mmio(packed struct(u32) {
        /// Sub second value SS[15:0] is the value in the synchronous prescaler counter. The fraction of a second is given by the formula below: Second fraction = (PREDIV_S - SS) / (PREDIV_S + 1) Note: SS can be larger than PREDIV_S only after a shift operation. In that case, the correct time/date is one second less than as indicated by RTC_TR/RTC_DR.
        SS: u16,
        padding: u16 = 0,
    }),
    /// This register is write protected. The write access procedure is described in RTC register write protection on page9.
    /// offset: 0x2c
    RTC_SHIFTR: mmio.Mmio(packed struct(u32) {
        /// Subtract a fraction of a second These bits are write only and is always read as zero. Writing to this bit has no effect when a shift operation is pending (when SHPF=1, in RTC_ISR). The value which is written to SUBFS is added to the synchronous prescaler counter. Since this counter counts down, this operation effectively subtracts from (delays) the clock by: Delay (seconds) = SUBFS / (PREDIV_S + 1) A fraction of a second can effectively be added to the clock (advancing the clock) when the ADD1S function is used in conjunction with SUBFS, effectively advancing the clock by: Advance (seconds) = (1 - (SUBFS / (PREDIV_S + 1))). Note: Writing to SUBFS causes RSF to be cleared. Software can then wait until RSF=1 to be sure that the shadow registers have been updated with the shifted time.
        SUBFS: u15,
        reserved31: u16 = 0,
        /// Add one second This bit is write only and is always read as zero. Writing to this bit has no effect when a shift operation is pending (when SHPF=1, in RTC_ISR). This function is intended to be used with SUBFS (see description below) in order to effectively add a fraction of a second to the clock in an atomic operation.
        ADD1S: u1,
    }),
    /// The content of this register is valid only when TSF is set to 1 in RTC_ISR. It is cleared when TSF bit is reset.
    /// offset: 0x30
    RTC_TSTR: mmio.Mmio(packed struct(u32) {
        /// Second units in BCD format.
        SU: u4,
        /// Second tens in BCD format.
        ST: u3,
        reserved8: u1 = 0,
        /// Minute units in BCD format.
        MNU: u4,
        /// Minute tens in BCD format.
        MNT: u3,
        reserved16: u1 = 0,
        /// Hour units in BCD format.
        HU: u4,
        /// Hour tens in BCD format.
        HT: u2,
        /// AM/PM notation
        PM: u1,
        padding: u9 = 0,
    }),
    /// The content of this register is valid only when TSF is set to 1 in RTC_ISR. It is cleared when TSF bit is reset.
    /// offset: 0x34
    RTC_TSDR: mmio.Mmio(packed struct(u32) {
        /// Date units in BCD format
        DU: u4,
        /// Date tens in BCD format
        DT: u2,
        reserved8: u2 = 0,
        /// Month units in BCD format
        MU: u4,
        /// Month tens in BCD format
        MT: u1,
        /// Week day units
        WDU: u3,
        padding: u16 = 0,
    }),
    /// The content of this register is valid only when RTC_ISR/TSF is set. It is cleared when the RTC_ISR/TSF bit is reset.
    /// offset: 0x38
    RTC_TSSSR: mmio.Mmio(packed struct(u32) {
        /// Sub second value SS[15:0] is the value of the synchronous prescaler counter when the timestamp event occurred.
        SS: u16,
        padding: u16 = 0,
    }),
    /// This register is write protected. The write access procedure is described in RTC register write protection on page9.
    /// offset: 0x3c
    RTC_CALR: mmio.Mmio(packed struct(u32) {
        /// Calibration minus The frequency of the calendar is reduced by masking CALM out of 220 RTCCLK pulses (32 seconds if the input frequency is 32768 Hz). This decreases the frequency of the calendar with a resolution of 0.9537 ppm. To increase the frequency of the calendar, this feature should be used in conjunction with CALP. See Section24.3.12: RTC smooth digital calibration on page13.
        CALM: u9,
        reserved13: u4 = 0,
        /// Use a 16-second calibration cycle period When CALW16 is set to 1, the 16-second calibration cycle period is selected.This bit must not be set to 1 if CALW8=1. Note: CALM[0] is stuck at 0 when CALW16= 1. Refer to Section24.3.12: RTC smooth digital calibration.
        CALW16: u1,
        /// Use an 8-second calibration cycle period When CALW8 is set to 1, the 8-second calibration cycle period is selected. Note: CALM[1:0] are stuck at 00; when CALW8= 1. Refer to Section24.3.12: RTC smooth digital calibration.
        CALW8: u1,
        /// Increase frequency of RTC by 488.5 ppm This feature is intended to be used in conjunction with CALM, which lowers the frequency of the calendar with a fine resolution. if the input frequency is 32768 Hz, the number of RTCCLK pulses added during a 32-second window is calculated as follows: (512 * CALP) - CALM. Refer to Section24.3.12: RTC smooth digital calibration.
        CALP: u1,
        padding: u16 = 0,
    }),
    /// RTC tamper and alternate function configuration register
    /// offset: 0x40
    RTC_TAMPCR: mmio.Mmio(packed struct(u32) {
        /// RTC_TAMP1 input detection enable
        TAMP1E: u1,
        /// Active level for RTC_TAMP1 input If TAMPFLT != 00 if TAMPFLT = 00:
        TAMP1TRG: u1,
        /// Tamper interrupt enable
        TAMPIE: u1,
        /// RTC_TAMP2 input detection enable
        TAMP2E: u1,
        /// Active level for RTC_TAMP2 input if TAMPFLT != 00: if TAMPFLT = 00:
        TAMP2TRG: u1,
        /// RTC_TAMP3 detection enable
        TAMP3E: u1,
        /// Active level for RTC_TAMP3 input if TAMPFLT != 00: if TAMPFLT = 00:
        TAMP3TRG: u1,
        /// Activate timestamp on tamper detection event TAMPTS is valid even if TSE=0 in the RTC_CR register.
        TAMPTS: u1,
        /// Tamper sampling frequency Determines the frequency at which each of the RTC_TAMPx inputs are sampled.
        TAMPFREQ: u3,
        /// RTC_TAMPx filter count These bits determines the number of consecutive samples at the specified level (TAMP*TRG) needed to activate a Tamper event. TAMPFLT is valid for each of the RTC_TAMPx inputs.
        TAMPFLT: u2,
        /// RTC_TAMPx precharge duration These bit determines the duration of time during which the pull-up/is activated before each sample. TAMPPRCH is valid for each of the RTC_TAMPx inputs.
        TAMPPRCH: u2,
        /// RTC_TAMPx pull-up disable This bit determines if each of the RTC_TAMPx pins are pre-charged before each sample.
        TAMPPUDIS: u1,
        /// Tamper 1 interrupt enable
        TAMP1IE: u1,
        /// Tamper 1 no erase
        TAMP1NOERASE: u1,
        /// Tamper 1 mask flag
        TAMP1MF: u1,
        /// Tamper 2 interrupt enable
        TAMP2IE: u1,
        /// Tamper 2 no erase
        TAMP2NOERASE: u1,
        /// Tamper 2 mask flag
        TAMP2MF: u1,
        /// Tamper 3 interrupt enable
        TAMP3IE: u1,
        /// Tamper 3 no erase
        TAMP3NOERASE: u1,
        /// Tamper 3 mask flag
        TAMP3MF: u1,
        padding: u7 = 0,
    }),
    /// This register can be written only when ALRAE is reset in RTC_CR register, or in initialization mode.This register is write protected. The write access procedure is described in RTC register write protection on page9
    /// offset: 0x44
    RTC_ALRMASSR: mmio.Mmio(packed struct(u32) {
        /// Sub seconds value This value is compared with the contents of the synchronous prescaler counter to determine if Alarm A is to be activated. Only bits 0 up MASKSS-1 are compared.
        SS: u15,
        reserved24: u9 = 0,
        /// Mask the most-significant bits starting at this bit ... The overflow bits of the synchronous counter (bits 15) is never compared. This bit can be different from 0 only after a shift operation.
        MASKSS: u4,
        padding: u4 = 0,
    }),
    /// This register can be written only when ALRBE is reset in RTC_CR register, or in initialization mode.This register is write protected.The write access procedure is described in Section: RTC register write protection.
    /// offset: 0x48
    RTC_ALRMBSSR: mmio.Mmio(packed struct(u32) {
        /// Sub seconds value This value is compared with the contents of the synchronous prescaler counter to determine if Alarm B is to be activated. Only bits 0 up to MASKSS-1 are compared.
        SS: u15,
        reserved24: u9 = 0,
        /// Mask the most-significant bits starting at this bit ... The overflow bits of the synchronous counter (bits 15) is never compared. This bit can be different from 0 only after a shift operation.
        MASKSS: u4,
        padding: u4 = 0,
    }),
    /// RTC option register
    /// offset: 0x4c
    RTC_OR: mmio.Mmio(packed struct(u32) {
        /// RTC_ALARM output type on PC13
        RTC_ALARM_TYPE: u1,
        /// RTC_OUT remap
        RTC_OUT_RMP: u1,
        padding: u30 = 0,
    }),
    /// RTC backup registers
    /// offset: 0x50
    RTC_BKP0R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0x54
    RTC_BKP1R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0x58
    RTC_BKP2R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0x5c
    RTC_BKP3R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0x60
    RTC_BKP4R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0x64
    RTC_BKP5R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0x68
    RTC_BKP6R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0x6c
    RTC_BKP7R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0x70
    RTC_BKP8R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0x74
    RTC_BKP9R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0x78
    RTC_BKP10R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0x7c
    RTC_BKP11R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0x80
    RTC_BKP12R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0x84
    RTC_BKP13R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0x88
    RTC_BKP14R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0x8c
    RTC_BKP15R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0x90
    RTC_BKP16R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0x94
    RTC_BKP17R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0x98
    RTC_BKP18R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0x9c
    RTC_BKP19R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0xa0
    RTC_BKP20R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0xa4
    RTC_BKP21R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0xa8
    RTC_BKP22R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0xac
    RTC_BKP23R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0xb0
    RTC_BKP24R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0xb4
    RTC_BKP25R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0xb8
    RTC_BKP26R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0xbc
    RTC_BKP27R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0xc0
    RTC_BKP28R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0xc4
    RTC_BKP29R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0xc8
    RTC_BKP30R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
    /// RTC backup registers
    /// offset: 0xcc
    RTC_BKP31R: mmio.Mmio(packed struct(u32) {
        /// The application can write or read data to and from these registers. They are powered-on by VBAT when VDD is switched off, so that they are not reset by System reset, and their contents remain valid when the device operates in low-power mode. This register is reset on a tamper detection event, as long as TAMPxF=1. or when the Flash readout protection is disabled.
        BKP: u32,
    }),
};
