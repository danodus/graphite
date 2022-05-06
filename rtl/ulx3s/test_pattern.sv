// test_pattern.sv
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

module test_pattern #(
    parameter FB_WIDTH = 128,
    parameter FB_HEIGHT = 128
) (
    input  wire logic                        clk,
    input  wire logic                        reset_i,

    // VRAM write
    input  wire logic                        vram_ack_i,
    output      logic                        vram_sel_o,
    output      logic                        vram_wr_o,
    output      logic  [3:0]                 vram_mask_o,
    output      logic [31:0]                 vram_addr_o,
    output      logic [15:0]                 vram_data_out_o
);

    enum { FILL0, FILL1 } state;

    logic [31:0] addr;

    always_ff @(posedge clk) begin
        if (reset_i) begin
            addr            <= 24'd0;
            state           <= FILL0;
            vram_sel_o      <= 1'b0;
            vram_mask_o     <= 4'hF;
            vram_wr_o  <= 1'b0;
            vram_data_out_o <= 16'h0;
        end else begin
            case (state)
                FILL0: begin
                    if (addr < FB_WIDTH * FB_HEIGHT) begin
                        vram_sel_o      <= 1'b1;
                        vram_wr_o       <= 1'b1;
                        vram_addr_o     <= addr;
                        vram_data_out_o <= addr[15:0];
                        state <= FILL1;
                    end
                end
                
                FILL1: begin
                    if (vram_ack_i) begin
                        vram_sel_o <= 1'b0;
                        vram_wr_o  <= 1'b0;
                        addr       <= addr + 32'd1;
                        state      <= FILL0;
                    end
                end
            endcase
        end
    end

endmodule
