// ulx3s_v31_top.sv
// Copyright (c) 2023-2024 Daniel Cliche
// SPDX-License-Identifier: MIT

// Based on the Oberon ULX3S design

module ulx3s_v31_top(
    // System clock and reset
    input  wire logic clk_25mhz, // main clock input from external clock source

    // On-board user buttons and status LEDs
    input  wire logic [6:0] btn,
    output      logic [7:0] led,

    // USB Slave (FT231x) interface 
    output      logic ftdi_rxd,
    input  wire logic ftdi_txd,
     
    // SDRAM interface (For use with 16Mx16bit or 32Mx16bit SDR DRAM, depending on version)
    output      logic        sdram_csn, 
    output      logic        sdram_clk,	 // clock to SDRAM
    output      logic        sdram_cke,  // clock enable to SDRAM	
    output      logic        sdram_rasn, // SDRAM RAS
    output      logic        sdram_casn, // SDRAM CAS
    output      logic        sdram_wen,	 // SDRAM write-enable
    output      logic [12:0] sdram_a,	 // SDRAM address bus
    output      logic [1:0]  sdram_ba,	 // SDRAM bank-address
    output      logic [1:0]  sdram_dqm,
    inout       logic [15:0] sdram_d,	 // data bus to/from SDRAM	
      
    // DVI interface
    output      logic [3:0] gpdi_dp,
     
    // SD/MMC Interface (Support either SPI or nibble-mode)
    inout logic       sd_clk, sd_cmd,
    inout logic [3:0] sd_d,

    // USB
    input  wire logic        usb_fpga_dp,     // D differential in
    inout  wire logic        usb_fpga_bd_dp,  // D+
    inout  wire logic        usb_fpga_bd_dn,  // D-
    inout  wire logic        usb_fpga_pu_dp,  // 1 = 1.5K up, 0 = 15K down, z = float
    inout  wire logic        usb_fpga_pu_dn   // 1 = 1.5K up, 0 = 15K down, z = float
);

`ifdef VIDEO_480P
    localparam pixel_clock_hz = 34_000_000; // DMT: 33.75MHz
`elsif VIDEO_720P
    localparam pixel_clock_hz = 75_000_000; // DMT: 74.25MHz
`elsif VIDEO_1080P
    localparam pixel_clock_hz = 75_000_000; // DMT: 74.25MHz
`else // VGA
    localparam pixel_clock_hz = 25_000_000; // DMT: 25MHz
`endif

    assign sdram_cke = 1'b1; // SDRAM clock enable

    logic pll_video_locked;
    logic [3:0] clocks_video;
    ecp5pll
    #(
        .in_hz(25_000_000),
        .out0_hz(5*pixel_clock_hz),
        .out1_hz(pixel_clock_hz)
    )
    ecp5pll_video_inst
    (
        .clk_i(clk_25mhz),
        .clk_o(clocks_video),
        .locked(pll_video_locked)
    );
    logic clk_pixel, clk_shift;
    assign clk_shift = clocks_video[0]; // 125 MHz
    assign clk_pixel = clocks_video[1]; // 25 MHz

    logic clk_sdram;
    logic pll_sdram_locked;

    pll_sdram pll_sdram(
        .clkin(clk_25mhz),
        .clkout0(clk_sdram),
        .locked(pll_sdram_locked)
    );

    assign sdram_clk = ~clk_sdram;

    logic clk_cpu;
    logic pll_cpu_locked;
    pll_cpu pll_cpu(
        .clkin(clk_25mhz),
        .clkout0(clk_cpu),
        .locked(pll_cpu_locked)
    );

    logic vga_hsync, vga_vsync, vga_blank;
    logic [7:0] vga_r, vga_g, vga_b;

    logic pll_locked;
    assign pll_locked = pll_cpu_locked & pll_sdram_locked & pll_video_locked;

    soc_top #(
        .FREQ_HZ(48_000_000),
        .BAUD_RATE(2_000_000)
    ) soc_top(
        .clk_cpu(clk_cpu),
        .clk_sdram(clk_sdram),
        .clk_pixel(clk_pixel),
        .reset_i(!pll_locked | ~btn[0]), // reset

        // UART
        .rx_i(ftdi_txd),
        .tx_o(ftdi_rxd),
        // LED
        .led_o(led),
        // SD card
        .sd_do_i(sd_d[0]),
        .sd_di_o(sd_cmd),
        .sd_ck_o(sd_clk),
        .sd_cs_n_o(sd_d[3]),
        // VGA video
        .vga_hsync_o(vga_hsync),
        .vga_vsync_o(vga_vsync),
        .vga_blank_o(vga_blank),
        .vga_r_o(vga_r),
        .vga_g_o(vga_g),
        .vga_b_o(vga_b),
        // USB
        .usb_fpga_dp(usb_fpga_dp),
        .usb_fpga_bd_dp(usb_fpga_bd_dp),
        .usb_fpga_bd_dn(usb_fpga_bd_dn),
        .usb_fpga_pu_dp(usb_fpga_pu_dp),
        .usb_fpga_pu_dn(usb_fpga_pu_dn),
        // SDRAM
        .sdram_cas_n_o(sdram_casn),
        .sdram_ras_n_o(sdram_rasn),
        .sdram_cs_n_o(sdram_csn),
        .sdram_we_n_o(sdram_wen),
        .sdram_ba_o(sdram_ba),
        .sdram_addr_o(sdram_a),
        .sdram_data_io(sdram_d),
        .sdram_dqm_o(sdram_dqm)
    );

    // VGA to digital video converter
    hdmi_interface hdmi_interface_instance(
      .pixel_clk(clk_pixel),
      .pixel_clk_x5(clk_shift),
      .red(vga_r),
      .green(vga_g),
      .blue(vga_b),
      .vde(~vga_blank),
      .hsync(vga_hsync),
      .vsync(vga_vsync),
      .gpdi_dp(gpdi_dp),
      .gpdi_dn()
    );

endmodule
