const mmio = @import("mmio");
const types = @import("../../types.zig");

/// Cryptographic processor
pub const CRYP = extern struct {
    /// control register
    /// offset: 0x00
    CR: mmio.Mmio(packed struct(u32) {
        reserved2: u2 = 0,
        /// Algorithm direction
        ALGODIR: u1,
        /// Algorithm mode
        ALGOMODE0: u3,
        /// Data type selection
        DATATYPE: u2,
        /// Key size selection (AES mode only)
        KEYSIZE: u2,
        reserved14: u4 = 0,
        /// FIFO flush
        FFLUSH: u1,
        /// Cryptographic processor enable
        CRYPEN: u1,
        /// GCM_CCMPH
        GCM_CCMPH: u2,
        reserved19: u1 = 0,
        /// ALGOMODE
        ALGOMODE3: u1,
        padding: u12 = 0,
    }),
    /// status register
    /// offset: 0x04
    SR: mmio.Mmio(packed struct(u32) {
        /// Input FIFO empty
        IFEM: u1,
        /// Input FIFO not full
        IFNF: u1,
        /// Output FIFO not empty
        OFNE: u1,
        /// Output FIFO full
        OFFU: u1,
        /// Busy bit
        BUSY: u1,
        padding: u27 = 0,
    }),
    /// data input register
    /// offset: 0x08
    DIN: mmio.Mmio(packed struct(u32) {
        /// Data input
        DATAIN: u32,
    }),
    /// data output register
    /// offset: 0x0c
    DOUT: mmio.Mmio(packed struct(u32) {
        /// Data output
        DATAOUT: u32,
    }),
    /// DMA control register
    /// offset: 0x10
    DMACR: mmio.Mmio(packed struct(u32) {
        /// DMA input enable
        DIEN: u1,
        /// DMA output enable
        DOEN: u1,
        padding: u30 = 0,
    }),
    /// interrupt mask set/clear register
    /// offset: 0x14
    IMSCR: mmio.Mmio(packed struct(u32) {
        /// Input FIFO service interrupt mask
        INIM: u1,
        /// Output FIFO service interrupt mask
        OUTIM: u1,
        padding: u30 = 0,
    }),
    /// raw interrupt status register
    /// offset: 0x18
    RISR: mmio.Mmio(packed struct(u32) {
        /// Input FIFO service raw interrupt status
        INRIS: u1,
        /// Output FIFO service raw interrupt status
        OUTRIS: u1,
        padding: u30 = 0,
    }),
    /// masked interrupt status register
    /// offset: 0x1c
    MISR: mmio.Mmio(packed struct(u32) {
        /// Input FIFO service masked interrupt status
        INMIS: u1,
        /// Output FIFO service masked interrupt status
        OUTMIS: u1,
        padding: u30 = 0,
    }),
    /// key registers
    /// offset: 0x20
    K0LR: mmio.Mmio(packed struct(u32) {
        /// b224
        b224: u1,
        /// b225
        b225: u1,
        /// b226
        b226: u1,
        /// b227
        b227: u1,
        /// b228
        b228: u1,
        /// b229
        b229: u1,
        /// b230
        b230: u1,
        /// b231
        b231: u1,
        /// b232
        b232: u1,
        /// b233
        b233: u1,
        /// b234
        b234: u1,
        /// b235
        b235: u1,
        /// b236
        b236: u1,
        /// b237
        b237: u1,
        /// b238
        b238: u1,
        /// b239
        b239: u1,
        /// b240
        b240: u1,
        /// b241
        b241: u1,
        /// b242
        b242: u1,
        /// b243
        b243: u1,
        /// b244
        b244: u1,
        /// b245
        b245: u1,
        /// b246
        b246: u1,
        /// b247
        b247: u1,
        /// b248
        b248: u1,
        /// b249
        b249: u1,
        /// b250
        b250: u1,
        /// b251
        b251: u1,
        /// b252
        b252: u1,
        /// b253
        b253: u1,
        /// b254
        b254: u1,
        /// b255
        b255: u1,
    }),
    /// key registers
    /// offset: 0x24
    K0RR: mmio.Mmio(packed struct(u32) {
        /// b192
        b192: u1,
        /// b193
        b193: u1,
        /// b194
        b194: u1,
        /// b195
        b195: u1,
        /// b196
        b196: u1,
        /// b197
        b197: u1,
        /// b198
        b198: u1,
        /// b199
        b199: u1,
        /// b200
        b200: u1,
        /// b201
        b201: u1,
        /// b202
        b202: u1,
        /// b203
        b203: u1,
        /// b204
        b204: u1,
        /// b205
        b205: u1,
        /// b206
        b206: u1,
        /// b207
        b207: u1,
        /// b208
        b208: u1,
        /// b209
        b209: u1,
        /// b210
        b210: u1,
        /// b211
        b211: u1,
        /// b212
        b212: u1,
        /// b213
        b213: u1,
        /// b214
        b214: u1,
        /// b215
        b215: u1,
        /// b216
        b216: u1,
        /// b217
        b217: u1,
        /// b218
        b218: u1,
        /// b219
        b219: u1,
        /// b220
        b220: u1,
        /// b221
        b221: u1,
        /// b222
        b222: u1,
        /// b223
        b223: u1,
    }),
    /// key registers
    /// offset: 0x28
    K1LR: mmio.Mmio(packed struct(u32) {
        /// b160
        b160: u1,
        /// b161
        b161: u1,
        /// b162
        b162: u1,
        /// b163
        b163: u1,
        /// b164
        b164: u1,
        /// b165
        b165: u1,
        /// b166
        b166: u1,
        /// b167
        b167: u1,
        /// b168
        b168: u1,
        /// b169
        b169: u1,
        /// b170
        b170: u1,
        /// b171
        b171: u1,
        /// b172
        b172: u1,
        /// b173
        b173: u1,
        /// b174
        b174: u1,
        /// b175
        b175: u1,
        /// b176
        b176: u1,
        /// b177
        b177: u1,
        /// b178
        b178: u1,
        /// b179
        b179: u1,
        /// b180
        b180: u1,
        /// b181
        b181: u1,
        /// b182
        b182: u1,
        /// b183
        b183: u1,
        /// b184
        b184: u1,
        /// b185
        b185: u1,
        /// b186
        b186: u1,
        /// b187
        b187: u1,
        /// b188
        b188: u1,
        /// b189
        b189: u1,
        /// b190
        b190: u1,
        /// b191
        b191: u1,
    }),
    /// key registers
    /// offset: 0x2c
    K1RR: mmio.Mmio(packed struct(u32) {
        /// b128
        b128: u1,
        /// b129
        b129: u1,
        /// b130
        b130: u1,
        /// b131
        b131: u1,
        /// b132
        b132: u1,
        /// b133
        b133: u1,
        /// b134
        b134: u1,
        /// b135
        b135: u1,
        /// b136
        b136: u1,
        /// b137
        b137: u1,
        /// b138
        b138: u1,
        /// b139
        b139: u1,
        /// b140
        b140: u1,
        /// b141
        b141: u1,
        /// b142
        b142: u1,
        /// b143
        b143: u1,
        /// b144
        b144: u1,
        /// b145
        b145: u1,
        /// b146
        b146: u1,
        /// b147
        b147: u1,
        /// b148
        b148: u1,
        /// b149
        b149: u1,
        /// b150
        b150: u1,
        /// b151
        b151: u1,
        /// b152
        b152: u1,
        /// b153
        b153: u1,
        /// b154
        b154: u1,
        /// b155
        b155: u1,
        /// b156
        b156: u1,
        /// b157
        b157: u1,
        /// b158
        b158: u1,
        /// b159
        b159: u1,
    }),
    /// key registers
    /// offset: 0x30
    K2LR: mmio.Mmio(packed struct(u32) {
        /// b96
        b96: u1,
        /// b97
        b97: u1,
        /// b98
        b98: u1,
        /// b99
        b99: u1,
        /// b100
        b100: u1,
        /// b101
        b101: u1,
        /// b102
        b102: u1,
        /// b103
        b103: u1,
        /// b104
        b104: u1,
        /// b105
        b105: u1,
        /// b106
        b106: u1,
        /// b107
        b107: u1,
        /// b108
        b108: u1,
        /// b109
        b109: u1,
        /// b110
        b110: u1,
        /// b111
        b111: u1,
        /// b112
        b112: u1,
        /// b113
        b113: u1,
        /// b114
        b114: u1,
        /// b115
        b115: u1,
        /// b116
        b116: u1,
        /// b117
        b117: u1,
        /// b118
        b118: u1,
        /// b119
        b119: u1,
        /// b120
        b120: u1,
        /// b121
        b121: u1,
        /// b122
        b122: u1,
        /// b123
        b123: u1,
        /// b124
        b124: u1,
        /// b125
        b125: u1,
        /// b126
        b126: u1,
        /// b127
        b127: u1,
    }),
    /// key registers
    /// offset: 0x34
    K2RR: mmio.Mmio(packed struct(u32) {
        /// b64
        b64: u1,
        /// b65
        b65: u1,
        /// b66
        b66: u1,
        /// b67
        b67: u1,
        /// b68
        b68: u1,
        /// b69
        b69: u1,
        /// b70
        b70: u1,
        /// b71
        b71: u1,
        /// b72
        b72: u1,
        /// b73
        b73: u1,
        /// b74
        b74: u1,
        /// b75
        b75: u1,
        /// b76
        b76: u1,
        /// b77
        b77: u1,
        /// b78
        b78: u1,
        /// b79
        b79: u1,
        /// b80
        b80: u1,
        /// b81
        b81: u1,
        /// b82
        b82: u1,
        /// b83
        b83: u1,
        /// b84
        b84: u1,
        /// b85
        b85: u1,
        /// b86
        b86: u1,
        /// b87
        b87: u1,
        /// b88
        b88: u1,
        /// b89
        b89: u1,
        /// b90
        b90: u1,
        /// b91
        b91: u1,
        /// b92
        b92: u1,
        /// b93
        b93: u1,
        /// b94
        b94: u1,
        /// b95
        b95: u1,
    }),
    /// key registers
    /// offset: 0x38
    K3LR: mmio.Mmio(packed struct(u32) {
        /// b32
        b32: u1,
        /// b33
        b33: u1,
        /// b34
        b34: u1,
        /// b35
        b35: u1,
        /// b36
        b36: u1,
        /// b37
        b37: u1,
        /// b38
        b38: u1,
        /// b39
        b39: u1,
        /// b40
        b40: u1,
        /// b41
        b41: u1,
        /// b42
        b42: u1,
        /// b43
        b43: u1,
        /// b44
        b44: u1,
        /// b45
        b45: u1,
        /// b46
        b46: u1,
        /// b47
        b47: u1,
        /// b48
        b48: u1,
        /// b49
        b49: u1,
        /// b50
        b50: u1,
        /// b51
        b51: u1,
        /// b52
        b52: u1,
        /// b53
        b53: u1,
        /// b54
        b54: u1,
        /// b55
        b55: u1,
        /// b56
        b56: u1,
        /// b57
        b57: u1,
        /// b58
        b58: u1,
        /// b59
        b59: u1,
        /// b60
        b60: u1,
        /// b61
        b61: u1,
        /// b62
        b62: u1,
        /// b63
        b63: u1,
    }),
    /// key registers
    /// offset: 0x3c
    K3RR: mmio.Mmio(packed struct(u32) {
        /// b0
        b0: u1,
        /// b1
        b1: u1,
        /// b2
        b2: u1,
        /// b3
        b3: u1,
        /// b4
        b4: u1,
        /// b5
        b5: u1,
        /// b6
        b6: u1,
        /// b7
        b7: u1,
        /// b8
        b8: u1,
        /// b9
        b9: u1,
        /// b10
        b10: u1,
        /// b11
        b11: u1,
        /// b12
        b12: u1,
        /// b13
        b13: u1,
        /// b14
        b14: u1,
        /// b15
        b15: u1,
        /// b16
        b16: u1,
        /// b17
        b17: u1,
        /// b18
        b18: u1,
        /// b19
        b19: u1,
        /// b20
        b20: u1,
        /// b21
        b21: u1,
        /// b22
        b22: u1,
        /// b23
        b23: u1,
        /// b24
        b24: u1,
        /// b25
        b25: u1,
        /// b26
        b26: u1,
        /// b27
        b27: u1,
        /// b28
        b28: u1,
        /// b29
        b29: u1,
        /// b30
        b30: u1,
        /// b31
        b31: u1,
    }),
    /// initialization vector registers
    /// offset: 0x40
    IV0LR: mmio.Mmio(packed struct(u32) {
        /// IV31
        IV31: u1,
        /// IV30
        IV30: u1,
        /// IV29
        IV29: u1,
        /// IV28
        IV28: u1,
        /// IV27
        IV27: u1,
        /// IV26
        IV26: u1,
        /// IV25
        IV25: u1,
        /// IV24
        IV24: u1,
        /// IV23
        IV23: u1,
        /// IV22
        IV22: u1,
        /// IV21
        IV21: u1,
        /// IV20
        IV20: u1,
        /// IV19
        IV19: u1,
        /// IV18
        IV18: u1,
        /// IV17
        IV17: u1,
        /// IV16
        IV16: u1,
        /// IV15
        IV15: u1,
        /// IV14
        IV14: u1,
        /// IV13
        IV13: u1,
        /// IV12
        IV12: u1,
        /// IV11
        IV11: u1,
        /// IV10
        IV10: u1,
        /// IV9
        IV9: u1,
        /// IV8
        IV8: u1,
        /// IV7
        IV7: u1,
        /// IV6
        IV6: u1,
        /// IV5
        IV5: u1,
        /// IV4
        IV4: u1,
        /// IV3
        IV3: u1,
        /// IV2
        IV2: u1,
        /// IV1
        IV1: u1,
        /// IV0
        IV0: u1,
    }),
    /// initialization vector registers
    /// offset: 0x44
    IV0RR: mmio.Mmio(packed struct(u32) {
        /// IV63
        IV63: u1,
        /// IV62
        IV62: u1,
        /// IV61
        IV61: u1,
        /// IV60
        IV60: u1,
        /// IV59
        IV59: u1,
        /// IV58
        IV58: u1,
        /// IV57
        IV57: u1,
        /// IV56
        IV56: u1,
        /// IV55
        IV55: u1,
        /// IV54
        IV54: u1,
        /// IV53
        IV53: u1,
        /// IV52
        IV52: u1,
        /// IV51
        IV51: u1,
        /// IV50
        IV50: u1,
        /// IV49
        IV49: u1,
        /// IV48
        IV48: u1,
        /// IV47
        IV47: u1,
        /// IV46
        IV46: u1,
        /// IV45
        IV45: u1,
        /// IV44
        IV44: u1,
        /// IV43
        IV43: u1,
        /// IV42
        IV42: u1,
        /// IV41
        IV41: u1,
        /// IV40
        IV40: u1,
        /// IV39
        IV39: u1,
        /// IV38
        IV38: u1,
        /// IV37
        IV37: u1,
        /// IV36
        IV36: u1,
        /// IV35
        IV35: u1,
        /// IV34
        IV34: u1,
        /// IV33
        IV33: u1,
        /// IV32
        IV32: u1,
    }),
    /// initialization vector registers
    /// offset: 0x48
    IV1LR: mmio.Mmio(packed struct(u32) {
        /// IV95
        IV95: u1,
        /// IV94
        IV94: u1,
        /// IV93
        IV93: u1,
        /// IV92
        IV92: u1,
        /// IV91
        IV91: u1,
        /// IV90
        IV90: u1,
        /// IV89
        IV89: u1,
        /// IV88
        IV88: u1,
        /// IV87
        IV87: u1,
        /// IV86
        IV86: u1,
        /// IV85
        IV85: u1,
        /// IV84
        IV84: u1,
        /// IV83
        IV83: u1,
        /// IV82
        IV82: u1,
        /// IV81
        IV81: u1,
        /// IV80
        IV80: u1,
        /// IV79
        IV79: u1,
        /// IV78
        IV78: u1,
        /// IV77
        IV77: u1,
        /// IV76
        IV76: u1,
        /// IV75
        IV75: u1,
        /// IV74
        IV74: u1,
        /// IV73
        IV73: u1,
        /// IV72
        IV72: u1,
        /// IV71
        IV71: u1,
        /// IV70
        IV70: u1,
        /// IV69
        IV69: u1,
        /// IV68
        IV68: u1,
        /// IV67
        IV67: u1,
        /// IV66
        IV66: u1,
        /// IV65
        IV65: u1,
        /// IV64
        IV64: u1,
    }),
    /// initialization vector registers
    /// offset: 0x4c
    IV1RR: mmio.Mmio(packed struct(u32) {
        /// IV127
        IV127: u1,
        /// IV126
        IV126: u1,
        /// IV125
        IV125: u1,
        /// IV124
        IV124: u1,
        /// IV123
        IV123: u1,
        /// IV122
        IV122: u1,
        /// IV121
        IV121: u1,
        /// IV120
        IV120: u1,
        /// IV119
        IV119: u1,
        /// IV118
        IV118: u1,
        /// IV117
        IV117: u1,
        /// IV116
        IV116: u1,
        /// IV115
        IV115: u1,
        /// IV114
        IV114: u1,
        /// IV113
        IV113: u1,
        /// IV112
        IV112: u1,
        /// IV111
        IV111: u1,
        /// IV110
        IV110: u1,
        /// IV109
        IV109: u1,
        /// IV108
        IV108: u1,
        /// IV107
        IV107: u1,
        /// IV106
        IV106: u1,
        /// IV105
        IV105: u1,
        /// IV104
        IV104: u1,
        /// IV103
        IV103: u1,
        /// IV102
        IV102: u1,
        /// IV101
        IV101: u1,
        /// IV100
        IV100: u1,
        /// IV99
        IV99: u1,
        /// IV98
        IV98: u1,
        /// IV97
        IV97: u1,
        /// IV96
        IV96: u1,
    }),
    /// context swap register
    /// offset: 0x50
    CSGCMCCM0R: mmio.Mmio(packed struct(u32) {
        /// CSGCMCCM0R
        CSGCMCCM0R: u32,
    }),
    /// context swap register
    /// offset: 0x54
    CSGCMCCM1R: mmio.Mmio(packed struct(u32) {
        /// CSGCMCCM1R
        CSGCMCCM1R: u32,
    }),
    /// context swap register
    /// offset: 0x58
    CSGCMCCM2R: mmio.Mmio(packed struct(u32) {
        /// CSGCMCCM2R
        CSGCMCCM2R: u32,
    }),
    /// context swap register
    /// offset: 0x5c
    CSGCMCCM3R: mmio.Mmio(packed struct(u32) {
        /// CSGCMCCM3R
        CSGCMCCM3R: u32,
    }),
    /// context swap register
    /// offset: 0x60
    CSGCMCCM4R: mmio.Mmio(packed struct(u32) {
        /// CSGCMCCM4R
        CSGCMCCM4R: u32,
    }),
    /// context swap register
    /// offset: 0x64
    CSGCMCCM5R: mmio.Mmio(packed struct(u32) {
        /// CSGCMCCM5R
        CSGCMCCM5R: u32,
    }),
    /// context swap register
    /// offset: 0x68
    CSGCMCCM6R: mmio.Mmio(packed struct(u32) {
        /// CSGCMCCM6R
        CSGCMCCM6R: u32,
    }),
    /// context swap register
    /// offset: 0x6c
    CSGCMCCM7R: mmio.Mmio(packed struct(u32) {
        /// CSGCMCCM7R
        CSGCMCCM7R: u32,
    }),
    /// context swap register
    /// offset: 0x70
    CSGCM0R: mmio.Mmio(packed struct(u32) {
        /// CSGCM0R
        CSGCM0R: u32,
    }),
    /// context swap register
    /// offset: 0x74
    CSGCM1R: mmio.Mmio(packed struct(u32) {
        /// CSGCM1R
        CSGCM1R: u32,
    }),
    /// context swap register
    /// offset: 0x78
    CSGCM2R: mmio.Mmio(packed struct(u32) {
        /// CSGCM2R
        CSGCM2R: u32,
    }),
    /// context swap register
    /// offset: 0x7c
    CSGCM3R: mmio.Mmio(packed struct(u32) {
        /// CSGCM3R
        CSGCM3R: u32,
    }),
    /// context swap register
    /// offset: 0x80
    CSGCM4R: mmio.Mmio(packed struct(u32) {
        /// CSGCM4R
        CSGCM4R: u32,
    }),
    /// context swap register
    /// offset: 0x84
    CSGCM5R: mmio.Mmio(packed struct(u32) {
        /// CSGCM5R
        CSGCM5R: u32,
    }),
    /// context swap register
    /// offset: 0x88
    CSGCM6R: mmio.Mmio(packed struct(u32) {
        /// CSGCM6R
        CSGCM6R: u32,
    }),
    /// context swap register
    /// offset: 0x8c
    CSGCM7R: mmio.Mmio(packed struct(u32) {
        /// CSGCM7R
        CSGCM7R: u32,
    }),
};
