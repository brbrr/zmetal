//! STM32H750x
const microzig = @import("microzig");
const mmio = microzig.mmio;
pub const types = @import("types.zig");

pub const Interrupt = struct {
    name: [:0]const u8,
    index: i16,
    description: ?[:0]const u8,
};

pub const properties = struct {
    pub const @"cpu.endian" = "little";
    pub const @"cpu.fpuPresent" = "true";
    pub const @"cpu.mpuPresent" = "true";
    pub const @"cpu.name" = "CM7";
    pub const @"cpu.nvicPrioBits" = "4";
    pub const @"cpu.revision" = "r0p1";
    pub const @"cpu.vendorSystickConfig" = "false";
};

pub const interrupts: []const Interrupt = &.{
    .{ .name = "NMI", .index = -14, .description = null },
    .{ .name = "HardFault", .index = -13, .description = null },
    .{ .name = "MemManageFault", .index = -12, .description = null },
    .{ .name = "BusFault", .index = -11, .description = null },
    .{ .name = "UsageFault", .index = -10, .description = null },
    .{ .name = "SVCall", .index = -5, .description = null },
    .{ .name = "PendSV", .index = -2, .description = null },
    .{ .name = "SysTick", .index = -1, .description = null },
    .{ .name = "WWDG1", .index = 0, .description = "Window Watchdog interrupt" },
    .{ .name = "PVD_PVM", .index = 1, .description = "PVD through EXTI line" },
    .{ .name = "RTC_TAMP_STAMP_CSS_LSE", .index = 2, .description = "RTC tamper, timestamp" },
    .{ .name = "RTC_WKUP", .index = 3, .description = "RTC Wakeup interrupt" },
    .{ .name = "FLASH", .index = 4, .description = "Flash memory" },
    .{ .name = "RCC", .index = 5, .description = "RCC global interrupt" },
    .{ .name = "EXTI0", .index = 6, .description = "EXTI Line 0 interrupt" },
    .{ .name = "EXTI1", .index = 7, .description = "EXTI Line 1 interrupt" },
    .{ .name = "EXTI2", .index = 8, .description = "EXTI Line 2 interrupt" },
    .{ .name = "EXTI3", .index = 9, .description = "EXTI Line 3interrupt" },
    .{ .name = "EXTI4", .index = 10, .description = "EXTI Line 4interrupt" },
    .{ .name = "DMA1_STR0", .index = 11, .description = "DMA1 Stream0" },
    .{ .name = "DMA1_STR1", .index = 12, .description = "DMA1 Stream1" },
    .{ .name = "DMA1_STR2", .index = 13, .description = "DMA1 Stream2" },
    .{ .name = "DMA1_STR3", .index = 14, .description = "DMA1 Stream3" },
    .{ .name = "DMA1_STR4", .index = 15, .description = "DMA1 Stream4" },
    .{ .name = "DMA1_STR5", .index = 16, .description = "DMA1 Stream5" },
    .{ .name = "DMA1_STR6", .index = 17, .description = "DMA1 Stream6" },
    .{ .name = "ADC1_2", .index = 18, .description = "ADC1 and ADC2" },
    .{ .name = "FDCAN1_IT0", .index = 19, .description = "FDCAN1 Interrupt 0" },
    .{ .name = "FDCAN2_IT0", .index = 20, .description = "FDCAN2 Interrupt 0" },
    .{ .name = "FDCAN1_IT1", .index = 21, .description = "FDCAN1 Interrupt 1" },
    .{ .name = "FDCAN2_IT1", .index = 22, .description = "FDCAN2 Interrupt 1" },
    .{ .name = "EXTI9_5", .index = 23, .description = "EXTI Line[9:5] interrupts" },
    .{ .name = "TIM1_BRK", .index = 24, .description = "TIM1 break interrupt" },
    .{ .name = "TIM1_UP", .index = 25, .description = "TIM1 update interrupt" },
    .{ .name = "TIM1_TRG_COM", .index = 26, .description = "TIM1 trigger and commutation" },
    .{ .name = "TIM_CC", .index = 27, .description = "TIM1 capture / compare" },
    .{ .name = "TIM2", .index = 28, .description = "TIM2 global interrupt" },
    .{ .name = "TIM3", .index = 29, .description = "TIM3 global interrupt" },
    .{ .name = "TIM4", .index = 30, .description = "TIM4 global interrupt" },
    .{ .name = "I2C1_EV", .index = 31, .description = "I2C1 event interrupt" },
    .{ .name = "I2C1_ER", .index = 32, .description = "I2C1 error interrupt" },
    .{ .name = "I2C2_EV", .index = 33, .description = "I2C2 event interrupt" },
    .{ .name = "I2C2_ER", .index = 34, .description = "I2C2 error interrupt" },
    .{ .name = "SPI1", .index = 35, .description = "SPI1 global interrupt" },
    .{ .name = "SPI2", .index = 36, .description = "SPI2 global interrupt" },
    .{ .name = "USART1", .index = 37, .description = "USART1 global interrupt" },
    .{ .name = "USART2", .index = 38, .description = "USART2 global interrupt" },
    .{ .name = "USART3", .index = 39, .description = "USART3 global interrupt" },
    .{ .name = "EXTI15_10", .index = 40, .description = "EXTI Line[15:10] interrupts" },
    .{ .name = "RTC_ALARM", .index = 41, .description = "RTC alarms (A and B)" },
    .{ .name = "TIM8_BRK_TIM12", .index = 43, .description = "TIM8 and 12 break global" },
    .{ .name = "TIM8_UP_TIM13", .index = 44, .description = "TIM8 and 13 update global" },
    .{ .name = "TIM8_TRG_COM_TIM14", .index = 45, .description = 
    \\TIM8 and 14 trigger /commutation and
    \\        global
    },
    .{ .name = "TIM8_CC", .index = 46, .description = "TIM8 capture / compare" },
    .{ .name = "DMA1_STR7", .index = 47, .description = "DMA1 Stream7" },
    .{ .name = "FMC", .index = 48, .description = "FMC global interrupt" },
    .{ .name = "SDMMC1", .index = 49, .description = "SDMMC global interrupt" },
    .{ .name = "TIM5", .index = 50, .description = "TIM5 global interrupt" },
    .{ .name = "SPI3", .index = 51, .description = "SPI3 global interrupt" },
    .{ .name = "UART4", .index = 52, .description = "UART4 global interrupt" },
    .{ .name = "UART5", .index = 53, .description = "UART5 global interrupt" },
    .{ .name = "TIM6_DAC", .index = 54, .description = "TIM6 global interrupt" },
    .{ .name = "TIM7", .index = 55, .description = "TIM7 global interrupt" },
    .{ .name = "DMA2_STR0", .index = 56, .description = "DMA2 Stream0 interrupt" },
    .{ .name = "DMA2_STR1", .index = 57, .description = "DMA2 Stream1 interrupt" },
    .{ .name = "DMA2_STR2", .index = 58, .description = "DMA2 Stream2 interrupt" },
    .{ .name = "DMA2_STR3", .index = 59, .description = "DMA2 Stream3 interrupt" },
    .{ .name = "DMA2_STR4", .index = 60, .description = "DMA2 Stream4 interrupt" },
    .{ .name = "ETH", .index = 61, .description = "Ethernet global interrupt" },
    .{ .name = "ETH_WKUP", .index = 62, .description = "Ethernet wakeup through EXTI" },
    .{ .name = "DMA2_STR5", .index = 68, .description = "DMA2 Stream5 interrupt" },
    .{ .name = "DMA2_STR6", .index = 69, .description = "DMA2 Stream6 interrupt" },
    .{ .name = "DMA2_STR7", .index = 70, .description = "DMA2 Stream7 interrupt" },
    .{ .name = "USART6", .index = 71, .description = "USART6 global interrupt" },
    .{ .name = "I2C3_EV", .index = 72, .description = "I2C3 event interrupt" },
    .{ .name = "I2C3_ER", .index = 73, .description = "I2C3 error interrupt" },
    .{ .name = "OTG_HS_EP1_OUT", .index = 74, .description = "OTG_HS out global interrupt" },
    .{ .name = "OTG_HS_EP1_IN", .index = 75, .description = "OTG_HS in global interrupt" },
    .{ .name = "OTG_HS_WKUP", .index = 76, .description = "OTG_HS wakeup interrupt" },
    .{ .name = "OTG_HS", .index = 77, .description = "OTG_HS global interrupt" },
    .{ .name = "DCMI", .index = 78, .description = "DCMI global interrupt" },
    .{ .name = "CRYP", .index = 79, .description = "CRYP global interrupt" },
    .{ .name = "HASH_RNG", .index = 80, .description = "HASH and RNG" },
    .{ .name = "FPU", .index = 81, .description = "Floating point unit interrupt" },
    .{ .name = "UART7", .index = 82, .description = "UART7 global interrupt" },
    .{ .name = "UART8", .index = 83, .description = "UART8 global interrupt" },
    .{ .name = "SPI4", .index = 84, .description = "SPI4 global interrupt" },
    .{ .name = "SPI5", .index = 85, .description = "SPI5 global interrupt" },
    .{ .name = "SPI6", .index = 86, .description = "SPI6 global interrupt" },
    .{ .name = "SAI1", .index = 87, .description = "SAI1 global interrupt" },
    .{ .name = "LTDC", .index = 88, .description = "LCD-TFT global interrupt" },
    .{ .name = "LTDC_ER", .index = 89, .description = "LCD-TFT error interrupt" },
    .{ .name = "DMA2D", .index = 90, .description = "DMA2D global interrupt" },
    .{ .name = "SAI2", .index = 91, .description = "SAI2 global interrupt" },
    .{ .name = "QUADSPI", .index = 92, .description = "QuadSPI global interrupt" },
    .{ .name = "LPTIM1", .index = 93, .description = "LPTIM1 global interrupt" },
    .{ .name = "CEC", .index = 94, .description = "HDMI-CEC global interrupt" },
    .{ .name = "I2C4_EV", .index = 95, .description = "I2C4 event interrupt" },
    .{ .name = "I2C4_ER", .index = 96, .description = "I2C4 error interrupt" },
    .{ .name = "SPDIF", .index = 97, .description = "SPDIFRX global interrupt" },
    .{ .name = "OTG_FS_EP1_OUT", .index = 98, .description = "OTG_FS out global interrupt" },
    .{ .name = "OTG_FS_EP1_IN", .index = 99, .description = "OTG_FS in global interrupt" },
    .{ .name = "OTG_FS_WKUP", .index = 100, .description = "OTG_FS wakeup" },
    .{ .name = "OTG_FS", .index = 101, .description = "OTG_FS global interrupt" },
    .{ .name = "DMAMUX1_OV", .index = 102, .description = "DMAMUX1 overrun interrupt" },
    .{ .name = "HRTIM1_MST", .index = 103, .description = "HRTIM1 master timer interrupt" },
    .{ .name = "HRTIM1_TIMA", .index = 104, .description = "HRTIM1 timer A interrupt" },
    .{ .name = "HRTIM_TIMB", .index = 105, .description = "HRTIM1 timer B interrupt" },
    .{ .name = "HRTIM1_TIMC", .index = 106, .description = "HRTIM1 timer C interrupt" },
    .{ .name = "HRTIM1_TIMD", .index = 107, .description = "HRTIM1 timer D interrupt" },
    .{ .name = "HRTIM_TIME", .index = 108, .description = "HRTIM1 timer E interrupt" },
    .{ .name = "HRTIM1_FLT", .index = 109, .description = "HRTIM1 fault interrupt" },
    .{ .name = "DFSDM1_FLT0", .index = 110, .description = "DFSDM1 filter 0 interrupt" },
    .{ .name = "DFSDM1_FLT1", .index = 111, .description = "DFSDM1 filter 1 interrupt" },
    .{ .name = "DFSDM1_FLT2", .index = 112, .description = "DFSDM1 filter 2 interrupt" },
    .{ .name = "DFSDM1_FLT3", .index = 113, .description = "DFSDM1 filter 3 interrupt" },
    .{ .name = "SAI3", .index = 114, .description = "SAI3 global interrupt" },
    .{ .name = "SWPMI1", .index = 115, .description = "SWPMI global interrupt" },
    .{ .name = "TIM15", .index = 116, .description = "TIM15 global interrupt" },
    .{ .name = "TIM16", .index = 117, .description = "TIM16 global interrupt" },
    .{ .name = "TIM17", .index = 118, .description = "TIM17 global interrupt" },
    .{ .name = "MDIOS_WKUP", .index = 119, .description = "MDIOS wakeup" },
    .{ .name = "MDIOS", .index = 120, .description = "MDIOS global interrupt" },
    .{ .name = "JPEG", .index = 121, .description = "JPEG global interrupt" },
    .{ .name = "MDMA", .index = 122, .description = "MDMA" },
    .{ .name = "SDMMC", .index = 124, .description = "SDMMC global interrupt" },
    .{ .name = "HSEM0", .index = 125, .description = "HSEM global interrupt 1" },
    .{ .name = "ADC3", .index = 127, .description = "ADC3 global interrupt" },
    .{ .name = "DMAMUX2_OVR", .index = 128, .description = "DMAMUX2 overrun interrupt" },
    .{ .name = "BDMA_CH1", .index = 129, .description = "BDMA channel 1 interrupt" },
    .{ .name = "BDMA_CH2", .index = 130, .description = "BDMA channel 2 interrupt" },
    .{ .name = "BDMA_CH3", .index = 131, .description = "BDMA channel 3 interrupt" },
    .{ .name = "BDMA_CH4", .index = 132, .description = "BDMA channel 4 interrupt" },
    .{ .name = "BDMA_CH5", .index = 133, .description = "BDMA channel 5 interrupt" },
    .{ .name = "BDMA_CH6", .index = 134, .description = "BDMA channel 6 interrupt" },
    .{ .name = "BDMA_CH7", .index = 135, .description = "BDMA channel 7 interrupt" },
    .{ .name = "BDMA_CH8", .index = 136, .description = "BDMA channel 8 interrupt" },
    .{ .name = "COMP", .index = 137, .description = "COMP1 and COMP2" },
    .{ .name = "LPTIM2", .index = 138, .description = "LPTIM2 timer interrupt" },
    .{ .name = "LPTIM3", .index = 139, .description = "LPTIM2 timer interrupt" },
    .{ .name = "LPTIM4", .index = 140, .description = "LPTIM2 timer interrupt" },
    .{ .name = "LPTIM5", .index = 141, .description = "LPTIM2 timer interrupt" },
    .{ .name = "LPUART", .index = 142, .description = "LPUART global interrupt" },
    .{ .name = "WWDG1_RST", .index = 143, .description = "Window Watchdog interrupt" },
    .{ .name = "CRS", .index = 144, .description = "Clock Recovery System globa" },
    .{ .name = "SAI4", .index = 146, .description = "SAI4 global interrupt" },
    .{ .name = "WKUP", .index = 149, .description = "WKUP1 to WKUP6 pins" },
};

