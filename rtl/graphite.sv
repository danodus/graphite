// graphite.sv
// Copyright (c) 2021-2022 Daniel Cliche
// SPDX-License-Identifier: MIT

// Ref.: https://www.scratchapixel.com/lessons/3d-basic-rendering/rasterization-practical-implementation

`include "graphite.svh"

`define TEXTURED
`define PERSP_CORRECT

module dsp_mul(
    input wire logic signed [31:0] p0,
    input wire logic signed [31:0] p1,
    output     logic signed [31:0] z
);
    assign z = mul(p0, p1);
endmodule

module dsp_rmul(
    input wire logic signed [31:0] p0,
    input wire logic signed [31:0] p1,
    output     logic signed [31:0] z
);
    assign z = rmul(p0, p1);
endmodule

module graphite #(
    parameter FB_WIDTH = 128,
    parameter FB_HEIGHT = 128,
    parameter TEXTURE_WIDTH = 32,
    parameter TEXTURE_HEIGHT = 32
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

    enum { WAIT_COMMAND, PROCESS_COMMAND, CLEAR, DRAW_LINE,
           DRAW_TRIANGLE, DRAW_TRIANGLEB, DRAW_TRIANGLEC, DRAW_TRIANGLED, DRAW_TRIANGLEE,
           DRAW_TRIANGLE2,
           DRAW_TRIANGLE3, DRAW_TRIANGLE3B, DRAW_TRIANGLE3C, DRAW_TRIANGLE3D, DRAW_TRIANGLE3E, DRAW_TRIANGLE3F, DRAW_TRIANGLE3G, DRAW_TRIANGLE3H, DRAW_TRIANGLE3I, DRAW_TRIANGLE3J,
           DRAW_TRIANGLE4, DRAW_TRIANGLE4B, DRAW_TRIANGLE4C, DRAW_TRIANGLE4D, DRAW_TRIANGLE4E, DRAW_TRIANGLE4F, DRAW_TRIANGLE4G, DRAW_TRIANGLE4H, DRAW_TRIANGLE4I, DRAW_TRIANGLE4J, DRAW_TRIANGLE4K, DRAW_TRIANGLE4L,
           DRAW_TRIANGLE5, DRAW_TRIANGLE5B, DRAW_TRIANGLE5C, DRAW_TRIANGLE5D, DRAW_TRIANGLE5E, DRAW_TRIANGLE5F, DRAW_TRIANGLE5G, DRAW_TRIANGLE5H, 
           DRAW_TRIANGLE6, DRAW_TRIANGLE6B, DRAW_TRIANGLE6C, DRAW_TRIANGLE6D,
           DRAW_TRIANGLE7, DRAW_TRIANGLE7B, DRAW_TRIANGLE8, DRAW_TRIANGLE9
    } state;

    logic signed [31:0] vv00, vv01, vv02, vv10, vv11, vv12, vv20, vv21, vv22;
    logic signed [11:0] x, y;
    logic        [15:0] color;
    logic signed [31:0] u0, v0, u1, v1, u2, v2;

    logic [15:0] raster_addr;
    logic [15:0] texture_address, texture_write_address;

    //
    // Draw line
    //

    logic start_line;
    logic drawing_line;
    logic busy_line;
    logic done_line;
    logic signed [11:0] x_line, y_line;

    logic wait_vram_ack = 1'b0;

    draw_line #(.CORDW(12)) draw_line (    // framebuffer coord width in bits
        .clk(clk),                         // clock
        .reset_i(reset_i),                 // reset
        .start_i(start_line),              // start line rendering
        .oe_i(!wait_vram_ack),             // output enable
        .x0_i(12'(vv00 >> 16)),            // point 0 - horizontal position
        .y0_i(12'(vv01 >> 16)),            // point 0 - vertical position
        .x1_i(12'(vv10 >> 16)),            // point 1 - horizontal position
        .y1_i(12'(vv11 >> 16)),            // point 1 - vertical position
        .x_o(x_line),                      // horizontal drawing position
        .y_o(y_line),                      // vertical drawing position
        .drawing_o(drawing_line),          // line is drawing
        .busy_o(busy_line),                // line drawing request in progress
        .done_o(done_line)                 // line complete (high for one tick)
    );

    //
    // Draw triangle
    //

    logic signed [31:0] p0, p1;
    logic signed [31:0] w0, w1, w2;
    logic signed [31:0] inv_area;
    logic signed [31:0] r, g, b;

    logic signed [31:0] c00, c01, c02;
    logic signed [31:0] c10, c11, c12;
    logic signed [31:0] c20, c21, c22;

    logic signed [31:0] dsp_mul_p0, dsp_mul_p1, dsp_mul_z;
    logic signed [31:0] dsp_rmul_p0, dsp_rmul_p1, dsp_rmul_z;

    logic signed [31:0] t0, t1, t2;

    dsp_mul dsp_mul(
        .p0(dsp_mul_p0),
        .p1(dsp_mul_p1),
        .z(dsp_mul_z)
    );

    dsp_rmul dsp_rmul(
        .p0(dsp_rmul_p0),
        .p1(dsp_rmul_p1),
        .z(dsp_rmul_z)
    );

    logic signed [11:0] min_x, min_y, max_x, max_y;

    logic [31:0] reciprocal_x, reciprocal_z;
    reciprocal reciprocal(.clk(clk), .x_i(reciprocal_x), .z_o(reciprocal_z));
    
    //function logic signed [31:0] edge_function(logic signed [31:0] a0, logic signed [31:0] a1, logic signed [31:0] b0, logic signed [31:0] b1, logic signed [31:0] c0, logic signed [31:0] c1);
    //    edge_function = mul(c0 - a0, b1 - a1) - mul(c1 - a1, b0 - a0);
    //endfunction

    assign c00 = u0;
    assign c01 = v0;
    assign c02 = 32'd0;
    assign c10 = u1;
    assign c11 = v1;
    assign c12 = 32'd0;
    assign c20 = u2;
    assign c21 = v2;
    assign c22 = 32'd0;
    
    assign p0 = {20'd0, x} << 16;
    assign p1 = {20'd0, y} << 16;

    assign cmd_axis_tready_o = state == WAIT_COMMAND;

    always_ff @(posedge clk) begin
        if (start_line)
            start_line <= 1'b0;

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
                            vv00[15:0] <= 16'd0;
                        end else begin
                            //vv00[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_Y0: begin
                        if (cmd_axis_tdata_i[16]) begin
                            vv01[31:16] <= cmd_axis_tdata_i[15:0];
                            vv01[15:0] <= 16'd0;
                        end else begin
                            //vv01[15:0] <= cmd_axis_tdata_i[15:0];
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
                            vv10[15:0] <= 16'd0;
                        end else begin
                            //vv10[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_Y1: begin
                        if (cmd_axis_tdata_i[16]) begin
                            vv11[31:16] <= cmd_axis_tdata_i[15:0];
                            vv11[15:0] <= 16'd0;
                        end else begin
                            //vv11[15:0] <= cmd_axis_tdata_i[15:0];
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
                            vv20[15:0] <= 16'd0;
                        end else begin
                            //vv20[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_Y2: begin
                        if (cmd_axis_tdata_i[16]) begin
                            vv21[31:16] <= cmd_axis_tdata_i[15:0];
                            vv21[15:0] <= 16'd0;
                        end else begin
                            //vv21[15:0] <= cmd_axis_tdata_i[15:0];
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
                    OP_SET_S0: begin
                        if (cmd_axis_tdata_i[16]) begin
                            u0[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            u0[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_T0: begin
                        if (cmd_axis_tdata_i[16]) begin
                            v0[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            v0[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_S1: begin
                        if (cmd_axis_tdata_i[16]) begin
                            u1[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            u1[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_T1: begin
                        if (cmd_axis_tdata_i[16]) begin
                            v1[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            v1[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_S2: begin
                        if (cmd_axis_tdata_i[16]) begin
                            u2[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            u2[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_T2: begin
                        if (cmd_axis_tdata_i[16]) begin
                            v2[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            v2[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_COLOR: begin
                        color <= cmd_axis_tdata_i[15:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_CLEAR: begin
                        vram_addr_o     <= 16'h0;
                        vram_data_out_o <= color;
                        vram_mask_o     <= 4'hF;
                        vram_sel_o      <= 1'b1;
                        vram_wr_o       <= 1'b1;
                        state           <= CLEAR;
                    end
                    OP_DRAW: begin
                        if (cmd_axis_tdata_i[0] == 0) begin
                            // Draw line
                            start_line      <= 1;
                            state           <= DRAW_LINE;
                        end else begin
                            // Draw triangle
                            vram_addr_o     <= 16'h0;
                            vram_data_out_o <= color;
                            vram_mask_o     <= 4'hF;
                            min_x <= min3(12'(vv00 >> 16), 12'(vv10 >> 16), 12'(vv20 >> 16));
                            min_y <= min3(12'(vv01 >> 16), 12'(vv11 >> 16), 12'(vv21 >> 16));
                            max_x <= max3(12'(vv00 >> 16), 12'(vv10 >> 16), 12'(vv20 >> 16));
                            max_y <= max3(12'(vv01 >> 16), 12'(vv11 >> 16), 12'(vv21 >> 16));
                            state <= DRAW_TRIANGLE;
                        end
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

            CLEAR: begin
                if (vram_addr_o < FB_WIDTH * FB_HEIGHT - 1) begin
                    vram_addr_o <= vram_addr_o + 1;
                end else begin
                    vram_sel_o <= 1'b0;
                    vram_wr_o  <= 1'b0;
                    state      <= WAIT_COMMAND;
                end
            end

            DRAW_LINE: begin
                if (done_line) begin
                    vram_sel_o      <= 1'b0;
                    vram_wr_o       <= 1'b0;
                    state           <= WAIT_COMMAND;
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
                dsp_mul_p0 <= vv20 - vv00;
                dsp_mul_p1 <= vv11 - vv01;
                state <= DRAW_TRIANGLEC;
            end

            DRAW_TRIANGLEC: begin
                t0 <= dsp_mul_z;
                // t1 = mul(c1 - a1, b0 - a0)
                dsp_mul_p0 <= vv21 - vv01;
                dsp_mul_p1 <= vv10 - vv00;
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
                dsp_mul_p0 <= p0 - vv10;
                dsp_mul_p1 <= vv21 - vv11;
                state <= DRAW_TRIANGLE3B;
            end

            DRAW_TRIANGLE3B: begin
                t0 <= dsp_mul_z;
                // t1 = mul(c1 - a1, b0 - a0)
                dsp_mul_p0 <= p1 - vv11;
                dsp_mul_p1 <= vv20 - vv10;
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
                dsp_mul_p0 <= p0 - vv20;
                dsp_mul_p1 <= vv01 - vv21;
                state <= DRAW_TRIANGLE3E;
            end

            DRAW_TRIANGLE3E: begin
                t0 <= dsp_mul_z;
                // t1 = mul(c1 - a1, b0 - a0)
                dsp_mul_p0 <= p1 - vv21;
                dsp_mul_p1 <= vv00 - vv20;
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
                dsp_mul_p0 <= p0 - vv00;
                dsp_mul_p1 <= vv11 - vv01;
                state <= DRAW_TRIANGLE3H;
            end

            DRAW_TRIANGLE3H: begin
                t0 <= dsp_mul_z;
                // t1 = mul(c1 - a1, b0 - a0)
                dsp_mul_p0 <= p1 - vv01;
                dsp_mul_p1 <= vv10 - vv00;
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
                    state <= DRAW_TRIANGLE8;
                end else begin
`ifdef TEXTURED
                    // w0 = rmul(w0, inv_area)
                    dsp_rmul_p0 <= w0;
                    dsp_rmul_p1 <= inv_area;
                    state <= DRAW_TRIANGLE4B;
