module top(
    input wire logic clk,
    input wire logic reset_i,

    input wire logic [31:0] a_value_i,
    output logic     [31:0] z_value_o,

    input wire logic        exec_strobe_i,
    output logic            done_strobe_o
    );

    float_to_int float_to_int(
        .clk(clk),
        .reset_i(reset_i),
        .a_value_i(a_value_i),
        .z_value_o(z_value_o),
        .exec_strobe_i(exec_strobe_i),
        .done_strobe_o(done_strobe_o)
    );
endmodule