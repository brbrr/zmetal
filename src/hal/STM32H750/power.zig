const std = @import("std");
const microzig = @import("microzig");

const hal = @import("hal.zig");

var pwr = microzig.chip.peripherals.PWR;
const PWR = microzig.chip.types.peripherals.pwr_h7rm0433;

const PWR_FLAG_SETTING_DELAY: u32 = 1000;

pub const VoltageScale = enum {
    Scale0, // 480MHz overdrive
    Scale1, // 400MHz
    Scale2,
    Scale3,
};

// pub inline fn set_voltage_scalling(scale: PWR.VOS) void {
//     pwr.D3CR.modify_one("VOS", scale);
//     _ = pwr.D3CR.read();
// }

const syscfg = microzig.chip.peripherals.SYSCFG;
// Note: microzig's PWR.VOS enum has no Scale0 — on the H7, VOS0 (480 MHz
// overdrive) is reached by selecting the highest VOS (Scale1) and enabling the
// SYSCFG overdrive bit. So this takes the local VoltageScale enum (which has
// Scale0) and maps the rest to PWR.VOS.
pub fn set_voltage_scalling(scale: VoltageScale) void {
    if (scale == .Scale0) {
        // First set the highest VOS, then enable overdrive
        pwr.D3CR.modify_one("VOS", .Scale1);
        // Read back for delay (register write synchronization)
        _ = pwr.D3CR.read().VOS;

        // Enable PWR overdrive via SYSCFG
        syscfg.PWRCR.modify_one("ODEN", 1);
        // Read back for delay
        _ = syscfg.PWRCR.read().ODEN;
    } else {
        // Disable overdrive first before scaling down
        syscfg.PWRCR.modify_one("ODEN", 0);
        _ = syscfg.PWRCR.read().ODEN;

        const vos: PWR.VOS = switch (scale) {
            .Scale0 => unreachable,
            .Scale1 => .Scale1,
            .Scale2 => .Scale2,
            .Scale3 => .Scale3,
        };
        pwr.D3CR.modify_one("VOS", vos);
        _ = pwr.D3CR.read().VOS;
    }
}

pub const PwrFlag = enum {
    PVDO, // PVD Output. Valid only if PVD is enabled by HAL_PWR_EnablePVD().
    AVDO, // AVD Output. Valid only if AVD is enabled by HAL_PWREx_EnableAVD().
    ACTVOSRDY, // Regulator voltage scaling output selection is ready.
    VOSRDY, // Regulator voltage scaling output selection is ready.
    SCUEN, // Supply configuration update is enabled.
    BRR, // Backup regulator ready flag. Not reset by STANDBY, system reset, or power-on reset.
    SB, // System entered STANDBY mode.
    STOP, // System entered STOP mode.
    SB_D1, // D1 domain entered STANDBY mode.
    SB_D2, // D2 domain entered STANDBY mode.
    USB33RDY, // USB supply from regulator is ready.
    TEMPH, // Temperature equal or above high threshold level.
    TEMPL, // Temperature equal or below low threshold level.
    VBATH, // VBAT level equal or above high threshold level.
    VBATL, // VBAT level equal or below low threshold level.
};

pub fn get_flag(flag: PwrFlag) bool {
    return switch (flag) {
        .PVDO => pwr.CSR1.read().PVDO == 1,
        .AVDO => pwr.CSR1.read().AVDO == 1,
        .ACTVOSRDY => pwr.CSR1.read().ACTVOSRDY == 1,
        .SCUEN => pwr.CR3.read().SCUEN == 1,
        .USB33RDY => pwr.CR3.read().USB33RDY == 1,
        .VOSRDY => pwr.D3CR.read().VOSRDY == 1,
        .SB => pwr.CPUCR.read().SBF == 1,
        .STOP => pwr.CPUCR.read().STOPF == 1,
        .SB_D1 => pwr.CPUCR.read().SBF_D1 == 1,
        .SB_D2 => pwr.CPUCR.read().SBF_D2 == 1,
        .BRR => pwr.CR2.read().BRRDY == 1,
        .TEMPH => pwr.CR2.read().TEMPH == 1,
        .TEMPL => pwr.CR2.read().TEMPL == 1,
        .VBATH => pwr.CR2.read().VBATH == 1,
        .VBATL => pwr.CR2.read().VBATL == 1,
    };
}

