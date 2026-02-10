const microzig = @import("microzig");
const mmio = microzig.mmio;
const types = @import("../../types.zig");

pub const I2C = I2C1;

/// I2C
pub const I2C1 = extern struct {
    /// Access: No wait states, except if a write access occurs while a write access to this register is ongoing. In this case, wait states are inserted in the second write access until the previous one is completed. The latency of the second write access can be up to 2 x PCLK1 + 6 x I2CCLK.
    /// offset: 0x00
    CR1: mmio.Mmio(packed struct(u32) {
        /// Peripheral enable Note: When PE=0, the I2C SCL and SDA lines are released. Internal state machines and status bits are put back to their reset value. When cleared, PE must be kept low for at least 3 APB clock cycles.
        PE: u1,
        /// TX Interrupt enable
        TXIE: u1,
        /// RX Interrupt enable
        RXIE: u1,
        /// Address match Interrupt enable (slave only)
        ADDRIE: u1,
        /// Not acknowledge received Interrupt enable
        NACKIE: u1,
        /// STOP detection Interrupt enable
        STOPIE: u1,
        /// Transfer Complete interrupt enable Note: Any of these events will generate an interrupt: Transfer Complete (TC) Transfer Complete Reload (TCR)
        TCIE: u1,
        /// Error interrupts enable Note: Any of these errors generate an interrupt: Arbitration Loss (ARLO) Bus Error detection (BERR) Overrun/Underrun (OVR) Timeout detection (TIMEOUT) PEC error detection (PECERR) Alert pin event detection (ALERT)
        ERRIE: u1,
        /// Digital noise filter These bits are used to configure the digital noise filter on SDA and SCL input. The digital filter will filter spikes with a length of up to DNF[3:0] * tI2CCLK ... Note: If the analog filter is also enabled, the digital filter is added to the analog filter. This filter can only be programmed when the I2C is disabled (PE = 0).
        DNF: u4,
        /// Analog noise filter OFF Note: This bit can only be programmed when the I2C is disabled (PE = 0).
        ANFOFF: u1,
        reserved14: u1 = 0,
        /// DMA transmission requests enable
        TXDMAEN: u1,
        /// DMA reception requests enable
        RXDMAEN: u1,
        /// Slave byte control This bit is used to enable hardware byte control in slave mode.
        SBC: u1,
        /// Clock stretching disable This bit is used to disable clock stretching in slave mode. It must be kept cleared in master mode. Note: This bit can only be programmed when the I2C is disabled (PE = 0).
        NOSTRETCH: u1,
        /// Wakeup from Stop mode enable Note: If the Wakeup from Stop mode feature is not supported, this bit is reserved and forced by hardware to 0. Please refer to Section25.3: I2C implementation. Note: WUPEN can be set only when DNF = 0000
        WUPEN: u1,
        /// General call enable
        GCEN: u1,
        /// SMBus Host address enable Note: If the SMBus feature is not supported, this bit is reserved and forced by hardware to 0. Please refer to Section25.3: I2C implementation.
        SMBHEN: u1,
        /// SMBus Device Default address enable Note: If the SMBus feature is not supported, this bit is reserved and forced by hardware to 0. Please refer to Section25.3: I2C implementation.
        SMBDEN: u1,
        /// SMBus alert enable Device mode (SMBHEN=0): Host mode (SMBHEN=1): Note: When ALERTEN=0, the SMBA pin can be used as a standard GPIO. If the SMBus feature is not supported, this bit is reserved and forced by hardware to 0. Please refer to Section25.3: I2C implementation.
        ALERTEN: u1,
        /// PEC enable Note: If the SMBus feature is not supported, this bit is reserved and forced by hardware to 0. Please refer to Section25.3: I2C implementation.
        PECEN: u1,
        padding: u8 = 0,
    }),
    /// Access: No wait states, except if a write access occurs while a write access to this register is ongoing. In this case, wait states are inserted in the second write access until the previous one is completed. The latency of the second write access can be up to 2 x PCLK1 + 6 x I2CCLK.
    /// offset: 0x04
    CR2: mmio.Mmio(packed struct(u32) {
        /// Slave address  (master mode) In 7-bit addressing mode (ADD10 = 0): This bit is dont care In 10-bit addressing mode (ADD10 = 1): This bit should be written with bit 0 of the slave address to be sent Note: Changing these bits when the START bit is set is not allowed.
        SADD: u10,
        /// /// Slave address bit 0 (master mode) In 7-bit addressing mode (ADD10 = 0): This bit is dont care In 10-bit addressing mode (ADD10 = 1): This bit should be written with bit 0 of the slave address to be sent Note: Changing these bits when the START bit is set is not allowed.
        /// SADD0: u1,
        /// /// Slave address bit 7:1 (master mode) In 7-bit addressing mode (ADD10 = 0): These bits should be written with the 7-bit slave address to be sent In 10-bit addressing mode (ADD10 = 1): These bits should be written with bits 7:1 of the slave address to be sent. Note: Changing these bits when the START bit is set is not allowed.
        /// SADD1: u1,
        /// /// Slave address bit 7:1 (master mode) In 7-bit addressing mode (ADD10 = 0): These bits should be written with the 7-bit slave address to be sent In 10-bit addressing mode (ADD10 = 1): These bits should be written with bits 7:1 of the slave address to be sent. Note: Changing these bits when the START bit is set is not allowed.
        /// SADD2: u1,
        /// /// Slave address bit 7:1 (master mode) In 7-bit addressing mode (ADD10 = 0): These bits should be written with the 7-bit slave address to be sent In 10-bit addressing mode (ADD10 = 1): These bits should be written with bits 7:1 of the slave address to be sent. Note: Changing these bits when the START bit is set is not allowed.
        /// SADD3: u1,
        /// /// Slave address bit 7:1 (master mode) In 7-bit addressing mode (ADD10 = 0): These bits should be written with the 7-bit slave address to be sent In 10-bit addressing mode (ADD10 = 1): These bits should be written with bits 7:1 of the slave address to be sent. Note: Changing these bits when the START bit is set is not allowed.
        /// SADD4: u1,
        /// /// Slave address bit 7:1 (master mode) In 7-bit addressing mode (ADD10 = 0): These bits should be written with the 7-bit slave address to be sent In 10-bit addressing mode (ADD10 = 1): These bits should be written with bits 7:1 of the slave address to be sent. Note: Changing these bits when the START bit is set is not allowed.
        /// SADD5: u1,
        /// /// Slave address bit 7:1 (master mode) In 7-bit addressing mode (ADD10 = 0): These bits should be written with the 7-bit slave address to be sent In 10-bit addressing mode (ADD10 = 1): These bits should be written with bits 7:1 of the slave address to be sent. Note: Changing these bits when the START bit is set is not allowed.
        /// SADD6: u1,
        /// /// Slave address bit 7:1 (master mode) In 7-bit addressing mode (ADD10 = 0): These bits should be written with the 7-bit slave address to be sent In 10-bit addressing mode (ADD10 = 1): These bits should be written with bits 7:1 of the slave address to be sent. Note: Changing these bits when the START bit is set is not allowed.
        /// SADD7: u1,
        /// /// Slave address bit 9:8 (master mode) In 7-bit addressing mode (ADD10 = 0): These bits are dont care In 10-bit addressing mode (ADD10 = 1): These bits should be written with bits 9:8 of the slave address to be sent Note: Changing these bits when the START bit is set is not allowed.
        /// SADD8: u1,
        /// /// Slave address bit 9:8 (master mode) In 7-bit addressing mode (ADD10 = 0): These bits are dont care In 10-bit addressing mode (ADD10 = 1): These bits should be written with bits 9:8 of the slave address to be sent Note: Changing these bits when the START bit is set is not allowed.
        /// SADD9: u1,
        /// Transfer direction (master mode) Note: Changing this bit when the START bit is set is not allowed.
        RD_WRN: u1,
        /// 10-bit addressing mode (master mode) Note: Changing this bit when the START bit is set is not allowed.
        ADD10: u1,
        /// 10-bit address header only read direction (master receiver mode) Note: Changing this bit when the START bit is set is not allowed.
        HEAD10R: u1,
        /// Start generation This bit is set by software, and cleared by hardware after the Start followed by the address sequence is sent, by an arbitration loss, by a timeout error detection, or when PE = 0. It can also be cleared by software by writing 1 to the ADDRCF bit in the ICR register. If the I2C is already in master mode with AUTOEND = 0, setting this bit generates a Repeated Start condition when RELOAD=0, after the end of the NBYTES transfer. Otherwise setting this bit will generate a START condition once the bus is free. Note: Writing 0 to this bit has no effect. The START bit can be set even if the bus is BUSY or I2C is in slave mode. This bit has no effect when RELOAD is set.
        START: u1,
        /// Stop generation (master mode) The bit is set by software, cleared by hardware when a Stop condition is detected, or when PE = 0. In Master Mode: Note: Writing 0 to this bit has no effect.
        STOP: u1,
        /// NACK generation (slave mode) The bit is set by software, cleared by hardware when the NACK is sent, or when a STOP condition or an Address matched is received, or when PE=0. Note: Writing 0 to this bit has no effect. This bit is used in slave mode only: in master receiver mode, NACK is automatically generated after last byte preceding STOP or RESTART condition, whatever the NACK bit value. When an overrun occurs in slave receiver NOSTRETCH mode, a NACK is automatically generated whatever the NACK bit value. When hardware PEC checking is enabled (PECBYTE=1), the PEC acknowledge value does not depend on the NACK value.
        NACK: u1,
        /// Number of bytes The number of bytes to be transmitted/received is programmed there. This field is dont care in slave mode with SBC=0. Note: Changing these bits when the START bit is set is not allowed.
        NBYTES: u8,
        /// NBYTES reload mode This bit is set and cleared by software.
        RELOAD: u1,
        /// Automatic end mode (master mode) This bit is set and cleared by software. Note: This bit has no effect in slave mode or when the RELOAD bit is set.
        AUTOEND: u1,
        /// Packet error checking byte This bit is set by software, and cleared by hardware when the PEC is transferred, or when a STOP condition or an Address matched is received, also when PE=0. Note: Writing 0 to this bit has no effect. This bit has no effect when RELOAD is set. This bit has no effect is slave mode when SBC=0. If the SMBus feature is not supported, this bit is reserved and forced by hardware to 0. Please refer to Section25.3: I2C implementation.
        PECBYTE: u1,
        padding: u5 = 0,
    }),
    /// Access: No wait states, except if a write access occurs while a write access to this register is ongoing. In this case, wait states are inserted in the second write access until the previous one is completed. The latency of the second write access can be up to 2 x PCLK1 + 6 x I2CCLK.
    /// offset: 0x08
    OAR1: mmio.Mmio(packed struct(u32) {
        /// Interface address 7-bit addressing mode: dont care 10-bit addressing mode: bits 9:8 of address Note: These bits can be written only when OA1EN=0. OA1[7:1]: Interface address Bits 7:1 of address Note: These bits can be written only when OA1EN=0. OA1[0]: Interface address 7-bit addressing mode: dont care 10-bit addressing mode: bit 0 of address Note: This bit can be written only when OA1EN=0.
        OA1: u10,
        /// Own Address 1 10-bit mode Note: This bit can be written only when OA1EN=0.
        OA1MODE: u1,
        reserved15: u4 = 0,
        /// Own Address 1 enable
        OA1EN: u1,
        padding: u16 = 0,
    }),
    /// Access: No wait states, except if a write access occurs while a write access to this register is ongoing. In this case, wait states are inserted in the second write access until the previous one is completed. The latency of the second write access can be up to 2 x PCLK1 + 6 x I2CCLK.
    /// offset: 0x0c
    OAR2: mmio.Mmio(packed struct(u32) {
        reserved1: u1 = 0,
        /// Interface address bits 7:1 of address Note: These bits can be written only when OA2EN=0.
        OA2: u7,
        /// Own Address 2 masks Note: These bits can be written only when OA2EN=0. As soon as OA2MSK is not equal to 0, the reserved I2C addresses (0b0000xxx and 0b1111xxx) are not acknowledged even if the comparison matches.
        OA2MSK: u3,
        reserved15: u4 = 0,
        /// Own Address 2 enable
        OA2EN: u1,
        padding: u16 = 0,
    }),
    /// Access: No wait states
    /// offset: 0x10
    TIMINGR: mmio.Mmio(packed struct(u32) {
        /// SCL low period (master mode) This field is used to generate the SCL low period in master mode. tSCLL = (SCLL+1) x tPRESC Note: SCLL is also used to generate tBUF and tSU:STA timings.
        SCLL: u8,
        /// SCL high period (master mode) This field is used to generate the SCL high period in master mode. tSCLH = (SCLH+1) x tPRESC Note: SCLH is also used to generate tSU:STO and tHD:STA timing.
        SCLH: u8,
        /// Data hold time This field is used to generate the delay tSDADEL between SCL falling edge and SDA edge. In master mode and in slave mode with NOSTRETCH = 0, the SCL line is stretched low during tSDADEL. tSDADEL= SDADEL x tPRESC Note: SDADEL is used to generate tHD:DAT timing.
        SDADEL: u4,
        /// Data setup time This field is used to generate a delay tSCLDEL between SDA edge and SCL rising edge. In master mode and in slave mode with NOSTRETCH = 0, the SCL line is stretched low during tSCLDEL. tSCLDEL = (SCLDEL+1) x tPRESC Note: tSCLDEL is used to generate tSU:DAT timing.
        SCLDEL: u4,
        reserved28: u4 = 0,
        /// Timing prescaler This field is used to prescale I2CCLK in order to generate the clock period tPRESC used for data setup and hold counters (refer to I2C timings on page9) and for SCL high and low level counters (refer to I2C master initialization on page24). tPRESC = (PRESC+1) x tI2CCLK
        PRESC: u4,
    }),
    /// Access: No wait states, except if a write access occurs while a write access to this register is ongoing. In this case, wait states are inserted in the second write access until the previous one is completed. The latency of the second write access can be up to 2 x PCLK1 + 6 x I2CCLK.
    /// offset: 0x14
    TIMEOUTR: mmio.Mmio(packed struct(u32) {
        /// Bus Timeout A This field is used to configure: The SCL low timeout condition tTIMEOUT when TIDLE=0 tTIMEOUT= (TIMEOUTA+1) x 2048 x tI2CCLK The bus idle condition (both SCL and SDA high) when TIDLE=1 tIDLE= (TIMEOUTA+1) x 4 x tI2CCLK Note: These bits can be written only when TIMOUTEN=0.
        TIMEOUTA: u12,
        /// Idle clock timeout detection Note: This bit can be written only when TIMOUTEN=0.
        TIDLE: u1,
        reserved15: u2 = 0,
        /// Clock timeout enable
        TIMOUTEN: u1,
        /// Bus timeout B This field is used to configure the cumulative clock extension timeout: In master mode, the master cumulative clock low extend time (tLOW:MEXT) is detected In slave mode, the slave cumulative clock low extend time (tLOW:SEXT) is detected tLOW:EXT= (TIMEOUTB+1) x 2048 x tI2CCLK Note: These bits can be written only when TEXTEN=0.
        TIMEOUTB: u12,
        reserved31: u3 = 0,
        /// Extended clock timeout enable
        TEXTEN: u1,
    }),
    /// Access: No wait states
    /// offset: 0x18
    ISR: mmio.Mmio(packed struct(u32) {
        /// Transmit data register empty (transmitters) This bit is set by hardware when the TXDR register is empty. It is cleared when the next data to be sent is written in the TXDR register. This bit can be written to 1 by software in order to flush the transmit data register TXDR. Note: This bit is set by hardware when PE=0.
        TXE: u1,
        /// Transmit interrupt status (transmitters) This bit is set by hardware when the TXDR register is empty and the data to be transmitted must be written in the TXDR register. It is cleared when the next data to be sent is written in the TXDR register. This bit can be written to 1 by software when NOSTRETCH=1 only, in order to generate a TXIS event (interrupt if TXIE=1 or DMA request if TXDMAEN=1). Note: This bit is cleared by hardware when PE=0.
        TXIS: u1,
        /// Receive data register not empty (receivers) This bit is set by hardware when the received data is copied into the RXDR register, and is ready to be read. It is cleared when RXDR is read. Note: This bit is cleared by hardware when PE=0.
        RXNE: u1,
        /// Address matched (slave mode) This bit is set by hardware as soon as the received slave address matched with one of the enabled slave addresses. It is cleared by software by setting ADDRCF bit. Note: This bit is cleared by hardware when PE=0.
        ADDR: u1,
        /// Not Acknowledge received flag This flag is set by hardware when a NACK is received after a byte transmission. It is cleared by software by setting the NACKCF bit. Note: This bit is cleared by hardware when PE=0.
        NACKF: u1,
        /// Stop detection flag This flag is set by hardware when a Stop condition is detected on the bus and the peripheral is involved in this transfer: either as a master, provided that the STOP condition is generated by the peripheral. or as a slave, provided that the peripheral has been addressed previously during this transfer. It is cleared by software by setting the STOPCF bit. Note: This bit is cleared by hardware when PE=0.
        STOPF: u1,
        /// Transfer Complete (master mode) This flag is set by hardware when RELOAD=0, AUTOEND=0 and NBYTES data have been transferred. It is cleared by software when START bit or STOP bit is set. Note: This bit is cleared by hardware when PE=0.
        TC: u1,
        /// Transfer Complete Reload This flag is set by hardware when RELOAD=1 and NBYTES data have been transferred. It is cleared by software when NBYTES is written to a non-zero value. Note: This bit is cleared by hardware when PE=0. This flag is only for master mode, or for slave mode when the SBC bit is set.
        TCR: u1,
        /// Bus error This flag is set by hardware when a misplaced Start or Stop condition is detected whereas the peripheral is involved in the transfer. The flag is not set during the address phase in slave mode. It is cleared by software by setting BERRCF bit. Note: This bit is cleared by hardware when PE=0.
        BERR: u1,
        /// Arbitration lost This flag is set by hardware in case of arbitration loss. It is cleared by software by setting the ARLOCF bit. Note: This bit is cleared by hardware when PE=0.
        ARLO: u1,
        /// Overrun/Underrun (slave mode) This flag is set by hardware in slave mode with NOSTRETCH=1, when an overrun/underrun error occurs. It is cleared by software by setting the OVRCF bit. Note: This bit is cleared by hardware when PE=0.
        OVR: u1,
        /// PEC Error in reception This flag is set by hardware when the received PEC does not match with the PEC register content. A NACK is automatically sent after the wrong PEC reception. It is cleared by software by setting the PECCF bit. Note: This bit is cleared by hardware when PE=0. If the SMBus feature is not supported, this bit is reserved and forced by hardware to 0. Please refer to Section25.3: I2C implementation.
        PECERR: u1,
        /// Timeout or tLOW detection flag This flag is set by hardware when a timeout or extended clock timeout occurred. It is cleared by software by setting the TIMEOUTCF bit. Note: This bit is cleared by hardware when PE=0. If the SMBus feature is not supported, this bit is reserved and forced by hardware to 0. Please refer to Section25.3: I2C implementation.
        TIMEOUT: u1,
        /// SMBus alert This flag is set by hardware when SMBHEN=1 (SMBus host configuration), ALERTEN=1 and a SMBALERT event (falling edge) is detected on SMBA pin. It is cleared by software by setting the ALERTCF bit. Note: This bit is cleared by hardware when PE=0. If the SMBus feature is not supported, this bit is reserved and forced by hardware to 0. Please refer to Section25.3: I2C implementation.
        ALERT: u1,
        reserved15: u1 = 0,
        /// Bus busy This flag indicates that a communication is in progress on the bus. It is set by hardware when a START condition is detected. It is cleared by hardware when a Stop condition is detected, or when PE=0.
        BUSY: u1,
        /// Transfer direction (Slave mode) This flag is updated when an address match event occurs (ADDR=1).
        DIR: u1,
        /// Address match code (Slave mode) These bits are updated with the received address when an address match event occurs (ADDR = 1). In the case of a 10-bit address, ADDCODE provides the 10-bit header followed by the 2 MSBs of the address.
        ADDCODE: u7,
        padding: u8 = 0,
    }),
    /// Access: No wait states
    /// offset: 0x1c
    ICR: mmio.Mmio(packed struct(u32) {
        reserved3: u3 = 0,
        /// Address matched flag clear Writing 1 to this bit clears the ADDR flag in the ISR register. Writing 1 to this bit also clears the START bit in the CR2 register.
        ADDRCF: u1,
        /// Not Acknowledge flag clear Writing 1 to this bit clears the ACKF flag in ISR register.
        NACKCF: u1,
        /// Stop detection flag clear Writing 1 to this bit clears the STOPF flag in the ISR register.
        STOPCF: u1,
        reserved8: u2 = 0,
        /// Bus error flag clear Writing 1 to this bit clears the BERRF flag in the ISR register.
        BERRCF: u1,
        /// Arbitration Lost flag clear Writing 1 to this bit clears the ARLO flag in the ISR register.
        ARLOCF: u1,
        /// Overrun/Underrun flag clear Writing 1 to this bit clears the OVR flag in the ISR register.
        OVRCF: u1,
        /// PEC Error flag clear Writing 1 to this bit clears the PECERR flag in the ISR register. Note: If the SMBus feature is not supported, this bit is reserved and forced by hardware to 0. Please refer to Section25.3: I2C implementation.
        PECCF: u1,
        /// Timeout detection flag clear Writing 1 to this bit clears the TIMEOUT flag in the ISR register. Note: If the SMBus feature is not supported, this bit is reserved and forced by hardware to 0. Please refer to Section25.3: I2C implementation.
        TIMOUTCF: u1,
        /// Alert flag clear Writing 1 to this bit clears the ALERT flag in the ISR register. Note: If the SMBus feature is not supported, this bit is reserved and forced by hardware to 0. Please refer to Section25.3: I2C implementation.
        ALERTCF: u1,
        padding: u18 = 0,
    }),
    /// Access: No wait states
    /// offset: 0x20
    PECR: mmio.Mmio(packed struct(u32) {
        /// Packet error checking register This field contains the internal PEC when PECEN=1. The PEC is cleared by hardware when PE=0.
        PEC: u8,
        padding: u24 = 0,
    }),
    /// Access: No wait states
    /// offset: 0x24
    RXDR: mmio.Mmio(packed struct(u32) {
        /// 8-bit receive data Data byte received from the I2C bus.
        RXDATA: u8,
        padding: u24 = 0,
    }),
    /// Access: No wait states
    /// offset: 0x28
    TXDR: mmio.Mmio(packed struct(u32) {
        /// 8-bit transmit data Data byte to be transmitted to the I2C bus. Note: These bits can be written only when TXE=1.
        TXDATA: u8,
        padding: u24 = 0,
    }),
};
