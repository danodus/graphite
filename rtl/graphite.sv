// graphite.sv
// Copyright (c) 2021-2022 Daniel Cliche
// SPDX-License-Identifier: MIT

// Ref.: https://www.scratchapixel.com/lessons/3d-basic-rendering/rasterization-practical-implementation

`include "graphite.svh"

module dsp_mul(
    input wire logic signed [31:0] p0,
    input wire logic signed [31:0] p1,
    output     logic signed [31:0] z
);
    assign z = p0 * p1;
endmodule

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
    //input  wire logic                        vram_ack_i,
    output      logic                        vram_sel_o,
    output      logic                        vram_wr_o,
    output      logic  [3:0]                 vram_mask_o,
    output      logic [15:0]                 vram_addr_o,
    input       logic [15:0]                 vram_data_in_i,
    output      logic [15:0]                 vram_data_out_o,

    output      logic                        swap_o
    );

    enum { WAIT_COMMAND, PROCESS_COMMAND, CLEAR_FB, CLEAR_DEPTH,
           DRAW_TRIANGLE, DRAW_TRIANGLEB, DRAW_TRIANGLEC, DRAW_TRIANGLED, DRAW_TRIANGLEE,
           DRAW_TRIANGLE2,
           DRAW_TRIANGLE3, DRAW_TRIANGLE3B, DRAW_TRIANGLE3C, DRAW_TRIANGLE3D, DRAW_TRIANGLE3E, DRAW_TRIANGLE3F, DRAW_TRIANGLE3G, DRAW_TRIANGLE3H, DRAW_TRIANGLE3I, DRAW_TRIANGLE3J,
           DRAW_TRIANGLE4, DRAW_TRIANGLE4B, DRAW_TRIANGLE4C, DRAW_TRIANGLE4D, DRAW_TRIANGLE4E, DRAW_TRIANGLE4F, DRAW_TRIANGLE4G, DRAW_TRIANGLE4H, DRAW_TRIANGLE4I, DRAW_TRIANGLE4J, DRAW_TRIANGLE4K, DRAW_TRIANGLE4L, DRAW_TRIANGLE4M, DRAW_TRIANGLE4N, DRAW_TRIANGLE4O, DRAW_TRIANGLE4P, DRAW_TRIANGLE4Q, DRAW_TRIANGLE4R, DRAW_TRIANGLE4S, DRAW_TRIANGLE4T, DRAW_TRIANGLE4U, DRAW_TRIANGLE4V, DRAW_TRIANGLE4W, DRAW_TRIANGLE4X, DRAW_TRIANGLE4Y, DRAW_TRIANGLE4Z,
           DRAW_TRIANGLE5, DRAW_TRIANGLE5B, DRAW_TRIANGLE5C, DRAW_TRIANGLE5D, DRAW_TRIANGLE5D2, DRAW_TRIANGLE5D3, DRAW_TRIANGLE5D4, DRAW_TRIANGLE5D4B, DRAW_TRIANGLE5D5, DRAW_TRIANGLE5D6, DRAW_TRIANGLE5D7, DRAW_TRIANGLE5E, DRAW_TRIANGLE5F, DRAW_TRIANGLE5G, DRAW_TRIANGLE5H, DRAW_TRIANGLE5I, DRAW_TRIANGLE5J, DRAW_TRIANGLE5K,
           DRAW_TRIANGLE6, DRAW_TRIANGLE6B, DRAW_TRIANGLE6C, DRAW_TRIANGLE6D,
           DRAW_TRIANGLE7, DRAW_TRIANGLE7B, DRAW_TRIANGLE7C, DRAW_TRIANGLE7D, DRAW_TRIANGLE7E,
           DRAW_TRIANGLE8, DRAW_TRIANGLE8B, DRAW_TRIANGLE8C, DRAW_TRIANGLE8D, DRAW_TRIANGLE8E,
           DRAW_TRIANGLE9, DRAW_TRIANGLE10
    } state;

    logic signed [31:0] vv00, vv01, vv02, vv10, vv11, vv12, vv20, vv21, vv22;
    logic signed [31:0] c00, c01, c02;
    logic signed [31:0] c10, c11, c12;
    logic signed [31:0] c20, c21, c22;
    logic signed [31:0] st00, st01, st10, st11, st20, st21;

    logic signed [11:0] x, y;
    
    logic [15:0] raster_addr;
    logic [15:0] texture_address, texture_write_address;

    //
    // Draw triangle
    //

    logic is_textured, is_clamp_s, is_clamp_t, is_depth_test;

    logic signed [31:0] p0, p1;
    logic signed [31:0] w0, w1, w2;
    logic signed [31:0] inv_area;
    logic signed [31:0] s, t;
    logic signed [31:0] r, g, b;

    logic signed [31:0] dsp_mul_p0, dsp_mul_p1, dsp_mul_z;

    logic signed [31:0] t0, t1, t2;
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

    assign cmd_axis_tready_o = state == WAIT_COMMAND;

    always_ff @(posedge clk) begin
        case (state)
            WAIT_COMMAND: begin
                swap_o <= 1'b0;
                vram_sel_o <= 1'b0;
                vram_wr_o  <= 1'b0;
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
                        vram_addr_o     <= (cmd_axis_tdata_i[16] == 0) ? 16'h0 : 16'(FB_WIDTH * FB_HEIGHT);
                        vram_data_out_o <= cmd_axis_tdata_i[15:0];
                        vram_mask_o     <= 4'hF;
                        vram_sel_o      <= 1'b1;
                        vram_wr_o       <= 1'b1;
                        state           <= (cmd_axis_tdata_i[16] == 0) ? CLEAR_FB : CLEAR_DEPTH;
                    end
                    OP_DRAW: begin
                        // Draw triangle
                        is_textured     <= cmd_axis_tdata_i[0];
                        is_clamp_t      <= cmd_axis_tdata_i[1];
                        is_clamp_s      <= cmd_axis_tdata_i[2];
                        is_depth_test   <= cmd_axis_tdata_i[3];
                        vram_addr_o     <= 16'h0;
                        vram_mask_o     <= 4'hF;
                        min_x <= min3(12'(vv00 >> 16), 12'(vv10 >> 16), 12'(vv20 >> 16));
                        min_y <= min3(12'(vv01 >> 16), 12'(vv11 >> 16), 12'(vv21 >> 16));
                        max_x <= max3(12'(vv00 >> 16), 12'(vv10 >> 16), 12'(vv20 >> 16));
                        max_y <= max3(12'(vv01 >> 16), 12'(vv11 >> 16), 12'(vv21 >> 16));
                        state <= DRAW_TRIANGLE;
                    end
                    OP_SWAP: begin
                        swap_o <= 1'b1;
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_TEX_ADDR: begin
                        texture_address <= cmd_axis_tdata_i[15:0];
                        texture_write_address <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_WRITE_TEX: begin
                        vram_addr_o <= texture_write_address;
                        vram_data_out_o <= cmd_axis_tdata_i[15:0];
                        vram_mask_o <= 4'hF;
                        vram_sel_o <= 1'b1;
                        vram_wr_o  <= 1'b1;
                        texture_write_address <= texture_write_address + 1;
                        state <= WAIT_COMMAND;
                    end
                    default:
                        state <= WAIT_COMMAND;
                endcase
            end

            CLEAR_FB: begin
                if (vram_addr_o < FB_WIDTH * FB_HEIGHT - 1) begin
                    vram_addr_o <= vram_addr_o + 1;
                end else begin
                    vram_sel_o <= 1'b0;
                    vram_wr_o  <= 1'b0;
                    state      <= WAIT_COMMAND;
                end
            end

            CLEAR_DEPTH: begin
                if (vram_addr_o < 2 * FB_WIDTH * FB_HEIGHT - 1) begin
                    vram_addr_o <= vram_addr_o + 1;
                end else begin
                    vram_sel_o <= 1'b0;
                    vram_wr_o  <= 1'b0;
                    state      <= WAIT_COMMAND;
                end
            end

            DRAW_TRIANGLE: begin
                min_x <= max(min_x, 0);
                min_y <= max(min_y, 0);
                max_x <= min(max_x, FB_WIDTH - 1);
                max_y <= min(max_y, FB_HEIGHT - 1);
                state <= DRAW_TRIANGLEB;
            end

            DRAW_TRIANGLEB: begin
                // area = edge_function(vv0, vv1, vv2)

                // area = mul(c0 - a0, b1 - a1) - mul(c1 - a1, b0 - a0)
                // t0 = mul(c0 - a0, b1 - a1)
                dsp_mul_p0 <= (vv20 - vv00) >>> 8;
                dsp_mul_p1 <= (vv11 - vv01) >>> 8;
                state <= DRAW_TRIANGLEC;
            end

            DRAW_TRIANGLEC: begin
                t0 <= dsp_mul_z;
                // t1 = mul(c1 - a1, b0 - a0)
                dsp_mul_p0 <= (vv21 - vv01) >>> 8;
                dsp_mul_p1 <= (vv10 - vv00) >>> 8;
                state <= DRAW_TRIANGLED;
            end

            DRAW_TRIANGLED: begin
                t1 <= dsp_mul_z;
                state <= DRAW_TRIANGLEE;
            end

            DRAW_TRIANGLEE: begin
                reciprocal_x <= t0 - t1;
                state <= DRAW_TRIANGLE2;
            end

            DRAW_TRIANGLE2: begin
                inv_area <= reciprocal_z;
                x <= min_x;
                y <= min_y;
                raster_addr <= {4'd0, min_y} * FB_WIDTH + {4'd0, min_x};
                state <= DRAW_TRIANGLE3;
            end

            DRAW_TRIANGLE3: begin
                // w0 = edge_function(vv1, vv2, p);
                // w0 = mul(c0 - a0, b1 - a1) - mul(c1 - a1, b0 - a0)
                // t0 = mul(c0 - a0, b1 - a1)
                dsp_mul_p0 <= (p0 - vv10) >>> 8;
                dsp_mul_p1 <= (vv21 - vv11) >>> 8;
                state <= DRAW_TRIANGLE3B;
            end

            DRAW_TRIANGLE3B: begin
                t0 <= dsp_mul_z;
                // t1 = mul(c1 - a1, b0 - a0)
                dsp_mul_p0 <= (p1 - vv11) >>> 8;
                dsp_mul_p1 <= (vv20 - vv10) >>> 8;
                state <= DRAW_TRIANGLE3C;
            end

            DRAW_TRIANGLE3C: begin
                t1 <= dsp_mul_z;
                state <= DRAW_TRIANGLE3D;
            end

            DRAW_TRIANGLE3D: begin
                w0 <= t0 - t1;

                // w1 = edge_function(vv2, vv0, p);
                // w1 = mul(c0 - a0, b1 - a1) - mul(c1 - a1, b0 - a0)
                // t0 = mul(c0 - a0, b1 - a1)
                dsp_mul_p0 <= (p0 - vv20) >>> 8;
                dsp_mul_p1 <= (vv01 - vv21) >>> 8;
                state <= DRAW_TRIANGLE3E;
            end

            DRAW_TRIANGLE3E: begin
                t0 <= dsp_mul_z;
                // t1 = mul(c1 - a1, b0 - a0)
                dsp_mul_p0 <= (p1 - vv21) >>> 8;
                dsp_mul_p1 <= (vv00 - vv20) >>> 8;
                state <= DRAW_TRIANGLE3F;
            end

            DRAW_TRIANGLE3F: begin
                t1 <= dsp_mul_z;
                state <= DRAW_TRIANGLE3G;
            end

            DRAW_TRIANGLE3G: begin
                w1 <= t0 - t1;

                // w2 = edge_function(vv0, vv1, p);
                // w2 = mul(c0 - a0, b1 - a1) - mul(c1 - a1, b0 - a0)
                // t0 = mul(c0 - a0, b1 - a1)
                dsp_mul_p0 <= (p0 - vv00) >>> 8;
                dsp_mul_p1 <= (vv11 - vv01) >>> 8;
                state <= DRAW_TRIANGLE3H;
            end

            DRAW_TRIANGLE3H: begin
                t0 <= dsp_mul_z;
                // t1 = mul(c1 - a1, b0 - a0)
                dsp_mul_p0 <= (p1 - vv01) >>> 8;
                dsp_mul_p1 <= (vv10 - vv00) >>> 8;
                state <= DRAW_TRIANGLE3I;
            end

            DRAW_TRIANGLE3I: begin
                t1 <= dsp_mul_z;
                state <= DRAW_TRIANGLE3J;
            end

            DRAW_TRIANGLE3J: begin
                w2 <= t0 - t1;
                state <= DRAW_TRIANGLE4;
            end

            DRAW_TRIANGLE4: begin
                // if w0 < 0, w1 < 0 or w2 < 0
                if (w0[31] || w1[31] || w2[31]) begin
                    state <= DRAW_TRIANGLE9;
                end else begin
                    // w0 = rmul(w0, inv_area)
                    dsp_mul_p0 <= w0 >>> 16;
                    dsp_mul_p1 <= inv_area;
                    state <= DRAW_TRIANGLE4B;
                end
            end

            DRAW_TRIANGLE4B: begin
                w0 <= dsp_mul_z >> 8;
                // w1 = rmul(w1, inv_area)
                dsp_mul_p0 <= w1 >>> 16;
                state <= DRAW_TRIANGLE4C;
            end

            DRAW_TRIANGLE4C: begin
                w1 <= dsp_mul_z >> 8;
                // w2 = rmul(w2, inv_area)
                dsp_mul_p0 <= w2 >>> 16;
                state <= DRAW_TRIANGLE4D;
            end

            DRAW_TRIANGLE4D: begin
                w2 <= dsp_mul_z >> 8;
                // r = mul(w0, c00) + mul(w1, c10) + mul(w2, c20)
                // t0 = mul(w0, c00)
                dsp_mul_p0 <= w0 >>> 8;
                dsp_mul_p1 <= c00 >>> 8;
                state <= DRAW_TRIANGLE4E;
            end

            DRAW_TRIANGLE4E: begin
                t0 <= dsp_mul_z;
                // t1 = mul(w1, c10)
                dsp_mul_p0 <= w1 >>> 8;
                dsp_mul_p1 <= c10 >>> 8;
                state <= DRAW_TRIANGLE4F;
            end

            DRAW_TRIANGLE4F: begin
                t1 <= dsp_mul_z;
                // t2 = mul(w2, c20)
                dsp_mul_p0 <= w2 >>> 8;
                dsp_mul_p1 <= c20 >>> 8;
                state <= DRAW_TRIANGLE4G;
            end

            DRAW_TRIANGLE4G: begin
                t2 <= dsp_mul_z;
                state <= DRAW_TRIANGLE4H;
            end

            DRAW_TRIANGLE4H: begin
                r <= t0 + t1 + t2;
                // g = mul(w0, c01) + mul(w1, c11) + mul(w2, c21)
                // t0 = mul(w0, c01)
                dsp_mul_p0 <= w0 >>> 8;
                dsp_mul_p1 <= c01 >>> 8;
                state <= DRAW_TRIANGLE4I;
            end

            DRAW_TRIANGLE4I: begin
                t0 <= dsp_mul_z;
                // t1 = mul(w1, c11)
                dsp_mul_p0 <= w1 >>> 8;
                dsp_mul_p1 <= c11 >>> 8;
                state <= DRAW_TRIANGLE4J;
            end

            DRAW_TRIANGLE4J: begin
                t1 <= dsp_mul_z;
                // t2 = mul(w2, c21)
                dsp_mul_p0 <= w2 >>> 8;
                dsp_mul_p1 <= c21 >>> 8;
                state <= DRAW_TRIANGLE4K;
            end

            DRAW_TRIANGLE4K: begin
                t2 <= dsp_mul_z;
                state <= DRAW_TRIANGLE4L;
            end

            DRAW_TRIANGLE4L: begin
                g <= t0 + t1 + t2;
                // b = mul(w0, c02) + mul(w1, c12) + mul(w2, c22)
                // t0 = mul(w0, c02)
                dsp_mul_p0 <= w0 >>> 8;
                dsp_mul_p1 <= c02 >>> 8;
                state <= DRAW_TRIANGLE4M;
            end

            DRAW_TRIANGLE4M: begin
                t0 <= dsp_mul_z;
                // t1 = mul(w1, c12)
                dsp_mul_p0 <= w1 >>> 8;
                dsp_mul_p1 <= c12 >>> 8;
                state <= DRAW_TRIANGLE4N;
            end

            DRAW_TRIANGLE4N: begin
                t1 <= dsp_mul_z;
                // t2 = mul(w2, c22)
                dsp_mul_p0 <= w2 >>> 8;
                dsp_mul_p1 <= c22 >>> 8;
                state <= DRAW_TRIANGLE4O;
            end

            DRAW_TRIANGLE4O: begin
                t2 <= dsp_mul_z;
                state <= DRAW_TRIANGLE4P;
            end

            DRAW_TRIANGLE4P: begin
                b <= t0 + t1 + t2;
                if (is_textured) begin
                    state <= DRAW_TRIANGLE4Q;
                end else begin
                    sample <= 16'hFFFF;
                    state <= DRAW_TRIANGLE4Z;
                end
            end

            DRAW_TRIANGLE4Q: begin
                // s = mul(w0, st00) + mul(w1, st10) + mul(w2, st20)
                // t0 = mul(w0, st00)
                dsp_mul_p0 <= w0 >>> 8;
                dsp_mul_p1 <= st00 >>> 8;
                state <= DRAW_TRIANGLE4R;
            end

            DRAW_TRIANGLE4R: begin
                t0 <= dsp_mul_z;
                // t1 = mul(w1, st10)
                dsp_mul_p0 <= w1 >>> 8;
                dsp_mul_p1 <= st10 >>> 8;
                state <= DRAW_TRIANGLE4S;
            end

            DRAW_TRIANGLE4S: begin
                t1 <= dsp_mul_z;
                // t2 = mul(w2, st20)
                dsp_mul_p0 <= w2 >>> 8;
                dsp_mul_p1 <= st20 >>> 8;
                state <= DRAW_TRIANGLE4T;
            end

            DRAW_TRIANGLE4T: begin
                t2 <= dsp_mul_z;
                state <= DRAW_TRIANGLE4U;
            end

            DRAW_TRIANGLE4U: begin
                s <= t0 + t1 + t2;
                // t = mul(w0, st01) + mul(w1, st11) + mul(w2, st21)
                // t0 = mul(w0, st01)
                dsp_mul_p0 <= w0 >>> 8;
                dsp_mul_p1 <= st01 >>> 8;
                state <= DRAW_TRIANGLE4V;
            end

            DRAW_TRIANGLE4V: begin
                t0 <= dsp_mul_z;
                // t1 = mul(w1, st11)
                dsp_mul_p0 <= w1 >>> 8;
                dsp_mul_p1 <= st11 >>> 8;
                state <= DRAW_TRIANGLE4W;
            end

            DRAW_TRIANGLE4W: begin
                t1 <= dsp_mul_z;
                // t2 = mul(w2, st21)
                dsp_mul_p0 <= w2 >>> 8;
                dsp_mul_p1 <= st21 >>> 8;
                state <= DRAW_TRIANGLE4X;
            end

            DRAW_TRIANGLE4X: begin
                t2 <= dsp_mul_z;
                state <= DRAW_TRIANGLE4Y;
            end

            DRAW_TRIANGLE4Y: begin
                t <= t0 + t1 + t2;
                state <= DRAW_TRIANGLE4Z;
            end

            DRAW_TRIANGLE4Z: begin
                state <= DRAW_TRIANGLE5;
            end

            DRAW_TRIANGLE5: begin
                // Perspective correction
                // z = w0 * vv02 + w1 * vv12 + w2 * vv22
                // r = r * 1/z
                // g = g * 1/z
                // b = b * 1/z
                // s = s * 1/z
                // t = t * 1/z
                dsp_mul_p0 <= w0 >>> 8;
                dsp_mul_p1 <= vv02 >>> 8;
                state <= DRAW_TRIANGLE5B;
            end

            DRAW_TRIANGLE5B: begin
                t0 <= dsp_mul_z;
                dsp_mul_p0 <= w1 >>> 8;
                dsp_mul_p1 <= vv12 >>> 8;
                state <= DRAW_TRIANGLE5C;
            end

            DRAW_TRIANGLE5C: begin
                t1 <= dsp_mul_z;
                dsp_mul_p0 <= w2 >>> 8;
                dsp_mul_p1 <= vv22 >>> 8;
                state <= DRAW_TRIANGLE5D;
            end

            DRAW_TRIANGLE5D: begin
                t2 <= dsp_mul_z;
                state <= DRAW_TRIANGLE5D2;
            end

            DRAW_TRIANGLE5D2: begin
                z <= t0 + t1 + t2;
                vram_addr_o <= FB_WIDTH * FB_HEIGHT + 16'(y) * FB_WIDTH + 16'(x);
                vram_wr_o <= 1'b0;
                vram_sel_o <= 1'b1;
                state <= DRAW_TRIANGLE5D3;
            end

            DRAW_TRIANGLE5D3: begin
                state <= DRAW_TRIANGLE5D4;
            end

            DRAW_TRIANGLE5D4: begin
                vram_sel_o <= 1'b0;
                depth <= 16'(vram_data_in_i);
                state <= DRAW_TRIANGLE5D4B;
            end

            DRAW_TRIANGLE5D4B: begin
                if (!is_depth_test || (16'(z) > depth)) begin
                    state <= DRAW_TRIANGLE5D5;
                end else begin
                    state <= DRAW_TRIANGLE9;
                end
            end

            DRAW_TRIANGLE5D5: begin
                vram_data_out_o <= 16'(z);
                vram_wr_o <= 1'b1;
                vram_sel_o <= 1'b1;
                state <= DRAW_TRIANGLE5D6;
            end

            DRAW_TRIANGLE5D6: begin
                state <= DRAW_TRIANGLE5D7;
            end

            DRAW_TRIANGLE5D7: begin
                vram_sel_o <= 1'b0;
                state <= DRAW_TRIANGLE5E;
            end

            DRAW_TRIANGLE5E: begin
                reciprocal_x <= z << 12;
                state <= DRAW_TRIANGLE5F;
            end

            DRAW_TRIANGLE5F: begin
                dsp_mul_p0 <= r >>> 8;
                dsp_mul_p1 <= (reciprocal_z << 12) >>> 8;
                state <= DRAW_TRIANGLE5G;
            end

            DRAW_TRIANGLE5G: begin
                r <= dsp_mul_z >> 8;
                dsp_mul_p0 <= g >>> 8;
                state <= DRAW_TRIANGLE5H;
            end

            DRAW_TRIANGLE5H: begin
                g <= dsp_mul_z >> 8;
                dsp_mul_p0 <= b >>> 8;
                state <= DRAW_TRIANGLE5I;
            end

            DRAW_TRIANGLE5I: begin
                b <= dsp_mul_z >> 8;
                dsp_mul_p0 <= s >>> 8;
                state <= DRAW_TRIANGLE5J;
            end

            DRAW_TRIANGLE5J: begin
                s <= dsp_mul_z >> 8;
                dsp_mul_p0 <= t >>> 8;
                state <= DRAW_TRIANGLE5K;
            end

            DRAW_TRIANGLE5K: begin
                t <= dsp_mul_z >> 8;
                state <= DRAW_TRIANGLE6;
            end

            DRAW_TRIANGLE6: begin
                if (is_textured) begin
                    state <= DRAW_TRIANGLE7;
                end else begin
                    state <= DRAW_TRIANGLE8;
                end
            end

            DRAW_TRIANGLE7: begin
                // t0 = rmul(rmul((TEXTURE_HEIGHT - 1) << 16, clamp(t)), TEXTURE_WIDTH << 16)
                dsp_mul_p0 <= ((TEXTURE_HEIGHT - 1) << 16) >>> 8;
                dsp_mul_p1 <= (is_clamp_t ? clamp(t) : wrap(t)) >>> 8;
                state <= DRAW_TRIANGLE7B;
            end

            DRAW_TRIANGLE7B: begin
                t0 <= rmul(dsp_mul_z, TEXTURE_WIDTH << 16);
                // t1 = rmul((TEXTURE_WIDTH - 1) << 16, clamp(s))
                dsp_mul_p0 <= ((TEXTURE_WIDTH - 1) << 16) >>> 8;
                dsp_mul_p1 <= (is_clamp_s ? clamp(s) : wrap(s)) >>> 8;
                state <= DRAW_TRIANGLE7C;
            end

            DRAW_TRIANGLE7C: begin
                vram_sel_o <= 1'b1;
                vram_wr_o  <= 1'b0;
                vram_addr_o <= texture_address + 16'((t0 + dsp_mul_z) >> 16);
                state <= DRAW_TRIANGLE7D;
            end

            DRAW_TRIANGLE7D: begin
                state <= DRAW_TRIANGLE7E;
            end

            DRAW_TRIANGLE7E: begin
                vram_sel_o <= 1'b0;
                sample <= vram_data_in_i;
                state <= DRAW_TRIANGLE8;
            end

            DRAW_TRIANGLE8: begin
                vram_data_out_o[15:12] <= 4'hF;
                // vram_data_out_o[11:8] = 4'(mul({12'd0, sample[11:8], 16'd0}, r) >> 16)
                // vram_data_out_o[7:4] = 4'(mul({12'd0, sample[7:4], 16'd0}, g) >> 16)
                // vram_data_out_o[3:0] = 4'(mul({12'd0, sample[3:0], 16'd0}, b) >> 16)
                dsp_mul_p0 <= {12'd0, sample[11:8], 16'd0} >>> 8;
                dsp_mul_p1 <= r >>> 8;
                state <= DRAW_TRIANGLE8B;
            end

            DRAW_TRIANGLE8B: begin
                vram_data_out_o[11:8] <= 4'(dsp_mul_z >> 16);
                dsp_mul_p0 <= {12'd0, sample[7:4], 16'd0} >>> 8;
                dsp_mul_p1 <= g >>> 8;
                state <= DRAW_TRIANGLE8C;
            end

            DRAW_TRIANGLE8C: begin
                vram_data_out_o[7:4] <= 4'(dsp_mul_z >> 16);
                dsp_mul_p0 <= {12'd0, sample[3:0], 16'd0} >>> 8;
                dsp_mul_p1 <= b >>> 8;
                state <= DRAW_TRIANGLE8D;
            end

            DRAW_TRIANGLE8D: begin
                vram_data_out_o[3:0] <= 4'(dsp_mul_z >> 16);
                vram_sel_o <= 1'b1;
                vram_wr_o  <= 1'b1;
                vram_addr_o <= raster_addr;
                state <= DRAW_TRIANGLE8E;
            end

            DRAW_TRIANGLE8E: begin
                state <= DRAW_TRIANGLE9;
            end

            DRAW_TRIANGLE9: begin
                vram_sel_o <= 1'b0;
                vram_wr_o  <= 1'b0;

                if (x < max_x) begin
                    x <= x + 1;
                    raster_addr <= raster_addr + 1;
                end else begin
                    x <= min_x;
                    y <= y + 1;
                    raster_addr <= raster_addr + {4'd0, (FB_WIDTH[11:0] - max_x) + min_x};
                end

                state <= DRAW_TRIANGLE10;
            end

            DRAW_TRIANGLE10: begin
                if (y > max_y) begin
                    state       <= WAIT_COMMAND;
                end else begin
                    state       <= DRAW_TRIANGLE3;
                end
            end
        endcase

        if (reset_i) begin
            swap_o            <= 1'b0;
            vram_sel_o        <= 1'b0;
            texture_address   <= 2 * FB_WIDTH * FB_HEIGHT;
            state             <= WAIT_COMMAND;
        end
    end

endmodule

