// graphite_rasterizer.sv
// Copyright (c) 2021-2026 Daniel Cliche
// SPDX-License-Identifier: MIT

`include "graphite.svh"

module dsp_mul(
    input wire logic signed [31:0] p0,
    input wire logic signed [31:0] p1,
    output     logic signed [63:0] z
);
    assign z = mul(p0, p1);
endmodule

module graphite_rasterizer #(
    parameter FB_WIDTH = 128,
    parameter FB_HEIGHT = 128,
    parameter TEXTURE_WIDTH = 32,
    parameter TEXTURE_HEIGHT = 32
) (
    input  wire logic clk,
    input  wire logic reset_i,
    input  wire logic ce_i,
    input  wire logic start_i,

    input  wire logic signed [31:0] vv00_i, vv01_i, vv02_i,
    input  wire logic signed [31:0] vv10_i, vv11_i, vv12_i,
    input  wire logic signed [31:0] vv20_i, vv21_i, vv22_i,
    input  wire logic signed [31:0] c00_i, c01_i, c02_i,
    input  wire logic signed [31:0] c10_i, c11_i, c12_i,
    input  wire logic signed [31:0] c20_i, c21_i, c22_i,
    input  wire logic signed [31:0] st00_i, st01_i, st10_i, st11_i, st20_i, st21_i,

    input  wire logic [31:0] fb_address_i,
    input  wire logic [31:0] texture_address_i,
    input  wire logic [31:0] back_rel_address_i,
    input  wire logic [31:0] depth_rel_address_i,

    input  wire logic is_textured_i,
    input  wire logic is_clamp_s_i,
    input  wire logic is_clamp_t_i,
    input  wire logic is_depth_test_i,
    input  wire logic is_perspective_correct_i,
    input  wire logic [2:0] texture_width_scale_i,
    input  wire logic [2:0] texture_height_scale_i,

    input  wire logic [15:0] vram_data_in_i,

    output logic busy_o,
    output logic fs_busy_o,

    output logic vram_sel_o,
    output logic vram_wr_o,
    output logic [3:0] vram_mask_o,
    output logic [31:0] vram_addr_o,
    output logic [15:0] vram_data_out_o
);

    enum { IDLE,
           DRAW_TRIANGLE00, DRAW_TRIANGLE01, DRAW_TRIANGLE02, DRAW_TRIANGLE04, DRAW_TRIANGLE05, DRAW_TRIANGLE06, DRAW_TRIANGLE07, DRAW_TRIANGLE08,
           DRAW_TRIANGLE12, DRAW_TRIANGLE13, DRAW_TRIANGLE15,
           DRAW_TRIANGLE18, DRAW_TRIANGLE21,
           DRAW_TRIANGLE24, DRAW_TRIANGLE25, DRAW_TRIANGLE28,
           DRAW_TRIANGLE31, DRAW_TRIANGLE32, DRAW_TRIANGLE33, DRAW_TRIANGLE_FRAGMENT,
           DRAW_TRIANGLE59,
           DRAW_TRIANGLE60
    } state;

    localparam NB_DSP_MULS = 3;

    logic signed [11:0] x, y;
    logic signed [11:0] min_x, min_y, max_x, max_y;

    logic signed [31:0] w0, w1, w2;
    logic signed [31:0] inv_area;
    logic signed [31:0] s, t;
    logic signed [31:0] r, g, b;

    logic signed [31:0] p0, p1;
    logic signed [31:0] raster_dsp_mul_p0[NB_DSP_MULS], raster_dsp_mul_p1[NB_DSP_MULS];
    wire signed [31:0] frag_dsp_mul_p0[NB_DSP_MULS], frag_dsp_mul_p1[NB_DSP_MULS];
    wire signed [31:0] dsp_mul_p0[NB_DSP_MULS], dsp_mul_p1[NB_DSP_MULS];
    logic signed [63:0] dsp_mul_z[NB_DSP_MULS];

    logic [31:0] z;
    logic [15:0] sample;
    logic [31:0] raster_rel_address;

    logic [31:0] raster_reciprocal_x;
    logic raster_reciprocal_start;
    wire [31:0] frag_reciprocal_x;
    wire frag_reciprocal_start;
    wire [31:0] reciprocal_x;
    wire reciprocal_start;
    logic [31:0] reciprocal_z;
    logic reciprocal_done;

    logic frag_launch;
    logic start_pending;
    wire fs_busy;
    wire frag_done;

    wire fs_vram_sel_o, fs_vram_wr_o;
    wire [3:0] fs_vram_mask_o;
    wire [31:0] fs_vram_addr_o;
    wire [15:0] fs_vram_data_out_o;

    assign busy_o = (state != IDLE);
    assign fs_busy_o = fs_busy;

    assign p0 = {6'd0, x, 14'd0};
    assign p1 = {6'd0, y, 14'd0};

    genvar mi;
    generate
        for (mi = 0; mi < NB_DSP_MULS; mi++) begin : gen_dsp_mux
            assign dsp_mul_p0[mi] = fs_busy ? frag_dsp_mul_p0[mi] : raster_dsp_mul_p0[mi];
            assign dsp_mul_p1[mi] = fs_busy ? frag_dsp_mul_p1[mi] : raster_dsp_mul_p1[mi];
        end
    endgenerate

    genvar dsp_mul_index;
    generate
        for (dsp_mul_index = 0; dsp_mul_index < NB_DSP_MULS; dsp_mul_index = dsp_mul_index + 1) begin
            dsp_mul dsp_mul_inst(
                .p0(dsp_mul_p0[dsp_mul_index]),
                .p1(dsp_mul_p1[dsp_mul_index]),
                .z(dsp_mul_z[dsp_mul_index])
            );
        end
    endgenerate

    reciprocal reciprocal_inst(
        .clk(clk),
        .reset_i(reset_i),
        .start_i(reciprocal_start),
        .x_i(reciprocal_x),
        .z_o(reciprocal_z),
        .done_o(reciprocal_done)
    );

    graphite_fragment_shader #(
        .FB_WIDTH(FB_WIDTH),
        .FB_HEIGHT(FB_HEIGHT),
        .TEXTURE_WIDTH(TEXTURE_WIDTH),
        .TEXTURE_HEIGHT(TEXTURE_HEIGHT)
    ) fragment (
        .clk(clk),
        .reset_i(reset_i),
        .ce_i(ce_i),
        .start_i(frag_launch),
        .x_i(x),
        .y_i(y),
        .z_i(z),
        .r_i(r),
        .g_i(g),
        .b_i(b),
        .s_i(s),
        .t_i(t),
        .sample_i(sample),
        .is_textured_i(is_textured_i),
        .is_clamp_s_i(is_clamp_s_i),
        .is_clamp_t_i(is_clamp_t_i),
        .is_depth_test_i(is_depth_test_i),
        .is_perspective_correct_i(is_perspective_correct_i),
        .texture_width_scale_i(texture_width_scale_i),
        .texture_height_scale_i(texture_height_scale_i),
        .fb_address_i(fb_address_i),
        .texture_address_i(texture_address_i),
        .depth_rel_address_i(depth_rel_address_i),
        .back_rel_address_i(back_rel_address_i),
        .raster_rel_address_i(raster_rel_address),
        .vram_data_in_i(vram_data_in_i),
        .dsp_mul_z_0_i(dsp_mul_z[0]),
        .dsp_mul_z_1_i(dsp_mul_z[1]),
        .dsp_mul_z_2_i(dsp_mul_z[2]),
        .reciprocal_z_i(reciprocal_z),
        .reciprocal_done_i(reciprocal_done),
        .busy_o(fs_busy),
        .done_o(frag_done),
        .fs_dsp_mul_p0_0_o(frag_dsp_mul_p0[0]),
        .fs_dsp_mul_p0_1_o(frag_dsp_mul_p0[1]),
        .fs_dsp_mul_p0_2_o(frag_dsp_mul_p0[2]),
        .fs_dsp_mul_p1_0_o(frag_dsp_mul_p1[0]),
        .fs_dsp_mul_p1_1_o(frag_dsp_mul_p1[1]),
        .fs_dsp_mul_p1_2_o(frag_dsp_mul_p1[2]),
        .fs_reciprocal_x_o(frag_reciprocal_x),
        .fs_reciprocal_start_o(frag_reciprocal_start),
        .fs_vram_sel_o(fs_vram_sel_o),
        .fs_vram_wr_o(fs_vram_wr_o),
        .fs_vram_mask_o(fs_vram_mask_o),
        .fs_vram_addr_o(fs_vram_addr_o),
        .fs_vram_data_out_o(fs_vram_data_out_o)
    );

    assign reciprocal_x = fs_busy ? frag_reciprocal_x : raster_reciprocal_x;
    assign reciprocal_start = fs_busy ? frag_reciprocal_start : raster_reciprocal_start;

    assign vram_sel_o = fs_vram_sel_o;
    assign vram_wr_o = fs_vram_wr_o;
    assign vram_mask_o = fs_vram_mask_o;
    assign vram_addr_o = fs_vram_addr_o;
    assign vram_data_out_o = fs_vram_data_out_o;

    // Latch start (one-cycle pulse from cmd proc is easy to miss after module split).
    always_ff @(posedge clk) begin
        if (reset_i) begin
            start_pending <= 1'b0;
        end else begin
            if (start_i)
                start_pending <= 1'b1;
            else if (ce_i && state != IDLE)
                start_pending <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if (ce_i) case (state)
            IDLE: begin
                if (start_pending)
                    state <= DRAW_TRIANGLE00;
            end

            DRAW_TRIANGLE00: begin
                min_x <= max(min3(12'(vv00_i >> 14), 12'(vv10_i >> 14), 12'(vv20_i >> 14)), 0);
                min_y <= max(min3(12'(vv01_i >> 14), 12'(vv11_i >> 14), 12'(vv21_i >> 14)), 0);
                max_x <= min(max3(12'(vv00_i >> 14), 12'(vv10_i >> 14), 12'(vv20_i >> 14)), FB_WIDTH - 1);
                max_y <= min(max3(12'(vv01_i >> 14), 12'(vv11_i >> 14), 12'(vv21_i >> 14)), FB_HEIGHT - 1);
                state <= DRAW_TRIANGLE01;
            end

            DRAW_TRIANGLE01: begin
                raster_dsp_mul_p0[0] <= (vv20_i - vv00_i);
                raster_dsp_mul_p1[0] <= (vv11_i - vv01_i);
                raster_dsp_mul_p0[1] <= (vv21_i - vv01_i);
                raster_dsp_mul_p1[1] <= (vv10_i - vv00_i);
                state <= DRAW_TRIANGLE02;
            end

            DRAW_TRIANGLE02: begin
                raster_reciprocal_x <= dsp_mul_z[0][31:0] - dsp_mul_z[1][31:0];
                raster_reciprocal_start <= 1'b1;
                state <= DRAW_TRIANGLE04;
            end

            DRAW_TRIANGLE04: begin
                raster_reciprocal_start <= 1'b0;
                if (reciprocal_done) begin
                    inv_area <= reciprocal_z;
                    x <= min_x;
                    y <= min_y;
                    raster_rel_address <= {20'd0, min_y} * FB_WIDTH + {20'd0, min_x};
                    state <= DRAW_TRIANGLE05;
                end
            end

            DRAW_TRIANGLE05: begin
                raster_dsp_mul_p0[0] <= (p0 - vv10_i);
                raster_dsp_mul_p1[0] <= (vv21_i - vv11_i);
                raster_dsp_mul_p0[1] <= (p1 - vv11_i);
                raster_dsp_mul_p1[1] <= (vv20_i - vv10_i);
                state <= DRAW_TRIANGLE06;
            end

            DRAW_TRIANGLE06: begin
                w0 <= dsp_mul_z[0][31:0] - dsp_mul_z[1][31:0];
                raster_dsp_mul_p0[0] <= (p0 - vv20_i);
                raster_dsp_mul_p1[0] <= (vv01_i - vv21_i);
                raster_dsp_mul_p0[1] <= (p1 - vv21_i);
                raster_dsp_mul_p1[1] <= (vv00_i - vv20_i);
                state <= DRAW_TRIANGLE07;
            end

            DRAW_TRIANGLE07: begin
                w1 <= dsp_mul_z[0][31:0] - dsp_mul_z[1][31:0];
                raster_dsp_mul_p0[0] <= (p0 - vv00_i);
                raster_dsp_mul_p1[0] <= (vv11_i - vv01_i);
                raster_dsp_mul_p0[1] <= (p1 - vv01_i);
                raster_dsp_mul_p1[1] <= (vv10_i - vv00_i);
                state <= DRAW_TRIANGLE08;
            end

            DRAW_TRIANGLE08: begin
                w2 <= dsp_mul_z[0][31:0] - dsp_mul_z[1][31:0];
                state <= DRAW_TRIANGLE12;
            end

            DRAW_TRIANGLE12: begin
                if (w0[31] || w1[31] || w2[31]) begin
                    state <= DRAW_TRIANGLE59;
                end else begin
                    raster_dsp_mul_p0[0] <= w0;
                    raster_dsp_mul_p1[0] <= inv_area;
                    raster_dsp_mul_p0[1] <= w1;
                    raster_dsp_mul_p1[1] <= inv_area;
                    raster_dsp_mul_p0[2] <= w2;
                    raster_dsp_mul_p1[2] <= inv_area;
                    state <= DRAW_TRIANGLE13;
                end
            end

            DRAW_TRIANGLE13: begin
                w0 <= dsp_mul_z[0][31:0] >> 8;
                w1 <= dsp_mul_z[1][31:0] >> 8;
                w2 <= dsp_mul_z[2][31:0] >> 8;
                state <= DRAW_TRIANGLE15;
            end

            DRAW_TRIANGLE15: begin
                raster_dsp_mul_p0[0] <= w0;
                raster_dsp_mul_p1[0] <= c00_i;
                raster_dsp_mul_p0[1] <= w1;
                raster_dsp_mul_p1[1] <= c10_i;
                raster_dsp_mul_p0[2] <= w2;
                raster_dsp_mul_p1[2] <= c20_i;
                state <= DRAW_TRIANGLE18;
            end

            DRAW_TRIANGLE18: begin
                r <= dsp_mul_z[0][31:0] + dsp_mul_z[1][31:0] + dsp_mul_z[2][31:0];
                raster_dsp_mul_p0[0] <= w0;
                raster_dsp_mul_p1[0] <= c01_i;
                raster_dsp_mul_p0[1] <= w1;
                raster_dsp_mul_p1[1] <= c11_i;
                raster_dsp_mul_p0[2] <= w2;
                raster_dsp_mul_p1[2] <= c21_i;
                state <= DRAW_TRIANGLE21;
            end

            DRAW_TRIANGLE21: begin
                g <= dsp_mul_z[0][31:0] + dsp_mul_z[1][31:0] + dsp_mul_z[2][31:0];
                raster_dsp_mul_p0[0] <= w0;
                raster_dsp_mul_p1[0] <= c02_i;
                raster_dsp_mul_p0[1] <= w1;
                raster_dsp_mul_p1[1] <= c12_i;
                raster_dsp_mul_p0[2] <= w2;
                raster_dsp_mul_p1[2] <= c22_i;
                state <= DRAW_TRIANGLE24;
            end

            DRAW_TRIANGLE24: begin
                b <= dsp_mul_z[0][31:0] + dsp_mul_z[1][31:0] + dsp_mul_z[2][31:0];
                if (is_textured_i) begin
                    state <= DRAW_TRIANGLE25;
                end else begin
                    sample <= 16'hFFFF;
                    state <= DRAW_TRIANGLE32;
                end
            end

            DRAW_TRIANGLE25: begin
                raster_dsp_mul_p0[0] <= w0;
                raster_dsp_mul_p1[0] <= st00_i;
                raster_dsp_mul_p0[1] <= w1;
                raster_dsp_mul_p1[1] <= st10_i;
                raster_dsp_mul_p0[2] <= w2;
                raster_dsp_mul_p1[2] <= st20_i;
                state <= DRAW_TRIANGLE28;
            end

            DRAW_TRIANGLE28: begin
                s <= dsp_mul_z[0][31:0] + dsp_mul_z[1][31:0] + dsp_mul_z[2][31:0];
                raster_dsp_mul_p0[0] <= w0;
                raster_dsp_mul_p1[0] <= st01_i;
                raster_dsp_mul_p0[1] <= w1;
                raster_dsp_mul_p1[1] <= st11_i;
                raster_dsp_mul_p0[2] <= w2;
                raster_dsp_mul_p1[2] <= st21_i;
                state <= DRAW_TRIANGLE31;
            end

            DRAW_TRIANGLE31: begin
                t <= dsp_mul_z[0][31:0] + dsp_mul_z[1][31:0] + dsp_mul_z[2][31:0];
                state <= DRAW_TRIANGLE32;
            end

            DRAW_TRIANGLE32: begin
                raster_dsp_mul_p0[0] <= w0;
                raster_dsp_mul_p1[0] <= vv02_i;
                raster_dsp_mul_p0[1] <= w1;
                raster_dsp_mul_p1[1] <= vv12_i;
                raster_dsp_mul_p0[2] <= w2;
                raster_dsp_mul_p1[2] <= vv22_i;
                state <= DRAW_TRIANGLE33;
            end

            DRAW_TRIANGLE33: begin
                z <= dsp_mul_z[0][31:0] + dsp_mul_z[1][31:0] + dsp_mul_z[2][31:0];
                frag_launch <= 1'b1;
                state <= DRAW_TRIANGLE_FRAGMENT;
            end

            DRAW_TRIANGLE_FRAGMENT: begin
                frag_launch <= 1'b0;
                if (frag_done)
                    state <= DRAW_TRIANGLE59;
            end

            DRAW_TRIANGLE59: begin
                if (x < max_x) begin
                    x <= x + 1;
                    raster_rel_address <= raster_rel_address + 1;
                end else begin
                    x <= min_x;
                    y <= y + 1;
                    raster_rel_address <= raster_rel_address + {20'd0, (FB_WIDTH[11:0] - max_x) + min_x};
                end
                state <= DRAW_TRIANGLE60;
            end

            DRAW_TRIANGLE60: begin
                if (y > max_y) begin
                    state <= IDLE;
                end else begin
                    state <= DRAW_TRIANGLE05;
                end
            end
        endcase

        if (reset_i) begin
            state <= IDLE;
            raster_reciprocal_start <= 1'b0;
            frag_launch <= 1'b0;
        end
    end

endmodule
