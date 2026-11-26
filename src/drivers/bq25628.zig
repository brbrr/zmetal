//! The TI BQ25628 1-cell charger: its register words, status bytes and
//! ADC results as pure functions, and `Bq25628`, the driver built on them.
//! Std only and generic over the bus, so the host tests all of it, the
//! driver's register sequences against a fake chip.
//!
//! The driver changes control registers by read-modify-write of named
//! fields and leaves every other bit as found. The two exceptions write a
//! whole value: the six 16-bit words, each of which holds one field (the
//! four limit words ICHG, VREG, IINDPM and VINDPM, and IPRECHG and ITERM,
//! whose reserved bits are written 0, their power-on value), and REG0x27,
//! whose eight bits are all channel disables. A command bit that `configure`
//! finds set is not written back, so a read that catches one cannot repeat
//! its command: `configure` writes REG_RST and FORCE_INDET 0, and its first
//! write to REG0x16 writes WD_RST 0. The write that turns charging on
//! (`configure`'s step 4) writes WD_RST back as it reads it, which is 0
//! after that first write unless the chip has not yet cleared a kick;
//! `kickWatchdog` writes it 1.
//!
//! Every address, field and step is from TI SLUSEG4C (Rev. C), §8.6.2, as
//! collected in the v3 power research note ([POWER] §1.2-§1.11). A
//! BQ25622E driver is no reference for these: ICHG, IPRECHG and ITERM sit
//! at other bits there, and its I2C address is 0x6B.
//!
//! The 16-bit registers are little-endian: the low byte is at the even
//! address and goes first on the wire, and both bytes go in one transfer
//! (SLUSEG4C §8.6.1).

const std = @import("std");

/// The charger's 7-bit I2C address (SLUSEG4C §8.5.1).
pub const default_address: u7 = 0x6A;

/// The register addresses (SLUSEG4C Table 8-7) that this driver touches.
pub const reg = struct {
    /// 16-bit, ICHG in bits 10:5.
    pub const ichg: u8 = 0x02;
    /// 16-bit, VREG in bits 11:3.
    pub const vreg: u8 = 0x04;
    /// 16-bit, IINDPM in bits 11:4.
    pub const iindpm: u8 = 0x06;
    /// 16-bit, VINDPM in bits 13:5.
    pub const vindpm: u8 = 0x08;
    /// 16-bit, IPRECHG in bits 7:3; bits 15:8 reserved.
    pub const iprechg: u8 = 0x10;
    /// 16-bit, ITERM in bits 7:2; bits 15:8 reserved.
    pub const iterm: u8 = 0x12;
    pub const charge_control: u8 = 0x14;
    /// Charge_Timer_Control.
    pub const timer_control: u8 = 0x15;
    pub const control_0: u8 = 0x16;
    pub const control_1: u8 = 0x17;
    pub const control_2: u8 = 0x18;
    pub const control_3: u8 = 0x19;
    /// NTC_Control_0.
    pub const ntc_control_0: u8 = 0x1A;
    /// Charger_Status_0; Charger_Status_1 and FAULT_Status_0 follow at
    /// 0x1E and 0x1F.
    pub const status_0: u8 = 0x1D;
    /// Charger_Flag_0: the flags of REG0x1D's events, latched, cleared
    /// when read.
    pub const flag_0: u8 = 0x20;
    pub const adc_control: u8 = 0x26;
    /// ADC_Function_Disable_0: one bit per channel, 1 leaves it out.
    pub const adc_disable: u8 = 0x27;
    /// The first of eight 16-bit results: IBUS, IBAT, VBUS, VPMID, VBAT,
    /// VSYS, TS and TDIE, in that order.
    pub const ibus_adc: u8 = 0x28;
    pub const tdie_adc: u8 = 0x36;
    pub const part_info: u8 = 0x38;
};

/// Masks of the 8-bit register fields used here, by register
/// ([POWER] §1.4, §1.9, §1.10). Each note lists the fields of the
/// register that no function of the driver changes.
const bits = struct {
    /// The low bytes of the IPRECHG (REG0x10) and ITERM (REG0x12) words:
    /// the field. The word's other bits are reserved ([POWER] §1.3).
    const prechg_term = struct {
        const iprechg: u8 = 0b1111_1000; // bits 7:3
        const iterm: u8 = 0b1111_1100; // bits 7:2
    };
    /// REG0x14 Charge_Control. Not changed: Q1_FULLON, Q4_FULLON,
    /// ITRICKLE, TOPOFF_TMR, VRECHG.
    const charge_control = struct {
        /// [POWER] §1.4 EN_TERM row: 0x14.2, power-on 1.
        const en_term: u8 = 1 << 2;
        const vindpm_bat_track: u8 = 1 << 1;
    };
    /// REG0x15 Charge_Timer_Control. Not changed: DIS_STAT,
    /// EN_AUTO_INDET, EN_DCP_BIAS, TMR2X_EN, PRECHG_TMR.
    const timer_control = struct {
        /// [POWER] §1.13: bits 6:4 are EN_AUTO_INDET, FORCE_INDET,
        /// EN_DCP_BIAS (and §1.2's field order); power-on 0 (5Ch). A
        /// command; [POWER] does not say it clears itself. `configure`
        /// writes it 0.
        const force_indet: u8 = 1 << 5;
        /// [POWER] §1.4 EN_SAFETY_TMRS row: 0x15.2, power-on 1.
        const en_safety_tmrs: u8 = 1 << 2;
        /// [POWER] §1.4 CHG_TMR row: 0x15.0, 0 = 14.5 h (power-on), 1 = 28 h.
        const chg_tmr: u8 = 1 << 0;
    };
    /// REG0x16 Charger_Control_0. Not changed: EN_AUTO_IBATDIS (bit 7).
    const control_0 = struct {
        const force_ibatdis: u8 = 1 << 6;
        const en_chg: u8 = 1 << 5;
        const en_hiz: u8 = 1 << 4;
        const force_pmid_dis: u8 = 1 << 3;
        const wd_rst: u8 = 1 << 2;
        const watchdog: u8 = 0b11;
    };
    /// REG0x17 Charger_Control_1. Not changed: SET_CONV_FREQ,
    /// SET_CONV_STRN.
    const control_1 = struct {
        /// [POWER] §1.4 REG_RST row: 0x17.7, "1 = reset registers and
        /// timer; self-clears". `configure` writes it 0.
        const reg_rst: u8 = 1 << 7;
        /// [POWER] §1.4 TREG row: 0x17.6, 0 = 60 °C, 1 = 120 °C (power-on).
        const treg: u8 = 1 << 6;
        const vbus_ovp: u8 = 1 << 0;
    };
    /// REG0x18 Charger_Control_2. Not changed: PFM_OTG_DIS (bit 5).
    /// BATFET_DLY is changed only by `enterShipMode`.
    const control_2 = struct {
        const en_bypass_otg: u8 = 1 << 7;
        const en_otg: u8 = 1 << 6;
        const pfm_fwd_dis: u8 = 1 << 4;
        const batfet_ctrl_wvbus: u8 = 1 << 3;
        const batfet_dly: u8 = 1 << 2;
        const batfet_ctrl: u8 = 0b11;
        const batfet_ctrl_ship: u8 = 0b10;
    };
    /// REG0x19 Charger_Control_3. Not changed: IBAT_PK, VBAT_UVLO,
    /// VBAT_OTG_MIN, CHG_RATE.
    const control_3 = struct {
        const en_extilim: u8 = 1 << 2;
    };
    /// REG0x1A NTC_Control_0. Not changed: TS_TH_OTG_HOT, TS_TH_OTG_COLD,
    /// TS_ISET_WARM, TS_ISET_COOL.
    const ntc_control_0 = struct {
        /// [POWER] §1.4 TS_IGNORE row: 0x1A.7, 1 = ignore TS, power-on 0.
        const ts_ignore: u8 = 1 << 7;
    };
    /// REG0x26 ADC_Control. Not changed: ADC_AVG_INIT (bit 2).
    const adc_control = struct {
        const adc_en: u8 = 1 << 7;
        const adc_rate_one_shot: u8 = 1 << 6;
        const adc_sample: u8 = 0b11 << 4;
        const adc_sample_10bit: u8 = 0b10 << 4;
        const adc_avg: u8 = 1 << 3;
    };
    /// REG0x27 ADC_Function_Disable_0: 1 leaves a channel out.
    const adc_disable = struct {
        const ts: u8 = 1 << 2;
        const vpmid: u8 = 1 << 0;
    };
    /// REG0x20 Charger_Flag_0: the layout of REG0x1D.
    const flag_0 = status_0;
    /// REG0x1D Charger_Status_0 ([POWER] §1.10). REG0x20 has the same
    /// layout, with _FLAG for _STAT.
    const status_0 = struct {
        const adc_done: u8 = 1 << 6;
        const treg: u8 = 1 << 5;
        const vsys: u8 = 1 << 4;
        const iindpm: u8 = 1 << 3;
        const vindpm: u8 = 1 << 2;
        const safety_tmr: u8 = 1 << 1;
        const wd: u8 = 1 << 0;
    };
    /// REG0x1E Charger_Status_1.
    const status_1 = struct {
        const chg_stat_shift = 3; // CHG_STAT, bits 4:3
        const vbus_stat: u8 = 0b111;
    };
    /// REG0x1F FAULT_Status_0.
    const fault_status_0 = struct {
        const vbus_fault: u8 = 1 << 7;
        const bat_fault: u8 = 1 << 6;
        const sys_fault: u8 = 1 << 5;
        const otg_fault: u8 = 1 << 4;
        const tshut: u8 = 1 << 3;
        const ts_stat: u8 = 0b111;
    };
};

// Each returns the 16-bit register word; send it low byte first.
//
// The minimums below hold while Q4_FULLON (REG0x14 bit 6) is 0, its
// power-on value. With it set the chip's minimums are 80 mA for ICHG and
// IPRECHG and 60 mA for ITERM ([POWER] §1.3). This driver never sets
// Q4_FULLON, and does not clear it either: only a power-on reset or a
// ship-mode or shutdown exit does ([POWER] §1.6). Whether a smaller value
// written while it is set reads back as written is not known.

/// ICHG (REG0x02 bits 10:5): 40 mA steps, clamped to 40..2000 mA.
pub fn ichgWord(ma: u16) u16 {
    return limitWord(ma, 40, 40, 2000, 5, 6);
}

/// VREG (REG0x04 bits 11:3): 10 mV steps, clamped to 3500..4800 mV.
pub fn vregWord(mv: u16) u16 {
    return limitWord(mv, 10, 3500, 4800, 3, 9);
}

/// IINDPM (REG0x06 bits 11:4): 20 mA steps, clamped to 100..3200 mA.
pub fn iindpmWord(ma: u16) u16 {
    return limitWord(ma, 20, 100, 3200, 4, 8);
}

/// VINDPM (REG0x08 bits 13:5): 40 mV steps, clamped to 3800..16800 mV.
pub fn vindpmWord(mv: u16) u16 {
    return limitWord(mv, 40, 3800, 16800, 5, 9);
}

/// IPRECHG (REG0x10 bits 7:3): 10 mA steps, clamped to 10..310 mA
/// ([POWER] §1.3, Table 8-15). The high byte is reserved.
pub fn iprechgWord(ma: u16) u16 {
    return limitWord(ma, 10, 10, 310, 3, 5);
}

/// ITERM (REG0x12 bits 7:2): 5 mA steps, clamped to 5..310 mA ([POWER]
/// §1.3, Table 8-16). The 6-bit field could hold code 3Fh (315 mA), but
/// the datasheet's range ends at 3Eh and says nothing of 3Fh, so the
/// clamp stops at 310 mA. The high byte is reserved.
pub fn itermWord(ma: u16) u16 {
    return limitWord(ma, 5, 5, 310, 2, 6);
}

/// True when `read` and `written` agree in every bit of `mask`.
fn agreeUnder(mask: []const u8, read: []const u8, written: []const u8) bool {
    for (mask, read, written) |m, r, w| {
        if ((r ^ w) & m != 0) return false;
    }
    return true;
}

/// `value` clamped to `min..max`, as a count of `step`s rounded down, in
/// the `width`-bit field at bit `shift`. The checks below keep every count
/// inside its field, so the shift drops nothing and no other bit is set.
fn limitWord(value: u16, comptime step: u16, comptime min: u16, comptime max: u16, comptime shift: u4, comptime width: u5) u16 {
    comptime {
        std.debug.assert(min >= step and min <= max);
        std.debug.assert(max / step < 1 << width);
        std.debug.assert(@as(u8, shift) + width <= 16);
    }
    return (std.math.clamp(value, min, max) / step) << shift;
}

