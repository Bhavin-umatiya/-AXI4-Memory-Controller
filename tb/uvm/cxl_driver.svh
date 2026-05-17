`timescale 1ns / 1ps

class cxl_driver extends uvm_driver #(cxl_item);
    `uvm_component_utils(cxl_driver)

    virtual cxl_if vif;

    function new(string name = "cxl_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual cxl_if)::get(this, "", "vif", vif))
            `uvm_fatal("DRV", "Could not get CXL virtual interface")
    endfunction

    task run_phase(uvm_phase phase);
        // Reset state
        vif.cxl_valid  <= 1'b0;
        vif.cxl_opcode <= 2'b00;
        vif.cxl_addr   <= '0;
        vif.cxl_wdata  <= '0;

        @(posedge vif.rst_n);
        `uvm_info("DRV", "System Reset Released. Starting Driver...", UVM_LOW)

        forever begin
            cxl_item item;
            seq_item_port.get_next_item(item);
            drive_item(item);
            seq_item_port.item_done();
        end
    endtask

    task drive_item(cxl_item item);
        // Apply randomized delay
        repeat (item.delay) @(posedge vif.clk);

        // Drive CXL request
        vif.cxl_valid  <= 1'b1;
        vif.cxl_opcode <= item.trans_type;
        vif.cxl_addr   <= item.addr;
        vif.cxl_wdata  <= item.wdata;

        // Wait for handshake
        do begin
            @(posedge vif.clk);
        end while (!vif.cxl_ready);

        // Clear request
        vif.cxl_valid  <= 1'b0;
        vif.cxl_opcode <= 2'b00;
        vif.cxl_addr   <= '0;
        vif.cxl_wdata  <= '0;

        // For Reads, wait to capture read response
        if (item.trans_type == cxl_item::CXL_READ) begin
            do begin
                @(posedge vif.clk);
            end while (!vif.cxl_rsp_valid);
            item.rdata = vif.cxl_rsp_rdata;
            item.error = vif.cxl_rsp_error;
        end
    endtask

endclass : cxl_driver
