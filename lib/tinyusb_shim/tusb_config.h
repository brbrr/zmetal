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

// --- Audio (UAC2) ---
#define CFG_TUD_AUDIO             1

// One audio function, full-duplex, single PCM format.
#define CFG_TUD_AUDIO_FUNC_1_N_AS_INT                  2   // 2 AS interfaces (spk + mic)
#define CFG_TUD_AUDIO_FUNC_1_N_FORMATS                 1
#define CFG_TUD_AUDIO_ENABLE_INTERRUPT_EP              0

// These size the C driver's EP/FIFO buffers only (the actual descriptor is
// built at runtime from AudioConfig). Set to the MAX envelope — 96 kHz, 2ch,
// 4-byte subslot — so any runtime format fits. EP size = (96+1)*4*2 = 776 B,
// within the full-speed 1023 B/frame iso ceiling.
#define CFG_TUD_AUDIO_FUNC_1_MAX_SAMPLE_RATE           96000
#define CFG_TUD_AUDIO_FUNC_1_N_CHANNELS_TX             2   // mic  (device -> host)
#define CFG_TUD_AUDIO_FUNC_1_N_CHANNELS_RX             2   // spk  (host -> device)
#define CFG_TUD_AUDIO_FUNC_1_FORMAT_1_N_BYTES_PER_SAMPLE_TX  4
#define CFG_TUD_AUDIO_FUNC_1_FORMAT_1_RESOLUTION_TX          32
#define CFG_TUD_AUDIO_FUNC_1_FORMAT_1_N_BYTES_PER_SAMPLE_RX  4
#define CFG_TUD_AUDIO_FUNC_1_FORMAT_1_RESOLUTION_RX          32

// Control buffer for class requests (clock freq get/set/range).
#define CFG_TUD_AUDIO_FUNC_1_CTRL_BUF_SZ               64

// --- Capture (mic) IN endpoint ---
#define CFG_TUD_AUDIO_ENABLE_EP_IN                     1
#define CFG_TUD_AUDIO_FUNC_1_EP_IN_SZ_MAX \
  TUD_AUDIO_EP_SIZE(false, CFG_TUD_AUDIO_FUNC_1_MAX_SAMPLE_RATE, \
    CFG_TUD_AUDIO_FUNC_1_FORMAT_1_N_BYTES_PER_SAMPLE_TX, CFG_TUD_AUDIO_FUNC_1_N_CHANNELS_TX)
#define CFG_TUD_AUDIO_FUNC_1_EP_IN_SW_BUF_SZ           (4 * CFG_TUD_AUDIO_FUNC_1_EP_IN_SZ_MAX)

// --- Playback (spk) OUT endpoint + feedback ---
#define CFG_TUD_AUDIO_ENABLE_EP_OUT                    1
// Adaptive OUT, no feedback EP: macOS will not drive a UAC2 feedback endpoint on
// full-speed (it stalls after priming). The host self-paces; residual host/SAI
// clock drift is corrected in software on the consume side.
#define CFG_TUD_AUDIO_ENABLE_FEEDBACK_EP               0
#define CFG_TUD_AUDIO_FUNC_1_EP_OUT_SZ_MAX \
  TUD_AUDIO_EP_SIZE(false, CFG_TUD_AUDIO_FUNC_1_MAX_SAMPLE_RATE, \
    CFG_TUD_AUDIO_FUNC_1_FORMAT_1_N_BYTES_PER_SAMPLE_RX, CFG_TUD_AUDIO_FUNC_1_N_CHANNELS_RX)
// FIFO_COUNT feedback needs the OUT SW FIFO >= 4x EP size.
#define CFG_TUD_AUDIO_FUNC_1_EP_OUT_SW_BUF_SZ          (4 * CFG_TUD_AUDIO_FUNC_1_EP_OUT_SZ_MAX)

#endif