/// True when REG0x38 names a BQ25628: PN (bits 5:3) is 2. DEV_REV (bits
/// 2:0) is not checked; the datasheet's reset values for this register
/// contradict each other ([POWER] §1.11).
pub fn isBq25628(part_info: u8) bool {
    return (part_info >> 3) & 0b111 == 2;
}

/// CHG_STAT, REG0x1E bits 4:3.
pub const ChargeState = enum {
    /// Not charging, or charging terminated: the chip does not tell the
    /// two apart.
    not_charging,
    /// Trickle, pre-charge or fast charge (constant current).
    charging,
    /// Taper charge (constant voltage).
    taper,
    /// The top-off timer is running.
    top_off,
};

/// TS_STAT, REG0x1F bits 2:0 ([POWER] §1.10, Table 8-28): the battery
/// temperature zone the thermistor reports.
pub const ThermistorState = enum(u3) {
    normal = 0b000,
    /// COLD, OTG_COLD, or no bias rail for the thermistor.
    cold = 0b001,
    /// HOT or OTG_HOT.
    hot = 0b010,
    cool = 0b011,
    warm = 0b100,
    precool = 0b101,
    prewarm = 0b110,
    /// The TS bias reference failed.
    bias_fault = 0b111,
};

/// What REG0x1D..0x1F tell ([POWER] §1.10). Every field is a live state
/// bit, not a latched flag.
pub const Status = struct {
    /// VBUS_STAT != 000. That includes 111, boost OTG, which this driver
    /// never turns on. The chip has no separate power-good bit.
    vbus_present: bool,
    charge: ChargeState,
    /// IINDPM_STAT: the input current limit regulates, from IINDPM or the
    /// ILIM pin.
    input_current_limited: bool,
    /// VINDPM_STAT: the input voltage limit regulates.
    input_voltage_limited: bool,
    /// TREG_STAT: the die is held at its regulation temperature.
    thermal_regulation: bool,
    /// WD_STAT: the watchdog expired and the chip is in default mode, as
    /// it is after power-on until the first register write.
    watchdog_expired: bool,
    /// SAFETY_TMR_STAT.
    safety_timer_expired: bool,
    /// VBUS_FAULT_STAT: VBUS over-voltage, or the sleep comparator; the
    /// converter does not switch.
    vbus_fault: bool,
    /// BAT_FAULT_STAT: battery over-current or over-voltage.
    battery_fault: bool,
    /// SYS_FAULT_STAT: SYS short or over-voltage.
    system_fault: bool,
    /// TSHUT_STAT.
    thermal_shutdown: bool,
    /// VSYS_STAT: the battery is below VSYSMIN and the chip regulates the
    /// system voltage at VSYSMIN.
    minimum_system_voltage: bool,
    /// OTG_FAULT_STAT: with an adapter, IBUS over-current or PMID
    /// over-voltage; in boost OTG (which this driver never turns on), a
    /// reverse-current, under- or over-voltage fault.
    otg_fault: bool,
    /// TS_STAT: why charging may be reduced or stopped by temperature.
    thermistor: ThermistorState,
};

pub fn decodeStatus(regs_1d_to_1f: [3]u8) Status {
    const s0 = regs_1d_to_1f[0];
    const s1 = regs_1d_to_1f[1];
    const fault = regs_1d_to_1f[2];
    return .{
        .vbus_present = s1 & bits.status_1.vbus_stat != 0,
        .charge = switch (@as(u2, @truncate(s1 >> bits.status_1.chg_stat_shift))) {
            0b00 => .not_charging,
            0b01 => .charging,
            0b10 => .taper,
            0b11 => .top_off,
        },
        .input_current_limited = s0 & bits.status_0.iindpm != 0,
        .input_voltage_limited = s0 & bits.status_0.vindpm != 0,
        .thermal_regulation = s0 & bits.status_0.treg != 0,
        .watchdog_expired = s0 & bits.status_0.wd != 0,
        .safety_timer_expired = s0 & bits.status_0.safety_tmr != 0,
        .vbus_fault = fault & bits.fault_status_0.vbus_fault != 0,
        .battery_fault = fault & bits.fault_status_0.bat_fault != 0,
        .system_fault = fault & bits.fault_status_0.sys_fault != 0,
        .thermal_shutdown = fault & bits.fault_status_0.tshut != 0,
        .minimum_system_voltage = s0 & bits.status_0.vsys != 0,
        .otg_fault = fault & bits.fault_status_0.otg_fault != 0,
        .thermistor = @fromBackingInt(@as(u3, @truncate(fault & bits.fault_status_0.ts_stat))),
    };
}

/// One conversion's results ([POWER] §1.9). The TS and VPMID channels are
/// not decoded.
pub const Measurement = struct {
    /// Input current, VBUS to PMID, in 2 mA steps.
    ibus_ma: i16,
    /// Battery current, positive while charging, in 4 mA steps. null: the
    /// conversion was aborted (word 0x8000, whatever the reserved bits 1:0
    /// hold) because the current changed direction. It reads 0 while
    /// EN_CHG is 0.
    ibat_ma: ?i16,
    vbus_mv: u16,
    vbat_mv: u16,
    vsys_mv: u16,
    /// The die temperature, 0.5 °C per unit.
    die_half_degrees_c: i16,
};

/// `adc` = REG0x28..0x37 as read from the chip (16 bytes, little-endian words).
pub fn decodeMeasurement(adc: [16]u8) Measurement {
    const ibus = adcWord(&adc, 0); // REG0x28
    const ibat = adcWord(&adc, 2); // REG0x2A
    const vbus = adcWord(&adc, 4); // REG0x2C
    const vbat = adcWord(&adc, 8); // REG0x30
    const vsys = adcWord(&adc, 10); // REG0x32
    const tdie = adcWord(&adc, reg.tdie_adc - reg.ibus_adc); // REG0x36
    return .{
        // Bits 15:1, two's complement, 2 mA: the word is the current in
        // mA once the reserved bit 0 is cleared.
        .ibus_ma = @bitCast(ibus & 0xFFFE),
        // Bits 15:2, two's complement, 4 mA: likewise with bits 1:0. The
        // abort code 0x8000 is recognised with those bits cleared as well.
        .ibat_ma = if (ibat & 0xFFFC == 0x8000) null else @as(i16, @bitCast(ibat & 0xFFFC)),
        // Bits 14:2, 3.97 mV.
        .vbus_mv = hundredths((vbus >> 2) & 0x1FFF, 397),
        // Bits 12:1, 1.99 mV.
        .vbat_mv = hundredths((vbat >> 1) & 0x0FFF, 199),
        .vsys_mv = hundredths((vsys >> 1) & 0x0FFF, 199),
        // Bits 11:0, two's complement in 12 bits, so bit 11 is the sign.
        .die_half_degrees_c = @as(i12, @bitCast(@as(u12, @truncate(tdie)))),
    };
}

fn adcWord(adc: *const [16]u8, comptime offset: usize) u16 {
    return std.mem.readInt(u16, adc[offset..][0..2], .little);
}

/// `code` times `per_100 / 100`, rounded down. The product needs more than
/// 16 bits (8191 * 397 = 3,251,827); the result fits (at most 32518).
fn hundredths(code: u16, comptime per_100: u32) u16 {
    return @intCast(@as(u32, code) * per_100 / 100);
}

pub const Error = error{
    /// REG0x38 names another part.
    WrongPart,
    /// A register reads back other than as written.
    VerifyFailed,
};

/// WATCHDOG, REG0x16 bits 1:0.
pub const Watchdog = enum(u2) { disabled = 0, s50 = 1, s100 = 2, s200 = 3 };

/// VBUS_OVP, REG0x17 bit 0: the VBUS over-voltage threshold, 0 = 6.3 V,
/// 1 = 18.5 V (power-on) ([POWER] §1.4, Table 8-20).
pub const VbusOvp = enum { v6_3, v18_5 };

/// BATFET_DLY, REG0x18 bit 2: the delay before a BATFET_CTRL action, 0 =
/// 25 ms, 1 = 12.5 s (power-on) ([POWER] §1.4, Table 8-21).
pub const ShipModeDelay = enum { ms25, s12_5 };

/// TREG, REG0x17 bit 6: 0 = 60 °C, 1 = 120 °C, its power-on value
/// ([POWER] §1.4, Table 8-20).
pub const ThermalRegulation = enum { c60, c120 };

/// CHG_TMR, REG0x15 bit 0: the fast-charge safety timer, 0 = 14.5 h (its
/// power-on value), 1 = 28 h ([POWER] §1.4, Table 8-18). [POWER] §1.8
/// gives 10.5 h as the least for 14.5 h, and no least for 28 h.
pub const FastChargeTimer = enum { h14_5, h28 };

/// What `configure` writes. The defaults are the chip's power-on
/// behaviour, so a caller states only what it changes, plus the four
/// fields that have none: the charge current, the two input limits, and
/// the charge voltage, which is left without one because it is the value
/// that can overcharge a cell.
///
/// Not here, because `configure` always turns them on, whatever it finds:
/// charge termination (EN_TERM), the safety timers (EN_SAFETY_TMRS) and
/// the battery temperature sensor (TS_IGNORE = 0), all three their
/// power-on values. Charging without them takes a change to this driver.
pub const Config = struct {
    /// ICHG: 40 mA steps rounded down, clamped to 40..2000 mA.
    charge_current_ma: u16,
    /// VREG: 10 mV steps rounded down, clamped to 3500..4800 mV. The
    /// chip's power-on value is 4200 mV ([POWER] §1.3).
    charge_voltage_mv: u16,
    /// IINDPM: 20 mA steps rounded down, clamped to 100..3200 mA. The chip
    /// puts it back to 3200 mA when the adapter is removed.
    input_current_ma: u16,
    /// VINDPM: 40 mV steps rounded down, clamped to 3800..16800 mV.
    input_voltage_mv: u16,
    /// Power-on behaviour is true: the effective limit is max(input_voltage_mv, VBAT + 400 mV).
    input_voltage_tracks_battery: bool = true,
    /// The I2C watchdog. `configure` switches it off with its first write
    /// and writes this setting last, together with EN_CHG, once every
    /// limit is in place and verified: no expiry can come in the middle of
    /// `configure`, and a failed one leaves the watchdog off. With
    /// `.disabled` the settings stay until the chip goes back to its
    /// power-on values. With any other setting
    /// `configure` ends by restarting the period (as `kickWatchdog` does),
    /// and from then on the caller must call `kickWatchdog` within every
    /// period, or the chip halves ICHG and reverts several bits to their
    /// power-on values, among them EN_CHG, EN_HIZ, EN_EXTILIM (the ILIM
    /// pin back on) and ADC_EN ([POWER] §1.5). The period is not exact:
    /// the 200 s setting can expire after 136 s, so kick at no more than
    /// half the period.
    watchdog: Watchdog = .s50,
    /// The ILIM pin also limits the input current (the lower limit wins).
    use_ilim_pin: bool = true,
    /// Pulse-frequency mode at light load; off keeps the converter at a fixed frequency.
    light_load_pfm: bool = true,
    /// The VBUS over-voltage threshold: 6.3 V or 18.5 V.
    vbus_ovp: VbusOvp = .v18_5,
    /// The BATFET actions (ship mode, system reset, the QON long press) also work with an adapter present.
    batfet_actions_with_vbus: bool = false,
    /// TREG: the die temperature the chip holds by reducing the charge
    /// current ([POWER] §1.4).
    thermal_regulation: ThermalRegulation = .c120,
    /// CHG_TMR: how long a fast charge may run before the chip stops it.
    /// `status().safety_timer_expired` reports that stop; how the chip
    /// clears it is not in [POWER], and this driver cannot restart such a
    /// charge.
    fast_charge_timer: FastChargeTimer = .h14_5,
    /// ITERM: 5 mA steps rounded down, clamped to 5..310 mA; power-on
    /// 20 mA ([POWER] §1.3).
    termination_current_ma: u16 = 20,
    /// IPRECHG: 10 mA steps rounded down, clamped to 10..310 mA; power-on
    /// 30 mA ([POWER] §1.3).
    precharge_current_ma: u16 = 30,
};

