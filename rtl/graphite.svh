`ifndef GRAPHITE_SVH
`define GRAPHITE_SVH

// 8 OP | 24 Immediate

localparam OP_SET_X0        = 0;
localparam OP_SET_Y0        = 1;
localparam OP_SET_Z0        = 2; // w0
localparam OP_SET_X1        = 3;
localparam OP_SET_Y1        = 4;
localparam OP_SET_Z1        = 5; // w1
localparam OP_SET_X2        = 6;
localparam OP_SET_Y2        = 7;
localparam OP_SET_Z2        = 8; // w2
localparam OP_SET_R0        = 9;
localparam OP_SET_G0        = 10;
localparam OP_SET_B0        = 11;
localparam OP_SET_A0        = 12; // not implemented yet
localparam OP_SET_R1        = 13;
localparam OP_SET_G1        = 14;
localparam OP_SET_B1        = 15;
localparam OP_SET_A1        = 16; // not implemented yet
localparam OP_SET_R2        = 17;
localparam OP_SET_G2        = 18;
localparam OP_SET_B2        = 19;
localparam OP_SET_A2        = 20; // not implemented yet
localparam OP_SET_S0        = 21;
localparam OP_SET_T0        = 22;
localparam OP_SET_S1        = 23;
localparam OP_SET_T1        = 24;
localparam OP_SET_S2        = 25;
localparam OP_SET_T2        = 26;
localparam OP_SET_DAX_STEP  = 27; // standard rasterizer only
localparam OP_SET_DBX_STEP  = 28; // standard rasterizer only
localparam OP_SET_DS0_STEP  = 29; // standard rasterizer only
localparam OP_SET_DT0_STEP  = 30; // standard rasterizer only
localparam OP_SET_DW0_STEP  = 31; // standard rasterizer only
localparam OP_SET_DS1_STEP  = 32; // standard rasterizer only
localparam OP_SET_DT1_STEP  = 33; // standard rasterizer only
localparam OP_SET_DW1_STEP  = 34; // standard rasterizer only
localparam OP_SET_DR0_STEP  = 35; // standard rasterizer only
localparam OP_SET_DG0_STEP  = 36; // standard rasterizer only
localparam OP_SET_DB0_STEP  = 37; // standard rasterizer only
localparam OP_SET_DA0_STEP  = 38; // standard rasterizer only, not implemented yet
localparam OP_SET_DR1_STEP  = 39; // standard rasterizer only
localparam OP_SET_DG1_STEP  = 40; // standard rasterizer only
localparam OP_SET_DB1_STEP  = 41; // standard rasterizer only
localparam OP_SET_DA1_STEP  = 42; // standard rasterizer only, not implemented yet
localparam OP_SET_TEX_ADDR  = 43;
localparam OP_CLEAR         = 44;
localparam OP_DRAW          = 45;
localparam OP_SWAP          = 46;
localparam OP_WRITE_TEX     = 47;

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
