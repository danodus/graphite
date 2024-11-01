// soc_top.sv
// Copyright (c) 2023-2024 Daniel Cliche
// SPDX-License-Identifier: MIT

/*
Project Oberon, Revised Edition 2013

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
CONNECTION WITH THE DEALINGS IN OR USE OR PERFORMANCE OF THE SOFTWARE.
*/

// NW 22.9.2015 / OberonStation ver 3.10.15 PDR
// with SRAM, byte access, flt.-pt., and gpio
// PS/2 mouse and network 7.1.2014 PDR
// Modified for SDRAM - Nicolae Dumitrache 2016: +cache (16KB, 4-way 8-set), +SDRAM interface (100Mhz)

module soc_top #(
    parameter FREQ_HZ = 25_000_000,
    parameter BAUD_RATE = 115_200,
    parameter DEFAULT_FB_ADDRESS = 32'h1000000
) (
    input  wire logic        clk_cpu,
    input  wire logic        clk_sdram,
    input  wire logic        clk_pixel,
    input  wire logic        reset_i,
    // UART
    input  wire logic        rx_i,
    output      logic        tx_o,
    // LED
    output      logic [7:0]  led_o,
    // SD card
    input  wire logic        sd_do_i,
    output      logic        sd_di_o,
    output      logic        sd_ck_o,
    output      logic        sd_cs_n_o,
    // VGA video
    output      logic        vga_hsync_o,
    output      logic        vga_vsync_o,
    output      logic        vga_blank_o,
    output      logic [7:0]  vga_r_o,
    output      logic [7:0]  vga_g_o,
    output      logic [7:0]  vga_b_o,
    // USB
    input  wire logic        usb_fpga_dp,     // D differential in
    inout  wire logic        usb_fpga_bd_dp,  // D+
    inout  wire logic        usb_fpga_bd_dn,  // D-
    inout  wire logic        usb_fpga_pu_dp,  // 1 = 1.5K up, 0 = 15K down, z = float
    inout  wire logic        usb_fpga_pu_dn,  // 1 = 1.5K up, 0 = 15K down, z = float
    // SDRAM
    output      logic        sdram_cas_n_o,
    output      logic        sdram_ras_n_o,
    output      logic        sdram_cs_n_o,
    output      logic        sdram_we_n_o,
    output      logic [1:0]  sdram_ba_o,
    output      logic [12:0] sdram_addr_o,
    inout       logic [15:0] sdram_data_io,
    output wire logic [1:0]  sdram_dqm_o
);

    // IO addresses for input / output
    // 0  milliseconds / --
    // 1  LEDs
    // 2  RS-232 data / RS-232 data (start)
    // 3  RS-232 status / RS-232 control
    // 4  SPI data / SPI data (start)
    // 5  SPI status / SPI control
    // 6  reserved
    // 7  reserved
    // 8  graphite
    // 9  -- / H resolution, V resolution
    
`ifdef VIDEO_480P
    localparam H_RES = 848;
    localparam V_RES = 480;
    localparam H_POL = 1;
    localparam V_POL = 1;
`elsif VIDEO_720P
    localparam H_RES = 1280;
    localparam V_RES = 720;
    localparam H_POL = 1;
    localparam V_POL = 1;
`elsif VIDEO_1080P
    localparam H_RES = 1920;
    localparam V_RES = 1080;
    localparam H_POL = 1;
    localparam V_POL = 1;
`else // VGA
    localparam H_RES = 640;
    localparam V_RES = 480;
    localparam H_POL = 0;
    localparam V_POL = 0;
