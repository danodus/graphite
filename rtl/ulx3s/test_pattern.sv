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

    enum { FILL0, FILL1, HOLD } state;

    logic [31:0] addr;
    logic [11:0] line_counter, col_counter;

    logic [15:0] color;

    assign color = line_counter == 0 || line_counter == (FB_HEIGHT - 1) || col_counter == 0 || col_counter == (FB_WIDTH - 1) ? 16'hFFFF : 16'hF00F;

    always_ff @(posedge clk) begin
        if (reset_i) begin
            addr            <= 24'd0;
            state           <= FILL0;
            vram_sel_o      <= 1'b0;
            vram_mask_o     <= 4'hF;
            vram_wr_o  <= 1'b0;
            vram_data_out_o <= 16'h0;
            line_counter <= 12'd0;
            col_counter <= 12'd0;
        end else begin
            case (state)
                FILL0: begin
                    if (col_counter >= FB_WIDTH) begin
                        col_counter <= 0;
                        line_counter <= line_counter + 1;
                    end else begin
                        col_counter <= col_counter + 1;
                    end

                    if (line_counter >= FB_HEIGHT) begin
                        state <= HOLD;
                    end else begin
                        vram_sel_o      <= 1'b1;
                        vram_wr_o       <= 1'b1;
                        vram_addr_o     <= addr;
                        vram_data_out_o <= color;
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

                HOLD: begin
                    state <= HOLD;
                end
            endcase
        end
    end

endmodule
