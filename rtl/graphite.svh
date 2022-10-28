`ifndef GRAPHITE_SVH
`define GRAPHITE_SVH

// 8 OP | 24 Immediate

localparam OP_SET_X0        = 0;
localparam OP_SET_Y0        = 1;
localparam OP_SET_Z0        = 2;
localparam OP_SET_X1        = 3;
localparam OP_SET_Y1        = 4;
localparam OP_SET_Z1        = 5;
localparam OP_SET_X2        = 6;
localparam OP_SET_Y2        = 7;
localparam OP_SET_Z2        = 8;
localparam OP_SET_R0        = 9;
localparam OP_SET_G0        = 10;
localparam OP_SET_B0        = 11;
localparam OP_SET_R1        = 12;
localparam OP_SET_G1        = 13;
localparam OP_SET_B1        = 14;
localparam OP_SET_R2        = 15;
localparam OP_SET_G2        = 16;
localparam OP_SET_B2        = 17;
localparam OP_SET_S0        = 18;
localparam OP_SET_T0        = 19;
localparam OP_SET_S1        = 20;
localparam OP_SET_T1        = 21;
localparam OP_SET_S2        = 22;
localparam OP_SET_T2        = 23;
localparam OP_CLEAR         = 24;
localparam OP_DRAW          = 25;
localparam OP_SWAP          = 26;
localparam OP_SET_TEX_ADDR  = 27;
localparam OP_WRITE_TEX     = 28;



localparam OP_POS   = 24;
localparam OP_SIZE  = 8;

function logic signed [31:0] mul(logic signed [31:0] x, logic signed [31:0] y);
    logic signed [63:0] x2, y2, mul2;
    begin
        x2 = {{32{x[31]}}, x};
        y2 = {{32{y[31]}}, y};
        mul2 = (x2 * y2) >>> 16;
        mul = mul2[31:0];
    end
endfunction

function logic signed [31:0] div(logic signed [31:0] x, logic signed [31:0] y);
    logic signed [63:0] x2, y2, div2;
    begin
        x2 = {{32{x[31]}}, x};
        y2 = {{32{y[31]}}, y};
        div2 = (x2 << 16) / y2;
        div = div2[31:0];
    end
endfunction

function logic signed [31:0] rdiv(logic signed [31:0] x, logic signed [31:0] y);
    rdiv = x / (y >>> 16);
endfunction

function logic signed [31:0] clamp(logic signed [31:0] x);
    if (x[31])
        clamp = 32'd0;
    else if (x[31:16] != 16'd0)
        clamp = 32'd1 << 16;
    else
        clamp = x;
endfunction

function logic signed [31:0] wrap(logic signed [31:0] x);
    if (x[31])
        wrap = 32'd0;
    else
        wrap = {16'd0, x[15:0]};
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
