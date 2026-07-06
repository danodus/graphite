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

    output logic [15:0] min_x_o, max_x_o, max_y_o, start_x_o, start_y_o,
    output logic signed [31:0] E01_start_o, E12_start_o, E20_start_o,
    output logic signed [31:0] step_e01_x_o, step_e01_y_o, step_e12_x_o, step_e12_y_o, step_e20_x_o, step_e20_y_o,
    output logic signed [31:0] start_w_inv_o, start_s_o, start_t_o, start_r_o, start_g_o, start_b_o,
    output logic signed [31:0] dw_dx_o, dw_dy_o, ds_dx_o, ds_dy_o, dt_dx_o, dt_dy_o,
    output logic signed [31:0] dr_dx_o, dr_dy_o, dg_dx_o, dg_dy_o, db_dx_o, db_dy_o,

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

    logic [15:0] min_x, max_x, max_y, start_x, start_y;
    logic signed [31:0] E01_start, E12_start, E20_start;
    logic signed [31:0] step_e01_x, step_e01_y, step_e12_x, step_e12_y, step_e20_x, step_e20_y;
    logic signed [31:0] start_w_inv, start_s, start_t, start_r, start_g, start_b;
    logic signed [31:0] dw_dx, dw_dy, ds_dx, ds_dy, dt_dx, dt_dy;
    logic signed [31:0] dr_dx, dr_dy, dg_dx, dg_dy, db_dx, db_dy;

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

    assign min_x_o = min_x;
    assign max_x_o = max_x;
    assign max_y_o = max_y;
    assign start_x_o = start_x;
    assign start_y_o = start_y;
    assign E01_start_o = E01_start;
    assign E12_start_o = E12_start;
    assign E20_start_o = E20_start;
    assign step_e01_x_o = step_e01_x;
    assign step_e01_y_o = step_e01_y;
    assign step_e12_x_o = step_e12_x;
    assign step_e12_y_o = step_e12_y;
    assign step_e20_x_o = step_e20_x;
    assign step_e20_y_o = step_e20_y;
    assign start_w_inv_o = start_w_inv;
    assign start_s_o = start_s;
    assign start_t_o = start_t;
    assign start_r_o = start_r;
    assign start_g_o = start_g;
    assign start_b_o = start_b;
    assign dw_dx_o = dw_dx;
    assign dw_dy_o = dw_dy;
    assign ds_dx_o = ds_dx;
    assign ds_dy_o = ds_dy;
    assign dt_dx_o = dt_dx;
    assign dt_dy_o = dt_dy;
    assign dr_dx_o = dr_dx;
    assign dr_dy_o = dr_dy;
    assign dg_dx_o = dg_dx;
    assign dg_dy_o = dg_dy;
    assign db_dx_o = db_dx;
    assign db_dy_o = db_dy;
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
                    OP_SET_MIN_X: begin
                        min_x <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_MAX_X: begin
                        max_x <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_MAX_Y: begin
                        max_y <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_START_X: begin
                        start_x <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_START_Y: begin
                        start_y <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_E01_START: begin
                        if (cmd_axis_tdata_i[16])
                            E01_start[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            E01_start[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_E12_START: begin
                        if (cmd_axis_tdata_i[16])
                            E12_start[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            E12_start[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_E20_START: begin
                        if (cmd_axis_tdata_i[16])
                            E20_start[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            E20_start[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_STEP_E01_X: begin
                        if (cmd_axis_tdata_i[16])
                            step_e01_x[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            step_e01_x[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_STEP_E01_Y: begin
                        if (cmd_axis_tdata_i[16])
                            step_e01_y[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            step_e01_y[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_STEP_E12_X: begin
                        if (cmd_axis_tdata_i[16])
                            step_e12_x[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            step_e12_x[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_STEP_E12_Y: begin
                        if (cmd_axis_tdata_i[16])
                            step_e12_y[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            step_e12_y[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_STEP_E20_X: begin
                        if (cmd_axis_tdata_i[16])
                            step_e20_x[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            step_e20_x[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_STEP_E20_Y: begin
                        if (cmd_axis_tdata_i[16])
                            step_e20_y[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            step_e20_y[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_START_W_INV: begin
                        if (cmd_axis_tdata_i[16])
                            start_w_inv[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            start_w_inv[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_START_S: begin
                        if (cmd_axis_tdata_i[16])
                            start_s[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            start_s[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_START_T: begin
                        if (cmd_axis_tdata_i[16])
                            start_t[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            start_t[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_START_R: begin
                        if (cmd_axis_tdata_i[16])
                            start_r[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            start_r[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_START_G: begin
                        if (cmd_axis_tdata_i[16])
                            start_g[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            start_g[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_START_B: begin
                        if (cmd_axis_tdata_i[16])
                            start_b[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            start_b[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DW_DX: begin
                        if (cmd_axis_tdata_i[16])
                            dw_dx[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            dw_dx[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DW_DY: begin
                        if (cmd_axis_tdata_i[16])
                            dw_dy[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            dw_dy[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DS_DX: begin
                        if (cmd_axis_tdata_i[16])
                            ds_dx[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            ds_dx[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DS_DY: begin
                        if (cmd_axis_tdata_i[16])
                            ds_dy[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            ds_dy[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DT_DX: begin
                        if (cmd_axis_tdata_i[16])
                            dt_dx[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            dt_dx[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DT_DY: begin
                        if (cmd_axis_tdata_i[16])
                            dt_dy[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            dt_dy[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DR_DX: begin
                        if (cmd_axis_tdata_i[16])
                            dr_dx[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            dr_dx[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DR_DY: begin
                        if (cmd_axis_tdata_i[16])
                            dr_dy[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            dr_dy[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DG_DX: begin
                        if (cmd_axis_tdata_i[16])
                            dg_dx[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            dg_dx[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DG_DY: begin
                        if (cmd_axis_tdata_i[16])
                            dg_dy[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            dg_dy[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DB_DX: begin
                        if (cmd_axis_tdata_i[16])
                            db_dx[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            db_dx[15:0] <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DB_DY: begin
                        if (cmd_axis_tdata_i[16])
                            db_dy[31:16] <= cmd_axis_tdata_i[15:0];
                        else
                            db_dy[15:0] <= cmd_axis_tdata_i[15:0];
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
                    clear_o       <= 1'b0;
                    core_vram_sel <= 1'b0;
                    core_vram_wr  <= 1'b0;
                    state         <= WAIT_COMMAND;
                end
            end

            CLEAR_DEPTH0: begin
                if (core_vram_addr < fb_address + 3 * FB_WIDTH * FB_HEIGHT - 1)
                    core_vram_addr <= core_vram_addr + 1;
                else begin
                    clear_o       <= 1'b0;
                    core_vram_sel <= 1'b0;
                    core_vram_wr  <= 1'b0;
                    state         <= WAIT_COMMAND;
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