/// The driver, generic over `Bus`: a type, or a pointer to one, that has
///
/// - `pub const Error`, an error set;
/// - `write(self, address: u7, bytes: []const u8) Error!void`: one write
///   transfer of `bytes`, START to STOP;
/// - `writeThenRead(self, address: u7, tx: []const u8, rx: []u8) Error!void`:
///   a write of `tx`, a repeated START, and a read that fills `rx`.
///
/// Run the charger's bus at 100 kHz, with at least 90 µs between any two
/// STARTs on it, repeated STARTs and those after a NACK included. With
/// zmetal's HAL: `.speed = .I2C_100KHZ, .min_start_gap_us = 90`. This
/// driver adds no delays. The charger asks for the 90 µs gap at every
/// speed, and at 400 kHz also for a bus-free time and a repeated-START
/// set-up time (tSU:STA) of 68 µs or more ([POWER] §1.1, SLUSEG4C §8.5.1).
/// Every read here is a register pointer, a repeated START and the data
/// (`writeThenRead`), and the HAL cannot lengthen tSU:STA: its start gap
/// holds SCL low, while tSU:STA is counted with SCL high ([POWER] §3 row
/// 24). At 100 kHz only the 90 µs rule applies.
pub fn Bq25628(comptime Bus: type) type {
    const BusType = switch (@typeInfo(Bus)) {
        .pointer => |p| p.child,
        else => Bus,
    };
    if (!@hasDecl(BusType, "Error") or @typeInfo(BusType.Error) != .error_set)
        @compileError(@typeName(Bus) ++ " has no `pub const Error` error set");

    return struct {
        const Self = @This();

        /// The errors of a transfer on `Bus`.
        pub const BusError = BusType.Error;

        bus: Bus,
        address: u7,

        /// Reads the part number; writes nothing.
        pub fn init(bus: Bus, address: u7) (BusError || Error)!Self {
            const self: Self = .{ .bus = bus, .address = address };
            if (!isBq25628(try self.readByte(reg.part_info))) return error.WrongPart;
            return self;
        }

        /// Writes `cfg`, in this order:
        ///
        /// 1. REG0x16: the watchdog off (WATCHDOG = 00). The chip starts
        ///    its watchdog on the first register write, and one may be
        ///    running already, so this goes first: no expiry can come in
        ///    the middle of `configure`, and none can turn charging on
        ///    before the limits are in place. In the same write: neither
        ///    forced discharge, WD_RST = 0. EN_CHG and EN_HIZ stay as
        ///    found, so a chip that was not charging does not start on the
        ///    limits left in it.
        /// 2. The charge voltage (VREG word), then the charge current
        ///    (ICHG), then the rest: the IINDPM, VINDPM, IPRECHG and ITERM
        ///    words; REG0x14 VINDPM_BAT_TRACK, with EN_TERM = 1; REG0x15
        ///    CHG_TMR, with EN_SAFETY_TMRS = 1 and FORCE_INDET = 0; REG0x17
        ///    TREG and VBUS_OVP, with REG_RST = 0; REG0x18 PFM_FWD_DIS and
        ///    BATFET_CTRL_WVBUS, with both OTG modes off and BATFET_CTRL =
        ///    00, which withdraws a ship-mode request still pending
        ///    ([POWER] §1.7); REG0x19 EN_EXTILIM; REG0x1A TS_IGNORE = 0.
        ///    Termination, the safety timers and the temperature sensor go
        ///    back to their power-on values only on a watchdog expiry or a
        ///    reset ([POWER] §1.4, §1.5), so one left off by other firmware
        ///    would stay off with the watchdog disabled.
        /// 3. The read-back: every register written so far is read back,
        ///    and `error.VerifyFailed` if a compared bit differs from what
        ///    was written. Compared: the four limit words (ICHG, VREG,
        ///    IINDPM, VINDPM) whole, the IPRECHG and ITERM fields, and in
        ///    each control register the bits named in steps 1 and 2. Not
        ///    compared: WD_RST, REG_RST and FORCE_INDET, command bits
        ///    written 0; EN_CHG and EN_HIZ, left as found (an adapter
        ///    plug-in clears EN_HIZ); the reserved bits of the IPRECHG and
        ///    ITERM words; and every other bit `configure` does not write,
        ///    of most of which [POWER] does not say whether they can
        ///    change by themselves.
        /// 4. REG0x16, in one write: charging on (EN_CHG = 1), HIZ off and
        ///    WATCHDOG from `cfg`; those three read back. Both wait for
        ///    step 3, so neither charging nor a watchdog that could turn
        ///    it on runs while VREG or ICHG may hold other values; one
        ///    write leaves no state between the two.
        /// 5. With a watchdog set: WD_RST = 1, the write `kickWatchdog`
        ///    does. In host mode only that write is known to restart the
        ///    watchdog ([POWER] §1.5); whether switching it off and on
        ///    again in steps 1 and 4 does is not known, so without this a
        ///    period could expire soon after `configure` returns. A full
        ///    period starts here, and the
        ///    caller must call `kickWatchdog` within it and every one
        ///    after. With `.disabled` nothing more is written.
        ///
        /// Each 8-bit register is read, the bits named here are changed,
        /// and it is written back; no other bit changes, BATFET_DLY
        /// included.
        ///
        /// An error stops `configure` where it happens, and the chip keeps
        /// what was written before it:
        ///
        /// - in step 1: nothing (a watchdog found running still runs), or
        ///   REG0x16 as step 1 writes it, the watchdog off;
        /// - in steps 2 and 3 (`VerifyFailed` included): REG0x16 as step 1
        ///   writes it and the leading part of step 2, with the watchdog
        ///   off and charging as found. A chip that was not charging is
        ///   still not charging, and no watchdog expiry can turn it on; one
        ///   that was (as from power-on) charges on the limits it had,
        ///   with VREG already the configured one once ICHG changes;
        /// - in step 4: the same, or charging on and the watchdog as
        ///   configured, with every setting written and verified;
        /// - in step 5: everything configured, the watchdog period not
        ///   restarted, so an expiry may come early: it halves ICHG and
        ///   puts the bits of [POWER] §1.5 back to their power-on values.
        ///
        /// A failed `configure` therefore leaves the watchdog off from
        /// step 1 until step 4: call `configure` again rather than rely on
        /// it.
        pub fn configure(self: Self, cfg: Config) (BusError || Error)!void {
            // Each `*_owned` mask is what step 2 writes in a control
            // register and what the read-back compares there.
            const c0 = bits.control_0;
            // WATCHDOG = 00 (off), no forced discharge, and WD_RST = 0,
            // which is a command bit and not compared.
            const control_0_owned = c0.force_ibatdis | c0.force_pmid_dis | c0.watchdog;
            const control_0 = try self.update(reg.control_0, control_0_owned | c0.wd_rst, 0);

            const words = [4]u16{
                ichgWord(cfg.charge_current_ma),
                vregWord(cfg.charge_voltage_mv),
                iindpmWord(cfg.input_current_ma),
                vindpmWord(cfg.input_voltage_mv),
            };
            try self.writeWord(reg.vreg, words[1]);
            try self.writeWord(reg.ichg, words[0]);
            try self.writeWord(reg.iindpm, words[2]);
            try self.writeWord(reg.vindpm, words[3]);
            const prechg_term = [2]u16{ iprechgWord(cfg.precharge_current_ma), itermWord(cfg.termination_current_ma) };
            try self.writeWord(reg.iprechg, prechg_term[0]);
            try self.writeWord(reg.iterm, prechg_term[1]);

            const cc = bits.charge_control;
            const charge_control_owned = cc.en_term | cc.vindpm_bat_track;
            const charge_control = try self.update(
                reg.charge_control,
                charge_control_owned,
                cc.en_term | (if (cfg.input_voltage_tracks_battery) cc.vindpm_bat_track else 0),
            );
            const tc = bits.timer_control;
            const timer_control_owned = tc.en_safety_tmrs | tc.chg_tmr;
            // FORCE_INDET = 0, a command bit, not compared.
            const timer_control = try self.update(reg.timer_control, timer_control_owned | tc.force_indet, tc.en_safety_tmrs | switch (cfg.fast_charge_timer) {
                .h14_5 => 0,
                .h28 => tc.chg_tmr,
            });
            const c1 = bits.control_1;
            const control_1_owned = c1.treg | c1.vbus_ovp;
            // REG_RST = 0, a command bit, not compared.
            const control_1 = try self.update(reg.control_1, control_1_owned | c1.reg_rst, (switch (cfg.thermal_regulation) {
                .c60 => 0,
                .c120 => c1.treg,
            }) | (switch (cfg.vbus_ovp) {
                .v6_3 => 0,
                .v18_5 => c1.vbus_ovp,
            }));
            const c2 = bits.control_2;
            const control_2_owned = c2.en_bypass_otg | c2.en_otg | c2.pfm_fwd_dis | c2.batfet_ctrl_wvbus | c2.batfet_ctrl;
            const control_2 = try self.update(
                reg.control_2,
                control_2_owned,
                (if (cfg.light_load_pfm) 0 else c2.pfm_fwd_dis) |
                    (if (cfg.batfet_actions_with_vbus) c2.batfet_ctrl_wvbus else 0),
            );
            const control_3_owned = bits.control_3.en_extilim;
            const control_3 = try self.update(reg.control_3, control_3_owned, if (cfg.use_ilim_pin) control_3_owned else 0);
            const ntc_control_0_owned = bits.ntc_control_0.ts_ignore;
            const ntc_control_0 = try self.update(reg.ntc_control_0, ntc_control_0_owned, 0);

            // The read-back, in two bursts: REG0x02..0x09, the four limit
            // words compared whole; and REG0x10..0x1A, the IPRECHG and
            // ITERM fields and the owned bits of the control registers.
            var limits_written: [8]u8 = undefined;
            for (words, 0..) |w, i| std.mem.writeInt(u16, limits_written[2 * i ..][0..2], w, .little);
            var limits_read: [8]u8 = undefined;
            try self.readBytes(reg.ichg, &limits_read);
            if (!std.mem.eql(u8, &limits_read, &limits_written)) return error.VerifyFailed;

            var rest_written: [11]u8 = undefined;
            for (prechg_term, 0..) |w, i| std.mem.writeInt(u16, rest_written[2 * i ..][0..2], w, .little);
            rest_written[4..].* = .{ charge_control, timer_control, control_0, control_1, control_2, control_3, ntc_control_0 };
            const rest_owned = [11]u8{
                bits.prechg_term.iprechg, 0, bits.prechg_term.iterm, 0,
                charge_control_owned,     timer_control_owned,
                control_0_owned,          control_1_owned,
                control_2_owned,          control_3_owned,
                ntc_control_0_owned,
            };
            var rest_read: [11]u8 = undefined;
            try self.readBytes(reg.iprechg, &rest_read);
            if (!agreeUnder(&rest_owned, &rest_read, &rest_written)) return error.VerifyFailed;

            // Only now, with every limit in place and verified: charging
            // and the watchdog on together, in one write.
            const control_0_on = c0.en_chg | c0.en_hiz | c0.watchdog;
            const charging = try self.update(reg.control_0, control_0_on, c0.en_chg | @as(u8, @backingInt(cfg.watchdog)));
            if ((try self.readByte(reg.control_0) ^ charging) & control_0_on != 0) return error.VerifyFailed;

            // In host mode only a WD_RST write is known to restart the
            // watchdog; switching it off and on may not.
            if (cfg.watchdog != .disabled) try self.kickWatchdog();
        }

        /// IINDPM alone, as `Config.input_current_ma`.
        pub fn setInputCurrentLimit(self: Self, ma: u16) BusError!void {
            try self.writeWord(reg.iindpm, iindpmWord(ma));
        }

        /// EN_EXTILIM alone, as `Config.use_ilim_pin`.
        ///
        /// Mind the order with `false`: it leaves IINDPM as the only input
        /// limit, and the chip puts IINDPM back to 3.2 A whenever the
        /// adapter is removed ([POWER] §1.3, Table 8-11). So on each
        /// attach set the input limit first (`setInputCurrentLimit`), then
        /// call `useIlimPin(false)`; the other order leaves the adapter
        /// with a 3.2 A limit in between.
        pub fn useIlimPin(self: Self, enable: bool) BusError!void {
            const ilim = bits.control_3.en_extilim;
            _ = try self.update(reg.control_3, ilim, if (enable) ilim else 0);
        }

        /// The live status of REG0x1D..0x1F. Reading them clears nothing.
        pub fn status(self: Self) BusError!Status {
            var regs: [3]u8 = undefined;
            try self.readBytes(reg.status_0, &regs);
            return decodeStatus(regs);
        }

        /// The WATCHDOG setting now in the chip, REG0x16 bits 1:0. Its
        /// own expiry does not change it, and its power-on value is
        /// `.s50`. So a board that keeps the watchdog disabled can tell
        /// from any other value that the chip went back to its power-on
        /// registers (ship-mode exit, power-on reset) and must be
        /// configured again, the pattern PowerFeather's driver uses
        /// ([POWER] §4.1 "Patterns worth copying", 3).
        pub fn watchdog(self: Self) BusError!Watchdog {
            const control_0 = try self.readByte(reg.control_0);
            return @fromBackingInt(@as(u2, @truncate(control_0 & bits.control_0.watchdog)));
        }

        /// Restarts the watchdog: WD_RST (REG0x16 bit 2) = 1, the other
        /// bits as read; the chip clears WD_RST itself. Needed within the
        /// period for any setting but `.disabled`.
        pub fn kickWatchdog(self: Self) BusError!void {
            const wd_rst = bits.control_0.wd_rst;
            _ = try self.update(reg.control_0, wd_rst, wd_rst);
        }

        /// Starts one conversion of IBUS, IBAT, VBUS, VBAT, VSYS and TDIE:
        /// one-shot, 10-bit (7.5 ms per channel), no averaging. Returns
        /// false when the chip refused to start the ADC, which it does
        /// while neither VBUS nor VBAT is valid ([POWER] §1.9): ADC_EN
        /// then reads back 0. A conversion takes far longer than that
        /// read-back, so a 0 there is a refusal, not a finished conversion.
        ///
        /// It first reads REG0x20, which clears its flags, so a "done"
        /// flag left by an earlier conversion is gone. It leaves out the
        /// TS and VPMID channels: with TS on, the ADC does not run on
        /// battery below 3.2 V.
        pub fn startMeasurement(self: Self) BusError!bool {
            _ = try self.readByte(reg.flag_0);
            // A whole byte: each of the eight bits is one channel's disable.
            try self.writeByte(reg.adc_disable, bits.adc_disable.ts | bits.adc_disable.vpmid);
            const a = bits.adc_control;
            _ = try self.update(
                reg.adc_control,
                a.adc_en | a.adc_rate_one_shot | a.adc_sample | a.adc_avg,
                a.adc_en | a.adc_rate_one_shot | a.adc_sample_10bit,
            );
            return try self.readByte(reg.adc_control) & a.adc_en != 0;
        }

        /// The result of the conversion started last, once: null until
        /// ADC_DONE_FLAG (REG0x20 bit 6) is set. Reading REG0x20 clears
        /// the flag, so the next call returns null again. Six channels
        /// take about 45 ms; the caller decides how long to poll.
        ///
        /// Reading REG0x20 also clears the chip's other event flags in
        /// that register, which this driver does not use. After a bus
        /// error on the results the flag is gone as well: start another
        /// conversion.
        pub fn readMeasurement(self: Self) BusError!?Measurement {
            if (try self.readByte(reg.flag_0) & bits.flag_0.adc_done == 0) return null;
            var adc: [16]u8 = undefined;
            try self.readBytes(reg.ibus_adc, &adc);
            return decodeMeasurement(adc);
        }

        /// Before the board powers itself off: the ILIM pin on
        /// (EN_EXTILIM = 1) and the ADC off (ADC_EN = 0). IINDPM goes back
        /// to 3.2 A when the adapter is removed, while a cleared
        /// EN_EXTILIM survives a soft power-off, so without the pin the
        /// next adapter would see only the 3.2 A limit. The ADC draws
        /// about 260 µA from the battery while it runs.
        pub fn prepareForPowerOff(self: Self) BusError!void {
            const ilim = bits.control_3.en_extilim;
            _ = try self.update(reg.control_3, ilim, ilim);
            _ = try self.update(reg.adc_control, bits.adc_control.adc_en, 0);
        }

        /// Requests ship mode: one read-modify-write of REG0x18 with
        /// BATFET_DLY from `delay` and BATFET_CTRL = 10;
        /// BATFET_CTRL_WVBUS stays as configured.
        ///
        /// On battery the BATFET opens after the delay, the board loses
        /// power and the chip stops answering on I2C. With an adapter
        /// present the request waits for the adapter to be removed, and
        /// if `batfet_actions_with_vbus` is set the BATFET already opens
        /// after the delay, so the board runs from USB with the cell
        /// disconnected until then. The chip leaves ship mode on USB
        /// plug-in or a QON press of 0.93 s or more, with every register
        /// back at its power-on value ([POWER] §1.7).
        ///
        /// The function cannot tell whether ship mode was reached: a
        /// caller that is still running some time later may write
        /// BATFET_CTRL = 00 through `configure` to cancel.
        pub fn enterShipMode(self: Self, delay: ShipModeDelay) BusError!void {
            const c2 = bits.control_2;
            _ = try self.update(reg.control_2, c2.batfet_dly | c2.batfet_ctrl, c2.batfet_ctrl_ship | switch (delay) {
                .ms25 => 0,
                .s12_5 => c2.batfet_dly,
            });
        }

        fn readBytes(self: Self, register: u8, out: []u8) BusError!void {
            const tx = [1]u8{register};
            try self.bus.writeThenRead(self.address, &tx, out);
        }

        fn readByte(self: Self, register: u8) BusError!u8 {
            var b: [1]u8 = undefined;
            try self.readBytes(register, &b);
            return b[0];
        }

        fn writeByte(self: Self, register: u8, value: u8) BusError!void {
            const tx = [2]u8{ register, value };
            try self.bus.write(self.address, &tx);
        }

        /// Both bytes in one transfer, low byte first (SLUSEG4C §8.6.1).
        fn writeWord(self: Self, register: u8, word: u16) BusError!void {
            const tx = [3]u8{ register, @truncate(word), @truncate(word >> 8) };
            try self.bus.write(self.address, &tx);
        }

        /// Reads `register`, replaces the bits in `mask` with `value`,
        /// writes the byte back and returns it.
        fn update(self: Self, register: u8, mask: u8, value: u8) BusError!u8 {
            std.debug.assert(value & ~mask == 0);
            const byte = (try self.readByte(register) & ~mask) | value;
            try self.writeByte(register, byte);
            return byte;
        }
    };
}

