// async_fifo_tb.sv
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

// Ref.: https://gist.github.com/shtaxxx/7051753

module async_fifo_tb;
    localparam DATA_WIDTH = 32;
    localparam ADDR_LEN = 10;

    logic                  reader_clk;
    logic                  reader_rst;
    logic [DATA_WIDTH-1:0] reader_q;
    logic                  reader_deq;
    logic                  reader_empty, reader_alm_empty;

    logic                  writer_clk;
    logic                  writer_rst;
    logic [DATA_WIDTH-1:0] writer_d;
    logic                  writer_enq;
    logic                  writer_full, writer_alm_full;

    async_fifo #(
        .ADDR_LEN(ADDR_LEN),
        .DATA_WIDTH(DATA_WIDTH)
    ) async_fifo (
        .reader_clk,
        .reader_rst_i(reader_rst),
        .reader_q_o(reader_q),
        .reader_deq_i(reader_deq),
        .reader_empty_o(reader_empty),
        .reader_alm_empty_o(reader_alm_empty),
        .writer_clk,
        .writer_rst_i(writer_rst),
        .writer_d_i(writer_d),
        .writer_enq_i(writer_enq),
        .writer_full_o(writer_full),
        .writer_alm_full_o(writer_alm_full)
    );

    initial begin
        reader_clk = 0;
        forever #5 reader_clk = !reader_clk;
    end

    initial begin
        writer_clk = 0;
        forever #10 writer_clk = !writer_clk;
    end

    task n_reader_clk;
        begin
            wait(~reader_clk);
            wait(reader_clk);
            #1;
        end
    endtask

    task n_writer_clk;
        begin
            wait(~writer_clk);
            wait(writer_clk);
            #1;
        end
    endtask

    integer i, j;

    logic [DATA_WIDTH-1:0] sum_out;

    initial begin
        reader_deq = 0;
        reader_rst = 0;
        #100;
        reader_rst = 1;
        #100;
        reader_rst = 0;
        #100;
        
        for (i = 0; i < 1024 * 3; i = i + 1) begin
            n_reader_clk();
        end

        sum_out = 0;

        for (i = 0; i < 1024 * 16; i = i + 1) begin
            if (reader_deq) begin
                sum_out = sum_out + reader_q;
            end
            if (reader_empty) begin
                reader_deq = 0;
            end else begin
                reader_deq = 1;
            end
            n_reader_clk();
        end
    end

    reg [DATA_WIDTH-1:0] sum_in;

    initial begin
        writer_d = 0;
        writer_enq = 0;
        writer_rst = 0;
        #100;
        writer_rst = 1;
        #100;
        writer_rst = 0;
        #100;

        for (j = 0; j < 10; j = j + 1) begin
            n_writer_clk();
        end

        writer_d = 0;
        sum_in = 0;

        for (j = 0; j < 1024 * 16; j = j + 1) begin
            if (writer_alm_full) begin
                writer_enq = 0;
            end else if (writer_d > 2**ADDR_LEN + 10) begin
                writer_enq = 0;
            end else begin
                writer_d = writer_d + 1;
                writer_enq = 1;
                sum_in = sum_in + writer_d;
            end
            n_writer_clk();
        end
    end

    initial begin
        #100000;
        $display("sum_in=%d, sum_out=%d, match?=%b", sum_in, sum_out, sum_in == sum_out);
        $finish;
    end

    always @(posedge reader_clk) begin
        if (!reader_rst) begin
            $display("reader_q=%x, reader_deq=%x, reader_empty=%x, reader_alm_empty=%x", reader_q, reader_deq, reader_empty, reader_alm_empty);
        end
    end

    always @(posedge writer_clk) begin
        if (!writer_rst) begin
            $display("writer_d=%x, writer_enq=%x, writer_full=%x, writer_alm_full=%x", writer_d, writer_enq, writer_full, writer_alm_full);
        end
    end

    initial begin
        $dumpfile("async_fifo_tb.vcd");
        $dumpvars(0, async_fifo_tb);
    end

endmodule