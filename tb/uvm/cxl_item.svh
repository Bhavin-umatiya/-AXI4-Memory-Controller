`timescale 1ns / 1ps

class cxl_item extends uvm_sequence_item;

    typedef enum bit [1:0] {
        CXL_READ  = 2'b01,
        CXL_WRITE = 2'b10
    } trans_type_t;

    // Transaction parameters
    rand trans_type_t trans_type;
    rand bit [11:0]   addr;
    rand bit [511:0]  wdata;
    rand int          delay;

    // Response parameters
    bit [511:0]       rdata;
    bit               error;

    `uvm_object_utils_begin(cxl_item)
        `uvm_field_enum(trans_type_t, trans_type, UVM_ALL_ON)
        `uvm_field_int(addr, UVM_ALL_ON)
        `uvm_field_sarray_int(wdata, UVM_ALL_ON)
        `uvm_field_int(delay, UVM_ALL_ON)
        `uvm_field_sarray_int(rdata, UVM_ALL_ON)
        `uvm_field_int(error, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "cxl_item");
        super.new(name);
    endfunction

    // ----------------------------------------------------
    // Constraints (Including Corner Cases)
    // ----------------------------------------------------

    // 1. Memory bounds for simple SRAM core (corresponds to 4KB of RAM -> 64 cache lines of 64 bytes)
    constraint mem_bounds_c {
        addr < 12'd64; 
    }

    // 2. Corner case: delay distributions
    constraint delay_c {
        delay dist { 0:/30, [1:5]:/70 };
    end

endclass : cxl_item