// ============================================================================

test "charge and input limits encode to the datasheet's words" {
    try std.testing.expectEqual(@as(u16, 0x0100), ichgWord(320)); // power-on value
    try std.testing.expectEqual(@as(u16, 0x04A0), ichgWord(1480));
    try std.testing.expectEqual(@as(u16, 0x04C0), ichgWord(1520));
    try std.testing.expectEqual(@as(u16, 0x02D0), iindpmWord(900));
    try std.testing.expectEqual(@as(u16, 0x0460), iindpmWord(1400));
    try std.testing.expectEqual(@as(u16, 0x0780), iindpmWord(2400));
    try std.testing.expectEqual(@as(u16, 0x0A00), iindpmWord(3200)); // power-on value
    try std.testing.expectEqual(@as(u16, 0x0DC0), vindpmWord(4400));
    try std.testing.expectEqual(@as(u16, 0x0E60), vindpmWord(4600)); // power-on value
    try std.testing.expectEqual(@as(u16, 0x0D20), vregWord(4200)); // power-on value
    try std.testing.expectEqual(vregWord(4200), vregWord(4205));
    try std.testing.expectEqual(vregWord(3500), vregWord(0));
    try std.testing.expectEqual(vregWord(4800), vregWord(9000));
}
test "values between steps round down, values out of range clamp" {
    try std.testing.expectEqual(ichgWord(1480), ichgWord(1500));
    try std.testing.expectEqual(ichgWord(40), ichgWord(0));
    try std.testing.expectEqual(ichgWord(2000), ichgWord(5000));
    try std.testing.expectEqual(iindpmWord(100), iindpmWord(0));
    try std.testing.expectEqual(iindpmWord(3200), iindpmWord(60000));
    try std.testing.expectEqual(vindpmWord(3800), vindpmWord(0));
}
test "the limits' bounds are the datasheet's codes" {
    // [POWER] §1.3: word = (value / step) << shift; each range's codes.
    // ICHG, 40 mA << 5, codes 1h..32h.
    try std.testing.expectEqual(@as(u16, 0x0020), ichgWord(40)); // 1 << 5
    try std.testing.expectEqual(@as(u16, 0x0040), ichgWord(80)); // 2 << 5
    try std.testing.expectEqual(@as(u16, 0x0620), ichgWord(1960)); // 49 << 5 = 1568
    try std.testing.expectEqual(@as(u16, 0x0640), ichgWord(2000)); // 50 << 5 = 1600
    try std.testing.expectEqual(@as(u16, 0x0020), ichgWord(0));
    try std.testing.expectEqual(@as(u16, 0x0640), ichgWord(60000));
    // VREG, 10 mV << 3, codes 15Eh..1E0h.
    try std.testing.expectEqual(@as(u16, 0x0AF0), vregWord(3500)); // 350 = 0x15E; << 3 = 2800
    try std.testing.expectEqual(@as(u16, 0x0AF8), vregWord(3510)); // 351 << 3 = 2808
    try std.testing.expectEqual(@as(u16, 0x0EF8), vregWord(4790)); // 479 << 3 = 3832
    try std.testing.expectEqual(@as(u16, 0x0F00), vregWord(4800)); // 480 = 0x1E0; << 3 = 3840
    try std.testing.expectEqual(@as(u16, 0x0AF0), vregWord(0));
    try std.testing.expectEqual(@as(u16, 0x0F00), vregWord(60000));
    // IINDPM, 20 mA << 4, codes 5h..A0h.
    try std.testing.expectEqual(@as(u16, 0x0050), iindpmWord(100)); // 5 << 4
    try std.testing.expectEqual(@as(u16, 0x0060), iindpmWord(120)); // 6 << 4
    try std.testing.expectEqual(@as(u16, 0x09F0), iindpmWord(3180)); // 159 << 4 = 2544
    try std.testing.expectEqual(@as(u16, 0x0A00), iindpmWord(3200)); // 160 = 0xA0; << 4 = 2560
    try std.testing.expectEqual(@as(u16, 0x0050), iindpmWord(0));
    try std.testing.expectEqual(@as(u16, 0x0A00), iindpmWord(60000));
    // VINDPM, 40 mV << 5, codes 5Fh..1A4h.
    try std.testing.expectEqual(@as(u16, 0x0BE0), vindpmWord(3800)); // 95 = 0x5F; << 5 = 3040
    try std.testing.expectEqual(@as(u16, 0x0C00), vindpmWord(3840)); // 96 << 5 = 3072
    try std.testing.expectEqual(@as(u16, 0x3460), vindpmWord(16760)); // 419 << 5 = 13408
    try std.testing.expectEqual(@as(u16, 0x3480), vindpmWord(16800)); // 420 = 0x1A4; << 5 = 13440
    try std.testing.expectEqual(@as(u16, 0x0BE0), vindpmWord(0));
    try std.testing.expectEqual(@as(u16, 0x3480), vindpmWord(60000));
}
test "pre-charge and termination currents encode to the datasheet's words, clamped to its ranges" {
    // IPRECHG, REG0x10 bits 7:3, 10 mA per code, codes 1h..1Fh.
    try std.testing.expectEqual(@as(u16, 0x0008), iprechgWord(10)); // minimum: 1 << 3
    try std.testing.expectEqual(@as(u16, 0x0010), iprechgWord(20)); // one step in: 2 << 3
    try std.testing.expectEqual(@as(u16, 0x0018), iprechgWord(30)); // power-on: 3 << 3, the 0018h of the register heading
    try std.testing.expectEqual(@as(u16, 0x00F0), iprechgWord(300)); // one step in: 30 << 3 = 240
    try std.testing.expectEqual(@as(u16, 0x00F8), iprechgWord(310)); // maximum: 31 << 3 = 248
    try std.testing.expectEqual(@as(u16, 0x0008), iprechgWord(0));
    try std.testing.expectEqual(@as(u16, 0x0018), iprechgWord(39)); // rounds down
    try std.testing.expectEqual(@as(u16, 0x00F8), iprechgWord(60000));
    // ITERM, REG0x12 bits 7:2, 5 mA per code, codes 1h..3Eh.
    try std.testing.expectEqual(@as(u16, 0x0004), itermWord(5)); // minimum: 1 << 2
    try std.testing.expectEqual(@as(u16, 0x0008), itermWord(10)); // one step in: 2 << 2
    try std.testing.expectEqual(@as(u16, 0x0010), itermWord(20)); // power-on: 4 << 2, the 0010h of the register heading
    try std.testing.expectEqual(@as(u16, 0x00F4), itermWord(305)); // one step in: 61 << 2 = 244
    try std.testing.expectEqual(@as(u16, 0x00F8), itermWord(310)); // maximum: 62 << 2 = 248
    try std.testing.expectEqual(@as(u16, 0x0004), itermWord(0));
    try std.testing.expectEqual(@as(u16, 0x0010), itermWord(24)); // rounds down
    try std.testing.expectEqual(@as(u16, 0x00F8), itermWord(315)); // code 3Fh fits the field but is outside the range
    try std.testing.expectEqual(@as(u16, 0x00F8), itermWord(60000));
}
test "part number" {
    try std.testing.expect(isBq25628(0x12));
    try std.testing.expect(isBq25628(0x10));
    try std.testing.expect(!isBq25628(0x1A)); // PN 3 = BQ25622E
    try std.testing.expect(!isBq25628(0xFF));
    try std.testing.expect(!isBq25628(0x00));
}
test "status bytes" {
    const idle = decodeStatus(.{ 0x00, 0x00, 0x00 });
    try std.testing.expect(!idle.vbus_present);
    try std.testing.expectEqual(ChargeState.not_charging, idle.charge);
    const charging = decodeStatus(.{ 0x08, 0x0C, 0x00 }); // IINDPM active; CHG_STAT 01; VBUS_STAT 100
    try std.testing.expect(charging.vbus_present and charging.input_current_limited);
    try std.testing.expectEqual(ChargeState.charging, charging.charge);
    try std.testing.expectEqual(ChargeState.taper, decodeStatus(.{ 0x00, 0x14, 0x00 }).charge);
    try std.testing.expectEqual(ChargeState.top_off, decodeStatus(.{ 0x00, 0x1C, 0x00 }).charge);
    const bad = decodeStatus(.{ 0x25, 0x04, 0xC8 });
    try std.testing.expect(bad.thermal_regulation and bad.input_voltage_limited and bad.watchdog_expired);
    try std.testing.expect(bad.vbus_fault and bad.battery_fault and bad.thermal_shutdown and !bad.system_fault);
    try std.testing.expect(!bad.minimum_system_voltage and !bad.otg_fault);
    try std.testing.expectEqual(ThermistorState.normal, bad.thermistor);
}
test "status: the minimum system voltage, the OTG fault and the thermistor" {
    // REG0x1D bit 4 VSYS_STAT; REG0x1F bit 4 OTG_FAULT_STAT, bits 2:0
    // TS_STAT ([POWER] §1.10).
    const s = decodeStatus(.{ 0x10, 0x00, 0x13 }); // VSYS_STAT; OTG_FAULT_STAT, TS_STAT 011
    try std.testing.expect(s.minimum_system_voltage and s.otg_fault);
    try std.testing.expectEqual(ThermistorState.cool, s.thermistor);
    try std.testing.expect(!s.thermal_shutdown and !s.system_fault and !s.input_current_limited);
    // Every TS_STAT code, alone in REG0x1F.
    const states = [8]ThermistorState{ .normal, .cold, .hot, .cool, .warm, .precool, .prewarm, .bias_fault };
    for (states, 0..) |state, code| {
        const t = decodeStatus(.{ 0x00, 0x00, @intCast(code) });
        try std.testing.expectEqual(state, t.thermistor);
        try std.testing.expect(!t.otg_fault and !t.thermal_shutdown);
    }
    // The other bits of REG0x1F do not reach TS_STAT.
    try std.testing.expectEqual(ThermistorState.normal, decodeStatus(.{ 0xFF, 0xFF, 0xF8 }).thermistor);
}
test "ADC words" {
    var adc: [16]u8 = @splat(0);
    adc[0] = 0xA0;
    adc[1] = 0x0F; // IBUS 0x0FA0 -> 4000 mA
    adc[2] = 0xB4;
    adc[3] = 0xE2; // IBAT 0xE2B4 -> -7500 mA
    adc[4] = 0xAC;
    adc[5] = 0x13; // VBUS 0x13AC -> code 1259 -> 4998 mV
    adc[8] = 0x7E;
    adc[9] = 0x10; // VBAT 0x107E -> code 2111 -> 4200 mV
    adc[10] = 0x86;
    adc[11] = 0x0E; // VSYS 0x0E86 -> code 1859 -> 3699 mV
    adc[14] = 0xB0;
    adc[15] = 0x0F; // TDIE 0xFB0 -> -80 half degrees (-40 °C)
    const m = decodeMeasurement(adc);
    try std.testing.expectEqual(@as(i16, 4000), m.ibus_ma);
    try std.testing.expectEqual(@as(?i16, -7500), m.ibat_ma);
    try std.testing.expectEqual(@as(u16, 4998), m.vbus_mv);
    try std.testing.expectEqual(@as(u16, 4200), m.vbat_mv);
    try std.testing.expectEqual(@as(u16, 3699), m.vsys_mv);
    adc[0] = 0xA1; // IBUS with the reserved bit 0 set: still 4000 mA
    try std.testing.expectEqual(@as(i16, 4000), decodeMeasurement(adc).ibus_ma);
    try std.testing.expectEqual(@as(i16, -80), m.die_half_degrees_c);
    adc[2] = 0x00;
    adc[3] = 0x80; // IBAT 0x8000: aborted
    try std.testing.expectEqual(@as(?i16, null), decodeMeasurement(adc).ibat_ma);
    adc[2] = 0x01; // IBAT 0x8001: aborted, reserved bit 0 set
    try std.testing.expectEqual(@as(?i16, null), decodeMeasurement(adc).ibat_ma);
    adc[2] = 0x03; // IBAT 0x8003: aborted, both reserved bits set
    try std.testing.expectEqual(@as(?i16, null), decodeMeasurement(adc).ibat_ma);
    adc[14] = 0x18;
    adc[15] = 0x01; // TDIE 0x118 -> 280 half degrees (140 °C)
    try std.testing.expectEqual(@as(i16, 280), decodeMeasurement(adc).die_half_degrees_c);
}

