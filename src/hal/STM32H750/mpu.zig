const std = @import("std");

const microzig = @import("microzig");
const peri = microzig.chip.peripherals;
const cpu_peri = microzig.cpu.peripherals;
const mpu = cpu_peri.mpu;

pub const IsEnabled = enum(u1) {
    Disabled = 0,
    Enabled = 1,
};

pub const AccessEnable = enum(u1) {
    Enable = 0,
    Disable = 1,
};

pub const MpuRegionSize = enum(u5) {
    Size32B = 0x04,
    Size64B = 0x05,
    Size128B = 0x06,
    Size256B = 0x07,
    Size512B = 0x08,
    Size1KB = 0x09,
    Size2KB = 0x0A,
    Size4KB = 0x0B,
    Size8KB = 0x0C,
    Size16KB = 0x0D,
    Size32KB = 0x0E,
    Size64KB = 0x0F,
    Size128KB = 0x10,
    Size256KB = 0x11,
    Size512KB = 0x12,
    Size1MB = 0x13,
    Size2MB = 0x14,
    Size4MB = 0x15,
    Size8MB = 0x16,
    Size16MB = 0x17,
    Size32MB = 0x18,
    Size64MB = 0x19,
    Size128MB = 0x1A,
    Size256MB = 0x1B,
    Size512MB = 0x1C,
    Size1GB = 0x1D,
    Size2GB = 0x1E,
    Size4GB = 0x1F,
};

pub const MpuRegionAccess = enum(u3) {
    NoAccess = 0x00,
    PrivRW = 0x01,
    PrivRW_URO = 0x02,
    FullAccess = 0x03,
    PrivRO = 0x05,
    PrivRO_URO = 0x06,
};

pub const MpuTexLevel = enum(u3) {
    Level0 = 0x00,
    Level1 = 0x01,
    Level2 = 0x02,
};

pub const MpuRegionNumber = enum(u8) {
    Number0 = 0x00,
    Number1 = 0x01,
    Number2 = 0x02,
    Number3 = 0x03,
    Number4 = 0x04,
    Number5 = 0x05,
    Number6 = 0x06,
    Number7 = 0x07,
    Number8 = 0x08,
    Number9 = 0x09,
    Number10 = 0x0A,
    Number11 = 0x0B,
    Number12 = 0x0C,
    Number13 = 0x0D,
    Number14 = 0x0E,
    Number15 = 0x0F,
    _,
};

pub const MPUControl = enum(u32) {
    None = 0x00000000,
    HardFaultNmi = 0x00000002,
    PrivilegedDefault = 0x00000004,
    HfnmiPrivDef = 0x00000006,
};

pub const MPU_Region_Config = struct {
    enable: IsEnabled,
    number: u8,

    BaseAddress: u32,
    Size: MpuRegionSize,
    SubRegionDisable: u8,
    TypeExtField: MpuTexLevel,
    AccessPermission: MpuRegionAccess,
    DisableExec: AccessEnable,
    Shareable: IsEnabled,
    cacheable: IsEnabled,
    bufferable: IsEnabled,
};

pub fn enable() void {
    // Enable the MPU
    set_MPU_control(.PrivilegedDefault);
    // Enable fault exceptions
    microzig.cpu.interrupt.exception.enable(.MemManageFault);
    // Ensure MPU setting take effects
    microzig.cpu.dsb();
    microzig.cpu.isb();
}

fn set_MPU_control(value: MPUControl) void {
    const bits = @intFromEnum(value);
    mpu.CTRL.modify(.{
        .ENABLE = @as(u1, @intCast((bits >> 0) & 1)),
        .HFNMIENA = @as(u1, @intCast((bits >> 1) & 1)),
        .PRIVDEFENA = @as(u1, @intCast((bits >> 2) & 1)),
    });
}

pub fn disable() void {
    // Make sure outstanding transfers are done
    microzig.cpu.dmb();
    // Disable fault exceptions */
    microzig.cpu.interrupt.exception.disable(.MemManageFault);
    // Disable the MPU and clear the control register
    cpu_peri.mpu.CTRL.raw = 0;
}

pub fn config_region(config: MPU_Region_Config) !void {
    mpu.RNR.modify_one("REGION", config.number);
    if (config.enable == .Enabled) {
        mpu.RBAR.raw = config.BaseAddress;
        mpu.RASR.modify(.{
            .XN = @as(u1, @intCast(@intFromEnum(config.DisableExec))),
            .AP = @as(u3, @intCast(@intFromEnum(config.AccessPermission))),
            .TEX = @as(u3, @intCast(@intFromEnum(config.TypeExtField))),
            .S = @as(u1, @intCast(@intFromEnum(config.Shareable))),
            .C = @as(u1, @intCast(@intFromEnum(config.cacheable))),
            .B = @as(u1, @intCast(@intFromEnum(config.bufferable))),
            .SRD = config.SubRegionDisable,
            .SIZE = @as(u5, @intCast(@intFromEnum(config.Size))),
            .ENABLE = @as(u1, @intCast(@intFromEnum(config.enable))),
        });
    } else {
        mpu.RBAR.raw = 0;
        mpu.RASR.raw = 0;
    }
}