pub const PwrSupplyMode = union(enum) {
    LDO,
    ExtSource,
    pub fn get(self: PwrSupplyMode) [3]u1 {
        return switch (self) {
            .LDO => [_]u1{ 1, 0, 0 },
            .ExtSource => [_]u1{ 0, 1, 0 },
        };
    }
};

fn isSupplySourceMatch(mode: PwrSupplyMode) bool {
    const cr3 = pwr.CR3.read(); // Read register once
    const vals = mode.get();
    return cr3.LDOEN == vals[0] and cr3.BYPASS == vals[1] and cr3.SCUEN == vals[2];
    // return switch (mode) {
    //     else => |vals| ,
    //     // .LDO => cr3.LDOEN == 1 and cr3.BYPASS == 0 and cr3.SCUEN == 0,
    //     // .ExtSource =>  cr3.LDOEN == 0 and cr3.BYPASS == 1 and cr3.SCUEN == 0,
    // };
}

pub fn config_ext_power_supply(mode: PwrSupplyMode) bool {
    var tickstart: u32 = undefined;

    // Check if supply source was configured
    if (!get_flag(.SCUEN)) {
        // Check supply configuration
        if (!isSupplySourceMatch(mode)) {
            return false; //  Supply configuration update locked, can't apply a new supply config
        } else {
            // Supply configuration update locked, but new supply configuration matches with old supply configuration : nothing to do
            return true;
        }
    }

    const vals = mode.get();
    pwr.CR3.modify(.{
        .LDOEN = vals[0],
        .BYPASS = vals[1],
        .SCUEN = vals[2],
    });

    tickstart = hal.clock.get_tick();

    // Wait till voltage level flag is set
    while (!get_flag(.ACTVOSRDY)) {
        if ((hal.clock.get_tick() - tickstart) > PWR_FLAG_SETTING_DELAY) {
            return false;
        }
    }

    return true;
}

pub const PvdThreshold = enum(u3) {
    V2_2,
    V2_3,
    V2_4,
    V2_5,
    V2_6,
    V2_7,
    V2_8,
    V2_9,
};

pub const DeepsleepModes = enum(u1) {
    stop,
    standby,
};

pub const VoltRegulatorMode = enum(u1) {
    on,
    off,
};

pub const Events = packed struct(u2) {
    Standby: bool = false,
    Wakeup: bool = false,
};

pub const PowerConfig = struct {
    pvd_threshold: PvdThreshold = .V2_9,
    deepsleep_mode: DeepsleepModes = .stop, //define the deepsleep behavior
    volt_regulator_mode: VoltRegulatorMode = .on, //define the voltage regulator behavior , only used if `deepsleep_mode` is set to `stop`
    wakeup_pin: bool = false, //enable/disable the wakeup pin
};

pub inline fn apply(config: PowerConfig) void {
    _ = config;
    // pwr.CR.modify(.{
    //     .PLS = @intFromEnum(config.pvd_threshold),
    //     .PDDS = @as(PDDS, @enumFromInt(@intFromEnum(config.deepsleep_mode))),
    //     .LPDS = @intFromEnum(config.volt_regulator_mode),
    // });
    // pwr.CSR.modify(.{ .EWUP = @intFromBool(config.wakeup_pin) });
}

///enable/disable the power voltage detection peripheral.
pub inline fn set_pvd(set: bool) void {
    pwr.CR.modify(.{ .PVDE = @intFromBool(set) });
}

///get the current power detection status.
///0 = VDD/VDDA is higher than the threshold.
///1 = VDD/VDDA is lower than the threshold.
pub inline fn pvd_status() u1 {
    return pwr.CSR.read().PVDO;
}

///enable/disable the backup domain write protection.
///this is used to protect the RTC and backup registers.
///
///this function also exists in the `hal.backup` module.
pub inline fn backup_domain_protection(set: bool) void {
    pwr.CR.modify(.{ .DBP = @intFromBool(!set) });
}

pub inline fn get_events() Events {
    const csr = pwr.CSR.read();
    return Events{
        .Standby = csr.SBF != 0,
        .Wakeup = csr.WUF != 0,
    };
}

pub inline fn clear_events() void {
    pwr.CR.modify(.{ .CWUF = 1, .CSBF = 1 });
}