/// The chip's registers 0x00..0x38 behind the `Bus` contract, with the
/// behaviours of the real chip that the driver depends on: reading REG0x20
/// clears it, a refused ADC start reads back with ADC_EN = 0, a 16-bit
/// register (REG0x02..0x09, REG0x10..0x13) is written only as both bytes
/// in one transfer from its low byte ([POWER] §1.1, §1.3), and (as
/// faults to inject) a register that ignores writes, bits that ignore
/// writes, and bits that clear themselves once written.
const FakeChip = struct {
    r: [0x39]u8 = @splat(0),
    /// The address the test expects every transfer to use.
    address: u7 = default_address,
    /// `write` calls; reads are not counted.
    writes: usize = 0,
    /// The register pointer of the first `write`.
    first_write_register: u8 = 0,
    /// Stores every write to REG0x26 with ADC_EN (bit 7) cleared, as the
    /// chip does while neither VBUS nor VBAT is valid.
    adc_refuses: bool = false,
    /// A register whose writes are ignored.
    stuck_register: ?u8 = null,
    /// Bits of one register that keep their value whatever is written.
    stuck_bits: ?Bits = null,
    /// Bits of one register that read 0 after any write, as a command bit
    /// that the chip clears once it has acted (FORCE_INDET, say) would.
    self_clearing: ?Bits = null,
    /// A register whose every written byte is kept in `watched`, as it
    /// came on the wire.
    watch: ?u8 = null,
    watched: [8]u8 = undefined,
    watched_len: usize = 0,

    const Bits = struct { register: u8, mask: u8 };

    pub const Error = error{ WrongAddress, NoRegister, SplitWord, WatchFull };

    /// `bytes[0]` is the register pointer; the rest is stored from there
    /// with auto-increment. A write that touches REG0x02..0x09 or
    /// REG0x10..0x13 must start at an even address and carry exactly two
    /// data bytes: one word.
    pub fn write(self: *FakeChip, address: u7, bytes: []const u8) FakeChip.Error!void {
        if (address != self.address) return error.WrongAddress;
        if (bytes.len < 1 or bytes[0] + bytes.len - 1 > self.r.len) return error.NoRegister;
        const data = bytes.len - 1;
        const first: usize = bytes[0];
        const last = first + data -| 1;
        const touches_words = data > 0 and
            ((first <= 0x09 and last >= 0x02) or (first <= 0x13 and last >= 0x10));
        if (touches_words and (first % 2 != 0 or data != 2)) return error.SplitWord;
        if (self.writes == 0) self.first_write_register = bytes[0];
        self.writes += 1;
        for (bytes[1..], @as(usize, bytes[0])..) |b, i| {
            if (self.watch) |w| {
                if (w == i) {
                    if (self.watched_len == self.watched.len) return error.WatchFull;
                    self.watched[self.watched_len] = b;
                    self.watched_len += 1;
                }
            }
            if (self.stuck_register) |stuck| if (stuck == i) continue;
            var v = if (i == reg.adc_control and self.adc_refuses) b & 0x7F else b;
            if (self.stuck_bits) |s| {
                if (s.register == i) v = (v & ~s.mask) | (self.r[i] & s.mask);
            }
            if (self.self_clearing) |s| {
                if (s.register == i) v &= ~s.mask;
            }
            self.r[i] = v;
        }
    }

    /// `tx[0]` is the register pointer; `rx` is filled from there with
    /// auto-increment.
    pub fn writeThenRead(self: *FakeChip, address: u7, tx: []const u8, rx: []u8) FakeChip.Error!void {
        if (address != self.address) return error.WrongAddress;
        if (tx.len != 1 or tx[0] + rx.len > self.r.len) return error.NoRegister;
        for (rx, @as(usize, tx[0])..) |*b, i| {
            b.* = self.r[i];
            if (i == reg.flag_0) self.r[i] = 0; // cleared when read
        }
    }
};

/// A chip at the power-on values of [POWER] §1.2. REG0x17 is the register
/// heading's 4Fh; [POWER] §1.12 notes that the field table sums to 4Dh.
fn porChip() FakeChip {
    var c: FakeChip = .{};
    c.r[0x02..0x0A].* = .{ 0x00, 0x01, 0x20, 0x0D, 0x00, 0x0A, 0x60, 0x0E };
    c.r[0x10..0x14].* = .{ 0x18, 0x00, 0x10, 0x00 };
    c.r[0x14..0x1B].* = .{ 0x06, 0x5C, 0xA1, 0x4F, 0x04, 0xC4, 0x3D };
    c.r[0x26] = 0x30;
    c.r[0x38] = 0x12;
    return c;
}

