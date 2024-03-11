// fifo.sv
// Copyright (c) 2022 Daniel Cliche
// SPDX-License-Identifier: MIT

// Ref.: https://gist.github.com/shtaxxx/7051753

module fifo #(
    parameter ADDR_LEN = 10,
    parameter DATA_WIDTH = 32
) (
    input  wire logic                  clk,
    input  wire logic                  reset_i,
    
    // Reader
    output      logic [DATA_WIDTH-1:0] reader_q_o,
    input  wire logic                  reader_deq_i,    // dequeue
    output      logic                  reader_empty_o,
    output      logic                  reader_alm_empty_o,

    // Writer
    input  wire logic [DATA_WIDTH-1:0] writer_d_i,
    input  wire logic                  writer_enq_i,    // enqueue
    output      logic                  writer_full_o,
    output      logic                  writer_alm_full_o
);

    localparam MEM_SIZE = 2 ** ADDR_LEN;

    logic [ADDR_LEN-1:0] head;
    logic [ADDR_LEN-1:0] tail;

    // read pointer
    always_ff @(posedge clk) begin
        if (reset_i) begin
            head <= 0;
        end else begin
            if (!reader_empty_o && reader_deq_i) begin
                head <= head == (MEM_SIZE - 1) ? 0 : head + 1;
            end
        end
    end

    // write pointer
    always_ff @(posedge clk) begin
        if (reset_i) begin
            tail <= 0;
        end else begin
            if (!writer_full_o && writer_enq_i)
                tail <= tail == (MEM_SIZE - 1) ? 0 : tail + 1;
        end
    end

    assign reader_empty_o     = (tail == head);
    assign reader_alm_empty_o = (tail == head + 1) || (tail == head);

    assign writer_full_o      = (head == tail + 1);
    assign writer_alm_full_o  = (head == tail + 2) || (head == tail + 1);

    logic ram_we;
    assign ram_we = writer_enq_i && !writer_full_o;
    bram2 #(
        .W_A(ADDR_LEN),
        .W_D(DATA_WIDTH)
    ) ram (
        .clk(clk),
        .addr0_i(head), .d0_i('h0), .we0_i(1'b0), .q0_o(reader_q_o), // read
        .addr1_i(tail), .d1_i(writer_d_i), .we1_i(ram_we), .q1_o()   // write
    );

endmodule

// Dual-port BRAM
module bram2 #(
    parameter W_A = 10,
    parameter W_D = 32
) (
    input  wire logic clk,

    // First port
    input  wire logic [W_A-1:0] addr0_i,
    input  wire logic [W_D-1:0] d0_i,
    input  wire logic           we0_i,
    output      logic [W_D-1:0] q0_o,

    // Second port
    input  wire logic [W_A-1:0] addr1_i,
    input  wire logic [W_D-1:0] d1_i,
    input  wire logic           we1_i,
    output      logic [W_D-1:0] q1_o
);
    localparam LEN = 2 ** W_A;

    logic [W_A-1:0] d_addr0;
    logic [W_A-1:0] d_addr1;
    logic [W_D-1:0] mem[0:LEN-1];

    always_ff @(posedge clk) begin
        if (we0_i)
            mem[addr0_i] <= d0_i;
        d_addr0 <= addr0_i;
    end

    always_ff @(posedge clk) begin
        if (we1_i)
            mem[addr1_i] <= d1_i;
        d_addr1 <= addr1_i;
    end

    assign q0_o = mem[d_addr0];
    assign q1_o = mem[d_addr1];

endmodule