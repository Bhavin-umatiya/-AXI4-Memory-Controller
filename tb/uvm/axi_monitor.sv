`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import axi_pkg::*;

class axi_monitor extends uvm_monitor;
    `uvm_component_utils(axi_monitor)

    virtual axi_if vif;
    uvm_analysis_port #(axi_item) ap;

    // ----------------------------------------------------
    // Functional Coverage (Covergroups)
    // ----------------------------------------------------
    axi_item cov_item;
    
    covergroup axi_cg;
        option.per_instance = 1;
        
        cp_trans_type: coverpoint cov_item.trans_type {
            bins write = {axi_item::WRITE};
            bins read  = {axi_item::READ};
        }
        
        cp_burst_len: coverpoint cov_item.awlen { // covers read len too effectively due to constraint
            bins single     = {0};
            bins short      = {[1:7]};
            bins med        = {[8:15]};
            bins max_length = {255};
        }
        
        // Corner case: crossing read/write with burst length
        cross_type_len: cross cp_trans_type, cp_burst_len;
    endgroup

    function new(string name = "axi_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
        axi_cg = new();
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif))
            `uvm_fatal("MON", "Could not get vif")
    endfunction

    task run_phase(uvm_phase phase);
        fork
            monitor_write_channel();
            monitor_read_channel();
        join
    endtask

    task monitor_write_channel();
        axi_item item;
        forever begin
            @(posedge vif.clk iff (vif.awvalid && vif.awready));
            item = axi_item::type_id::create("item");
            item.trans_type = axi_item::WRITE;
            item.awid    = vif.awid;
            item.awaddr  = vif.awaddr;
            item.awlen   = vif.awlen;
            item.awsize  = vif.awsize;
            item.awburst = vif.awburst;

            // Wait for all data beats
            for (int i = 0; i <= item.awlen; i++) begin
                @(posedge vif.clk iff (vif.wvalid && vif.wready));
                item.wdata[i] = vif.wdata;
                item.wstrb[i] = vif.wstrb;
            end
            
            // Wait for response
            @(posedge vif.clk iff (vif.bvalid && vif.bready));
            item.bresp = vif.bresp;

            // Sample coverage
            cov_item = item;
            axi_cg.sample();

            ap.write(item);
        end
    endtask

    task monitor_read_channel();
        axi_item item;
        forever begin
            @(posedge vif.clk iff (vif.arvalid && vif.arready));
            item = axi_item::type_id::create("item");
            item.trans_type = axi_item::READ;
            item.arid    = vif.arid;
            item.araddr  = vif.araddr;
            item.arlen   = vif.arlen;
            item.arsize  = vif.arsize;
            item.arburst = vif.arburst;

            // Wait for all read data beats
            for (int i = 0; i <= item.arlen; i++) begin
                @(posedge vif.clk iff (vif.rvalid && vif.rready));
                item.rdata.push_back(vif.rdata);
            end
            item.rresp = vif.rresp;

            // Sample coverage
            cov_item = item;
            axi_cg.sample();

            ap.write(item);
        end
    endtask

endclass : axi_monitor
