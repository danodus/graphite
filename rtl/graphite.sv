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

    logic signed [31:0] vv00, vv01, vv02, vv10, vv11, vv12, vv20, vv21, vv22;
    logic signed [31:0] c00, c01, c02, c10, c11, c12, c20, c21, c22;
    logic signed [31:0] st00, st01, st10, st11, st20, st21;
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
        .vv00_o(vv00), .vv01_o(vv01), .vv02_o(vv02),
        .vv10_o(vv10), .vv11_o(vv11), .vv12_o(vv12),
        .vv20_o(vv20), .vv21_o(vv21), .vv22_o(vv22),
        .c00_o(c00), .c01_o(c01), .c02_o(c02),
        .c10_o(c10), .c11_o(c11), .c12_o(c12),
        .c20_o(c20), .c21_o(c21), .c22_o(c22),
        .st00_o(st00), .st01_o(st01), .st10_o(st10), .st11_o(st11), .st20_o(st20), .st21_o(st21),
        .fb_address_o(fb_address), .texture_address_o(texture_address),
        .back_rel_address_o(back_rel_address), .depth_rel_address_o(depth_rel_address),
        .is_textured_o(is_textured), .is_clamp_s_o(is_clamp_s), .is_clamp_t_o(is_clamp_t),
        .is_depth_test_o(is_depth_test), .is_perspective_correct_o(is_perspective_correct),
        .texture_width_scale_o(texture_width_scale), .texture_height_scale_o(texture_height_scale)
    );

    graphite_rasterizer #(
        .FB_WIDTH(FB_WIDTH),
        .FB_HEIGHT(FB_HEIGHT),
        .TEXTURE_WIDTH(TEXTURE_WIDTH),
        .TEXTURE_HEIGHT(TEXTURE_HEIGHT)
    ) rasterizer (
        .clk(clk),
        .reset_i(reset_i),
        .ce_i(ce_i),
        .start_i(raster_start),
        .vv00_i(vv00), .vv01_i(vv01), .vv02_i(vv02),
        .vv10_i(vv10), .vv11_i(vv11), .vv12_i(vv12),
        .vv20_i(vv20), .vv21_i(vv21), .vv22_i(vv22),
        .c00_i(c00), .c01_i(c01), .c02_i(c02),
        .c10_i(c10), .c11_i(c11), .c12_i(c12),
        .c20_i(c20), .c21_i(c21), .c22_i(c22),
        .st00_i(st00), .st01_i(st01), .st10_i(st10), .st11_i(st11), .st20_i(st20), .st21_i(st21),
        .fb_address_i(fb_address), .texture_address_i(texture_address),
        .back_rel_address_i(back_rel_address), .depth_rel_address_i(depth_rel_address),
        .is_textured_i(is_textured), .is_clamp_s_i(is_clamp_s), .is_clamp_t_i(is_clamp_t),
        .is_depth_test_i(is_depth_test), .is_perspective_correct_i(is_perspective_correct),
        .texture_width_scale_i(texture_width_scale), .texture_height_scale_i(texture_height_scale),
        .vram_data_in_i(vram_data_in_i),
        .busy_o(raster_busy),
        .fs_busy_o(fs_busy),
        .vram_sel_o(raster_vram_sel),
        .vram_wr_o(raster_vram_wr),
        .vram_mask_o(raster_vram_mask),
        .vram_addr_o(raster_vram_addr),
        .vram_data_out_o(raster_vram_data_out)
    );

    assign vram_sel_o = fs_busy ? raster_vram_sel : core_vram_sel;
    assign vram_wr_o = fs_busy ? raster_vram_wr : core_vram_wr;
    assign vram_mask_o = fs_busy ? raster_vram_mask : core_vram_mask;
    assign vram_addr_o = fs_busy ? raster_vram_addr : core_vram_addr;
    assign vram_data_out_o = fs_busy ? raster_vram_data_out : core_vram_data_out;

endmodule
