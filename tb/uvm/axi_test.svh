`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

// ----------------------------------------------------
// SEQUENCES
// ----------------------------------------------------

class base_sequence extends uvm_sequence #(cxl_item);
    `uvm_object_utils(base_sequence)

    function new(string name = "base_sequence");
        super.new(name);
    endfunction

    task body();
        cxl_item item;
        bit [11:0] last_addr;
        
        // 1. Random Write Burst (CXL 64-byte write)
        item = cxl_item::type_id::create("item");
        start_item(item);
        if (!item.randomize() with { trans_type == cxl_item::CXL_WRITE; delay == 0; }) 
            `uvm_error("SEQ", "Randomization failed")
        last_addr = item.addr;
        finish_item(item);

        // 2. Read back from the exact same address (Verify parity)
        item = cxl_item::type_id::create("item");
        start_item(item);
        if (!item.randomize() with { 
            trans_type == cxl_item::CXL_READ; 
            delay == 0; 
            addr == last_addr;
        }) `uvm_error("SEQ", "Randomization failed")
        finish_item(item);
    endtask
endclass : base_sequence

// ----------------------------------------------------
// TEST
// ----------------------------------------------------

class axi_test extends uvm_test;
    `uvm_component_utils(axi_test)

    axi_env env;

    function new(string name = "axi_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = axi_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        base_sequence seq;
        seq = base_sequence::type_id::create("seq");
        
        phase.raise_objection(this);
        `uvm_info("TEST", "Starting CXL Test Sequence...", UVM_LOW)
        
        // Run 1,000 iterations (2,000 transactions / 32,000 AXI beats) to achieve deep functional coverage closure
        for(int i=0; i<1000; i++) begin
            seq.start(env.agent.sequencer);
        end
        
        #100ns;
        `uvm_info("TEST", "CXL Test Sequence Complete.", UVM_LOW)
        phase.drop_objection(this);
    endtask

endclass : axi_test
