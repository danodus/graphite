`ifndef GRAPHITE_SVH
`define GRAPHITE_SVH

// FPU

localparam FPU_OP_INT_TO_FLOAT    = 0;
localparam FPU_OP_FLOAT_TO_INT    = 1;
localparam FPU_OP_ADD             = 2;
localparam FPU_OP_MULTIPLY        = 3;
localparam FPU_OP_DIVIDE          = 4;

// 4 OP | 12 Immediate

localparam OP_NOP           = 0;
localparam OP_SET_X0        = 1;
localparam OP_SET_Y0        = 2;
localparam OP_SET_X1        = 3;
localparam OP_SET_Y1        = 4;
localparam OP_SET_X2        = 5;
localparam OP_SET_Y2        = 6;
localparam OP_SET_COLOR     = 7;
localparam OP_CLEAR         = 8;
localparam OP_DRAW_LINE     = 9;
localparam OP_DRAW_TRIANGLE = 10;

localparam OP_POS   = 12;
localparam OP_SIZE  = 4;

`endif // GRAPHITE_SVH
