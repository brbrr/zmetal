#ifndef TUSB_CONFIG_H
#define TUSB_CONFIG_H

#include "tusb_option.h"

// --- Common ---
#define CFG_TUSB_MCU              OPT_MCU_STM32H7
#define CFG_TUSB_OS               OPT_OS_NONE
#define CFG_TUSB_MEM_SECTION
#define CFG_TUSB_MEM_ALIGN        __attribute__((aligned(4)))

// dwc2 on STM32H7 FS: no internal DMA (Buffer/FIFO mode), full speed.
#define BOARD_TUD_MAX_SPEED       OPT_MODE_FULL_SPEED

// Roothub port 0 is device-mode, full-speed. TinyUSB 0.18.0 derives
// TUD_OPT_RHPORT from this (see tusb_option.h); it is what makes the
// backward-compatible `tusb_init()` macro (-> tusb_rhport_init(0, NULL))
// resolve instead of static-asserting. Added beyond the task brief's literal
// tusb_config.h listing because 0.18.0 requires it (not present in the
// brief's reference version of TinyUSB).
#define CFG_TUSB_RHPORT0_MODE     (OPT_MODE_DEVICE | OPT_MODE_FULL_SPEED)

// --- Device ---
#define CFG_TUD_ENABLED           1
#define CFG_TUD_MAX_SPEED         OPT_MODE_FULL_SPEED

#define CFG_TUD_ENDPOINT0_SIZE    64

#define CFG_TUD_CDC               1
#define CFG_TUD_MIDI              1
#define CFG_TUD_MSC               0
#define CFG_TUD_HID               0
#define CFG_TUD_VENDOR            0

// CDC FIFO sizes (bytes).
#define CFG_TUD_CDC_RX_BUFSIZE    256
#define CFG_TUD_CDC_TX_BUFSIZE    256
#define CFG_TUD_CDC_EP_BUFSIZE    64

// MIDI FIFO sizes (bytes).
#define CFG_TUD_MIDI_RX_BUFSIZE   128
#define CFG_TUD_MIDI_TX_BUFSIZE   128
#define CFG_TUD_MIDI_EP_BUFSIZE   64

#endif
