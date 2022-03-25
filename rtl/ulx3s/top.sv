// top.sv
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

`include "../graphite.svh"

module sdram_ctrl_wrapper #(
    parameter CLK_FREQ_MHZ	= 100,	// sdram_clk freq in MHZ
    parameter POWERUP_DELAY	= 200,	// power up delay in us
    parameter REFRESH_MS	= 64,	// time to wait between refreshes in ms (0 = disable)
    parameter BURST_LENGTH	= 8,	// 0, 1, 2, 4 or 8 (0 = full page)
    parameter ROW_WIDTH	    = 13,	// Row width
    parameter COL_WIDTH	    = 9,	// Column width
    parameter BA_WIDTH	    = 2,	// Ba width
    parameter tCAC		    = 2,	// CAS Latency
    parameter tRAC		    = 5,	// RAS Latency
    parameter tRP		    = 2,	// Command Period (PRE to ACT)
    parameter tRC		    = 7,	// Command Period (REF to REF / ACT to ACT)
    parameter tMRD		    = 2	    // Mode Register Set To Command Delay time
)
(
    // SDRAM interface
    input			        sdram_rst,
    input			        sdram_clk,
    output	[BA_WIDTH-1:0]	ba_o,
    output		            [12:0]  a_o,
    output			        cs_n_o,
    output			        ras_n_o,
    output			        cas_n_o,
    output			        we_n_o,
    output reg	[1:0]	    dqm_o,
    inout  wire	[15:0]	    dq_io,
    output reg	        	dq_oe_o,
    output			        cke_o,

    // Internal interface
    output			        idle_o,
    input		[31:0]	    adr_i,
    output reg	[31:0]	    adr_o,
    input		[15:0]	    dat_i,
    output reg	[15:0]	    dat_o,
    input		[1:0]	    sel_i,
    input			        acc_i,
    output reg		        ack_o,
    input			        we_i
);
    wire [15:0] dq_o;
    reg [15:0] dq_i;

    sdram_ctrl #(
        .CLK_FREQ_MHZ(CLK_FREQ_MHZ),
        .POWERUP_DELAY(POWERUP_DELAY),
        .REFRESH_MS(REFRESH_MS),
        .BURST_LENGTH(BURST_LENGTH),
        .ROW_WIDTH(ROW_WIDTH),
        .COL_WIDTH(COL_WIDTH),
        .BA_WIDTH(BA_WIDTH),
        .tCAC(tCAC),
        .tRAC(tRAC),
        .tRP(tRP),
        .tMRD(tMRD)
    ) sdraw_ctrl(
        .sdram_rst,
        .sdram_clk,
        .ba_o,
        .a_o,
        .cs_n_o,
        .ras_n_o,
        .cas_n_o,
        .we_n_o,
        .dq_o(dq_o),
        .dqm_o,
        .dq_i(dq_i),
        .dq_oe_o,
        .cke_o,

        // Internal interface
        .idle_o,
        .adr_i,
        .adr_o,
        .dat_i,
        .dat_o,
        .sel_i,
        .acc_i,
        .ack_o,
        .we_i        
    );

    always @(posedge sdram_clk)
        dq_i <= dq_io;

    assign dq_io = dq_oe_o ? dq_o : 16'hZZZZ;
    
endmodule

module top(
    input  wire logic       clk_25mhz,

    output      logic [3:0] gpdi_dp,
    output      logic [3:0] gpdi_dn,

    input  wire logic [6:0] btn,

    input  wire logic       ftdi_txd,
    output      logic       ftdi_rxd,

    // SDRAM
    output      logic        sdram_clk,
    output      logic        sdram_cke,
    output      logic        sdram_csn,
    output      logic        sdram_wen,
    output      logic        sdram_rasn,
    output      logic        sdram_casn,
    output      logic [12:0] sdram_a,
    output      logic [1:0]  sdram_ba,
    output      logic [1:0]  sdram_dqm,
    inout       logic [15:0] sdram_d
);

    localparam FB_WIDTH = 128;
    localparam FB_HEIGHT = 128;

    logic clk_pix, clk_1x, clk_10x;
    logic clk_locked;

    // reset
    logic auto_reset;
    logic [5:0] auto_reset_counter = 0;
    logic reset;

    // reset
    assign auto_reset = auto_reset_counter < 5'b11111;
    assign reset = auto_reset || !btn[0];

	always @(posedge clk_pix) begin
        if (clk_locked)
		    auto_reset_counter <= auto_reset_counter + auto_reset;
	end

    pll_ecp5 #(
        .ENABLE_FAST_CLK(0)
    ) pll_main (
        .clk_25m(clk_25mhz),
        .locked(clk_locked),
        .clk_1x(clk_1x),
        .clk_2x(clk_pix),
        .clk_10x(clk_10x)
    );

    // display timings
    localparam CORDW = 16;
    logic signed [CORDW-1:0] sx, sy;
    logic hsync, vsync, de, frame, line;
    
    display_timings_480p #(.CORDW(CORDW)) display_timings_480p(
        .clk_pix(clk_pix),
        .rst(reset),
        .sx(sx),
        .sy(sy),
        .hsync(hsync),
        .vsync(vsync),
        .de(de),
        .frame(frame),
        .line(line)
    );

    logic [3:0] vga_r;                      // vga red (4-bit)
    logic [3:0] vga_g;                      // vga green (4-bits)
    logic [3:0] vga_b;                      // vga blue (4-bits)
    logic       vga_hsync;                  // vga hsync
    logic       vga_vsync;                  // vga vsync
    logic       vga_de;                     // vga data enable


    hdmi_encoder hdmi(
        .pixel_clk(clk_pix),
        .pixel_clk_x5(clk_10x),

        .red({2{vga_r}}),
        .green({2{vga_g}}),
        .blue({2{vga_b}}),

        .vde(vga_de),
        .hsync(vga_hsync),
        .vsync(vga_vsync),

        .gpdi_dp(gpdi_dp),
        .gpdi_dn(gpdi_dn)
    );


    // VGA output
    // 128x128: 14 bits to address 16-bit values
    logic [13:0] vga_read_addr;
    logic [11:0] line_counter, col_counter;
    always_ff @(posedge clk_pix) begin
        vga_hsync <= hsync;
        vga_vsync <= vsync;
        vga_de    <= de;

        if (frame) begin
            col_counter <= 12'd0;
            line_counter <= 12'd0;
            vga_read_addr <= 14'd0;
        end else begin
            if (line) begin
                col_counter  <= 12'd0;
                line_counter <= line_counter + 1;
            end
        end
        

        if (de) begin
            col_counter <= col_counter + 1;
            //if (line_counter < 12'(FB_WIDTH) && col_counter < 12'(FB_HEIGHT)) begin
                vga_read_addr <= vga_read_addr + 1;
                vga_r <= vram_data_out[11:8];
                vga_g <= vram_data_out[7:4];
                vga_b <= vram_data_out[3:0];
            //end else begin
            //    vga_r <= 4'h2;
            //    vga_g <= 4'h2;
            //    vga_b <= 4'h2;
            //end
        end else begin
            vga_r <= 4'h0;
            vga_g <= 4'h0;
            vga_b <= 4'h0;
        end

        if (reset) begin
            vga_read_addr <= 14'd0;
            line_counter  <= 12'd0;
            col_counter   <= 12'd0;
        end
    end

    logic [15:0] vram_data_out;

    logic sdram_dq_oe;

    assign sdram_clk = clk_pix;

    logic sc_idle;
    logic [31:0] sc_adr_in, sc_adr_out;
    logic [15:0] sc_dat_in, sc_dat_out;
    logic sc_acc;
    logic sc_ack;
    logic sc_we;

    sdram_ctrl_wrapper #(
        .CLK_FREQ_MHZ(25),      // sdram_clk freq in MHZ
        .POWERUP_DELAY(200),    // power up delay in us
        .REFRESH_MS(0),         // time to wait between refreshes in ms (0 = disable)
        .BURST_LENGTH(8),       // 0, 1, 2, 4 or 8 (0 = full page)
        .ROW_WIDTH(13),         // Row width
        .COL_WIDTH(9),          // Column width
        .BA_WIDTH(2),           // Ba width
        .tCAC(2),               // CAS Latency
        .tRAC(4),               // RAS Latency
        .tRP(2),                // Command Period (PRE to ACT)
        .tRC(8),                // Command Period (REF to REF / ACT to ACT)
        .tMRD(2)            	// Mode Register Set To Command Delay time
    ) sdram_ctrl (
        // SDRAM interface
        .sdram_rst(reset),
        .sdram_clk(clk_pix),
        .ba_o(sdram_ba),
        .a_o(sdram_a),
        .cs_n_o(sdram_csn),
        .ras_n_o(sdram_rasn),
        .cas_n_o(sdram_casn),
        .we_n_o(sdram_wen),
        .dq_io(sdram_d),
        .dqm_o(sdram_dqm),
        .dq_oe_o(sdram_dq_oe),
        .cke_o(sdram_cke),

        // Internal interface
        .idle_o(sc_idle),
        .adr_i(sc_adr_in),
        .adr_o(sc_adr_out),
        .dat_i(sc_dat_in),
        .dat_o(sc_dat_out),
        .sel_i(2'b11),
        .acc_i(sc_acc),
        .ack_o(sc_ack),
        .we_i(sc_we)
    );

    logic [31:0] adr = 32'd0;
    logic [15:0] dat = 16'hF000;

    enum { WRITE, WAIT_WRITE, READ, WAIT_READ } state;

    always_ff @(posedge clk_pix) begin
        case (state)
            WRITE: begin
                if (sc_idle) begin
                    sc_adr_in <= adr;
                    sc_dat_in <= dat;
                    sc_acc <= 1'b1;
                    sc_we <= 1'b1;
                    state <= WAIT_WRITE;
                end
            end
            WAIT_WRITE: begin
                if (sc_ack) begin
                    sc_acc <= 1'b0;
                    sc_we <= 1'b0;
                    state <= READ;
                end
            end
            READ: begin
                if (sc_idle) begin
                    sc_adr_out <= adr;
                    sc_acc <= 1'b1;
                    sc_we <= 1'b0;
                    state <= WAIT_READ;
                end
            end
            WAIT_READ: begin
                if (sc_ack) begin
                    sc_acc <= 1'b0;
                    vram_data_out <= sc_dat_out;
                    dat[11:0] <= 12'(dat + 1);
                    adr[15:0] <= 16'(adr + 1);
                    state <= WRITE;
                end
            end
        endcase;

        if (frame) begin
            dat[11:0] <= 12'd0;
            adr[15:0] <= 16'd0;
        end

        if (reset) begin
            vram_data_out <= 16'd0;
            state <= WRITE;
        end
    end

/*    

    // video ram

    logic        vram_sel;
    logic        vram_wr;
    logic [3:0]  vram_mask;
    logic [31:0] vram_address;
    logic [15:0] vram_data_in;
    logic [15:0] vram_data_out;

    assign vram_sel = 1'b1;
    assign vram_wr = graphite_vram_sel ? graphite_vram_wr : 1'b0;
    assign vram_mask = graphite_vram_sel ? graphite_vram_mask : 4'hF;
    assign vram_address = graphite_vram_sel ? graphite_vram_address : {2'd0, vga_read_addr};
    assign vram_data_in = graphite_vram_sel ? graphite_vram_data_out : 16'd0;

    ram  #(
        .SIZE(4 * FB_WIDTH * FB_HEIGHT)
    ) vram (
        .clk(clk_pix),
        .sel_i(vram_sel),
        .wr_en_i(vram_wr),
        .wr_mask_i(vram_mask),
        .address_in_i(vram_address),
        .data_in_i(vram_data_in),
        .data_out_o(vram_data_out)
    );

    // graphite
    logic        graphite_tvalid;
    logic        graphite_tready;
    logic [31:0] graphite_tdata;

    logic        graphite_vram_sel;
    logic        graphite_vram_wr;
    logic [3:0]  graphite_vram_mask;
    logic [31:0] graphite_vram_address;
    logic [15:0] graphite_vram_data_out;

    graphite #(
        .FB_WIDTH(FB_WIDTH),
        .FB_HEIGHT(FB_HEIGHT)
    ) graphite (
        .clk(clk_pix),
        .reset_i(reset),
        .cmd_axis_tvalid_i(graphite_tvalid),
        .cmd_axis_tready_o(graphite_tready),
        .cmd_axis_tdata_i(graphite_tdata),
        .vram_sel_o(graphite_vram_sel),
        .vram_wr_o(graphite_vram_wr),
        .vram_mask_o(graphite_vram_mask),
        .vram_addr_o(graphite_vram_address),
        .vram_data_in_i(vram_data_out),
        .vram_data_out_o(graphite_vram_data_out),
        .swap_o()
    );

    logic uart_rd;
    logic [7:0] uart_data;
    logic uart_busy;
    logic uart_valid;

    uart #(.FREQ_MHZ(25)) uart(
        .clk(clk_pix),
        .reset_i(reset),
        .tx_o(ftdi_rxd),
        .rx_i(ftdi_txd),
        .wr_i(1'b0),
        .rd_i(uart_rd),
        .tx_data_i(8'd0),
        .rx_data_o(uart_data),
        .busy_o(uart_busy),
        .valid_o(uart_valid)
    );

    enum { WAIT_B0,WAIT_B1,WAIT_B2, WAIT_B3, WRITE_CMD } state;

    logic [31:0] cmd;
    always_ff @(posedge clk_pix) begin
        case (state)
            WAIT_B0: begin
                uart_rd <= 1'b1;
                graphite_tvalid = 1'b0;
                if (!uart_busy && uart_valid) begin
                    cmd[31:24] <= uart_data;
                    state      <= WAIT_B1;                     
                end
            end
            WAIT_B1: begin
                uart_rd <= 1'b1;
                graphite_tvalid = 1'b0;
                if (!uart_busy && uart_valid) begin
                    cmd[23:16] <= uart_data;
                    state      <= WAIT_B2;
                end
            end
            WAIT_B2: begin
                uart_rd <= 1'b1;
                graphite_tvalid = 1'b0;
                if (!uart_busy && uart_valid) begin
                    cmd[15:8] <= uart_data;
                    state     <= WAIT_B3;
                end
            end
            WAIT_B3: begin
                uart_rd <= 1'b1;
                graphite_tvalid = 1'b0;
                if (!uart_busy && uart_valid) begin
                    cmd[7:0] <= uart_data;
                    state    <= WRITE_CMD;
                end
            end
            WRITE_CMD: begin
                uart_rd <= 1'b0;
                if (graphite_tready) begin
                    graphite_tdata  <= cmd;
                    graphite_tvalid <= 1'b1;
                    state           <= WAIT_B0;
                end
            end
        endcase

        if (reset) begin
            graphite_tvalid <= 1'b0;
            uart_rd         <= 1'b0;
            state           <= WAIT_B0;
        end
    end
*/

endmodule