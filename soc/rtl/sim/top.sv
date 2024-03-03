// top.sv
// Copyright (c) 2023-2024 Daniel Cliche
// SPDX-License-Identifier: MIT

module top (
    input  wire logic        clk,
    input  wire logic        clk_sdram,
    input  wire logic        reset_i,
    output      logic [7:0]  display_o,
    input  wire logic        rx_i,
    output      logic        tx_o,

    output      logic        vga_hsync,
    output      logic        vga_vsync,
    output      logic [7:0]  vga_r,
    output      logic [7:0]  vga_g,
    output      logic [7:0]  vga_b,

    input  wire logic [7:0]  ps2_kbd_code_i,
    input  wire logic        ps2_kbd_strobe_i,
    input  wire logic        ps2_kbd_err_i,

    // SDRAM
    output      logic        sdram_clk_o,
    output      logic        sdram_cke_o,
    output      logic        sdram_cs_n_o,
    output      logic        sdram_we_n_o,
    output      logic        sdram_ras_n_o,
    output      logic        sdram_cas_n_o,
    output      logic [12:0] sdram_a_o,
    output      logic [1:0]  sdram_ba_o,
    output      logic [1:0]  sdram_dqm_o,
    inout       logic [15:0] sdram_dq_io  
    );

    assign sdram_cke_o = 1'b1; // SDRAM clock enable

    soc_top soc_top
    (
        .clk_cpu(clk),
        .clk_sdram(clk_sdram),
        .clk_pixel(clk),
        .reset_i(reset_i),

        // UART
        .rx_i(),
        .tx_o(),
        // LED
        .led_o(display_o),
        // SD card
        .sd_do_i(),
        .sd_di_o(),
        .sd_ck_o(),
        .sd_cs_n_o(),
        // VGA video
        .vga_hsync_o(vga_hsync),
        .vga_vsync_o(vga_vsync),
        .vga_blank_o(),
        .vga_r_o(vga_r),
        .vga_g_o(vga_g),
        .vga_b_o(vga_b),
        // USB
        .usb_fpga_dp(),
        .usb_fpga_bd_dp(),
        .usb_fpga_bd_dn(),
        .usb_fpga_pu_dp(),
        .usb_fpga_pu_dn(),
        // SDRAM
        .sdram_cas_n_o(sdram_cas_n_o),
        .sdram_ras_n_o(sdram_ras_n_o),
        .sdram_cs_n_o(sdram_cs_n_o),
        .sdram_we_n_o(sdram_we_n_o),
        .sdram_ba_o(sdram_ba_o),
        .sdram_addr_o(sdram_a_o),
        .sdram_data_io(sdram_dq_io),
        .sdram_dqm_o(sdram_dqm_o)
    );

    initial begin
        //$display("[%0t] Tracing to logs/vlt_dump.vcd...\n", $time);
        //$dumpfile("logs/vlt_dump.vcd");
        //$dumpvars();
    end
    
endmodule