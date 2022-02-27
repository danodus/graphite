
`include "../graphite.svh"

module top(
    input  wire logic       CLK,
    input  wire logic       BTN_N,
    output      logic       P1A1, P1A2, P1A3, P1A4, P1A7, P1A8, P1A9, P1A10,   // PMOD 1A
    output      logic       P1B1, P1B2, P1B3, P1B4, P1B7, P1B8, P1B9, P1B10,   // PMOD 1B
    input  wire logic       RX,
    output      logic       TX
    );

    logic clk_pix;
    logic clk_locked;

    // reset
    logic auto_reset;
    logic [5:0] auto_reset_counter = 0;
    logic reset;

    // reset
    assign auto_reset = auto_reset_counter < 5'b11111;
    assign reset = auto_reset || !BTN_N;

	always @(posedge clk_pix) begin
        if (clk_locked)
		    auto_reset_counter <= auto_reset_counter + auto_reset;
	end

    // clock gen
    clock_gen_480p clock_gen_480p(
        .clk(CLK),
        .rst(BTN_N),
        .clk_pix(clk_pix),
        .clk_locked(clk_locked)
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

    assign {P1A1, P1A2, P1A3, P1A4, P1A7, P1A8, P1A9, P1A10} =
       {vga_r[0], vga_r[1], vga_r[2], vga_r[3], vga_b[0], vga_b[1], vga_b[2], vga_b[3]};
    assign {P1B1, P1B2, P1B3, P1B4, P1B7, P1B8, P1B9, P1B10} =
       {vga_g[0], vga_g[1], vga_g[2], vga_g[3], vga_hsync, vga_vsync, 1'b0, 1'b0};


    // VGA output
    // 128x128: 14 bits to address 16-bit values
    logic [13:0] vga_read_addr;
    logic [11:0] line_counter, col_counter;
    always_ff @(posedge clk_pix) begin
        vga_hsync <= hsync;
        vga_vsync <= vsync;

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
            if (line_counter < 12'd128 && col_counter < 12'd128) begin
                vga_read_addr <= vga_read_addr + 1;
                vga_r <= vram_data_out[11:8];
                vga_g <= vram_data_out[7:4];
                vga_b <= vram_data_out[3:0];
            end else begin
                vga_r <= 4'h1;
                vga_g <= 4'h1;
                vga_b <= 4'h1;
            end
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

    // video ram

    logic        vram_sel;
    logic        vram_wr;
    logic [3:0]  vram_mask;
    logic [15:0] vram_address;
    logic [15:0] vram_data_in;
    logic [15:0] vram_data_out;

    assign vram_sel = 1'b1;
    assign vram_wr = graphite_vram_sel ? graphite_vram_wr : 1'b0;
    assign vram_mask = graphite_vram_sel ? graphite_vram_mask : 4'hF;
    assign vram_address = graphite_vram_sel ? graphite_vram_address : {2'd0, vga_read_addr};
    assign vram_data_in = graphite_vram_sel ? graphite_vram_data_out : 16'd0;

    ram vram(
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
    logic [15:0] graphite_vram_address;
    logic [15:0] graphite_vram_data_out;

    graphite graphite(
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
        .tx_o(TX),
        .rx_i(RX),
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


endmodule