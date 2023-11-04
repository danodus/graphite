module top (
    input  wire logic       clk,
    input  wire logic       clk_sdram,
    input  wire logic       reset_i,
    output      logic [7:0] display_o,
    input  wire logic       rx_i,
    output      logic       tx_o,

    output logic vga_hsync,
    output logic vga_vsync,
    output logic [3:0] vga_r,
    output logic [3:0] vga_g,
    output logic [3:0] vga_b,

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

    assign sdram_cke_o = 1'b1; // -- SDRAM clock enable

    RISCVTop sys_inst
    (
        .CLK_CPU(clk),
        .CLK_SDRAM(clk_sdram),
        .CLK_PIXEL(clk),
        .RESET(reset_i), // right
        .RX(),   // RS-232
        .TX(),
        .LED(display_o),

        .SD_DO(),          // SPI - SD card & network
        .SD_DI(),
        .SD_CK(),
        .SD_nCS(),

        .VGA_HSYNC(vga_hsync),
        .VGA_VSYNC(vga_vsync),
        .VGA_BLANK(),
        .VGA_R(vga_r),
        .VGA_G(vga_g),
        .VGA_B(vga_b),

        .PS2CLKA(), // keyboard clock
        .PS2DATA(), // keyboard data
        .PS2CLKB(), // mouse clock
        .PS2DATB(), // mouse data

        .SDRAM_nCAS(sdram_cas_n_o),
        .SDRAM_nRAS(sdram_ras_n_o),
        .SDRAM_nCS(sdram_cs_n_o),
        .SDRAM_nWE(sdram_we_n_o),
        .SDRAM_BA(sdram_ba_o),
        .SDRAM_ADDR(sdram_a_o),
        .SDRAM_DATA(sdram_dq_io),
        .SDRAM_DQML(sdram_dqm_o[0]),
        .SDRAM_DQMH(sdram_dqm_o[1])
    );

    initial begin
        //$display("[%0t] Tracing to logs/vlt_dump.vcd...\n", $time);
        //$dumpfile("logs/vlt_dump.vcd");
        //$dumpvars();
    end
    
endmodule