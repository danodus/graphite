// graphite.sv
// Copyright (c) 2021-2026 Daniel Cliche
// SPDX-License-Identifier: MIT

`include "graphite.svh"

module graphite #(
    parameter FB_ADDRESS = 32'h0,
    parameter FB_WIDTH = 128,
    parameter FB_HEIGHT = 128,
    parameter TEXTURE_WIDTH = 32,
    parameter TEXTURE_HEIGHT = 32,
    parameter SUBPIXEL_PRECISION_MASK = 16'hF000
) (
    input  wire logic clk,
    input  wire logic reset_i,
    input  wire logic ce_i,

    input  wire logic cmd_axis_tvalid_i,
    output      logic cmd_axis_tready_o,
    input  wire logic [31:0] cmd_axis_tdata_i,

    output      logic vram_sel_o,
    output      logic vram_wr_o,
    output      logic [3:0] vram_mask_o,
    output      logic [31:0] vram_addr_o,
    input       logic [15:0] vram_data_in_i,
    output      logic [15:0] vram_data_out_o,

    input  wire logic vsync_i,
    output      logic swap_o,
    output      logic [31:0] front_addr_o,
    output      logic clear_o
);

    logic raster_start;
    logic raster_busy;
    logic fs_busy;

    logic core_vram_sel, core_vram_wr;
    logic [3:0] core_vram_mask;
    logic [31:0] core_vram_addr;
    logic [15:0] core_vram_data_out;

    logic raster_vram_sel, raster_vram_wr;
    logic [3:0] raster_vram_mask;
    logic [31:0] raster_vram_addr;
    logic [15:0] raster_vram_data_out;

    logic signed [15:0] v0_x, v0_y, v1_x, v1_y, v2_x, v2_y;
    logic sign;
    logic signed [31:0] start_w_inv, start_s, start_t, start_r, start_g, start_b;
    logic signed [31:0] dw_dx, dw_dy, ds_dx, ds_dy, dt_dx, dt_dy;
    logic signed [31:0] dr_dx, dr_dy, dg_dx, dg_dy, db_dx, db_dy;
    logic [31:0] fb_address, texture_address, back_rel_address, depth_rel_address;
    logic is_textured, is_clamp_s, is_clamp_t, is_depth_test, is_perspective_correct;
    logic [2:0] texture_width_scale, texture_height_scale;

    graphite_command_processor #(
        .FB_ADDRESS(FB_ADDRESS),
        .FB_WIDTH(FB_WIDTH),
        .FB_HEIGHT(FB_HEIGHT),
        .SUBPIXEL_PRECISION_MASK(SUBPIXEL_PRECISION_MASK)
    ) cmd_proc (
        .clk(clk),
        .reset_i(reset_i),
        .ce_i(ce_i),
        .cmd_axis_tvalid_i(cmd_axis_tvalid_i),
        .cmd_axis_tready_o(cmd_axis_tready_o),
        .cmd_axis_tdata_i(cmd_axis_tdata_i),
        .vsync_i(vsync_i),
        .raster_busy_i(raster_busy),
        .raster_start_o(raster_start),
        .swap_o(swap_o),
        .clear_o(clear_o),
        .front_addr_o(front_addr_o),
        .core_vram_sel_o(core_vram_sel),
        .core_vram_wr_o(core_vram_wr),
        .core_vram_mask_o(core_vram_mask),
        .core_vram_addr_o(core_vram_addr),
        .core_vram_data_out_o(core_vram_data_out),
        .v0_x_o(v0_x), .v0_y_o(v0_y), .v1_x_o(v1_x), .v1_y_o(v1_y), .v2_x_o(v2_x), .v2_y_o(v2_y),
        .sign_o(sign),
        .start_w_inv_o(start_w_inv), .start_s_o(start_s), .start_t_o(start_t), .start_r_o(start_r), .start_g_o(start_g), .start_b_o(start_b),
        .dw_dx_o(dw_dx), .dw_dy_o(dw_dy), .ds_dx_o(ds_dx), .ds_dy_o(ds_dy), .dt_dx_o(dt_dx), .dt_dy_o(dt_dy),
        .dr_dx_o(dr_dx), .dr_dy_o(dr_dy), .dg_dx_o(dg_dx), .dg_dy_o(dg_dy), .db_dx_o(db_dx), .db_dy_o(db_dy),
        .fb_address_o(fb_address), .texture_address_o(texture_address),
        .back_rel_address_o(back_rel_address), .depth_rel_address_o(depth_rel_address),
        .is_textured_o(is_textured), .is_clamp_s_o(is_clamp_s), .is_clamp_t_o(is_clamp_t),
        .is_depth_test_o(is_depth_test), .is_perspective_correct_o(is_perspective_correct),
        .texture_width_scale_o(texture_width_scale), .texture_height_scale_o(texture_height_scale)
    );

    logic tex_req;
    logic [31:0] tex_addr;
    logic tex_ack;
    logic [31:0] tex_rdata;

    logic fb_req;
    logic [31:0] fb_addr;
    logic [31:0] fb_wdata;
    logic fb_ack;

    logic zb_req;
    logic zb_we;
    logic [31:0] zb_addr;
    logic [15:0] zb_wdata;
    logic zb_ack;
    logic [15:0] zb_rdata;

    graphite_rasterizer #(
        .FB_WIDTH(FB_WIDTH),
        .FB_HEIGHT(FB_HEIGHT)
    ) rasterizer (
        .clk(clk),
        .ce(ce_i),
        .rst_n(!reset_i),
        .start(raster_start),
        .busy(raster_busy),
        .enable_texture(is_textured),
        .enable_depth_test(is_depth_test),
        .clamp_s(is_clamp_s),
        .clamp_t(is_clamp_t),
        .texture_width_scale(texture_width_scale),
        .texture_height_scale(texture_height_scale),
        .v0_x(v0_x), .v0_y(v0_y), .v1_x(v1_x), .v1_y(v1_y), .v2_x(v2_x), .v2_y(v2_y),
        .sign(sign),
        .start_w_inv(start_w_inv), .start_s(start_s), .start_t(start_t), .start_r(start_r), .start_g(start_g), .start_b(start_b),
        .dw_dx(dw_dx), .dw_dy(dw_dy), .ds_dx(ds_dx), .ds_dy(ds_dy), .dt_dx(dt_dx), .dt_dy(dt_dy),
        .dr_dx(dr_dx), .dr_dy(dr_dy), .dg_dx(dg_dx), .dg_dy(dg_dy), .db_dx(db_dx), .db_dy(db_dy),
        .tex_req(tex_req), .tex_addr(tex_addr), .tex_ack(tex_ack), .tex_rdata(tex_rdata),
        .fb_req(fb_req), .fb_addr(fb_addr), .fb_wdata(fb_wdata), .fb_ack(fb_ack),
        .zb_req(zb_req), .zb_we(zb_we), .zb_addr(zb_addr), .zb_wdata(zb_wdata), .zb_ack(zb_ack), .zb_rdata(zb_rdata)
    );

    // Rasterizer VRAM arbiter
    logic [15:0] fb_wdata_565;
    assign fb_wdata_565 = {fb_wdata[23:19], fb_wdata[15:10], fb_wdata[7:3]};

    assign tex_rdata = {vram_data_in_i[15:12], vram_data_in_i[15:12],
                        vram_data_in_i[11:8], vram_data_in_i[11:8],
                        vram_data_in_i[7:4], vram_data_in_i[7:4],
                        vram_data_in_i[3:0], vram_data_in_i[3:0]};
    assign zb_rdata = vram_data_in_i;

    always_comb begin
        raster_vram_sel = 0;
        raster_vram_wr = 0;
        raster_vram_mask = 4'hF;
        raster_vram_addr = 0;
        raster_vram_data_out = 0;
        zb_ack = 0;
        tex_ack = 0;
        fb_ack = 0;

        if (zb_req && !zb_we) begin
            raster_vram_sel = 1;
            raster_vram_wr = 0;
            raster_vram_addr = fb_address + depth_rel_address + zb_addr;
            zb_ack = 1;
        end else if (tex_req) begin
            raster_vram_sel = 1;
            raster_vram_wr = 0;
            raster_vram_addr = texture_address + tex_addr;
            tex_ack = 1;
        end else if (zb_req && zb_we) begin
            raster_vram_sel = 1;
            raster_vram_wr = 1;
            raster_vram_addr = fb_address + depth_rel_address + zb_addr;
            raster_vram_data_out = zb_wdata;
            zb_ack = 1;
        end else if (fb_req) begin
            raster_vram_sel = 1;
            raster_vram_wr = 1;
            raster_vram_addr = fb_address + back_rel_address + fb_addr;
            raster_vram_data_out = fb_wdata_565;
            fb_ack = 1;
        end
    end

    assign fs_busy = 0; // Legacy signal
    
    assign vram_sel_o = raster_vram_sel | core_vram_sel;
    assign vram_wr_o = raster_vram_wr | core_vram_wr;
    assign vram_mask_o = raster_vram_sel ? raster_vram_mask : core_vram_mask;
    assign vram_addr_o = raster_vram_sel ? raster_vram_addr : core_vram_addr;
    assign vram_data_out_o = raster_vram_sel ? raster_vram_data_out : core_vram_data_out;

endmodule
