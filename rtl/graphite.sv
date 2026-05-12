// graphite.sv
// Copyright (c) 2021-2024 Daniel Cliche
// SPDX-License-Identifier: MIT

// Ref.: https://www.scratchapixel.com/lessons/3d-basic-rendering/rasterization-practical-implementation

`include "graphite.svh"

module dsp_mul(
    input wire logic signed [31:0] p0,
    input wire logic signed [31:0] p1,
    output     logic signed [63:0] z
);
    assign z = mul(p0, p1);
endmodule

module graphite #(
    parameter FB_ADDRESS = 32'h0,
    parameter FB_WIDTH = 128,
    parameter FB_HEIGHT = 128,
    parameter TEXTURE_WIDTH = 32,
    parameter TEXTURE_HEIGHT = 32,
    parameter SUBPIXEL_PRECISION_MASK = 16'hF000
    ) (
    input  wire logic                        clk,
    input  wire logic                        reset_i,
    input  wire logic                        ce_i,

    // AXI stream command interface (slave)
    input  wire logic                        cmd_axis_tvalid_i,
    output      logic                        cmd_axis_tready_o,
    input  wire logic [31:0]                 cmd_axis_tdata_i,

    // VRAM write
    output      logic                        vram_sel_o,
    output      logic                        vram_wr_o,
    output      logic  [3:0]                 vram_mask_o,
    output      logic [31:0]                 vram_addr_o,
    input       logic [15:0]                 vram_data_in_i,
    output      logic [15:0]                 vram_data_out_o,

    input  wire logic                        vsync_i,
    output      logic                        swap_o,
    output      logic [31:0]                 front_addr_o,
    output      logic                        clear_o
    );

    enum { WAIT_COMMAND, PROCESS_COMMAND, SWAP0, CLEAR_FB0, CLEAR_DEPTH0,
           DRAW_TRIANGLE00, DRAW_TRIANGLE01, DRAW_TRIANGLE02, DRAW_TRIANGLE04, DRAW_TRIANGLE05, DRAW_TRIANGLE06, DRAW_TRIANGLE07, DRAW_TRIANGLE08,
           DRAW_TRIANGLE12, DRAW_TRIANGLE13, DRAW_TRIANGLE15,
           DRAW_TRIANGLE18, DRAW_TRIANGLE21,
           DRAW_TRIANGLE24, DRAW_TRIANGLE25, DRAW_TRIANGLE28,
           DRAW_TRIANGLE31, DRAW_TRIANGLE32, DRAW_TRIANGLE33, DRAW_TRIANGLE_FRAGMENT,
           DRAW_TRIANGLE59,
           DRAW_TRIANGLE60
    } state;

    localparam NB_DSP_MULS = 3;

    logic signed [31:0] vv00, vv01, vv02, vv10, vv11, vv12, vv20, vv21, vv22;
    logic signed [31:0] c00, c01, c02;
    logic signed [31:0] c10, c11, c12;
    logic signed [31:0] c20, c21, c22;
    logic signed [31:0] st00, st01, st10, st11, st20, st21;

    logic signed [11:0] x, y;
    
    logic [31:0] fb_address, texture_address;
    logic [31:0] front_rel_address, back_rel_address, depth_rel_address;

    logic [31:0] texture_write_address;
    logic [31:0] raster_rel_address;

    assign front_addr_o = fb_address + front_rel_address;

    logic [2:0] texture_width_scale;
    logic [2:0] texture_height_scale;

    //
    // Draw triangle
    //

    logic is_textured, is_clamp_s, is_clamp_t, is_depth_test, is_perspective_correct;

    logic signed [31:0] p0, p1;
    logic signed [31:0] w0, w1, w2;
    logic signed [31:0] inv_area;
    logic signed [31:0] s, t;
    logic signed [31:0] r, g, b;

    logic signed [31:0] raster_dsp_mul_p0[NB_DSP_MULS], raster_dsp_mul_p1[NB_DSP_MULS];
    wire signed [31:0] frag_dsp_mul_p0[NB_DSP_MULS], frag_dsp_mul_p1[NB_DSP_MULS];
    wire signed [31:0] dsp_mul_p0[NB_DSP_MULS], dsp_mul_p1[NB_DSP_MULS];
    logic signed [63:0] dsp_mul_z[NB_DSP_MULS];

    logic signed [31:0] t0, t1;
    logic        [31:0] z;

    logic        [15:0] sample;

    logic signed [11:0] min_x, min_y, max_x, max_y;

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
            dsp_mul dsp_mul(
                .p0(dsp_mul_p0[dsp_mul_index]),
                .p1(dsp_mul_p1[dsp_mul_index]),
                .z(dsp_mul_z[dsp_mul_index])
            );
        end
    endgenerate

    logic [31:0] raster_reciprocal_x;
    logic raster_reciprocal_start;
    wire [31:0] frag_reciprocal_x;
    wire frag_reciprocal_start;
    wire [31:0] reciprocal_x;
    wire reciprocal_start;
    logic [31:0] reciprocal_z;
    logic reciprocal_done;

    reciprocal reciprocal(
        .clk(clk),
        .reset_i(reset_i),
        .start_i(reciprocal_start),
        .x_i(reciprocal_x),
        .z_o(reciprocal_z),
        .done_o(reciprocal_done)
    );

    logic core_vram_sel, core_vram_wr;
    logic [3:0] core_vram_mask;
    logic [31:0] core_vram_addr;
    logic [15:0] core_vram_data_out;

    logic frag_launch;
    wire fs_busy;
    wire frag_done;

    wire fs_vram_sel_o, fs_vram_wr_o;
    wire [3:0] fs_vram_mask_o;
    wire [31:0] fs_vram_addr_o;
    wire [15:0] fs_vram_data_out_o;

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
        .is_textured_i(is_textured),
        .is_clamp_s_i(is_clamp_s),
        .is_clamp_t_i(is_clamp_t),
        .is_depth_test_i(is_depth_test),
        .is_perspective_correct_i(is_perspective_correct),
        .texture_width_scale_i(texture_width_scale),
        .texture_height_scale_i(texture_height_scale),
        .fb_address_i(fb_address),
        .texture_address_i(texture_address),
        .depth_rel_address_i(depth_rel_address),
        .back_rel_address_i(back_rel_address),
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
    assign vram_sel_o = fs_busy ? fs_vram_sel_o : core_vram_sel;
    assign vram_wr_o = fs_busy ? fs_vram_wr_o : core_vram_wr;
    assign vram_mask_o = fs_busy ? fs_vram_mask_o : core_vram_mask;
    assign vram_addr_o = fs_busy ? fs_vram_addr_o : core_vram_addr;
    assign vram_data_out_o = fs_busy ? fs_vram_data_out_o : core_vram_data_out;

    assign p0 = {6'd0, x, 14'd0};
    assign p1 = {6'd0, y, 14'd0};

    assign cmd_axis_tready_o = state == WAIT_COMMAND;

    always_ff @(posedge clk) begin
        if (ce_i) case (state)
            WAIT_COMMAND: begin
                swap_o <= 1'b0;
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
                        core_vram_addr     <= fb_address + ((cmd_axis_tdata_i[16] == 0) ? back_rel_address : 32'(2 * FB_WIDTH * FB_HEIGHT));
                        core_vram_data_out <= cmd_axis_tdata_i[15:0];
                        clear_o            <= 1'b1;
                        core_vram_mask     <= 4'hF;
                        core_vram_sel      <= 1'b1;
                        core_vram_wr       <= 1'b1;
                        state              <= (cmd_axis_tdata_i[16] == 0) ? CLEAR_FB0 : CLEAR_DEPTH0;
                    end
                    OP_DRAW: begin
                        // Draw triangle
                        is_textured            <= cmd_axis_tdata_i[0];
                        is_clamp_t             <= cmd_axis_tdata_i[1];
                        is_clamp_s             <= cmd_axis_tdata_i[2];
                        is_depth_test          <= cmd_axis_tdata_i[3];
                        is_perspective_correct <= cmd_axis_tdata_i[4];
                        texture_width_scale    <= cmd_axis_tdata_i[7:5];
                        texture_height_scale   <= cmd_axis_tdata_i[10:8];
                        core_vram_mask     <= 4'hF;
                        min_x <= min3(12'(vv00 >> 14), 12'(vv10 >> 14), 12'(vv20 >> 14));
                        min_y <= min3(12'(vv01 >> 14), 12'(vv11 >> 14), 12'(vv21 >> 14));
                        max_x <= max3(12'(vv00 >> 14), 12'(vv10 >> 14), 12'(vv20 >> 14));
                        max_y <= max3(12'(vv01 >> 14), 12'(vv11 >> 14), 12'(vv21 >> 14));
                        state <= DRAW_TRIANGLE00;
                    end
                    OP_SWAP: begin
                        if (vsync_i || !cmd_axis_tdata_i[0]) begin
                            swap_o <= 1'b1;
                            front_rel_address <= back_rel_address;
                            back_rel_address  <= front_rel_address;
                            state         <= SWAP0;
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
                        if (cmd_axis_tdata_i[16]) begin
                            fb_address[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            fb_address[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        front_rel_address   <= 32'h0;
                        back_rel_address    <= cmd_axis_tdata_i[17] ? 32'h0 : FB_WIDTH * FB_HEIGHT;
                        state <= WAIT_COMMAND;
                    end
                    default:
                        state <= WAIT_COMMAND;
                endcase
            end

            SWAP0: begin
                if (vsync_i) begin
                    state  <= WAIT_COMMAND;
                end
            end

            CLEAR_FB0: begin
                if (core_vram_addr < fb_address + back_rel_address + FB_WIDTH * FB_HEIGHT - 1) begin
                    core_vram_addr <= core_vram_addr + 1;
                end else begin
                    clear_o     <= 1'b0;
                    state       <= WAIT_COMMAND;
                end
            end

            CLEAR_DEPTH0: begin
                if (core_vram_addr < fb_address + 3 * FB_WIDTH * FB_HEIGHT - 1) begin
                    core_vram_addr <= core_vram_addr + 1;
                end else begin
                    clear_o    <= 1'b0;
                    state      <= WAIT_COMMAND;
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
                raster_dsp_mul_p0[0] <= (vv20 - vv00);
                raster_dsp_mul_p1[0] <= (vv11 - vv01);
                // t1 = mul(c1 - a1, b0 - a0)
                raster_dsp_mul_p0[1] <= (vv21 - vv01);
                raster_dsp_mul_p1[1] <= (vv10 - vv00);
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
                // w0 = edge_function(vv1, vv2, p);
                // w0 = mul(c0 - a0, b1 - a1) - mul(c1 - a1, b0 - a0)
                // t0 = mul(c0 - a0, b1 - a1)
                raster_dsp_mul_p0[0] <= (p0 - vv10);
                raster_dsp_mul_p1[0] <= (vv21 - vv11);
                // t1 = mul(c1 - a1, b0 - a0)
                raster_dsp_mul_p0[1] <= (p1 - vv11);
                raster_dsp_mul_p1[1] <= (vv20 - vv10);
                state <= DRAW_TRIANGLE06;
            end

            DRAW_TRIANGLE06: begin

                w0 <= dsp_mul_z[0][31:0] - dsp_mul_z[1][31:0];

                // w1 = edge_function(vv2, vv0, p);
                // w1 = mul(c0 - a0, b1 - a1) - mul(c1 - a1, b0 - a0)
                // t0 = mul(c0 - a0, b1 - a1)
                raster_dsp_mul_p0[0] <= (p0 - vv20);
                raster_dsp_mul_p1[0] <= (vv01 - vv21);

                // t1 = mul(c1 - a1, b0 - a0)
                raster_dsp_mul_p0[1] <= (p1 - vv21);
                raster_dsp_mul_p1[1] <= (vv00 - vv20);
                state <= DRAW_TRIANGLE07;
            end

            DRAW_TRIANGLE07: begin
                w1 <= dsp_mul_z[0][31:0] - dsp_mul_z[1][31:0];

                // w2 = edge_function(vv0, vv1, p);
                // w2 = mul(c0 - a0, b1 - a1) - mul(c1 - a1, b0 - a0)
                // t0 = mul(c0 - a0, b1 - a1)
                raster_dsp_mul_p0[0] <= (p0 - vv00);
                raster_dsp_mul_p1[0] <= (vv11 - vv01);
                // t1 = mul(c1 - a1, b0 - a0)
                raster_dsp_mul_p0[1] <= (p1 - vv01);
                raster_dsp_mul_p1[1] <= (vv10 - vv00);

                state <= DRAW_TRIANGLE08;
            end

            DRAW_TRIANGLE08: begin
                w2 <= dsp_mul_z[0][31:0] - dsp_mul_z[1][31:0];
                state <= DRAW_TRIANGLE12;
            end

            DRAW_TRIANGLE12: begin
                // if w0 < 0, w1 < 0 or w2 < 0
                if (w0[31] || w1[31] || w2[31]) begin
                    state <= DRAW_TRIANGLE59;
                end else begin
                    // w0 = mul(w0, inv_area)
                    raster_dsp_mul_p0[0] <= w0;
                    raster_dsp_mul_p1[0] <= inv_area;
                    // w1 = mul(w1, inv_area)
                    raster_dsp_mul_p0[1] <= w1;
                    raster_dsp_mul_p1[1] <= inv_area;
                    // w2 = mul(w2, inv_area)
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
                // r = mul(w0, c00) + mul(w1, c10) + mul(w2, c20)
                // t0 = mul(w0, c00)
                raster_dsp_mul_p0[0] <= w0;
                raster_dsp_mul_p1[0] <= c00;
                // t1 = mul(w1, c10)
                raster_dsp_mul_p0[1] <= w1;
                raster_dsp_mul_p1[1] <= c10;
                // t2 = mul(w2, c20)
                raster_dsp_mul_p0[2] <= w2;
                raster_dsp_mul_p1[2] <= c20;
                state <= DRAW_TRIANGLE18;
            end

            DRAW_TRIANGLE18: begin
                r <= dsp_mul_z[0][31:0] + dsp_mul_z[1][31:0] + dsp_mul_z[2][31:0];
                // g = mul(w0, c01) + mul(w1, c11) + mul(w2, c21)
                // t0 = mul(w0, c01)
                raster_dsp_mul_p0[0] <= w0;
                raster_dsp_mul_p1[0] <= c01;
                // t1 = mul(w1, c11)
                raster_dsp_mul_p0[1] <= w1;
                raster_dsp_mul_p1[1] <= c11;
                // t2 = mul(w2, c21)
                raster_dsp_mul_p0[2] <= w2;
                raster_dsp_mul_p1[2] <= c21;
                state <= DRAW_TRIANGLE21;
            end

            DRAW_TRIANGLE21: begin
                g <= dsp_mul_z[0][31:0] + dsp_mul_z[1][31:0] + dsp_mul_z[2][31:0];
                // b = mul(w0, c02) + mul(w1, c12) + mul(w2, c22)
                // t0 = mul(w0, c02)
                raster_dsp_mul_p0[0] <= w0;
                raster_dsp_mul_p1[0] <= c02;
                // t1 = mul(w1, c12)
                raster_dsp_mul_p0[1] <= w1;
                raster_dsp_mul_p1[1] <= c12;
                // t2 = mul(w2, c22)
                raster_dsp_mul_p0[2] <= w2;
                raster_dsp_mul_p1[2] <= c22;
                state <= DRAW_TRIANGLE24;
            end

            DRAW_TRIANGLE24: begin
                b <= dsp_mul_z[0][31:0] + dsp_mul_z[1][31:0] + dsp_mul_z[2][31:0];
                if (is_textured) begin
                    state <= DRAW_TRIANGLE25;
                end else begin
                    sample <= 16'hFFFF;
                    state <= DRAW_TRIANGLE32;
                end
            end

            DRAW_TRIANGLE25: begin
                // s = mul(w0, st00) + mul(w1, st10) + mul(w2, st20)
                // t0 = mul(w0, st00)
                raster_dsp_mul_p0[0] <= w0;
                raster_dsp_mul_p1[0] <= st00;
                // t1 = mul(w1, st10)
                raster_dsp_mul_p0[1] <= w1;
                raster_dsp_mul_p1[1] <= st10;
                // t2 = mul(w2, st20)
                raster_dsp_mul_p0[2] <= w2;
                raster_dsp_mul_p1[2] <= st20;
                state <= DRAW_TRIANGLE28;
            end

            DRAW_TRIANGLE28: begin
                s <= dsp_mul_z[0][31:0] + dsp_mul_z[1][31:0] + dsp_mul_z[2][31:0];
                // t = mul(w0, st01) + mul(w1, st11) + mul(w2, st21)
                // t0 = mul(w0, st01)
                raster_dsp_mul_p0[0] <= w0;
                raster_dsp_mul_p1[0] <= st01;
                // t1 = mul(w1, st11)
                raster_dsp_mul_p0[1] <= w1;
                raster_dsp_mul_p1[1] <= st11;
                // t2 = mul(w2, st21)
                raster_dsp_mul_p0[2] <= w2;
                raster_dsp_mul_p1[2] <= st21;
                state <= DRAW_TRIANGLE31;
            end

            DRAW_TRIANGLE31: begin
                t <= dsp_mul_z[0][31:0] + dsp_mul_z[1][31:0] + dsp_mul_z[2][31:0];
                state <= DRAW_TRIANGLE32;
            end

            DRAW_TRIANGLE32: begin
                // z = w0 * vv02 + w1 * vv12 + w2 * vv22
                raster_dsp_mul_p0[0] <= w0;
                raster_dsp_mul_p1[0] <= vv02;
                raster_dsp_mul_p0[1] <= w1;
                raster_dsp_mul_p1[1] <= vv12;
                raster_dsp_mul_p0[2] <= w2;
                raster_dsp_mul_p1[2] <= vv22;
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
                    state       <= WAIT_COMMAND;
                end else begin
                    state       <= DRAW_TRIANGLE05;
                end
            end
        endcase

        if (reset_i) begin
            swap_o               <= 1'b0;
            core_vram_sel        <= 1'b0;
            core_vram_wr         <= 1'b0;
            clear_o              <= 1'b0;
            fb_address           <= FB_ADDRESS;
            front_rel_address    <= 32'h0;
            back_rel_address     <= FB_WIDTH * FB_HEIGHT;
            depth_rel_address    <= 2 * FB_WIDTH * FB_HEIGHT;
            texture_address      <= FB_ADDRESS + 3 * FB_WIDTH * FB_HEIGHT;
            state                <= WAIT_COMMAND;
            raster_reciprocal_start <= 1'b0;
            texture_width_scale  <= 3'd0;
            texture_height_scale <= 3'd0;
            frag_launch          <= 1'b0;
        end
    end

endmodule

