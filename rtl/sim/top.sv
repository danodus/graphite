module top(
    input wire logic clk,
    input wire logic reset_i,

    input wire logic [2:0]  op,

    input wire logic [31:0] a_value_i,
    input wire logic [31:0] b_value_i,
    output logic     [31:0] z_value_o,

    input wire logic        exec_strobe_i,
    output logic            done_strobe_o
    );

    logic [31:0] z_op0, z_op1, z_op2, z_op3, z_op4;
    logic done_op0, done_op1, done_op2, done_op3, done_op4;

    float_to_int float_to_int(
        .clk(clk),
        .reset_i(reset_i),
        .a_value_i(a_value_i),
        .z_value_o(z_op0),
        .exec_strobe_i(op == 0 && exec_strobe_i),
        .done_strobe_o(done_op0)
    );

    int_to_float int_to_float(
        .clk(clk),
        .reset_i(reset_i),
        .a_value_i(a_value_i),
        .z_value_o(z_op1),
        .exec_strobe_i(op == 1 && exec_strobe_i),
        .done_strobe_o(done_op1)
    );

    adder adder(
        .clk(clk),
        .reset_i(reset_i),
        .a_value_i(a_value_i),
        .b_value_i(b_value_i),
        .z_value_o(z_op2),
        .exec_strobe_i(op == 2 && exec_strobe_i),
        .done_strobe_o(done_op2)
    );
    
    multiplier multiplier(
        .clk(clk),
        .reset_i(reset_i),
        .a_value_i(a_value_i),
        .b_value_i(b_value_i),
        .z_value_o(z_op3),
        .exec_strobe_i(op == 3 && exec_strobe_i),
        .done_strobe_o(done_op3)
    );
    
    divider divider(
        .clk(clk),
        .reset_i(reset_i),
        .a_value_i(a_value_i),
        .b_value_i(b_value_i),
        .z_value_o(z_op4),
        .exec_strobe_i(op == 4 && exec_strobe_i),
        .done_strobe_o(done_op4)
    );    

    always_comb begin
        z_value_o = op == 4 ? z_op4 : op == 3 ? z_op3 : op == 2 ? z_op2 : op == 1 ? z_op1 : z_op0;
        done_strobe_o = done_op0 | done_op1 | done_op2 | done_op3 | done_op4;
    end

endmodule