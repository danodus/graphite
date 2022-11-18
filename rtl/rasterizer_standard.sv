// rasterizer_standard.sv
// Copyright (c) 2021-2022 Daniel Cliche
// SPDX-License-Identifier: MIT

`include "graphite.svh"

module dsp_mul(
    input wire logic signed [31:0] p0,
    input wire logic signed [31:0] p1,
    output     logic signed [31:0] z
);
    assign z = mul(p0, p1);
endmodule

module dsp_interp(
    input wire logic signed [31:0] p0,
    input wire logic signed [31:0] p1,
    input wire logic signed [31:0] p2,
    output     logic signed [31:0] z
);
    assign z = p0 + mul(p1, p2);
endmodule

module dsp_lerp(
    input wire logic signed [31:0] a,
    input wire logic signed [31:0] b,
    input wire logic signed [31:0] t,
    output     logic signed [31:0] z
);
    assign z = mul(1 << 16 - t, a) + mul(t, b);
endmodule

module rasterizer_standard #(
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

    input wire logic               bottom_half_i,

    input wire logic signed [31:0] y0_i, // int
    input wire logic signed [31:0] y1_i, // int
    input wire logic signed [31:0] y2_i, // int
    input wire logic signed [31:0] x0_i, // int
    input wire logic signed [31:0] x1_i, // int
    input wire logic signed [31:0] s0_i,
    input wire logic signed [31:0] t0_i,
    input wire logic signed [31:0] w0_i,
    input wire logic signed [31:0] s1_i,
    input wire logic signed [31:0] t1_i,
    input wire logic signed [31:0] w1_i,
    input wire logic signed [31:0] r0_i,
    input wire logic signed [31:0] g0_i,
    input wire logic signed [31:0] b0_i,
    input wire logic signed [31:0] r1_i,
    input wire logic signed [31:0] g1_i,
    input wire logic signed [31:0] b1_i,
    input wire logic signed [31:0] dax_step_i,
    input wire logic signed [31:0] dbx_step_i,
    input wire logic signed [31:0] ds0_step_i,
    input wire logic signed [31:0] dt0_step_i,
    input wire logic signed [31:0] dw0_step_i,
    input wire logic signed [31:0] ds1_step_i,
    input wire logic signed [31:0] dt1_step_i,
    input wire logic signed [31:0] dw1_step_i,
    input wire logic signed [31:0] dr0_step_i,
    input wire logic signed [31:0] dg0_step_i,
    input wire logic signed [31:0] db0_step_i,
    input wire logic signed [31:0] dr1_step_i,
    input wire logic signed [31:0] dg1_step_i,
    input wire logic signed [31:0] db1_step_i,

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

    enum { IDLE,
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


    logic signed [31:0] dsp_mul_p0, dsp_mul_p1, dsp_mul_z;

    dsp_mul dsp_mul(
        .p0(dsp_mul_p0),
        .p1(dsp_mul_p1),
        .z(dsp_mul_z)
    );

    logic signed [31:0] dsp_interp_p0[3];
    logic signed [31:0] dsp_interp_p1[3];
    logic signed [31:0] dsp_interp_p2[3];
    logic signed [31:0] dsp_interp_z[3];
/*
    genvar i;
    generate
        for (i = 0; i < 3; i++) begin
            dsp_interp dsp_interp[i](
                .p0(dsp_interp_p0[i]),
                .p1(dsp_interp_p1[i]),
                .p2(dsp_interp_p2[i]),
                .z(dsp_interp_z[i])
            );
        end
    endgenerate
*/
    dsp_interp dsp_interp0(
        .p0(dsp_interp_p0[0]),
        .p1(dsp_interp_p1[0]),
        .p2(dsp_interp_p2[0]),
        .z(dsp_interp_z[0])
    );
    dsp_interp dsp_interp1(
        .p0(dsp_interp_p0[1]),
        .p1(dsp_interp_p1[1]),
        .p2(dsp_interp_p2[1]),
        .z(dsp_interp_z[1])
    );
    dsp_interp dsp_interp2(
        .p0(dsp_interp_p0[2]),
        .p1(dsp_interp_p1[2]),
        .p2(dsp_interp_p2[2]),
        .z(dsp_interp_z[2])
    );

    logic signed [31:0] dsp_lerp_p0[3];
    logic signed [31:0] dsp_lerp_p1[3];
    logic signed [31:0] dsp_lerp_p2[3];
    logic signed [31:0] dsp_lerp_z[3];

    dsp_lerp dsp_lerp0(
        .a(dsp_lerp_a[0]),
        .b(dsp_lerp_b[0]),
        .t(dsp_lerp_t[0]),
        .z(dsp_lerp_z[0])
    );
    dsp_lerp dsp_lerp1(
        .a(dsp_lerp_a[1]),
        .b(dsp_lerp_b[1]),
        .t(dsp_lerp_t[1]),
        .z(dsp_lerp_z[1])
    );
    dsp_lerp dsp_lerp2(
        .a(dsp_lerp_a[2]),
        .b(dsp_lerp_b[2]),
        .t(dsp_lerp_t[2]),
        .z(dsp_lerp_z[2])
    );
    dsp_lerp dsp_lerp3(
        .a(dsp_lerp_a[3]),
        .b(dsp_lerp_b[3]),
        .t(dsp_lerp_t[3]),
        .z(dsp_lerp_z[3])
    );

    logic [31:0] reciprocal_x, reciprocal_z;
    reciprocal reciprocal(.clk(clk), .x_i(reciprocal_x), .z_o(reciprocal_z));
    
    assign busy_o = state != IDLE;

    logic signed [31:0] sy, ey, sx, ss, st, sw, sr, sg, sb, sa;

    logic signed [31:0] x, y, ax, bx, tex_ss, tex_st, tex_sw;

    always_comb begin
        if (bottom_half_i) begin
            sy = y1_i;
            ey = y2_i;
            sx = x1_i;
            ss = s1_i;
            st = t1_i;
            sw = w1_i;
            sr = r1_i;
            sg = g1_i;
            sb = b1_i;
        end else begin
            // top half
            sy = y0_i;
            ey = y1_i;
            sx = x0_i;
            ss = s0_i;
            st = t0_i;
            sw = w0_i;
            sr = r0_i;
            sg = g0_i;
            sb = b0_i;
        end
    end

    always_ff @(posedge clk) begin
        case (state)
            IDLE: begin
                if (start_i) begin
                    // Draw triangle
                    vram_mask_o     <= 4'hF;
                    state <= DRAW_TRIANGLE00;
                end
            end

            DRAW_TRIANGLE00: begin
                y <= sy;
                state <= DRAW_TRIANGLE01;
            end

            DRAW_TRIANGLE01: begin
                if (y <= ey) begin
                    dsp_interp_p0[0] <= sx << 16;
                    dsp_interp_p1[0] <= (y - sy) << 16;
                    dsp_interp_p2[0] <= dax_step_i;
                    dsp_interp_p0[1] <= x0_i << 16;
                    dsp_interp_p1[1] <= (y - y0_i) << 16;
                    dsp_interp_p2[1] <= dbx_step_i;
                    state <= DRAW_TRIANGLE02;
                end else begin
                end
            end

            DRAW_TRIANGLE02: begin
                ax <= dsp_interp_z[0] >>> 16;
                bx <= dsp_interp_z[1] >>> 16;
                dsp_interp_p0[0] <= ss;
                dsp_interp_p1[0] <= (y - sy) << 16;
                dsp_interp_p2[0] <= ds0_step_i;
                dsp_interp_p0[1] <= st;
                dsp_interp_p1[1] <= (y - sy) << 16;
                dsp_interp_p2[1] <= dt0_step_i;
                dsp_interp_p0[2] <= sw;
                dsp_interp_p1[2] <= (y - sy) << 16;
                dsp_interp_p2[2] <= dw0_step_i;
                state <= DRAW_TRIANGLE03;
            end

            DRAW_TRIANGLE03: begin
                tex_ss <= dsp_interp_z[0];
                tex_st <= dsp_interp_z[1];
                tex_sw <= dsp_interp_z[2];
                dsp_interp_p0[0] <= s0_i;
                dsp_interp_p1[0] <= (y - y0_i) << 16;
                dsp_interp_p2[0] <= ds1_step_i;
                dsp_interp_p0[1] <= t0_i;
                dsp_interp_p1[1] <= (y - y0_i) << 16;
                dsp_interp_p2[1] <= dt1_step_i;
                dsp_interp_p0[2] <= w0_i;
                dsp_interp_p1[2] <= (y - y0_i) << 16;
                dsp_interp_p2[2] <= dw1_step_i;
                state <= DRAW_TRIANGLE04;
            end

            DRAW_TRIANGLE04: begin
                tex_es <= dsp_interp_z[0];
                tex_et <= dsp_interp_z[1];
                tex_ew <= dsp_interp_z[2];
                dsp_interp_p0[0] <= sr;
                dsp_interp_p1[0] <= (y - sy) << 16;
                dsp_interp_p2[0] <= dr0_step_i;
                dsp_interp_p0[1] <= sg;
                dsp_interp_p1[1] <= (y - sy) << 16;
                dsp_interp_p2[1] <= dg0_step_i;
                dsp_interp_p0[2] <= sb;
                dsp_interp_p1[2] <= (y - sy) << 16;
                dsp_interp_p2[2] <= db0_step_i;
                state <= DRAW_TRIANGLE05;
            end

            DRAW_TRIANGLE05: begin
                col_sr <= dsp_interp_z[0];
                col_sg <= dsp_interp_z[1];
                col_sb <= dsp_interp_z[2];
                dsp_interp_p0[0] <= r0_i;
                dsp_interp_p1[0] <= (y - y0_i) << 16;
                dsp_interp_p2[0] <= dr1_step_i;
                dsp_interp_p0[1] <= g0_i;
                dsp_interp_p1[1] <= (y - y0_i) << 16;
                dsp_interp_p2[1] <= dg1_step_i;
                dsp_interp_p0[2] <= b0_i;
                dsp_interp_p1[2] <= (y - y0_i) << 16;
                dsp_interp_p2[2] <= db1_step_i;
                state <= DRAW_TRIANGLE06;
            end

            DRAW_TRIANGLE06: begin
                col_er <= dep_interp_z[0];
                col_eg <= dsp_interp_z[1];
                col_eb <= dsp_interp_z[2];
                if (ax <= bx) {
                    state <= DRAW_TRIANGLE08;
                } else {
                    state <= DRAW_TRIANGLE07;
                }
            end

            DRAW_TRIANGLE07: begin
                ax <= bx;
                tex_ss <= tex_es;
                tex_st <= tex_et;
                tex_sw <= tex_ew;
                col_sr <= col_er;
                col_sg <= col_eg;
                col_sb <= col_eb;
                state <= DRAW_TRIANGLE08;  
            end

            DRAW_TRIANGLE08: begin
                tex_s <= tex_ss;
                tex_t <= tex_st;
                tex_w <= tex_sw;
                col_r <= col_sr;
                col_g <= col_sg;
                col_b <= col_sb;

                reciprocal_x <= (bx - ax) << 16;
                t <= 32'd0;
                state <= DRAW_TRIANGLE09;
            end

            DRAW_TRIANGLE09: begin
                tstep <= reciprocal_z >>> 8;
                x <= ax;
                state <= DRAW_TRIANGLE10;
            end

            DRAW_TRIANGLE10: begin
                if (x >= bx) begin
                    state <= DRAW_TRIANGLE???;
                end else begin
                    dsp_lerp_a[0] <= tex_ss;
                    dsp_lerp_b[0] <= tex_es;
                    dsp_lerp_t[0] <= t;
                    dsp_lerp_a[1] <= tex_st;
                    dsp_lerp_b[1] <= tex_et;
                    dsp_lerp_t[1] <= t;
                    dsp_lerp_a[2] <= tex_sw;
                    dsp_lerp_b[2] <= tex_ew;
                    dsp_lerp_t[2] <= t;
                    state <= DRAW_TRIANGLE11;
                end
            end

            DRAW_TRIANGLE11: begin
                tex_s <= dsp_lerp_z[0];
                tex_t <= dsp_lerp_z[1];
                tex_w <= dsp_lerp_z[2];
                
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

