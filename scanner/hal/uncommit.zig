//! S4 of "Never unflashable": the scanner uncommits itself. Interrupts off,
//! FLASH_ACR.EMPTY set, flash page 0 erased, EMPTY set once more, system
//! reset. The chip then holds no bootable image: the ROM starts its
//! bootloader at the reset (the empty flag) and at every power-on after it
//! (the erased first word).
//!
//! The flag comes first (ruling of 2026-11-26): a reset that arrives in the
//! middle of the erase (the Daisy's NRST, or a lock-up followed by one)
//! then starts the ROM, not a half-erased page 0. If the erase never
//! starts, a reset lands in the bootloader with page 0 intact, which the
//! Daisy handles, and a power cycle re-reads the flag from flash. The
//! second write covers a first one that did not take, and it comes while
//! FLASH_CR is still unlocked, in case ACR writes need that on this chip
//! (ST's HAL_FLASHEx_ForceFlashEmpty writes ACR without unlocking, but that
//! is not verified for the C0).
//!
//! From the moment the erase starts nothing in flash may run: page 0 holds
//! the vector table and the start of the code. So the whole sequence is one
//! function in RAM (`.ram_text`, copied with `.data` by the reset path), it
//! calls nothing, takes its constants from its own literal pool in RAM, and
//! touches no flash register but KEYR, SR, CR and ACR. It is built without
//! runtime safety, so no compiler-inserted check can call into flash.
//!
//! The sequence (RM0490 4.3.5 page erase, docs.dirba.io mirror; ST's
//! HAL_FLASH_Unlock and HAL_FLASHEx_Erase / FLASH_PageErase in
//! stm32c0xx-hal-driver 50844c4; register bits from stm32c031xx.h; facts
//! file docs/superpowers/specs/2026-11-25-c031-flash-facts.md section 2):
//!
//! 1. interrupts off;
//! 2. ACR |= EMPTY (bit 16; PROGEMPTY in stm32c031xx.h), a read-modify-
//!    write that keeps LATENCY and every other bit, before the first key;
//! 3. wait while SR.BSY1 (bit 16);
//! 4. unlock, only if CR.LOCK (bit 31) is set (HAL_FLASH_Unlock does the
//!    same: a key written to an unlocked FLASH_CR is a wrong sequence):
//!    KEYR = 0x4567_0123, KEYR = 0xCDEF_89AB;
//! 5. clear the error flags and EOP, SR = 0x0000_C3FB (rc_w1: EOP 0,
//!    OPERR 1, PROGERR 3, WRPERR 4, PGAERR 5, SIZERR 6, PGSERR 7, MISERR 8,
//!    FASTERR 9, RDERR 14, OPTVERR 15; HAL's FLASH_FLAG_SR_ERROR plus EOP);
//! 6. wait while SR.CFGBSY (bit 18);
//! 7. CR = 0x0000_0002 (PER, PNB = 0), then CR = 0x0001_0002 (PER, PNB 0,
//!    STRT): exact values, so nothing the bootloader left in CR (PG, MER,
//!    OBL_LAUNCH, ...) survives;
//! 8. wait while BSY1, then while CFGBSY (RM step 6);
//! 9. ACR |= EMPTY again, the same read-modify-write, the flash still
//!    unlocked;
//! 10. CR = 0x8000_0000: PER off, CR locked;
//! 11. AIRCR = 0x05FA_0004 (VECTKEY, SYSRESETREQ), and wait for the reset.
//!
//! The waits have no bound: a flash that stays busy leaves the chip
//! waiting, never running erased flash, and the Daisy's NRST ends it.

/// Erases flash page 0 and resets into the ROM bootloader. Never returns.
pub fn run() noreturn {
    // `bl` cannot reach RAM from flash: the linker routes this call through
    // a long-branch thunk (in flash, run before anything is erased).
    eraseAndReset();
}

const flash_r_base: u32 = 0x4002_2000; // FLASH_R_BASE, stm32c031xx.h
const acr_addr = flash_r_base + 0x00;
const keyr_addr = flash_r_base + 0x08;
const sr_addr = flash_r_base + 0x10;
const cr_addr = flash_r_base + 0x14;
const aircr_addr: u32 = 0xE000_ED0C;

const key1: u32 = 0x4567_0123;
const key2: u32 = 0xCDEF_89AB;
const sr_bsy1: u32 = 1 << 16;
const sr_cfgbsy: u32 = 1 << 18;
const sr_clear: u32 = 0x0000_C3FB;
const cr_lock: u32 = 1 << 31;
const cr_page0_erase: u32 = 1 << 1; // PER, PNB = 0
const cr_page0_erase_start: u32 = cr_page0_erase | (1 << 16); // + STRT
const acr_empty: u32 = 1 << 16;
const aircr_sysresetreq: u32 = (0x05FA << 16) | (1 << 2);

/// Never inlined: all of it must stay in `.ram_text`.
noinline fn eraseAndReset() linksection(".ram_text") callconv(.c) noreturn {
    @setRuntimeSafety(false);
    asm volatile ("cpsid i" ::: .{ .memory = true });

    const acr: *volatile u32 = @ptrFromInt(acr_addr);
    const keyr: *volatile u32 = @ptrFromInt(keyr_addr);
    const sr: *volatile u32 = @ptrFromInt(sr_addr);
    const cr: *volatile u32 = @ptrFromInt(cr_addr);
    const aircr: *volatile u32 = @ptrFromInt(aircr_addr);

    // The flag first: from here on any reset starts the ROM.
    acr.* = acr.* | acr_empty;

    while (sr.* & sr_bsy1 != 0) {}
    if (cr.* & cr_lock != 0) {
        keyr.* = key1;
        keyr.* = key2;
    }
    sr.* = sr_clear;
    while (sr.* & sr_cfgbsy != 0) {}

    cr.* = cr_page0_erase;
    cr.* = cr_page0_erase_start;
    while (sr.* & sr_bsy1 != 0) {}
    while (sr.* & sr_cfgbsy != 0) {}
    // Once more, in case the first write did not take, before the lock.
    acr.* = acr.* | acr_empty;
    cr.* = cr_lock;

    asm volatile ("dsb" ::: .{ .memory = true });
    aircr.* = aircr_sysresetreq;
    asm volatile ("dsb" ::: .{ .memory = true });
    while (true) {}
}
