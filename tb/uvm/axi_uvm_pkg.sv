`timescale 1ns / 1ps

package axi_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import axi_pkg::*;

    // Include UVM components in correct compilation order
    `include "axi_item.sv"
    `include "axi_driver.sv"
    `include "axi_monitor.sv"
    `include "axi_agent.sv"
    `include "axi_scoreboard.sv"
    `include "axi_env.sv"
    `include "axi_test.sv"

endpackage : axi_uvm_pkg
