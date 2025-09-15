// TODO:
// - test current code: play around with lower values of reload Reg
// - Test that val reg is incrementing correctly
// - test that COUNTFLAG is flipped at all

const std = @import("std");

const microzig = @import("microzig");
const cpu = microzig.cpu;
const chip = microzig.chip;

const chip_peri = chip.peripherals;
const RCC = chip_peri.RCC;

const daisy = @import("hal/STM32H750/daisy.zig");

pub const hal = @import("hal/STM32H750/hal.zig");
const stm32 = hal;
const errors = @import("hal/STM32H750/errors.zig");
pub const panic = errors.panic;

// INTERNAL_ADDRESS = 0x08000000
// FLASH_ADDRESS ?= $(INTERNAL_ADDRESS)
// dfu-util -a 0 -s 0x08000000:leave -D zig-out/firmware/blinky.bin -d ,0483:df11
// openocd -s /usr/local/share/openocd/scripts -f interface/stlink.cfg -f target/stm32h7x.cfg -c "program ./zig-out/firmware/blinky.elf verify reset exit"

const systick = cpu.peripherals.systick;
const scb = cpu.peripherals.scb;

pub const microzig_options: microzig.Options = .{
    .interrupts = .{
        .SysTick = .{ .c = sys_tick_handler },
        .HardFault = .{ .c = hw_handler },
        .NMI = .{ .c = nmi_handler },
        .MemManageFault = .{ .c = mem_manage_fault_handler },
        .BusFault = .{ .c = bus_fault_handler },
        .UsageFault = .{ .c = usage_fault_handler },
        .SVCall = .{ .c = sv_call_handler },
        .PendSV = .{ .c = hw_handler },
    },
};

fn hw_handler() callconv(.c) void {
    @breakpoint();
    @panic("HardFault");
}
fn nmi_handler() callconv(.c) void {
    @breakpoint();
    @panic("NMI");
}
fn mem_manage_fault_handler() callconv(.c) void {
    @breakpoint();
    @panic("MemManageFault");
}
fn bus_fault_handler() callconv(.c) void {
    @breakpoint();
    @panic("BusFault");
}
fn usage_fault_handler() callconv(.c) void {
    @breakpoint();
    @panic("UsageFault");
}
fn sv_call_handler() callconv(.c) void {
    @breakpoint();
    @panic("SVCall");
}

fn sys_tick_handler() callconv(.c) void {
    hal.clock.inc_tick();
    count += 1;
    if (count == 1_000) {
        //     led.toggle();
        // } else if (count == 1100) {
        //     led.toggle();
        // } else if (count == 1200) {
        //     led.toggle();
        // } else if (count == 1300) {
        //     led.toggle();
        count = 0;
    }
}

var count: u32 = 1;

pub fn init_vector_table() void {
    // SCB base address (System Control Block)
    // const SCB_CPACR: *volatile u32 = @ptrFromInt(0xE000ED88);
    // SCB_CPACR.* |= 0xF << 20;

    const fpu = microzig.chip.peripherals.FPU_CPACR;
    // Set CP10 and CP11 to full access
    fpu.CPACR.modify_one("CP", 0xF);

    // Data & Instruction Synchronization Barriers
    cpu.dmb();
    cpu.isb();

    // Reset RCC clock configuration to default state
    RCC.CR.modify_one("HSION", 0);
    RCC.CFGR.raw = 0x00000000;
    RCC.CR.raw &= 0xEAF6ED7F;
    RCC.D1CFGR.raw = 0x00000000;
    RCC.D2CFGR.raw = 0x00000000;
    RCC.D3CFGR.raw = 0x00000000;
    RCC.PLLCKSELR.raw = 0x00000000;
    RCC.PLLCFGR.raw = 0x00000000;
    RCC.PLL1DIVR.raw = 0x00000000;
    RCC.PLL1FRACR.raw = 0x00000000;
    RCC.PLL2DIVR.raw = 0x00000000;
    RCC.PLL2FRACR.raw = 0x00000000;
    RCC.PLL3DIVR.raw = 0x00000000;
    RCC.PLL3FRACR.raw = 0x00000000;
    RCC.CR.raw &= 0xFFFBFFFF;
    RCC.CIER.raw = 0x00000000;

    //* in case of initialized data in D2 SRAM (AHB SRAM) , enable the D2 SRAM clock ((AHB SRAM clock) */
    RCC.AHB2ENR.modify(.{
        .SRAM1EN = 1,
        .SRAM2EN = 1,
        .SRAM3EN = 1,
    });

    const tmpreg = RCC.AHB2ENR.read();
    _ = tmpreg;

    errors.delay(1000);

    // STM32H7 revY workaround
    // Change  the switch matrix read issuing capability to 1 for the AXI SRAM target (Target 7) */
    if ((chip_peri.DBGMCU.IDC.raw & 0xFFFF0000) < 0x20000000) {
        const mysctic_ptr: *volatile u32 = @ptrFromInt(0x51008108);
        mysctic_ptr.* = 0x00000001;
        // @ptrCast(*volatile u32, @intToPtr(0x51008108)).* = 0x00000001;
    }

    scb.VTOR = @intCast(@intFromPtr(&cpu.startup_logic._vector_table));
}

pub fn init() void {
    init_vector_table();
}

const led = hal.gpio.Pin.init("C", "7", .{});
const btn = hal.gpio.Pin.init("G", "9", .{
    .mode = .Input,
});
const tx = hal.gpio.Pin.init("B", "6", .{
    .mode = .{ .Alternate = .af7 },
    .otype = .PushPull,
    .speed = .VeryHighSpeed,
    .pull = .Floating,
});
const rx = hal.gpio.Pin.init("B", "7", .{
    .mode = .{ .Alternate = .af7 },
    .otype = .PushPull,
    .speed = .VeryHighSpeed,
    .pull = .PullUp,
});
const uart1 = hal.uart.Uart.init(.USART1, .{
    .baudrate = 115_200,
    // .baudrate = 9600,
});
pub fn main() !void {
    init_vector_table();

    // errors.delay(5_000_000);
    daisy.init() catch {
        errors.error_handler();
    };
    led.configure();
    btn.configure();
    led.toggle();

    tx.configure();
    rx.configure();

    uart1.configure();

    while (true) {
        cpu.wfi();
        if (btn.read() == .Low) {
            led.toggle();
        }

        const c = uart1.readByte();
        uart1.writeByte(c); // echo
        // uart1.writeByte('H');
        // uart1.writeByte('i');
    }
}
