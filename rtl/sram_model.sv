`timescale 1ns / 1ps

module sram_model #(
    parameter ADDR_WIDTH = 12, // 4KB memory by default if 32-bit words
    parameter DATA_WIDTH = 32
) (
    input  logic                  clk,
    input  logic                  rst_n,

    // Write Port
    input  logic                  we,
    input  logic [ADDR_WIDTH-1:0] waddr,
    input  logic [DATA_WIDTH-1:0] wdata,
    input  logic [(DATA_WIDTH/8)-1:0] wstrb,

    // Read Port
    input  logic                  re,
    input  logic [ADDR_WIDTH-1:0] raddr,
    output logic [DATA_WIDTH-1:0] rdata
);

    localparam int MEM_DEPTH = 1 << ADDR_WIDTH;

    // Memory array
    logic [7:0] mem [MEM_DEPTH][DATA_WIDTH/8];

    // Read logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata <= '0;
        end else if (re) begin
            for (int i = 0; i < DATA_WIDTH/8; i++) begin
                rdata[i*8 +: 8] <= mem[raddr][i];
            end
        end
    end

    // Write logic (byte-enable support)
    always_ff @(posedge clk) begin
        if (we) begin
            for (int i = 0; i < DATA_WIDTH/8; i++) begin
                if (wstrb[i]) begin
                    mem[waddr][i] <= wdata[i*8 +: 8];
                end
            end
        end
    end

endmodule