pub const VectorTable = extern struct {
    const Handler = microzig.interrupt.Handler;
    const unhandled = microzig.interrupt.unhandled;

    initial_stack_pointer: *const anyopaque,
    Reset: Handler,
    NMI: Handler = unhandled,
    HardFault: Handler = unhandled,
    MemManageFault: Handler = unhandled,
    BusFault: Handler = unhandled,
    UsageFault: Handler = unhandled,
    reserved5: [4]u32 = undefined,
    SVCall: Handler = unhandled,
    reserved10: [2]u32 = undefined,
    PendSV: Handler = unhandled,
    SysTick: Handler = unhandled,
    /// Window Watchdog interrupt
    WWDG1: Handler = unhandled,
    /// PVD through EXTI line
    PVD_PVM: Handler = unhandled,
    /// RTC tamper, timestamp
    RTC_TAMP_STAMP_CSS_LSE: Handler = unhandled,
    /// RTC Wakeup interrupt
    RTC_WKUP: Handler = unhandled,
    /// Flash memory
    FLASH: Handler = unhandled,
    /// RCC global interrupt
    RCC: Handler = unhandled,
    /// EXTI Line 0 interrupt
    EXTI0: Handler = unhandled,
    /// EXTI Line 1 interrupt
    EXTI1: Handler = unhandled,
    /// EXTI Line 2 interrupt
    EXTI2: Handler = unhandled,
    /// EXTI Line 3interrupt
    EXTI3: Handler = unhandled,
    /// EXTI Line 4interrupt
    EXTI4: Handler = unhandled,
    /// DMA1 Stream0
    DMA1_STR0: Handler = unhandled,
    /// DMA1 Stream1
    DMA1_STR1: Handler = unhandled,
    /// DMA1 Stream2
    DMA1_STR2: Handler = unhandled,
    /// DMA1 Stream3
    DMA1_STR3: Handler = unhandled,
    /// DMA1 Stream4
    DMA1_STR4: Handler = unhandled,
    /// DMA1 Stream5
    DMA1_STR5: Handler = unhandled,
    /// DMA1 Stream6
    DMA1_STR6: Handler = unhandled,
    /// DMA1 Stream7
    DMA1_STR7: Handler = unhandled,
    /// ADC1 and ADC2
    ADC1_2: Handler = unhandled,
    /// FDCAN1 Interrupt 0
    FDCAN1_IT0: Handler = unhandled,
    /// FDCAN2 Interrupt 0
    FDCAN2_IT0: Handler = unhandled,
    /// FDCAN1 Interrupt 1
    FDCAN1_IT1: Handler = unhandled,
    /// FDCAN2 Interrupt 1
    FDCAN2_IT1: Handler = unhandled,
    /// EXTI Line[9:5] interrupts
    EXTI9_5: Handler = unhandled,
    /// TIM1 break interrupt
    TIM1_BRK: Handler = unhandled,
    /// TIM1 update interrupt
    TIM1_UP: Handler = unhandled,
    /// TIM1 trigger and commutation
    TIM1_TRG_COM: Handler = unhandled,
    /// TIM1 capture / compare
    TIM_CC: Handler = unhandled,
    /// TIM2 global interrupt
    TIM2: Handler = unhandled,
    /// TIM3 global interrupt
    TIM3: Handler = unhandled,
    /// TIM4 global interrupt
    TIM4: Handler = unhandled,
    /// I2C1 event interrupt
    I2C1_EV: Handler = unhandled,
    /// I2C1 error interrupt
    I2C1_ER: Handler = unhandled,
    /// I2C2 event interrupt
    I2C2_EV: Handler = unhandled,
    /// I2C2 error interrupt
    I2C2_ER: Handler = unhandled,
    /// SPI1 global interrupt
    SPI1: Handler = unhandled,
    /// SPI2 global interrupt
    SPI2: Handler = unhandled,
    /// USART1 global interrupt
    USART1: Handler = unhandled,
    /// USART2 global interrupt
    USART2: Handler = unhandled,
    /// USART3 global interrupt
    USART3: Handler = unhandled,
    /// EXTI Line[15:10] interrupts
    EXTI15_10: Handler = unhandled,
    /// RTC alarms (A and B)
    RTC_ALARM: Handler = unhandled,
    reserved56: [1]u32 = undefined,
    /// TIM8 and 12 break global
    TIM8_BRK_TIM12: Handler = unhandled,
    /// TIM8 and 13 update global
    TIM8_UP_TIM13: Handler = unhandled,
    /// TIM8 and 14 trigger /commutation and global
    TIM8_TRG_COM_TIM14: Handler = unhandled,
    /// TIM8 capture / compare
    TIM8_CC: Handler = unhandled,
    /// FMC global interrupt
    FMC: Handler = unhandled,
    /// SDMMC global interrupt
    SDMMC1: Handler = unhandled,
    /// TIM5 global interrupt
    TIM5: Handler = unhandled,
    /// SPI3 global interrupt
    SPI3: Handler = unhandled,
    /// UART4 global interrupt
    UART4: Handler = unhandled,
    /// UART5 global interrupt
    UART5: Handler = unhandled,
    /// TIM6 global interrupt
    TIM6_DAC: Handler = unhandled,
    /// TIM7 global interrupt
    TIM7: Handler = unhandled,
    /// DMA2 Stream0 interrupt
    DMA2_STR0: Handler = unhandled,
    /// DMA2 Stream1 interrupt
    DMA2_STR1: Handler = unhandled,
    /// DMA2 Stream2 interrupt
    DMA2_STR2: Handler = unhandled,
    /// DMA2 Stream3 interrupt
    DMA2_STR3: Handler = unhandled,
    /// DMA2 Stream4 interrupt
    DMA2_STR4: Handler = unhandled,
    /// Ethernet global interrupt
    ETH: Handler = unhandled,
    /// Ethernet wakeup through EXTI
    ETH_WKUP: Handler = unhandled,
    reserved77: [5]u32 = undefined,
    /// DMA2 Stream5 interrupt
    DMA2_STR5: Handler = unhandled,
    /// DMA2 Stream6 interrupt
    DMA2_STR6: Handler = unhandled,
    /// DMA2 Stream7 interrupt
    DMA2_STR7: Handler = unhandled,
    /// USART6 global interrupt
    USART6: Handler = unhandled,
    /// I2C3 event interrupt
    I2C3_EV: Handler = unhandled,
    /// I2C3 error interrupt
    I2C3_ER: Handler = unhandled,
    /// OTG_HS out global interrupt
    OTG_HS_EP1_OUT: Handler = unhandled,
    /// OTG_HS in global interrupt
    OTG_HS_EP1_IN: Handler = unhandled,
    /// OTG_HS wakeup interrupt
    OTG_HS_WKUP: Handler = unhandled,
    /// OTG_HS global interrupt
    OTG_HS: Handler = unhandled,
    /// DCMI global interrupt
    DCMI: Handler = unhandled,
    /// CRYP global interrupt
    CRYP: Handler = unhandled,
    /// HASH and RNG
    HASH_RNG: Handler = unhandled,
    /// Floating point unit interrupt
    FPU: Handler = unhandled,
    /// UART7 global interrupt
    UART7: Handler = unhandled,
    /// UART8 global interrupt
    UART8: Handler = unhandled,
    /// SPI4 global interrupt
    SPI4: Handler = unhandled,
    /// SPI5 global interrupt
    SPI5: Handler = unhandled,
    /// SPI6 global interrupt
    SPI6: Handler = unhandled,
    /// SAI1 global interrupt
    SAI1: Handler = unhandled,
    /// LCD-TFT global interrupt
    LTDC: Handler = unhandled,
    /// LCD-TFT error interrupt
    LTDC_ER: Handler = unhandled,
    /// DMA2D global interrupt
    DMA2D: Handler = unhandled,
    /// SAI2 global interrupt
    SAI2: Handler = unhandled,
    /// QuadSPI global interrupt
    QUADSPI: Handler = unhandled,
    /// LPTIM1 global interrupt
    LPTIM1: Handler = unhandled,
    /// HDMI-CEC global interrupt
    CEC: Handler = unhandled,
    /// I2C4 event interrupt
    I2C4_EV: Handler = unhandled,
    /// I2C4 error interrupt
    I2C4_ER: Handler = unhandled,
    /// SPDIFRX global interrupt
    SPDIF: Handler = unhandled,
    /// OTG_FS out global interrupt
    OTG_FS_EP1_OUT: Handler = unhandled,
    /// OTG_FS in global interrupt
    OTG_FS_EP1_IN: Handler = unhandled,
    /// OTG_FS wakeup
    OTG_FS_WKUP: Handler = unhandled,
    /// OTG_FS global interrupt
    OTG_FS: Handler = unhandled,
    /// DMAMUX1 overrun interrupt
    DMAMUX1_OV: Handler = unhandled,
    /// HRTIM1 master timer interrupt
    HRTIM1_MST: Handler = unhandled,
    /// HRTIM1 timer A interrupt
    HRTIM1_TIMA: Handler = unhandled,
    /// HRTIM1 timer B interrupt
    HRTIM_TIMB: Handler = unhandled,
    /// HRTIM1 timer C interrupt
    HRTIM1_TIMC: Handler = unhandled,
    /// HRTIM1 timer D interrupt
    HRTIM1_TIMD: Handler = unhandled,
    /// HRTIM1 timer E interrupt
    HRTIM_TIME: Handler = unhandled,
    /// HRTIM1 fault interrupt
    HRTIM1_FLT: Handler = unhandled,
    /// DFSDM1 filter 0 interrupt
    DFSDM1_FLT0: Handler = unhandled,
    /// DFSDM1 filter 1 interrupt
    DFSDM1_FLT1: Handler = unhandled,
    /// DFSDM1 filter 2 interrupt
    DFSDM1_FLT2: Handler = unhandled,
    /// DFSDM1 filter 3 interrupt
    DFSDM1_FLT3: Handler = unhandled,
    /// SAI3 global interrupt
    SAI3: Handler = unhandled,
    /// SWPMI global interrupt
    SWPMI1: Handler = unhandled,
    /// TIM15 global interrupt
    TIM15: Handler = unhandled,
    /// TIM16 global interrupt
    TIM16: Handler = unhandled,
    /// TIM17 global interrupt
    TIM17: Handler = unhandled,
    /// MDIOS wakeup
    MDIOS_WKUP: Handler = unhandled,
    /// MDIOS global interrupt
    MDIOS: Handler = unhandled,
    /// JPEG global interrupt
    JPEG: Handler = unhandled,
    /// MDMA
    MDMA: Handler = unhandled,
    reserved137: [1]u32 = undefined,
    /// SDMMC global interrupt
    SDMMC: Handler = unhandled,
    /// HSEM global interrupt 1
    HSEM0: Handler = unhandled,
    reserved140: [1]u32 = undefined,
    /// ADC3 global interrupt
    ADC3: Handler = unhandled,
    /// DMAMUX2 overrun interrupt
    DMAMUX2_OVR: Handler = unhandled,
    /// BDMA channel 1 interrupt
    BDMA_CH1: Handler = unhandled,
    /// BDMA channel 2 interrupt
    BDMA_CH2: Handler = unhandled,
    /// BDMA channel 3 interrupt
    BDMA_CH3: Handler = unhandled,
    /// BDMA channel 4 interrupt
    BDMA_CH4: Handler = unhandled,
    /// BDMA channel 5 interrupt
    BDMA_CH5: Handler = unhandled,
    /// BDMA channel 6 interrupt
    BDMA_CH6: Handler = unhandled,
    /// BDMA channel 7 interrupt
    BDMA_CH7: Handler = unhandled,
    /// BDMA channel 8 interrupt
    BDMA_CH8: Handler = unhandled,
    /// COMP1 and COMP2
    COMP: Handler = unhandled,
    /// LPTIM2 timer interrupt
    LPTIM2: Handler = unhandled,
    /// LPTIM2 timer interrupt
    LPTIM3: Handler = unhandled,
    /// LPTIM2 timer interrupt
    LPTIM4: Handler = unhandled,
    /// LPTIM2 timer interrupt
    LPTIM5: Handler = unhandled,
    /// LPUART global interrupt
    LPUART: Handler = unhandled,
    /// Window Watchdog interrupt
    WWDG1_RST: Handler = unhandled,
    /// Clock Recovery System globa
    CRS: Handler = unhandled,
    reserved159: [1]u32 = undefined,
    /// SAI4 global interrupt
    SAI4: Handler = unhandled,
    reserved161: [2]u32 = undefined,
    /// WKUP1 to WKUP6 pins
    WKUP: Handler = unhandled,
};

