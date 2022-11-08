// rasterizer_barycentric.sv
// Copyright (c) 2021-2022 Daniel Cliche
// SPDX-License-Identifier: MIT

// Ref.: https://www.scratchapixel.com/lessons/3d-basic-rendering/rasterization-practical-implementation

`include "graphite.svh"

module dsp_mul(
    input wire logic signed [31:0] p0,
    input wire logic signed [31:0] p1,
    output     logic signed [31:0] z
);
    assign z = mul(p0, p1);
endmodule

module rasterizer_barycentric #(
    parameter FB_WIDTH = 128,
    parameter FB_HEIGHT = 128,
    parameter TEXTURE_WIDTH = 32,
    parameter TEXTURE_HEIGHT = 32,
    parameter SUBPIXEL_PRECISION_MASK = 16'hF000
    ) (
    input  wire logic                        clk,
    input  wire logic                        reset_i,

    input wire logic               start_i,
    output     logic               busy_o,

    input wire logic signed [31:0] vv00_i, 
    input wire logic signed [31:0] vv01_i,
    input wire logic signed [31:0] vv02_i,
    input wire logic signed [31:0] vv10_i,
    input wire logic signed [31:0] vv11_i,
    input wire logic signed [31:0] vv12_i,
    input wire logic signed [31:0] vv20_i,
    input wire logic signed [31:0] vv21_i,
    input wire logic signed [31:0] vv22_i,
    
    input wire logic signed [31:0] c00_i,
    input wire logic signed [31:0] c01_i,
    input wire logic signed [31:0] c02_i,

    input wire logic signed [31:0] c10_i,
    input wire logic signed [31:0] c11_i,
    input wire logic signed [31:0] c12_i,

    input wire logic signed [31:0] c20_i,
    input wire logic signed [31:0] c21_i,
    input wire logic signed [31:0] c22_i,
    
    input wire logic signed [31:0] st00_i,
    input wire logic signed [31:0] st01_i,
    input wire logic signed [31:0] st10_i,
    input wire logic signed [31:0] st11_i,
    input wire logic signed [31:0] st20_i,
    input wire logic signed [31:0] st21_i,   

    input wire logic is_textured_i,
    input wire logic is_clamp_s_i,
    input wire logic is_clamp_t_i,
    input wire logic is_depth_test_i,

    input wire logic [31:0] back_address_i,
    input wire logic [31:0] depth_address_i,
    input wire logic [31:0] texture_address_i,

    // VRAM write
    input  wire logic                        vram_ack_i,
    output      logic                        vram_sel_o,
    output      logic                        vram_wr_o,
    output      logic  [3:0]                 vram_mask_o,
    output      logic [31:0]                 vram_addr_o,
    input       logic [15:0]                 vram_data_in_i,
    output      logic [15:0]                 vram_data_out_o
    );

    enum { IDLE, DRAW,
           DRAW_TRIANGLE00, DRAW_TRIANGLE01, DRAW_TRIANGLE02, DRAW_TRIANGLE03, DRAW_TRIANGLE04, DRAW_TRIANGLE05,
           DRAW_TRIANGLE06, DRAW_TRIANGLE07, DRAW_TRIANGLE08, DRAW_TRIANGLE09, DRAW_TRIANGLE10, DRAW_TRIANGLE11,
           DRAW_TRIANGLE12, DRAW_TRIANGLE13, DRAW_TRIANGLE14, DRAW_TRIANGLE15, DRAW_TRIANGLE16, DRAW_TRIANGLE17,
           DRAW_TRIANGLE18, DRAW_TRIANGLE19, DRAW_TRIANGLE20, DRAW_TRIANGLE21, DRAW_TRIANGLE22, DRAW_TRIANGLE23,
           DRAW_TRIANGLE24, DRAW_TRIANGLE25, DRAW_TRIANGLE26, DRAW_TRIANGLE27, DRAW_TRIANGLE28, DRAW_TRIANGLE29,
           DRAW_TRIANGLE30, DRAW_TRIANGLE31, DRAW_TRIANGLE32, DRAW_TRIANGLE33, DRAW_TRIANGLE34, DRAW_TRIANGLE35,
           DRAW_TRIANGLE36, DRAW_TRIANGLE37, DRAW_TRIANGLE38, DRAW_TRIANGLE39, DRAW_TRIANGLE40, DRAW_TRIANGLE41,
           DRAW_TRIANGLE42, DRAW_TRIANGLE43, DRAW_TRIANGLE44, DRAW_TRIANGLE45, DRAW_TRIANGLE46, DRAW_TRIANGLE47,
           DRAW_TRIANGLE48, DRAW_TRIANGLE49, DRAW_TRIANGLE50, DRAW_TRIANGLE51, DRAW_TRIANGLE52, DRAW_TRIANGLE53,
           DRAW_TRIANGLE54, DRAW_TRIANGLE55, DRAW_TRIANGLE56, DRAW_TRIANGLE57, DRAW_TRIANGLE58, DRAW_TRIANGLE59,
           DRAW_TRIANGLE60
    } state;

    logic signed [11:0] x, y;
    

    logic [31:0] raster_rel_address;

    //
    // Draw triangle
    //

    logic signed [31:0] p0, p1;
    logic signed [31:0] w0, w1, w2;
    logic signed [31:0] inv_area;
    logic signed [31:0] s, t;
    logic signed [31:0] r, g, b;

    logic signed [31:0] dsp_mul_p0, dsp_mul_p1, dsp_mul_z;

    logic signed [31:0] t0, t1;
    logic        [31:0] z;

    logic        [15:0] depth;
    logic        [15:0] sample;

    dsp_mul dsp_mul(
        .p0(dsp_mul_p0),
        .p1(dsp_mul_p1),
        .z(dsp_mul_z)
    );

    logic signed [11:0] min_x, min_y, max_x, max_y;

    logic [31:0] reciprocal_x, reciprocal_z;
    reciprocal reciprocal(.clk(clk), .x_i(reciprocal_x), .z_o(reciprocal_z));
    
    assign p0 = {4'd0, x, 16'd0};
    assign p1 = {4'd0, y, 16'd0};

    assign busy_o = state != IDLE;

    always_ff @(posedge clk) begin
        case (state)
            IDLE: begin
                if (start_i) begin
                    // Draw triangle
                    vram_mask_o     <= 4'hF;
                    min_x <= min3(12'(vv00_i >> 16), 12'(vv10_i >> 16), 12'(vv20_i >> 16));
                    min_y <= min3(12'(vv01_i >> 16), 12'(vv11_i >> 16), 12'(vv21_i >> 16));
                    max_x <= max3(12'(vv00_i >> 16), 12'(vv10_i >> 16), 12'(vv20_i >> 16));
                    max_y <= max3(12'(vv01_i >> 16), 12'(vv11_i >> 16), 12'(vv21_i >> 16));
                    state <= DRAW_TRIANGLE00;
                end
            end
            
            DRAW_TRIANGLE00: begin
                min_x <= max(min_x, 0);
                min_y <= max(min_y, 0);
                max_x <= min(max_x, FB_WIDTH - 1);
                max_y <= min(max_y, FB_HEIGHT - 1);
                state <= DRAW_TRIANGLE01;
            end

            DRAW_TRIANGLE01: begin
                // area = edge_function(vv0, vv1, vv2)

                // area = mul(c0 - a0, b1 - a1) - mul(c1 - a1, b0 - a0)
                // t0 = mul(c0 - a0, b1 - a1)
                dsp_mul_p0 <= (vv20_i - vv00_i);
                dsp_mul_p1 <= (vv11_i - vv01_i);
                state <= DRAW_TRIANGLE02;
            end

            DRAW_TRIANGLE02: begin
                t0 <= dsp_mul_z;
                // t1 = mul(c1 - a1, b0 - a0)
                dsp_mul_p0 <= (vv21_i - vv01_i);
                dsp_mul_p1 <= (vv10_i - vv00_i);
                state <= DRAW_TRIANGLE03;
            end

            DRAW_TRIANGLE03: begin
                reciprocal_x <= t0 - dsp_mul_z;
                state <= DRAW_TRIANGLE04;
            end

            DRAW_TRIANGLE04: begin
                inv_area <= reciprocal_z;
                x <= min_x;
                y <= min_y;
                raster_rel_address <= {20'd0, min_y} * FB_WIDTH + {20'd0, min_x};
                state <= DRAW_TRIANGLE05;
            end

            DRAW_TRIANGLE05: begin
                // w0 = edge_function(vv1, vv2, p);
                // w0 = mul(c0 - a0, b1 - a1) - mul(c1 - a1, b0 - a0)
                // t0 = mul(c0 - a0, b1 - a1)
                dsp_mul_p0 <= (p0 - vv10_i);
                dsp_mul_p1 <= (vv21_i - vv11_i);
                state <= DRAW_TRIANGLE06;
            end

            DRAW_TRIANGLE06: begin
                t0 <= dsp_mul_z;
                // t1 = mul(c1 - a1, b0 - a0)
                dsp_mul_p0 <= (p1 - vv11_i);
                dsp_mul_p1 <= (vv20_i - vv10_i);
                state <= DRAW_TRIANGLE07;
            end

            DRAW_TRIANGLE07: begin
                w0 <= t0 - dsp_mul_z;

                // w1 = edge_function(vv2, vv0, p);
                // w1 = mul(c0 - a0, b1 - a1) - mul(c1 - a1, b0 - a0)
                // t0 = mul(c0 - a0, b1 - a1)
                dsp_mul_p0 <= (p0 - vv20_i);
                dsp_mul_p1 <= (vv01_i - vv21_i);
                state <= DRAW_TRIANGLE08;
            end

            DRAW_TRIANGLE08: begin
                t0 <= dsp_mul_z;
                // t1 = mul(c1 - a1, b0 - a0)
                dsp_mul_p0 <= (p1 - vv21_i);
                dsp_mul_p1 <= (vv00_i - vv20_i);
                state <= DRAW_TRIANGLE09;
            end

            DRAW_TRIANGLE09: begin
                w1 <= t0 - dsp_mul_z;

                // w2 = edge_function(vv0, vv1, p);
                // w2 = mul(c0 - a0, b1 - a1) - mul(c1 - a1, b0 - a0)
                // t0 = mul(c0 - a0, b1 - a1)
                dsp_mul_p0 <= (p0 - vv00_i);
                dsp_mul_p1 <= (vv11_i - vv01_i);
                state <= DRAW_TRIANGLE10;
            end

            DRAW_TRIANGLE10: begin
                t0 <= dsp_mul_z;
                // t1 = mul(c1 - a1, b0 - a0)
                dsp_mul_p0 <= (p1 - vv01_i);
                dsp_mul_p1 <= (vv10_i - vv00_i);
                state <= DRAW_TRIANGLE11;
            end

            DRAW_TRIANGLE11: begin
                w2 <= t0 - dsp_mul_z;
                state <= DRAW_TRIANGLE12;
            end

            DRAW_TRIANGLE12: begin
                // if w0 < 0, w1 < 0 or w2 < 0
                if (w0[31] || w1[31] || w2[31]) begin
                    state <= DRAW_TRIANGLE59;
                end else begin
                    // w0 = mul(w0, inv_area)
                    dsp_mul_p0 <= w0;
                    dsp_mul_p1 <= inv_area;
                    state <= DRAW_TRIANGLE13;
                end
            end

            DRAW_TRIANGLE13: begin
                w0 <= dsp_mul_z >> 8;
                // w1 = mul(w1, inv_area)
                dsp_mul_p0 <= w1;
                state <= DRAW_TRIANGLE14;
            end

            DRAW_TRIANGLE14: begin
                w1 <= dsp_mul_z >> 8;
                // w2 = mul(w2, inv_area)
                dsp_mul_p0 <= w2;
                state <= DRAW_TRIANGLE15;
            end

            DRAW_TRIANGLE15: begin
                w2 <= dsp_mul_z >> 8;
                // r = mul(w0, c00) + mul(w1, c10) + mul(w2, c20)
                // t0 = mul(w0, c00)
                dsp_mul_p0 <= w0;
                dsp_mul_p1 <= c00_i;
                state <= DRAW_TRIANGLE16;
            end

            DRAW_TRIANGLE16: begin
                t0 <= dsp_mul_z;
                // t1 = mul(w1, c10)
                dsp_mul_p0 <= w1;
                dsp_mul_p1 <= c10_i;
                state <= DRAW_TRIANGLE17;
            end

            DRAW_TRIANGLE17: begin
                t1 <= dsp_mul_z;
                // t2 = mul(w2, c20)
                dsp_mul_p0 <= w2;
                dsp_mul_p1 <= c20_i;
                state <= DRAW_TRIANGLE18;
            end

            DRAW_TRIANGLE18: begin
                r <= t0 + t1 + dsp_mul_z;
                // g = mul(w0, c01) + mul(w1, c11) + mul(w2, c21)
                // t0 = mul(w0, c01)
                dsp_mul_p0 <= w0;
                dsp_mul_p1 <= c01_i;
                state <= DRAW_TRIANGLE19;
            end

            DRAW_TRIANGLE19: begin
                t0 <= dsp_mul_z;
                // t1 = mul(w1, c11)
                dsp_mul_p0 <= w1;
                dsp_mul_p1 <= c11_i;
                state <= DRAW_TRIANGLE20;
            end

            DRAW_TRIANGLE20: begin
                t1 <= dsp_mul_z;
                // t2 = mul(w2, c21)
                dsp_mul_p0 <= w2;
                dsp_mul_p1 <= c21_i;
                state <= DRAW_TRIANGLE21;
            end

            DRAW_TRIANGLE21: begin
                g <= t0 + t1 + dsp_mul_z;
                // b = mul(w0, c02) + mul(w1, c12) + mul(w2, c22)
                // t0 = mul(w0, c02)
                dsp_mul_p0 <= w0;
                dsp_mul_p1 <= c02_i;
                state <= DRAW_TRIANGLE22;
            end

            DRAW_TRIANGLE22: begin
                t0 <= dsp_mul_z;
                // t1 = mul(w1, c12)
                dsp_mul_p0 <= w1;
                dsp_mul_p1 <= c12_i;
                state <= DRAW_TRIANGLE23;
            end

            DRAW_TRIANGLE23: begin
                t1 <= dsp_mul_z;
                // t2 = mul(w2, c22)
                dsp_mul_p0 <= w2;
                dsp_mul_p1 <= c22_i;
                state <= DRAW_TRIANGLE24;
            end

            DRAW_TRIANGLE24: begin
                b <= t0 + t1 + dsp_mul_z;
                if (is_textured_i) begin
                    state <= DRAW_TRIANGLE25;
                end else begin
                    sample <= 16'hFFFF;
                    state <= DRAW_TRIANGLE32;
                end
            end

            DRAW_TRIANGLE25: begin
                // s = mul(w0, st00) + mul(w1, st10) + mul(w2, st20)
                // t0 = mul(w0, st00)
                dsp_mul_p0 <= w0;
                dsp_mul_p1 <= st00_i;
                state <= DRAW_TRIANGLE26;
            end

            DRAW_TRIANGLE26: begin
                t0 <= dsp_mul_z;
                // t1 = mul(w1, st10)
                dsp_mul_p0 <= w1;
                dsp_mul_p1 <= st10_i;
                state <= DRAW_TRIANGLE27;
            end

            DRAW_TRIANGLE27: begin
                t1 <= dsp_mul_z;
                // t2 = mul(w2, st20)
                dsp_mul_p0 <= w2;
                dsp_mul_p1 <= st20_i;
                state <= DRAW_TRIANGLE28;
            end

            DRAW_TRIANGLE28: begin
                s <= t0 + t1 + dsp_mul_z;
                // t = mul(w0, st01) + mul(w1, st11) + mul(w2, st21)
                // t0 = mul(w0, st01)
                dsp_mul_p0 <= w0;
                dsp_mul_p1 <= st01_i;
                state <= DRAW_TRIANGLE29;
            end

            DRAW_TRIANGLE29: begin
                t0 <= dsp_mul_z;
                // t1 = mul(w1, st11)
                dsp_mul_p0 <= w1;
                dsp_mul_p1 <= st11_i;
                state <= DRAW_TRIANGLE30;
            end

            DRAW_TRIANGLE30: begin
                t1 <= dsp_mul_z;
                // t2 = mul(w2, st21)
                dsp_mul_p0 <= w2;
                dsp_mul_p1 <= st21_i;
                state <= DRAW_TRIANGLE31;
            end

            DRAW_TRIANGLE31: begin
                t <= t0 + t1 + dsp_mul_z;
                state <= DRAW_TRIANGLE32;
            end

            DRAW_TRIANGLE32: begin
                // Perspective correction
                // z = w0 * vv02 + w1 * vv12 + w2 * vv22
                // r = r * 1/z
                // g = g * 1/z
                // b = b * 1/z
                // s = s * 1/z
                // t = t * 1/z
                dsp_mul_p0 <= w0;
                dsp_mul_p1 <= vv02_i;
                state <= DRAW_TRIANGLE33;
            end

            DRAW_TRIANGLE33: begin
                t0 <= dsp_mul_z;
                dsp_mul_p0 <= w1;
                dsp_mul_p1 <= vv12_i;
                state <= DRAW_TRIANGLE34;
            end

            DRAW_TRIANGLE34: begin
                t1 <= dsp_mul_z;
                dsp_mul_p0 <= w2;
                dsp_mul_p1 <= vv22_i;
                state <= DRAW_TRIANGLE35;
            end

            DRAW_TRIANGLE35: begin
                z <= t0 + t1 + dsp_mul_z;
                vram_addr_o <= depth_address_i + 32'(y) * FB_WIDTH + 32'(x);
                if (is_depth_test_i) begin
                    vram_wr_o <= 1'b0;
                    vram_sel_o <= 1'b1;
                    state <= DRAW_TRIANGLE36;
                end else begin
                    state <= DRAW_TRIANGLE39;
                end
            end

            DRAW_TRIANGLE36: begin
                // wait memory access
                if (vram_ack_i) begin
                    vram_sel_o <= 1'b0;
                    state <= DRAW_TRIANGLE37;
                end
            end

            DRAW_TRIANGLE37: begin
                depth <= 16'(vram_data_in_i);
                state <= DRAW_TRIANGLE38;
            end

            DRAW_TRIANGLE38: begin
                if (16'(z) > depth) begin
                    state <= DRAW_TRIANGLE39;
                end else begin
                    state <= DRAW_TRIANGLE59;
                end
            end

            DRAW_TRIANGLE39: begin
                vram_data_out_o <= 16'(z);
                vram_wr_o <= 1'b1;
                vram_sel_o <= 1'b1;
                state <= DRAW_TRIANGLE40;
            end

            DRAW_TRIANGLE40: begin
                // wait memory access
                if (vram_ack_i) begin
                    vram_sel_o <= 1'b0;
                    state <= DRAW_TRIANGLE41;
                end
            end

            DRAW_TRIANGLE41: begin
                reciprocal_x <= z << 12;
                state <= DRAW_TRIANGLE42;
            end

            DRAW_TRIANGLE42: begin
                dsp_mul_p0 <= r;
                dsp_mul_p1 <= (reciprocal_z << 12);
                state <= DRAW_TRIANGLE43;
            end

            DRAW_TRIANGLE43: begin
                r <= dsp_mul_z >> 8;
                dsp_mul_p0 <= g;
                state <= DRAW_TRIANGLE44;
            end

            DRAW_TRIANGLE44: begin
                g <= dsp_mul_z >> 8;
                dsp_mul_p0 <= b;
                state <= DRAW_TRIANGLE45;
            end

            DRAW_TRIANGLE45: begin
                b <= dsp_mul_z >> 8;
                dsp_mul_p0 <= s;
                state <= DRAW_TRIANGLE46;
            end

            DRAW_TRIANGLE46: begin
                s <= dsp_mul_z >> 8;
                dsp_mul_p0 <= t;
                state <= DRAW_TRIANGLE47;
            end

            DRAW_TRIANGLE47: begin
                t <= dsp_mul_z >> 8;
                state <= DRAW_TRIANGLE48;
            end

            DRAW_TRIANGLE48: begin
                if (is_textured_i) begin
                    state <= DRAW_TRIANGLE49;
                end else begin
                    state <= DRAW_TRIANGLE54;
                end
            end

            DRAW_TRIANGLE49: begin
                // t0 = rmul(mul((TEXTURE_HEIGHT - 1) << 16, clamp(t)), TEXTURE_WIDTH << 16)
                dsp_mul_p0 <= ((TEXTURE_HEIGHT - 1) << 16);
                dsp_mul_p1 <= (is_clamp_t_i ? clamp(t) : wrap(t));
                state <= DRAW_TRIANGLE50;
            end

            DRAW_TRIANGLE50: begin
                t0 <= mul(dsp_mul_z & 32'hFFFF0000, TEXTURE_WIDTH << 16);
                // t1 = mul((TEXTURE_WIDTH - 1) << 16, clamp(s))
                dsp_mul_p0 <= ((TEXTURE_WIDTH - 1) << 16);
                dsp_mul_p1 <= (is_clamp_s_i ? clamp(s) : wrap(s));
                state <= DRAW_TRIANGLE51;
            end

            DRAW_TRIANGLE51: begin
                vram_sel_o <= 1'b1;
                vram_wr_o  <= 1'b0;
                vram_addr_o <= texture_address_i + 32'((t0 + dsp_mul_z) >> 16);
                state <= DRAW_TRIANGLE52;
            end

            DRAW_TRIANGLE52: begin
                // wait memory access
                if (vram_ack_i) begin
                    state <= DRAW_TRIANGLE53;
                    vram_sel_o <= 1'b0;
                end
            end

            DRAW_TRIANGLE53: begin
                sample <= vram_data_in_i;
                state <= DRAW_TRIANGLE54;
            end

            DRAW_TRIANGLE54: begin
                vram_data_out_o[15:12] <= 4'hF;
                // vram_data_out_o[11:8] = 4'(mul({12'd0, sample[11:8], 16'd0}, r) >> 16)
                // vram_data_out_o[7:4] = 4'(mul({12'd0, sample[7:4], 16'd0}, g) >> 16)
                // vram_data_out_o[3:0] = 4'(mul({12'd0, sample[3:0], 16'd0}, b) >> 16)
                dsp_mul_p0 <= {12'd0, sample[11:8], 16'd0};
                dsp_mul_p1 <= r;
                state <= DRAW_TRIANGLE55;
            end

            DRAW_TRIANGLE55: begin
                vram_data_out_o[11:8] <= 4'(dsp_mul_z >> 16);
                dsp_mul_p0 <= {12'd0, sample[7:4], 16'd0};
                dsp_mul_p1 <= g;
                state <= DRAW_TRIANGLE56;
            end

            DRAW_TRIANGLE56: begin
                vram_data_out_o[7:4] <= 4'(dsp_mul_z >> 16);
                dsp_mul_p0 <= {12'd0, sample[3:0], 16'd0};
                dsp_mul_p1 <= b;
                state <= DRAW_TRIANGLE57;
            end

            DRAW_TRIANGLE57: begin
                vram_data_out_o[3:0] <= 4'(dsp_mul_z >> 16);
                vram_sel_o <= 1'b1;
                vram_wr_o  <= 1'b1;
                vram_addr_o <= back_address_i + raster_rel_address;
                state <= DRAW_TRIANGLE58;
            end

            DRAW_TRIANGLE58: begin
                // wait memory access
                if (vram_ack_i) begin
                    state <= DRAW_TRIANGLE59;
                    vram_sel_o <= 1'b0;
                    vram_wr_o  <= 1'b0;
                end
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
                    state       <= IDLE;
                end else begin
                    state       <= DRAW_TRIANGLE05;
                end
            end
        endcase

        if (reset_i) begin
            state               <= IDLE;
            vram_sel_o          <= 1'b0;
            vram_wr_o           <= 1'b0; 
            vram_mask_o         <= 4'hF;                       
        end
    end

endmodule

