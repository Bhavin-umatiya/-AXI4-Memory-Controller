`timescale 1ns / 1ps

class cxl_agent extends uvm_agent;
    `uvm_component_utils(cxl_agent)

    uvm_sequencer #(cxl_item) sequencer;
    cxl_driver                driver;
    cxl_monitor               monitor;

    function new(string name = "cxl_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor = cxl_monitor::type_id::create("monitor", this);
        if (get_is_active() == UVM_ACTIVE) begin
            sequencer = uvm_sequencer#(cxl_item)::type_id::create("sequencer", this);
            driver    = cxl_driver::type_id::create("driver", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        if (get_is_active() == UVM_ACTIVE) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction

endclass : cxl_agent
