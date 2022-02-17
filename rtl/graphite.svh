`ifndef GRAPHITE_SVH
`define GRAPHITE_SVH

// 4 OP | 12 Immediate

localparam OP_SET_X0        = 0;
localparam OP_SET_Y0        = 1;
localparam OP_SET_X1        = 2;
localparam OP_SET_Y1        = 3;
localparam OP_SET_X2        = 4;
localparam OP_SET_Y2        = 5;
localparam OP_SET_U0        = 6;
localparam OP_SET_V0        = 7;
localparam OP_SET_U1        = 8;
localparam OP_SET_V1        = 9;
localparam OP_SET_U2        = 10;
localparam OP_SET_V2        = 11;
localparam OP_SET_COLOR     = 12;
localparam OP_CLEAR         = 13;
localparam OP_DRAW_LINE     = 14;
localparam OP_DRAW_TRIANGLE = 15;


localparam OP_POS   = 12;
localparam OP_SIZE  = 4;

function logic signed [31:0] mul(logic signed [31:0] x, logic signed [31:0] y);
    mul = (x >> 8) * (y >> 8);
endfunction

function logic signed [31:0] rmul(logic signed [31:0] x, logic signed [31:0] y);
    rmul = (x >> 16) * y;
endfunction

function logic signed [31:0] rdiv(logic signed [31:0] x, logic signed [31:0] y);
    rdiv = x / (y >> 16);
endfunction

function logic signed [11:0] min(logic signed [11:0] a, logic signed [11:0] b);
    min = (a <= b) ? a : b;
endfunction

function logic signed [11:0] max(logic signed [11:0] a, logic signed [11:0] b);
    max = (a >= b) ? a : b;
endfunction

function logic signed [11:0] min3(logic signed [11:0] a, logic signed [11:0] b, logic signed [11:0] c);
    min3 = min(a, min(b, c));
endfunction

function logic signed [11:0] max3(logic signed [11:0] a, logic signed [11:0] b, logic signed [11:0] c);
    max3 = max(a, max(b, c));
endfunction

`endif // GRAPHITE_SVH
