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

    enum { WAIT_COMMAND, PROCESS_COMMAND, CLEAR, DRAW } state;

    logic signed [11:0] x0, y0, x1, y1;
    logic signed [11:0] x, y;
    logic signed [11:0] x_line, y_line;
    logic        [15:0] color;

    //
    // FPU
    //

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

    //
    // Edge function
    // z = (c[0] - a[0]) * (b[1] - a[1]) - (c[1] - a[1]) * (b[0] - a[0])
    //

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

    assign cmd_axis_tready_o = state == WAIT_COMMAND;

    always_ff @(posedge clk) begin

        case (state)
            WAIT_COMMAND: begin
                if (cmd_axis_tvalid_i)
                    state <= PROCESS_COMMAND;
            end

            PROCESS_COMMAND: begin
                case (cmd_axis_tdata_i[OP_POS+:OP_SIZE])
                    OP_NOP: begin
                        $display("NOP opcode received");
                        state <= WAIT_COMMAND;
                    end
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
                        state           <= DRAW;
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

            DRAW: begin
                if (done_line) begin
                    vram_sel_o      <= 1'b0;
                    vram_wr_o       <= 1'b0;
                    state           <= WAIT_COMMAND;
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
            if (x_line < FB_WIDTH && y_line < FB_HEIGHT) begin
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