`else
                    state <= DRAW_TRIANGLE7;
`endif                    
                end
            end

            DRAW_TRIANGLE4B: begin
                w0 <= dsp_rmul_z >> 8;
                // w1 = rmul(w1, inv_area)
                dsp_rmul_p0 <= w1;
                state <= DRAW_TRIANGLE4C;
            end

            DRAW_TRIANGLE4C: begin
                w1 <= dsp_rmul_z >> 8;
                // w2 = rmul(w2, inv_area)
                dsp_rmul_p0 <= w2;
                state <= DRAW_TRIANGLE4D;
            end

            DRAW_TRIANGLE4D: begin
                w2 <= dsp_rmul_z >> 8;
                // r = mul(w0, c00) + mul(w1, c10) + mul(w2, c20)
                // t0 = mul(w0, c00)
                dsp_mul_p0 <= w0;
                dsp_mul_p1 <= c00;
                state <= DRAW_TRIANGLE4E;
            end

            DRAW_TRIANGLE4E: begin
                t0 <= dsp_mul_z;
                // t1 = mul(w1, c10)
                dsp_mul_p0 <= w1;
                dsp_mul_p1 <= c10;
                state <= DRAW_TRIANGLE4F;
            end

            DRAW_TRIANGLE4F: begin
                t1 <= dsp_mul_z;
                // t2 = mul(w2, c20)
                dsp_mul_p0 <= w2;
                dsp_mul_p1 <= c20;
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
                dsp_mul_p0 <= w0;
                dsp_mul_p1 <= c01;
                state <= DRAW_TRIANGLE4I;
            end

            DRAW_TRIANGLE4I: begin
                t0 <= dsp_mul_z;
                // t1 = mul(w1, c11)
                dsp_mul_p0 <= w1;
                dsp_mul_p1 <= c11;
                state <= DRAW_TRIANGLE4J;
            end

            DRAW_TRIANGLE4J: begin
                t1 <= dsp_mul_z;
                // t2 = mul(w2, c21)
                dsp_mul_p0 <= w2;
                dsp_mul_p1 <= c21;
                state <= DRAW_TRIANGLE4K;
            end

            DRAW_TRIANGLE4K: begin
                t2 <= dsp_mul_z;
                state <= DRAW_TRIANGLE4L;
            end

            DRAW_TRIANGLE4L: begin
                g <= t0 + t1 + t2;
