`include "graphite.svh"

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
    output      logic [15:0]                 vram_data_out_o
    );

    enum { WAIT_COMMAND, PROCESS_COMMAND, CLEAR, DRAW_LINE, DRAW_TRIANGLE, DRAW_TRIANGLE2, DRAW_TRIANGLE3, DRAW_TRIANGLE4, DRAW_TRIANGLE5, DRAW_TRIANGLE6, DRAW_TRIANGLE7, DRAW_TRIANGLE8 } state;

    logic signed [11:0] x0, y0, x1, y1, x2, y2;
    logic signed [11:0] x, y;
    logic signed [11:0] x_line, y_line;
    logic        [15:0] color;
    logic signed [31:0] u0, v0, u1, v1, u2, v2;

    //
    // FPU
    //

    /*
    logic [3:0]  fpu_op;
    logic [31:0] fpu_a_value;
    logic [31:0] fpu_b_value;
    logic [31:0] fpu_z_value;
    logic        fpu_exec_strobe;
    logic        fpu_done_strobe;

    fpu fpu(
        .clk(clk),
        .reset_i(reset_i),
        .op_i(fpu_op),
        .a_value_i(fpu_a_value),
        .b_value_i(fpu_b_value),
        .z_value_o(fpu_z_value),

        .exec_strobe_i(fpu_exec_strobe),
        .done_strobe_o(fpu_done_strobe)
    );
    */

    //
    // Edge function
    // z = (c[0] - a[0]) * (b[1] - a[1]) - (c[1] - a[1]) * (b[0] - a[0])
    //

    /*
    logic [31:0] a[2], b[2], c[2];
    logic [31:0] z;
    logic exec_strobe, done_strobe;

    edge_function edge_function(
        .clk(clk),
        .reset_i(reset_i),

        .a_i(a),
        .b_i(b),
        .c_i(c),
        .z_o(z),

        .exec_strobe_i(exec_strobe),
        .done_strobe_o(done_strobe),

        // FPU
        .fpu_op_o(fpu_op),
        .fpu_a_value_o(fpu_a_value),
        .fpu_b_value_o(fpu_b_value),
        .fpu_z_value_i(fpu_z_value),
        .fpu_exec_strobe_o(fpu_exec_strobe),
        .fpu_done_strobe_i(fpu_done_strobe)
    );
    */

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

    logic signed [31:0] vv0[2], vv1[2], vv2[2];
    logic signed [31:0] p[2];
    logic signed [31:0] w0, w1, w2;
    logic signed [31:0] area, inv_area;
    logic signed [31:0] r, g, b, rr, gg, bb;
    
    logic signed [31:0] c0[3];
    logic signed [31:0] c1[3];
    logic signed [31:0] c2[3];
    
    logic signed [11:0] min_x, min_y, max_x, max_y;

    reciprocal area_reciprocal(.x_i(area), .z_o(inv_area));

    function logic signed [31:0] edge_function(logic signed [31:0] a[2], logic signed [31:0] b[2], logic signed [31:0] c[2]);
        edge_function = mul(c[0] - a[0], b[1] - a[1]) - mul(c[1] - a[1], b[0] - a[0]);
    endfunction

    assign vv0 = '{{20'd0, x0} << 16, {20'd0, y0} << 16};
    assign vv1 = '{{20'd0, x1} << 16, {20'd0, y1} << 16};
    assign vv2 = '{{20'd0, x2} << 16, {20'd0, y2} << 16};

    assign c0 = '{u0, v0, 32'd0};
    assign c1 = '{u1, v1, 32'd0};
    assign c2 = '{u2, v2, 32'd0};
    
    assign p = '{{20'd0, x} << 16, {20'd0, y} << 16};

    assign cmd_axis_tready_o = state == WAIT_COMMAND;

    always_ff @(posedge clk) begin

        case (state)
            WAIT_COMMAND: begin
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
                        $display("Clear opcode received");
                        vram_addr_o     <= 16'h0;
                        vram_data_out_o <= color;
                        vram_mask_o     <= 4'hF;
                        vram_sel_o      <= 1'b1;
                        vram_wr_o       <= 1'b1;
                        state           <= CLEAR;
                    end
                    OP_DRAW_LINE: begin
                        $display("Draw line opcode received");
                        start_line      <= 1;
                        state           <= DRAW_LINE;
                    end
                    OP_DRAW_TRIANGLE: begin
                        $display("Draw triangle opcode received");
                        vram_addr_o     <= 16'h0;
                        vram_data_out_o <= color;
                        vram_mask_o     <= 4'hF;
                        min_x <= max(min3(x0, x1, x2), 0);
                        min_y <= max(min3(y0, y1, y2), 0);
                        max_x <= min(max3(x0, x1, x2), FB_WIDTH - 1);
                        max_y <= min(max3(y0, y1, y2), FB_HEIGHT - 1);
                        area  <= edge_function(vv0, vv1, vv2);
                        state           <= DRAW_TRIANGLE;
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
                x <= min_x;
                y <= min_y;
                vram_addr_o <= vram_addr_o + {4'd0, min_y} * FB_WIDTH + {4'd0, min_x};
                state <= DRAW_TRIANGLE2;
            end

            DRAW_TRIANGLE2: begin
                w0 <= edge_function(vv1, vv2, p);
                w1 <= edge_function(vv2, vv0, p);
                w2 <= edge_function(vv0, vv1, p);

                state <= DRAW_TRIANGLE3;
            end

            DRAW_TRIANGLE3: begin
                if (w0 >= 0 && w1 >= 0 && w2 >= 0 && inv_area > 0) begin
                    w0 <= rmul(w0, inv_area);
                    w1 <= rmul(w1, inv_area);
                    w2 <= rmul(w2, inv_area);
                    state <= DRAW_TRIANGLE4;
                end else begin
                    state <= DRAW_TRIANGLE7;
                end
            end

            DRAW_TRIANGLE4: begin
                r <= mul(w0, c0[0]) + mul(w1, c1[0]) + mul(w2, c2[0]);
                g <= mul(w0, c0[1]) + mul(w1, c1[1]) + mul(w2, c2[1]);
                b <= mul(w0, c0[2]) + mul(w1, c1[2]) + mul(w2, c2[2]);
                state <= DRAW_TRIANGLE5;
            end

            DRAW_TRIANGLE5: begin
                rr <= mul(r, 32'd15 << 16) >> 16;
                gg <= mul(g, 32'd15 << 16) >> 16;
                bb <= mul(b, 32'd15 << 16) >> 16;
                state <= DRAW_TRIANGLE6;
            end

            DRAW_TRIANGLE6: begin
                vram_data_out_o <= {4'hF, rr[3:0], gg[3:0], bb[3:0]};
                vram_sel_o      <= 1'b1;
                vram_wr_o       <= 1'b1;
                state <= DRAW_TRIANGLE7;
            end

            DRAW_TRIANGLE7: begin
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

                state <= DRAW_TRIANGLE8;
            end

            DRAW_TRIANGLE8: begin
                if (y >= max_y) begin
                    state       <= WAIT_COMMAND;
                end else begin
                    state       <= DRAW_TRIANGLE2;
                end
            end

        endcase

        if (reset_i) begin
            vram_sel_o        <= 1'b0;
            start_line        <= 1'b0;
            state             <= WAIT_COMMAND;
        end
    end

    always_ff @(posedge clk) begin

        if (start_line)
            start_line <= 1'b0;

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

        
    end

endmodule

