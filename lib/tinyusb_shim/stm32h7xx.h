/* Minimal CMSIS-equivalent shim for STM32H750, providing ONLY the symbols
 * lib/tinyusb/src/portable/synopsys/dwc2/dwc2_stm32.h references for
 * CFG_TUSB_MCU == OPT_MCU_STM32H7. No vendored ST CMSIS (the HAL is Zig on
 * microzig registers); per project convention (see lib/zfat_shim) we shim
 * exactly what dwc2_stm32.h names.
 *
 * STM32H750 has TWO independent USB OTG cores (RM0433 memory map):
 *   USB1_OTG_HS @ 0x40040000  (Daisy header pins PB14/PB15, FS mode via embedded PHY)
 *   USB2_OTG_FS @ 0x40080000  (Daisy onboard micro-USB)
 * We define USB2_OTG_FS so dwc2_stm32.h does NOT take its single-port path
 * (which would alias FS onto HS); it then builds
 *   _dwc2_controller[] = { [0] = OTG_FS, [1] = OTG_HS }
 * per its own comment "Port0 to OTG_FS, and Port1 to OTG_HS".
 */
#ifndef ZMETAL_TINYUSB_SHIM_STM32H7XX_H
#define ZMETAL_TINYUSB_SHIM_STM32H7XX_H

#include <stdint.h>

/* Mark the chip as having the second (FS) OTG instance so dwc2_stm32.h keeps
 * FS and HS distinct. */
#define USB2_OTG_FS  1

/* Peripheral base addresses (RM0433). */
#define USB_OTG_FS_PERIPH_BASE   (0x40080000UL)
#define USB_OTG_HS_PERIPH_BASE   (0x40040000UL)
#define USB1_OTG_HS_PERIPH_BASE  (0x40040000UL)

/* IRQ numbers (microzig metapac STM32H750IB): OTG_FS global = 101, OTG_HS = 77. */
typedef int32_t IRQn_Type;
#define OTG_FS_IRQn ((IRQn_Type)101)
#define OTG_HS_IRQn ((IRQn_Type)77)

/* Minimal Cortex-M NVIC enable/disable, standard ISER/ICER layout (ARMv7-M B3.4). */
#define ZMETAL_NVIC_ISER_BASE  (0xE000E100UL)
#define ZMETAL_NVIC_ICER_BASE  (0xE000E180UL)

static inline void NVIC_EnableIRQ(IRQn_Type IRQn) {
  if ((int32_t)IRQn >= 0) {
    volatile uint32_t *iser = (volatile uint32_t *)ZMETAL_NVIC_ISER_BASE;
    iser[((uint32_t)IRQn) >> 5] = (uint32_t)(1UL << (((uint32_t)IRQn) & 0x1FUL));
  }
}

static inline void NVIC_DisableIRQ(IRQn_Type IRQn) {
  if ((int32_t)IRQn >= 0) {
    volatile uint32_t *icer = (volatile uint32_t *)ZMETAL_NVIC_ICER_BASE;
    icer[((uint32_t)IRQn) >> 5] = (uint32_t)(1UL << (((uint32_t)IRQn) & 0x1FUL));
  }
}

/* AHB clock — used only by dwc2's FS turnaround table / remote-wakeup delay;
 * the project runs well above the top bucket so a constant suffices. */
#define SystemCoreClock  480000000UL

static inline void __NOP(void) {
  __asm volatile("nop");
}

#endif