`ifdef PERSP_CORRECT
                state <= DRAW_TRIANGLE5;
`else                                
                state <= DRAW_TRIANGLE6;
`endif                
            end

            DRAW_TRIANGLE5: begin
                // Perspective correction
                // z = 1 / (w0 * vv02 + w1 * vv12 + w2 * vv22)
                // r = r * z
                // g = g * z
                dsp_mul_p0 <= w0;
                dsp_mul_p1 <= vv02;
                state <= DRAW_TRIANGLE5B;
            end

            DRAW_TRIANGLE5B: begin
                t0 <= dsp_mul_z;
                dsp_mul_p0 <= w1;
                dsp_mul_p1 <= vv12;
                state <= DRAW_TRIANGLE5C;
            end

            DRAW_TRIANGLE5C: begin
                t1 <= dsp_mul_z;
                dsp_mul_p0 <= w2;
                dsp_mul_p1 <= vv22;
                state <= DRAW_TRIANGLE5D;
            end

            DRAW_TRIANGLE5D: begin
                t2 <= dsp_mul_z;
                state <= DRAW_TRIANGLE5E;
            end

            DRAW_TRIANGLE5E: begin
                reciprocal_x <= (t0 + t1 + t2) << 12;
                state <= DRAW_TRIANGLE5F;
            end

            DRAW_TRIANGLE5F: begin
                dsp_mul_p0 <= r;
                dsp_mul_p1 <= reciprocal_z << 12;
                state <= DRAW_TRIANGLE5G;
            end

            DRAW_TRIANGLE5G: begin
                r <= dsp_mul_z >> 8;
                dsp_mul_p0 <= g;
                state <= DRAW_TRIANGLE5H;
            end

            DRAW_TRIANGLE5H: begin
                g <= dsp_mul_z >> 8;
                state <= DRAW_TRIANGLE6;
            end

            DRAW_TRIANGLE6: begin
                $display("%x,%x", g, r);
                t0 <= rmul(rmul((TEXTURE_HEIGHT) << 16, clamp(g)), TEXTURE_WIDTH << 16);
                state <= DRAW_TRIANGLE6B;
            end

            DRAW_TRIANGLE6B: begin
                t1 <= rmul((TEXTURE_WIDTH) << 16, clamp(r));
                state <= DRAW_TRIANGLE6C;
            end

            DRAW_TRIANGLE6C: begin
                vram_sel_o <= 1'b1;
                vram_wr_o  <= 1'b0;
                vram_addr_o <= texture_address + 16'((t0 + t1) >> 16);
                state <= DRAW_TRIANGLE6D;
            end

            DRAW_TRIANGLE6D: begin
                state <= DRAW_TRIANGLE7;
            end

            DRAW_TRIANGLE7: begin
`ifdef TEXTURED                
                vram_data_out_o <= vram_data_in_i;
