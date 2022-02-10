`timescale 1ns/1ps

module edge_function_tb;

    localparam FP_0_0  = 32'h00000000;
    localparam FP_0_25 = 32'h3e800000;
    localparam FP_0_5  = 32'h3f000000;
    localparam FP_1_0  = 32'h3f800000;

    logic clk = 0;
    logic reset;
    logic [31:0] a[2], b[2], c[2];
    logic [31:0] z;
    logic exec_strobe, done_strobe;

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

    edge_function UUT(
        .clk(clk),
        .reset_i(reset),

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

    initial begin

        $dumpfile("edge_function_tb.vcd");
        $dumpvars(0, UUT);

        reset = 1'b1;

        // z = (c[0] - a[0]) * (b[1] - a[1]) - (c[1] - a[1]) * (b[0] - a[0])
        a[0] = FP_0_0;
        a[1] = FP_0_5;
        b[0] = FP_0_5;
        b[1] = FP_0_0;
        c[0] = FP_0_0;
        c[1] = FP_0_0;

        exec_strobe = 1'b0;

        #20
        reset = 1'b0;
        #40
        exec_strobe = 1'b1;

        #1000000
        $finish;
    end

    always #5 clk = !clk;

    always @(posedge clk) begin
        if (done_strobe) begin
            $display("%t, z=%x", $time, z);
            assert (z == FP_0_25)
                $display ("OK");
            else
                $error("Wrong result");
            $finish;
        end
    end


endmodule