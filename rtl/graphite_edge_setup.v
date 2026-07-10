// graphite_edge_setup.v
// Copyright (c) 2021-2026 Daniel Cliche
// SPDX-License-Identifier: MIT

module graphite_edge_setup #(
    parameter FB_WIDTH = 640
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    
    input  wire signed [15:0] v0_x,
    input  wire signed [15:0] v0_y,
    input  wire signed [15:0] v1_x,
    input  wire signed [15:0] v1_y,
    input  wire signed [15:0] v2_x,
    input  wire signed [15:0] v2_y,
    input  wire        sign,

    output wire [15:0] min_x,
    output wire [15:0] max_x,
    output wire [15:0] max_y,
    output wire [15:0] start_x,
    output wire [15:0] start_y,

    output wire signed [31:0] E01_start,
    output wire signed [31:0] E12_start,
    output wire signed [31:0] E20_start,

    output wire signed [31:0] step_e01_x,
    output wire signed [31:0] step_e01_y,
    output wire signed [31:0] step_e12_x,
    output wire signed [31:0] step_e12_y,
    output wire signed [31:0] step_e20_x,
    output wire signed [31:0] step_e20_y
);

    wire signed [15:0] dx01 = v1_x - v0_x;
    wire signed [15:0] dy01 = v1_y - v0_y;
    wire signed [15:0] dx12 = v2_x - v1_x;
    wire signed [15:0] dy12 = v2_y - v1_y;
    wire signed [15:0] dx20 = v0_x - v2_x;
    wire signed [15:0] dy20 = v0_y - v2_y;

    wire bias01_is_neg1 = (sign == 1'b1) ? !(dy01 > 0 || (dy01 == 0 && dx01 < 0)) : (dy01 > 0 || (dy01 == 0 && dx01 < 0));
    wire bias12_is_neg1 = (sign == 1'b1) ? !(dy12 > 0 || (dy12 == 0 && dx12 < 0)) : (dy12 > 0 || (dy12 == 0 && dx12 < 0));
    wire bias20_is_neg1 = (sign == 1'b1) ? !(dy20 > 0 || (dy20 == 0 && dx20 < 0)) : (dy20 > 0 || (dy20 == 0 && dx20 < 0));
    
    wire signed [1:0] bias01 = bias01_is_neg1 ? -2'sd1 : 2'sd0;
    wire signed [1:0] bias12 = bias12_is_neg1 ? -2'sd1 : 2'sd0;
    wire signed [1:0] bias20 = bias20_is_neg1 ? -2'sd1 : 2'sd0;

    wire signed [15:0] min_x_raw = (v0_x < v1_x) ? ((v0_x < v2_x) ? v0_x : v2_x) : ((v1_x < v2_x) ? v1_x : v2_x);
    wire signed [15:0] max_x_raw = (v0_x > v1_x) ? ((v0_x > v2_x) ? v0_x : v2_x) : ((v1_x > v2_x) ? v1_x : v2_x);

    wire signed [15:0] min_x_floor = min_x_raw >>> 4;
    wire signed [15:0] max_x_floor = max_x_raw >>> 4;
    
    wire signed [15:0] min_x_clip = (min_x_floor < 0) ? 16'd0 : min_x_floor;
    wire signed [15:0] max_x_clip = (max_x_floor >= FB_WIDTH) ? (FB_WIDTH - 1) : max_x_floor;

    wire signed [15:0] start_y_raw = v0_y >>> 4;
    wire signed [15:0] start_y_clip = (start_y_raw < 0) ? 16'd0 : start_y_raw;

    wire signed [15:0] p_x = (min_x_clip <<< 4) + 16'd8;
    wire signed [15:0] p_y = (start_y_clip <<< 4) + 16'd8;

    wire signed [15:0] px_minus_v0x = p_x - v0_x;
    wire signed [15:0] py_minus_v0y = p_y - v0_y;
    wire signed [15:0] px_minus_v1x = p_x - v1_x;
    wire signed [15:0] py_minus_v1y = p_y - v1_y;
    wire signed [15:0] px_minus_v2x = p_x - v2_x;
    wire signed [15:0] py_minus_v2y = p_y - v2_y;

    reg signed [31:0] p0_x_dy, p0_y_dx;
    reg signed [31:0] p1_x_dy, p1_y_dx;
    reg signed [31:0] p2_x_dy, p2_y_dx;
    
    reg signed [1:0]  r_bias01, r_bias12, r_bias20;
    
    reg signed [31:0] r_step_e01_x, r_step_e01_y, r_step_e12_x, r_step_e12_y, r_step_e20_x, r_step_e20_y;
    reg [15:0] r_min_x, r_max_x, r_max_y, r_start_x, r_start_y;
    
    reg r_sign;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p0_x_dy <= 32'd0; p0_y_dx <= 32'd0;
            p1_x_dy <= 32'd0; p1_y_dx <= 32'd0;
            p2_x_dy <= 32'd0; p2_y_dx <= 32'd0;
            r_bias01 <= 2'd0; r_bias12 <= 2'd0; r_bias20 <= 2'd0;
            r_step_e01_x <= 32'd0; r_step_e01_y <= 32'd0;
            r_step_e12_x <= 32'd0; r_step_e12_y <= 32'd0;
            r_step_e20_x <= 32'd0; r_step_e20_y <= 32'd0;
            r_min_x <= 16'd0; r_max_x <= 16'd0; r_max_y <= 16'd0;
            r_start_x <= 16'd0; r_start_y <= 16'd0;
            r_sign <= 1'b0;
        end else if (start) begin
            p0_x_dy <= px_minus_v0x * dy01;
            p0_y_dx <= py_minus_v0y * dx01;
            p1_x_dy <= px_minus_v1x * dy12;
            p1_y_dx <= py_minus_v1y * dx12;
            p2_x_dy <= px_minus_v2x * dy20;
            p2_y_dx <= py_minus_v2y * dx20;
            
            r_bias01 <= bias01;
            r_bias12 <= bias12;
            r_bias20 <= bias20;

            r_step_e01_x <= sign ? -({{12{dy01[15]}}, dy01, 4'd0}) :  ({{12{dy01[15]}}, dy01, 4'd0});
            r_step_e01_y <= sign ?  ({{12{dx01[15]}}, dx01, 4'd0}) : -({{12{dx01[15]}}, dx01, 4'd0});
            
            r_step_e12_x <= sign ? -({{12{dy12[15]}}, dy12, 4'd0}) :  ({{12{dy12[15]}}, dy12, 4'd0});
            r_step_e12_y <= sign ?  ({{12{dx12[15]}}, dx12, 4'd0}) : -({{12{dx12[15]}}, dx12, 4'd0});
            
            r_step_e20_x <= sign ? -({{12{dy20[15]}}, dy20, 4'd0}) :  ({{12{dy20[15]}}, dy20, 4'd0});
            r_step_e20_y <= sign ?  ({{12{dx20[15]}}, dx20, 4'd0}) : -({{12{dx20[15]}}, dx20, 4'd0});

            r_min_x <= min_x_clip;
            r_max_x <= max_x_clip;
            r_max_y <= v2_y >>> 4;
            r_start_x <= min_x_clip;
            r_start_y <= start_y_clip;
            
            r_sign <= sign;
        end
    end

    wire signed [31:0] diff01 = p0_x_dy - p0_y_dx;
    wire signed [31:0] diff12 = p1_x_dy - p1_y_dx;
    wire signed [31:0] diff20 = p2_x_dy - p2_y_dx;
    
    wire signed [31:0] bias01_ext = {{30{r_bias01[1]}}, r_bias01};
    wire signed [31:0] bias12_ext = {{30{r_bias12[1]}}, r_bias12};
    wire signed [31:0] bias20_ext = {{30{r_bias20[1]}}, r_bias20};

    assign E01_start = r_sign ? (-diff01 + bias01_ext) : (diff01 + bias01_ext);
    assign E12_start = r_sign ? (-diff12 + bias12_ext) : (diff12 + bias12_ext);
    assign E20_start = r_sign ? (-diff20 + bias20_ext) : (diff20 + bias20_ext);

    assign step_e01_x = r_step_e01_x;
    assign step_e01_y = r_step_e01_y;
    assign step_e12_x = r_step_e12_x;
    assign step_e12_y = r_step_e12_y;
    assign step_e20_x = r_step_e20_x;
    assign step_e20_y = r_step_e20_y;

    assign min_x = r_min_x;
    assign max_x = r_max_x;
    assign max_y = r_max_y;
    assign start_x = r_start_x;
    assign start_y = r_start_y;

endmodule
