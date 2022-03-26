// sdram_ctrl_tb.sv
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

module sdram_ctrl_tb;

    logic reset;
    logic clk = 0;

    // SDRAM interface
    logic [1:0]	sdram_ba;
    logic [12:0] sdram_a;
    logic sdram_csn;
    logic sdram_rasn;
    logic sdram_casn;
    logic sdram_wen;
    logic [1:0] sdram_dqm;
    logic [15:0] sdram_dq_in, sdram_dq_out;
    logic sdram_dq_oe;
    logic sdram_cke;

    // Internal interface
    logic sc_idle;
    logic [31:0] sc_adr_in = 0;
    logic [31:0] sc_adr_out;
    logic [15:0] sc_dat_in = 0;
    logic [15:0] sc_dat_out;
    logic sc_acc = 0;
    logic sc_ack;
    logic sc_we = 0;

    logic [15:0] vram_data_out;

    sdram_ctrl #(
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
        .sdram_clk(clk),
        .ba_o(sdram_ba),
        .a_o(sdram_a),
        .cs_n_o(sdram_csn),
        .ras_n_o(sdram_rasn),
        .cas_n_o(sdram_casn),
        .we_n_o(sdram_wen),
        .dq_i(sdram_dq_in),
        .dq_o(sdram_dq_out),
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


    enum { WAIT_IDLE, READ, WAIT_READ } state;

    logic [31:0] adr = 32'd0;

    always_ff @(posedge clk) begin
        case (state)
            WAIT_IDLE: begin
                if (sc_idle) state <= READ;
            end  
            READ: begin
                sc_adr_in <= adr;
                sc_acc <= 1'b1;
                sc_we <= 1'b0;
                state <= WAIT_READ;
            end
            WAIT_READ: begin
                vram_data_out <= sc_dat_out;
                if (sc_ack) begin
                    adr[15:0] <= 16'(adr + 16);
                    sc_acc <= 1'b0;
                    state <= READ;
                end
            end
        endcase;

        if (reset) begin
            vram_data_out <= 16'd0;
            state <= WAIT_IDLE;
        end
    end

    initial begin
        $dumpfile("sdram_ctrl_tb.vcd");
        $dumpvars(0, sdram_ctrl_tb);
        reset = 1'b1;
        #20
        reset = 1'b0;
        #100000
        $finish;
    end

    always #5 clk = !clk;


endmodule
