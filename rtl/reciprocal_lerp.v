// reciprocal_lerp.v
// Copyright (c) 2021-2026 Daniel Cliche
// SPDX-License-Identifier: MIT

module reciprocal_lerp (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         stall,  // Freeze all pipeline registers when high
    input  wire [31:0]  z_inv,  // Input 2.30 fixed-point stream from span
    output reg  [31:0]  w_out   // Output 16.16 perspective scale factor
);

    // -------------------------------------------------------------------------
    // STAGE 1: Explicit Priority Encoder (Leading Zero Detection) & Normalization
    // -------------------------------------------------------------------------
    reg [4:0]  lz_count;
    reg [31:0] z_norm;

    always @(*) begin
        if      (z_inv[31]) lz_count = 5'd0;
        else if (z_inv[30]) lz_count = 5'd1;
        else if (z_inv[29]) lz_count = 5'd2;
        else if (z_inv[28]) lz_count = 5'd3;
        else if (z_inv[27]) lz_count = 5'd4;
        else if (z_inv[26]) lz_count = 5'd5;
        else if (z_inv[25]) lz_count = 5'd6;
        else if (z_inv[24]) lz_count = 5'd7;
        else if (z_inv[23]) lz_count = 5'd8;
        else if (z_inv[22]) lz_count = 5'd9;
        else if (z_inv[21]) lz_count = 5'd10;
        else if (z_inv[20]) lz_count = 5'd11;
        else if (z_inv[19]) lz_count = 5'd12;
        else if (z_inv[18]) lz_count = 5'd13;
        else if (z_inv[17]) lz_count = 5'd14;
        else if (z_inv[16]) lz_count = 5'd15;
        else if (z_inv[15]) lz_count = 5'd16;
        else if (z_inv[14]) lz_count = 5'd17;
        else if (z_inv[13]) lz_count = 5'd18;
        else if (z_inv[12]) lz_count = 5'd19;
        else if (z_inv[11]) lz_count = 5'd20;
        else if (z_inv[10]) lz_count = 5'd21;
        else if (z_inv[9])  lz_count = 5'd22;
        else if (z_inv[8])  lz_count = 5'd23;
        else if (z_inv[7])  lz_count = 5'd24;
        else if (z_inv[6])  lz_count = 5'd25;
        else if (z_inv[5])  lz_count = 5'd26;
        else if (z_inv[4])  lz_count = 5'd27;
        else if (z_inv[3])  lz_count = 5'd28;
        else if (z_inv[2])  lz_count = 5'd29;
        else if (z_inv[1])  lz_count = 5'd30;
        else                lz_count = 5'd31;

        z_norm = z_inv << lz_count;
    end

    // Pipeline Registers: Stage 1 (gated by stall)
    reg [4:0]  r1_lz_count;
    reg [7:0]  r1_lut_idx;
    reg [22:0] r1_frac;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r1_lz_count <= 5'd0;
            r1_lut_idx  <= 8'd0;
            r1_frac     <= 23'd0;
        end else if (!stall) begin
            r1_lz_count <= lz_count;
            r1_lut_idx  <= z_norm[30:23];
            r1_frac     <= z_norm[22:0];
        end
    end

    // -------------------------------------------------------------------------
    // STAGE 2: BRAM LUT Inversion Data Lookup
    // The LUT now receives the stall signal so its output register freezes
    // in lock-step with the r1b_* registers below.  Without this, the LUT
    // advances one extra cycle during a stall (because r1_lut_idx is stall-
    // gated but the LUT register is not), creating a 1-cycle misalignment
    // between lut_base and r1b_lz_count/r1b_frac after the stall ends.
    // -------------------------------------------------------------------------
    wire [31:0] lut_base;
    wire [23:0] lut_slope;

    reciprocal_lut u_sst1_table (
        .clk  (clk),
        .stall(stall),       // ← stall gate prevents lut_base from advancing
        .idx  (r1_lut_idx),
        .base (lut_base),
        .slope(lut_slope)
    );

    // Pipeline Registers: Stage 1b  (delay r1_* by one extra cycle to align
    // with the LUT's registered output; also gated by stall)
    reg [4:0]  r1b_lz_count;
    reg [22:0] r1b_frac;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r1b_lz_count <= 5'd0;
            r1b_frac     <= 23'd0;
        end else if (!stall) begin
            r1b_lz_count <= r1_lz_count;
            r1b_frac     <= r1_frac;
        end
    end

    // Pipeline Registers: Stage 2 -> Stage 3
    // r1b_lz_count / r1b_frac are now aligned with lut_base / lut_slope.
    reg [4:0]  r2_lz_count;
    reg [31:0] r2_base;
    reg [46:0] r2_delta_prod;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r2_lz_count   <= 5'd0;
            r2_base       <= 32'd0;
            r2_delta_prod <= 47'd0;
        end else if (!stall) begin
            r2_lz_count   <= r1b_lz_count;
            r2_base       <= lut_base;
            r2_delta_prod <= r1b_frac * lut_slope;
        end
    end

    // -------------------------------------------------------------------------
    // STAGE 3: Piecewise Linear Assembly & Fixed-Point Conversion
    // -------------------------------------------------------------------------
    wire [31:0] w_norm    = r2_base - 32'(r2_delta_prod >> 23);
    wire [63:0] w_expanded = ({32'b0, w_norm} << r2_lz_count);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_out <= 32'd0;
        end else if (!stall) begin
            w_out <= w_expanded[52:21];
        end
    end

endmodule
