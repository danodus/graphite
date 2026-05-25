// graphite_command_processor.sv
// Copyright (c) 2021-2026 Daniel Cliche
// SPDX-License-Identifier: MIT

`include "graphite.svh"

module graphite_command_processor #(
    parameter FB_ADDRESS = 32'h0,
    parameter FB_WIDTH = 128,
    parameter FB_HEIGHT = 128,
    parameter SUBPIXEL_PRECISION_MASK = 16'hF000
) (
    input  wire logic clk,
    input  wire logic reset_i,
    input  wire logic ce_i,

    input  wire logic cmd_axis_tvalid_i,
    output      logic cmd_axis_tready_o,
    input  wire logic [31:0] cmd_axis_tdata_i,

    input  wire logic vsync_i,
    input  wire logic raster_busy_i,

    output logic raster_start_o,
    output logic swap_o,
    output logic clear_o,
    output logic [31:0] front_addr_o,

    output logic core_vram_sel_o,
    output logic core_vram_wr_o,
    output logic [3:0] core_vram_mask_o,
    output logic [31:0] core_vram_addr_o,
    output logic [15:0] core_vram_data_out_o,

    output logic signed [31:0] vv00_o, vv01_o, vv02_o,
    output logic signed [31:0] vv10_o, vv11_o, vv12_o,
    output logic signed [31:0] vv20_o, vv21_o, vv22_o,
    output logic signed [31:0] c00_o, c01_o, c02_o,
    output logic signed [31:0] c10_o, c11_o, c12_o,
    output logic signed [31:0] c20_o, c21_o, c22_o,
    output logic signed [31:0] st00_o, st01_o, st10_o, st11_o, st20_o, st21_o,

    output logic [31:0] fb_address_o,
    output logic [31:0] texture_address_o,
    output logic [31:0] back_rel_address_o,
    output logic [31:0] depth_rel_address_o,

    output logic is_textured_o,
    output logic is_clamp_s_o,
    output logic is_clamp_t_o,
    output logic is_depth_test_o,
    output logic is_perspective_correct_o,
    output logic [2:0] texture_width_scale_o,
    output logic [2:0] texture_height_scale_o
);

    enum { WAIT_COMMAND, PROCESS_COMMAND, WAIT_RASTER, SWAP0, CLEAR_FB0, CLEAR_DEPTH0 } state;

    logic signed [31:0] vv00, vv01, vv02, vv10, vv11, vv12, vv20, vv21, vv22;
    logic signed [31:0] c00, c01, c02, c10, c11, c12, c20, c21, c22;
    logic signed [31:0] st00, st01, st10, st11, st20, st21;

    logic [31:0] fb_address, texture_address;
    logic [31:0] front_rel_address, back_rel_address, depth_rel_address;
    logic [31:0] texture_write_address;

    logic is_textured, is_clamp_s, is_clamp_t, is_depth_test, is_perspective_correct;
    logic [2:0] texture_width_scale, texture_height_scale;

    logic core_vram_sel, core_vram_wr;
    logic [3:0] core_vram_mask;
    logic [31:0] core_vram_addr;
    logic [15:0] core_vram_data_out;

    assign front_addr_o = fb_address + front_rel_address;
    assign cmd_axis_tready_o = (state == WAIT_COMMAND) && !raster_busy_i;

    assign vv00_o = vv00;
    assign vv01_o = vv01;
    assign vv02_o = vv02;
    assign vv10_o = vv10;
    assign vv11_o = vv11;
    assign vv12_o = vv12;
    assign vv20_o = vv20;
    assign vv21_o = vv21;
    assign vv22_o = vv22;
    assign c00_o = c00;
    assign c01_o = c01;
    assign c02_o = c02;
    assign c10_o = c10;
    assign c11_o = c11;
    assign c12_o = c12;
    assign c20_o = c20;
    assign c21_o = c21;
    assign c22_o = c22;
    assign st00_o = st00;
    assign st01_o = st01;
    assign st10_o = st10;
    assign st11_o = st11;
    assign st20_o = st20;
    assign st21_o = st21;
    assign fb_address_o = fb_address;
    assign texture_address_o = texture_address;
    assign back_rel_address_o = back_rel_address;
    assign depth_rel_address_o = depth_rel_address;
    assign is_textured_o = is_textured;
    assign is_clamp_s_o = is_clamp_s;
    assign is_clamp_t_o = is_clamp_t;
    assign is_depth_test_o = is_depth_test;
    assign is_perspective_correct_o = is_perspective_correct;
    assign texture_width_scale_o = texture_width_scale;
    assign texture_height_scale_o = texture_height_scale;

    assign core_vram_sel_o = core_vram_sel;
    assign core_vram_wr_o = core_vram_wr;
    assign core_vram_mask_o = core_vram_mask;
    assign core_vram_addr_o = core_vram_addr;
    assign core_vram_data_out_o = core_vram_data_out;

    always_ff @(posedge clk) begin
        raster_start_o <= 1'b0;
        if (ce_i) case (state)
            WAIT_COMMAND: begin
                swap_o <= 1'b0;
                if (cmd_axis_tvalid_i)
                    state <= PROCESS_COMMAND;
            end

            PROCESS_COMMAND: begin
                case (cmd_axis_tdata_i[OP_POS+:OP_SIZE])
                    OP_SET_X0: begin
                        if (cmd_axis_tdata_i[16])
                            vv00[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            vv00[15:0] <= cmd_axis_tdata_i[15:0] & SUBPIXEL_PRECISION_MASK;
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_Y0: begin
                        if (cmd_axis_tdata_i[16])
                            vv01[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            vv01[15:0] <= cmd_axis_tdata_i[15:0] & SUBPIXEL_PRECISION_MASK;
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_Z0: begin
                        if (cmd_axis_tdata_i[16])
                            vv02[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            vv02[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_X1: begin
                        if (cmd_axis_tdata_i[16])
                            vv10[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            vv10[15:0] <= cmd_axis_tdata_i[15:0] & SUBPIXEL_PRECISION_MASK;
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_Y1: begin
                        if (cmd_axis_tdata_i[16])
                            vv11[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            vv11[15:0] <= cmd_axis_tdata_i[15:0] & SUBPIXEL_PRECISION_MASK;
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_Z1: begin
                        if (cmd_axis_tdata_i[16])
                            vv12[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            vv12[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_X2: begin
                        if (cmd_axis_tdata_i[16])
                            vv20[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            vv20[15:0] <= cmd_axis_tdata_i[15:0] & SUBPIXEL_PRECISION_MASK;
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_Y2: begin
                        if (cmd_axis_tdata_i[16])
                            vv21[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            vv21[15:0] <= cmd_axis_tdata_i[15:0] & SUBPIXEL_PRECISION_MASK;
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_Z2: begin
                        if (cmd_axis_tdata_i[16])
                            vv22[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            vv22[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_R0: begin
                        if (cmd_axis_tdata_i[16])
                            c00[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            c00[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_G0: begin
                        if (cmd_axis_tdata_i[16])
                            c01[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            c01[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_B0: begin
                        if (cmd_axis_tdata_i[16])
                            c02[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            c02[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_R1: begin
                        if (cmd_axis_tdata_i[16])
                            c10[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            c10[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_G1: begin
                        if (cmd_axis_tdata_i[16])
                            c11[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            c11[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_B1: begin
                        if (cmd_axis_tdata_i[16])
                            c12[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            c12[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_R2: begin
                        if (cmd_axis_tdata_i[16])
                            c20[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            c20[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_G2: begin
                        if (cmd_axis_tdata_i[16])
                            c21[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            c21[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_B2: begin
                        if (cmd_axis_tdata_i[16])
                            c22[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            c22[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_S0: begin
                        if (cmd_axis_tdata_i[16])
                            st00[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            st00[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_T0: begin
                        if (cmd_axis_tdata_i[16])
                            st01[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            st01[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_S1: begin
                        if (cmd_axis_tdata_i[16])
                            st10[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            st10[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_T1: begin
                        if (cmd_axis_tdata_i[16])
                            st11[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            st11[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_S2: begin
                        if (cmd_axis_tdata_i[16])
                            st20[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            st20[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_T2: begin
                        if (cmd_axis_tdata_i[16])
                            st21[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            st21[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_CLEAR: begin
                        core_vram_addr     <= fb_address + ((cmd_axis_tdata_i[16] == 0) ? back_rel_address : 32'(2 * FB_WIDTH * FB_HEIGHT));
                        core_vram_data_out <= cmd_axis_tdata_i[15:0];
                        clear_o            <= 1'b1;
                        core_vram_mask     <= 4'hF;
                        core_vram_sel      <= 1'b1;
                        core_vram_wr       <= 1'b1;
                        state              <= (cmd_axis_tdata_i[16] == 0) ? CLEAR_FB0 : CLEAR_DEPTH0;
                    end
                    OP_DRAW: begin
                        is_textured            <= cmd_axis_tdata_i[0];
                        is_clamp_t             <= cmd_axis_tdata_i[1];
                        is_clamp_s             <= cmd_axis_tdata_i[2];
                        is_depth_test          <= cmd_axis_tdata_i[3];
                        is_perspective_correct <= cmd_axis_tdata_i[4];
                        texture_width_scale    <= cmd_axis_tdata_i[7:5];
                        texture_height_scale   <= cmd_axis_tdata_i[10:8];
                        raster_start_o <= 1'b1;
                        state <= WAIT_RASTER;
                    end
                    OP_SWAP: begin
                        if (vsync_i || !cmd_axis_tdata_i[0]) begin
                            swap_o <= 1'b1;
                            front_rel_address <= back_rel_address;
                            back_rel_address  <= front_rel_address;
                            state <= SWAP0;
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
                    OP_SET_FB_ADDR: begin
                        if (cmd_axis_tdata_i[16])
                            fb_address[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            fb_address[15:0] <= cmd_axis_tdata_i[15:0];
                        front_rel_address <= 32'h0;
                        back_rel_address  <= cmd_axis_tdata_i[17] ? 32'h0 : FB_WIDTH * FB_HEIGHT;
                        state <= WAIT_COMMAND;
                    end
                    default:
                        state <= WAIT_COMMAND;
                endcase
            end

            WAIT_RASTER: begin
                if (!raster_busy_i)
                    state <= WAIT_COMMAND;
            end

            SWAP0: begin
                if (vsync_i)
                    state <= WAIT_COMMAND;
            end

            CLEAR_FB0: begin
                if (core_vram_addr < fb_address + back_rel_address + FB_WIDTH * FB_HEIGHT - 1)
                    core_vram_addr <= core_vram_addr + 1;
                else begin
                    clear_o <= 1'b0;
                    state   <= WAIT_COMMAND;
                end
            end

            CLEAR_DEPTH0: begin
                if (core_vram_addr < fb_address + 3 * FB_WIDTH * FB_HEIGHT - 1)
                    core_vram_addr <= core_vram_addr + 1;
                else begin
                    clear_o <= 1'b0;
                    state   <= WAIT_COMMAND;
                end
            end
        endcase

        if (reset_i) begin
            swap_o            <= 1'b0;
            core_vram_sel     <= 1'b0;
            core_vram_wr      <= 1'b0;
            clear_o           <= 1'b0;
            fb_address        <= FB_ADDRESS;
            front_rel_address <= 32'h0;
            back_rel_address  <= FB_WIDTH * FB_HEIGHT;
            depth_rel_address <= 2 * FB_WIDTH * FB_HEIGHT;
            texture_address   <= FB_ADDRESS + 3 * FB_WIDTH * FB_HEIGHT;
            state             <= WAIT_COMMAND;
            texture_width_scale  <= 3'd0;
            texture_height_scale <= 3'd0;
            raster_start_o    <= 1'b0;
        end
    end

endmodule
