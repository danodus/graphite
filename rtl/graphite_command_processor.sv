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

    output logic signed [15:0] v0_x_o, v0_y_o, v1_x_o, v1_y_o, v2_x_o, v2_y_o,
    output logic sign_o,
    output logic signed [31:0] start_w_inv_o, start_s_o, start_t_o, start_r_o, start_g_o, start_b_o,
    output logic signed [31:0] dw_dx_o, dw_dy_o, ds_dx_o, ds_dy_o, dt_dx_o, dt_dy_o,
    output logic signed [31:0] dr_dx_o, dr_dy_o, dg_dx_o, dg_dy_o, db_dx_o, db_dy_o,

    output logic [31:0] fb_address_o,
    output logic [31:0] texture_address_o,
    output logic [31:0] back_rel_address_o,
    output logic [31:0] depth_address_o,

    output logic is_textured_o,
    output logic is_clamp_s_o,
    output logic is_clamp_t_o,
    output logic is_depth_test_o,
    output logic is_perspective_correct_o,
    output logic is_depth_only_o,
    output logic is_shadow_o,
    output logic is_dither_o,
    output logic [2:0] texture_width_scale_o,
    output logic [2:0] texture_height_scale_o,

    output logic signed [31:0] start_su_o, start_sv_o, start_sz_o,
    output logic signed [31:0] dsu_dx_o, dsu_dy_o, dsv_dx_o, dsv_dy_o, dsz_dx_o, dsz_dy_o,
    output logic [15:0] viewport_width_o,
    output logic [15:0] viewport_height_o,
    output logic [31:0] shadow_address_o,
    output logic [2:0] shadow_width_scale_o,
    output logic [2:0] shadow_height_scale_o,
    output logic [15:0] shadow_bias_o,
    output logic [7:0] depth_bias_o
);

    enum { WAIT_COMMAND, PROCESS_COMMAND, WAIT_RASTER, SWAP0, CLEAR_FB0, CLEAR_DEPTH0 } state;

    logic signed [15:0] v0_x, v0_y, v1_x, v1_y, v2_x, v2_y;
    logic sign_reg;
    logic signed [31:0] start_w_inv, start_s, start_t, start_r, start_g, start_b;
    logic signed [31:0] dw_dx, dw_dy, ds_dx, ds_dy, dt_dx, dt_dy;
    logic signed [31:0] dr_dx, dr_dy, dg_dx, dg_dy, db_dx, db_dy;
    logic signed [31:0] start_su, start_sv, start_sz;
    logic signed [31:0] dsu_dx, dsu_dy, dsv_dx, dsv_dy, dsz_dx, dsz_dy;

    logic [31:0] fb_address, texture_address;
    logic [31:0] front_rel_address, back_rel_address;
    logic [31:0] depth_address, shadow_address;
    logic [31:0] texture_write_address;
    logic [15:0] viewport_width, viewport_height;
    logic [31:0] viewport_pixels;

    logic is_textured, is_clamp_s, is_clamp_t, is_depth_test, is_perspective_correct;
    logic is_depth_only, is_shadow, is_dither;
    logic [2:0] texture_width_scale, texture_height_scale;
    logic [2:0] shadow_width_scale, shadow_height_scale;
    logic [15:0] shadow_bias;
    logic [7:0] depth_bias;

    // Screen-sized clears use the elaborated product. Power-of-two viewports
    // (the shadow map) use a shift so this path does not infer a multiplier.
    function automatic [31:0] span_pixels(input [15:0] w, input [15:0] h);
        reg [4:0] lw, lh;
        begin
            lw = 5'd31;
            lh = 5'd31;
            case (w)
                16'd32:   lw = 5'd5;
                16'd64:   lw = 5'd6;
                16'd128:  lw = 5'd7;
                16'd256:  lw = 5'd8;
                16'd512:  lw = 5'd9;
                16'd1024: lw = 5'd10;
                default:  lw = 5'd31;
            endcase
            case (h)
                16'd32:   lh = 5'd5;
                16'd64:   lh = 5'd6;
                16'd128:  lh = 5'd7;
                16'd256:  lh = 5'd8;
                16'd512:  lh = 5'd9;
                16'd1024: lh = 5'd10;
                default:  lh = 5'd31;
            endcase
            if (w == FB_WIDTH && h == FB_HEIGHT)
                span_pixels = FB_WIDTH * FB_HEIGHT;
            else if (lw != 5'd31 && lh != 5'd31)
                span_pixels = 32'd1 << (lw + lh);
            else
                span_pixels = FB_WIDTH * FB_HEIGHT;
        end
    endfunction

    logic core_vram_sel, core_vram_wr;
    logic [3:0] core_vram_mask;
    logic [31:0] core_vram_addr;
    logic [15:0] core_vram_data_out;

    assign front_addr_o = fb_address + front_rel_address;
    assign cmd_axis_tready_o = (state == WAIT_COMMAND) && !raster_busy_i;

    assign v0_x_o = v0_x;
    assign v0_y_o = v0_y;
    assign v1_x_o = v1_x;
    assign v1_y_o = v1_y;
    assign v2_x_o = v2_x;
    assign v2_y_o = v2_y;
    assign sign_o = sign_reg;
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
    assign depth_address_o = depth_address;
    assign is_textured_o = is_textured;
    assign is_clamp_s_o = is_clamp_s;
    assign is_clamp_t_o = is_clamp_t;
    assign is_depth_test_o = is_depth_test;
    assign is_perspective_correct_o = is_perspective_correct;
    assign is_depth_only_o = is_depth_only;
    assign is_shadow_o = is_shadow;
    assign is_dither_o = is_dither;
    assign texture_width_scale_o = texture_width_scale;
    assign texture_height_scale_o = texture_height_scale;
    assign start_su_o = start_su;
    assign start_sv_o = start_sv;
    assign start_sz_o = start_sz;
    assign dsu_dx_o = dsu_dx;
    assign dsu_dy_o = dsu_dy;
    assign dsv_dx_o = dsv_dx;
    assign dsv_dy_o = dsv_dy;
    assign dsz_dx_o = dsz_dx;
    assign dsz_dy_o = dsz_dy;
    assign viewport_width_o = viewport_width;
    assign viewport_height_o = viewport_height;
    assign shadow_address_o = shadow_address;
    assign shadow_width_scale_o = shadow_width_scale;
    assign shadow_height_scale_o = shadow_height_scale;
    assign shadow_bias_o = shadow_bias;
    assign depth_bias_o = depth_bias;

    assign core_vram_sel_o = core_vram_sel;
    assign core_vram_wr_o = core_vram_wr;
    assign core_vram_mask_o = core_vram_mask;
    assign core_vram_addr_o = core_vram_addr;
    assign core_vram_data_out_o = core_vram_data_out;

    always_ff @(posedge clk) begin
        if (reset_i) begin
            swap_o            <= 1'b0;
            core_vram_sel     <= 1'b0;
            core_vram_wr      <= 1'b0;
            clear_o           <= 1'b0;
            fb_address        <= FB_ADDRESS;
            front_rel_address <= 32'h0;
            back_rel_address  <= FB_WIDTH * FB_HEIGHT;
            depth_address     <= FB_ADDRESS + 2 * FB_WIDTH * FB_HEIGHT;
            shadow_address    <= FB_ADDRESS + 3 * FB_WIDTH * FB_HEIGHT;
            viewport_width    <= FB_WIDTH;
            viewport_height   <= FB_HEIGHT;
            viewport_pixels   <= FB_WIDTH * FB_HEIGHT;
            // The sim and older command streams rely on this reset base. The
            // flight demo moves it past the shadow map with OP_SET_TEX_ADDR.
            texture_address   <= FB_ADDRESS + 3 * FB_WIDTH * FB_HEIGHT;
            state             <= WAIT_COMMAND;
            texture_width_scale  <= 3'd0;
            texture_height_scale <= 3'd0;
            shadow_width_scale   <= 3'd0;
            shadow_height_scale  <= 3'd0;
            shadow_bias          <= 16'd0;
            depth_bias           <= 8'd0;
            is_depth_only        <= 1'b0;
            is_shadow            <= 1'b0;
            is_dither            <= 1'b0;
            raster_start_o    <= 1'b0;
        end else if (ce_i) begin
            raster_start_o <= 1'b0;
            case (state)
                WAIT_COMMAND: begin
                swap_o <= 1'b0;
                if (cmd_axis_tvalid_i)
                    state <= PROCESS_COMMAND;
            end

            PROCESS_COMMAND: begin
                case (cmd_axis_tdata_i[OP_POS+:OP_SIZE])
                    OP_SET_V0_X: begin
                        v0_x <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_V0_Y: begin
                        v0_y <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_V1_X: begin
                        v1_x <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_V1_Y: begin
                        v1_y <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_V2_X: begin
                        v2_x <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_V2_Y: begin
                        v2_y <= cmd_axis_tdata_i[15:0];
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
                        core_vram_addr     <= (cmd_axis_tdata_i[16] == 0) ? (fb_address + back_rel_address) : depth_address;
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
                        sign_reg               <= cmd_axis_tdata_i[5];
                        texture_width_scale    <= cmd_axis_tdata_i[8:6];
                        texture_height_scale   <= cmd_axis_tdata_i[11:9];
                        is_depth_only          <= cmd_axis_tdata_i[12];
                        is_shadow              <= cmd_axis_tdata_i[13];
                        depth_bias             <= cmd_axis_tdata_i[21:14];
                        is_dither              <= cmd_axis_tdata_i[22];
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
                    OP_SET_START_SU: begin
                        if (cmd_axis_tdata_i[16]) start_su[31:16] <= cmd_axis_tdata_i[15:0];
                        else                      start_su[15:0]  <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_START_SV: begin
                        if (cmd_axis_tdata_i[16]) start_sv[31:16] <= cmd_axis_tdata_i[15:0];
                        else                      start_sv[15:0]  <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_START_SZ: begin
                        if (cmd_axis_tdata_i[16]) start_sz[31:16] <= cmd_axis_tdata_i[15:0];
                        else                      start_sz[15:0]  <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DSU_DX: begin
                        if (cmd_axis_tdata_i[16]) dsu_dx[31:16] <= cmd_axis_tdata_i[15:0];
                        else                      dsu_dx[15:0]  <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DSU_DY: begin
                        if (cmd_axis_tdata_i[16]) dsu_dy[31:16] <= cmd_axis_tdata_i[15:0];
                        else                      dsu_dy[15:0]  <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DSV_DX: begin
                        if (cmd_axis_tdata_i[16]) dsv_dx[31:16] <= cmd_axis_tdata_i[15:0];
                        else                      dsv_dx[15:0]  <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DSV_DY: begin
                        if (cmd_axis_tdata_i[16]) dsv_dy[31:16] <= cmd_axis_tdata_i[15:0];
                        else                      dsv_dy[15:0]  <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DSZ_DX: begin
                        if (cmd_axis_tdata_i[16]) dsz_dx[31:16] <= cmd_axis_tdata_i[15:0];
                        else                      dsz_dx[15:0]  <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DSZ_DY: begin
                        if (cmd_axis_tdata_i[16]) dsz_dy[31:16] <= cmd_axis_tdata_i[15:0];
                        else                      dsz_dy[15:0]  <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_VIEWPORT: begin
                        viewport_width  <= {4'd0, cmd_axis_tdata_i[11:0]};
                        viewport_height <= {4'd0, cmd_axis_tdata_i[23:12]};
                        viewport_pixels <= span_pixels({4'd0, cmd_axis_tdata_i[11:0]}, {4'd0, cmd_axis_tdata_i[23:12]});
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_ZB_ADDR: begin
                        if (cmd_axis_tdata_i[16]) depth_address[31:16] <= cmd_axis_tdata_i[15:0];
                        else                      depth_address[15:0]  <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_SHADOW: begin
                        if (cmd_axis_tdata_i[16]) shadow_address[31:16] <= cmd_axis_tdata_i[15:0];
                        else                      shadow_address[15:0]  <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_SHADOW_PARAM: begin
                        shadow_width_scale  <= cmd_axis_tdata_i[2:0];
                        shadow_height_scale <= cmd_axis_tdata_i[5:3];
                        shadow_bias         <= cmd_axis_tdata_i[21:6];
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
                if (core_vram_addr < depth_address + viewport_pixels - 1)
                    core_vram_addr <= core_vram_addr + 1;
                else begin
                    clear_o       <= 1'b0;
                    core_vram_sel <= 1'b0;
                    core_vram_wr  <= 1'b0;
                    state         <= WAIT_COMMAND;
                end
            end
            endcase
        end
    end

endmodule
