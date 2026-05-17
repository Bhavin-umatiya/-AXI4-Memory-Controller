`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class axi_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(axi_scoreboard)

    uvm_analysis_imp #(cxl_item, axi_scoreboard) ap_imp;

    // Golden Reference Model (512-bit wide cachelines)
    bit [511:0] ref_mem [int]; // Associative array mapped by CXL address

    function new(string name = "axi_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap_imp = new("ap_imp", this);
    endfunction

    function void write(cxl_item item);
        if (item.trans_type == cxl_item::CXL_WRITE) begin
            // ----------------------------------------------------
            // WRITE OPERATION: Update Reference Model
            // ----------------------------------------------------
            ref_mem[item.addr] = item.wdata;
            `uvm_info("SCB_WRITE", $sformatf("Wrote to Golden CXL Mem: Addr=0x%0h, Data=0x%0h", item.addr, item.wdata), UVM_HIGH)

        end else if (item.trans_type == cxl_item::CXL_READ) begin
            // ----------------------------------------------------
            // READ OPERATION: Check RTL Data against Reference Model
            // ----------------------------------------------------
            bit [511:0] expected_data;
            
            if (ref_mem.exists(item.addr)) begin
                expected_data = ref_mem[item.addr];
            end else begin
                expected_data = '0; // Uninitialized memory returns 0
            end

            if (item.rdata !== expected_data) begin
                `uvm_error("SCB_FAIL", $sformatf("Data Mismatch! CXL Addr: 0x%0h, Expected: 0x%0h, Actual: 0x%0h", item.addr, expected_data, item.rdata))
            end else begin
                `uvm_info("SCB_PASS", $sformatf("CXL Data Match! Addr: 0x%0h, Data: 0x%0h", item.addr, expected_data), UVM_LOW)
            end
        end
    endfunction

endclass : axi_scoreboard
