// graphite.svh
// Copyright (c) 2021-2026 Daniel Cliche
// SPDX-License-Identifier: MIT

`ifndef GRAPHITE_SVH
`define GRAPHITE_SVH

// 8 OP | 24 Immediate

localparam OP_SET_MIN_X         = 0;
localparam OP_SET_MAX_X         = 1;
localparam OP_SET_MAX_Y         = 2;
localparam OP_SET_START_X       = 3;
localparam OP_SET_START_Y       = 4;
localparam OP_SET_E01_START     = 5;
localparam OP_SET_E12_START     = 6;
localparam OP_SET_E20_START     = 7;
localparam OP_SET_STEP_E01_X    = 8;
localparam OP_SET_STEP_E01_Y    = 9;
localparam OP_SET_STEP_E12_X    = 10;
localparam OP_SET_STEP_E12_Y    = 11;
localparam OP_SET_STEP_E20_X    = 12;
localparam OP_SET_STEP_E20_Y    = 13;
localparam OP_SET_START_W_INV   = 14;
localparam OP_SET_START_S       = 15;
localparam OP_SET_START_T       = 16;
localparam OP_SET_START_R       = 17;
localparam OP_SET_START_G       = 18;
localparam OP_SET_START_B       = 19;
localparam OP_SET_DW_DX         = 20;
localparam OP_SET_DW_DY         = 21;
localparam OP_SET_DS_DX         = 22;
localparam OP_SET_DS_DY         = 23;
localparam OP_SET_DT_DX         = 24;
localparam OP_SET_DT_DY         = 25;
localparam OP_SET_DR_DX         = 26;
localparam OP_SET_DR_DY         = 27;
localparam OP_SET_DG_DX         = 28;
localparam OP_SET_DG_DY         = 29;
localparam OP_SET_DB_DX         = 30;
localparam OP_SET_DB_DY         = 31;
localparam OP_CLEAR             = 32;
localparam OP_DRAW              = 33;
localparam OP_SWAP              = 34;
localparam OP_SET_TEX_ADDR      = 35;
localparam OP_SET_FB_ADDR       = 36;



localparam OP_POS   = 24;
localparam OP_SIZE  = 8;

`endif // GRAPHITE_SVH
