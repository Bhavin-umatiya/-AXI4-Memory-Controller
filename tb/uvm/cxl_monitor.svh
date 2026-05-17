`timescale 1ns / 1ps

class cxl_monitor extends uvm_monitor;
    `uvm_component_utils(cxl_monitor)

    virtual cxl_if vif;
    uvm_analysis_port #(cxl_item) ap;

    cxl_item cov_item;

    // Functional Coverage Group
    covergroup cxl_cg;
        option.per_instance = 1;
        option.name = "cxl_functional_coverage";

        cp_trans_type: coverpoint cov_item.trans_type {
            bins cxl_write = {cxl_item::CXL_WRITE};
            bins cxl_read  = {cxl_item::CXL_READ};
        }

        cp_address: coverpoint cov_item.addr {
            bins low_range  = {[0:15]};
            bins mid_range  = {[16:47]};
            bins high_range = {[48:63]};
        }

        cross_trans_addr: cross cp_trans_type, cp_address;
    endgroup

    function new(string name = "cxl_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
        cxl_cg = new();
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual cxl_if)::get(this, "", "vif", vif))
            `uvm_fatal("MON", "Could not get CXL virtual interface")
    endfunction

    task run_phase(uvm_phase phase);
        fork
            monitor_cxl_channel();
        join
    endtask

    task monitor_cxl_channel();
        cxl_item item;
        forever begin
            @(posedge vif.clk iff (vif.cxl_valid && vif.cxl_ready));
            item = cxl_item::type_id::create("item");
            item.trans_type = cxl_item::trans_type_t'(vif.cxl_opcode);
            item.addr       = vif.cxl_addr;

            if (item.trans_type == cxl_item::CXL_WRITE) begin
                item.wdata = vif.cxl_wdata;
                // Broadcast write transaction
                ap.write(item);
                cov_item = item;
                cxl_cg.sample();
            end else if (item.trans_type == cxl_item::CXL_READ) begin
                // Wait for the corresponding response
                do begin
                    @(posedge vif.clk);
                end while (!vif.cxl_rsp_valid);
                item.rdata = vif.cxl_rsp_rdata;
                item.error = vif.cxl_rsp_error;
                // Broadcast read transaction
                ap.write(item);
                cov_item = item;
                cxl_cg.sample();
            end
        end
    endtask

endclass : cxl_monitor
