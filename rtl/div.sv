// div.sv
// Copyright (c) 2023 Daniel Cliche
// SPDX-License-Identifier: MIT

// Ref.: https://projectf.io/posts/division-in-verilog/

module div #(parameter WIDTH=32) (     // width of numbers in bits
    input wire logic clk,              // clock
    input wire logic reset_i,          // reset
    input wire logic start_i,          // start calculation
    output     logic busy_o,           // calculation in progress
    output     logic done_o,           // calculation is complete (high for one tick)
    output     logic valid_o,          // result is valid
    output     logic dbz_o,            // divide by zero
    input wire logic [WIDTH-1:0] a_i,  // dividend (numerator)
    input wire logic [WIDTH-1:0] b_i,  // divisor (denominator)
    output     logic [WIDTH-1:0] val_o,// result value: quotient
    output     logic [WIDTH-1:0] rem_o // result: remainder
    );

    logic [WIDTH-1:0] b1;             // copy of divisor
    logic [WIDTH-1:0] quo, quo_next;  // intermediate quotient
    logic [WIDTH:0] acc, acc_next;    // accumulator (1 bit wider)
    logic [$clog2(WIDTH)-1:0] i;      // iteration counter

    // division algorithm iteration
    always_comb begin
        if (acc >= {1'b0, b1}) begin
            acc_next = acc - b1;
            {acc_next, quo_next} = {acc_next[WIDTH-1:0], quo, 1'b1};
        end else begin
            {acc_next, quo_next} = {acc, quo} << 1;
        end
    end

    // calculation control
    always_ff @(posedge clk) begin
        done_o <= 0;
        if (start_i) begin
            valid_o <= 0;
            i <= 0;
            if (b_i == 0) begin  // catch divide by zero
                busy_o <= 0;
                done_o <= 1;
                dbz_o <= 1;
            end else begin
                busy_o <= 1;
                dbz_o <= 0;
                b1 <= b_i;
                {acc, quo} <= {{WIDTH{1'b0}}, a_i, 1'b0};  // initialize calculation
            end
        end else if (busy_o) begin
            if (i == {$clog2(WIDTH){1'b1}}) begin  // we're done
                busy_o <= 0;
                done_o <= 1;
                valid_o <= 1;
                val_o <= quo_next;
                rem_o <= acc_next[WIDTH:1];  // undo final shift
            end else begin  // next iteration
                i <= i + 1;
                acc <= acc_next;
                quo <= quo_next;
            end
        end
        if (reset_i) begin
            busy_o <= 0;
            done_o <= 0;
            valid_o <= 0;
            dbz_o <= 0;
            val_o <= 0;
            rem_o <= 0;
        end
    end
endmodule