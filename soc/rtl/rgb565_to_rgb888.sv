// rgb565_to_rgb888.sv
// Copyright (c) 2024 Daniel Cliche
// SPDX-License-Identifier: MIT

// Ref.: https://github.com/agg23/openfpga-litex/blob/master/rtl/video/rgb565_to_rgb888.sv

module rgb565_to_rgb888 (
    input   wire logic [15:0] rgb565_i,
    output       logic [23:0] rgb888_o
);

    // Constants taken from https://stackoverflow.com/a/9069480
    logic [13:0] red   = {2'b0, rgb565_i[15:11]} * 10'd527 + 14'd23;
    logic [13:0] green = {1'b0, rgb565_i[10:5]} * 10'd259 + 14'd33;
    logic [13:0] blue  = {2'b0, rgb565_i[4:0]} * 10'd527 + 14'd23;

    assign rgb888_o[23:16] = red[13:6];
    assign rgb888_o[15:8]  = green[13:6];
    assign rgb888_o[7:0]   = blue[13:6];

endmodule