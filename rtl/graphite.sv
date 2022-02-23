`include "graphite.svh"

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
    parameter CMD_STREAM_WIDTH = 16
    ) (
    input  wire logic                        clk,
    input  wire logic                        reset_i,

    // AXI stream command interface (slave)
    input  wire logic                        cmd_axis_tvalid_i,
    output      logic                        cmd_axis_tready_o,
    input  wire logic [CMD_STREAM_WIDTH-1:0] cmd_axis_tdata_i,

    // VRAM write
    //input  wire logic                        vram_ack_i,
    output      logic                        vram_sel_o,
    output      logic                        vram_wr_o,
    output      logic  [3:0]                 vram_mask_o,
    output      logic [15:0]                 vram_addr_o,
    output      logic [15:0]                 vram_data_out_o,

    output      logic                        swap_o
    );

    enum { WAIT_COMMAND, PROCESS_COMMAND, CLEAR, DRAW_LINE,
           DRAW_TRIANGLE, DRAW_TRIANGLEB, DRAW_TRIANGLEC, DRAW_TRIANGLED, DRAW_TRIANGLEE,
           DRAW_TRIANGLE2,
           DRAW_TRIANGLE3, DRAW_TRIANGLE3B, DRAW_TRIANGLE3C, DRAW_TRIANGLE3D, DRAW_TRIANGLE3E, DRAW_TRIANGLE3F, DRAW_TRIANGLE3G, DRAW_TRIANGLE3H, DRAW_TRIANGLE3I, DRAW_TRIANGLE3J,
           DRAW_TRIANGLE4, DRAW_TRIANGLE4B, DRAW_TRIANGLE4C, DRAW_TRIANGLE4D, DRAW_TRIANGLE4E, DRAW_TRIANGLE4F, DRAW_TRIANGLE4G, DRAW_TRIANGLE4H, DRAW_TRIANGLE4I, DRAW_TRIANGLE4J, DRAW_TRIANGLE4K, DRAW_TRIANGLE4L,
           DRAW_TRIANGLE5, DRAW_TRIANGLE6, DRAW_TRIANGLE7, DRAW_TRIANGLE8, DRAW_TRIANGLE9
    } state;

    logic signed [11:0] x0, y0, x1, y1, x2, y2;
    logic signed [11:0] x, y;
    logic signed [11:0] x_line, y_line;
    logic        [15:0] color;
    logic signed [31:0] u0, v0, u1, v1, u2, v2;

    //
    // Draw line
    //

    logic start_line;
    logic drawing_line;
    logic busy_line;
    logic done_line;

    logic wait_vram_ack = 1'b0;

    draw_line #(.CORDW(12)) draw_line (    // framebuffer coord width in bits
        .clk(clk),                         // clock
        .reset_i(reset_i),                 // reset
        .start_i(start_line),              // start line rendering
        .oe_i(!wait_vram_ack),             // output enable
        .x0_i(x0),                         // point 0 - horizontal position
        .y0_i(y0),                         // point 0 - vertical position
        .x1_i(x1),                         // point 1 - horizontal position
        .y1_i(y1),                         // point 1 - vertical position
        .x_o(x_line),                      // horizontal drawing position
        .y_o(y_line),                      // vertical drawing position
        .drawing_o(drawing_line),          // line is drawing
        .busy_o(busy_line),                // line drawing request in progress
        .done_o(done_line)                 // line complete (high for one tick)
    );

    //
    // Draw triangle
    //

    logic signed [31:0] vv00, vv01, vv10, vv11, vv20, vv21;
    logic signed [31:0] p0, p1;
    logic signed [31:0] w0, w1, w2;
    logic signed [31:0] area, inv_area;
    logic signed [31:0] r, g, b;

    logic [11:0] tex_sample;
    
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

    reciprocal area_reciprocal(.clk(clk), .x_i(area), .z_o(inv_area));

    //function logic signed [31:0] edge_function(logic signed [31:0] a0, logic signed [31:0] a1, logic signed [31:0] b0, logic signed [31:0] b1, logic signed [31:0] c0, logic signed [31:0] c1);
    //    edge_function = mul(c0 - a0, b1 - a1) - mul(c1 - a1, b0 - a0);
    //endfunction


    function logic [11:0] get_texture_sample(logic signed [31:0] u, logic signed [31:0] v);
        if (u < (32768) && v < (32768)) get_texture_sample = 12'hF00;
        else if (u >= (32768) && v < (32768)) get_texture_sample = 12'h0F0;
        else if (u < (32768) && v >= (32768)) get_texture_sample = 12'h00F;
        else get_texture_sample = 12'hFF0;
    endfunction

    assign vv00 = {{20{x0[11]}}, x0} << 16;
    assign vv01 = {{20{y0[11]}}, y0} << 16;
    assign vv10 = {{20{x1[11]}}, x1} << 16;
    assign vv11 = {{20{y1[11]}}, y1} << 16;
    assign vv20 = {{20{x2[11]}}, x2} << 16;
    assign vv21 = {{20{y2[11]}}, y2} << 16;

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
                if (cmd_axis_tvalid_i)
                    state <= PROCESS_COMMAND;
            end

            PROCESS_COMMAND: begin
                case (cmd_axis_tdata_i[OP_POS+:OP_SIZE])
                    OP_SET_X0: begin
                        x0 <= cmd_axis_tdata_i[11:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_Y0: begin
                        y0 <= cmd_axis_tdata_i[11:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_X1: begin
                        x1 <= cmd_axis_tdata_i[11:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_Y1: begin
                        y1 <= cmd_axis_tdata_i[11:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_X2: begin
                        x2 <= cmd_axis_tdata_i[11:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_Y2: begin
                        y2 <= cmd_axis_tdata_i[11:0];
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_U0: begin
                        u0 <= {15'b0, cmd_axis_tdata_i[11:0], 5'b0};
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_V0: begin
                        v0 <= {15'b0, cmd_axis_tdata_i[11:0], 5'b0};
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_U1: begin
                        u1 <= {15'b0, cmd_axis_tdata_i[11:0], 5'b0};
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_V1: begin
                        v1 <= {15'b0, cmd_axis_tdata_i[11:0], 5'b0};
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_U2: begin
                        u2 <= {15'b0, cmd_axis_tdata_i[11:0], 5'b0};
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_V2: begin
                        v2 <= {15'b0, cmd_axis_tdata_i[11:0], 5'b0};
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_COLOR: begin
                        color <= {4'hF, cmd_axis_tdata_i[OP_POS - 1:0]};
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
                        if (cmd_axis_tdata_i[11:0] == 0) begin
                            // Draw line
                            start_line      <= 1;
                            state           <= DRAW_LINE;
                        end else begin
                            // Draw triangle
                            vram_addr_o     <= 16'h0;
                            vram_data_out_o <= color;
                            vram_mask_o     <= 4'hF;
                            min_x <= min3(x0, x1, x2);
                            min_y <= min3(y0, y1, y2);
                            max_x <= max3(x0, x1, x2);
                            max_y <= max3(y0, y1, y2);
                            state <= DRAW_TRIANGLE;
                        end
                    end
                    OP_SWAP: begin
                        swap_o <= 1'b1;
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
                area = t0 - t1;
                state <= DRAW_TRIANGLE2;
            end

            DRAW_TRIANGLE2: begin
                x <= min_x;
                y <= min_y;
                vram_addr_o <= vram_addr_o + {4'd0, min_y} * FB_WIDTH + {4'd0, min_x};
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
                    //state <= DRAW_TRIANGLE7;
                    // w0 = rmul(w0, inv_area)
                    dsp_rmul_p0 <= w0;
                    dsp_rmul_p1 <= inv_area;
                    state <= DRAW_TRIANGLE4B;
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
                state <= DRAW_TRIANGLE6;
            end

            DRAW_TRIANGLE5: begin
            end

            DRAW_TRIANGLE6: begin
                tex_sample = get_texture_sample(r, g);
                state <= DRAW_TRIANGLE7;
            end

            DRAW_TRIANGLE7: begin
                //vram_data_out_o <= {16'hFFFF};
                vram_data_out_o <= {4'hF, tex_sample[11:8], tex_sample[7:4], tex_sample[3:0]};
                vram_sel_o      <= 1'b1;
                vram_wr_o       <= 1'b1;
                state <= DRAW_TRIANGLE8;
            end

            DRAW_TRIANGLE8: begin
                vram_sel_o <= 1'b0;
                vram_wr_o  <= 1'b0;

                if (x < max_x) begin
                    x <= x + 1;
                    vram_addr_o <= vram_addr_o + 1;
                end else begin
                    x <= min_x;
                    y <= y + 1;
                    vram_addr_o <= vram_addr_o + {4'd0, (FB_WIDTH[11:0] - max_x) + min_x};
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
            state             <= WAIT_COMMAND;
        end
    end

endmodule

