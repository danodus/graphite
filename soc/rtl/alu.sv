// alu.sv
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

module alu(
    input  wire logic        clk,
    input  wire logic        reset_i,
    input  wire logic        ce_i,
    input  wire logic        start_i,
    input  wire logic [31:0] in1_i,
    input  wire logic [31:0] in2_i,
    input  wire logic [2:0]  op_i,
    input                    op_qual_i, // operation qualification (+/-,logical/arithmetic)
    input                    op_ext_i,  // multiplier extension
    output      logic [31:0] out_o,
    output      logic        busy_o
    );

    logic mul_start;
    logic mul_done;
    logic [31:0] mul_res;    // result    

    multiplier multiplier(
        .clk(clk),
        .reset(reset_i),
        .ce(ce_i),
        .factor1(in1_i),
        .factor2(in2_i),
        .MULop(op_i[1:0]),
        .product(mul_res),
        .valid(mul_start),
        .ready(mul_done)
    );

    logic div_start;
    logic div_done;
    logic [31:0] div_res;    // result

    divider divider(
        .clk(clk),
        .reset(reset_i),
        .ce(ce_i),
        .divident(in1_i),
        .divisor(in2_i),
        .DIVop(op_i[1:0]),
        .divOrRemRslt(div_res),
        .valid(div_start),
        .ready(div_done),
        .div_by_zero_err()
    );

    enum {IDLE, MUL, DIV} state;

    assign busy_o = state != IDLE;

    // ALU logic
    always_ff @(posedge clk) begin
        if (reset_i) begin
            state     <= IDLE;
            mul_start <= 1'b0;
            div_start <= 1'b0;
        end else begin
            if (ce_i) begin
                case (state)
                    IDLE: begin
                        if (start_i) begin
                            if (op_ext_i == 1'b0) begin
                                case (op_i)
                                    3'b000: out_o <= op_qual_i ? in1_i - in2_i : in1_i + in2_i;                        // ADD/SUB
                                    3'b010: out_o <= ($signed(in1_i) < $signed(in2_i)) ? 32'b1 : 32'b0;                // SLT
                                    3'b011: out_o <= (in1_i < in2_i) ? 32'b1 : 32'b0;                                  // SLTU
                                    3'b100: out_o <= in1_i ^ in2_i;                                                    // XOR
                                    3'b110: out_o <= in1_i | in2_i;                                                    // OR
                                    3'b111: out_o <= in1_i & in2_i;                                                    // AND
                                    3'b001: out_o <= in1_i << in2_i[4:0];                                              // SLL
                                    3'b101: out_o <= $signed({op_qual_i ? in1_i[31] : 1'b0, in1_i}) >>> in2_i[4:0];    // SRL/SRA
                                endcase
                            end else begin
                                // extended operations
                                case (op_i)
                                    3'b000,
                                    3'b001,
                                    3'b010,
                                    3'b011:
                                    begin
                                        mul_start <= 1'b1;
                                        state <= MUL;
                                    end
                                    3'b100,                         // DIV
                                    3'b101,
                                    3'b110,                          // REM
                                    3'b111:                          // REMU
                                    begin
                                        div_start <= 1'b1;
                                        state  <= DIV;
                                    end
    `ifndef SYNTHESIS                           
                                default:
                                    $display("Unknown operation %d", op_i);
    `endif
                                endcase
                            end
                        end // if start
                    end
                    MUL: begin
                        if (mul_start) begin
                            mul_start <= 1'b0;
                        end else if (mul_done) begin
                            out_o  <= mul_res;
                            state  <= IDLE;
                        end
                    end
                    DIV: begin
                        if (div_start) begin
                            div_start <= 1'b0;
                        end else if (div_done) begin
                            out_o  <= div_res;
                            state  <= IDLE;
                        end
                    end
                endcase
            end // ce
        end
    end

endmodule
