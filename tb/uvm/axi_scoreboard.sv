`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class axi_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(axi_scoreboard)

    uvm_analysis_imp #(axi_item, axi_scoreboard) ap_imp;

    // Golden Reference Model (SRAM)
    int ref_mem [*]; // Associative array

    function new(string name = "axi_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap_imp = new("ap_imp", this);
    endfunction

    function void write(axi_item item);
        int current_addr;
        
        if (item.trans_type == axi_item::WRITE) begin
            // ----------------------------------------------------
            // WRITE OPERATION: Update Reference Model
            // ----------------------------------------------------
            current_addr = item.awaddr;
            for (int i = 0; i <= item.awlen; i++) begin
                // Note: Ignoring wstrb for simplicity in this basic model
                ref_mem[current_addr] = item.wdata[i];
                `uvm_info("SCB_WRITE", $sformatf("Wrote to Golden Mem: Addr=0x%0h, Data=0x%0h", current_addr, item.wdata[i]), UVM_HIGH)
                
                // INCR burst address calculation
                if (item.awburst == axi_pkg::BURST_INCR) begin
                    current_addr += (1 << item.awsize);
                end
            end

        end else if (item.trans_type == axi_item::READ) begin
            // ----------------------------------------------------
            // READ OPERATION: Check RTL Data against Reference Model
            // ----------------------------------------------------
            current_addr = item.araddr;
            for (int i = 0; i <= item.arlen; i++) begin
                int expected_data;
                
                if (ref_mem.exists(current_addr)) begin
                    expected_data = ref_mem[current_addr];
                end else begin
                    expected_data = 0; // Uninitialized memory in SRAM model is 0
                end

                if (item.rdata[i] !== expected_data) begin
                    `uvm_error("SCB_FAIL", $sformatf("Data Mismatch! Addr: 0x%0h, Expected: 0x%0h, Actual: 0x%0h", current_addr, expected_data, item.rdata[i]))
                end else begin
                    `uvm_info("SCB_PASS", $sformatf("Data Match! Addr: 0x%0h, Data: 0x%0h", current_addr, expected_data), UVM_HIGH)
                end

                // INCR burst address calculation
                if (item.arburst == axi_pkg::BURST_INCR) begin
                    current_addr += (1 << item.arsize);
                end
            end
        end
    endfunction

endclass : axi_scoreboard
