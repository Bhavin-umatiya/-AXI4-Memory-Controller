`timescale 1ns / 1ps

interface cxl_if(input logic clk, input logic rst_n);

    // Request Channel
    logic         cxl_valid;
    logic [1:0]   cxl_opcode; // 1: MEM_RD, 2: MEM_WR
    logic [11:0]  cxl_addr;   // Cache-line aligned address
    logic [511:0] cxl_wdata;  // 512-bit cacheline data
    logic         cxl_ready;  // Slave backpressure

    // Response Channel
    logic         cxl_rsp_valid;
    logic [511:0] cxl_rsp_rdata;
    logic         cxl_rsp_error;

endinterface : cxl_if
