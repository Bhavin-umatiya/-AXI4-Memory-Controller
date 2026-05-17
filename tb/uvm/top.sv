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

    // Instantiate AXI Interface
    axi_if vif(clk, rst_n);

    // Instantiate AXI Slave RTL
    axi4_slave #(
        .ID_WIDTH(4),
        .ADDR_WIDTH(12),
        .DATA_WIDTH(32)
    ) dut (
        .clk(vif.clk),
        .rst_n(vif.rst_n),

        // Write Address Channel
        .awid(vif.awid),
        .awaddr(vif.awaddr),
        .awlen(vif.awlen),
        .awsize(vif.awsize),
        .awburst(vif.awburst),
        .awvalid(vif.awvalid),
        .awready(vif.awready),

        // Write Data Channel
        .wdata(vif.wdata),
        .wstrb(vif.wstrb),
        .wlast(vif.wlast),
        .wvalid(vif.wvalid),
        .wready(vif.wready),

        // Write Response Channel
        .bid(vif.bid),
        .bresp(vif.bresp),
        .bvalid(vif.bvalid),
        .bready(vif.bready),

        // Read Address Channel
        .arid(vif.arid),
        .araddr(vif.araddr),
        .arlen(vif.arlen),
        .arsize(vif.arsize),
        .arburst(vif.arburst),
        .arvalid(vif.arvalid),
        .arready(vif.arready),

        // Read Data Channel
        .rid(vif.rid),
        .rdata(vif.rdata),
        .rresp(vif.rresp),
        .rlast(vif.rlast),
        .rvalid(vif.rvalid),
        .rready(vif.rready)
    );

    // Start UVM Simulation
    initial begin
        // Pass virtual interface to configuration DB
        uvm_config_db#(virtual axi_if)::set(null, "*", "vif", vif);
        
        // Start test
        run_test("axi_test");
    end

    // Timeout watchdog
    initial begin
        #500000; // 500us timeout
        `uvm_fatal("TOP", "Simulation Timeout!")
    end

endmodule : top
