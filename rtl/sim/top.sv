// top.sv
// Copyright (c) 2021-2022 Daniel Cliche
// SPDX-License-Identifier: MIT

module top(
    input wire logic                  clk,
    input wire logic                  reset_i,

    // AXI stream command interface (slave)
    input wire logic                   cmd_axis_tvalid_i,
    output logic                       cmd_axis_tready_o,
    input wire [31:0]                  cmd_axis_tdata_i,

    // VRAM write
    //input  wire logic                        vram_ack_i,
    output      logic                        vram_sel_o,
    output      logic                        vram_wr_o,
    output      logic  [3:0]                 vram_mask_o,
    output      logic [31:0]                 vram_addr_o,
    input       logic [15:0]                 vram_data_in_i,
    output      logic [15:0]                 vram_data_out_o,

    output      logic                        swap_o
    );

    logic        vram_sel;
    logic        vram_wr_en;
    logic  [3:0] vram_wr_mask;
    logic [31:0] vram_addr;
    logic [15:0] vram_data_in;

    graphite #(
        .FB_WIDTH(128),
        .FB_HEIGHT(128)
    ) graphite (
        .clk(clk),
        .reset_i(reset_i),
        .cmd_axis_tvalid_i(cmd_axis_tvalid_i),
        .cmd_axis_tready_o(cmd_axis_tready_o),
        .cmd_axis_tdata_i(cmd_axis_tdata_i),
        .vram_sel_o(vram_sel_o),
        .vram_wr_o(vram_wr_o),
        .vram_mask_o(vram_mask_o),
        .vram_addr_o(vram_addr_o),
        .vram_data_in_i(vram_data_in_i),
        .vram_data_out_o(vram_data_out_o),
        .swap_o(swap_o)
    );

endmodule