`endif

    logic rst_n = 1'b0;
    logic vga_hsync, vga_vsync;
    logic de;

    logic [1:0]  MISO = {1'b1, sd_do_i};
    logic [1:0]  SCLK, MOSI;
    logic [1:0]  SS;
    logic [15:0] RGB565;
    logic [23:0] RGB888;
    logic CE; 
    logic empty;
    logic qready = 1'b0;
    logic req_flush_cache;

    assign sd_di_o   = MOSI[0];
    assign sd_ck_o   = SCLK[0];
    assign sd_cs_n_o = SS[0];

    assign vga_r_o = RGB888[23:16];
    assign vga_g_o = RGB888[15:8];
    assign vga_b_o = RGB888[7:0];

    assign vga_hsync_o = H_POL ? vga_hsync : ~vga_hsync;
    assign vga_vsync_o = V_POL ? vga_vsync : ~vga_vsync;
    assign vga_blank_o = ~de;

    rgb565_to_rgb888 rgb565_to_rgb888(
        .rgb565_i(RGB565),
        .rgb888_o(RGB888)
    );

    logic [31:0] adr;
    logic [4:0]  iowadr; // word address
    logic [31:0] inbus, inbus0;  // data to RISC core
    logic [31:0] inbusvid;
    logic [31:0] outbus;  // data from RISC core
    logic rd, wr, ioenb, dspreq;
    logic [3:0]  wmask;

    logic [7:0] dataTx, dataRx;
    logic rdyTx, rdyRx, uartDequeue;
    logic startTx;
    logic doneRx;
    logic limit;  // of cnt0

    logic [16:0] cnt0 = 0;
    logic [31:0] cnt1 = 0; // milliseconds

    logic [31:0] spiRx;
    logic spiStart, spiRdy;
    logic [3:0] spiCtrl;
    logic [19:0] vidadr = 0;

    assign iowadr = adr[6:2];
    assign ioenb = (adr[31:28] == 4'hE);
    logic mreq = !ioenb && !pm_sel;

    logic cpu_we, cpu_sel;
    assign rd = cpu_sel && !pm_sel && !cpu_we;
    assign wr = cpu_sel && !pm_sel && cpu_we;

    logic [31:0] pmout;
    prom prom(.adr(adr[10:2]), .data(pmout), .clk(clk_cpu), .ce(CE));

    logic pm_sel = adr[31:28] == 4'hF;

    processor cpu(
        .clk(clk_cpu),
        .reset_i(~rst_n),
        .ce_i(CE && !process_graphite),

        // interrupts (2)
        .irq_i(2'b00),
        .eoi_o(),

        // memory
        .sel_o(cpu_sel),
        .addr_o(adr),
        .we_o(cpu_we),
        .wr_mask_o(wmask),
        .data_in_i(pm_sel ? pmout : inbus),
        .data_out_o(outbus),
        .ack_i(1'b1)
    );

    //
    // UART
    //

    logic uart_tx_strobe;
    logic [7:0] uart_tx_data;
    logic [7:0] uart_rx_data;
    logic uart_valid;
    logic uart_wr;

    logic uart_enq;
    logic uart_deq;
    logic uart_fifo_empty;

    assign rdyRx = ~uart_fifo_empty;

    fifo #(
        .ADDR_LEN(10),
        .DATA_WIDTH(8)
    ) uart_fifo(
        .clk(clk_cpu),
        .reset_i(~rst_n),
        .reader_q_o(uart_code),
        .reader_deq_i(uart_deq),
        .reader_empty_o(uart_fifo_empty),
        .reader_alm_empty_o(),

        .writer_d_i(uart_rx_data),
        .writer_enq_i(uart_enq),
        .writer_full_o(),
        .writer_alm_full_o()
    );

    uart_rx #(.FREQ_HZ(FREQ_HZ), .BAUD_RATE(BAUD_RATE)) uart_rx(.clk(clk_cpu), .rst(rst_n), .RxD(rx_i), .fsel(1'b0), .done(doneRx),
    .data(uart_rx_data), .rdy(uart_valid));
    uart_tx #(.FREQ_HZ(FREQ_HZ), .BAUD_RATE(BAUD_RATE)) uart_tx(.clk(clk_cpu), .rst(rst_n), .start(uart_wr), .fsel(1'b0),
    .data(uart_tx_data), .TxD(tx_o), .rdy(rdyTx));

    logic [7:0] uart_code;
    always_ff @(posedge clk_cpu) begin
        if (~rst_n) begin
            uart_enq     <= 1'b0;
            uart_deq     <= 1'b0;
            uart_tx_data <= 8'd0;
            uart_wr      <= 1'b0;
            doneRx       <= 1'b0;
        end begin
            doneRx <= 1'b0;
            uart_enq <= 1'b0;
            if (uart_deq) begin
                uart_deq <= 1'b0;
                dataRx <= uart_code; 
            end
            if (uartDequeue) begin
                if (!uart_fifo_empty) begin
                    uart_deq <= 1'b1;
                end
            end
            if (uart_valid && !doneRx) begin
                doneRx <= 1'b1;
                uart_enq <= 1'b1;
            end
        end

        if (startTx) begin
            uart_tx_data <= dataTx;
            uart_wr <= 1'b1;
        end else begin
            uart_wr <= 1'b0;
        end
    end

    spi #(.FREQ_HZ(FREQ_HZ)) spi(.clk(clk_cpu), .rst(rst_n), .start(spiStart), .dataTx(outbus),
    .fast(spiCtrl[2]), .dataRx(spiRx), .rdy(spiRdy),
        .SCLK(SCLK[0]), .MOSI(MOSI[0]), .MISO(MISO[0] & MISO[1]));
    video #(
        .H_RES(H_RES),  // horizontal resolution (pixels)
        .V_RES(V_RES),  // vertical resolution (lines)
`ifdef VIDEO_480P
        .CORDW(11),   // signed coordinate width (bits)
        .H_FP(16),    // horizontal front porch
        .H_SYNC(112), // horizontal sync
        .H_BP(112),   // horizontal back porch
        .V_FP(6),     // vertical front porch
        .V_SYNC(8),   // vertical sync
        .V_BP(23)     // vertical back porch
