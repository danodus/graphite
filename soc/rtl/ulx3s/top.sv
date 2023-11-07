`default_nettype none

module top(
    input clk_25mhz,

    output wifi_en, wifi_gpio0,

    input [6:0] btn,
    output [7:0] led,

    inout [27:0] gp, gn,

    output ftdi_rxd,
    input ftdi_txd,
     
    // SDRAM interface
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
      
    // DVI interface
    // output [3:0] gpdi_dp, gpdi_dn,
    output [3:0] gpdi_dp,
     
    // SD/MMC Interface (Support either SPI or nibble-mode)
    inout sd_clk, sd_cmd,
    inout [3:0] sd_d,

    // PS2 interface
    output usb_fpga_pu_dp, usb_fpga_pu_dn,
    inout usb_fpga_bd_dp, usb_fpga_bd_dn // enable internal pullups at constraints file
);


    assign wifi_gpio0 = btn[0];
    // assign wifi_en = 1'b0;

    assign sdram_cke = 1'b1; // -- SDRAM clock enable

    assign usb_fpga_pu_dp = 1'b1; 	// pull USB D+ to +3.3V through 1.5K resistor
    assign usb_fpga_pu_dn = 1'b1; 	// pull USB D- to +3.3V through 1.5K resistor

    localparam PIXEL_CLOCK_MHZ = 25;

    logic pll_video_locked;
    logic [3:0] clocks_video;
        ecp5pll
        #(
            .in_hz(               25*1000000),
          .out0_hz(5*PIXEL_CLOCK_MHZ*1000000),
          .out1_hz(  PIXEL_CLOCK_MHZ*1000000)
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

    logic [3:0] clocks_system;
    logic pll_system_locked;
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

    logic clk_cpu, clk_sdram;
    assign clk_sdram = clocks_system[0]; // 100 MHz sdram controller
    assign sdram_clk = clocks_system[1]; // 100 MHz 180 deg SDRAM chip
    assign clk_cpu = clocks_system[2];   // 50 MHz

    logic pll_locked;
    assign pll_locked = pll_system_locked & pll_video_locked;

    // reset
    logic auto_reset;
    logic [5:0] auto_reset_counter = 0;
    logic reset;

    assign auto_reset = auto_reset_counter < 5'b11111;
    assign reset = auto_reset || !btn[0];

    always_ff @(posedge clk_cpu) begin
        if (pll_locked)
            auto_reset_counter <= auto_reset_counter + auto_reset;
	end

    gsoc gsoc(
        .clk_cpu(clk_cpu),
        .clk_sdram(clk_sdram),
        .clk_pixel(clk_pixel),
        .reset_i(reset),
        
        .led_o(led),

        .rx_i(ftdi_txd),
        .tx_o(ftdi_rxd),

        .sdram_cs_n_o(sdram_csn),
        .sdram_we_n_o(sdram_wen),
        .sdram_ras_n_o(sdram_rasn),
        .sdram_cas_n_o(sdram_casn),
        .sdram_a_o(sdram_a),
        .sdram_ba_o(sdram_ba),
        .sdram_dqm_o(sdram_dqm),
        .sdram_dq_io(sdram_d)
    );


    assign gp[22] = 1'b1; // US3 PULLUP
    assign gn[22] = 1'b1; // US3 PULLUP

/*
    wire vga_hsync, vga_vsync, vga_blank;
    wire [3:0] vga_r, vga_g, vga_b;


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
*/
endmodule
