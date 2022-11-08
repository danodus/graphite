// graphite.sv
// Copyright (c) 2021-2022 Daniel Cliche
// SPDX-License-Identifier: MIT

// Ref.: https://www.scratchapixel.com/lessons/3d-basic-rendering/rasterization-practical-implementation

`include "graphite.svh"

module graphite #(
    parameter FB_WIDTH = 128,
    parameter FB_HEIGHT = 128,
    parameter TEXTURE_WIDTH = 32,
    parameter TEXTURE_HEIGHT = 32,
    parameter SUBPIXEL_PRECISION_MASK = 16'hF000
    ) (
    input  wire logic                        clk,
    input  wire logic                        reset_i,

    // AXI stream command interface (slave)
    input  wire logic                        cmd_axis_tvalid_i,
    output      logic                        cmd_axis_tready_o,
    input  wire logic [31:0]                 cmd_axis_tdata_i,

    // VRAM write
    input  wire logic                        vram_ack_i,
    output      logic                        vram_sel_o,
    output      logic                        vram_wr_o,
    output      logic  [3:0]                 vram_mask_o,
    output      logic [31:0]                 vram_addr_o,
    input       logic [15:0]                 vram_data_in_i,
    output      logic [15:0]                 vram_data_out_o,

    input  wire logic                        vsync_i,
    output      logic                        swap_o,
    output      logic [31:0]                 front_addr_o
    );

    enum { WAIT_COMMAND, PROCESS_COMMAND, SWAP0, CLEAR_FB0, CLEAR_FB1, CLEAR_DEPTH0, CLEAR_DEPTH1, WRITE_TEX, DRAW, DRAW2
    } state;

    logic signed [31:0] vv00, vv01, vv02, vv10, vv11, vv12, vv20, vv21, vv22;
    logic signed [31:0] c00, c01, c02;
    logic signed [31:0] c10, c11, c12;
    logic signed [31:0] c20, c21, c22;
    logic signed [31:0] st00, st01, st10, st11, st20, st21;

    logic signed [11:0] x, y;
    
    logic [31:0] front_address, back_address, depth_address, texture_address;

    logic [31:0] texture_write_address;
    logic [31:0] raster_rel_address;

    assign front_addr_o = front_address;

    logic is_textured, is_clamp_s, is_clamp_t, is_depth_test;

    logic rasterizer_start, rasterizer_busy;

    logic vram_sel, rasterizer_vram_sel;
    logic vram_wr, rasterizer_vram_wr;
    logic [3:0] vram_mask, rasterizer_vram_mask;
    logic [31:0] vram_addr, rasterizer_vram_addr;
    logic [15:0] vram_data_out, rasterizer_vram_data_out;

    always_comb begin
        if (state == DRAW || state == DRAW2) begin
            vram_sel_o = rasterizer_vram_sel;
            vram_wr_o = rasterizer_vram_wr;
            vram_mask_o = rasterizer_vram_mask;
            vram_addr_o = rasterizer_vram_addr;
            vram_data_out_o = rasterizer_vram_data_out;
        end else begin
            vram_sel_o = vram_sel;
            vram_wr_o = vram_wr;
            vram_mask_o = vram_mask;
            vram_addr_o = vram_addr;
            vram_data_out_o = vram_data_out;
        end
    end

    rasterizer_barycentric #(
        .FB_WIDTH(FB_WIDTH),
        .FB_HEIGHT(FB_HEIGHT),
        .TEXTURE_WIDTH(TEXTURE_WIDTH),
        .TEXTURE_HEIGHT(TEXTURE_HEIGHT),
        .SUBPIXEL_PRECISION_MASK(SUBPIXEL_PRECISION_MASK)
    ) rasterizer_barycentric(
        .clk(clk),
        .reset_i(reset_i),

        .start_i(rasterizer_start),
        .busy_o(rasterizer_busy),

        .vv00_i(vv00), 
        .vv01_i(vv01),
        .vv02_i(vv02),
        .vv10_i(vv10),
        .vv11_i(vv11),
        .vv12_i(vv12),
        .vv20_i(vv20),
        .vv21_i(vv21),
        .vv22_i(vv22),
        
        .c00_i(c00),
        .c01_i(c01),
        .c02_i(c02),

        .c10_i(c10),
        .c11_i(c11),
        .c12_i(c12),

        .c20_i(c20),
        .c21_i(c21),
        .c22_i(c22),
        
        .st00_i(st00),
        .st01_i(st01),
        .st10_i(st10),
        .st11_i(st11),
        .st20_i(st20),
        .st21_i(st21),   

        .is_textured_i(is_textured),
        .is_clamp_s_i(is_clamp_s),
        .is_clamp_t_i(is_clamp_t),
        .is_depth_test_i(is_depth_test),

        .back_address_i(back_address),
        .depth_address_i(depth_address),
        .texture_address_i(texture_address),        

        // VRAM write
        .vram_ack_i(vram_ack_i),
        .vram_sel_o(rasterizer_vram_sel),
        .vram_wr_o(rasterizer_vram_wr),
        .vram_mask_o(rasterizer_vram_mask),
        .vram_addr_o(rasterizer_vram_addr),
        .vram_data_in_i(vram_data_in_i),
        .vram_data_out_o(rasterizer_vram_data_out)
    );

    assign cmd_axis_tready_o = state == WAIT_COMMAND;

    always_ff @(posedge clk) begin
        case (state)
            WAIT_COMMAND: begin
                swap_o <= 1'b0;
                if (cmd_axis_tvalid_i)
                    state <= PROCESS_COMMAND;
            end

            PROCESS_COMMAND: begin
                case (cmd_axis_tdata_i[OP_POS+:OP_SIZE])
                    OP_SET_X0: begin
                        if (cmd_axis_tdata_i[16]) begin
                            vv00[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            vv00[15:0] <= cmd_axis_tdata_i[15:0] & SUBPIXEL_PRECISION_MASK;
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_Y0: begin
                        if (cmd_axis_tdata_i[16]) begin
                            vv01[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            vv01[15:0] <= cmd_axis_tdata_i[15:0] & SUBPIXEL_PRECISION_MASK;
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_Z0: begin
                        if (cmd_axis_tdata_i[16]) begin
                            vv02[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            vv02[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_X1: begin
                        if (cmd_axis_tdata_i[16]) begin
                            vv10[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            vv10[15:0] <= cmd_axis_tdata_i[15:0] & SUBPIXEL_PRECISION_MASK;
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_Y1: begin
                        if (cmd_axis_tdata_i[16]) begin
                            vv11[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            vv11[15:0] <= cmd_axis_tdata_i[15:0] & SUBPIXEL_PRECISION_MASK;
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_Z1: begin
                        if (cmd_axis_tdata_i[16]) begin
                            vv12[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            vv12[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_X2: begin
                        if (cmd_axis_tdata_i[16]) begin
                            vv20[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            vv20[15:0] <= cmd_axis_tdata_i[15:0] & SUBPIXEL_PRECISION_MASK;
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_Y2: begin
                        if (cmd_axis_tdata_i[16]) begin
                            vv21[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            vv21[15:0] <= cmd_axis_tdata_i[15:0] & SUBPIXEL_PRECISION_MASK;
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_Z2: begin
                        if (cmd_axis_tdata_i[16]) begin
                            vv22[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            vv22[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_R0: begin
                        if (cmd_axis_tdata_i[16]) begin
                            c00[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            c00[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_G0: begin
                        if (cmd_axis_tdata_i[16]) begin
                            c01[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            c01[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_B0: begin
                        if (cmd_axis_tdata_i[16]) begin
                            c02[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            c02[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_R1: begin
                        if (cmd_axis_tdata_i[16]) begin
                            c10[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            c10[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_G1: begin
                        if (cmd_axis_tdata_i[16]) begin
                            c11[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            c11[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_B1: begin
                        if (cmd_axis_tdata_i[16]) begin
                            c12[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            c12[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_R2: begin
                        if (cmd_axis_tdata_i[16]) begin
                            c20[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            c20[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_G2: begin
                        if (cmd_axis_tdata_i[16]) begin
                            c21[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            c21[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_B2: begin
                        if (cmd_axis_tdata_i[16]) begin
                            c22[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            c22[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_S0: begin
                        if (cmd_axis_tdata_i[16]) begin
                            st00[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            st00[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_T0: begin
                        if (cmd_axis_tdata_i[16]) begin
                            st01[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            st01[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_S1: begin
                        if (cmd_axis_tdata_i[16]) begin
                            st10[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            st10[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_T1: begin
                        if (cmd_axis_tdata_i[16]) begin
                            st11[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            st11[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_S2: begin
                        if (cmd_axis_tdata_i[16]) begin
                            st20[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            st20[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_T2: begin
                        if (cmd_axis_tdata_i[16]) begin
                            st21[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            st21[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_CLEAR: begin
                        vram_addr     <= (cmd_axis_tdata_i[16] == 0) ? back_address : 32'(2 * FB_WIDTH * FB_HEIGHT);
                        vram_data_out <= cmd_axis_tdata_i[15:0];
                        vram_mask     <= 4'hF;
                        vram_sel      <= 1'b1;
                        vram_wr       <= 1'b1;
                        state           <= (cmd_axis_tdata_i[16] == 0) ? CLEAR_FB0 : CLEAR_DEPTH0;
                    end
                    OP_DRAW: begin
                        is_textured     <= cmd_axis_tdata_i[0];
                        is_clamp_t      <= cmd_axis_tdata_i[1];
                        is_clamp_s      <= cmd_axis_tdata_i[2];
                        is_depth_test   <= cmd_axis_tdata_i[3];
                        rasterizer_start <= 1'b1;
                        state <= DRAW;
                    end
                    OP_SWAP: begin
                        if (vsync_i || !cmd_axis_tdata_i[0]) begin
                            swap_o <= 1'b1;
                            front_address <= back_address;
                            back_address  <= front_address;
                            state         <= SWAP0;
                        end
                    end
                    OP_SET_TEX_ADDR: begin
                        if (cmd_axis_tdata_i[16]) begin
                            texture_address[31:16] <= cmd_axis_tdata_i[15:0];
                            texture_write_address[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            texture_address[15:0] <= cmd_axis_tdata_i[15:0];
                            texture_write_address[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_WRITE_TEX: begin
                        vram_addr <= texture_write_address;
                        vram_data_out <= cmd_axis_tdata_i[15:0];
                        vram_mask <= 4'hF;
                        vram_sel <= 1'b1;
                        vram_wr  <= 1'b1;
                        state <= WRITE_TEX;
                    end
                    default:
                        state <= WAIT_COMMAND;
                endcase
            end

            SWAP0: begin
                if (vsync_i) begin
                    state  <= WAIT_COMMAND;
                end
            end

            CLEAR_FB0: begin
                if (vram_ack_i) begin
                    vram_sel <= 1'b0;
                    vram_wr  <= 1'b0;
                    state <= CLEAR_FB1;
                end
            end

            CLEAR_FB1: begin
                if (vram_addr_o < back_address + FB_WIDTH * FB_HEIGHT - 1) begin
                    vram_addr <= vram_addr_o + 1;
                    vram_sel  <= 1'b1;
                    vram_wr   <= 1'b1;
                    state       <= CLEAR_FB0;
                end else begin
                    state       <= WAIT_COMMAND;
                end
            end

            CLEAR_DEPTH0: begin
                if (vram_ack_i) begin
                    vram_sel <= 1'b0;
                    vram_wr  <= 1'b0;
                    state  <= CLEAR_DEPTH1;
                end
            end

            CLEAR_DEPTH1: begin
                if (vram_addr_o < 3 * FB_WIDTH * FB_HEIGHT - 1) begin
                    vram_addr <= vram_addr_o + 1;
                    vram_sel  <= 1'b1;
                    vram_wr   <= 1'b1;
                    state       <= CLEAR_DEPTH0;
                end else begin
                    state      <= WAIT_COMMAND;
                end
            end

            WRITE_TEX: begin
                if (vram_ack_i) begin
                    vram_sel <= 1'b0;
                    vram_wr  <= 1'b0;
                    texture_write_address <= texture_write_address + 1;
                    state <= WAIT_COMMAND;
                end
            end

            DRAW: begin
                rasterizer_start <= 1'b0;
                state <= DRAW2;
            end

            DRAW2: begin
                if (!rasterizer_busy)
                    state <= WAIT_COMMAND;
            end
        endcase

        if (reset_i) begin
            swap_o              <= 1'b0;
            vram_sel          <= 1'b0;
            vram_wr           <= 1'b0;
            front_address       <= 32'h0;
            back_address        <= FB_WIDTH * FB_HEIGHT;
            depth_address       <= 2 * FB_WIDTH * FB_HEIGHT;
            texture_address     <= 3 * FB_WIDTH * FB_HEIGHT;
            state               <= WAIT_COMMAND;
            rasterizer_start    <= 1'b0;
        end
    end

endmodule

