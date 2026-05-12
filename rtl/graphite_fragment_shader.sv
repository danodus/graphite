// graphite_fragment_shader.sv
// Copyright (c) 2021-2026 Daniel Cliche
// SPDX-License-Identifier: MIT

`include "graphite.svh"

module graphite_fragment_shader #(
    parameter int FB_WIDTH = 128,
    parameter int FB_HEIGHT = 128,
    parameter int TEXTURE_WIDTH = 32,
    parameter int TEXTURE_HEIGHT = 32
) (
    input  wire logic clk,
    input  wire logic reset_i,
    input  wire logic ce_i,
    input  wire logic start_i,

    input  wire logic signed [11:0] x_i,
    input  wire logic signed [11:0] y_i,
    input  wire logic        [31:0] z_i,
    input  wire logic signed [31:0] r_i,
    input  wire logic signed [31:0] g_i,
    input  wire logic signed [31:0] b_i,
    input  wire logic signed [31:0] s_i,
    input  wire logic signed [31:0] t_i,
    input  wire logic        [15:0] sample_i,

    input  wire logic is_textured_i,
    input  wire logic is_clamp_s_i,
    input  wire logic is_clamp_t_i,
    input  wire logic is_depth_test_i,
    input  wire logic is_perspective_correct_i,
    input  wire logic [2:0] texture_width_scale_i,
    input  wire logic [2:0] texture_height_scale_i,

    input  wire logic [31:0] fb_address_i,
    input  wire logic [31:0] texture_address_i,
    input  wire logic [31:0] depth_rel_address_i,
    input  wire logic [31:0] back_rel_address_i,
    input  wire logic [31:0] raster_rel_address_i,

    input  wire logic [15:0] vram_data_in_i,

    // Separate multiplier result ports (Yosys does not support unpacked array ports)
    input  wire logic signed [63:0] dsp_mul_z_0_i,
    input  wire logic signed [63:0] dsp_mul_z_1_i,
    input  wire logic signed [63:0] dsp_mul_z_2_i,
    input  wire logic [31:0] reciprocal_z_i,
    input  wire logic reciprocal_done_i,

    output logic busy_o,
    output logic done_o,

    output logic signed [31:0] fs_dsp_mul_p0_0_o,
    output logic signed [31:0] fs_dsp_mul_p0_1_o,
    output logic signed [31:0] fs_dsp_mul_p0_2_o,
    output logic signed [31:0] fs_dsp_mul_p1_0_o,
    output logic signed [31:0] fs_dsp_mul_p1_1_o,
    output logic signed [31:0] fs_dsp_mul_p1_2_o,
    output logic [31:0] fs_reciprocal_x_o,
    output logic fs_reciprocal_start_o,

    output logic fs_vram_sel_o,
    output logic fs_vram_wr_o,
    output logic [3:0] fs_vram_mask_o,
    output logic [31:0] fs_vram_addr_o,
    output logic [15:0] fs_vram_data_out_o
);

    enum logic [4:0] {
        FS_IDLE,
        FS_S35,
        FS_S36,
        FS_S37,
        FS_S38,
        FS_S39,
        FS_S40,
        FS_S41,
        FS_S42,
        FS_S43,
        FS_S44,
        FS_S48,
        FS_S49,
        FS_S51,
        FS_S52,
        FS_S53,
        FS_S54,
        FS_S55,
        FS_S56,
        FS_S57,
        FS_S58
    } state;

    logic signed [31:0] r, g, b, s, t;
    logic        [31:0] z;
    logic        [15:0] depth;
    logic        [15:0] sample;

    logic        rec_start_r;

    assign busy_o = (state != FS_IDLE);
    assign fs_vram_mask_o = 4'hF;
    assign fs_reciprocal_start_o = rec_start_r;

    always_ff @(posedge clk) begin
        done_o <= 1'b0;
        if (ce_i) begin
            rec_start_r <= 1'b0;
            unique case (state)
                FS_IDLE: begin
                    if (start_i) begin
                        z <= z_i;
                        r <= r_i;
                        g <= g_i;
                        b <= b_i;
                        s <= s_i;
                        t <= t_i;
                        sample <= sample_i;
                        state <= FS_S35;
                    end else begin
                        fs_vram_sel_o <= 1'b0;
                        fs_vram_wr_o <= 1'b0;
                        fs_dsp_mul_p0_0_o <= '0;
                        fs_dsp_mul_p0_1_o <= '0;
                        fs_dsp_mul_p0_2_o <= '0;
                        fs_dsp_mul_p1_0_o <= '0;
                        fs_dsp_mul_p1_1_o <= '0;
                        fs_dsp_mul_p1_2_o <= '0;
                    end
                end

                FS_S35: begin
                    fs_vram_addr_o <= fb_address_i + depth_rel_address_i + 32'(y_i) * FB_WIDTH + 32'(x_i);
                    if (is_depth_test_i) begin
                        fs_vram_wr_o <= 1'b0;
                        fs_vram_sel_o <= 1'b1;
                        state <= FS_S36;
                    end else begin
                        state <= FS_S39;
                    end
                end

                FS_S36: begin
                    fs_vram_sel_o <= 1'b0;
                    state <= FS_S37;
                end

                FS_S37: begin
                    depth <= vram_data_in_i;
                    state <= FS_S38;
                end

                FS_S38: begin
                    if (16'(z) > depth) begin
                        state <= FS_S39;
                    end else begin
                        state <= FS_IDLE;
                        done_o <= 1'b1;
                    end
                end

                FS_S39: begin
                    fs_vram_data_out_o <= 16'(z);
                    fs_vram_wr_o <= 1'b1;
                    fs_vram_sel_o <= 1'b1;
                    state <= FS_S40;
                end

                FS_S40: begin
                    fs_vram_sel_o <= 1'b0;
                    state <= FS_S41;
                end

                FS_S41: begin
                    if (is_perspective_correct_i) begin
                        fs_reciprocal_x_o <= z << 12;
                        rec_start_r <= 1'b1;
                        state <= FS_S42;
                    end else begin
                        state <= FS_S48;
                    end
                end

                FS_S42: begin
                    if (reciprocal_done_i) begin
                        fs_dsp_mul_p0_0_o <= r;
                        fs_dsp_mul_p1_0_o <= (reciprocal_z_i << 12);
                        fs_dsp_mul_p0_1_o <= g;
                        fs_dsp_mul_p1_1_o <= (reciprocal_z_i << 12);
                        fs_dsp_mul_p0_2_o <= b;
                        fs_dsp_mul_p1_2_o <= (reciprocal_z_i << 12);
                        state <= FS_S43;
                    end
                end

                FS_S43: begin
                    r <= dsp_mul_z_0_i[31:0] >> 8;
                    g <= dsp_mul_z_1_i[31:0] >> 8;
                    b <= dsp_mul_z_2_i[31:0] >> 8;
                    fs_dsp_mul_p0_0_o <= s;
                    fs_dsp_mul_p1_0_o <= (reciprocal_z_i << 12);
                    fs_dsp_mul_p0_1_o <= t;
                    fs_dsp_mul_p1_1_o <= (reciprocal_z_i << 12);
                    state <= FS_S44;
                end

                FS_S44: begin
                    s <= dsp_mul_z_0_i[31:0] >> 8;
                    t <= dsp_mul_z_1_i[31:0] >> 8;
                    state <= FS_S48;
                end

                FS_S48: begin
                    if (is_textured_i) begin
                        state <= FS_S49;
                    end else begin
                        state <= FS_S54;
                    end
                end

                FS_S49: begin
                    fs_dsp_mul_p0_0_o <= (((TEXTURE_HEIGHT << texture_height_scale_i) - 1) << 14);
                    fs_dsp_mul_p1_0_o <= (is_clamp_t_i ? clamp(t) : wrap(t));
                    fs_dsp_mul_p0_1_o <= (((TEXTURE_WIDTH << texture_width_scale_i) - 1) << 14);
                    fs_dsp_mul_p1_1_o <= (is_clamp_s_i ? clamp(s) : wrap(s));
                    state <= FS_S51;
                end

                FS_S51: begin
                    fs_dsp_mul_p0_0_o <= dsp_mul_z_0_i[31:0] & 32'hFFFFC000;
                    fs_dsp_mul_p1_0_o <= (TEXTURE_WIDTH << texture_width_scale_i) << 14;
                    state <= FS_S52;
                end

                FS_S52: begin
                    fs_vram_sel_o <= 1'b1;
                    fs_vram_wr_o <= 1'b0;
                    fs_vram_addr_o <= texture_address_i + 32'(dsp_mul_z_0_i >> 14) + 32'(dsp_mul_z_1_i >> 14);
                    state <= FS_S53;
                end

                FS_S53: begin
                    fs_vram_sel_o <= 1'b0;
                    sample <= vram_data_in_i;
                    state <= FS_S54;
                end

                FS_S54: begin
                    fs_dsp_mul_p0_0_o <= {13'd0, sample[11:8], sample[11], 14'd0};
                    fs_dsp_mul_p1_0_o <= r;
                    state <= FS_S55;
                end

                FS_S55: begin
                    fs_vram_data_out_o[15:11] <= 5'(dsp_mul_z_0_i[31:0] >> 14);
                    fs_dsp_mul_p0_0_o <= {12'd0, sample[7:4], sample[7:6], 14'd0};
                    fs_dsp_mul_p1_0_o <= g;
                    state <= FS_S56;
                end

                FS_S56: begin
                    fs_vram_data_out_o[10:5] <= 6'(dsp_mul_z_0_i[31:0] >> 14);
                    fs_dsp_mul_p0_0_o <= {13'd0, sample[3:0], sample[3], 14'd0};
                    fs_dsp_mul_p1_0_o <= b;
                    state <= FS_S57;
                end

                FS_S57: begin
                    fs_vram_data_out_o[4:0] <= 5'(dsp_mul_z_0_i[31:0] >> 14);
                    fs_vram_sel_o <= 1'b1;
                    fs_vram_wr_o <= 1'b1;
                    fs_vram_addr_o <= fb_address_i + back_rel_address_i + raster_rel_address_i;
                    state <= FS_S58;
                end

                FS_S58: begin
                    fs_vram_sel_o <= 1'b0;
                    fs_vram_wr_o <= 1'b0;
                    state <= FS_IDLE;
                    done_o <= 1'b1;
                end

                default: state <= FS_IDLE;
            endcase
        end
        if (reset_i) begin
            state <= FS_IDLE;
            rec_start_r <= 1'b0;
            fs_vram_sel_o <= 1'b0;
            fs_vram_wr_o <= 1'b0;
            done_o <= 1'b0;
        end
    end

endmodule
