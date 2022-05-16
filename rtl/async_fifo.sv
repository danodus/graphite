// async_fifo.sv
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

// Ref.: https://gist.github.com/shtaxxx/7051753

module async_fifo #(
    parameter ADDR_LEN = 10,
    parameter DATA_WIDTH = 32
) (
    // Reader
    input  wire logic                  reader_clk,
    input  wire logic                  reader_rst_i,
    output      logic [DATA_WIDTH-1:0] reader_q_o,
    input  wire logic                  reader_deq_i,    // dequeue
    output      logic                  reader_empty_o,
    output      logic                  reader_alm_empty_o,

    // Writer
    input  wire logic                  writer_clk,
    input  wire logic                  writer_rst_i,
    input  wire logic [DATA_WIDTH-1:0] writer_d_i,
    input  wire logic                  writer_enq_i,    // enqueue
    output      logic                  writer_full_o,
    output      logic                  writer_alm_full_o
);

    localparam MEM_SIZE = 2 ** ADDR_LEN;

    logic [ADDR_LEN-1:0] head;
    logic [ADDR_LEN-1:0] tail;

    logic [ADDR_LEN-1:0] gray_head;
    logic [ADDR_LEN-1:0] gray_tail;

    logic [ADDR_LEN-1:0] d_gray_head;
    logic [ADDR_LEN-1:0] d_gray_tail;

    logic [ADDR_LEN-1:0] dd_gray_head;
    logic [ADDR_LEN-1:0] dd_gray_tail;

    function logic [ADDR_LEN-1:0] to_gray(
        input logic [ADDR_LEN-1:0] in_i
    );
        to_gray = in_i ^ (in_i >> 1);
    endfunction

    // read pointer
    always_ff @(posedge reader_clk) begin
        if (reader_rst_i) begin
            head <= 0;
        end else begin
            if (!reader_empty_o && reader_deq_i)
                head <= head == (MEM_SIZE - 1) ? 0 : head + 1;
        end
    end

    // write pointer
    always_ff @(posedge writer_clk) begin
        if (writer_rst_i) begin
            tail <= 0;
        end else begin
            if (!writer_full_o && writer_enq_i)
                tail <= tail == (MEM_SIZE - 1) ? 0 : tail + 1;
        end
    end

    assign gray_head = to_gray(head);
    assign gray_tail = to_gray(tail);

    // read pointer (reader_clk -> writer_clk)
    always_ff @(posedge writer_clk) begin
        d_gray_head  <= gray_head;
        dd_gray_head <= d_gray_head;
        if (writer_rst_i) begin
            d_gray_head <= 0;
            dd_gray_head <= 0;
        end
    end

    // write pointer (writer_clk -> reader_clk)
    always_ff @(posedge reader_clk) begin
        d_gray_tail  <= gray_tail;
        dd_gray_tail <= d_gray_tail;
        if (reader_rst_i) begin
            d_gray_tail <= 0;
            dd_gray_tail <= 0;
        end
    end

    always_ff @(posedge reader_clk) begin
        if (reader_deq_i && !reader_empty_o) begin
            reader_empty_o     <= (dd_gray_tail == to_gray(head + 1));
            reader_alm_empty_o <= (dd_gray_tail == to_gray(head + 2)) || (dd_gray_tail == to_gray(head + 1));
        end else begin
            reader_empty_o     <= (dd_gray_tail == to_gray(head));
            reader_alm_empty_o <= (dd_gray_tail == to_gray(head + 1)) || (dd_gray_tail == to_gray(head));
        end
        if (reader_rst_i) begin
            reader_empty_o     <= 1'b1;
            reader_alm_empty_o <= 1'b1;
        end
    end

    always_ff @(posedge writer_clk) begin
        if (writer_enq_i && !writer_full_o) begin
            writer_full_o     <= (dd_gray_head == to_gray(tail + 2));
            writer_alm_full_o <= (dd_gray_head == to_gray(tail + 3)) || (dd_gray_head == to_gray(tail + 2));
        end else begin
            writer_full_o     <= (dd_gray_head == to_gray(tail + 1));
            writer_alm_full_o <= (dd_gray_head == to_gray(tail + 2)) || (dd_gray_head == to_gray(tail + 1));
        end
        if (writer_rst_i) begin
            writer_full_o     <= 1'b0;
            writer_alm_full_o <= 1'b0;
        end
    end

    logic ram_we;
    assign ram_we = writer_enq_i && !writer_full_o;
    async_bram2 #(
        .W_A(ADDR_LEN),
        .W_D(DATA_WIDTH)
    ) ram (
        .clk0(reader_clk), .addr0_i(head), .d0_i({DATA_WIDTH{1'b0}}), .we0_i(1'b0), .q0_o(reader_q_o), // read
        .clk1(writer_clk), .addr1_i(tail), .d1_i(writer_d_i), .we1_i(ram_we), .q1_o()   // write
    );

endmodule

// Dual-port BRAM
module async_bram2 #(
    parameter W_A = 10,
    parameter W_D = 32
) (
    // First port
    input  wire logic clk0,
    input  wire logic [W_A-1:0] addr0_i,
    input  wire logic [W_D-1:0] d0_i,
    input  wire logic           we0_i,
    output      logic [W_D-1:0] q0_o,

    // Second port
    input  wire logic clk1,
    input  wire logic [W_A-1:0] addr1_i,
    input  wire logic [W_D-1:0] d1_i,
    input  wire logic           we1_i,
    output      logic [W_D-1:0] q1_o
);
    localparam LEN = 2 ** W_A;

    logic [W_A-1:0] d_addr0;
    logic [W_A-1:0] d_addr1;
    logic [W_D-1:0] mem[0:LEN-1];

    always_ff @(posedge clk0) begin
        if (we0_i)
            mem[addr0_i] <= d0_i;
        d_addr0 <= addr0_i;
    end

    always_ff @(posedge clk1) begin
        if (we1_i)
            mem[addr1_i] <= d1_i;
        d_addr1 <= addr1_i;
    end

    assign q0_o = mem[d_addr0];
    assign q1_o = mem[d_addr1];

endmodule