`else
                vram_data_out_o <= {16'hFFFF};
`endif          
                vram_sel_o <= 1'b1;
                vram_wr_o  <= 1'b1;
                vram_addr_o <= raster_addr;
                state <= DRAW_TRIANGLE7B;
            end

            DRAW_TRIANGLE7B: begin
                state <= DRAW_TRIANGLE8;
            end

            DRAW_TRIANGLE8: begin
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

                state <= DRAW_TRIANGLE9;
            end

            DRAW_TRIANGLE9: begin
                if (y >= max_y) begin
                    state       <= WAIT_COMMAND;
                end else begin
                    state       <= DRAW_TRIANGLE3;
                end
            end
        endcase

        if (drawing_line) begin
            if (x_line >= 0 && y_line >= 0 && x_line < FB_WIDTH && y_line < FB_HEIGHT) begin
                vram_addr_o     <= {4'b0, y_line} * FB_WIDTH + {4'b0, x_line};
                vram_data_out_o <= color;
                vram_mask_o     <= 4'hF;
                vram_sel_o      <= 1'b1;
                vram_wr_o       <= 1'b1;
            end else begin
                vram_sel_o      <= 1'b0;
                vram_wr_o       <= 1'b0;
            end
        end

        if (reset_i) begin
            swap_o            <= 1'b0;
            vram_sel_o        <= 1'b0;
            start_line        <= 1'b0;
            texture_address   <= FB_WIDTH * FB_HEIGHT;
            state             <= WAIT_COMMAND;
        end
    end

endmodule

