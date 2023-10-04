`include "graphite.svh"

// f(x) = NUMERATOR/x
module reciprocal #(
    parameter NUMERATOR = 32'h100
)(
    input wire logic clk,
    input wire logic reset_i,
    input wire logic start_i,
    input wire logic [31:0] x_i,
    output     logic [31:0] z_o,
    output     logic        done_o
);

    logic div_dbz;
    logic [31:0] div_val;
    assign z_o = div_dbz ? NUMERATOR << 14 : div_val;

    div div(
        .clk(clk),
        .reset_i(reset_i),
        .start_i(start_i),
        .busy_o(),
        .done_o(done_o),
        .valid_o(),
        .dbz_o(div_dbz),
        .a_i(NUMERATOR << 14 << 7),
        .b_i(x_i >> 7),
        .val_o(div_val),
        .rem_o()
    );

endmodule