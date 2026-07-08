// graphite_rasterizer.v
// Copyright (c) 2021-2026 Daniel Cliche
// SPDX-License-Identifier: MIT

module graphite_rasterizer #(
    parameter FB_WIDTH = 640
) (
    input  wire         clk,
    input  wire         ce,
    input  wire         rst_n,

    // Control
    input  wire         start,
    input  wire         enable_texture,
    input  wire         enable_depth_test,
    input  wire         clamp_s,
    input  wire         clamp_t,
    input  wire [2:0]   texture_width_scale,
    input  wire [2:0]   texture_height_scale,
    output wire         busy,

    // Bounding Box
    input  wire [15:0]  min_x,
    input  wire [15:0]  max_x,
    input  wire [15:0]  max_y,
    input  wire [15:0]  start_x,
    input  wire [15:0]  start_y,

    // Edge Equations Initial Values
    input  wire signed [31:0] E01_start,
    input  wire signed [31:0] E12_start,
    input  wire signed [31:0] E20_start,

    // Edge Step Deltas
    input  wire signed [31:0] step_e01_x,
    input  wire signed [31:0] step_e01_y,
    input  wire signed [31:0] step_e12_x,
    input  wire signed [31:0] step_e12_y,
    input  wire signed [31:0] step_e20_x,
    input  wire signed [31:0] step_e20_y,

    // Initial Packed Attributes at (start_x, start_y)
    input  wire signed [31:0] start_w_inv,
    input  wire signed [31:0] start_s,
    input  wire signed [31:0] start_t,
    input  wire signed [31:0] start_r,
    input  wire signed [31:0] start_g,
    input  wire signed [31:0] start_b,

    // Attribute Step Deltas
    input  wire signed [31:0] dw_dx, dw_dy,
    input  wire signed [31:0] ds_dx, ds_dy,
    input  wire signed [31:0] dt_dx, dt_dy,
    input  wire signed [31:0] dr_dx, dr_dy,
    input  wire signed [31:0] dg_dx, dg_dy,
    input  wire signed [31:0] db_dx, db_dy,

    // Texture Memory Interface (Read-Only)
    output reg         tex_req,
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
    
    // Stage 5 writes to FB/ZB. Stage 3 issues ZB read.
    wire zb_collision = p_r5_valid && p_r3_valid && p_r3_inside;
    wire mem_stall = (zb_req && !zb_ack) || (tex_req && !tex_ack) || (fb_req && !fb_ack);
    wire pipe_stall = mem_stall || zb_collision;
    wire mult_stall;
    wire stall = pipe_stall || mult_stall;

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
    reg hit_inside_this_row;

    wire scanner_valid  = scan_active && (scan_y <= max_y) && (scan_y < 16'd480);
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

    wire signed [31:0] scanner_zinv = acc_w_inv >>> 14; 
    wire signed [31:0] scanner_s_w  = acc_s >>> 2;      
    wire signed [31:0] scanner_t_w  = acc_t >>> 2;
    wire signed [31:0] scanner_r_w  = acc_r <<< 4;      
    wire signed [31:0] scanner_g_w  = acc_g <<< 4;
    wire signed [31:0] scanner_b_w  = acc_b <<< 4;

    wire signed [31:0] next_r_down  = acc_r + dr_dy;
    wire signed [31:0] next_g_down  = acc_g + dg_dy;
    wire signed [31:0] next_b_down  = acc_b + db_dy;
    wire signed [31:0] next_r_horiz = acc_r + ((scan_dir == 2'sd1) ? dr_dx : -dr_dx);
    wire signed [31:0] next_g_horiz = acc_g + ((scan_dir == 2'sd1) ? dg_dx : -dg_dx);
    wire signed [31:0] next_b_horiz = acc_b + ((scan_dir == 2'sd1) ? db_dx : -db_dx);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scan_active <= 1'b0;
            hit_inside_this_row <= 1'b0;
            scan_x      <= 16'd0;
            scan_y      <= 16'd0;
            scan_dir    <= 2'sd1;
            E01 <= 32'd0; E12 <= 32'd0; E20 <= 32'd0;
            acc_w_inv <= 32'd0;
            acc_s <= 32'd0; acc_t <= 32'd0;
            acc_r <= 32'd0; acc_g <= 32'd0; acc_b <= 32'd0;
        end else if (ce) begin
            if (start && !busy) begin
                scan_active <= 1'b1;
                hit_inside_this_row <= 1'b0;
                scan_x      <= start_x;
                scan_y      <= start_y;
                scan_dir    <= 2'sd1;
                E01 <= E01_start; E12 <= E12_start; E20 <= E20_start;
                acc_w_inv <= start_w_inv;
                acc_s <= start_s; acc_t <= start_t;
                acc_r <= start_r; acc_g <= start_g; acc_b <= start_b;
            end else if (scan_active && !stall) begin
                if (scan_y > max_y || scan_y >= 16'd480) begin
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
                    acc_r <= {{8{next_r_down[23]}}, next_r_down[23:0]};
                    acc_g <= {{8{next_g_down[23]}}, next_g_down[23:0]};
                    acc_b <= {{8{next_b_down[23]}}, next_b_down[23:0]};
                    if (scan_y + 1'b1 > max_y || scan_y + 1'b1 >= 16'd480)
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
                    acc_r <= {{8{next_r_horiz[23]}}, next_r_horiz[23:0]};
                    acc_g <= {{8{next_g_horiz[23]}}, next_g_horiz[23:0]};
                    acc_b <= {{8{next_b_horiz[23]}}, next_b_horiz[23:0]};
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

                p_r2_valid  <= p_r1_valid;
                p_r2_inside <= p_r1_inside;
                p_r2_x      <= p_r1_x;     p_r2_y      <= p_r1_y;
                p_r2_s_w    <= p_r1_s_w;   p_r2_t_w    <= p_r1_t_w;
                p_r2_r_w    <= p_r1_r_w;   p_r2_g_w    <= p_r1_g_w;   p_r2_b_w    <= p_r1_b_w;

                p_r3_valid  <= p_r2_valid;
                p_r3_inside <= p_r2_inside;
                p_r3_x      <= p_r2_x;     p_r3_y      <= p_r2_y;
                p_r3_s_w    <= p_r2_s_w;   p_r3_t_w    <= p_r2_t_w;
                p_r3_r_w    <= p_r2_r_w;   p_r3_g_w    <= p_r2_g_w;   p_r3_b_w    <= p_r2_b_w;
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

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p_r4_valid <= 1'b0;
        end else if (ce) begin
            if (start && !busy) begin
                p_r4_valid <= 1'b0;
            end else if (!mem_stall && !mult_stall) begin
                if (zb_collision) begin
                    p_r4_valid <= 1'b0;
                end else begin
                    p_r4_valid  <= p_r3_valid;
                    p_r4_inside <= p_r3_inside;
                    p_r4_x      <= p_r3_x;     p_r4_y      <= p_r3_y;
                    p_r4_s_w    <= p_r3_s_w;   p_r4_t_w    <= p_r3_t_w;
                    p_r4_r_w    <= p_r3_r_w;   p_r4_g_w    <= p_r3_g_w;   p_r4_b_w    <= p_r3_b_w;
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


    // Latched ZB data for Depth Test
    reg [15:0] latched_zb_rdata;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            latched_zb_rdata <= 16'h0000;
        end else if (ce) begin
            if (zb_ack && !zb_we) begin
                latched_zb_rdata <= zb_rdata;
            end
        end
    end
    wire [15:0] current_zb_depth = (zb_ack && !zb_we) ? zb_rdata : latched_zb_rdata;
    wire z_pass = !enable_depth_test || (p4_depth_16 < current_zb_depth);

    // =========================================================================
    // Time-multiplexed Multipliers (Stage 4)
    // =========================================================================
    reg [1:0] mult_state;
    assign mult_stall = p_r4_valid && p_r4_inside && z_pass && (mult_state != 2'd3);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mult_state <= 2'd0;
        end else if (ce) begin
            if (start && !busy) begin
                mult_state <= 2'd0;
            end else if (!mem_stall) begin
                if (p_r4_valid && p_r4_inside && z_pass) begin
                    if (mult_state == 2'd3) begin
                        mult_state <= 2'd0;
                    end else begin
                        mult_state <= mult_state + 1'b1;
                    end
                end else begin
                    mult_state <= 2'd0;
                end
            end
        end
    end

    reg signed [31:0] mult_op_a1, mult_op_a2;
    always @(*) begin
        case (mult_state)
            2'd0: begin mult_op_a1 = p_r4_s_w; mult_op_a2 = p_r4_t_w; end
            2'd1: begin mult_op_a1 = p_r4_r_w; mult_op_a2 = p_r4_g_w; end
            2'd2: begin mult_op_a1 = p_r4_b_w; mult_op_a2 = 32'd0;    end
            default: begin mult_op_a1 = 32'd0; mult_op_a2 = 32'd0;    end
        endcase
    end

    wire signed [63:0] mult_res1 = mult_op_a1 * $signed(w_out);
    wire signed [63:0] mult_res2 = mult_op_a2 * $signed(w_out);

    reg signed [31:0] p4_true_u, p4_true_v, p4_true_r, p4_true_g, p4_true_b;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p4_true_u <= 32'd0; p4_true_v <= 32'd0;
            p4_true_r <= 32'd0; p4_true_g <= 32'd0;
            p4_true_b <= 32'd0;
        end else if (ce) begin
            if (!mem_stall && p_r4_valid && p_r4_inside && z_pass) begin
                if (mult_state == 2'd0) begin
                    p4_true_u <= mult_res1[55:24];
                    p4_true_v <= mult_res2[55:24];
                end else if (mult_state == 2'd1) begin
                    p4_true_r <= mult_res1[55:24];
                    p4_true_g <= mult_res2[55:24];
                end else if (mult_state == 2'd2) begin
                    p4_true_b <= mult_res1[55:24];
                end
            end
        end
    end

    wire [7:0] p4_clamped_r = p4_true_r[31] ? 8'h00 : (|p4_true_r[30:24] ? 8'hFF : p4_true_r[23:16]);
    wire [7:0] p4_clamped_g = p4_true_g[31] ? 8'h00 : (|p4_true_g[30:24] ? 8'hFF : p4_true_g[23:16]);
    wire [7:0] p4_clamped_b = p4_true_b[31] ? 8'h00 : (|p4_true_b[30:24] ? 8'hFF : p4_true_b[23:16]);

    wire [11:0] u_int = p4_true_u[27:16];
    wire [11:0] v_int = p4_true_v[27:16];

    wire [11:0] u_mask = (12'd1 << (5 + texture_width_scale)) - 12'd1;
    wire [11:0] v_mask = (12'd1 << (5 + texture_height_scale)) - 12'd1;
    
    wire u_negative = p4_true_u[31];
    wire u_overflow = (p4_true_u[30:16] > {3'b000, u_mask});
    wire [11:0] u_clamped = u_negative ? 12'd0 : (u_overflow ? u_mask : u_int);
    wire [11:0] u_wrapped = u_int & u_mask;
    wire [11:0] u_final   = clamp_s ? u_clamped : u_wrapped;

    wire v_negative = p4_true_v[31];
    wire v_overflow = (p4_true_v[30:16] > {3'b000, v_mask});
    wire [11:0] v_clamped = v_negative ? 12'd0 : (v_overflow ? v_mask : v_int);
    wire [11:0] v_wrapped = v_int & v_mask;
    wire [11:0] v_final   = clamp_t ? v_clamped : v_wrapped;

    // Shift V by the texture width and add U
    wire [23:0] tex_offset = ({12'd0, v_final} << (5 + texture_width_scale)) | {12'd0, u_final};

    wire [31:0] p4_tex_addr = {8'b0, tex_offset};



    // =========================================================================
    // Pipeline Stage 5 (Early-Z Compare & Texture Fetch)
    // =========================================================================
    reg [15:0] p_r5_x, p_r5_y;
    reg [15:0] p_r5_depth_16;
    reg [7:0]  p_r5_clamped_r, p_r5_clamped_g, p_r5_clamped_b;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p_r5_valid <= 1'b0;
            tex_req    <= 1'b0;
            tex_addr   <= 32'd0;
        end else if (ce) begin
            if (start && !busy) begin
                p_r5_valid <= 1'b0;
            end else begin
                if (!mem_stall) begin
                    p_r5_valid     <= p_r4_valid && p_r4_inside && z_pass && !mult_stall;
                    p_r5_x         <= p_r4_x;
                    p_r5_y         <= p_r4_y;
                    p_r5_depth_16  <= p4_depth_16;
                    p_r5_clamped_r <= p4_clamped_r;
                    p_r5_clamped_g <= p4_clamped_g;
                    p_r5_clamped_b <= p4_clamped_b;

                    if (p_r4_valid && p_r4_inside && z_pass && !mult_stall) begin
                        tex_addr <= p4_tex_addr;
                        tex_req  <= 1'b1;
                    end else begin
                        tex_req  <= 1'b0;
                    end
                end else if (tex_ack) begin
                    tex_req <= 1'b0;
                end
            end
        end
    end

    // Latched Texture data for Blend
    reg [31:0] latched_tex_rdata;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            latched_tex_rdata <= 32'd0;
        end else if (ce) begin
            if (tex_ack) begin
                latched_tex_rdata <= tex_rdata;
            end
        end
    end
    wire [31:0] current_tex_data = tex_ack ? tex_rdata : latched_tex_rdata;

    // =========================================================================
    // Pipeline Stage 6 (Shade Blending & FB/ZB Write)
    // =========================================================================
    wire [15:0] blend_r = ({8'b0, current_tex_data[23:16]} * {8'b0, p_r5_clamped_r}) >> 8;
    wire [15:0] blend_g = ({8'b0, current_tex_data[15:8]}  * {8'b0, p_r5_clamped_g}) >> 8;
    wire [15:0] blend_b = ({8'b0, current_tex_data[7:0]}   * {8'b0, p_r5_clamped_b}) >> 8;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fb_req   <= 1'b0;
            fb_addr  <= 32'd0;
            fb_wdata <= 32'd0;
        end else if (ce) begin
            if (!mem_stall) begin
                if (p_r5_valid) begin
                    fb_addr  <= ({16'b0, p_r5_y} * FB_WIDTH) + {16'b0, p_r5_x};
                    fb_wdata <= enable_texture ? {8'b0, blend_r[7:0], blend_g[7:0], blend_b[7:0]}
                                               : {8'b0, p_r5_clamped_r, p_r5_clamped_g, p_r5_clamped_b};
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
            if (!mem_stall) begin
                if (p_r5_valid && enable_depth_test) begin
                    // Stage 6 Write
                    zb_addr  <= ({16'b0, p_r5_y} * FB_WIDTH) + {16'b0, p_r5_x};
                    zb_wdata <= p_r5_depth_16;
                    zb_we    <= 1'b1;
                    zb_req   <= 1'b1;
                end else if (p_r3_valid && p_r3_inside && !zb_collision && !mult_stall) begin
                    // Stage 3 Read
                    zb_addr  <= ({16'b0, p_r3_y} * FB_WIDTH) + {16'b0, p_r3_x};
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
    assign busy = scan_active || p_r1_valid || p_r2_valid || p_r3_valid || p_r4_valid || p_r5_valid || fb_req;

endmodule