const board = Config{
    .charge_current_ma = 1480,
    .charge_voltage_mv = 4200,
    .input_current_ma = 900,
    .input_voltage_mv = 4400,
    .input_voltage_tracks_battery = false,
    .watchdog = .disabled,
    .use_ilim_pin = false,
    .light_load_pfm = false,
    .vbus_ovp = .v6_3,
    .batfet_actions_with_vbus = true,
};
/// Differs from `board` in every field, so that configuring a chip with one
/// after the other changes every bit `configure` owns.
const unlike_board = Config{
    .charge_current_ma = 1000,
    .charge_voltage_mv = 4350,
    .input_current_ma = 1400,
    .input_voltage_mv = 5000,
    .input_voltage_tracks_battery = true,
    .watchdog = .s100,
    .use_ilim_pin = true,
    .light_load_pfm = true,
    .vbus_ovp = .v18_5,
    .batfet_actions_with_vbus = false,
    .thermal_regulation = .c60,
    .fast_charge_timer = .h28,
    .termination_current_ma = 60,
    .precharge_current_ma = 80,
};
test "Config has no default charge voltage, so every caller states it" {
    const info = @typeInfo(Config).@"struct";
    var found = false;
    inline for (info.field_names, info.field_attrs) |name, attrs| {
        if (comptime std.mem.eql(u8, name, "charge_voltage_mv")) {
            try std.testing.expect(attrs.default_value_ptr == null);
            found = true;
        }
    }
    try std.testing.expect(found);
}
test "init accepts a BQ25628 and writes nothing" {
    var chip = porChip();
    _ = try Bq25628(*FakeChip).init(&chip, 0x6A);
    try std.testing.expectEqual(@as(usize, 0), chip.writes);
}
test "init rejects another part" {
    var chip = porChip();
    chip.r[0x38] = 0x1A; // BQ25622E
    try std.testing.expectError(error.WrongPart, Bq25628(*FakeChip).init(&chip, 0x6A));
    try std.testing.expectEqual(@as(usize, 0), chip.writes);
}
test "configure from power-on values" {
    var chip = porChip();
    const dev = try Bq25628(*FakeChip).init(&chip, 0x6A);
    try dev.configure(board);
    try std.testing.expectEqualSlices(u8, &.{ 0xA0, 0x04 }, chip.r[0x02..0x04]);
    try std.testing.expectEqualSlices(u8, &.{ 0x20, 0x0D }, chip.r[0x04..0x06]);
    try std.testing.expectEqualSlices(u8, &.{ 0xD0, 0x02 }, chip.r[0x06..0x08]);
    try std.testing.expectEqualSlices(u8, &.{ 0xC0, 0x0D }, chip.r[0x08..0x0A]);
    try std.testing.expectEqual(@as(u8, 0x04), chip.r[0x14]); // VINDPM_BAT_TRACK cleared, EN_TERM kept on
    try std.testing.expectEqual(@as(u8, 0x5C), chip.r[0x15]); // EN_SAFETY_TMRS kept on
    try std.testing.expectEqual(@as(u8, 0xA0), chip.r[0x16]); // WATCHDOG = 00, the rest kept
    try std.testing.expectEqual(@as(u8, 0x4E), chip.r[0x17]); // VBUS_OVP = 0, TREG kept at 120 °C
    try std.testing.expectEqual(@as(u8, 0x1C), chip.r[0x18]); // PFM_FWD_DIS, BATFET_CTRL_WVBUS set
    try std.testing.expectEqual(@as(u8, 0xC0), chip.r[0x19]); // EN_EXTILIM cleared
    try std.testing.expectEqual(@as(u8, 0x3D), chip.r[0x1A]); // TS_IGNORE kept off
}
test "configure reaches the same state from a chip left in a bad one" {
    var a = porChip();
    var b = porChip();
    b.r[0x02] = 0xC0;
    b.r[0x03] = 0x04; // ICHG 1520 mA
    b.r[0x04] = 0x98;
    b.r[0x05] = 0x0D; // VREG 4350 mV
    b.r[0x06] = 0x80;
    b.r[0x07] = 0x07; // IINDPM 2400 mA
    b.r[0x08] = 0x60;
    b.r[0x09] = 0x0E; // VINDPM 4600 mV
    b.r[0x10] = 0x50; // IPRECHG 100 mA
    b.r[0x12] = 0x50; // ITERM 100 mA
    b.r[0x14] = 0x02; // tracking on, termination off
    b.r[0x15] = 0x59; // safety timers off, fast-charge timer 28 h
    b.r[0x16] = 0xDF; // EN_CHG off, HIZ on, both forced discharges on, WD_RST set, watchdog 200 s
    b.r[0x17] = 0x0F; // VBUS_OVP 18.5 V, TREG 60 °C
    b.r[0x18] = 0xC6; // both OTG bits, BATFET_DLY 12.5 s, a ship-mode request pending
    b.r[0x19] = 0xC4; // ILIM pin on
    b.r[0x1A] = 0xBD; // TS ignored
    try (try Bq25628(*FakeChip).init(&a, 0x6A)).configure(board);
    try (try Bq25628(*FakeChip).init(&b, 0x6A)).configure(board);
    try std.testing.expectEqualSlices(u8, a.r[0x02..0x1B], b.r[0x02..0x1B]);
    try std.testing.expectEqual(@as(u8, 0xA0), b.r[0x16]);
    try std.testing.expectEqual(@as(u8, 0x1C), b.r[0x18]);
}
test "configure turns termination, the safety timers and the temperature sensor on, and the thermal limit to 120 °C, whatever it found" {
    var chip = porChip();
    chip.r[0x14] = 0x02; // EN_TERM (bit 2) off; power-on 0x06
    chip.r[0x15] = 0x58; // EN_SAFETY_TMRS (bit 2) off; power-on 0x5C
    chip.r[0x17] = 0x0F; // TREG (bit 6) 60 °C; power-on 0x4F
    chip.r[0x1A] = 0xBD; // TS_IGNORE (bit 7) on; power-on 0x3D
    try (try Bq25628(*FakeChip).init(&chip, 0x6A)).configure(board);
    try std.testing.expectEqual(@as(u8, 0x04), chip.r[0x14]); // 0x02 | 0x04 (EN_TERM), & ~0x02 (`board`: no tracking)
    try std.testing.expectEqual(@as(u8, 0x5C), chip.r[0x15]); // 0x58 | 0x04 (EN_SAFETY_TMRS)
    try std.testing.expectEqual(@as(u8, 0x4E), chip.r[0x17]); // 0x0F | 0x40 (TREG 120 °C), & ~0x01 (`board`: VBUS_OVP 6.3 V)
    try std.testing.expectEqual(@as(u8, 0x3D), chip.r[0x1A]); // 0xBD & ~0x80 (TS_IGNORE off)
}
test "configure writes the thermal limit from Config" {
    var chip = porChip();
    var cool = board;
    cool.thermal_regulation = .c60;
    try (try Bq25628(*FakeChip).init(&chip, 0x6A)).configure(cool);
    try std.testing.expectEqual(@as(u8, 0x0E), chip.r[0x17]); // 0x4F & ~0x40 (TREG 60 °C) & ~0x01 (VBUS_OVP 6.3 V)
}
test "configure leaves a field it does not own" {
    var chip = porChip();
    chip.r[0x18] = 0x00; // BATFET_DLY 25 ms
    try (try Bq25628(*FakeChip).init(&chip, 0x6A)).configure(board);
    try std.testing.expectEqual(@as(u8, 0x18), chip.r[0x18]);
}
test "the first write switches the watchdog off, and the configured one comes last, with charging" {
    var slow = board;
    slow.watchdog = .s200;
    // Stopped after `init`'s read and step 1's read and write of REG0x16.
    var stopped = porChip(); // REG0x16 0xA1: the 50 s watchdog of power-on
    var bus: FailingBus = .{ .chip = &stopped, .budget = 3 };
    try std.testing.expectError(error.Injected, (try Bq25628(*FailingBus).init(&bus, 0x6A)).configure(slow));
    try std.testing.expectEqual(@as(usize, 1), stopped.writes);
    try std.testing.expectEqual(@as(u8, 0x16), stopped.first_write_register);
    try std.testing.expectEqual(@as(u8, 0xA0), stopped.r[0x16]); // 0xA1 & ~0x03: WATCHDOG 00, EN_CHG as found
    // Run to the end: 0xA0, then EN_CHG | WATCHDOG 11 = 0xA3, then WD_RST
    // from the restart (the fake does not clear it).
    var chip = porChip();
    try (try Bq25628(*FakeChip).init(&chip, 0x6A)).configure(slow);
    try std.testing.expectEqual(@as(u8, 0xA7), chip.r[0x16]);
}
test "a register that does not take the value fails the verify" {
    var chip = porChip();
    chip.stuck_register = 0x18; // the fake ignores writes to it
    try std.testing.expectError(error.VerifyFailed, (try Bq25628(*FakeChip).init(&chip, 0x6A)).configure(board));
}
test "a measurement is returned once, and only for the conversion started last" {
    var chip = porChip();
    const dev = try Bq25628(*FakeChip).init(&chip, 0x6A);
    chip.r[0x20] = 0x40; // "done" left over from an earlier conversion
    chip.r[0x30] = 0x7E;
    chip.r[0x31] = 0x10; // and its VBAT, 4200 mV
    try std.testing.expect(try dev.startMeasurement());
    try std.testing.expectEqual(@as(u8, 0x05), chip.r[0x27]);
    try std.testing.expectEqual(@as(u8, 0xE0), chip.r[0x26] & 0xF8); // enable, one-shot, 10-bit, no averaging
    try std.testing.expectEqual(@as(?Measurement, null), try dev.readMeasurement()); // the stale flag was dropped
    chip.r[0x20] = 0x40; // this conversion finishes
    try std.testing.expectEqual(@as(u16, 4200), (try dev.readMeasurement()).?.vbat_mv);
    try std.testing.expectEqual(@as(?Measurement, null), try dev.readMeasurement()); // consumed
}
test "a refused ADC start is reported" {
    var chip = porChip();
    chip.adc_refuses = true;
    const dev = try Bq25628(*FakeChip).init(&chip, 0x6A);
    try std.testing.expect(!try dev.startMeasurement());
}
test "kicking the watchdog sets WD_RST and nothing else" {
    var chip = porChip();
    const dev = try Bq25628(*FakeChip).init(&chip, 0x6A);
    try dev.kickWatchdog();
    try std.testing.expectEqual(@as(u8, 0xA5), chip.r[0x16]);
}
test "power-off preparation, input limit, ship mode" {
    var chip = porChip();
    const dev = try Bq25628(*FakeChip).init(&chip, 0x6A);
    try dev.configure(board);
    chip.r[0x26] |= 0x80;
    try dev.prepareForPowerOff();
    try std.testing.expectEqual(@as(u8, 0xC4), chip.r[0x19]);
    try std.testing.expectEqual(@as(u8, 0), chip.r[0x26] & 0x80);
    try dev.setInputCurrentLimit(2400);
    try std.testing.expectEqualSlices(u8, &.{ 0x80, 0x07 }, chip.r[0x06..0x08]);
    try dev.useIlimPin(false);
    try std.testing.expectEqual(@as(u8, 0xC0), chip.r[0x19]);
    try dev.enterShipMode(.ms25);
    try std.testing.expectEqual(@as(u8, 0x1A), chip.r[0x18]); // BATFET_DLY 0, BATFET_CTRL 10, PFM and WVBUS kept
}
test "the watchdog setting tells a configured chip from one back at its power-on values" {
    var chip = porChip();
    const dev = try Bq25628(*FakeChip).init(&chip, 0x6A);
    try std.testing.expectEqual(Watchdog.s50, try dev.watchdog());
    try dev.configure(board);
    try std.testing.expectEqual(Watchdog.disabled, try dev.watchdog());
}
test "configure ends by restarting the watchdog period when a watchdog is set" {
    var chip = porChip();
    var with_watchdog = board;
    with_watchdog.watchdog = .s50;
    try (try Bq25628(*FakeChip).init(&chip, 0x6A)).configure(with_watchdog);
    // 0xA1 (WATCHDOG = 01, the rest as configured) with WD_RST set; the
    // fake does not clear WD_RST as the chip does.
    try std.testing.expectEqual(@as(u8, 0xA5), chip.r[0x16]);

    var off = porChip();
    try (try Bq25628(*FakeChip).init(&off, 0x6A)).configure(board);
    try std.testing.expectEqual(@as(u8, 0xA0), off.r[0x16]); // .disabled: nothing more written
}
test "a register that does not take its value fails the verify, at every address configure writes" {
    var target = porChip();
    try (try Bq25628(*FakeChip).init(&target, 0x6A)).configure(board);
    // Each address whose bits `configure` writes and compares, with those
    // bits: the whole byte of the four limit words, the IPRECHG and ITERM
    // fields, the owned fields of a control register. The reserved high
    // bytes REG0x11 and REG0x13 are written but not compared.
    const written = [_]struct { u8, u8 }{
        .{ 0x02, 0xFF }, .{ 0x03, 0xFF }, .{ 0x04, 0xFF }, .{ 0x05, 0xFF },
        .{ 0x06, 0xFF }, .{ 0x07, 0xFF }, .{ 0x08, 0xFF }, .{ 0x09, 0xFF },
        .{ 0x10, 0xF8 }, .{ 0x12, 0xFC }, .{ 0x14, 0x06 }, .{ 0x15, 0x05 },
        .{ 0x16, 0x7B }, .{ 0x17, 0x41 }, .{ 0x18, 0xDB }, .{ 0x19, 0x04 },
        .{ 0x1A, 0x80 },
    };
    for (written) |w| {
        var chip = porChip();
        chip.r[w[0]] = target.r[w[0]] ^ w[1]; // every bit `configure` sets is away from its target
        chip.stuck_register = w[0];
        try std.testing.expectError(error.VerifyFailed, (try Bq25628(*FakeChip).init(&chip, 0x6A)).configure(board));
    }
}
test "a FORCE_INDET set when configure reads REG0x15 and clear at the read-back does not fail it" {
    var chip = porChip();
    chip.r[0x15] |= 0x20; // FORCE_INDET, bit 5 ([POWER] §1.13: bits 6:4 are EN_AUTO_INDET, FORCE_INDET, EN_DCP_BIAS)
    chip.self_clearing = .{ .register = 0x15, .mask = 0x20 };
    try (try Bq25628(*FakeChip).init(&chip, 0x6A)).configure(board);
    try std.testing.expectEqual(@as(u8, 0x5C), chip.r[0x15]);
}
test "a command bit found set is written 0 in every write configure makes to its register, and nothing else in the byte changes" {
    // FORCE_INDET (REG0x15 bit 5) and REG_RST (REG0x17 bit 7), each left
    // set in a power-on chip and kept set (the fake does not act on
    // either). The bytes are those a power-on chip gets, derived from
    // its 0x5C and 0x4F:
    //   REG0x15, `board`: 0x5C | EN_SAFETY_TMRS 0x04 = 0x5C;
    //            `unlike_board`: 0x5C | CHG_TMR 0x01 = 0x5D.
    //   REG0x17, `board`: TREG 0x40 kept, VBUS_OVP 0x01 cleared = 0x4E;
    //            `unlike_board`: TREG cleared, VBUS_OVP kept = 0x0F.
    const cases = [_]struct { register: u8, command: u8, board: u8, unlike: u8 }{
        .{ .register = 0x15, .command = 0x20, .board = 0x5C, .unlike = 0x5D },
        .{ .register = 0x17, .command = 0x80, .board = 0x4E, .unlike = 0x0F },
    };
    for (cases) |c| {
        for ([_]Config{ board, unlike_board }, [_]u8{ c.board, c.unlike }) |cfg, expected| {
            errdefer std.debug.print("REG0x{X:0>2}\n", .{c.register});
            var chip = porChip();
            chip.r[c.register] |= c.command;
            chip.watch = c.register;
            try (try Bq25628(*FakeChip).init(&chip, 0x6A)).configure(cfg);
            try std.testing.expectEqualSlices(u8, &.{expected}, chip.watched[0..chip.watched_len]);
        }
    }
}
test "the read-back passes over any bit that changes by itself outside the bits configure owns" {
    // Per control register, the bits no read-back compares: the command
    // bits the chip clears itself (REG0x15 FORCE_INDET, REG0x16 WD_RST,
    // REG0x17 REG_RST), EN_HIZ (REG0x16 bit 4, which an adapter plug-in
    // clears; compared only once written 0), and every bit `configure`
    // does not own. Each is set when `configure` reads the register and
    // clear after any write to it.
    const free = [_]struct { u8, u8 }{
        .{ 0x14, 0xF9 }, .{ 0x15, 0xFA }, .{ 0x16, 0x94 }, .{ 0x17, 0xBE },
        .{ 0x18, 0x24 }, .{ 0x19, 0xFB }, .{ 0x1A, 0x7F },
    };
    for ([_]Config{ board, unlike_board }) |cfg| {
        for (free) |f| {
            for (0..8) |n| {
                const bit = @as(u8, 1) << @intCast(n);
                if (f[1] & bit == 0) continue;
                errdefer std.debug.print("REG0x{X:0>2} bit {d}\n", .{ f[0], n });
                var chip = porChip();
                chip.r[f[0]] |= bit;
                chip.self_clearing = .{ .register = f[0], .mask = bit };
                try (try Bq25628(*FakeChip).init(&chip, 0x6A)).configure(cfg);
            }
        }
    }
}
test "the read-back still fails on any bit configure owns that does not take its value" {
    // The bits the read-backs compare: the four limit words whole, the
    // IPRECHG and ITERM fields, the owned bits of each control register.
    const compared = [_]struct { u8, u8 }{
        .{ 0x02, 0xFF }, .{ 0x03, 0xFF }, .{ 0x04, 0xFF }, .{ 0x05, 0xFF },
        .{ 0x06, 0xFF }, .{ 0x07, 0xFF }, .{ 0x08, 0xFF }, .{ 0x09, 0xFF },
        .{ 0x10, 0xF8 }, .{ 0x12, 0xFC }, .{ 0x14, 0x06 }, .{ 0x15, 0x05 },
        .{ 0x16, 0x7B }, .{ 0x17, 0x41 }, .{ 0x18, 0xDB }, .{ 0x19, 0x04 },
        .{ 0x1A, 0x80 },
    };
    for ([_]Config{ board, unlike_board }) |cfg| {
        var target = porChip();
        try (try Bq25628(*FakeChip).init(&target, 0x6A)).configure(cfg);
        for (compared) |c| {
            for (0..8) |n| {
                const bit = @as(u8, 1) << @intCast(n);
                if (c[1] & bit == 0) continue;
                errdefer std.debug.print("REG0x{X:0>2} bit {d}\n", .{ c[0], n });
                var chip = porChip();
                chip.r[c[0]] = target.r[c[0]] ^ bit; // that bit away from its target, and kept there
                chip.stuck_bits = .{ .register = c[0], .mask = bit };
                try std.testing.expectError(error.VerifyFailed, (try Bq25628(*FakeChip).init(&chip, 0x6A)).configure(cfg));
            }
        }
    }
}
test "a reserved bit that reads 1 fails the read-back in the four limit words only" {
    // Reserved ([POWER] §1.3): IPRECHG word bits 2:0 and 15:8, ITERM word
    // bits 1:0 and 15:8.
    for ([_]struct { u8, u8 }{ .{ 0x10, 0x01 }, .{ 0x11, 0x80 }, .{ 0x12, 0x01 }, .{ 0x13, 0x01 } }) |c| {
        errdefer std.debug.print("REG0x{X:0>2} mask 0x{X:0>2}\n", .{ c[0], c[1] });
        var chip = porChip();
        chip.r[c[0]] |= c[1];
        chip.stuck_bits = .{ .register = c[0], .mask = c[1] };
        try (try Bq25628(*FakeChip).init(&chip, 0x6A)).configure(board);
    }
    // ICHG word bit 11, REG0x03 bit 3: reserved on the BQ25628 ([POWER]
    // §1.13), and compared with the rest of the word.
    var chip = porChip();
    chip.r[0x03] |= 0x08;
    chip.stuck_bits = .{ .register = 0x03, .mask = 0x08 };
    try std.testing.expectError(error.VerifyFailed, (try Bq25628(*FakeChip).init(&chip, 0x6A)).configure(board));
}
test "the defaults of Config are the chip's power-on behaviour" {
    const por = porChip();
    var chip = porChip();
    try (try Bq25628(*FakeChip).init(&chip, 0x6A)).configure(.{
        .charge_current_ma = 320,
        .charge_voltage_mv = 4200,
        .input_current_ma = 3200,
        .input_voltage_mv = 4600,
    });
    try std.testing.expectEqualSlices(u8, por.r[0x02..0x16], chip.r[0x02..0x16]);
    try std.testing.expectEqualSlices(u8, por.r[0x17..0x1B], chip.r[0x17..0x1B]);
    // 0xA1 with WD_RST set by the restart that ends `configure` (the
    // default watchdog is .s50); the fake does not clear WD_RST.
    try std.testing.expectEqual(@as(u8, 0xA5), chip.r[0x16]);
}
test "configure follows every field of Config" {
    var chip = porChip();
    const dev = try Bq25628(*FakeChip).init(&chip, 0x6A);
    try dev.configure(board); // 0x14 = 0x04, 0x15 = 0x5C, 0x16 = 0xA0, 0x17 = 0x4E, 0x18 = 0x1C, 0x19 = 0xC0, 0x1A = 0x3D
    try dev.configure(unlike_board);
    try std.testing.expectEqualSlices(u8, &.{ 0x20, 0x03 }, chip.r[0x02..0x04]); // 1000 / 40 = 25 = 0x19; 0x19 << 5 = 0x0320
    try std.testing.expectEqualSlices(u8, &.{ 0x98, 0x0D }, chip.r[0x04..0x06]); // 4350 / 10 = 435 = 0x1B3; 0x1B3 << 3 = 0x0D98
    try std.testing.expectEqualSlices(u8, &.{ 0x60, 0x04 }, chip.r[0x06..0x08]); // 1400 / 20 = 70 = 0x46; 0x46 << 4 = 0x0460
    try std.testing.expectEqualSlices(u8, &.{ 0xA0, 0x0F }, chip.r[0x08..0x0A]); // 5000 / 40 = 125 = 0x7D; 0x7D << 5 = 0x0FA0
    try std.testing.expectEqual(@as(u8, 0x06), chip.r[0x14]); // 0x04 | 0x02 (VINDPM_BAT_TRACK on)
    try std.testing.expectEqual(@as(u8, 0xA6), chip.r[0x16]); // (0xA0 & 0x80) | 0x20 (EN_CHG) | 0b10 (100 s) = 0xA2, then | 0x04 (WD_RST, the restart)
    try std.testing.expectEqual(@as(u8, 0x0F), chip.r[0x17]); // 0x4E & ~0x40 (TREG 60 °C) | 0x01 (VBUS_OVP 18.5 V)
    try std.testing.expectEqual(@as(u8, 0x04), chip.r[0x18]); // 0x1C & ~0xDB = 0x04: PFM_FWD_DIS and WVBUS cleared, BATFET_DLY kept
    try std.testing.expectEqual(@as(u8, 0xC4), chip.r[0x19]); // 0xC0 | 0x04 (EN_EXTILIM on)
    try std.testing.expectEqualSlices(u8, &.{ 0x40, 0x00 }, chip.r[0x10..0x12]); // IPRECHG: 80 / 10 = 8; 8 << 3 = 0x0040
    try std.testing.expectEqualSlices(u8, &.{ 0x30, 0x00 }, chip.r[0x12..0x14]); // ITERM: 60 / 5 = 12 = 0x0C; 0x0C << 2 = 0x0030
    try std.testing.expectEqual(@as(u8, 0x5D), chip.r[0x15]); // 0x5C | 0x01 (CHG_TMR 28 h)
}
test "configure writes the pre-charge and termination currents and the charge timer" {
    var chip = porChip();
    chip.r[0x10] = 0x50; // IPRECHG 100 mA: 10 << 3
    chip.r[0x12] = 0x50; // ITERM 100 mA: 20 << 2
    chip.r[0x15] = 0x5D; // CHG_TMR 28 h
    try (try Bq25628(*FakeChip).init(&chip, 0x6A)).configure(board); // the defaults: 30 mA, 20 mA, 14.5 h
    try std.testing.expectEqualSlices(u8, &.{ 0x18, 0x00, 0x10, 0x00 }, chip.r[0x10..0x14]); // 3 << 3 = 0x0018; 4 << 2 = 0x0010
    try std.testing.expectEqual(@as(u8, 0x5C), chip.r[0x15]); // 0x5D & ~0x01
}
test "configure ends in the same state from any state, and keeps every bit it does not own" {
    // The bits `configure` sets in each control register, the command
    // bits it writes 0 (FORCE_INDET, WD_RST, REG_RST) included.
    const owned = [_]struct { u8, u8 }{
        .{ 0x14, 0x06 }, .{ 0x15, 0x25 }, .{ 0x16, 0x7F }, .{ 0x17, 0xC1 },
        .{ 0x18, 0xDB }, .{ 0x19, 0x04 }, .{ 0x1A, 0x80 },
    };
    var prng = std.Random.DefaultPrng.init(1);
    const random = prng.random();
    for ([_]Config{ board, unlike_board }) |cfg| {
        var target = porChip();
        try (try Bq25628(*FakeChip).init(&target, 0x6A)).configure(cfg);
        for (0..1000) |_| {
            var chip = porChip();
            random.bytes(chip.r[0x02..0x0A]);
            random.bytes(chip.r[0x10..0x1B]);
            const before = chip.r;
            try (try Bq25628(*FakeChip).init(&chip, 0x6A)).configure(cfg);
            try std.testing.expectEqualSlices(u8, target.r[0x02..0x0A], chip.r[0x02..0x0A]);
            try std.testing.expectEqualSlices(u8, target.r[0x10..0x14], chip.r[0x10..0x14]);
            for (owned) |o| {
                try std.testing.expectEqual(target.r[o[0]] & o[1], chip.r[o[0]] & o[1]);
                try std.testing.expectEqual(before[o[0]] & ~o[1], chip.r[o[0]] & ~o[1]);
            }
            for (before, chip.r, 0..) |was, now, i| {
                const is_written = (i >= 0x02 and i < 0x0A) or (i >= 0x10 and i < 0x1B);
                if (!is_written) try std.testing.expectEqual(was, now);
            }
        }
    }
}
test "the over-voltage threshold and the ship-mode delay are named types" {
    try std.testing.expectEqual(VbusOvp, @FieldType(Config, "vbus_ovp"));
    var cfg = board;
    const ovp: VbusOvp = .v18_5;
    cfg.vbus_ovp = ovp;
    var chip = porChip();
    const dev = try Bq25628(*FakeChip).init(&chip, 0x6A);
    try dev.configure(cfg);
    try std.testing.expectEqual(@as(u8, 0x4F), chip.r[0x17]); // TREG 120 °C, VBUS_OVP 18.5 V
    const delay: ShipModeDelay = .s12_5;
    try dev.enterShipMode(delay);
    try std.testing.expectEqual(@as(u8, 0x1E), chip.r[0x18]); // 0x1C | 0x04 (BATFET_DLY) | 0x02 (ship): PFM_FWD_DIS, WVBUS kept
}
test "ship mode with the 12.5 s delay, and the ILIM pin back on" {
    var chip = porChip();
    chip.r[0x18] = 0x00; // BATFET_DLY 25 ms, so the 12.5 s setting has to be written
    const dev = try Bq25628(*FakeChip).init(&chip, 0x6A);
    try dev.configure(board); // 0x18 = 0x18, 0x19 = 0xC0
    try dev.enterShipMode(.s12_5);
    try std.testing.expectEqual(@as(u8, 0x1E), chip.r[0x18]); // (0x18 & ~0x07) | 0x04 (BATFET_DLY 12.5 s) | 0x02 (ship)
    try dev.useIlimPin(true);
    try std.testing.expectEqual(@as(u8, 0xC4), chip.r[0x19]); // 0xC0 | 0x04 (EN_EXTILIM)
}
/// `FakeChip` behind a bus that fails every transfer from the `budget`-th
/// on, reads and writes alike, counting from 0.
const FailingBus = struct {
    chip: *FakeChip,
    budget: usize,
    transfers: usize = 0,

    pub const Error = FakeChip.Error || error{Injected};

    pub fn write(self: *FailingBus, address: u7, bytes: []const u8) FailingBus.Error!void {
        try self.spend();
        try self.chip.write(address, bytes);
    }

    pub fn writeThenRead(self: *FailingBus, address: u7, tx: []const u8, rx: []u8) FailingBus.Error!void {
        try self.spend();
        try self.chip.writeThenRead(address, tx, rx);
    }

    fn spend(self: *FailingBus) error{Injected}!void {
        if (self.transfers == self.budget) return error.Injected;
        self.transfers += 1;
    }
};

