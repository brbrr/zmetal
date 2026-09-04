/* UAC2 application callbacks + FIFO forwarders for the Zig audio engine.
 * Clock is a single fixed 48 kHz source; only sample-freq / clock-valid
 * control requests are answered. Interface / entity numbers must match
 * src/hal/STM32H750/usb/descriptors.zig. */
#include "tusb.h"

// Must match descriptors.zig.
#define ITF_AUDIO_SPK  5
#define ITF_AUDIO_MIC  6
#define ENT_CLOCK      0x04

// Sample rate the clock entity reports to the host — set at init from the
// runtime AudioConfig via zt_audio_set_sample_rate().
static volatile uint32_t g_sample_rate = 48000u;
void zt_audio_set_sample_rate(uint32_t rate) { g_sample_rate = rate; }

static volatile bool spk_active = false; // host opened playback (alt 1)
static volatile bool mic_active = false; // host opened capture (alt 1)

bool zt_audio_out_active(void) { return spk_active; }
bool zt_audio_in_active(void)  { return mic_active; }

uint16_t zt_audio_read(void* buf, uint16_t n)        { return tud_audio_read(buf, n); }
uint16_t zt_audio_write(const void* buf, uint16_t n) { return tud_audio_write(buf, n); }
uint32_t zt_audio_out_available(void)                { return tud_audio_available(); }

// ---- Set interface (alt setting) ----
bool tud_audio_set_itf_cb(uint8_t rhport, tusb_control_request_t const* req) {
  (void) rhport;
  uint8_t itf = tu_u16_low(req->wIndex);
  uint8_t alt = tu_u16_low(req->wValue);
  if (itf == ITF_AUDIO_SPK) spk_active = (alt != 0);
  if (itf == ITF_AUDIO_MIC) mic_active = (alt != 0);
  return true;
}

bool tud_audio_set_itf_close_ep_cb(uint8_t rhport, tusb_control_request_t const* req) {
  (void) rhport;
  uint8_t itf = tu_u16_low(req->wIndex);
  if (itf == ITF_AUDIO_SPK) spk_active = false;
  if (itf == ITF_AUDIO_MIC) mic_active = false;
  return true;
}

// ---- Clock source: sample-frequency + validity (GET only; fixed rate) ----
bool tud_audio_get_req_entity_cb(uint8_t rhport, tusb_control_request_t const* p_request) {
  uint8_t const entity_id = TU_U16_HIGH(p_request->wIndex);
  uint8_t const ctrl_sel  = TU_U16_HIGH(p_request->wValue);
  if (entity_id != ENT_CLOCK) return false;

  if (ctrl_sel == AUDIO20_CS_CTRL_SAM_FREQ) {
    if (p_request->bRequest == AUDIO20_CS_REQ_CUR) {
      audio20_control_cur_4_t cur = { (int32_t) tu_htole32(g_sample_rate) };
      return tud_audio_buffer_and_schedule_control_xfer(rhport, p_request, &cur, sizeof(cur));
    }
    if (p_request->bRequest == AUDIO20_CS_REQ_RANGE) {
      audio20_control_range_4_n_t(1) rng = { .wNumSubRanges = tu_htole16(1) };
      rng.subrange[0].bMin = (int32_t) g_sample_rate;
      rng.subrange[0].bMax = (int32_t) g_sample_rate;
      rng.subrange[0].bRes = 0;
      return tud_audio_buffer_and_schedule_control_xfer(rhport, p_request, &rng, sizeof(rng));
    }
  } else if (ctrl_sel == AUDIO20_CS_CTRL_CLK_VALID &&
             p_request->bRequest == AUDIO20_CS_REQ_CUR) {
    audio20_control_cur_1_t valid = { .bCur = 1 };
    return tud_audio_buffer_and_schedule_control_xfer(rhport, p_request, &valid, sizeof(valid));
  }
  return false;
}

bool tud_audio_set_req_entity_cb(uint8_t rhport, tusb_control_request_t const* p_request, uint8_t* buf) {
  (void) rhport; (void) p_request; (void) buf;
  return true; // fixed clock: nothing settable, ack so host proceeds
}