pub const peripherals = struct {
    /// General purpose timers
    pub const TIM2: *volatile types.peripherals.TIM2 = @ptrFromInt(0x40000000);
    /// General purpose timers
    pub const TIM3: *volatile types.peripherals.TIM2 = @ptrFromInt(0x40000400);
    /// General purpose timers
    pub const TIM4: *volatile types.peripherals.TIM2 = @ptrFromInt(0x40000800);
    /// General purpose timers
    pub const TIM5: *volatile types.peripherals.TIM2 = @ptrFromInt(0x40000c00);
    /// Basic timers
    pub const TIM6: *volatile types.peripherals.TIM6 = @ptrFromInt(0x40001000);
    /// Basic timers
    pub const TIM7: *volatile types.peripherals.TIM6 = @ptrFromInt(0x40001400);
    /// General purpose timers
    pub const TIM12: *volatile types.peripherals.TIM2 = @ptrFromInt(0x40001800);
    /// General purpose timers
    pub const TIM13: *volatile types.peripherals.TIM2 = @ptrFromInt(0x40001c00);
    /// General purpose timers
    pub const TIM14: *volatile types.peripherals.TIM2 = @ptrFromInt(0x40002000);
    /// Low power timer
    pub const LPTIM1: *volatile types.peripherals.LPTIM1 = @ptrFromInt(0x40002400);
    /// Serial peripheral interface
    pub const SPI2: *volatile types.peripherals.SPI1 = @ptrFromInt(0x40003800);
    /// Serial peripheral interface
    pub const SPI3: *volatile types.peripherals.SPI1 = @ptrFromInt(0x40003c00);
    /// Receiver Interface
    pub const SPDIFRX: *volatile types.peripherals.SPDIFRX = @ptrFromInt(0x40004000);
    /// Universal synchronous asynchronous receiver transmitter
    pub const USART2: *volatile types.peripherals.USART1 = @ptrFromInt(0x40004400);
    /// Universal synchronous asynchronous receiver transmitter
    pub const USART3: *volatile types.peripherals.USART1 = @ptrFromInt(0x40004800);
    /// Universal synchronous asynchronous receiver transmitter
    pub const UART4: *volatile types.peripherals.USART1 = @ptrFromInt(0x40004c00);
    /// Universal synchronous asynchronous receiver transmitter
    pub const UART5: *volatile types.peripherals.USART1 = @ptrFromInt(0x40005000);
    /// I2C
    pub const I2C1: *volatile types.peripherals.I2C1 = @ptrFromInt(0x40005400);
    /// I2C
    pub const I2C2: *volatile types.peripherals.I2C1 = @ptrFromInt(0x40005800);
    /// I2C
    pub const I2C3: *volatile types.peripherals.I2C1 = @ptrFromInt(0x40005c00);
    /// CEC
    pub const CEC: *volatile types.peripherals.CEC = @ptrFromInt(0x40006c00);
    /// DAC
    pub const DAC: *volatile types.peripherals.DAC = @ptrFromInt(0x40007400);
    /// Universal synchronous asynchronous receiver transmitter
    pub const UART7: *volatile types.peripherals.USART1 = @ptrFromInt(0x40007800);
    /// Universal synchronous asynchronous receiver transmitter
    pub const UART8: *volatile types.peripherals.USART1 = @ptrFromInt(0x40007c00);
    /// CRS
    pub const CRS: *volatile types.peripherals.CRS = @ptrFromInt(0x40008400);
    /// Single Wire Protocol Master Interface
    pub const SWPMI: *volatile types.peripherals.SWPMI = @ptrFromInt(0x40008800);
    /// Operational amplifiers
    pub const OPAMP: *volatile types.peripherals.OPAMP = @ptrFromInt(0x40009000);
    /// Management data input/output slave
    pub const MDIOS: *volatile types.peripherals.MDIOS = @ptrFromInt(0x40009400);
    /// FDCAN1
    pub const FDCAN1: *volatile types.peripherals.FDCAN1 = @ptrFromInt(0x4000a000);
    /// FDCAN1
    pub const FDCAN2: *volatile types.peripherals.FDCAN1 = @ptrFromInt(0x4000a400);
    /// CCU registers
    pub const CAN_CCU: *volatile types.peripherals.CAN_CCU = @ptrFromInt(0x4000a800);
    /// Advanced-timers
    pub const TIM1: *volatile types.peripherals.TIM1 = @ptrFromInt(0x40010000);
    /// Advanced-timers
    pub const TIM8: *volatile types.peripherals.TIM1 = @ptrFromInt(0x40010400);
    /// Universal synchronous asynchronous receiver transmitter
    pub const USART1: *volatile types.peripherals.USART1 = @ptrFromInt(0x40011000);
    /// Universal synchronous asynchronous receiver transmitter
    pub const USART6: *volatile types.peripherals.USART1 = @ptrFromInt(0x40011400);
    /// Serial peripheral interface
    pub const SPI1: *volatile types.peripherals.SPI1 = @ptrFromInt(0x40013000);
    /// Serial peripheral interface
    pub const SPI4: *volatile types.peripherals.SPI1 = @ptrFromInt(0x40013400);
    /// General purpose timers
    pub const TIM15: *volatile types.peripherals.TIM15 = @ptrFromInt(0x40014000);
    /// General-purpose-timers
    pub const TIM16: *volatile types.peripherals.TIM16 = @ptrFromInt(0x40014400);
    /// General-purpose-timers
    pub const TIM17: *volatile types.peripherals.TIM17 = @ptrFromInt(0x40014800);
    /// Serial peripheral interface
    pub const SPI5: *volatile types.peripherals.SPI1 = @ptrFromInt(0x40015000);
    /// SAI
    pub const SAI1: *volatile types.peripherals.SAI4 = @ptrFromInt(0x40015800);
    /// SAI
    pub const SAI2: *volatile types.peripherals.SAI4 = @ptrFromInt(0x40015c00);
    /// SAI
    pub const SAI3: *volatile types.peripherals.SAI4 = @ptrFromInt(0x40016000);
    /// Digital filter for sigma delta modulators
    pub const DFSDM: *volatile types.peripherals.DFSDM = @ptrFromInt(0x40017000);
    /// High Resolution Timer: Master Timers
    pub const HRTIM_Master: *volatile types.peripherals.HRTIM_Master = @ptrFromInt(0x40017400);
    /// High Resolution Timer: TIMA
    pub const HRTIM_TIMA: *volatile types.peripherals.HRTIM_TIMA = @ptrFromInt(0x40017480);
    /// High Resolution Timer: TIMB
    pub const HRTIM_TIMB: *volatile types.peripherals.HRTIM_TIMB = @ptrFromInt(0x40017500);
    /// High Resolution Timer: TIMC
    pub const HRTIM_TIMC: *volatile types.peripherals.HRTIM_TIMC = @ptrFromInt(0x40017580);
    /// High Resolution Timer: TIMD
    pub const HRTIM_TIMD: *volatile types.peripherals.HRTIM_TIMD = @ptrFromInt(0x40017600);
    /// High Resolution Timer: TIME
    pub const HRTIM_TIME: *volatile types.peripherals.HRTIM_TIME = @ptrFromInt(0x40017680);
    /// High Resolution Timer: Common functions
    pub const HRTIM_Common: *volatile types.peripherals.HRTIM_Common = @ptrFromInt(0x40017780);
    /// DMA controller
    pub const DMA1: *volatile types.peripherals.DMA.DMA1 = @ptrFromInt(0x40020000);
    /// DMA controller
    pub const DMA2: *volatile types.peripherals.DMA.DMA1 = @ptrFromInt(0x40020400);
    /// DMAMUX
    pub const DMAMUX1: *volatile types.peripherals.DMAMUX1 = @ptrFromInt(0x40020800);
    /// Analog to Digital Converter
    pub const ADC1: *volatile types.peripherals.ADC3 = @ptrFromInt(0x40022000);
    /// Analog to Digital Converter
    pub const ADC2: *volatile types.peripherals.ADC3 = @ptrFromInt(0x40022100);
    /// Analog-to-Digital Converter
    pub const ADC12_Common: *volatile types.peripherals.ADC3_Common = @ptrFromInt(0x40022300);
    /// ETH register block
    pub const ETH: *volatile types.peripherals.ETH = @ptrFromInt(0x40028000);
    /// USB 1 on the go high speed
    pub const OTG1_HS_GLOBAL: *volatile types.peripherals.OTG1_HS_GLOBAL = @ptrFromInt(0x40040000);
    /// USB 1 on the go high speed
    pub const OTG1_HS_HOST: *volatile types.peripherals.OTG1_HS_HOST = @ptrFromInt(0x40040400);
    /// USB 1 on the go high speed
    pub const OTG1_HS_DEVICE: *volatile types.peripherals.OTG1_HS_DEVICE = @ptrFromInt(0x40040800);
    /// USB 1 on the go high speed
    pub const OTG1_HS_PWRCLK: *volatile types.peripherals.OTG1_HS_PWRCLK = @ptrFromInt(0x40040e00);
    /// USB 1 on the go high speed
    pub const OTG2_HS_GLOBAL: *volatile types.peripherals.OTG1_HS_GLOBAL = @ptrFromInt(0x40080000);
    /// USB 1 on the go high speed
    pub const OTG2_HS_HOST: *volatile types.peripherals.OTG1_HS_HOST = @ptrFromInt(0x40080400);
    /// USB 1 on the go high speed
    pub const OTG2_HS_DEVICE: *volatile types.peripherals.OTG1_HS_DEVICE = @ptrFromInt(0x40080800);
    /// USB 1 on the go high speed
    pub const OTG2_HS_PWRCLK: *volatile types.peripherals.OTG1_HS_PWRCLK = @ptrFromInt(0x40080e00);
    /// Digital camera interface
    pub const DCMI: *volatile types.peripherals.DCMI = @ptrFromInt(0x48020000);
    /// Cryptographic processor
    pub const CRYP: *volatile types.peripherals.CRYP = @ptrFromInt(0x48021000);
    /// Hash processor
    pub const HASH: *volatile types.peripherals.HASH = @ptrFromInt(0x48021400);
    /// RNG
    pub const RNG: *volatile types.peripherals.RNG = @ptrFromInt(0x48021800);
    /// SDMMC1
    pub const SDMMC2: *volatile types.peripherals.SDMMC1 = @ptrFromInt(0x48022400);
    /// DELAY_Block_SDMMC1
    pub const DELAY_Block_SDMMC2: *volatile types.peripherals.DELAY_Block_SDMMC1 = @ptrFromInt(0x48022800);
    /// LCD-TFT Controller
    pub const LTDC: *volatile types.peripherals.LTDC = @ptrFromInt(0x50001000);
    /// WWDG
    pub const WWDG: *volatile types.peripherals.WWDG = @ptrFromInt(0x50003000);
    /// AXI interconnect registers
    pub const AXI: *volatile types.peripherals.AXI = @ptrFromInt(0x51000000);
    /// MDMA
    pub const MDMA: *volatile types.peripherals.MDMA = @ptrFromInt(0x52000000);
    /// DMA2D
    pub const DMA2D: *volatile types.peripherals.DMA2D = @ptrFromInt(0x52001000);
    /// Flash
    pub const FLASH: *volatile types.peripherals.Flash.Flash = @ptrFromInt(0x52002000);
    /// JPEG
    pub const JPEG: *volatile types.peripherals.JPEG = @ptrFromInt(0x52003000);
    /// FMC
    pub const FMC: *volatile types.peripherals.FMC = @ptrFromInt(0x52004000);
    /// QUADSPI
    pub const QUADSPI: *volatile types.peripherals.QUADSPI = @ptrFromInt(0x52005000);
    /// DELAY_Block_SDMMC1
    pub const DELAY_Block_QUADSPI: *volatile types.peripherals.DELAY_Block_SDMMC1 = @ptrFromInt(0x52006000);
    /// SDMMC1
    pub const SDMMC1: *volatile types.peripherals.SDMMC1 = @ptrFromInt(0x52007000);
    /// DELAY_Block_SDMMC1
    pub const DELAY_Block_SDMMC1: *volatile types.peripherals.DELAY_Block_SDMMC1 = @ptrFromInt(0x52008000);
    /// External interrupt/event controller
    pub const EXTI: *volatile types.peripherals.EXTI = @ptrFromInt(0x58000000);
    /// System configuration controller
    pub const SYSCFG: *volatile types.peripherals.SYSCFG = @ptrFromInt(0x58000400);
    /// LPUART1
    pub const LPUART1: *volatile types.peripherals.LPUART1 = @ptrFromInt(0x58000c00);
    /// Serial peripheral interface
    pub const SPI6: *volatile types.peripherals.SPI1 = @ptrFromInt(0x58001400);
    /// I2C
    pub const I2C4: *volatile types.peripherals.I2C1 = @ptrFromInt(0x58001c00);
    /// Low power timer
    pub const LPTIM2: *volatile types.peripherals.LPTIM1 = @ptrFromInt(0x58002400);
    /// Low power timer
    pub const LPTIM3: *volatile types.peripherals.LPTIM3 = @ptrFromInt(0x58002800);
    /// Low power timer
    pub const LPTIM4: *volatile types.peripherals.LPTIM3 = @ptrFromInt(0x58002c00);
    /// Low power timer
    pub const LPTIM5: *volatile types.peripherals.LPTIM3 = @ptrFromInt(0x58003000);
    /// COMP1
    pub const COMP1: *volatile types.peripherals.COMP1 = @ptrFromInt(0x58003800);
    /// VREFBUF
    pub const VREFBUF: *volatile types.peripherals.VREFBUF = @ptrFromInt(0x58003c00);
    /// RTC
    pub const RTC: *volatile types.peripherals.RTC = @ptrFromInt(0x58004000);
    /// IWDG
    pub const IWDG: *volatile types.peripherals.IWDG = @ptrFromInt(0x58004800);
    /// SAI
    pub const SAI4: *volatile types.peripherals.SAI4 = @ptrFromInt(0x58005400);
    /// GPIO
    pub const GPIOA: *volatile types.peripherals.GPIO.GPIOA = @ptrFromInt(0x58020000);
    /// GPIO
    pub const GPIOB: *volatile types.peripherals.GPIO.GPIOA = @ptrFromInt(0x58020400);
    /// GPIO
    pub const GPIOC: *volatile types.peripherals.GPIO.GPIOA = @ptrFromInt(0x58020800);
    /// GPIO
    pub const GPIOD: *volatile types.peripherals.GPIO.GPIOA = @ptrFromInt(0x58020c00);
    /// GPIO
    pub const GPIOE: *volatile types.peripherals.GPIO.GPIOA = @ptrFromInt(0x58021000);
    /// GPIO
    pub const GPIOF: *volatile types.peripherals.GPIO.GPIOA = @ptrFromInt(0x58021400);
    /// GPIO
    pub const GPIOG: *volatile types.peripherals.GPIO.GPIOA = @ptrFromInt(0x58021800);
    /// GPIO
    pub const GPIOH: *volatile types.peripherals.GPIO.GPIOA = @ptrFromInt(0x58021c00);
    /// GPIO
    pub const GPIOI: *volatile types.peripherals.GPIO.GPIOA = @ptrFromInt(0x58022000);
    /// GPIO
    pub const GPIOJ: *volatile types.peripherals.GPIO.GPIOA = @ptrFromInt(0x58022400);
    /// GPIO
    pub const GPIOK: *volatile types.peripherals.GPIO.GPIOA = @ptrFromInt(0x58022800);
    /// Reset and clock control
    pub const RCC: *volatile types.peripherals.RCC.RCC = @ptrFromInt(0x58024400);
    /// PWR
    pub const PWR: *volatile types.peripherals.PWR.PWR = @ptrFromInt(0x58024800);
    /// Cryptographic processor
    pub const CRC: *volatile types.peripherals.CRC = @ptrFromInt(0x58024c00);
    /// BDMA
    pub const BDMA: *volatile types.peripherals.BDMA = @ptrFromInt(0x58025400);
    /// DMAMUX
    pub const DMAMUX2: *volatile types.peripherals.DMAMUX2 = @ptrFromInt(0x58025800);
    /// Analog to Digital Converter
    pub const ADC3: *volatile types.peripherals.ADC3 = @ptrFromInt(0x58026000);
    /// Analog-to-Digital Converter
    pub const ADC3_Common: *volatile types.peripherals.ADC3_Common = @ptrFromInt(0x58026300);
    /// HSEM
    pub const HSEM: *volatile types.peripherals.HSEM = @ptrFromInt(0x58026400);
    /// Microcontroller Debug Unit
    pub const DBGMCU: *volatile types.peripherals.DBGMCU = @ptrFromInt(0x5c001000);
    /// System control block ACTLR
    pub const SCB_ACTRL: *volatile types.peripherals.SCB_ACTRL = @ptrFromInt(0xe000e008);
    /// SysTick timer
    pub const STK: *volatile types.peripherals.STK = @ptrFromInt(0xe000e010);
    /// Nested Vectored Interrupt Controller
    pub const NVIC: *volatile types.peripherals.NVIC = @ptrFromInt(0xe000e100);
    /// System control block
    pub const SCB: *volatile types.peripherals.SCB = @ptrFromInt(0xe000ed00);
    /// Processor features
    pub const PF: *volatile types.peripherals.PF.PF = @ptrFromInt(0xe000ed78);
    /// Floating point unit CPACR
    pub const FPU_CPACR: *volatile types.peripherals.FPU_CPACR = @ptrFromInt(0xe000ed88);
    /// Memory protection unit
    pub const MPU: *volatile types.peripherals.MPU = @ptrFromInt(0xe000ed90);
    /// Nested vectored interrupt controller
    pub const NVIC_STIR: *volatile types.peripherals.NVIC_STIR = @ptrFromInt(0xe000ef00);
    /// Floting point unit
    pub const FPU: *volatile types.peripherals.FPU = @ptrFromInt(0xe000ef34);
    /// CacheMaintenance
    pub const CACHE: *volatile types.peripherals.PF.CacheMaintenance = @ptrFromInt(0xe000ef50);
    /// Access control
    pub const AC: *volatile types.peripherals.AC = @ptrFromInt(0xe000ef90);
};
