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
    output      logic [15:0]                 vram_data_out_o,

    input  wire logic                        fill_i,
    input  wire logic                        fill_square_i
);

    localparam SQUARE_WIDTH = 100;
    localparam SQUARE_HEIGHT = 200;
    localparam SQUARE_COL = (FB_WIDTH - SQUARE_WIDTH) / 2;
    localparam SQUARE_LINE = (FB_HEIGHT - SQUARE_HEIGHT) / 2;

    enum { FILL0, FILL1, FILL_SQUARE0, FILL_SQUARE1, FILL_SQUARE2, FILL_SQUARE3, FILL_SQUARE4, FILL_SQUARE5, HOLD } state;

    logic [31:0] addr;
    logic [11:0] line_counter, col_counter;

    logic [11:0] bg_color;
    logic [11:0] color;

    assign color = line_counter == 0 || line_counter == (FB_HEIGHT - 1) || col_counter == 0 || col_counter == (FB_WIDTH - 1) ? 12'hFFF : {4'hF, addr[0] ? bg_color : 12'h000};
    
    always_ff @(posedge clk) begin
        if (reset_i) begin
            addr            <= 24'd0;
            state           <= FILL0;
            vram_sel_o      <= 1'b0;
            vram_mask_o     <= 4'hF;
            vram_wr_o       <= 1'b0;
            vram_data_out_o <= 16'h0;
            line_counter    <= 12'd0;
            col_counter     <= 12'd0;
            bg_color        <= 12'h00F;
        end else begin
            case (state)
                FILL0: begin
                    if (col_counter >= FB_WIDTH - 1) begin
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

                FILL_SQUARE0: begin
                    if (col_counter >= SQUARE_WIDTH - 1) begin
                        col_counter <= 0;
                        line_counter <= line_counter + 1;
                        addr        <= addr + FB_WIDTH - SQUARE_WIDTH + 1;
                    end else begin
                        col_counter <= col_counter + 1;
                        addr        <= addr + 32'd1;
                    end

                    if (line_counter >= SQUARE_HEIGHT) begin
                        state <= HOLD;
                    end else begin
                        vram_sel_o      <= 1'b1;
                        vram_wr_o       <= 1'b1;
                        vram_addr_o     <= addr;
                        vram_data_out_o <= {4'hF, bg_color};
                        state <= FILL_SQUARE1;
                    end
                end
                
                FILL_SQUARE1: begin
                    if (vram_ack_i) begin
                        vram_sel_o <= 1'b0;
                        vram_wr_o  <= 1'b0;
                        state      <= FILL_SQUARE2;
                    end
                end

                FILL_SQUARE2: begin
                    vram_sel_o      <= 1'b1;
                    vram_wr_o       <= 1'b1;
                    vram_addr_o     <= addr + FB_WIDTH * FB_HEIGHT;
                    vram_data_out_o <= {4'hF, bg_color};
                    state <= FILL_SQUARE3;
                end

                FILL_SQUARE3: begin
                    if (vram_ack_i) begin
                        vram_sel_o <= 1'b0;
                        vram_wr_o  <= 1'b0;
                        state      <= FILL_SQUARE4;
                    end                    
                end

                FILL_SQUARE4: begin
                    vram_sel_o      <= 1'b1;
                    vram_wr_o       <= 1'b0;
                    vram_addr_o     <= addr + FB_WIDTH * FB_HEIGHT;
                    state <= FILL_SQUARE5;
                end

                FILL_SQUARE5: begin
                    if (vram_ack_i) begin
                        vram_sel_o      <= 1'b0;
                        vram_wr_o       <= 1'b0;
                        state <= FILL_SQUARE0;
                    end
                end

                HOLD: begin
                    if (fill_i) begin
                        addr            <= 24'd0;
                        col_counter     <= 12'd0;
                        line_counter    <= 12'd0;
                        bg_color        <= bg_color + 12'h010;
                        state           <= FILL0;
                    end else if (fill_square_i) begin
                        addr            <= 24'(FB_WIDTH * SQUARE_LINE + SQUARE_COL);
                        col_counter     <= 12'd0;
                        line_counter    <= 12'd0;
                        bg_color        <= bg_color + 12'h010;
                        state           <= FILL_SQUARE0;
                    end
                end
            endcase
        end
    end

endmodule
