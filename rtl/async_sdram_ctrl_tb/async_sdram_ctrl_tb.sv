// async_sdram_ctrl_tb.sv
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

module async_sdram_ctrl_tb;

    logic reset;
    logic clk = 0;
    logic error;

    // SDRAM interface
    logic [1:0]	sdram_ba;
    logic [12:0] sdram_a;
    logic sdram_csn;
    logic sdram_rasn;
    logic sdram_casn;
    logic sdram_wen;
    logic [1:0] sdram_dqm;
    logic [15:0] sdram_dq_io;
    logic sdram_cke;

    async_sdram_test #(
        .SDRAM_CLK_FREQ_MHZ(100)
    ) async_sdram_test(
        .clk(clk),
        .reset_i(reset),

        // SDRAM interface
        .sdram_rst(reset),
        .sdram_clk(clk),
        .sdram_ba_o(sdram_ba),
        .sdram_a_o(sdram_a),
        .sdram_cs_n_o(sdram_csn),
        .sdram_ras_n_o(sdram_rasn),
        .sdram_cas_n_o(sdram_casn),
        .sdram_we_n_o(sdram_wen),
        .sdram_dq_io(sdram_dq_io),
        .sdram_dqm_o(sdram_dqm),
        .sdram_cke_o(sdram_cke),

        .error_o(error)
    );

    initial begin
        $dumpfile("async_sdram_ctrl_tb.vcd");
        $dumpvars(0, async_sdram_ctrl_tb);
        reset = 1'b1;
        #20
        reset = 1'b0;
        #100000
        $finish;
    end

    always #5 clk = !clk;


endmodule
