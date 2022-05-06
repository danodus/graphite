// async_sdram_test.sv
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

module async_sdram_test #(
    parameter SDRAM_CLK_FREQ_MHZ	= 100 	// sdram clk freq in MHZ
) (
    input wire logic clk,
    input wire logic reset_i,

    // SDRAM interface
    input  wire logic                   sdram_rst,
    input  wire logic                   sdram_clk,
    output	    logic [1:0]	            sdram_ba_o,
    output	    logic [12:0]            sdram_a_o,
    output	    logic                   sdram_cs_n_o,
    output      logic                   sdram_ras_n_o,
    output      logic                   sdram_cas_n_o,
    output	    logic                   sdram_we_n_o,
    output      logic [1:0]	            sdram_dqm_o,
    inout  wire	logic [15:0]	        sdram_dq_io,
    output      logic                   sdram_cke_o,

    output logic error_o
);


    logic [40:0] writer_d;
    logic writer_enq;
    logic writer_full;

    logic [15:0] reader_q;
    logic reader_deq;
    logic reader_empty;    

    logic [127:0] reader_burst_q;
    logic reader_burst_deq;
    logic reader_burst_empty;    

    async_sdram_ctrl #(
        .SDRAM_CLK_FREQ_MHZ(SDRAM_CLK_FREQ_MHZ)
    ) async_sdram_ctrl(
        // SDRAM interface
        .sdram_rst(sdram_rst),
        .sdram_clk(sdram_clk),
        .ba_o(sdram_ba_o),
        .a_o(sdram_a_o),
        .cs_n_o(sdram_cs_n_o),
        .ras_n_o(sdram_ras_n_o),
        .cas_n_o(sdram_cas_n_o),
        .we_n_o(sdram_we_n_o),
        .dq_io(sdram_dq_io),
        .dqm_o(sdram_dqm_o),
        .cke_o(sdram_cke_o),

        // Writer (input commands)
        .writer_clk(clk),
        .writer_rst_i(reset_i),
        .writer_d_i(writer_d),
        .writer_enq_i(writer_enq),    // enqueue
        .writer_full_o(writer_full),
        .writer_alm_full_o(),

        // Reader
        .reader_clk(clk),
        .reader_rst_i(reset_i),

        // Reader (output)
        .reader_q_o(reader_q),
        .reader_deq_i(reader_deq),    // dequeue
        .reader_empty_o(reader_empty),
        .reader_alm_empty_o(),

        .reader_burst_q_o(reader_burst_q),
        .reader_burst_deq_i(reader_burst_deq),    // dequeue
        .reader_burst_empty_o(reader_burst_empty),
        .reader_burst_alm_empty_o()
    );

    enum {IDLE, WRITE0, WRITE0B, WRITE0C, WRITE1, WRITE1B, READ0, READ0B, READ1} state;

    always_ff @(posedge clk) begin
        if (reset_i) begin
            error_o <= 1'b0;
            writer_enq <= 1'b0;
            reader_deq <= 1'b0;
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    if (!writer_full) begin
                        // write command
                        writer_d <= {1'b1, 24'h1000, 16'h1000};
                        writer_enq <= 1'b1;
                        state <= WRITE0;
                    end
                end
                WRITE0: begin
                    writer_enq = 1'b0;
                    state <= WRITE0B;
                end

                WRITE0B: begin
                    if (!writer_full) begin
                        // write command
                        writer_d <= {1'b1, 24'h2000, 16'h2000};
                        writer_enq <= 1'b1;
                        state <= WRITE0C;
                    end
                end
                WRITE0C: begin
                    writer_enq = 1'b0;
                    state <= WRITE1;
                end

                WRITE1: begin
                    if (!writer_full) begin
                        // read command
                        writer_d <= {1'b0, 24'h1000, 16'h0};
                        writer_enq <= 1'b1;
                        state <= WRITE1B;
                    end
                end

                WRITE1B: begin
                    writer_enq <= 1'b0;
                    state <= READ0;
                end

                READ0: begin
                    writer_enq <= 1'b0;
                    if (!reader_empty) begin
                        reader_deq = 1'b1;
                        state <= READ0B;
                    end
                end

                READ0B: begin
                    reader_deq = 1'b0;
                    state <= READ1;
                end

                READ1: begin
                    if (reader_q != 16'h1000) begin
                        // error
                        error_o <= 1'b1;
                    end else begin
                        // success
                        error_o <= 1'b0;
                    end
                    state <= IDLE;
                end
            endcase
        end
    end


endmodule