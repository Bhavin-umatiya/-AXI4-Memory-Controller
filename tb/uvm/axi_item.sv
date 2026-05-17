`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import axi_pkg::*;

class axi_item extends uvm_sequence_item;

    // Transaction Type
    typedef enum bit { WRITE, READ } trans_type_t;
    rand trans_type_t trans_type;

    // Delay before starting transaction
    rand int unsigned delay;

    // Write Address Channel
    rand bit [3:0]  awid;
    rand bit [11:0] awaddr;
    rand bit [7:0]  awlen;
    rand bit [2:0]  awsize;
    rand bit [1:0]  awburst;

    // Write Data Channel (Fixed-size arrays for burst data to support Vivado Xsim)
    rand bit [31:0] wdata[256];
    rand bit [3:0]  wstrb[256];

    // Read Address Channel
    rand bit [3:0]  arid;
    rand bit [11:0] araddr;
    rand bit [7:0]  arlen;
    rand bit [2:0]  arsize;
    rand bit [1:0]  arburst;

    // Read Data Channel (Captured during simulation)
    bit [31:0] rdata[$];
    bit [1:0]  rresp;

    // Write Response Channel (Captured during simulation)
    bit [1:0]  bresp;

    `uvm_object_utils_begin(axi_item)
        `uvm_field_enum(trans_type_t, trans_type, UVM_ALL_ON)
        `uvm_field_int(delay, UVM_ALL_ON)
        `uvm_field_int(awid, UVM_ALL_ON)
        `uvm_field_int(awaddr, UVM_ALL_ON)
        `uvm_field_int(awlen, UVM_ALL_ON)
        `uvm_field_int(awsize, UVM_ALL_ON)
        `uvm_field_int(awburst, UVM_ALL_ON)
        `uvm_field_sarray_int(wdata, UVM_ALL_ON)
        `uvm_field_sarray_int(wstrb, UVM_ALL_ON)
        `uvm_field_int(arid, UVM_ALL_ON)
        `uvm_field_int(araddr, UVM_ALL_ON)
        `uvm_field_int(arlen, UVM_ALL_ON)
        `uvm_field_int(arsize, UVM_ALL_ON)
        `uvm_field_int(arburst, UVM_ALL_ON)
        `uvm_field_queue_int(rdata, UVM_ALL_ON)
        `uvm_field_int(rresp, UVM_ALL_ON)
        `uvm_field_int(bresp, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "axi_item");
        super.new(name);
    endfunction

    // ----------------------------------------------------
    // Constraints (Including Corner Cases)
    // ----------------------------------------------------
    
    // 1. Data queue sizes must match burst lengths (Removed for fixed-size arrays)

    // 2. Address Alignment (Memory controller expects word-aligned for SIZE_4B)
    constraint align_c {
        awsize == SIZE_4B;
        arsize == SIZE_4B;
        awaddr[1:0] == 2'b00;
        araddr[1:0] == 2'b00;
    }

    // 2b. Write Strobe (Always write all 4 bytes to match basic Scoreboard model)
    constraint wstrb_c {
        foreach (wstrb[i]) {
            wstrb[i] == 4'b1111;
        }
    }

    // 3. Supported Burst Types (INCR only for simplicity, wrap/fixed reserved for future)
    constraint burst_type_c {
        awburst == BURST_INCR;
        arburst == BURST_INCR;
    }

    // 4. Memory Bounds (Do not wrap around the 4KB boundary in this simple test)
    constraint mem_bounds_c {
        (awaddr + ((awlen + 1) * 4)) < 4096;
        (araddr + ((arlen + 1) * 4)) < 4096;
    }

    // 5. Corner Cases (e.g., maximum burst lengths or 0 delay back-to-back)
    constraint corner_cases_c {
        // 20% chance of maximum burst length (256 beats)
        awlen dist { 0:/40, [1:15]:/40, 255:/20 };
        arlen dist { 0:/40, [1:15]:/40, 255:/20 };

        // 30% chance of back-to-back zero delay transactions
        delay dist { 0:/30, [1:5]:/70 };
    }

endclass : axi_item
