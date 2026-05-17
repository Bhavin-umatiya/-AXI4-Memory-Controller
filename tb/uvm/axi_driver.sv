`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import axi_pkg::*;

class axi_driver extends uvm_driver #(axi_item);
    `uvm_component_utils(axi_driver)

    virtual axi_if vif;

    function new(string name = "axi_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif))
            `uvm_fatal("DRV", "Could not get vif")
    endfunction

    task run_phase(uvm_phase phase);
        reset_signals();
        forever begin
            seq_item_port.get_next_item(req);
            drive_item(req);
            seq_item_port.item_done();
        end
    endtask

    task reset_signals();
        vif.awvalid <= 0;
        vif.wvalid  <= 0;
        vif.bready  <= 0;
        vif.arvalid <= 0;
        vif.rready  <= 0;
        vif.wlast   <= 0;
        @(posedge vif.rst_n);
    endtask

    task drive_item(axi_item item);
        repeat(item.delay) @(posedge vif.clk);
        
        if (item.trans_type == axi_item::WRITE) begin
            // 1. Drive Write Address
            vif.awid    <= item.awid;
            vif.awaddr  <= item.awaddr;
            vif.awlen   <= item.awlen;
            vif.awsize  <= item.awsize;
            vif.awburst <= item.awburst;
            vif.awvalid <= 1;
            @(posedge vif.clk iff vif.awready);
            vif.awvalid <= 0;

            // 2. Drive Write Data Burst
            for (int i = 0; i <= item.awlen; i++) begin
                vif.wdata  <= item.wdata[i];
                vif.wstrb  <= item.wstrb[i];
                vif.wlast  <= (i == item.awlen);
                vif.wvalid <= 1;
                @(posedge vif.clk iff vif.wready);
            end
            vif.wvalid <= 0;
            vif.wlast  <= 0;

            // 3. Wait for Write Response
            vif.bready <= 1;
            @(posedge vif.clk iff vif.bvalid);
            vif.bready <= 0;
            
        end else begin
            // 1. Drive Read Address
            vif.arid    <= item.arid;
            vif.araddr  <= item.araddr;
            vif.arlen   <= item.arlen;
            vif.arsize  <= item.arsize;
            vif.arburst <= item.arburst;
            vif.arvalid <= 1;
            @(posedge vif.clk iff vif.arready);
            vif.arvalid <= 0;

            // 2. Wait for Read Data Burst
            vif.rready <= 1;
            for (int i = 0; i <= item.arlen; i++) begin
                @(posedge vif.clk iff vif.rvalid);
                // Data captured in monitor
            end
            vif.rready <= 0;
        end
    endtask

endclass : axi_driver