test "a bus error anywhere in configure never leaves the watchdog running, or charging turned on, with a charge voltage or current other than the configured one" {
    var with_watchdog = board;
    with_watchdog.watchdog = .s50;
    // REG0x16 as found, each with EN_AUTO_IBATDIS (bit 7) as at power-on.
    const found_control_0 = [_]u8{
        0x80, // not charging, watchdog off
        0x81, // not charging, 50 s watchdog running
        0xA3, // charging, 200 s watchdog running
    };
    for ([_]Config{ board, with_watchdog }) |cfg| {
        for (found_control_0) |found| {
            // Transfer 0 is `init`'s read; the budget runs past the last
            // transfer, so the last pass is a `configure` that succeeds.
            var budget: usize = 0;
            while (budget < 100) : (budget += 1) {
                // Left by other firmware: VREG 4350 mV and ICHG 2000 mA,
                // both above `board`'s, and every protection off.
                var chip = porChip();
                chip.r[0x02..0x04].* = .{ 0x40, 0x06 }; // ICHG: 2000 / 40 = 50 = 0x32; 0x32 << 5 = 0x0640
                chip.r[0x04..0x06].* = .{ 0x98, 0x0D }; // VREG: 4350 / 10 = 435 = 0x1B3; 0x1B3 << 3 = 0x0D98
                chip.r[0x14] = 0x02; // EN_TERM off
                chip.r[0x15] = 0x58; // EN_SAFETY_TMRS off
                chip.r[0x16] = found;
                chip.r[0x17] = 0x0F; // TREG 60 °C
                chip.r[0x1A] = 0xBD; // TS_IGNORE on
                const before = chip.r;
                var bus: FailingBus = .{ .chip = &chip, .budget = budget };
                const done = if (Bq25628(*FailingBus).init(&bus, 0x6A)) |dev|
                    if (dev.configure(cfg)) true else |err| blk: {
                        try std.testing.expectEqual(error.Injected, err);
                        break :blk false;
                    }
                else |err| blk: {
                    try std.testing.expectEqual(error.Injected, err);
                    break :blk false;
                };
                // A failure at transfer N leaves the chip as it was after N
                // transfers, so every point of the sequence is seen here.
                // Before the first write the chip is as found, whatever it
                // runs; from then on it holds what `configure` wrote.
                if (chip.writes == 0) {
                    try std.testing.expectEqualSlices(u8, &before, &chip.r);
                } else {
                    const watchdog_running = chip.r[0x16] & 0x03 != 0; // WATCHDOG != 00
                    const charging_turned_on = chip.r[0x16] & 0x20 != 0 and found & 0x20 == 0; // EN_CHG
                    if (watchdog_running or charging_turned_on) {
                        try std.testing.expectEqualSlices(u8, &.{ 0xA0, 0x04 }, chip.r[0x02..0x04]); // ICHG 1480 mA: 37 = 0x25; 0x25 << 5 = 0x04A0
                        try std.testing.expectEqualSlices(u8, &.{ 0x20, 0x0D }, chip.r[0x04..0x06]); // VREG 4200 mV: 420 = 0x1A4; 0x1A4 << 3 = 0x0D20
                        try std.testing.expect(chip.r[0x14] & 0x04 != 0); // EN_TERM
                        try std.testing.expect(chip.r[0x15] & 0x04 != 0); // EN_SAFETY_TMRS
                        try std.testing.expect(chip.r[0x17] & 0x40 != 0); // TREG 120 °C
                        try std.testing.expect(chip.r[0x1A] & 0x80 == 0); // TS_IGNORE
                    }
                }
                if (done) {
                    try std.testing.expect(chip.r[0x16] & 0x30 == 0x20); // EN_CHG 1, EN_HIZ 0
                    try std.testing.expectEqual(@as(u8, @backingInt(cfg.watchdog)), chip.r[0x16] & 0x03);
                    break;
                }
            } else return error.TestUnexpectedResult; // `configure` never got through
        }
    }
}
/// A chip left by other firmware as in the failing-bus test above, with
/// REG0x16 `found`: VREG 4350 mV and ICHG 2000 mA, both above `board`'s,
/// and every protection off.
fn leftByOtherFirmware(found: u8) FakeChip {
    var chip = porChip();
    chip.r[0x02..0x04].* = .{ 0x40, 0x06 }; // ICHG: 2000 / 40 = 50 = 0x32; 0x32 << 5 = 0x0640
    chip.r[0x04..0x06].* = .{ 0x98, 0x0D }; // VREG: 4350 / 10 = 435 = 0x1B3; 0x1B3 << 3 = 0x0D98
    chip.r[0x14] = 0x02; // EN_TERM off
    chip.r[0x15] = 0x58; // EN_SAFETY_TMRS off
    chip.r[0x16] = found;
    chip.r[0x17] = 0x0F; // TREG 60 °C
    chip.r[0x1A] = 0xBD; // TS_IGNORE on
    return chip;
}

