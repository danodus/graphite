`timescale 1ns / 1ps

/*Project Oberon, Revised Edition 2013

Book copyright (C)2013 Niklaus Wirth and Juerg Gutknecht;
software copyright (C)2013 Niklaus Wirth (NW), Juerg Gutknecht (JG), Paul
Reed (PR/PDR).

Permission to use, copy, modify, and/or distribute this software and its
accompanying documentation (the "Software") for any purpose with or
without fee is hereby granted, provided that the above copyright notice
and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHORS DISCLAIM ALL WARRANTIES
WITH REGARD TO THE SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY, FITNESS AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS BE LIABLE FOR ANY CLAIM, SPECIAL, DIRECT, INDIRECT, OR
CONSEQUENTIAL DAMAGES OR ANY DAMAGES OR LIABILITY WHATSOEVER, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE DEALINGS IN OR USE OR PERFORMANCE OF THE SOFTWARE.*/

// 1024x768 display controller NW/PR 24.1.2014
// OberonStation (externally-clocked) ver PR 7.8.15/03.10.15
// Modified for SDRAM - Nicolae Dumitrache 2016

module video #(
    parameter CORDW=11,   // signed coordinate width (bits)
    parameter H_RES=640,  // horizontal resolution (pixels)
    parameter V_RES=480,  // vertical resolution (lines)
    parameter H_FP=16,    // horizontal front porch
    parameter H_SYNC=96,  // horizontal sync
    parameter H_BP=48,    // horizontal back porch
    parameter V_FP=10,    // vertical front porch
    parameter V_SYNC=2,   // vertical sync
    parameter V_BP=33     // vertical back porch
) (
    input clk, pclk, ce,
    input [31:0] viddata,
    output reg req,  // SRAM read request
    output hsync, vsync,  // to display
    output de,
    output [15:0] RGB
);

  localparam H_TOTAL = H_RES + H_FP + H_SYNC + H_BP;
  localparam V_TOTAL = V_RES + V_FP + V_SYNC + V_BP;

reg [CORDW-1:0] hcnt;
reg [CORDW-1:0] vcnt;
reg hword;  // from hcnt, but latched in the clk domain
reg [31:0] vidbuf, pixbuf;
reg hblank;
wire hend, vend, vblank, xfer;
wire [15:0] vid;
reg [1:0] init_req_counter;

assign de = !(hblank|vblank);

assign hend = (hcnt == H_TOTAL-1), vend = (vcnt == V_TOTAL-1);
assign vblank = (vcnt >= V_RES);
assign hsync = (hcnt >= H_RES+H_FP) & (hcnt < H_RES+H_FP+H_BP);
assign vsync = (vcnt >= V_RES+V_FP) & (vcnt < V_RES+V_FP+V_BP);
assign xfer = hcnt[0];  // data delay > hcnt cycle + req cycle
assign vid = (~hblank & ~vblank) ? pixbuf[15:0] : 16'd0;
assign RGB = vid;

always @(posedge pclk) if(ce && init_req_counter == 2'd0) begin  // pixel clock domain
  hcnt <= hend ? 0 : hcnt+1;
  vcnt <= hend ? (vend ? 0 : (vcnt+1)) : vcnt;
  hblank <= xfer ? (hcnt >= H_RES) : hblank;
  pixbuf <= xfer ? vidbuf : {16'd0, pixbuf[31:16]};
end

always @(posedge pclk) if(ce) begin  // CPU (SRAM) clock domain
  if (init_req_counter == 2'd0) begin
    hword <= hcnt[0];
    req <= ~vblank & (hcnt < H_RES) & hword;  // i.e. adr changed
    vidbuf <= req ? viddata : vidbuf;
  end else begin
    req <= 1;
    init_req_counter <= init_req_counter - 1;
  end
end else begin
  req <= 0;
  init_req_counter <= 2'd2;
end

endmodule
