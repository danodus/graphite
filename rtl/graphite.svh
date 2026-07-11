// graphite.svh
// Copyright (c) 2021-2026 Daniel Cliche
// SPDX-License-Identifier: MIT

`ifndef GRAPHITE_SVH
`define GRAPHITE_SVH

// 8 OP | 24 Immediate

localparam OP_SET_V0_X          = 0;
localparam OP_SET_V0_Y          = 1;
localparam OP_SET_V1_X          = 2;
localparam OP_SET_V1_Y          = 3;
localparam OP_SET_V2_X          = 4;
localparam OP_SET_V2_Y          = 5;
localparam OP_SET_START_W_INV   = 6;
localparam OP_SET_START_S       = 7;
localparam OP_SET_START_T       = 8;
localparam OP_SET_START_R       = 9;
localparam OP_SET_START_G       = 10;
localparam OP_SET_START_B       = 11;
localparam OP_SET_DW_DX         = 12;
localparam OP_SET_DW_DY         = 13;
localparam OP_SET_DS_DX         = 14;
localparam OP_SET_DS_DY         = 15;
localparam OP_SET_DT_DX         = 16;
localparam OP_SET_DT_DY         = 17;
localparam OP_SET_DR_DX         = 18;
localparam OP_SET_DR_DY         = 19;
localparam OP_SET_DG_DX         = 20;
localparam OP_SET_DG_DY         = 21;
localparam OP_SET_DB_DX         = 22;
localparam OP_SET_DB_DY         = 23;
localparam OP_CLEAR             = 24;
localparam OP_DRAW              = 25;
localparam OP_SWAP              = 26;
localparam OP_SET_TEX_ADDR      = 27;
localparam OP_SET_FB_ADDR       = 28;
localparam OP_SET_START_Q       = 29;
localparam OP_SET_DQ_DX         = 30;
localparam OP_SET_DQ_DY         = 31;



localparam OP_POS   = 24;
localparam OP_SIZE  = 8;

`endif // GRAPHITE_SVH
