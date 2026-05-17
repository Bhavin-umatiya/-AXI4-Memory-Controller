`timescale 1ns / 1ps

package axi_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import axi_pkg::*;

    // Include UVM CXL components in correct compilation order
    `include "cxl_item.svh"
    `include "cxl_driver.svh"
    `include "cxl_monitor.svh"
    `include "cxl_agent.svh"
    `include "axi_scoreboard.svh"
    `include "axi_env.svh"
    `include "axi_test.svh"

endpackage : axi_uvm_pkg
