const std = @import("std");

const microzig = @import("microzig");
const hal = @import("hal.zig");
const stm32 = hal;
const rcc = stm32.rcc;

pub const SystemConfig = struct {
    pub const SysFreq = enum {
        default,
        boost,
    };

    use_dcache: bool = true,
    use_icache: bool = true,
    skip_clocks: bool = false,
    freq: SysFreq = .default,
};

// __STATIC_INLINE void __NVIC_SetPriority(IRQn_Type IRQn, uint32_t priority)
// {
//   if ((int32_t)(IRQn) >= 0)
//   {
//     NVIC->IP[((uint32_t)IRQn)]                = (uint8_t)((priority << (8U - __NVIC_PRIO_BITS)) & (uint32_t)0xFFUL);
//   }
//   else
//   {
//     SCB->SHPR[(((uint32_t)IRQn) & 0xFUL)-4UL] = (uint8_t)((priority << (8U - __NVIC_PRIO_BITS)) & (uint32_t)0xFFUL);
//   }
// }

// __STATIC_INLINE void __NVIC_SetPriorityGrouping(uint32_t PriorityGroup)
// {
//   uint32_t reg_value;
//   uint32_t PriorityGroupTmp = (PriorityGroup & (uint32_t)0x07UL);             /* only values 0..7 are used          */
//
//   reg_value  =  SCB->AIRCR;                                                   /* read old register configuration    */
//   reg_value &= ~((uint32_t)(SCB_AIRCR_VECTKEY_Msk | SCB_AIRCR_PRIGROUP_Msk)); /* clear bits to change               */
//   reg_value  =  (reg_value                                   |
//                 ((uint32_t)0x5FAUL << SCB_AIRCR_VECTKEY_Pos) |
//                 (PriorityGroupTmp << SCB_AIRCR_PRIGROUP_Pos)  );              /* Insert write key and priority group */
//   SCB->AIRCR =  reg_value;
// }

const NVICPriorityGroup = enum(u32) {
    Group0 = 0x00000007,
    Group1 = 0x00000006,
    Group2 = 0x00000005,
    Group3 = 0x00000004,
    Group4 = 0x00000003,
};

pub fn isNVICPriorityGroup(group: NVICPriorityGroup) bool {
    return switch (group) {
        NVICPriorityGroup.Group0,
        NVICPriorityGroup.Group1,
        NVICPriorityGroup.Group2,
        NVICPriorityGroup.Group3,
        NVICPriorityGroup.Group4,
        => true,
        else => false,
    };
}

const SCB_AIRCR_VECTKEY_Pos: u32 = 16; //*!< SCB AIRCR: VECTKEY Position *
const SCB_AIRCR_VECTKEY_Msk: u32 = (0xFFFFUL << SCB_AIRCR_VECTKEY_Pos); //*!< SCB AIRCR: VECTKEY Mask */

const SCB_AIRCR_VECTKEYSTAT_Pos: u32 = 16; //*!< SCB AIRCR: VECTKEYSTAT Position */
const SCB_AIRCR_VECTKEYSTAT_Msk: u32 = (0xFFFFUL << SCB_AIRCR_VECTKEYSTAT_Pos); //*!< SCB AIRCR: VECTKEYSTAT Mask */

const SCB_AIRCR_ENDIANESS_Pos: u32 = 15; //*!< SCB AIRCR: ENDIANESS Position */
const SCB_AIRCR_ENDIANESS_Msk: u32 = (1 << SCB_AIRCR_ENDIANESS_Pos); //*!< SCB AIRCR: ENDIANESS Mask */

const SCB_AIRCR_PRIGROUP_Pos: u32 = 8; //*!< SCB AIRCR: PRIGROUP Position */
const SCB_AIRCR_PRIGROUP_Msk: u32 = (7 << SCB_AIRCR_PRIGROUP_Pos); //*!< SCB AIRCR: PRIGROUP Mask */

pub fn set_grouping_priority(priority_group: NVICPriorityGroup) void {
    const SCB = microzig.chip.peripherals.scb;
    const VECTKEY_Msk: u32 = 0xFFFF_0000;
    const VECTKEY_Pos: u32 = 16;
    const PRIGROUP_Msk: u32 = 0x0000_0700;
    const PRIGROUP_Pos: u32 = 8;

    const PriorityGroupTmp = priority_group & 0x07;
    // regs.DIER.raw &= ~(@as(u32, 0b1) << (@as(u5, channel) + 1)); //CCxIE bits
    var reg_value = SCB.AIRCR;
    reg_value &= ~(VECTKEY_Msk | PRIGROUP_Msk);
    reg_value |= (0x5FA << VECTKEY_Pos) | (PriorityGroupTmp << PRIGROUP_Pos);
    SCB.AIRCR.raw = reg_value;
}

pub fn hal_init() bool {
    var common_system_clock: u32 = undefined;

    //  Set Interrupt Group Priority */
    set_grouping_priority(.Group4);

    // /* Update the SystemCoreClock global variable */
    // common_system_clock = HAL_RCC_GetSysClockFreq() >> ((D1CorePrescTable[(RCC->D1CFGR & RCC_D1CFGR_D1CPRE)>> RCC_D1CFGR_D1CPRE_Pos]) & 0x1FU);
    //
    // // /* Update the SystemD2Clock global variable */
    // SystemD2Clock = (common_system_clock >> ((D1CorePrescTable[(RCC->D1CFGR & RCC_D1CFGR_HPRE)>> RCC_D1CFGR_HPRE_Pos]) & 0x1FU));
    //
    // SystemCoreClock = common_system_clock;

    // /* Use systick as time base source and configure 1ms tick (default clock after Reset is HSI) */
    if (HAL_InitTick(TICK_INT_PRIORITY) != HAL_OK) {
        return false;
    }

    //* Init the low level hardware */
    HAL_MspInit();

    //* Return function status */
    return true;
}
