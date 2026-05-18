`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import axi_pkg::*;
import axi_uvm_pkg::*;

module top;

    logic clk;
    logic rst_n;

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    // Reset generation
    initial begin
        rst_n = 0;
        #20 rst_n = 1;
    end

    // Instantiate CXL Interface
    cxl_if cxl_vif(clk, rst_n);

    // Instantiate AXI Interface (Internal bus between adapter and slave)
    axi_if axi_vif(clk, rst_n);

    // Instantiate CXL.mem to AXI4 Adapter
    cxl_mem_adapter u_cxl_adapter (
        .clk(clk),
        .rst_n(rst_n),

        // CXL.mem Interface
        .cxl_valid(cxl_vif.cxl_valid),
        .cxl_opcode(cxl_vif.cxl_opcode),
        .cxl_addr(cxl_vif.cxl_addr),
        .cxl_wdata(cxl_vif.cxl_wdata),
        .cxl_ready(cxl_vif.cxl_ready),

        .cxl_rsp_valid(cxl_vif.cxl_rsp_valid),
        .cxl_rsp_rdata(cxl_vif.cxl_rsp_rdata),
        .cxl_rsp_error(cxl_vif.cxl_rsp_error),

        // AXI4 Master Interface
        .m_awid(axi_vif.awid),
        .m_awaddr(axi_vif.awaddr),
        .m_awlen(axi_vif.awlen),
        .m_awsize(axi_vif.awsize),
        .m_awburst(axi_vif.awburst),
        .m_awvalid(axi_vif.awvalid),
        .m_awready(axi_vif.awready),

        .m_wdata(axi_vif.wdata),
        .m_wstrb(axi_vif.wstrb),
        .m_wlast(axi_vif.wlast),
        .m_wvalid(axi_vif.wvalid),
        .m_wready(axi_vif.wready),

        .m_bid(axi_vif.bid),
        .m_bresp(axi_vif.bresp),
        .m_bvalid(axi_vif.bvalid),
        .m_bready(axi_vif.bready),

        .m_arid(axi_vif.arid),
        .m_araddr(axi_vif.araddr),
        .m_arlen(axi_vif.arlen),
        .m_arsize(axi_vif.arsize),
        .m_arburst(axi_vif.arburst),
        .m_arvalid(axi_vif.arvalid),
        .m_arready(axi_vif.arready),

        .m_rid(axi_vif.rid),
        .m_rdata(axi_vif.rdata),
        .m_rresp(axi_vif.rresp),
        .m_rlast(axi_vif.rlast),
        .m_rvalid(axi_vif.rvalid),
        .m_rready(axi_vif.rready)
    );

    // Instantiate AXI Slave RTL
    axi4_slave #(
        .ID_WIDTH(4),
        .ADDR_WIDTH(12),
        .DATA_WIDTH(32)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

        // Write Address Channel
        .awid(axi_vif.awid),
        .awaddr(axi_vif.awaddr),
        .awlen(axi_vif.awlen),
        .awsize(axi_vif.awsize),
        .awburst(axi_vif.awburst),
        .awvalid(axi_vif.awvalid),
        .awready(axi_vif.awready),

        // Write Data Channel
        .wdata(axi_vif.wdata),
        .wstrb(axi_vif.wstrb),
        .wlast(axi_vif.wlast),
        .wvalid(axi_vif.wvalid),
        .wready(axi_vif.wready),

        // Write Response Channel
        .bid(axi_vif.bid),
        .bresp(axi_vif.bresp),
        .bvalid(axi_vif.bvalid),
        .bready(axi_vif.bready),

        // Read Address Channel
        .arid(axi_vif.arid),
        .araddr(axi_vif.araddr),
        .arlen(axi_vif.arlen),
        .arsize(axi_vif.arsize),
        .arburst(axi_vif.arburst),
        .arvalid(axi_vif.arvalid),
        .arready(axi_vif.arready),

        // Read Data Channel
        .rid(axi_vif.rid),
        .rdata(axi_vif.rdata),
        .rresp(axi_vif.rresp),
        .rlast(axi_vif.rlast),
        .rvalid(axi_vif.rvalid),
        .rready(axi_vif.rready)
    );

    // Start UVM Simulation
    initial begin
        // Pass CXL virtual interface to configuration DB
        uvm_config_db#(virtual cxl_if)::set(null, "*", "vif", cxl_vif);
        
        // Start test
        run_test("axi_test");
    end

    // Timeout watchdog
    initial begin
        #1000000; // 1ms timeout to allow 1,000 full testcycles
        `uvm_fatal("TOP", "Simulation Timeout!")
    end

endmodule : top
