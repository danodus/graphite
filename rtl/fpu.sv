`include "graphite.svh"

module fpu(
    input wire logic clk,
    input wire logic reset_i,

    input wire logic [3:0]  op_i,       // 

    input wire logic [31:0] a_value_i,
    input wire logic [31:0] b_value_i,
    output logic     [31:0] z_value_o,

    input wire logic        exec_strobe_i,
    output logic            done_strobe_o
    );

    // int to float

    logic        int_to_float_done_strobe;
    logic [31:0] int_to_float_z_value;

    int_to_float int_to_float(
        .clk(clk),
        .reset_i(reset_i),

        .a_value_i(a_value_i),
        .z_value_o(int_to_float_z_value),

        .exec_strobe_i((op_i == FPU_OP_INT_TO_FLOAT) ? exec_strobe_i : 1'b0),
        .done_strobe_o(int_to_float_done_strobe)
    );

    // float to int

    logic        float_to_int_done_strobe;
    logic [31:0] float_to_int_z_value;

    float_to_int float_to_int(
        .clk(clk),
        .reset_i(reset_i),

        .a_value_i(a_value_i),
        .z_value_o(float_to_int_z_value),

        .exec_strobe_i((op_i == FPU_OP_FLOAT_TO_INT) ? exec_strobe_i : 1'b0),
        .done_strobe_o(float_to_int_done_strobe)
    );

    // adder

    logic        adder_done_strobe;
    logic [31:0] adder_z_value;

    adder adder(
        .clk(clk),
        .reset_i(reset_i),

        .a_value_i(a_value_i),
        .b_value_i(b_value_i),
        .z_value_o(adder_z_value),

        .exec_strobe_i((op_i == FPU_OP_ADD) ? exec_strobe_i : 1'b0),
        .done_strobe_o(adder_done_strobe)
    );

    // multiply

    logic        multiplier_done_strobe;
    logic [31:0] multiplier_z_value;

    multiplier multiplier(
        .clk(clk),
        .reset_i(reset_i),

        .a_value_i(a_value_i),
        .b_value_i(b_value_i),
        .z_value_o(multiplier_z_value),

        .exec_strobe_i((op_i == FPU_OP_MULTIPLY) ? exec_strobe_i : 1'b0),
        .done_strobe_o(multiplier_done_strobe)
    );

    // divide

    logic        divider_done_strobe;
    logic [31:0] divider_z_value;

    divider divider(
        .clk(clk),
        .reset_i(reset_i),

        .a_value_i(a_value_i),
        .b_value_i(b_value_i),
        .z_value_o(divider_z_value),

        .exec_strobe_i((op_i == FPU_OP_DIVIDE) ? exec_strobe_i : 1'b0),
        .done_strobe_o(divider_done_strobe)
    );

    // output value and done strobe

    always_comb begin
        case (op_i)
            FPU_OP_INT_TO_FLOAT:
                z_value_o = int_to_float_z_value;
            FPU_OP_FLOAT_TO_INT:
                z_value_o = float_to_int_z_value;
            FPU_OP_ADD:
                z_value_o = adder_z_value;
            FPU_OP_MULTIPLY:
                z_value_o = multiplier_z_value;
            FPU_OP_DIVIDE:
                z_value_o = divider_z_value;
            default:
                z_value_o = 32'd0;
        endcase;

        done_strobe_o = int_to_float_done_strobe | float_to_int_done_strobe | adder_done_strobe
                        | multiplier_done_strobe | divider_done_strobe;
    end

endmodule