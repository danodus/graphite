module top (
    input  wire logic       clk,
    input  wire logic       clk_sdram,
    input  wire logic       reset_i,
    output      logic [7:0] led_o,
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

    gsoc gsoc
    (
        .clk_cpu(clk),
        .clk_sdram(clk_sdram),
        .clk_pixel(clk),
        .reset_i(reset_i),
        
        .led_o(led_o),

        .rx_i(),
        .tx_o(),

        .sdram_cs_n_o(sdram_cs_n_o),
        .sdram_we_n_o(sdram_we_n_o),
        .sdram_ras_n_o(sdram_ras_n_o),
        .sdram_cas_n_o(sdram_cas_n_o),
        .sdram_a_o(sdram_a_o),
        .sdram_ba_o(sdram_ba_o),
        .sdram_dqm_o(sdram_dqm_o),
        .sdram_dq_io(sdram_dq_io)
    );

    initial begin
        //$display("[%0t] Tracing to logs/vlt_dump.vcd...\n", $time);
        //$dumpfile("logs/vlt_dump.vcd");
        //$dumpvars();
    end
    
endmodule