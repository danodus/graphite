`default_nettype none

module ulx3s_v31(
//      -- System clock and reset
    input clk_25mhz, // main clock input from external clock source
    output wifi_en, wifi_gpio0,
    inout wifi_gpio21, wifi_gpio22,
    inout wifi_gpio26, wifi_gpio27,

//      -- On-board user buttons and status LEDs
    input [6:0] btn,
    output [7:0] led,

//      -- User GPIO (56 I/O pins) Header
    inout [27:0] gp, gn,  // GPIO Header pins available as one data block

//      -- USB Slave (FT231x) interface 
    output ftdi_rxd,
    input ftdi_txd,
     
//	-- SDRAM interface (For use with 16Mx16bit or 32Mx16bit SDR DRAM, depending on version)
    output sdram_csn, 
    output sdram_clk,	// clock to SDRAM
    output sdram_cke,	// clock enable to SDRAM	
    output sdram_rasn,      // SDRAM RAS
    output sdram_casn,	// SDRAM CAS
    output sdram_wen,	// SDRAM write-enable
    output [12:0] sdram_a,	// SDRAM address bus
    output [1:0] sdram_ba,	// SDRAM bank-address
    output [1:0] sdram_dqm,
    inout [15:0] sdram_d,	// data bus to/from SDRAM	
      
//	-- DVI interface
    // output [3:0] gpdi_dp, gpdi_dn,
    output [3:0] gpdi_dp,
     
//	-- SD/MMC Interface (Support either SPI or nibble-mode)
        inout sd_clk, sd_cmd,
        inout [3:0] sd_d,

//	-- PS2 interface
        output usb_fpga_pu_dp, usb_fpga_pu_dn,
        inout usb_fpga_bd_dp, usb_fpga_bd_dn // enable internal pullups at constraints file
    );
    assign wifi_gpio0 = btn[0];
    // assign wifi_en = 1'b0;

    assign sdram_cke = 1'b1; // -- SDRAM clock enable

    assign usb_fpga_pu_dp = 1'b1; 	// pull USB D+ to +3.3V through 1.5K resistor
    assign usb_fpga_pu_dn = 1'b1; 	// pull USB D- to +3.3V through 1.5K resistor

    // if picture "rolls" (sync problem), try another pixel clock
    parameter pixel_clock_MHz = 25;
    wire pll_video_locked;
    wire [3:0] clocks_video;
        ecp5pll
        #(
            .in_hz(               25*1000000),
          .out0_hz(5*pixel_clock_MHz*1000000),
          .out1_hz(  pixel_clock_MHz*1000000)
        )
        ecp5pll_video_inst
        (
          .clk_i(clk_25mhz),
          .clk_o(clocks_video),
          .locked(pll_video_locked)
        );
        wire clk_pixel, clk_shift;
        assign clk_shift = clocks_video[0]; // 125 MHz
        assign clk_pixel = clocks_video[1]; // 25 MHz

    wire [3:0] clocks_system;
    wire pll_system_locked;
        ecp5pll
        #(
            .in_hz( 25*1000000),
`ifdef FAST_CPU
          .out0_hz(100*1000000),
          .out1_hz(100*1000000), .out1_deg(180),
          .out2_hz( 50*1000000)
`else
          .out0_hz(50*1000000),
          .out1_hz(50*1000000), .out1_deg(180),
          .out2_hz(25*1000000)
`endif
        )
        ecp5pll_system_inst
        (
          .clk_i(clk_25mhz),
          .clk_o(clocks_system),
          .locked(pll_system_locked)
        );
    wire clk_cpu, clk_sdram;
    assign clk_sdram = clocks_system[0]; // 100 MHz sdram controller
    assign sdram_clk = clocks_system[1]; // 100 MHz 180 deg SDRAM chip
    assign clk_cpu = clocks_system[2];   // 100 MHz

    wire vga_hsync, vga_vsync, vga_blank;
    wire [3:0] vga_r, vga_g, vga_b;

    wire pll_locked;
    assign pll_locked = pll_system_locked & pll_video_locked;

    RISCVTop sys_inst
    (
        .CLK_CPU(clk_cpu),
        .CLK_SDRAM(clk_sdram),
        .CLK_PIXEL(clk_pixel),
        .RESET(!pll_locked | ~btn[0]), // reset
        .RX(ftdi_txd),   // RS-232
        .TX(ftdi_rxd),
        .LED(led),

        .SD_DO(sd_d[0]),          // SPI - SD card
        .SD_DI(sd_cmd),
        .SD_CK(sd_clk),
        .SD_nCS(sd_d[3]),

        .VGA_HSYNC(vga_hsync),
        .VGA_VSYNC(vga_vsync),
        .VGA_BLANK(vga_blank),
        .VGA_R(vga_r),
        .VGA_G(vga_g),
        .VGA_B(vga_b),

        .PS2CLKA(gn[1]), // keyboard clock
        .PS2DATA(gn[3]), // keyboard data
        .PS2CLKB(gn[0]), // mouse clock
        .PS2DATB(gn[2]), // mouse data

        .SDRAM_nCAS(sdram_casn),
        .SDRAM_nRAS(sdram_rasn),
        .SDRAM_nCS(sdram_csn),
        .SDRAM_nWE(sdram_wen),
        .SDRAM_BA(sdram_ba),
        .SDRAM_ADDR(sdram_a),
        .SDRAM_DATA(sdram_d),
        .SDRAM_DQML(sdram_dqm[0]),
        .SDRAM_DQMH(sdram_dqm[1])
    );
    assign gp[22] = 1'b1; // US3 PULLUP
    assign gn[22] = 1'b1; // US3 PULLUP

    // oberon video signal from oberon, rgb444->rgb888
    wire [7:0] vga_r8 = {vga_r, vga_r};
    wire [7:0] vga_g8 = {vga_g, vga_g};
    wire [7:0] vga_b8 = {vga_b, vga_b};

    // VGA to digital video converter
    hdmi_interface hdmi_interface_instance(
      .pixel_clk(clk_pixel),
      .pixel_clk_x5(clk_shift),
      .red(vga_r8),
      .green(vga_g8),
      .blue(vga_b8),
      .vde(~vga_blank),
      .hsync(vga_hsync),
      .vsync(vga_vsync),
      .gpdi_dp(gpdi_dp),
      .gpdi_dn()
    );

endmodule
