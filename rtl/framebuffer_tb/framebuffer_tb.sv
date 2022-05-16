// framebuffer_tb.sv
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

module framebuffer_tb;

    logic reset;
    logic clk = 0;
    logic clk2 = 0;
    logic error;

    // SDRAM interface
    logic [1:0]	sdram_ba;
    logic [12:0] sdram_a;
    logic sdram_csn;
    logic sdram_rasn;
    logic sdram_casn;
    logic sdram_wen;
    logic [1:0] sdram_dqm;
    logic [15:0] sdram_dq;
    logic sdram_cke;

    logic ack, sel, wr;
    logic [3:0] mask;
    logic [23:0] address;
    logic [15:0] data_in, data_out;
    logic stream_ena;
    logic [15:0] stream_data;
    logic stream_err_underflow;
    logic stream_start_frame;

    framebuffer #(
        .SDRAM_CLK_FREQ_MHZ(100),
        .FB_WIDTH(32),
        .FB_HEIGHT(32)
    ) framebuffer(
        .clk_pix(clk),
        .reset_i(reset),

        // SDRAM interface
        .sdram_rst(reset),
        .sdram_clk(clk2),
        .sdram_ba_o(sdram_ba),
        .sdram_a_o(sdram_a),
        .sdram_cs_n_o(sdram_cs_n),
        .sdram_ras_n_o(sdram_ras_n),
        .sdram_cas_n_o(sdram_cas_n),
        .sdram_we_n_o(sdram_we_n),
        .sdram_dq_io(sdram_dq),
        .sdram_dqm_o(sdram_dqm),
        .sdram_cke_o(sdram_cke),

        // Framebuffer access
        .ack_o(ack),
        .sel_i(sel),
        .wr_i(wr),
        .mask_i(mask),
        .address_i(address),
        .data_in_i(data_in),
        .data_out_o(data_out),

        // Framebuffer output data stream
        .stream_start_frame_i(stream_start_frame),
        .stream_base_address_i(24'd0),
        .stream_ena_i(stream_ena),
        .stream_data_o(stream_data),
        .stream_preloading_o(),
        .stream_err_underflow_o(stream_err_underflow)
    );

    initial begin
        $dumpfile("framebuffer_tb.vcd");
        $dumpvars(0, framebuffer_tb);
        sel = 1'b0;
        wr = 1'b0;
        mask = 4'hF;
        stream_ena = 1'b0;
        stream_start_frame = 1'b0;
        reset = 1'b1;
        #6
        reset = 1'b0;
        #200
        /*
        // Write BEEF at address 0
        data_in = 16'hBEEF;
        address = 24'd0;
        wr = 1'b1;
        sel = 1'b1;
        #4
        while (!ack)
            #2
        sel = 1'b0;
        wr = 1'b0;
        #200
        
        // Read at address 0
        address = 24'd0;
        sel = 1'b1;
        #4
        while (!ack)
            #2
        sel = 1'b0;
        #200
        */

        stream_start_frame = 1'b1;
        #4
        stream_start_frame = 1'b0;
        #500

        // Enable stream
        stream_ena = 1'b1;
        #200

        // Read at address 0
        /*
        address = 24'd0;
        sel = 1'b1;
        #4
        while (!ack)
            #2
        sel = 1'b0;
        #200
        */

        #2000
        $finish;
    end

    always #2 clk = !clk;
    always #1 clk2 = !clk2;

endmodule
