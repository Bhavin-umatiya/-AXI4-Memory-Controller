`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

// ----------------------------------------------------
// SEQUENCES
// ----------------------------------------------------

class base_sequence extends uvm_sequence #(axi_item);
    `uvm_object_utils(base_sequence)

    function new(string name = "base_sequence");
        super.new(name);
    endfunction

    task body();
        axi_item item;
        bit [11:0] last_waddr;
        bit [7:0]  last_wlen;
        
        // 1. Random Write Burst
        item = axi_item::type_id::create("item");
        start_item(item);
        if (!item.randomize() with { trans_type == axi_item::WRITE; delay == 0; }) 
            `uvm_error("SEQ", "Randomization failed")
        last_waddr = item.awaddr;
        last_wlen  = item.awlen;
        finish_item(item);

        // 2. Read back from the exact same address (Corner Case check)
        item = axi_item::type_id::create("item");
        start_item(item);
        if (!item.randomize() with { 
            trans_type == axi_item::READ; 
            delay == 0; 
            araddr == last_waddr; 
            arlen == last_wlen;
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
        `uvm_info("TEST", "Starting Test Sequence...", UVM_LOW)
        
        // Run 50 iterations of write/read bursts to test functional coverage
        for(int i=0; i<50; i++) begin
            seq.start(env.agent.sequencer);
        end
        
        #100ns;
        `uvm_info("TEST", "Test Sequence Complete.", UVM_LOW)
        phase.drop_objection(this);
    endtask

endclass : axi_test
