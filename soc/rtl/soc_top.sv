// soc_top.sv
// Copyright (c) 2023 Daniel Cliche
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

module soc_top(
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
    output      logic [3:0]  vga_r_o,
    output      logic [3:0]  vga_g_o,
    output      logic [3:0]  vga_b_o,
    // PS/2 keyboard
    input  wire logic        ps2clka_i,
    input  wire logic        ps2data_i,
    // PS/2 mouse
    inout       logic        ps2clkb_io,
    inout       logic        ps2datb_io,
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
    // 6  PS2 keyboard / --
    // 7  mouse / --
    // 8  graphite
    
    logic rst_n = 1'b0;
    logic vga_hsync, vga_vsync;
    logic de;

    logic [1:0]  MISO = {1'b1, sd_do_i};
    logic [1:0]  SCLK, MOSI;
    logic [1:0]  SS;
    logic [11:0] RGB;
    logic CE; 
    logic empty;
    logic qready = 1'b0;

    assign sd_di_o   = MOSI[0];
    assign sd_ck_o   = SCLK[0];
    assign sd_cs_n_o = SS[0];

    assign vga_r_o = RGB[11:8];
    assign vga_g_o = RGB[7:4];
    assign vga_b_o = RGB[3:0];
    assign vga_hsync_o = ~vga_hsync;
    assign vga_vsync_o = ~vga_vsync;
    assign vga_blank_o = ~de;

    logic [31:0] adr;
    logic [3:0]  iowadr; // word address
    logic [31:0] inbus, inbus0;  // data to RISC core
    logic [31:0] inbusvid;
    logic [31:0] outbus;  // data from RISC core
    logic rd, wr, ioenb, dspreq;
    logic [3:0]  wmask;

    logic [7:0] dataTx, dataRx, dataKbd;
    logic rdyRx, startTx, rdyTx, rdyKbd;
    logic doneRx;
    logic doneKbd;
    logic [27:0] dataMs;
    logic bitrate;  // for RS232
    logic limit;  // of cnt0

    logic [15:0] cnt0 = 0;
    logic [31:0] cnt1 = 0; // milliseconds

    logic [31:0] spiRx;
    logic spiStart, spiRdy;
    logic [3:0] spiCtrl;
    logic [18:0] vidadr = 0;

    assign iowadr = adr[5:2];
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

    uart_rx uart_rx(.clk(clk_cpu), .rst(rst_n), .RxD(rx_i), .fsel(bitrate), .done(doneRx),
    .data(dataRx), .rdy(rdyRx));
    uart_tx uart_tx(.clk(clk_cpu), .rst(rst_n), .start(startTx), .fsel(bitrate),
    .data(dataTx), .TxD(tx_o), .rdy(rdyTx));
    spi spi(.clk(clk_cpu), .rst(rst_n), .start(spiStart), .dataTx(outbus),
    .fast(spiCtrl[2]), .dataRx(spiRx), .rdy(spiRdy),
        .SCLK(SCLK[0]), .MOSI(MOSI[0]), .MISO(MISO[0] & MISO[1]));
    video video(.clk(clk_cpu), .ce(qready), .pclk(clk_pixel), .req(dspreq),
    .viddata(inbusvid), .de(de), .RGB(RGB), .hsync(vga_hsync), .vsync(vga_vsync));
    ps2kbd ps2kbd(.clk(clk_cpu), .rst(rst_n), .done(doneKbd), .rdy(rdyKbd), .shift(),
    .data(dataKbd), .PS2C(ps2clka_i), .PS2D(ps2data_i));
    logic [2:0] mousebtn;
    ps2mouse
    #(.c_x_bits(10), .c_y_bits(10), .c_y_neg(1), .c_z_ena(0), .c_hotplug(1))
    ps2mouse
    (
    .clk(clk_cpu), .clk_ena(1'b1), .ps2m_reset(~rst_n), .ps2m_clk(ps2clkb_io), .ps2m_dat(ps2datb_io),
    .x(dataMs[9:0]), .y(dataMs[21:12]), .btn(mousebtn)
    );
    assign dataMs[24] = mousebtn[1]; // left
    assign dataMs[25] = mousebtn[2]; // middle
    assign dataMs[26] = mousebtn[0]; // right
    assign dataMs[27] = 1'b1;

    // Graphite
    logic           graphite_cmd_axis_tvalid;
    logic           graphite_cmd_axis_tready;
    logic [31:0]    graphite_cmd_axis_tdata;

    logic graphite_vram_ack;
    logic graphite_vram_sel;
    logic graphite_vram_wr;
    logic [3:0] graphite_vram_mask;
    logic [31:0] graphite_vram_addr;
    logic [15:0] graphite_vram_data_in, graphite_vram_data_out;

    graphite #(
        .FB_WIDTH(640),
        .FB_HEIGHT(480)
    ) graphite(
        .clk(clk_cpu),
        .reset_i(~rst_n),
        .ce_i(CE),

        // AXI stream command interface (slave)
        .cmd_axis_tvalid_i(graphite_cmd_axis_tvalid),
        .cmd_axis_tready_o(graphite_cmd_axis_tready),
        .cmd_axis_tdata_i(graphite_cmd_axis_tdata),

        // VRAM write
        .vram_ack_i(1'b1),
        .vram_sel_o(graphite_vram_sel),
        .vram_wr_o(graphite_vram_wr),
        .vram_mask_o(graphite_vram_mask),
        .vram_addr_o(graphite_vram_addr),
        .vram_data_in_i(inbus0[15:0]),
        .vram_data_out_o(graphite_vram_data_out),

        .vsync_i(),
        .swap_o(),
        .front_addr_o()
    );

    assign inbus = ~ioenb ? inbus0 :
    ((iowadr == 0) ? cnt1 :
        (iowadr == 1) ? {32'b0 } :
        (iowadr == 2) ? {24'b0, dataRx} :
        (iowadr == 3) ? {30'b0, rdyTx, rdyRx} :
        (iowadr == 4) ? spiRx :
        (iowadr == 5) ? {31'b0, spiRdy} :
        (iowadr == 6) ? {3'b0, rdyKbd, dataMs} :
        (iowadr == 7) ? {24'b0, dataKbd} :
        (iowadr == 8) ? {31'b0, graphite_cmd_axis_tready} : 32'd0);

    assign dataTx = outbus[7:0];
    assign startTx = wr & ioenb & (iowadr == 2);
    `ifdef FAST_CPU
    assign limit = (cnt0 == 49999);
    `else
    assign limit = (cnt0 == 24999);
    `endif
    assign spiStart = wr & ioenb & (iowadr == 4);
    assign SS = ~spiCtrl[1:0];  //active low slave select
    assign MOSI[1] = MOSI[0], SCLK[1] = SCLK[0];

    always @(posedge clk_cpu) begin
        doneRx <= 1'b0;
        if (rd & ioenb & (iowadr == 2))
            doneRx <= 1'b1;
    end

    always @(posedge clk_cpu) begin
        doneKbd <= 1'b0;
        if (rd & ioenb & (iowadr == 7))
            doneKbd <= 1'b1;
    end

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
            bitrate <= 1'b0;
            graphite_cmd_axis_tvalid <= 1'b0;
        end else begin
            graphite_cmd_axis_tvalid <= 1'b0;
            if(CE && wr && ioenb) begin
                if (iowadr == 1)
                    led_o <= outbus[7:0];
                else if (iowadr == 3)
                    bitrate <= outbus[0];
                else if (iowadr == 5)
                    spiCtrl <= outbus[3:0];
                else if (iowadr == 8) begin
                    graphite_cmd_axis_tdata  <= outbus[31:0];
                    graphite_cmd_axis_tvalid <= 1'b1;
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
    always_comb begin
        sys_addr = 23'hxxxxx;
        case(cntrl0_user_command_register)
            2'b01: sys_addr = {waddr[16:0], 6'b000000}; // write 256bytes
            2'b10: sys_addr = {1'b1, vidadr[18:0], 3'b000}; // read 32bytes video
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
    logic [1:0] auto_flush = 2'b00;

    logic [31:0] cache_ctrl_adr;
    logic [31:0] cache_ctrl_din;
    logic cache_ctrl_mreq;
    logic [3:0] cache_ctrl_wmask;

    logic process_graphite;
    assign process_graphite = !cpu_sel && !graphite_cmd_axis_tready;

    always_comb begin
        if (process_graphite) begin
            cache_ctrl_adr = 32'h1000000 + {graphite_vram_addr[30:1], 2'b0};
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
         .flush(auto_flush == 2'b01)
    );
    
    logic [15:0] video_din;
    logic        vd1 = 1'b0;
    logic        almost_empty;
    vqueue #(
       .almost_empty(128),
       .addr_width(8)
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
      .Reset(),
      .RPReset()
    );
    
    logic nop;
    always_ff @(posedge clk_sdram) begin
        nop <= sys_cmd_ack == 2'b00;
        if(rst_n && almost_empty) cntrl0_user_command_register <= 2'b10;		// read 32 bytes VGA
        else if(ddr_wr) cntrl0_user_command_register <= 2'b01;		// write 256 bytes cache
        else if(ddr_rd) cntrl0_user_command_register <= 2'b11;		// read 256 bytes cache
        else cntrl0_user_command_register <= 2'b00;
        
        if(nop) case(sys_cmd_ack)
            2'b10: begin
                crw <= 1'b0;	// VGA read
                if(vidadr == 19'd19199) vidadr <= 19'd0; // 640*480*2/32-1
                else vidadr <= vidadr + 1'b1;
            end
            2'b01, 2'b11: crw <= 1'b1;	// cache read/write			
        endcase
        
        if(!crw && sys_rd_data_valid) begin
            vd1 <= !vd1;
            video_din <= sys_DOUT;
        end
    end
    
    always_ff @(posedge clk_pixel) begin
        auto_flush <= {auto_flush[0], vga_vsync};
        qready <= rst_n && !empty;
    end

endmodule