`elsif VIDEO_720P
        .CORDW(11),   // signed coordinate width (bits)
        .H_FP(110),   // horizontal front porch
        .H_SYNC(40),  // horizontal sync
        .H_BP(220),   // horizontal back porch
        .V_FP(5),     // vertical front porch
        .V_SYNC(5),   // vertical sync
        .V_BP(20)     // vertical back porch
`elsif VIDEO_1080P
        .CORDW(12),   // signed coordinate width (bits)
        .H_FP(88),    // horizontal front porch
        .H_SYNC(44),  // horizontal sync
        .H_BP(148),   // horizontal back porch
        .V_FP(4),     // vertical front porch
        .V_SYNC(5),   // vertical sync
        .V_BP(36)     // vertical back porch
`else
        .CORDW(11),   // signed coordinate width (bits)
        .H_FP(16),    // horizontal front porch
        .H_SYNC(96),  // horizontal sync
        .H_BP(48),    // horizontal back porch
        .V_FP(10),    // vertical front porch
        .V_SYNC(2),   // vertical sync
        .V_BP(33)     // vertical back porch
`endif
    )video(.clk(clk_cpu), .ce(qready), .pclk(clk_pixel), .req(dspreq),
    .viddata(inbusvid), .de(de), .RGB(RGB565), .hsync(vga_hsync), .vsync(vga_vsync));

    // USB host PHY + SIE hardware
    logic [31:0] sie_di;

    logic utmi_txvalid, utmi_txready, utmi_rxvalid, utmi_rxactive, utmi_rxerror;
    logic utmi_termselect, utmi_dppulldown, utmi_dmpulldown;
    logic [1:0] utmi_linestate, utmi_op_mode, utmi_xcvrselect;
    logic [7:0] utmi_data_out, utmi_data_in;

    PHY utmi_phy (
        .clk_i(clk_cpu),
        .rst_i(~rst_n),

        .utmi_data_out_i(utmi_data_out),
        .utmi_txvalid_i(utmi_txvalid),
        .utmi_txready_o(utmi_txready),

        .utmi_data_in_o(utmi_data_in),
        .utmi_rxvalid_o(utmi_rxvalid),
        .utmi_rxactive_o(utmi_rxactive),
        .utmi_rxerror_o(utmi_rxerror),
        .utmi_linestate_o(utmi_linestate),

        .utmi_op_mode_i(utmi_op_mode),
        .utmi_xcvrselect_i(utmi_xcvrselect),
        .utmi_termselect_i(utmi_termselect),
        .utmi_dppulldown_i(utmi_dppulldown),
        .utmi_dmpulldown_i(utmi_dmpulldown),

        .usb_fpga_dif(usb_fpga_dp),
        .usb_fpga_dp(usb_fpga_bd_dp),
        .usb_fpga_dn(usb_fpga_bd_dn),
        .usb_fpga_pu_dp(usb_fpga_pu_dp),
        .usb_fpga_pu_dn(usb_fpga_pu_dn)
    );

    REGS usb_regs (
        .clk_i(clk_cpu),
        .rst_i(~rst_n),
        .led_o(),

        .m_sel(ioenb & adr[6]),
        .m_addr(adr[5:2]),
        .m_data_i(outbus),
        .m_data_o(sie_di),
        .m_rd(rd),
        .m_wr(wr),
        .m_intr_o(),

        .utmi_data_in_i(utmi_data_in),
        .utmi_rxvalid_i(utmi_rxvalid),
        .utmi_rxactive_i(utmi_rxactive),
        .utmi_rxerror_i(utmi_rxerror),
        .utmi_linestate_i(utmi_linestate),

        .utmi_data_out_o(utmi_data_out),
        .utmi_txvalid_o(utmi_txvalid),
        .utmi_txready_i(utmi_txready),

        .utmi_op_mode_o(utmi_op_mode),
        .utmi_xcvrselect_o(utmi_xcvrselect),
        .utmi_termselect_o(utmi_termselect),
        .utmi_dppulldown_o(utmi_dppulldown),
        .utmi_dmpulldown_o(utmi_dmpulldown)
    );   

    logic [31:0]    fb_addr;     

    // Graphite
    logic           graphite_cmd_axis_tvalid;
    logic           graphite_cmd_axis_tready;
    logic [31:0]    graphite_cmd_axis_tdata;

    logic graphite_vram_sel;
    logic graphite_vram_wr;
    logic [3:0] graphite_vram_mask;
    logic [31:0] graphite_vram_addr;
    logic [15:0] graphite_vram_data_in, graphite_vram_data_out;
    logic [31:0] graphite_front_addr;
    logic graphite_clear;
    logic graphite_swap;
    logic use_graphite_front_addr;

    graphite #(
        .FB_ADDRESS(DEFAULT_FB_ADDRESS >> 'd1),
        .FB_WIDTH(H_RES),
        .FB_HEIGHT(V_RES)
    ) graphite(
        .clk(clk_cpu),
        .reset_i(~rst_n),
        .ce_i(CE),

        // AXI stream command interface (slave)
        .cmd_axis_tvalid_i(graphite_cmd_axis_tvalid),
        .cmd_axis_tready_o(graphite_cmd_axis_tready),
        .cmd_axis_tdata_i(graphite_cmd_axis_tdata),

        // VRAM write
        .vram_sel_o(graphite_vram_sel),
        .vram_wr_o(graphite_vram_wr),
        .vram_mask_o(graphite_vram_mask),
        .vram_addr_o(graphite_vram_addr),
        .vram_data_in_i(graphite_vram_addr[0] ? inbus0[31:16] : inbus0[15:0]),
        .vram_data_out_o(graphite_vram_data_out),

        .vsync_i(vga_vsync),
        .swap_o(graphite_swap),
        .front_addr_o(graphite_front_addr),
        .clear_o(graphite_clear)
    );

    assign inbus = ~ioenb ? inbus0 :
    ((iowadr == 0) ? cnt1 :
        (iowadr == 1) ? {32'b0 } :
        (iowadr == 2) ? {24'b0, dataRx} :
        (iowadr == 3) ? {30'b0, rdyTx, rdyRx} :
        (iowadr == 4) ? spiRx :
        (iowadr == 5) ? {31'b0, spiRdy} :
        (iowadr == 6) ? {32'b0} :
        (iowadr == 7) ? {32'b0} :
        (iowadr == 8) ? {31'b0, graphite_cmd_axis_tready} :
        (iowadr == 9) ? {16'(H_RES), 16'(V_RES)} :
        (iowadr == 10) ? fb_addr :
        (iowadr == 11) ? {31'b0, vga_vsync} :
        (iowadr >= 16 && iowadr < 32) ? sie_di : 32'd0);

    assign dataTx = outbus[7:0];
    assign startTx = wr & ioenb & (iowadr == 2);
    assign uartDequeue = wr & ioenb & (iowadr == 3);
    assign limit = (cnt0 == FREQ_HZ / 1000 - 1);
    assign spiStart = wr & ioenb & (iowadr == 4);
    assign SS = ~spiCtrl[1:0];  //active low slave select
    assign MOSI[1] = MOSI[0], SCLK[1] = SCLK[0];

    // Auto reset and counter
    always_ff @(posedge clk_cpu) begin
    `ifdef SYNTHESIS
        rst_n <= ((cnt1[4:0] == 0) & limit) ? ~reset_i : rst_n;
    `else // SYNTHESIS
        rst_n <= ~reset_i;
    `endif // SYNTHESIS
        cnt0 <= limit ? 0 : cnt0 + 1;
        cnt1 <= cnt1 + limit;
    end

    // IO write
    always_ff @(posedge clk_cpu) begin
        if (~rst_n) begin
            led_o <= 8'd0;
            spiCtrl <= 4'd0;
            graphite_cmd_axis_tvalid <= 1'b0;
            req_flush_cache <= 1'b0;
            fb_addr <= DEFAULT_FB_ADDRESS;
            use_graphite_front_addr <= 1'b0;
        end else begin
            graphite_cmd_axis_tvalid <= 1'b0;
            req_flush_cache <= 1'b0;
            if(CE && wr && ioenb) begin
                if (iowadr == 1)
                    led_o <= outbus[7:0];
                else if (iowadr == 5)
                    spiCtrl <= outbus[3:0];
                else if (iowadr == 8) begin
                    graphite_cmd_axis_tdata  <= outbus[31:0];
                    graphite_cmd_axis_tvalid <= 1'b1;
                    use_graphite_front_addr <= 1'b1;    // Graphite will handle the fb address
                end else if (iowadr == 9) begin
                    if (outbus[0])
                        req_flush_cache <= 1'b1;
                end else if (iowadr == 10) begin
                    fb_addr <= outbus[31:0];
                    use_graphite_front_addr <= 1'b0;
                end
            end
        end
    end

    logic [1:0]  cntrl0_user_command_register;
    logic [15:0] cntrl0_user_input_data;
    logic [15:0] sys_DOUT;
    logic        sys_rd_data_valid;
    logic        sys_wr_data_valid;
    logic [1:0]  sys_cmd_ack;
    logic        crw = 1'b0;
    logic [17:0] waddr;

    logic [22:0] sys_addr;
    logic [19:0] front_vidadr;
    assign front_vidadr = (use_graphite_front_addr ? graphite_front_addr[23:4] : fb_addr[24:5]) + vidadr;
    always_comb begin
        sys_addr = 23'hxxxxx;
        case(cntrl0_user_command_register)
            2'b01: sys_addr = {waddr[16:0], 6'b000000}; // write 256bytes
            2'b10: sys_addr = {front_vidadr, 3'b000}; // read 32bytes video
            2'b11: sys_addr = {cache_ctrl_adr[24:8], 6'b000000}; // read 256bytes	
        endcase
    end

    SDRAM_16bit SDR
    (
        .sys_CLK(clk_sdram),				// clock
        .sys_CMD(cntrl0_user_command_register),					// 00=nop, 01 = write 256 bytes, 10=read 32 bytes, 11=read 256 bytes
        .sys_ADDR(sys_addr),	// word address
        .sys_DIN(cntrl0_user_input_data),		// data input
        .sys_DOUT(sys_DOUT),					// data output
        .sys_rd_data_valid(sys_rd_data_valid),	// data valid read
        .sys_wr_data_valid(sys_wr_data_valid),	// data valid write
        .sys_cmd_ack(sys_cmd_ack),			// command acknowledged
        
        .sdr_n_CS_WE_RAS_CAS({sdram_cs_n_o, sdram_we_n_o, sdram_ras_n_o, sdram_cas_n_o}),			// SDRAM #CS, #WE, #RAS, #CAS
        .sdr_BA(sdram_ba_o),					// SDRAM bank address
        .sdr_ADDR(sdram_addr_o),				// SDRAM address
        .sdr_DATA(sdram_data_io),				// SDRAM data
        .sdr_DQM(sdram_dqm_o)					// SDRAM DQM
    );
    
    logic ddr_rd;
    logic ddr_wr;

    logic [31:0] cache_ctrl_adr;
    logic [31:0] cache_ctrl_din;
    logic cache_ctrl_mreq;
    logic [3:0] cache_ctrl_wmask;

    logic process_graphite;
    assign process_graphite = !cpu_sel && !graphite_cmd_axis_tready;

    always_comb begin
        if (process_graphite) begin
            cache_ctrl_adr = {graphite_vram_addr[31:1], 2'b0};
            cache_ctrl_din = {graphite_vram_data_out, graphite_vram_data_out};
            //cache_ctrl_din = {16'd0, graphite_vram_data_out};
            cache_ctrl_mreq = graphite_vram_sel;
            cache_ctrl_wmask = graphite_vram_addr[0] ? {{2{graphite_vram_wr}}, 2'b0} : {2'b0, {2{graphite_vram_wr}}};
            //cache_ctrl_wmask = {4{graphite_vram_wr}};
        end else begin
            cache_ctrl_adr = adr;
            cache_ctrl_din = outbus;
            cache_ctrl_mreq = mreq;
            cache_ctrl_wmask = wmask & {4{wr}};
        end
    end

    cache_controller cache_ctrl 
    (
         .addr(cache_ctrl_adr[25:0]), 
         .dout(inbus0), 
         .din(cache_ctrl_din), 
         .clk(clk_cpu),
         .mreq(cache_ctrl_mreq), 
         .wmask(cache_ctrl_wmask),
         .ce(CE), 
         .ddr_din(sys_DOUT), 
         .ddr_dout(cntrl0_user_input_data), 
         .ddr_clk(clk_sdram), 
         .ddr_rd(ddr_rd), 
         .ddr_wr(ddr_wr),
         .waddr(waddr),
         .cache_write_data(crw && sys_rd_data_valid), // read DDR, write to cache
         .cache_read_data(crw && sys_wr_data_valid),
         .flush(graphite_swap | req_flush_cache),
         .clear(graphite_clear)
    );
    
    logic [15:0] video_din;
    logic        vd1 = 1'b0;
    logic        almost_empty, almost_empty2;
    vqueue #(
       .almost_empty(128),
       .almost_empty2(512),
       .addr_width(10)
    ) vqueue_inst(
      .WrClock(clk_sdram), // input wr_clk
      .RdClock(clk_pixel), // input rd_clk
      .Data({sys_DOUT, video_din}), // input [31 : 0] din
      .WrEn(vd1), // input wr_en
      .RdEn(dspreq), // input rd_en
      .Q(inbusvid), // output [31 : 0] dout
      .Full(), // output full
      .Empty(empty), // output empty
      .AlmostFull(),
      .AlmostEmpty(almost_empty), // output prog_empty
      .AlmostEmpty2(almost_empty2),
      .Reset(),
      .RPReset()
    );
    
    logic nop;
    always_ff @(posedge clk_sdram) begin
        nop <= sys_cmd_ack == 2'b00;
        if(almost_empty2) cntrl0_user_command_register <= 2'b10;		// read 32 bytes VGA
        else if(ddr_wr) cntrl0_user_command_register <= 2'b01;		// write 256 bytes cache
        else if(ddr_rd) cntrl0_user_command_register <= 2'b11;		// read 256 bytes cache
        else cntrl0_user_command_register <= 2'b00;
        
        if(nop) case(sys_cmd_ack)
            2'b10: begin
                crw <= 1'b0;	// VGA read
                if(vidadr == 20'(H_RES*V_RES*2/32-1)) vidadr <= 20'd0;
                else vidadr <= vidadr + 20'b1;
            end
            2'b01, 2'b11: crw <= 1'b1;	// cache read/write			
        endcase
        
        if(!crw && sys_rd_data_valid) begin
            vd1 <= !vd1;
            video_din <= sys_DOUT;
        end
    end
    
    logic video_ready = 1'b0;

    always_ff @(posedge clk_pixel) begin
        if (rst_n)
            video_ready <= 1'b1;
        qready <= video_ready && !almost_empty;
    end

endmodule
