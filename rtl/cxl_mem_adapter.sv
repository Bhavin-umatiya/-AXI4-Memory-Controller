`timescale 1ns / 1ps

module cxl_mem_adapter (
    input  logic         clk,
    input  logic         rst_n,

    // CXL.mem Interface
    input  logic         cxl_valid,
    input  logic [1:0]   cxl_opcode, // 1: MEM_RD, 2: MEM_WR
    input  logic [11:0]  cxl_addr,   // 64-byte aligned cacheline address
    input  logic [511:0] cxl_wdata,  // 64-byte write data
    output logic         cxl_ready,  // Ready to accept new request

    output logic         cxl_rsp_valid,
    output logic [511:0] cxl_rsp_rdata,
    output logic         cxl_rsp_error,

    // AXI4 Master Interface
    // Write Address Channel
    output logic [3:0]   m_awid,
    output logic [11:0]  m_awaddr,
    output logic [7:0]   m_awlen,
    output logic [2:0]   m_awsize,
    output logic [1:0]   m_awburst,
    output logic         m_awvalid,
    input  logic         m_awready,

    // Write Data Channel
    output logic [31:0]  m_wdata,
    output logic [3:0]   m_wstrb,
    output logic         m_wlast,
    output logic         m_wvalid,
    input  logic         m_wready,

    // Write Response Channel
    input  logic [3:0]   m_bid,
    input  logic [1:0]   m_bresp,
    input  logic         m_bvalid,
    output logic         m_bready,

    // Read Address Channel
    output logic [3:0]   m_arid,
    output logic [11:0]  m_araddr,
    output logic [7:0]   m_arlen,
    output logic [2:0]   m_arsize,
    output logic [1:0]   m_arburst,
    output logic         m_arvalid,
    input  logic         m_arready,

    // Read Data Channel
    input  logic [3:0]   m_rid,
    input  logic [31:0]  m_rdata,
    input  logic [1:0]   m_rresp,
    input  logic         m_rlast,
    input  logic         m_rvalid,
    output logic         m_rready
);

    import axi_pkg::*;

    // FSM States
    typedef enum logic [2:0] {
        ST_IDLE,
        ST_WRITE_ADDR,
        ST_WRITE_DATA,
        ST_WRITE_RESP,
        ST_READ_ADDR,
        ST_READ_DATA,
        ST_CXL_RESP
    } state_t;

    state_t state, next_state;

    // Registers
    logic [11:0]  addr_reg;
    logic [511:0] wdata_reg;
    logic [511:0] rdata_reg;
    logic [3:0]   beat_counter;
    logic         error_reg;

    // Constant mappings
    assign m_awid    = 4'h0;
    assign m_arid    = 4'h0;
    assign m_awsize  = SIZE_4B;
    assign m_arsize  = SIZE_4B;
    assign m_awburst = BURST_INCR;
    assign m_arburst = BURST_INCR;
    assign m_awlen   = 8'h0F; // 16 beats (16 * 4 bytes = 64 bytes)
    assign m_arlen   = 8'h0F; // 16 beats

    // State Machine logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= ST_IDLE;
            addr_reg     <= '0;
            wdata_reg    <= '0;
            rdata_reg    <= '0;
            beat_counter <= '0;
            error_reg    <= '0;
        end else begin
            state <= next_state;
            case (state)
                ST_IDLE: begin
                    beat_counter <= '0;
                    error_reg    <= '0;
                    if (cxl_valid && cxl_ready) begin
                        addr_reg  <= cxl_addr;
                        wdata_reg <= cxl_wdata;
                    end
                end

                ST_WRITE_DATA: begin
                    if (m_wready && m_wvalid) begin
                        beat_counter <= beat_counter + 1;
                    end
                end

                ST_WRITE_RESP: begin
                    if (m_bvalid && m_bready) begin
                        error_reg <= (m_bresp != RESP_OKAY);
                    end
                end

                ST_READ_DATA: begin
                    if (m_rvalid && m_rready) begin
                        beat_counter <= beat_counter + 1;
                        rdata_reg[(beat_counter * 32) +: 32] <= m_rdata;
                        if (m_rresp != RESP_OKAY) begin
                            error_reg <= 1'b1;
                        end
                    end
                end
            endcase
        end
    end

    // Next State Combinational logic
    always_comb begin
        next_state = state;
        case (state)
            ST_IDLE: begin
                if (cxl_valid) begin
                    if (cxl_opcode == 2'b10)      // MEM_WR
                        next_state = ST_WRITE_ADDR;
                    else if (cxl_opcode == 2'b01) // MEM_RD
                        next_state = ST_READ_ADDR;
                end
            end

            ST_WRITE_ADDR: begin
                if (m_awready)
                    next_state = ST_WRITE_DATA;
            end

            ST_WRITE_DATA: begin
                if (m_wready && m_wlast)
                    next_state = ST_WRITE_RESP;
            end

            ST_WRITE_RESP: begin
                if (m_bvalid)
                    next_state = ST_CXL_RESP;
            end

            ST_READ_ADDR: begin
                if (m_arready)
                    next_state = ST_READ_DATA;
            end

            ST_READ_DATA: begin
                if (m_rvalid && m_rlast)
                    next_state = ST_CXL_RESP;
            end

            ST_CXL_RESP: begin
                next_state = ST_IDLE;
            end
        endcase
    end

    // Output assignments
    assign cxl_ready     = (state == ST_IDLE);
    
    // AXI Control Assignments
    assign m_awaddr      = {addr_reg, 6'b000000}; // Map 64-byte block address to byte address
    assign m_araddr      = {addr_reg, 6'b000000};
    
    assign m_awvalid     = (state == ST_WRITE_ADDR);
    assign m_arvalid     = (state == ST_READ_ADDR);
    
    assign m_wvalid      = (state == ST_WRITE_DATA);
    assign m_wdata       = wdata_reg[(beat_counter * 32) +: 32];
    assign m_wstrb       = 4'hF; // Always full 32-bit writes
    assign m_wlast       = (state == ST_WRITE_DATA) && (beat_counter == 4'd15);
    
    assign m_bready      = (state == ST_WRITE_RESP);
    assign m_rready      = (state == ST_READ_DATA);

    // CXL Response Assignments
    assign cxl_rsp_valid = (state == ST_CXL_RESP);
    assign cxl_rsp_rdata = rdata_reg;
    assign cxl_rsp_error = error_reg;

endmodule
