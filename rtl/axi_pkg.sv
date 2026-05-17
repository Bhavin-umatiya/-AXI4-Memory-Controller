`timescale 1ns / 1ps

package axi_pkg;

    // AXI4 Burst Types
    typedef enum logic [1:0] {
        BURST_FIXED = 2'b00,
        BURST_INCR  = 2'b01,
        BURST_WRAP  = 2'b10,
        BURST_RSVD  = 2'b11
    } axi_burst_t;

    // AXI4 Response Types
    typedef enum logic [1:0] {
        RESP_OKAY   = 2'b00,
        RESP_EXOKAY = 2'b01,
        RESP_SLVERR = 2'b10,
        RESP_DECERR = 2'b11
    } axi_resp_t;

    // AXI4 AxSize (Bytes per transfer)
    typedef enum logic [2:0] {
        SIZE_1B    = 3'b000,
        SIZE_2B    = 3'b001,
        SIZE_4B    = 3'b010,
        SIZE_8B    = 3'b011,
        SIZE_16B   = 3'b100,
        SIZE_32B   = 3'b101,
        SIZE_64B   = 3'b110,
        SIZE_128B  = 3'b111
    } axi_size_t;

endpackage : axi_pkg
