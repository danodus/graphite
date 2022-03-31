// async_sdram_ctrl.sv
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

module async_sdram_ctrl #(
    parameter SDRAM_CLK_FREQ_MHZ	= 100 	// sdram clk freq in MHZ
) (
    // SDRAM interface
    input  wire logic                   sdram_rst,
    input  wire logic                   sdram_clk,
    output	    logic [1:0]	            ba_o,
    output	    logic [12:0]            a_o,
    output	    logic                   cs_n_o,
    output      logic                   ras_n_o,
    output      logic                   cas_n_o,
    output	    logic                   we_n_o,
    output      logic [1:0]	            dqm_o,
    inout  wire	logic [15:0]	        dq_io,
    output      logic                   cke_o,

    // Writer (input commands)
    input  wire logic                  writer_clk,
    input  wire logic                  writer_rst_i,
    input  wire logic [40:0]           writer_d_i,
    input  wire logic                  writer_enq_i,    // enqueue
    output      logic                  writer_full_o,
    output      logic                  writer_alm_full_o,

    // Reader (output)
    input  wire logic                  reader_clk,
    input  wire logic                  reader_rst_i,
    output      logic [15:0]           reader_q_o,
    input  wire logic                  reader_deq_i,    // dequeue
    output      logic                  reader_empty_o,
    output      logic                  reader_alm_empty_o
);
    logic [15:0] dq_o;
    logic [15:0] dq_i;
    logic        dq_oe;

    logic sc_idle;
    logic [31:0] sc_adr_in, sc_adr_out;
    logic [15:0] sc_dat_in, sc_dat_out;
    logic sc_acc;
    logic sc_ack;
    logic sc_we;

    logic [40:0] cmd_reader_q;
    logic cmd_reader_deq;
    logic cmd_reader_empty, cmd_reader_alm_empty;

    logic [15:0] data_d;  // data to enqueue in the output FIFO
    logic data_enq;
    logic data_full;
    logic data_alm_full;

    async_fifo #(
        .ADDR_LEN(10),
        .DATA_WIDTH(41)
    ) cmd_async_fifo(
        .reader_clk(sdram_clk),
        .reader_rst_i(sdram_rst),
        .reader_q_o(cmd_reader_q),
        .reader_deq_i(cmd_reader_deq),
        .reader_empty_o(cmd_reader_empty),
        .reader_alm_empty_o(cmd_reader_alm_empty),

        .writer_clk(writer_clk),
        .writer_rst_i(writer_rst_i),
        .writer_d_i(writer_d_i),
        .writer_enq_i(writer_enq_i),
        .writer_full_o(writer_full_o),
        .writer_alm_full_o(writer_alm_full_o)
    );

    async_fifo #(
        .ADDR_LEN(10),
        .DATA_WIDTH(16)
    ) data_async_fifo(
        .reader_clk(reader_clk),
        .reader_rst_i(reader_rst_i),
        .reader_q_o(reader_q_o),
        .reader_deq_i(reader_deq_i),
        .reader_empty_o(reader_empty_o),
        .reader_alm_empty_o(reader_alm_empty_o),

        .writer_clk(sdram_clk),
        .writer_rst_i(sdram_rst),
        .writer_d_i(data_d),
        .writer_enq_i(data_enq),
        .writer_full_o(data_full),
        .writer_alm_full_o(data_alm_full)
    );

    sdram_ctrl #(
        .CLK_FREQ_MHZ(SDRAM_CLK_FREQ_MHZ),     // sdram_clk freq in MHZ
`ifdef SYNTHESIZE
        .POWERUP_DELAY(200),    // power up delay in us
`else
        .POWERUP_DELAY(0),    // power up delay in us
`endif
        .REFRESH_MS(64),        // time to wait between refreshes in ms (0 = disable)
        .BURST_LENGTH(8),       // 0, 1, 2, 4 or 8 (0 = full page)
        .ROW_WIDTH(13),         // Row width
        .COL_WIDTH(9),          // Column width
        .BA_WIDTH(2),           // Ba width
        .tCAC(2),               // CAS Latency
        .tRAC(4),               // RAS Latency
        .tRP(2),                // Command Period (PRE to ACT)
        .tRC(8),                // Command Period (REF to REF / ACT to ACT)
        .tMRD(2)            	// Mode Register Set To Command Delay time
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
        .dq_oe_o(dq_oe),
        .cke_o,

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

    always_ff @(posedge sdram_clk) begin
        dq_i <= dq_io;
    end

    assign dq_io = dq_oe ? dq_o : 16'hZZZZ;

    enum { WAIT_CMD, PROCESS_CMD, WRITE, WAIT_SC_WRITE, READ, WAIT_SC_READ, WRITE_FIFO_DATA } state;

    logic [23:0] addr;
    logic [15:0] param;

    always_ff @(posedge sdram_clk) begin
        case (state)
            WAIT_CMD: begin
                data_enq   <= 1'b0;
                if (!cmd_reader_empty) begin
                    cmd_reader_deq <= 1'b1;
                    state          <= PROCESS_CMD;
                end
            end

            PROCESS_CMD: begin
                cmd_reader_deq <= 1'b0;
                addr       <= cmd_reader_q[39:16];
                param      <= cmd_reader_q[15:0];
                state      <= cmd_reader_q[40] ? WRITE : READ;
            end

            WRITE: begin
                // Write a single word to SDRAM
                if (sc_idle) begin
                    sc_adr_in <= addr;
                    sc_dat_in <= param;
                    sc_acc    <= 1'b1;
                    sc_we     <= 1'b1;
                    state     <= WAIT_SC_WRITE;
                end                
            end

            WAIT_SC_WRITE: begin
                if (sc_ack) begin
                    sc_acc   <= 1'b0;
                    sc_we    <= 1'b0;
                    state    <= WAIT_CMD;
                end
            end

            READ: begin
                if (sc_idle) begin
                    sc_adr_in <= addr;
                    sc_acc    <= 1'b1;
                    sc_we     <= 1'b0;
                    state     <= WAIT_SC_READ;
                end
            end

            WAIT_SC_READ: begin
                if (sc_ack) begin
                    sc_acc <= 1'b0;
`ifdef SYNTHESIZE                    
                    data_d   <= sc_dat_out;
`else
                    data_d   <= sc_adr_out[15:0];
`endif
                    state    <= WRITE_FIFO_DATA;
                end
            end

            WRITE_FIFO_DATA: begin
                if (!data_full) begin
                    data_enq <= 1'b1;
                    state    <= WAIT_CMD;
                end
            end

        endcase

        if (sdram_rst) begin
            state          <= WAIT_CMD;
            data_enq       <= 1'b0;
            cmd_reader_deq <= 1'b0;
            sc_acc         <= 1'b0;
        end
    end

    
endmodule