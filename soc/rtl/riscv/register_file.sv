// register_file.sv
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

module register_file(
    input  wire logic        clk,
    input  wire logic        ce_i,
    input  wire logic [31:0] in_i,       // data for write back register
    input  wire logic [5:0]  in_sel_i,   // register number to write back to
    input  wire logic        in_en_i,    // don't actually write back unless asserted
    input  wire logic [5:0]  out1_sel_i, // register number for out1
    input  wire logic [5:0]  out2_sel_i, // register number for out2
    output      logic [31:0] out1_o,
    output      logic [31:0] out2_o,

    // debug
    output      logic [31:0] dbg_x0,
    output      logic [31:0] dbg_x1,
    output      logic [31:0] dbg_x2,
    output      logic [31:0] dbg_x3,
    output      logic [31:0] dbg_x4,
    output      logic [31:0] dbg_x5,
    output      logic [31:0] dbg_x6,
    output      logic [31:0] dbg_x7,
    output      logic [31:0] dbg_x8,
    output      logic [31:0] dbg_x9,
    output      logic [31:0] dbg_x10,
    output      logic [31:0] dbg_x11,
    output      logic [31:0] dbg_x12,
    output      logic [31:0] dbg_x13,
    output      logic [31:0] dbg_x14,
    output      logic [31:0] dbg_x15,
    output      logic [31:0] dbg_x16,
    output      logic [31:0] dbg_x17,
    output      logic [31:0] dbg_x18,
    output      logic [31:0] dbg_x19,
    output      logic [31:0] dbg_x20,
    output      logic [31:0] dbg_x21,
    output      logic [31:0] dbg_x22,
    output      logic [31:0] dbg_x23,
    output      logic [31:0] dbg_x24,
    output      logic [31:0] dbg_x25,
    output      logic [31:0] dbg_x26,
    output      logic [31:0] dbg_x27,
    output      logic [31:0] dbg_x28,
    output      logic [31:0] dbg_x29,
    output      logic [31:0] dbg_x30,
    output      logic [31:0] dbg_x31,
    output      logic [31:0] dbg_q0,
    output      logic [31:0] dbg_q1,
    output      logic [31:0] dbg_q2,
    output      logic [31:0] dbg_q3
    );

    logic [31:0] regs[35:0];

    initial begin
        for (integer i = 0; i < 36; i = i + 1)
            regs[i] = 32'd0;
    end

    always_comb begin
        dbg_x0 = regs[0];
        dbg_x1 = regs[1];
        dbg_x2 = regs[2];
        dbg_x3 = regs[3];
        dbg_x4 = regs[4];
        dbg_x5 = regs[5];
        dbg_x6 = regs[6];
        dbg_x7 = regs[7];
        dbg_x8 = regs[8];
        dbg_x9 = regs[9];
        dbg_x10 = regs[10];
        dbg_x11 = regs[11];
        dbg_x12 = regs[12];
        dbg_x13 = regs[13];
        dbg_x14 = regs[14];
        dbg_x15 = regs[15];
        dbg_x16 = regs[16];
        dbg_x17 = regs[17];
        dbg_x18 = regs[18];
        dbg_x19 = regs[19];
        dbg_x20 = regs[20];
        dbg_x21 = regs[21];
        dbg_x22 = regs[22];
        dbg_x23 = regs[23];
        dbg_x24 = regs[24];
        dbg_x25 = regs[25];
        dbg_x26 = regs[26];
        dbg_x27 = regs[27];
        dbg_x28 = regs[28];
        dbg_x29 = regs[29];
        dbg_x30 = regs[30];
        dbg_x31 = regs[31];
        dbg_q0  = regs[32];
        dbg_q1  = regs[33];
        dbg_q2  = regs[34];
        dbg_q3  = regs[35];
    end

    // actual register file storage
    always_ff @(posedge clk) begin
        if (ce_i) begin
            if (in_en_i) begin
                if (in_sel_i != 0)
                    regs[in_sel_i] <= in_i;
            end
            out1_o = regs[out1_sel_i];
            out2_o = regs[out2_sel_i];
        end
    end
endmodule