// graphite_rasterizer.v
// Copyright (c) 2021-2026 Daniel Cliche
// SPDX-License-Identifier: MIT

module graphite_rasterizer #(
    parameter FB_WIDTH = 640,
    parameter FB_HEIGHT = 480
) (
    input  wire         clk,
    input  wire         ce,
    input  wire         rst_n,

    // Control
    input  wire         start,
    input  wire         enable_texture,
    input  wire         enable_depth_test,
    input  wire         enable_perspective_correct,
    input  wire         depth_only,
    input  wire         enable_shadow,
    input  wire         enable_dither,
    input  wire         clamp_s,
    input  wire         clamp_t,
    input  wire [2:0]   texture_width_scale,
    input  wire [2:0]   texture_height_scale,
    input  wire [2:0]   shadow_width_scale,
    input  wire [2:0]   shadow_height_scale,
    input  wire [15:0]  shadow_bias,
    input  wire [7:0]   depth_bias,
    input  wire [15:0]  viewport_width,
    input  wire [15:0]  viewport_height,
    output wire         busy,

    // Vertices
    input  wire signed [15:0] v0_x,
    input  wire signed [15:0] v0_y,
    input  wire signed [15:0] v1_x,
    input  wire signed [15:0] v1_y,
    input  wire signed [15:0] v2_x,
    input  wire signed [15:0] v2_y,
    input  wire sign,

    // Initial Packed Attributes at (start_x, start_y)
    input  wire signed [31:0] start_w_inv,
    input  wire signed [31:0] start_s,
    input  wire signed [31:0] start_t,
    input  wire signed [31:0] start_r,
    input  wire signed [31:0] start_g,
    input  wire signed [31:0] start_b,
    input  wire signed [31:0] start_su,
    input  wire signed [31:0] start_sv,
    input  wire signed [31:0] start_sz,

    // Attribute Step Deltas
    input  wire signed [31:0] dw_dx, dw_dy,
    input  wire signed [31:0] ds_dx, ds_dy,
    input  wire signed [31:0] dt_dx, dt_dy,
    input  wire signed [31:0] dr_dx, dr_dy,
    input  wire signed [31:0] dg_dx, dg_dy,
    input  wire signed [31:0] db_dx, db_dy,
    input  wire signed [31:0] dsu_dx, dsu_dy,
    input  wire signed [31:0] dsv_dx, dsv_dy,
    input  wire signed [31:0] dsz_dx, dsz_dy,

    // Texture Memory Interface (Read-Only). tex_shadow selects the shadow map base.
    output reg         tex_req,
    output reg         tex_shadow,
    output reg  [31:0] tex_addr,
    input  wire        tex_ack,
    input  wire [31:0] tex_rdata,

    // Frame Buffer Interface (Write-Only)
    output reg         fb_req,
    output reg  [31:0] fb_addr,
    output reg  [31:0] fb_wdata,
    input  wire        fb_ack,

    // Z-Buffer Interface (Read/Write)
    output reg         zb_req,
    output reg         zb_we,
    output reg  [31:0] zb_addr,
    output reg  [15:0] zb_wdata,
    input  wire        zb_ack,
    input  wire [15:0] zb_rdata
);

    // =========================================================================
    // Pipeline Control & Hazard Detection
    // =========================================================================
    reg p_r1_valid, p_r2_valid, p_r3_valid, p_r4_valid, p_r5_valid;
    reg p_r1_inside, p_r2_inside, p_r3_inside, p_r4_inside;
    // Read data is valid the cycle after the cache acknowledge. The cache
    // BRAM is clocked on the falling edge, so using rdata in the ack cycle
    // is only a half-cycle path through the depth compare and address math.
    reg zb_fresh;
    reg tex_fresh;

    // Stage 5 writes to FB/ZB. Stage 3 issues ZB read.
    wire zb_collision = p_r5_valid && p_r3_valid && p_r3_inside;
    wire zb_read_wait = zb_req && !zb_we && !zb_fresh;
    wire zb_write_wait = zb_req && zb_we && !zb_ack;
    wire tex_wait = tex_req && !tex_fresh;
    wire mem_stall = zb_read_wait || zb_write_wait || tex_wait || (fb_req && !fb_ack);
    wire pipe_stall = mem_stall || zb_collision;

    // Power-of-two viewports (shadow map) address with a shift. The screen
    // size stays the elaborated constant so this does not add a multiplier.
    function automatic [31:0] pixel_addr(input [15:0] px, input [15:0] py);
        reg [31:0] row;
        begin
            case (viewport_width)
                16'd32:   row = {16'd0, py} << 5;
                16'd64:   row = {16'd0, py} << 6;
                16'd128:  row = {16'd0, py} << 7;
                16'd256:  row = {16'd0, py} << 8;
                16'd512:  row = {16'd0, py} << 9;
                16'd1024: row = {16'd0, py} << 10;
                default:  row = {16'd0, py} * FB_WIDTH;
            endcase
            pixel_addr = row + {16'd0, px};
        end
    endfunction

    // 4x4 Bayer thresholds, indexed by {y[1:0], x[1:0]}. Values are 0..15.
    function automatic [3:0] bayer4(input [1:0] x, input [1:0] y);
        case ({y, x})
            4'b0000: bayer4 = 4'd0;
            4'b0001: bayer4 = 4'd8;
            4'b0010: bayer4 = 4'd2;
            4'b0011: bayer4 = 4'd10;
            4'b0100: bayer4 = 4'd12;
            4'b0101: bayer4 = 4'd4;
            4'b0110: bayer4 = 4'd14;
            4'b0111: bayer4 = 4'd6;
            4'b1000: bayer4 = 4'd3;
            4'b1001: bayer4 = 4'd11;
            4'b1010: bayer4 = 4'd1;
            4'b1011: bayer4 = 4'd9;
            4'b1100: bayer4 = 4'd15;
            4'b1101: bayer4 = 4'd7;
            4'b1110: bayer4 = 4'd13;
            default: bayer4 = 4'd5;
        endcase
    endfunction

    wire signed [63:0] mult_res1;
    wire signed [63:0] mult_res2;

    // =========================================================================
    // Edge Setup Combinational Logic
    // =========================================================================
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
    wire signed [15:0] max_x_clip = (max_x_floor >= $signed(viewport_width)) ? ($signed(viewport_width) - 16'sd1) : max_x_floor;

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

    wire [15:0] min_x = min_x_clip;
    wire [15:0] max_x = max_x_clip;
    wire [15:0] max_y = v2_y >>> 4;
    wire [15:0] start_x = min_x_clip;
    wire [15:0] start_y = start_y_clip;

    wire signed [31:0] step_e01_x = sign ? -({{12{dy01[15]}}, dy01, 4'd0}) :  ({{12{dy01[15]}}, dy01, 4'd0});
    wire signed [31:0] step_e01_y = sign ?  ({{12{dx01[15]}}, dx01, 4'd0}) : -({{12{dx01[15]}}, dx01, 4'd0});
    wire signed [31:0] step_e12_x = sign ? -({{12{dy12[15]}}, dy12, 4'd0}) :  ({{12{dy12[15]}}, dy12, 4'd0});
    wire signed [31:0] step_e12_y = sign ?  ({{12{dx12[15]}}, dx12, 4'd0}) : -({{12{dx12[15]}}, dx12, 4'd0});
    wire signed [31:0] step_e20_x = sign ? -({{12{dy20[15]}}, dy20, 4'd0}) :  ({{12{dy20[15]}}, dy20, 4'd0});
    wire signed [31:0] step_e20_y = sign ?  ({{12{dx20[15]}}, dx20, 4'd0}) : -({{12{dx20[15]}}, dx20, 4'd0});

    reg signed [31:0] p0_x_dy, p0_y_dx;
    reg signed [31:0] p1_x_dy, p1_y_dx;
    reg signed [31:0] p2_x_dy, p2_y_dx;

    wire signed [31:0] diff01 = p0_x_dy - p0_y_dx;
    wire signed [31:0] diff12 = p1_x_dy - p1_y_dx;
    wire signed [31:0] diff20 = p2_x_dy - p2_y_dx;
    
    wire signed [31:0] bias01_ext = {{30{bias01[1]}}, bias01};
    wire signed [31:0] bias12_ext = {{30{bias12[1]}}, bias12};
    wire signed [31:0] bias20_ext = {{30{bias20[1]}}, bias20};

    wire signed [31:0] E01_start = sign ? (-diff01 + bias01_ext) : (diff01 + bias01_ext);
    wire signed [31:0] E12_start = sign ? (-diff12 + bias12_ext) : (diff12 + bias12_ext);
    wire signed [31:0] E20_start = sign ? (-diff20 + bias20_ext) : (diff20 + bias20_ext);

    reg setup_active;
    reg [1:0] setup_state;
    wire mult_stall;
    reg shadow_extra;
    wire stall = pipe_stall || mult_stall || shadow_extra;

    // =========================================================================
    // Scanner Registers (boustrophedon scan)
    // =========================================================================
    reg          scan_active;
    reg  [15:0]  scan_x;
    reg  [15:0]  scan_y;
    reg signed [1:0]  scan_dir;
    reg signed [31:0] E01, E12, E20;
    reg signed [31:0] acc_w_inv;
    reg signed [31:0] acc_s, acc_t;
    reg signed [31:0] acc_r, acc_g, acc_b;
    reg signed [31:0] acc_su, acc_sv, acc_sz;
    reg hit_inside_this_row;

    wire scanner_valid  = scan_active && (scan_y <= max_y) && (scan_y < viewport_height);
    wire scanner_inside = scanner_valid && (scan_x >= min_x) && (scan_x <= max_x) &&
                          !E01[31] && !E12[31] && !E20[31];

    wire signed [31:0] next_E01_y = E01 + step_e01_y;
    wire signed [31:0] next_E12_y = E12 + step_e12_y;
    wire signed [31:0] next_E20_y = E20 + step_e20_y;

    wire turn_around = hit_inside_this_row && !scanner_inside;
    wire E01_overtakes = E01[31] && !next_E01_y[31];
    wire E12_overtakes = E12[31] && !next_E12_y[31];
    wire E20_overtakes = E20[31] && !next_E20_y[31];
    wire any_edge_overtakes = E01_overtakes | E12_overtakes | E20_overtakes;
    
    wire smart_turn_around = turn_around && !any_edge_overtakes;

    wire scan_step_down = (scan_dir == 2'sd1  && scan_x >= max_x) ||
                          (scan_dir == -2'sd1 && scan_x <= min_x) ||
                          smart_turn_around;

    wire signed [31:0] scanner_zinv = acc_w_inv >>> 12; 
    wire signed [31:0] scanner_s_w  = acc_s >>> 2;      
    wire signed [31:0] scanner_t_w  = acc_t >>> 2;
    // Color is a 12.20 plane. >>> 4 yields 16.16, which the perspective multiply expects.
    wire signed [31:0] scanner_r_w  = acc_r >>> 4;
    wire signed [31:0] scanner_g_w  = acc_g >>> 4;
    wire signed [31:0] scanner_b_w  = acc_b >>> 4;
    wire signed [31:0] scanner_su_w = acc_su >>> 2;
    wire signed [31:0] scanner_sv_w = acc_sv >>> 2;
    wire signed [31:0] scanner_sz_w = acc_sz >>> 4;

    wire signed [31:0] next_r_down  = acc_r + dr_dy;
    wire signed [31:0] next_g_down  = acc_g + dg_dy;
    wire signed [31:0] next_b_down  = acc_b + db_dy;
    wire signed [31:0] next_r_horiz = acc_r + ((scan_dir == 2'sd1) ? dr_dx : -dr_dx);
    wire signed [31:0] next_g_horiz = acc_g + ((scan_dir == 2'sd1) ? dg_dx : -dg_dx);
    wire signed [31:0] next_b_horiz = acc_b + ((scan_dir == 2'sd1) ? db_dx : -db_dx);
    wire signed [31:0] next_su_down  = acc_su + dsu_dy;
    wire signed [31:0] next_sv_down  = acc_sv + dsv_dy;
    wire signed [31:0] next_sz_down  = acc_sz + dsz_dy;
    wire signed [31:0] next_su_horiz = acc_su + ((scan_dir == 2'sd1) ? dsu_dx : -dsu_dx);
    wire signed [31:0] next_sv_horiz = acc_sv + ((scan_dir == 2'sd1) ? dsv_dx : -dsv_dx);
    wire signed [31:0] next_sz_horiz = acc_sz + ((scan_dir == 2'sd1) ? dsz_dx : -dsz_dx);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            setup_active <= 1'b0;
            setup_state <= 2'd0;
            scan_active <= 1'b0;
            hit_inside_this_row <= 1'b0;
            scan_x      <= 16'd0;
            scan_y      <= 16'd0;
            scan_dir    <= 2'sd1;
            E01 <= 32'd0; E12 <= 32'd0; E20 <= 32'd0;
            acc_w_inv <= 32'd0;
            acc_s <= 32'd0; acc_t <= 32'd0;
            acc_r <= 32'd0; acc_g <= 32'd0; acc_b <= 32'd0;
            acc_su <= 32'd0; acc_sv <= 32'd0; acc_sz <= 32'd0;
            p0_x_dy <= 32'd0; p0_y_dx <= 32'd0;
            p1_x_dy <= 32'd0; p1_y_dx <= 32'd0;
            p2_x_dy <= 32'd0; p2_y_dx <= 32'd0;
        end else if (ce) begin
            if (start && !busy) begin
                setup_active <= 1'b1;
                setup_state <= 2'd0;
                // Capture these early since they don't depend on edge setup
                acc_w_inv <= start_w_inv;
                acc_s <= start_s; acc_t <= start_t;
                acc_r <= start_r; acc_g <= start_g; acc_b <= start_b;
                acc_su <= start_su; acc_sv <= start_sv; acc_sz <= start_sz;
            end else if (setup_active) begin
                if (setup_state == 2'd0) begin
                    p0_x_dy <= mult_res1[31:0];
                    p0_y_dx <= mult_res2[31:0];
                    setup_state <= 2'd1;
                end else if (setup_state == 2'd1) begin
                    p1_x_dy <= mult_res1[31:0];
                    p1_y_dx <= mult_res2[31:0];
                    setup_state <= 2'd2;
                end else if (setup_state == 2'd2) begin
                    p2_x_dy <= mult_res1[31:0];
                    p2_y_dx <= mult_res2[31:0];
                    setup_state <= 2'd3;
                end else if (setup_state == 2'd3) begin
                    setup_active <= 1'b0;
                    scan_active <= 1'b1;
                    hit_inside_this_row <= 1'b0;
                    scan_x      <= start_x;
                    scan_y      <= start_y;
                    scan_dir    <= 2'sd1;
                    E01 <= E01_start; E12 <= E12_start; E20 <= E20_start;
                end
            end else if (scan_active && !stall) begin
                if (scan_y > max_y || scan_y >= viewport_height) begin
                    scan_active <= 1'b0;
                end else if (scan_step_down) begin
                    scan_y   <= scan_y + 1'b1;
                    hit_inside_this_row <= 1'b0;
                    scan_dir <= -scan_dir;
                    E01 <= E01 + step_e01_y;
                    E12 <= E12 + step_e12_y;
                    E20 <= E20 + step_e20_y;
                    acc_w_inv <= acc_w_inv + dw_dy;
                    acc_s <= acc_s + ds_dy;
                    acc_t <= acc_t + dt_dy;
                    acc_r <= next_r_down;
                    acc_g <= next_g_down;
                    acc_b <= next_b_down;
                    acc_su <= next_su_down;
                    acc_sv <= next_sv_down;
                    acc_sz <= next_sz_down;
                    if (scan_y + 1'b1 > max_y || scan_y + 1'b1 >= viewport_height)
                        scan_active <= 1'b0;
                end else begin
                    if (scanner_inside) hit_inside_this_row <= 1'b1;
                    scan_x <= scan_x + ((scan_dir == 2'sd1) ? 16'd1 : -16'd1);
                    E01 <= E01 + ((scan_dir == 2'sd1) ? step_e01_x : -step_e01_x);
                    E12 <= E12 + ((scan_dir == 2'sd1) ? step_e12_x : -step_e12_x);
                    E20 <= E20 + ((scan_dir == 2'sd1) ? step_e20_x : -step_e20_x);
                    acc_w_inv <= acc_w_inv + ((scan_dir == 2'sd1) ? dw_dx : -dw_dx);
                    acc_s <= acc_s + ((scan_dir == 2'sd1) ? ds_dx : -ds_dx);
                    acc_t <= acc_t + ((scan_dir == 2'sd1) ? dt_dx : -dt_dx);
                    acc_r <= next_r_horiz;
                    acc_g <= next_g_horiz;
                    acc_b <= next_b_horiz;
                    acc_su <= next_su_horiz;
                    acc_sv <= next_sv_horiz;
                    acc_sz <= next_sz_horiz;
                end
            end
        end
    end

    // =========================================================================
    // Pipeline Stages 1 to 3
    // =========================================================================
    reg [15:0] p_r1_x, p_r2_x, p_r3_x;
    reg [15:0] p_r1_y, p_r2_y, p_r3_y;
    reg signed [31:0] p_r1_s_w, p_r2_s_w, p_r3_s_w;
    reg signed [31:0] p_r1_t_w, p_r2_t_w, p_r3_t_w;
    reg signed [31:0] p_r1_r_w, p_r2_r_w, p_r3_r_w;
    reg signed [31:0] p_r1_g_w, p_r2_g_w, p_r3_g_w;
    reg signed [31:0] p_r1_b_w, p_r2_b_w, p_r3_b_w;
    reg signed [31:0] p_r1_su_w, p_r2_su_w, p_r3_su_w;
    reg signed [31:0] p_r1_sv_w, p_r2_sv_w, p_r3_sv_w;
    reg signed [31:0] p_r1_sz_w, p_r2_sz_w, p_r3_sz_w;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p_r1_valid <= 1'b0; p_r2_valid <= 1'b0; p_r3_valid <= 1'b0;
        end else if (ce) begin
            if (start && !busy) begin
                p_r1_valid <= 1'b0; p_r2_valid <= 1'b0; p_r3_valid <= 1'b0;
            end else if (!stall) begin
                p_r1_valid  <= scanner_valid;
                p_r1_inside <= scanner_inside;
                p_r1_x      <= scan_x;     p_r1_y      <= scan_y;
                p_r1_s_w    <= scanner_s_w; p_r1_t_w    <= scanner_t_w;
                p_r1_r_w    <= scanner_r_w; p_r1_g_w    <= scanner_g_w; p_r1_b_w    <= scanner_b_w;
                p_r1_su_w   <= scanner_su_w; p_r1_sv_w <= scanner_sv_w; p_r1_sz_w <= scanner_sz_w;

                p_r2_valid  <= p_r1_valid;
                p_r2_inside <= p_r1_inside;
                p_r2_x      <= p_r1_x;     p_r2_y      <= p_r1_y;
                p_r2_s_w    <= p_r1_s_w;   p_r2_t_w    <= p_r1_t_w;
                p_r2_r_w    <= p_r1_r_w;   p_r2_g_w    <= p_r1_g_w;   p_r2_b_w    <= p_r1_b_w;
                p_r2_su_w   <= p_r1_su_w;  p_r2_sv_w <= p_r1_sv_w;   p_r2_sz_w <= p_r1_sz_w;

                p_r3_valid  <= p_r2_valid;
                p_r3_inside <= p_r2_inside;
                p_r3_x      <= p_r2_x;     p_r3_y      <= p_r2_y;
                p_r3_s_w    <= p_r2_s_w;   p_r3_t_w    <= p_r2_t_w;
                p_r3_r_w    <= p_r2_r_w;   p_r3_g_w    <= p_r2_g_w;   p_r3_b_w    <= p_r2_b_w;
                p_r3_su_w   <= p_r2_su_w;  p_r3_sv_w <= p_r2_sv_w;   p_r3_sz_w <= p_r2_sz_w;
            end
        end
    end

    // =========================================================================
    // Perspective Recovery (gated by !stall)
    // =========================================================================
    wire [31:0] w_out;
    reciprocal_lerp u_perspective_recip (
        .clk   (clk),
        .ce    (ce),
        .rst_n (rst_n),
        .stall (stall),
        .z_inv (scanner_zinv),
        .w_out (w_out)
    );

    // =========================================================================
    // Pipeline Stage 4 (Perspective Multiply & Depth Test Setup)
    // =========================================================================
    reg [15:0] p_r4_x, p_r4_y;
    reg signed [31:0] p_r4_s_w, p_r4_t_w, p_r4_r_w, p_r4_g_w, p_r4_b_w;
    reg signed [31:0] p_r4_su_w, p_r4_sv_w, p_r4_sz_w;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p_r4_valid <= 1'b0;
        end else if (ce) begin
            if (start && !busy) begin
                p_r4_valid <= 1'b0;
            end else if (!mem_stall && !mult_stall && !shadow_extra) begin
                if (zb_collision) begin
                    p_r4_valid <= 1'b0;
                end else begin
                    p_r4_valid  <= p_r3_valid;
                    p_r4_inside <= p_r3_inside;
                    p_r4_x      <= p_r3_x;     p_r4_y      <= p_r3_y;
                    p_r4_s_w    <= p_r3_s_w;   p_r4_t_w    <= p_r3_t_w;
                    p_r4_r_w    <= p_r3_r_w;   p_r4_g_w    <= p_r3_g_w;   p_r4_b_w    <= p_r3_b_w;
                    p_r4_su_w   <= p_r3_su_w;  p_r4_sv_w   <= p_r3_sv_w;  p_r4_sz_w   <= p_r3_sz_w;
                end
            end
        end
    end

    // Depth recovery
    reg [15:0] p4_depth_16;
    always @(*) begin
        if (w_out[31])                       p4_depth_16 = 16'h0000;
        else if (w_out[30:16] > 15'd20000)   p4_depth_16 = 16'd20000;
        else                                 p4_depth_16 = w_out[31:16];
    end


    // Latched ZB data for Depth Test. Sampled while the pipeline is held,
    // then used on the following cycle (see zb_fresh).
    reg [15:0] latched_zb_rdata;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            latched_zb_rdata <= 16'h0000;
            zb_fresh <= 1'b0;
        end else if (ce) begin
            if (start && !busy) begin
                zb_fresh <= 1'b0;
            end else if (zb_ack && zb_req && !zb_we) begin
                latched_zb_rdata <= zb_rdata;
                zb_fresh <= 1'b1;
            end else if (!mem_stall) begin
                zb_fresh <= 1'b0;
            end
        end
    end
    wire [15:0] current_zb_depth = latched_zb_rdata;

    // Depth-only draws store interpolated SZ. That path is affine (the ortho
    // shadow pass), so the 16.16 plane is valid without the perspective multiply.
    reg [15:0] sz_depth_affine;
    always @(*) begin
        if (p_r4_sz_w[31])                     sz_depth_affine = 16'h0000;
        else if (p_r4_sz_w[30:16] > 15'd20000) sz_depth_affine = 16'd20000;
        else                                   sz_depth_affine = p_r4_sz_w[31:16];
    end
    // Color draws store a closer depth so a coplanar decal wins against the
    // surface underneath. Depth-only shadow draws keep their own bias.
    wire [15:0] depth_bias_16 = {8'd0, depth_bias};
    wire [15:0] color_depth = (p4_depth_16 > depth_bias_16) ? (p4_depth_16 - depth_bias_16) : 16'd0;
    wire [15:0] test_depth = depth_only ? sz_depth_affine : color_depth;
    wire z_pass = !enable_depth_test || (test_depth < current_zb_depth);

    // =========================================================================
    // Time-multiplexed Multipliers (Stage 4)
    // Unshadowed draws keep the original 3 multiply cycles. Shadowed
    // perspective draws add one cycle: s/t, r/g, b/su, sv/sz.
    // =========================================================================
    reg [2:0] mult_state;
    wire shadow_persp = enable_shadow && enable_perspective_correct;
    wire [2:0] mult_last = shadow_persp ? 3'd4 : 3'd3;
    assign mult_stall = p_r4_valid && p_r4_inside && z_pass && (mult_state != mult_last) && enable_perspective_correct;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mult_state <= 3'd0;
        end else if (ce) begin
            if (start && !busy) begin
                mult_state <= 3'd0;
            end else if (!mem_stall && !shadow_extra) begin
                if (p_r4_valid && p_r4_inside && z_pass && enable_perspective_correct) begin
                    if (mult_state == mult_last) begin
                        mult_state <= 3'd0;
                    end else begin
                        mult_state <= mult_state + 3'd1;
                    end
                end else begin
                    mult_state <= 3'd0;
                end
            end
        end
    end

    reg signed [31:0] mult_op_a1, mult_op_b1;
    reg signed [31:0] mult_op_a2, mult_op_b2;

    always @(*) begin
        if (setup_active) begin
            case (setup_state)
                2'd0: begin
                    mult_op_a1 = {{16{px_minus_v0x[15]}}, px_minus_v0x};
                    mult_op_b1 = {{16{dy01[15]}}, dy01};
                    mult_op_a2 = {{16{py_minus_v0y[15]}}, py_minus_v0y};
                    mult_op_b2 = {{16{dx01[15]}}, dx01};
                end
                2'd1: begin
                    mult_op_a1 = {{16{px_minus_v1x[15]}}, px_minus_v1x};
                    mult_op_b1 = {{16{dy12[15]}}, dy12};
                    mult_op_a2 = {{16{py_minus_v1y[15]}}, py_minus_v1y};
                    mult_op_b2 = {{16{dx12[15]}}, dx12};
                end
                2'd2: begin
                    mult_op_a1 = {{16{px_minus_v2x[15]}}, px_minus_v2x};
                    mult_op_b1 = {{16{dy20[15]}}, dy20};
                    mult_op_a2 = {{16{py_minus_v2y[15]}}, py_minus_v2y};
                    mult_op_b2 = {{16{dx20[15]}}, dx20};
                end
                default: begin
                    mult_op_a1 = 32'd0; mult_op_b1 = 32'd0;
                    mult_op_a2 = 32'd0; mult_op_b2 = 32'd0;
                end
            endcase
        end else begin
            mult_op_b1 = $signed(w_out);
            mult_op_b2 = $signed(w_out);
            case (mult_state)
                3'd0: begin mult_op_a1 = p_r4_s_w;  mult_op_a2 = p_r4_t_w; end
                3'd1: begin mult_op_a1 = p_r4_r_w;  mult_op_a2 = p_r4_g_w; end
                3'd2: begin mult_op_a1 = p_r4_b_w;  mult_op_a2 = enable_shadow ? p_r4_su_w : 32'd0; end
                3'd3: begin mult_op_a1 = p_r4_sv_w; mult_op_a2 = p_r4_sz_w; end
                default: begin mult_op_a1 = 32'd0; mult_op_a2 = 32'd0; end
            endcase
        end
    end

    assign mult_res1 = mult_op_a1 * mult_op_b1;
    assign mult_res2 = mult_op_a2 * mult_op_b2;

    // Affine path bypasses these registers: stage 5 advances the same cycle the
    // pixel reaches stage 4, so a registered sample would lag by one pixel.
    reg signed [31:0] p4_true_u, p4_true_v, p4_true_r, p4_true_g, p4_true_b;
    reg signed [31:0] p4_true_su, p4_true_sv, p4_true_sz;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p4_true_u <= 32'd0; p4_true_v <= 32'd0;
            p4_true_r <= 32'd0; p4_true_g <= 32'd0;
            p4_true_b <= 32'd0;
            p4_true_su <= 32'd0; p4_true_sv <= 32'd0; p4_true_sz <= 32'd0;
        end else if (ce) begin
            if (!mem_stall && !shadow_extra && p_r4_valid && p_r4_inside && z_pass && enable_perspective_correct) begin
                if (mult_state == 3'd0) begin
                    p4_true_u <= mult_res1[55:24];
                    p4_true_v <= mult_res2[55:24];
                end else if (mult_state == 3'd1) begin
                    p4_true_r <= mult_res1[55:24];
                    p4_true_g <= mult_res2[55:24];
                end else if (mult_state == 3'd2) begin
                    p4_true_b <= mult_res1[55:24];
                    if (enable_shadow)
                        p4_true_su <= mult_res2[55:24];
                end else if (mult_state == 3'd3 && enable_shadow) begin
                    p4_true_sv <= mult_res1[55:24];
                    p4_true_sz <= mult_res2[55:24];
                end
            end
        end
    end

    wire signed [31:0] attr_u = enable_perspective_correct ? p4_true_u : p_r4_s_w;
    wire signed [31:0] attr_v = enable_perspective_correct ? p4_true_v : p_r4_t_w;
    wire signed [31:0] attr_r = enable_perspective_correct ? p4_true_r : p_r4_r_w;
    wire signed [31:0] attr_g = enable_perspective_correct ? p4_true_g : p_r4_g_w;
    wire signed [31:0] attr_b = enable_perspective_correct ? p4_true_b : p_r4_b_w;
    wire signed [31:0] attr_su = enable_perspective_correct ? p4_true_su : p_r4_su_w;
    wire signed [31:0] attr_sv = enable_perspective_correct ? p4_true_sv : p_r4_sv_w;
    wire signed [31:0] attr_sz = enable_perspective_correct ? p4_true_sz : p_r4_sz_w;

    wire [7:0] p4_clamped_r = attr_r[31] ? 8'h00 : (|attr_r[30:24] ? 8'hFF : attr_r[23:16]);
    wire [7:0] p4_clamped_g = attr_g[31] ? 8'h00 : (|attr_g[30:24] ? 8'hFF : attr_g[23:16]);
    wire [7:0] p4_clamped_b = attr_b[31] ? 8'h00 : (|attr_b[30:24] ? 8'hFF : attr_b[23:16]);

    wire [11:0] u_int = attr_u[27:16];
    wire [11:0] v_int = attr_v[27:16];

    wire [11:0] u_mask = (12'd1 << (5 + texture_width_scale)) - 12'd1;
    wire [11:0] v_mask = (12'd1 << (5 + texture_height_scale)) - 12'd1;
    
    wire u_negative = attr_u[31];
    wire u_overflow = (attr_u[30:16] > {3'b000, u_mask});
    wire [11:0] u_clamped = u_negative ? 12'd0 : (u_overflow ? u_mask : u_int);
    wire [11:0] u_wrapped = u_int & u_mask;
    wire [11:0] u_final   = clamp_s ? u_clamped : u_wrapped;

    wire v_negative = attr_v[31];
    wire v_overflow = (attr_v[30:16] > {3'b000, v_mask});
    wire [11:0] v_clamped = v_negative ? 12'd0 : (v_overflow ? v_mask : v_int);
    wire [11:0] v_wrapped = v_int & v_mask;
    wire [11:0] v_final   = clamp_t ? v_clamped : v_wrapped;

    // Shift V by the texture width and add U
    wire [23:0] tex_offset = ({12'd0, v_final} << (5 + texture_width_scale)) | {12'd0, u_final};

    wire [31:0] p4_tex_addr = {8'b0, tex_offset};

    wire [11:0] su_int = attr_su[27:16];
    wire [11:0] sv_int = attr_sv[27:16];
    wire [11:0] su_mask = (12'd1 << (5 + shadow_width_scale)) - 12'd1;
    wire [11:0] sv_mask = (12'd1 << (5 + shadow_height_scale)) - 12'd1;
    wire su_outside = attr_su[31] || (attr_su[30:16] > {3'b000, su_mask});
    wire sv_outside = attr_sv[31] || (attr_sv[30:16] > {3'b000, sv_mask});
    wire p4_shadow_inside = enable_shadow && !su_outside && !sv_outside;
    wire [11:0] su_clamped = attr_su[31] ? 12'd0 : (su_outside ? su_mask : su_int);
    wire [11:0] sv_clamped = attr_sv[31] ? 12'd0 : (sv_outside ? sv_mask : sv_int);
    wire [23:0] shadow_offset = ({12'd0, sv_clamped} << (5 + shadow_width_scale)) | {12'd0, su_clamped};
    wire [31:0] p4_shadow_addr = {8'b0, shadow_offset};

    reg [15:0] p4_sz_16;
    always @(*) begin
        if (attr_sz[31])                     p4_sz_16 = 16'h0000;
        else if (attr_sz[30:16] > 15'd20000) p4_sz_16 = 16'd20000;
        else                                 p4_sz_16 = attr_sz[31:16];
    end

    // =========================================================================
    // Pipeline Stage 5 (Early-Z Compare & Texture Fetch)
    // =========================================================================
    reg [15:0] p_r5_x, p_r5_y;
    reg [15:0] p_r5_depth_16;
    reg [7:0]  p_r5_clamped_r, p_r5_clamped_g, p_r5_clamped_b;
    reg        p_r5_shadow_inside;
    reg [15:0] p_r5_sz;
    reg [31:0] p_r5_shadow_addr;
    reg [31:0] albedo_hold;

    wire p4_accept = p_r4_valid && p_r4_inside && z_pass && !mult_stall;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p_r5_valid <= 1'b0;
            tex_req    <= 1'b0;
            tex_shadow <= 1'b0;
            tex_addr   <= 32'd0;
            albedo_hold <= 32'd0;
            shadow_extra <= 1'b0;
        end else if (ce) begin
            if (start && !busy) begin
                p_r5_valid <= 1'b0;
                tex_req    <= 1'b0;
                tex_shadow <= 1'b0;
                shadow_extra <= 1'b0;
            end else if (shadow_extra && !mem_stall) begin
                // Albedo was latched on the previous edge. Hold it and issue the shadow read.
                albedo_hold  <= current_tex_data;
                tex_addr     <= p_r5_shadow_addr;
                tex_shadow   <= 1'b1;
                tex_req      <= 1'b1;
                shadow_extra <= 1'b0;
            end else if (!mem_stall && !shadow_extra) begin
                p_r5_valid     <= p4_accept;
                p_r5_x         <= p_r4_x;
                p_r5_y         <= p_r4_y;
                p_r5_depth_16  <= test_depth;
                p_r5_clamped_r <= p4_clamped_r;
                p_r5_clamped_g <= p4_clamped_g;
                p_r5_clamped_b <= p4_clamped_b;
                p_r5_shadow_inside <= p4_shadow_inside;
                p_r5_sz        <= p4_sz_16;
                p_r5_shadow_addr <= p4_shadow_addr;

                if (p4_accept && !depth_only && enable_shadow && p4_shadow_inside && enable_texture) begin
                    tex_addr     <= p4_tex_addr;
                    tex_shadow   <= 1'b0;
                    tex_req      <= 1'b1;
                    shadow_extra <= 1'b1;
                end else if (p4_accept && !depth_only && enable_shadow && p4_shadow_inside) begin
                    tex_addr   <= p4_shadow_addr;
                    tex_shadow <= 1'b1;
                    tex_req    <= 1'b1;
                    shadow_extra <= 1'b0;
                end else if (p4_accept && !depth_only) begin
                    tex_addr   <= p4_tex_addr;
                    tex_shadow <= 1'b0;
                    tex_req    <= 1'b1;
                    shadow_extra <= 1'b0;
                end else begin
                    tex_req    <= 1'b0;
                    tex_shadow <= 1'b0;
                    shadow_extra <= 1'b0;
                end
            end else if (tex_ack) begin
                tex_req <= 1'b0;
            end
        end
    end

    // Latched texture sample. Visible the cycle after tex_ack (see tex_fresh).
    reg [31:0] latched_tex_rdata;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            latched_tex_rdata <= 32'd0;
            tex_fresh <= 1'b0;
        end else if (ce) begin
            if (start && !busy) begin
                tex_fresh <= 1'b0;
            end else if (tex_ack && tex_req) begin
                latched_tex_rdata <= tex_rdata;
                tex_fresh <= 1'b1;
            end else if (!mem_stall) begin
                tex_fresh <= 1'b0;
            end
        end
    end
    wire [31:0] current_tex_data = latched_tex_rdata;

    // =========================================================================
    // Pipeline Stage 6 (Shade Blending & FB/ZB Write)
    // =========================================================================
    // Textured pixels inside the map latched the albedo on the extra cycle, and
    // the sample visible at the write is the shadow depth. Pixels outside the
    // map fetched albedo directly, so they must not reuse a stale hold.
    wire [31:0] shade_tex = (enable_shadow && enable_texture && p_r5_shadow_inside) ? albedo_hold : current_tex_data;
    wire [15:0] blend_r = ({8'b0, shade_tex[23:16]} * {8'b0, p_r5_clamped_r}) >> 8;
    wire [15:0] blend_g = ({8'b0, shade_tex[15:8]}  * {8'b0, p_r5_clamped_g}) >> 8;
    wire [15:0] blend_b = ({8'b0, shade_tex[7:0]}   * {8'b0, p_r5_clamped_b}) >> 8;

    wire [7:0] lit_r = enable_texture ? blend_r[7:0] : p_r5_clamped_r;
    wire [7:0] lit_g = enable_texture ? blend_g[7:0] : p_r5_clamped_g;
    wire [7:0] lit_b = enable_texture ? blend_b[7:0] : p_r5_clamped_b;
    wire [16:0] sz_biased = {1'b0, p_r5_sz} + {1'b0, shadow_bias};
    wire [15:0] shadow_sample = current_tex_data[15:0];
    wire shadow_hit = enable_shadow && p_r5_shadow_inside && (shadow_sample < 16'd20000) &&
                      (sz_biased > {1'b0, shadow_sample});
    wire [7:0] out_r = shadow_hit ? (lit_r >> 1) : lit_r;
    wire [7:0] out_g = shadow_hit ? (lit_g >> 1) : lit_g;
    wire [7:0] out_b = shadow_hit ? (lit_b >> 1) : lit_b;

    // Ordered dither into the bits RGB565 discards: 3 for R/B, 2 for G.
    wire [3:0] bayer_t = bayer4(p_r5_x[1:0], p_r5_y[1:0]);
    wire [8:0] dither_sum_r = {1'b0, out_r} + {6'b0, bayer_t[3:1]};
    wire [8:0] dither_sum_g = {1'b0, out_g} + {7'b0, bayer_t[3:2]};
    wire [8:0] dither_sum_b = {1'b0, out_b} + {6'b0, bayer_t[3:1]};
    wire [7:0] fb_r = enable_dither ? (dither_sum_r[8] ? 8'hFF : dither_sum_r[7:0]) : out_r;
    wire [7:0] fb_g = enable_dither ? (dither_sum_g[8] ? 8'hFF : dither_sum_g[7:0]) : out_g;
    wire [7:0] fb_b = enable_dither ? (dither_sum_b[8] ? 8'hFF : dither_sum_b[7:0]) : out_b;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fb_req   <= 1'b0;
            fb_addr  <= 32'd0;
            fb_wdata <= 32'd0;
        end else if (ce) begin
            if (!mem_stall) begin
                if (p_r5_valid && !shadow_extra && !depth_only) begin
                    fb_addr  <= pixel_addr(p_r5_x, p_r5_y);
                    fb_wdata <= {8'b0, fb_r, fb_g, fb_b};
                    fb_req   <= 1'b1;
                end else begin
                    fb_req   <= 1'b0;
                end
            end else if (fb_ack) begin
                fb_req <= 1'b0;
            end
        end
    end

    // =========================================================================
    // Z-Buffer Shared Port (Reads & Writes)
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            zb_req   <= 1'b0;
            zb_we    <= 1'b0;
            zb_addr  <= 32'd0;
            zb_wdata <= 16'd0;
        end else if (ce) begin
            if (shadow_extra && !mem_stall) begin
                zb_req <= 1'b0;
                zb_we  <= 1'b0;
            end else if (!mem_stall) begin
                if (p_r5_valid && enable_depth_test && !shadow_extra) begin
                    // Stage 6 Write
                    zb_addr  <= pixel_addr(p_r5_x, p_r5_y);
                    zb_wdata <= p_r5_depth_16;
                    zb_we    <= 1'b1;
                    zb_req   <= 1'b1;
                end else if (p_r3_valid && p_r3_inside && !zb_collision && !mult_stall) begin
                    // Stage 3 Read
                    zb_addr  <= pixel_addr(p_r3_x, p_r3_y);
                    zb_wdata <= 16'd0;
                    zb_we    <= 1'b0;
                    zb_req   <= 1'b1;
                end else begin
                    zb_req   <= 1'b0;
                    zb_we    <= 1'b0;
                end
            end else if (zb_ack) begin
                zb_req <= 1'b0;
            end
        end
    end

    // =========================================================================
    // Busy Signal
    // =========================================================================
    assign busy = setup_active || scan_active || p_r1_valid || p_r2_valid || p_r3_valid || p_r4_valid || p_r5_valid || fb_req;

endmodule
