const mmio = @import("mmio");
const types = @import("../../types.zig");

/// Flash
pub const Flash = extern struct {
    /// Access control register
    /// offset: 0x00
    ACR: mmio.Mmio(packed struct(u32) {
        /// Read latency
        LATENCY: u3,
        reserved4: u1 = 0,
        /// Flash signal delay
        WRHIGHFREQ: u2,
        padding: u26 = 0,
    }),
    /// FLASH key register for bank 1
    /// offset: 0x04
    KEYR1: mmio.Mmio(packed struct(u32) {
        /// Bank 1 access configuration unlock key
        KEYR1: u32,
    }),
    /// FLASH option key register
    /// offset: 0x08
    OPTKEYR: mmio.Mmio(packed struct(u32) {
        /// Unlock key option bytes
        OPTKEYR: u32,
    }),
    /// FLASH control register for bank 1
    /// offset: 0x0c
    CR1: mmio.Mmio(packed struct(u32) {
        /// Bank 1 configuration lock bit
        LOCK1: u1,
        /// Bank 1 program enable bit
        PG1: u1,
        /// Bank 1 sector erase request
        SER1: u1,
        /// Bank 1 erase request
        BER1: u1,
        /// Bank 1 program size
        PSIZE1: u2,
        /// Bank 1 write forcing control bit
        FW1: u1,
        /// Bank 1 bank or sector erase start control bit
        START1: u1,
        /// Bank 1 sector erase selection number
        SNB1: u3,
        reserved15: u4 = 0,
        /// Bank 1 CRC control bit
        CRC_EN: u1,
        /// Bank 1 end-of-program interrupt control bit
        EOPIE1: u1,
        /// Bank 1 write protection error interrupt enable bit
        WRPERRIE1: u1,
        /// Bank 1 programming sequence error interrupt enable bit
        PGSERRIE1: u1,
        /// Bank 1 strobe error interrupt enable bit
        STRBERRIE1: u1,
        reserved21: u1 = 0,
        /// Bank 1 inconsistency error interrupt enable bit
        INCERRIE1: u1,
        /// Bank 1 write/erase error interrupt enable bit
        OPERRIE1: u1,
        /// Bank 1 read protection error interrupt enable bit
        RDPERRIE1: u1,
        /// Bank 1 secure error interrupt enable bit
        RDSERRIE1: u1,
        /// Bank 1 ECC single correction error interrupt enable bit
        SNECCERRIE1: u1,
        /// Bank 1 ECC double detection error interrupt enable bit
        DBECCERRIE1: u1,
        /// Bank 1 end of CRC calculation interrupt enable bit
        CRCENDIE1: u1,
        padding: u4 = 0,
    }),
    /// FLASH status register for bank 1
    /// offset: 0x10
    SR1: mmio.Mmio(packed struct(u32) {
        /// Bank 1 ongoing program flag
        BSY1: u1,
        /// Bank 1 write buffer not empty flag
        WBNE1: u1,
        /// Bank 1 wait queue flag
        QW1: u1,
        /// Bank 1 CRC busy flag
        CRC_BUSY1: u1,
        reserved16: u12 = 0,
        /// Bank 1 end-of-program flag
        EOP1: u1,
        /// Bank 1 write protection error flag
        WRPERR1: u1,
        /// Bank 1 programming sequence error flag
        PGSERR1: u1,
        /// Bank 1 strobe error flag
        STRBERR1: u1,
        reserved21: u1 = 0,
        /// Bank 1 inconsistency error flag
        INCERR1: u1,
        /// Bank 1 write/erase error flag
        OPERR1: u1,
        /// Bank 1 read protection error flag
        RDPERR1: u1,
        /// Bank 1 secure error flag
        RDSERR1: u1,
        /// Bank 1 single correction error flag
        SNECCERR11: u1,
        /// Bank 1 ECC double detection error flag
        DBECCERR1: u1,
        /// Bank 1 CRC-complete flag
        CRCEND1: u1,
        padding: u4 = 0,
    }),
    /// FLASH clear control register for bank 1
    /// offset: 0x14
    CCR1: mmio.Mmio(packed struct(u32) {
        reserved16: u16 = 0,
        /// Bank 1 EOP1 flag clear bit
        CLR_EOP1: u1,
        /// Bank 1 WRPERR1 flag clear bit
        CLR_WRPERR1: u1,
        /// Bank 1 PGSERR1 flag clear bi
        CLR_PGSERR1: u1,
        /// Bank 1 STRBERR1 flag clear bit
        CLR_STRBERR1: u1,
        reserved21: u1 = 0,
        /// Bank 1 INCERR1 flag clear bit
        CLR_INCERR1: u1,
        /// Bank 1 OPERR1 flag clear bit
        CLR_OPERR1: u1,
        /// Bank 1 RDPERR1 flag clear bit
        CLR_RDPERR1: u1,
        /// Bank 1 RDSERR1 flag clear bit
        CLR_RDSERR1: u1,
        /// Bank 1 SNECCERR1 flag clear bit
        CLR_SNECCERR1: u1,
        /// Bank 1 DBECCERR1 flag clear bit
        CLR_DBECCERR1: u1,
        /// Bank 1 CRCEND1 flag clear bit
        CLR_CRCEND1: u1,
        padding: u4 = 0,
    }),
    /// FLASH option control register
    /// offset: 0x18
    OPTCR: mmio.Mmio(packed struct(u32) {
        /// FLASH_OPTCR lock option configuration bit
        OPTLOCK: u1,
        /// Option byte start change option configuration bit
        OPTSTART: u1,
        reserved4: u2 = 0,
        /// Flash mass erase enable bit
        MER: u1,
        reserved30: u25 = 0,
        /// Option byte change error interrupt enable bit
        OPTCHANGEERRIE: u1,
        /// Bank swapping configuration bit
        SWAP_BANK: u1,
    }),
    /// FLASH option status register
    /// offset: 0x1c
    OPTSR_CUR: mmio.Mmio(packed struct(u32) {
        /// Option byte change ongoing flag
        OPT_BUSY: u1,
        reserved2: u1 = 0,
        /// Brownout level option status bit
        BOR_LEV: u2,
        /// IWDG1 control option status bit
        IWDG1_HW: u1,
        reserved6: u1 = 0,
        /// D1 DStop entry reset option status bit
        nRST_STOP_D1: u1,
        /// D1 DStandby entry reset option status bit
        nRST_STBY_D1: u1,
        /// Readout protection level option status byte
        RDP: u8,
        reserved17: u1 = 0,
        /// IWDG Stop mode freeze option status bit
        FZ_IWDG_STOP: u1,
        /// IWDG Standby mode freeze option status bit
        FZ_IWDG_SDBY: u1,
        /// DTCM RAM size option status
        ST_RAM_SIZE: u2,
        /// Security enable option status bit
        SECURITY: u1,
        reserved26: u4 = 0,
        /// User option bit 1
        RSS1: u1,
        reserved28: u1 = 0,
        /// Device personalization status bit
        PERSO_OK: u1,
        /// I/O high-speed at low-voltage status bit (PRODUCT_BELOW_25V)
        IO_HSLV: u1,
        /// Option byte change error flag
        OPTCHANGEERR: u1,
        /// Bank swapping option status bit
        SWAP_BANK_OPT: u1,
    }),
    /// FLASH option status register
    /// offset: 0x20
    OPTSR_PRG: mmio.Mmio(packed struct(u32) {
        reserved2: u2 = 0,
        /// BOR reset level option configuration bits
        BOR_LEV: u2,
        /// IWDG1 option configuration bit
        IWDG1_HW: u1,
        reserved6: u1 = 0,
        /// Option byte erase after D1 DStop option configuration bit
        nRST_STOP_D1: u1,
        /// Option byte erase after D1 DStandby option configuration bit
        nRST_STBY_D1: u1,
        /// Readout protection level option configuration byte
        RDP: u8,
        reserved17: u1 = 0,
        /// IWDG Stop mode freeze option configuration bit
        FZ_IWDG_STOP: u1,
        /// IWDG Standby mode freeze option configuration bit
        FZ_IWDG_SDBY: u1,
        /// DTCM size select option configuration bits
        ST_RAM_SIZE: u2,
        /// Security option configuration bit
        SECURITY: u1,
        reserved26: u4 = 0,
        /// User option configuration bit 1
        RSS1: u1,
        /// User option configuration bit 2
        RSS2: u1,
        reserved29: u1 = 0,
        /// I/O high-speed at low-voltage (PRODUCT_BELOW_25V)
        IO_HSLV: u1,
        reserved31: u1 = 0,
        /// Bank swapping option configuration bit
        SWAP_BANK_OPT: u1,
    }),
    /// FLASH option clear control register
    /// offset: 0x24
    OPTCCR: mmio.Mmio(packed struct(u32) {
        reserved30: u30 = 0,
        /// OPTCHANGEERR reset bit
        CLR_OPTCHANGEERR: u1,
        padding: u1 = 0,
    }),
    /// FLASH protection address for bank 1
    /// offset: 0x28
    PRAR_CUR1: mmio.Mmio(packed struct(u32) {
        /// Bank 1 lowest PCROP protected address
        PROT_AREA_START1: u12,
        reserved16: u4 = 0,
        /// Bank 1 highest PCROP protected address
        PROT_AREA_END1: u12,
        reserved31: u3 = 0,
        /// Bank 1 PCROP protected erase enable option status bit
        DMEP1: u1,
    }),
    /// FLASH protection address for bank 1
    /// offset: 0x2c
    PRAR_PRG1: mmio.Mmio(packed struct(u32) {
        /// Bank 1 lowest PCROP protected address configuration
        PROT_AREA_START1: u12,
        reserved16: u4 = 0,
        /// Bank 1 highest PCROP protected address configuration
        PROT_AREA_END1: u12,
        reserved31: u3 = 0,
        /// Bank 1 PCROP protected erase enable option configuration bit
        DMEP1: u1,
    }),
    /// FLASH secure address for bank 1
    /// offset: 0x30
    SCAR_CUR1: mmio.Mmio(packed struct(u32) {
        /// Bank 1 lowest secure protected address
        SEC_AREA_START1: u12,
        reserved16: u4 = 0,
        /// Bank 1 highest secure protected address
        SEC_AREA_END1: u12,
        reserved31: u3 = 0,
        /// Bank 1 secure protected erase enable option status bit
        DMES1: u1,
    }),
    /// FLASH secure address for bank 1
    /// offset: 0x34
    SCAR_PRG1: mmio.Mmio(packed struct(u32) {
        /// Bank 1 lowest secure protected address configuration
        SEC_AREA_START1: u12,
        reserved16: u4 = 0,
        /// Bank 1 highest secure protected address configuration
        SEC_AREA_END1: u12,
        reserved31: u3 = 0,
        /// Bank 1 secure protected erase enable option configuration bit
        DMES1: u1,
    }),
    /// FLASH write sector protection for bank 1
    /// offset: 0x38
    WPSN_CUR1R: mmio.Mmio(packed struct(u32) {
        /// Bank 1 sector write protection option status byte
        WRPSn1: u8,
        padding: u24 = 0,
    }),
    /// FLASH write sector protection for bank 1
    /// offset: 0x3c
    WPSN_PRG1R: mmio.Mmio(packed struct(u32) {
        /// Bank 1 sector write protection configuration byte
        WRPSn1: u8,
        padding: u24 = 0,
    }),
    /// FLASH register with boot address
    /// offset: 0x40
    BOOT_CURR: mmio.Mmio(packed struct(u32) {
        /// Boot address 0
        BOOT_ADD0: u16,
        /// Boot address 1
        BOOT_ADD1: u16,
    }),
    /// FLASH register with boot address
    /// offset: 0x44
    BOOT_PRGR: mmio.Mmio(packed struct(u32) {
        /// Boot address 0
        BOOT_ADD0: u16,
        /// Boot address 1
        BOOT_ADD1: u16,
    }),
    /// offset: 0x48
    reserved72: [8]u8,
    /// FLASH CRC control register for bank 1
    /// offset: 0x50
    CRCCR1: mmio.Mmio(packed struct(u32) {
        /// Bank 1 CRC sector number
        CRC_SECT: u3,
        reserved7: u4 = 0,
        /// Bank 1 CRC select bit
        ALL_BANK: u1,
        /// Bank 1 CRC sector mode select bit
        CRC_BY_SECT: u1,
        /// Bank 1 CRC sector select bit
        ADD_SECT: u1,
        /// Bank 1 CRC sector list clear bit
        CLEAN_SECT: u1,
        reserved16: u5 = 0,
        /// Bank 1 CRC start bit
        START_CRC: u1,
        /// Bank 1 CRC clear bit
        CLEAN_CRC: u1,
        reserved20: u2 = 0,
        /// Bank 1 CRC burst size
        CRC_BURST: u2,
        padding: u10 = 0,
    }),
    /// FLASH CRC start address register for bank 1
    /// offset: 0x54
    CRCSADD1R: mmio.Mmio(packed struct(u32) {
        /// CRC start address on bank 1
        CRC_START_ADDR: u32,
    }),
    /// FLASH CRC end address register for bank 1
    /// offset: 0x58
    CRCEADD1R: mmio.Mmio(packed struct(u32) {
        /// CRC end address on bank 1
        CRC_END_ADDR: u32,
    }),
    /// FLASH CRC data register
    /// offset: 0x5c
    CRCDATAR: mmio.Mmio(packed struct(u32) {
        /// CRC result
        CRC_DATA: u32,
    }),
    /// FLASH ECC fail address for bank 1
    /// offset: 0x60
    ECC_FA1R: mmio.Mmio(packed struct(u32) {
        /// Bank 1 ECC error address
        FAIL_ECC_ADDR1: u15,
        padding: u17 = 0,
    }),
    /// offset: 0x64
    reserved100: [156]u8,
    /// Access control register
    /// offset: 0x100
    ACR_: mmio.Mmio(packed struct(u32) {
        /// Read latency
        LATENCY: u3,
        reserved4: u1 = 0,
        /// Flash signal delay
        WRHIGHFREQ: u2,
        padding: u26 = 0,
    }),
    /// FLASH key register for bank 2
    /// offset: 0x104
    KEYR2: mmio.Mmio(packed struct(u32) {
        /// Bank 2 access configuration unlock key
        KEYR2: u32,
    }),
    /// FLASH option key register
    /// offset: 0x108
    OPTKEYR_: mmio.Mmio(packed struct(u32) {
        /// Unlock key option bytes
        OPTKEYR: u32,
    }),
    /// FLASH control register for bank 2
    /// offset: 0x10c
    CR2: mmio.Mmio(packed struct(u32) {
        /// Bank 2 configuration lock bit
        LOCK2: u1,
        /// Bank 2 program enable bit
        PG2: u1,
        /// Bank 2 sector erase request
        SER2: u1,
        /// Bank 2 erase request
        BER2: u1,
        /// Bank 2 program size
        PSIZE2: u2,
        /// Bank 2 write forcing control bit
        FW2: u1,
        /// Bank 2 bank or sector erase start control bit
        START2: u1,
        /// Bank 2 sector erase selection number
        SNB2: u3,
        reserved15: u4 = 0,
        /// Bank 2 CRC control bit
        CRC_EN: u1,
        /// Bank 2 end-of-program interrupt control bit
        EOPIE2: u1,
        /// Bank 2 write protection error interrupt enable bit
        WRPERRIE2: u1,
        /// Bank 2 programming sequence error interrupt enable bit
        PGSERRIE2: u1,
        /// Bank 2 strobe error interrupt enable bit
        STRBERRIE2: u1,
        reserved21: u1 = 0,
        /// Bank 2 inconsistency error interrupt enable bit
        INCERRIE2: u1,
        /// Bank 2 write/erase error interrupt enable bit
        OPERRIE2: u1,
        /// Bank 2 read protection error interrupt enable bit
        RDPERRIE2: u1,
        /// Bank 2 secure error interrupt enable bit
        RDSERRIE2: u1,
        /// Bank 2 ECC single correction error interrupt enable bit
        SNECCERRIE2: u1,
        /// Bank 2 ECC double detection error interrupt enable bit
        DBECCERRIE2: u1,
        /// Bank 2 end of CRC calculation interrupt enable bit
        CRCENDIE2: u1,
        padding: u4 = 0,
    }),
    /// FLASH status register for bank 2
    /// offset: 0x110
    SR2: mmio.Mmio(packed struct(u32) {
        /// Bank 2 ongoing program flag
        BSY2: u1,
        /// Bank 2 write buffer not empty flag
        WBNE2: u1,
        /// Bank 2 wait queue flag
        QW2: u1,
        /// Bank 2 CRC busy flag
        CRC_BUSY2: u1,
        reserved16: u12 = 0,
        /// Bank 2 end-of-program flag
        EOP2: u1,
        /// Bank 2 write protection error flag
        WRPERR2: u1,
        /// Bank 2 programming sequence error flag
        PGSERR2: u1,
        /// Bank 2 strobe error flag
        STRBERR2: u1,
        reserved21: u1 = 0,
        /// Bank 2 inconsistency error flag
        INCERR2: u1,
        /// Bank 2 write/erase error flag
        OPERR2: u1,
        /// Bank 2 read protection error flag
        RDPERR2: u1,
        /// Bank 2 secure error flag
        RDSERR2: u1,
        /// Bank 2 single correction error flag
        SNECCERR2: u1,
        /// Bank 2 ECC double detection error flag
        DBECCERR2: u1,
        /// Bank 2 CRC-complete flag
        CRCEND2: u1,
        padding: u4 = 0,
    }),
    /// FLASH clear control register for bank 2
    /// offset: 0x114
    CCR2: mmio.Mmio(packed struct(u32) {
        reserved16: u16 = 0,
        /// Bank 1 EOP1 flag clear bit
        CLR_EOP2: u1,
        /// Bank 2 WRPERR1 flag clear bit
        CLR_WRPERR2: u1,
        /// Bank 2 PGSERR1 flag clear bi
        CLR_PGSERR2: u1,
        /// Bank 2 STRBERR1 flag clear bit
        CLR_STRBERR2: u1,
        reserved21: u1 = 0,
        /// Bank 2 INCERR1 flag clear bit
        CLR_INCERR2: u1,
        /// Bank 2 OPERR1 flag clear bit
        CLR_OPERR2: u1,
        /// Bank 2 RDPERR1 flag clear bit
        CLR_RDPERR2: u1,
        /// Bank 1 RDSERR1 flag clear bit
        CLR_RDSERR1: u1,
        /// Bank 2 SNECCERR1 flag clear bit
        CLR_SNECCERR2: u1,
        /// Bank 1 DBECCERR1 flag clear bit
        CLR_DBECCERR1: u1,
        /// Bank 2 CRCEND1 flag clear bit
        CLR_CRCEND2: u1,
        padding: u4 = 0,
    }),
    /// FLASH option control register
    /// offset: 0x118
    OPTCR_: mmio.Mmio(packed struct(u32) {
        /// FLASH_OPTCR lock option configuration bit
        OPTLOCK: u1,
        /// Option byte start change option configuration bit
        OPTSTART: u1,
        reserved4: u2 = 0,
        /// Flash mass erase enable bit
        MER: u1,
        reserved30: u25 = 0,
        /// Option byte change error interrupt enable bit
        OPTCHANGEERRIE: u1,
        /// Bank swapping configuration bit
        SWAP_BANK: u1,
    }),
    /// FLASH option status register
    /// offset: 0x11c
    OPTSR_CUR_: mmio.Mmio(packed struct(u32) {
        /// Option byte change ongoing flag
        OPT_BUSY: u1,
        reserved2: u1 = 0,
        /// Brownout level option status bit
        BOR_LEV: u2,
        /// IWDG1 control option status bit
        IWDG1_HW: u1,
        reserved6: u1 = 0,
        /// D1 DStop entry reset option status bit
        nRST_STOP_D1: u1,
        /// D1 DStandby entry reset option status bit
        nRST_STBY_D1: u1,
        /// Readout protection level option status byte
        RDP: u8,
        reserved17: u1 = 0,
        /// IWDG Stop mode freeze option status bit
        FZ_IWDG_STOP: u1,
        /// IWDG Standby mode freeze option status bit
        FZ_IWDG_SDBY: u1,
        /// DTCM RAM size option status
        ST_RAM_SIZE: u2,
        /// Security enable option status bit
        SECURITY: u1,
        reserved26: u4 = 0,
        /// User option bit 1
        RSS1: u1,
        reserved28: u1 = 0,
        /// Device personalization status bit
        PERSO_OK: u1,
        /// I/O high-speed at low-voltage status bit (PRODUCT_BELOW_25V)
        IO_HSLV: u1,
        /// Option byte change error flag
        OPTCHANGEERR: u1,
        /// Bank swapping option status bit
        SWAP_BANK_OPT: u1,
    }),
    /// FLASH option status register
    /// offset: 0x120
    OPTSR_PRG_: mmio.Mmio(packed struct(u32) {
        reserved2: u2 = 0,
        /// BOR reset level option configuration bits
        BOR_LEV: u2,
        /// IWDG1 option configuration bit
        IWDG1_HW: u1,
        reserved6: u1 = 0,
        /// Option byte erase after D1 DStop option configuration bit
        nRST_STOP_D1: u1,
        /// Option byte erase after D1 DStandby option configuration bit
        nRST_STBY_D1: u1,
        /// Readout protection level option configuration byte
        RDP: u8,
        reserved17: u1 = 0,
        /// IWDG Stop mode freeze option configuration bit
        FZ_IWDG_STOP: u1,
        /// IWDG Standby mode freeze option configuration bit
        FZ_IWDG_SDBY: u1,
        /// DTCM size select option configuration bits
        ST_RAM_SIZE: u2,
        /// Security option configuration bit
        SECURITY: u1,
        reserved26: u4 = 0,
        /// User option configuration bit 1
        RSS1: u1,
        /// User option configuration bit 2
        RSS2: u1,
        reserved29: u1 = 0,
        /// I/O high-speed at low-voltage (PRODUCT_BELOW_25V)
        IO_HSLV: u1,
        reserved31: u1 = 0,
        /// Bank swapping option configuration bit
        SWAP_BANK_OPT: u1,
    }),
    /// FLASH option clear control register
    /// offset: 0x124
    OPTCCR_: mmio.Mmio(packed struct(u32) {
        reserved30: u30 = 0,
        /// OPTCHANGEERR reset bit
        CLR_OPTCHANGEERR: u1,
        padding: u1 = 0,
    }),
    /// FLASH protection address for bank 1
    /// offset: 0x128
    PRAR_CUR2: mmio.Mmio(packed struct(u32) {
        /// Bank 2 lowest PCROP protected address
        PROT_AREA_START2: u12,
        reserved16: u4 = 0,
        /// Bank 2 highest PCROP protected address
        PROT_AREA_END2: u12,
        reserved31: u3 = 0,
        /// Bank 2 PCROP protected erase enable option status bit
        DMEP2: u1,
    }),
    /// offset: 0x12c
    reserved300: [4]u8,
    /// FLASH secure address for bank 2
    /// offset: 0x130
    SCAR_CUR2: mmio.Mmio(packed struct(u32) {
        /// Bank 2 lowest secure protected address
        SEC_AREA_START2: u12,
        reserved16: u4 = 0,
        /// Bank 2 highest secure protected address
        SEC_AREA_END2: u12,
        reserved31: u3 = 0,
        /// Bank 2 secure protected erase enable option status bit
        DMES2: u1,
    }),
    /// FLASH secure address for bank 2
    /// offset: 0x134
    SCAR_PRG2: mmio.Mmio(packed struct(u32) {
        /// Bank 2 lowest secure protected address configuration
        SEC_AREA_START2: u12,
        reserved16: u4 = 0,
        /// Bank 2 highest secure protected address configuration
        SEC_AREA_END2: u12,
        reserved31: u3 = 0,
        /// Bank 2 secure protected erase enable option configuration bit
        DMES2: u1,
    }),
    /// FLASH write sector protection for bank 2
    /// offset: 0x138
    WPSN_CUR2R: mmio.Mmio(packed struct(u32) {
        /// Bank 2 sector write protection option status byte
        WRPSn2: u8,
        padding: u24 = 0,
    }),
    /// FLASH write sector protection for bank 2
    /// offset: 0x13c
    WPSN_PRG2R: mmio.Mmio(packed struct(u32) {
        /// Bank 2 sector write protection configuration byte
        WRPSn2: u8,
        padding: u24 = 0,
    }),
    /// offset: 0x140
    reserved320: [16]u8,
    /// FLASH CRC control register for bank 1
    /// offset: 0x150
    CRCCR2: mmio.Mmio(packed struct(u32) {
        /// Bank 2 CRC sector number
        CRC_SECT: u3,
        reserved7: u4 = 0,
        /// Bank 2 CRC select bit
        ALL_BANK: u1,
        /// Bank 2 CRC sector mode select bit
        CRC_BY_SECT: u1,
        /// Bank 2 CRC sector select bit
        ADD_SECT: u1,
        /// Bank 2 CRC sector list clear bit
        CLEAN_SECT: u1,
        reserved16: u5 = 0,
        /// Bank 2 CRC start bit
        START_CRC: u1,
        /// Bank 2 CRC clear bit
        CLEAN_CRC: u1,
        reserved20: u2 = 0,
        /// Bank 2 CRC burst size
        CRC_BURST: u2,
        padding: u10 = 0,
    }),
    /// FLASH CRC start address register for bank 2
    /// offset: 0x154
    CRCSADD2R: mmio.Mmio(packed struct(u32) {
        /// CRC start address on bank 2
        CRC_START_ADDR: u32,
    }),
    /// FLASH CRC end address register for bank 2
    /// offset: 0x158
    CRCEADD2R: mmio.Mmio(packed struct(u32) {
        /// CRC end address on bank 2
        CRC_END_ADDR: u32,
    }),
    /// offset: 0x15c
    reserved348: [4]u8,
    /// FLASH ECC fail address for bank 2
    /// offset: 0x160
    ECC_FA2R: mmio.Mmio(packed struct(u32) {
        /// Bank 2 ECC error address
        FAIL_ECC_ADDR2: u15,
        padding: u17 = 0,
    }),
};
