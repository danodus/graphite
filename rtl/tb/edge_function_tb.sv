`timescale 1ns/1ps

module edge_function_tb;

    logic clk = 0;
    logic reset;
    logic [31:0] a[2], b[2], c[2];
    logic [31:0] z;
    logic exec_strobe, done_strobe;

    edge_function UUT(
        .clk(clk),
        .reset_i(reset),

        .a_i(a),
        .b_i(b),
        .c_i(c),
        .z_o(z),

        .exec_strobe_i(exec_strobe),
        .done_strobe_o(done_strobe)
    );

    initial begin

        $dumpfile("edge_function_tb.vcd");
        $dumpvars(0, UUT);

        reset = 1'b1;

        // z = (c[0] - a[0]) * (b[1] - a[1]) - (c[1] - a[1]) * (b[0] - a[0])
        a[0] = 32'h00000000;      // 0.0f
        a[1] = 32'h00000000;      // 0.0f
        b[0] = 32'h3f800000;      // 1.0f
        b[1] = 32'h3f800000;      // 1.0f
        c[0] = 32'h3f800000;      // 1.0f
        c[1] = 32'h3f800000;      // 1.0f

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
            $finish;
        end
    end


endmodule;