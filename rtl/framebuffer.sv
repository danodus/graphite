// framebuffer.sv
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

module framebuffer #(
    parameter SDRAM_CLK_FREQ_MHZ	= 100,             	// sdram clk freq in MHZ
    parameter FB_WIDTH              = 128,
    parameter FB_HEIGHT             = 128
) (
    input  wire logic                   clk_pix,
    input  wire logic                   reset_i,

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

    // Framebuffer access
    output      logic                   ack_o,
    input  wire logic                   sel_i,
    input  wire logic                   wr_i,
    input  wire logic [3:0]             mask_i,
    input  wire logic [23:0]            address_i,
    input  wire logic [15:0]            data_in_i,
    output      logic [15:0]            data_out_o,

    // Framebuffer output data stream
    input  wire logic                   stream_start_frame_i,
    input  wire logic [23:0]            stream_base_address_i,  // base address (fetched at first pixel)
    input  wire logic                   stream_ena_i,           // stream enable
    output      logic [15:0]            stream_data_o,          // stream data output

    output      logic                   stream_preloading_o,
    output      logic                   stream_err_underflow_o,

    // debug
    output      logic  [3:0]            dbg_state_o
);

    localparam FB_SIZE = FB_WIDTH * FB_HEIGHT;
    localparam PRELOAD_DELAY_COUNT = 16'd64;

    enum {
        IDLE, WAIT_BURST, WRITE0, WRITE1, READ0, READ1, READ2, READ3, READ4, READ_BURST0, READ_BURST1, PRELOAD_DELAY, PRELOAD0, PRELOAD1, PRELOAD2, PRELOAD3, PRELOAD4
    } state;

    assign dbg_state_o = state;
    assign stream_preloading_o = req_burst_preload;
    assign stream_data_o = current_burst_data[127:112];

    logic [2:0]     burst_word_counter;
    logic [127:0]   current_burst_data, new_burst_data;
    logic [23:0]    burst_address;
    logic           req_burst_preload;
    logic           req_burst_read;
    logic [15:0]    preload_counter;
    logic           read_pending;

    always_ff @(posedge clk_pix) begin

        if (reset_i) begin
            state              <= IDLE;
            ack_o              <= 1'b0;
            writer_enq         <= 1'b0;
            writer_burst_enq   <= 1'b0;
            reader_deq         <= 1'b0;
            reader_burst_deq   <= 1'b0;
            burst_word_counter <= 3'd0;
            current_burst_data <= 128'd0;
            new_burst_data     <= 128'd0;
            burst_address      <= stream_base_address_i;
            req_burst_preload  <= 1'b0;
            req_burst_read     <= 1'b0;
            stream_err_underflow_o <= 1'b0;
            read_pending       <= 1'b0;

        end else begin
            if (stream_start_frame_i) begin
                burst_address  <= stream_base_address_i;
                burst_word_counter <= 3'd1;
                req_burst_preload <= 1'b1;
            end else if (stream_ena_i) begin
                if (burst_word_counter == 3'd0) begin
                    current_burst_data <= new_burst_data;
                    req_burst_read     <= 1'b1;
                end else begin
                    current_burst_data <= current_burst_data << 16;
                end
                burst_word_counter <= burst_word_counter + 3'd1;
            end

            case (state)
                IDLE: begin
                    stream_err_underflow_o <= 1'b0;

                    // output data stream
                    if (req_burst_preload) begin
                        req_burst_preload  <= 1'b0;
                        preload_counter    <= PRELOAD_DELAY_COUNT;
                        state              <= PRELOAD_DELAY;
                    end else if (stream_ena_i && req_burst_read) begin
                        req_burst_read     <= 1'b0;
                        state              <= READ_BURST0;
                    end else begin
                        // always read data
                        if (!writer_burst_full) begin
                            // read burst command
                            writer_burst_d <= {8'd0, burst_address};
                            writer_burst_enq <= 1'b1;

                            if (burst_address < stream_base_address_i + FB_SIZE - 8)
                                burst_address <= burst_address + 8;

                            state <= WAIT_BURST;
                        end else begin
                            if (read_pending) begin
                                if (!reader_empty) begin
                                    read_pending <= 1'b0;
                                    state <= READ2;
                                end
                            end else if (sel_i && !writer_full && !reader_burst_alm_empty) begin
                                state <= wr_i ? WRITE0 : READ0;
                            end
                        end
                    end
                end

                WAIT_BURST: begin
                    writer_burst_enq <= 1'b0;
                    state <= IDLE;
                end

                WRITE0: begin
                    if (!writer_full) begin
                        // write command
                        writer_d   <= {1'b1, address_i, data_in_i};
                        writer_enq <= 1'b1;
                        ack_o      <= 1'b1;
                        state      <= WRITE1;
                    end
                end

                WRITE1: begin
                        ack_o      <= 1'b0;
                        writer_enq <= 1'b0;
                        state      <= IDLE;
                end

                READ0: begin
                    if (!writer_full) begin
                        // write command
                        writer_d   <= {1'b0, address_i, 16'h0};
                        writer_enq <= 1'b1;
                        state      <= READ1;
                    end
                end

                READ1: begin
                    writer_enq <= 1'b0;
                    read_pending <= 1'b1;
                    state <= IDLE;
                end

                READ2: begin
                    // if a value is available, return it
                    if (!reader_empty) begin
                        reader_deq <= 1'b1;
                        state      <= READ3;
                    end
                end

                READ3: begin
                    reader_deq <= 1'b0;
                    data_out_o <= reader_q;
                    ack_o      <= 1'b1;
                    state      <= READ4;
                end

                READ4: begin
                    ack_o      <= 1'b0;
                    state      <= IDLE;
                end

                READ_BURST0: begin
                    if (!reader_burst_empty) begin
                        reader_burst_deq <= 1'b1;
                        state <= READ_BURST1;
                    end else begin
                        // Should not happen
                        //$display("Framebuffer stream underflow");
                        stream_err_underflow_o <= 1'b1;
                        state <= IDLE;
                    end
                end

                READ_BURST1: begin
                    reader_burst_deq <= 1'b0;
                    new_burst_data <= reader_burst_q[127:0];
                    state            <= IDLE;
                end

                PRELOAD_DELAY: begin
                    preload_counter <= preload_counter - 1;
                    if (preload_counter == 0)
                        state <= PRELOAD0;
                end

                PRELOAD0: begin
                    // clear
                    if (!reader_burst_empty) begin
                        reader_burst_deq <= 1'b1;
                        state <= PRELOAD1;
                    end else begin
                        state <= PRELOAD2;
                    end
                end

                PRELOAD1: begin
                    reader_burst_deq <= 1'b0;
                    state <= PRELOAD0;
                end

                PRELOAD2: begin
                    // request burst
                    if (!writer_burst_full) begin
                        writer_burst_d <= {8'd0, burst_address};
                        writer_burst_enq <= 1'b1;
                        if (burst_address < stream_base_address_i + FB_SIZE - 8)
                            burst_address <= burst_address + 8;
                        state <= PRELOAD3;
                    end
                end

                PRELOAD3: begin
                    writer_burst_enq <= 1'b0;
                    if (!reader_burst_empty) begin
                        reader_burst_deq <= 1'b1;
                        state <= PRELOAD4;
                    end
                end

                PRELOAD4: begin
                    reader_burst_deq    <= 1'b0;
                    new_burst_data      <= reader_burst_q[127:0];
                    current_burst_data  <= reader_burst_q[127:0];
                    req_burst_read      <= 1'b1;
                    state               <= IDLE;
                end

            endcase
        end
    end

    //
    // Async SDRAM
    //

    logic [40:0] writer_d;
    logic writer_enq;
    logic writer_full;

    logic [31:0] writer_burst_d;
    logic writer_burst_enq;
    logic writer_burst_full;

    logic [15:0] reader_q;
    logic reader_deq;
    logic reader_empty;    

    logic [127:0] reader_burst_q;

    logic reader_burst_deq;
    logic reader_burst_empty, reader_burst_alm_empty;

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
        .writer_clk(clk_pix),
        .writer_rst_i(reset_i),

        .writer_d_i(writer_d),
        .writer_enq_i(writer_enq),    // enqueue
        .writer_full_o(writer_full),
        .writer_alm_full_o(),

        .writer_burst_d_i(writer_burst_d),
        .writer_burst_enq_i(writer_burst_enq),    // enqueue
        .writer_burst_full_o(writer_burst_full),
        .writer_burst_alm_full_o(),

        // Reader
        .reader_clk(clk_pix),
        .reader_rst_i(reset_i),

        // Reader main channel
        .reader_q_o(reader_q),
        .reader_deq_i(reader_deq),    // dequeue
        .reader_empty_o(reader_empty),
        .reader_alm_empty_o(),

        // Reader secondary channel
        .reader_burst_q_o(reader_burst_q),
        .reader_burst_deq_i(reader_burst_deq),    // dequeue
        .reader_burst_empty_o(reader_burst_empty),
        .reader_burst_alm_empty_o(reader_burst_alm_empty)
    );

endmodule