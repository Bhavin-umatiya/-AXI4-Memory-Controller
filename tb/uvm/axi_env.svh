`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class axi_env extends uvm_env;
    `uvm_component_utils(axi_env)

    cxl_agent      agent;
    axi_scoreboard scoreboard;

    function new(string name = "axi_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent      = cxl_agent::type_id::create("agent", this);
        scoreboard = axi_scoreboard::type_id::create("scoreboard", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        // Connect Monitor's Analysis Port to Scoreboard's Analysis Imp
        agent.monitor.ap.connect(scoreboard.ap_imp);
    endfunction

endclass : axi_env