/// REG0x16 says the chip charges: EN_CHG (bit 5) = 1 and EN_HIZ (bit 4) =
/// 0. With EN_HIZ set the input is off, so EN_CHG alone charges nothing.
fn charges(control_0: u8) bool {
    return control_0 & 0x30 == 0x20;
}

/// `board`'s ICHG and VREG words as the chip holds them, low byte first:
/// 1480 mA / 40 = 37 = 0x25, 0x25 << 5 = 0x04A0; 4200 mV / 10 = 420 =
/// 0x1A4, 0x1A4 << 3 = 0x0D20.
const board_ichg = [2]u8{ 0xA0, 0x04 };
const board_vreg = [2]u8{ 0x20, 0x0D };

test "a bus error anywhere in configure, on a chip found in HIZ, never starts charging before the charge voltage and current are configured" {
    var with_watchdog = board;
    with_watchdog.watchdog = .s50;
    // REG0x16 as found: EN_AUTO_IBATDIS, EN_CHG and EN_HIZ (0x80 | 0x20 |
    // 0x10): charging enabled but the input off, so not charging; then the
    // same with the 50 s watchdog (WATCHDOG = 01) running.
    const found_control_0 = [_]u8{ 0xB0, 0xB1 };
    for ([_]Config{ board, with_watchdog }) |cfg| {
        for (found_control_0) |found| {
            var budget: usize = 0;
            while (budget < 100) : (budget += 1) {
                errdefer std.debug.print("found 0x{X:0>2}, budget {d}\n", .{ found, budget });
                var chip = leftByOtherFirmware(found);
                var bus: FailingBus = .{ .chip = &chip, .budget = budget };
                const done = if (Bq25628(*FailingBus).init(&bus, 0x6A)) |dev|
                    (if (dev.configure(cfg)) true else |_| false)
                else |_| false;
                if (chip.writes != 0) {
                    const charging_started = charges(chip.r[0x16]) and !charges(found);
                    const watchdog_running = chip.r[0x16] & 0x03 != 0;
                    if (charging_started or watchdog_running) {
                        try std.testing.expectEqualSlices(u8, &board_ichg, chip.r[0x02..0x04]);
                        try std.testing.expectEqualSlices(u8, &board_vreg, chip.r[0x04..0x06]);
                    }
                }
                if (done) {
                    try std.testing.expect(charges(chip.r[0x16]));
                    break;
                }
            } else return error.TestUnexpectedResult; // `configure` never got through
        }
    }
}

test "on a chip found charging, a bus error anywhere in configure never leaves the configured charge current with another charge voltage" {
    // REG0x16 as found: charging (0x80 | 0x20), without and with the 200 s
    // watchdog (WATCHDOG = 11). The chip charges on whatever limits it
    // holds, so VREG must be the configured one by the time ICHG is.
    for ([_]u8{ 0xA0, 0xA3 }) |found| {
        var budget: usize = 0;
        while (budget < 100) : (budget += 1) {
            errdefer std.debug.print("found 0x{X:0>2}, budget {d}\n", .{ found, budget });
            var chip = leftByOtherFirmware(found);
            var bus: FailingBus = .{ .chip = &chip, .budget = budget };
            const done = if (Bq25628(*FailingBus).init(&bus, 0x6A)) |dev|
                (if (dev.configure(board)) true else |_| false)
            else |_| false;
            if (std.mem.eql(u8, &board_ichg, chip.r[0x02..0x04])) {
                try std.testing.expectEqualSlices(u8, &board_vreg, chip.r[0x04..0x06]);
            }
            if (done) break;
        } else return error.TestUnexpectedResult;
    }
}

test "a read-back that fails leaves charging as found and the watchdog off" {
    // Bits that do not take what `configure` writes: a whole limit byte,
    // one bit of the IPRECHG field and one owned control bit. Each makes
    // step 3's read-back fail, before step 4 could turn charging on.
    const stuck = [_]FakeChip.Bits{
        .{ .register = 0x04, .mask = 0xFF }, // VREG's low byte stays 0x98, `board` writes 0x20
        .{ .register = 0x02, .mask = 0xFF }, // ICHG's low byte stays 0x40, `board` writes 0xA0
        .{ .register = 0x10, .mask = 0x08 }, // IPRECHG bit 3 stays 0; 30 mA is 3 << 3 = 0x18
        .{ .register = 0x1A, .mask = 0x80 }, // TS_IGNORE stays 1; `configure` writes 0
    };
    var with_watchdog = board;
    with_watchdog.watchdog = .s50;
    for ([_]Config{ board, with_watchdog }) |cfg| {
        // Not charging, watchdog off; not charging, 50 s watchdog; in HIZ.
        for ([_]u8{ 0x80, 0x81, 0xB0 }) |found| {
            for (stuck) |s| {
                errdefer std.debug.print("found 0x{X:0>2}, stuck 0x{X:0>2}/0x{X:0>2}\n", .{ found, s.register, s.mask });
                var chip = leftByOtherFirmware(found);
                chip.r[0x10] = 0x00; // so that the stuck IPRECHG bit differs from 0x18
                chip.stuck_bits = s;
                const dev = try Bq25628(*FakeChip).init(&chip, 0x6A);
                try std.testing.expectError(error.VerifyFailed, dev.configure(cfg));
                try std.testing.expectEqual(charges(found), charges(chip.r[0x16]));
                try std.testing.expectEqual(@as(u8, 0), chip.r[0x16] & 0x03); // WATCHDOG = 00
            }
        }
    }
}

test "the fake refuses a limit word written in halves, from its high byte, or with another" {
    var chip = porChip();
    try std.testing.expectError(error.SplitWord, chip.write(0x6A, &.{ 0x02, 0xA0 }));
    try std.testing.expectError(error.SplitWord, chip.write(0x6A, &.{ 0x03, 0x04 }));
    try std.testing.expectError(error.SplitWord, chip.write(0x6A, &.{ 0x03, 0x04, 0x20 }));
    try std.testing.expectError(error.SplitWord, chip.write(0x6A, &.{ 0x02, 0xA0, 0x04, 0x20, 0x0D }));
    try std.testing.expectError(error.SplitWord, chip.write(0x6A, &.{ 0x01, 0x00, 0xA0 }));
    try std.testing.expectError(error.SplitWord, chip.write(0x6A, &.{ 0x10, 0x18 }));
    try std.testing.expectError(error.SplitWord, chip.write(0x6A, &.{ 0x13, 0x00 }));
    try std.testing.expectError(error.SplitWord, chip.write(0x6A, &.{ 0x0F, 0x00, 0x18 }));
    try std.testing.expectError(error.SplitWord, chip.write(0x6A, &.{ 0x12, 0x10, 0x00, 0x06 }));
    try std.testing.expectEqual(@as(usize, 0), chip.writes);
    try chip.write(0x6A, &.{ 0x02, 0xA0, 0x04 });
    try std.testing.expectEqualSlices(u8, &.{ 0xA0, 0x04 }, chip.r[0x02..0x04]);
}
