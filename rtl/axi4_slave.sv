`timescale 1ns / 1ps
import axi_pkg::*;

module axi4_slave #(
    parameter ID_WIDTH   = 4,
    parameter ADDR_WIDTH = 12,
    parameter DATA_WIDTH = 32
) (
    input  logic                  clk,
    input  logic                  rst_n,

    // Write Address Channel (AW)
    input  logic [ID_WIDTH-1:0]   awid,
    input  logic [ADDR_WIDTH-1:0] awaddr,
    input  logic [7:0]            awlen,
    input  logic [2:0]            awsize,
    input  logic [1:0]            awburst,
    input  logic                  awvalid,
    output logic                  awready,

    // Write Data Channel (W)
    input  logic [DATA_WIDTH-1:0] wdata,
    input  logic [(DATA_WIDTH/8)-1:0] wstrb,
    input  logic                  wlast,
    input  logic                  wvalid,
    output logic                  wready,

    // Write Response Channel (B)
    output logic [ID_WIDTH-1:0]   bid,
    output logic [1:0]            bresp,
    output logic                  bvalid,
    input  logic                  bready,

    // Read Address Channel (AR)
    input  logic [ID_WIDTH-1:0]   arid,
    input  logic [ADDR_WIDTH-1:0] araddr,
    input  logic [7:0]            arlen,
    input  logic [2:0]            arsize,
    input  logic [1:0]            arburst,
    input  logic                  arvalid,
    output logic                  arready,

    // Read Data Channel (R)
    output logic [ID_WIDTH-1:0]   rid,
    output logic [DATA_WIDTH-1:0] rdata,
    output logic [1:0]            rresp,
    output logic                  rlast,
    output logic                  rvalid,
    input  logic                  rready
);

    //---------------------------------------------------------
    // SRAM Interface Signals
    //---------------------------------------------------------
    logic                  sram_we;
    logic [ADDR_WIDTH-1:0] sram_waddr;
    logic [DATA_WIDTH-1:0] sram_wdata;
    logic [(DATA_WIDTH/8)-1:0] sram_wstrb;

    logic                  sram_re;
    logic [ADDR_WIDTH-1:0] sram_raddr;
    logic [DATA_WIDTH-1:0] sram_rdata;

    // Convert byte address to word address for SRAM if needed
    // Assuming ADDR_WIDTH is word-aligned for SRAM model
    localparam BYTES_PER_WORD = DATA_WIDTH / 8;
    localparam ADDR_LSB = $clog2(BYTES_PER_WORD);

    sram_model #(
        .ADDR_WIDTH(ADDR_WIDTH - ADDR_LSB), 
        .DATA_WIDTH(DATA_WIDTH)
    ) u_sram (
        .clk   (clk),
        .rst_n (rst_n),
        .we    (sram_we),
        .waddr (sram_waddr[ADDR_WIDTH-1:ADDR_LSB]),
        .wdata (sram_wdata),
        .wstrb (sram_wstrb),
        .re    (sram_re),
        .raddr (sram_raddr[ADDR_WIDTH-1:ADDR_LSB]),
        .rdata (sram_rdata)
    );

    //---------------------------------------------------------
    // Write Channel FSM & Logic
    //---------------------------------------------------------
    typedef enum logic [1:0] { W_IDLE, W_DATA, W_RESP } w_state_t;
    w_state_t w_state, w_next;

    logic [ID_WIDTH-1:0]   w_id_reg;
    logic [ADDR_WIDTH-1:0] w_addr_reg;
    logic [7:0]            w_len_reg;
    logic [2:0]            w_size_reg;
    logic [1:0]            w_burst_reg;
    logic [7:0]            w_beat_cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_state <= W_IDLE;
        end else begin
            w_state <= w_next;
        end
    end

    always_comb begin
        w_next  = w_state;
        awready = 1'b0;
        wready  = 1'b0;
        bvalid  = 1'b0;
        sram_we = 1'b0;

        case (w_state)
            W_IDLE: begin
                awready = 1'b1;
                if (awvalid) begin
                    w_next = W_DATA;
                end
            end

            W_DATA: begin
                wready = 1'b1;
                if (wvalid) begin
                    sram_we = 1'b1;
                    if (wlast) begin
                        w_next = W_RESP;
                    end
                end
            end

            W_RESP: begin
                bvalid = 1'b1;
                if (bready) begin
                    w_next = W_IDLE;
                end
            end
        endcase
    end

    // Write internal registers update
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_addr_reg  <= '0;
            w_id_reg    <= '0;
            w_len_reg   <= '0;
            w_size_reg  <= '0;
            w_burst_reg <= '0;
            w_beat_cnt  <= '0;
        end else begin
            if (w_state == W_IDLE && awvalid) begin
                w_addr_reg  <= awaddr;
                w_id_reg    <= awid;
                w_len_reg   <= awlen;
                w_size_reg  <= awsize;
                w_burst_reg <= awburst;
                w_beat_cnt  <= '0;
            end else if (w_state == W_DATA && wvalid && wready) begin
                w_beat_cnt <= w_beat_cnt + 1;
                // Basic INCR burst address update
                if (w_burst_reg == BURST_INCR) begin
                    w_addr_reg <= w_addr_reg + (1 << w_size_reg);
                end
            end
        end
    end

    assign sram_waddr = w_addr_reg;
    assign sram_wdata = wdata;
    assign sram_wstrb = wstrb;

    assign bid   = w_id_reg;
    assign bresp = RESP_OKAY;

    //---------------------------------------------------------
    // Read Channel FSM & Logic
    //---------------------------------------------------------
    typedef enum logic [1:0] { R_IDLE, R_READ_MEM, R_SEND_DATA } r_state_t;
    r_state_t r_state, r_next;

    logic [ID_WIDTH-1:0]   r_id_reg;
    logic [ADDR_WIDTH-1:0] r_addr_reg;
    logic [7:0]            r_len_reg;
    logic [2:0]            r_size_reg;
    logic [1:0]            r_burst_reg;
    logic [7:0]            r_beat_cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_state <= R_IDLE;
        end else begin
            r_state <= r_next;
        end
    end

    always_comb begin
        r_next  = r_state;
        arready = 1'b0;
        rvalid  = 1'b0;
        sram_re = 1'b0;

        case (r_state)
            R_IDLE: begin
                arready = 1'b1;
                if (arvalid) begin
                    r_next = R_READ_MEM;
                end
            end

            R_READ_MEM: begin
                // Issue read to SRAM
                sram_re = 1'b1;
                r_next  = R_SEND_DATA;
            end

            R_SEND_DATA: begin
                rvalid = 1'b1;
                if (rready) begin
                    if (r_beat_cnt == r_len_reg) begin
                        r_next = R_IDLE; // Last beat completed
                    end else begin
                        r_next = R_READ_MEM; // Fetch next beat
                    end
                end
            end
        endcase
    end

    // Read internal registers update
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_addr_reg  <= '0;
            r_id_reg    <= '0;
            r_len_reg   <= '0;
            r_size_reg  <= '0;
            r_burst_reg <= '0;
            r_beat_cnt  <= '0;
        end else begin
            if (r_state == R_IDLE && arvalid) begin
                r_addr_reg  <= araddr;
                r_id_reg    <= arid;
                r_len_reg   <= arlen;
                r_size_reg  <= arsize;
                r_burst_reg <= arburst;
                r_beat_cnt  <= '0;
            end else if (r_state == R_SEND_DATA && rvalid && rready) begin
                r_beat_cnt <= r_beat_cnt + 1;
                if (r_burst_reg == BURST_INCR) begin
                    r_addr_reg <= r_addr_reg + (1 << r_size_reg);
                end
            end
        end
    end

    assign sram_raddr = r_addr_reg;
    assign rdata      = sram_rdata;
    assign rid        = r_id_reg;
    assign rresp      = RESP_OKAY;
    assign rlast      = (r_beat_cnt == r_len_reg);

endmodule
