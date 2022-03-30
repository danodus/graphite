// top.sv
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

`include "../graphite.svh"

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

    logic clk_pix, clk_pix_x5, clk_sdram;
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

    pll pll (
        .clkin(clk_25mhz),
        .locked(clk_locked),
        .clkout0(clk_pix_x5),
        .clkout2(clk_pix),
        .clkout3(clk_sdram)
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
        .pixel_clk_x5(clk_pix_x5),

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

    assign sdram_clk = clk_sdram;

    logic [15:0] vram_data_out;
    logic error;

    assign vram_data_out = error ? 16'hFF00 : 16'hF0F0;

    sdram_test #(
        .SDRAM_CLK_FREQ_MHZ(52)
    ) sdram_test(
        // SDRAM interface
        .sdram_rst(reset),
        .sdram_clk(clk_sdram),
        .sdram_ba_o(sdram_ba),
        .sdram_a_o(sdram_a),
        .sdram_cs_n_o(sdram_csn),
        .sdram_ras_n_o(sdram_rasn),
        .sdram_cas_n_o(sdram_casn),
        .sdram_we_n_o(sdram_wen),
        .sdram_dq_io(sdram_d),
        .sdram_dqm_o(sdram_dqm),
        .sdram_cke_o(sdram_cke),

        .error_o(error)
    );

/*

    logic [40:0] writer_d;
    logic writer_enq;
    logic writer_full;

    logic [15:0] reader_q;
    logic reader_deq;
    logic reader_empty;    

    async_sdram_ctrl #(
        .SDRAM_CLK_FREQ_MHZ(52)
    ) async_sdram_ctrl(
        // SDRAM interface
        .sdram_rst(reset),
        .sdram_clk(clk_sdram),
        .ba_o(sdram_ba),
        .a_o(sdram_a),
        .cs_n_o(sdram_csn),
        .ras_n_o(sdram_rasn),
        .cas_n_o(sdram_casn),
        .we_n_o(sdram_wen),
        .dq_io(sdram_d),
        .dqm_o(sdram_dqm),
        .cke_o(sdram_cke),

        // Writer (input commands)
        .writer_clk(clk_pix),
        .writer_rst_i(reset),
        .writer_d_i(writer_d),
        .writer_enq_i(writer_enq),    // enqueue
        .writer_full_o(writer_full),
        .writer_alm_full_o(),

        // Reader (output)
        .reader_clk(clk_pix),
        .reader_rst_i(reset),
        .reader_q_o(reader_q),
        .reader_deq_i(reader_deq),    // dequeue
        .reader_empty_o(reader_empty),
        .reader_alm_empty_o()
    );

    enum {IDLE, WRITE0, READ0, READ1} state;

    always_ff @(posedge clk_pix) begin
        if (reset) begin
            vram_data_out <= 16'hF555;
            writer_enq <= 1'b0;
            reader_deq <= 1'b0;
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    if (!writer_full) begin
                        // write command
                        writer_d <= {1'b1, 24'h0, 16'hBEEF};
                        writer_enq <= 1'b1;
                        state <= WRITE0;
                    end
                end
                WRITE0: begin
                    writer_enq = 1'b0;
                    if (!writer_full) begin
                        // read command
                        writer_d <= {1'b0, 24'h0, 16'h0};
                        writer_enq <= 1'b1;
                        state <= READ0;
                    end
                end
                READ0: begin
                    writer_enq <= 1'b0;
                    if (!reader_empty) begin
                        reader_deq = 1'b1;
                        state <= READ1;
                    end
                end

                READ1: begin
                    reader_deq <= 1'b0;
                    if (reader_q != 16'hBEEF) begin
                        // error - red
                        vram_data_out <= 16'hFF00;
                    end else begin
                        // success - green
                        vram_data_out <= 16'hF0F0;
                    end
                    state <= IDLE;
                end
            endcase
        end
    end
*/

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