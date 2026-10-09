// graphite_command_fifo.sv
// Copyright (c) 2021-2026 Daniel Cliche
// SPDX-License-Identifier: MIT

module graphite_command_fifo #(
    parameter DEPTH = 64
) (
    input  wire logic        clk,
    input  wire logic        reset_i,
    input  wire logic        ce_i,

    input  wire logic        in_valid_i,
    output wire logic        in_ready_o,
    input  wire logic [31:0] in_data_i,

    output wire logic        out_valid_o,
    input  wire logic        out_ready_i,
    output wire logic [31:0] out_data_o
);

    localparam PTR_WIDTH = $clog2(DEPTH);
    localparam COUNT_WIDTH = $clog2(DEPTH + 1);
    localparam [PTR_WIDTH-1:0] LAST_PTR = PTR_WIDTH'(DEPTH - 1);

    logic [31:0] data_mem [0:DEPTH-1];
    logic [PTR_WIDTH-1:0] write_ptr;
    logic [PTR_WIDTH-1:0] read_ptr;
    logic [COUNT_WIDTH-1:0] count;

    // Fall-through head. The RAM read is synchronous so a 256-deep FIFO maps
    // to one block RAM; this register makes the current word visible while
    // the next word is fetched.
    logic [31:0] mem_rdata;
    logic        forward_q;
    logic [31:0] forward_data_q;
    logic        out_valid_r;

    // Pop only in the GPU clock-enable domain. Push does not: the CPU must be
    // able to enqueue while the rasterizer is stalled on the cache. A full
    // FIFO can still accept a push in the same cycle as a pop.
    wire will_pop   = !reset_i && ce_i && out_valid_r && out_ready_i;
    wire has_space  = (count < DEPTH) || will_pop;
    assign in_ready_o = !reset_i && has_space;
    wire will_push  = in_valid_i && in_ready_o;

    wire [PTR_WIDTH-1:0] read_ptr_next = (read_ptr == LAST_PTR) ? '0 : read_ptr + 1'b1;
    // While popping, prefetch the word that becomes the head. Otherwise hold
    // the current head (a push must not change the word being presented).
    wire [PTR_WIDTH-1:0] rd_addr = will_pop ? read_ptr_next : read_ptr;
    // The synchronous read returns the old contents of a location written on
    // this edge. Forward when that location is the next head (push into an
    // empty FIFO, or push of the word that replaces the last popped one).
    wire forward = will_push && (write_ptr == rd_addr);

    wire [COUNT_WIDTH-1:0] count_next =
        (will_push && !will_pop) ? count + 1'b1 :
        (!will_push && will_pop) ? count - 1'b1 :
                                   count;

    assign out_valid_o = out_valid_r;
    assign out_data_o  = forward_q ? forward_data_q : mem_rdata;

    always_ff @(posedge clk) begin
        if (will_push)
            data_mem[write_ptr] <= in_data_i;
        mem_rdata <= data_mem[rd_addr];
    end

    always_ff @(posedge clk) begin
        if (reset_i) begin
            write_ptr      <= '0;
            read_ptr       <= '0;
            count          <= '0;
            out_valid_r    <= 1'b0;
            forward_q      <= 1'b0;
            forward_data_q <= '0;
        end else begin
            if (will_push) begin
                if (write_ptr == LAST_PTR)
                    write_ptr <= '0;
                else
                    write_ptr <= write_ptr + 1'b1;
            end

            if (will_pop)
                read_ptr <= read_ptr_next;

            count          <= count_next;
            out_valid_r    <= (count_next != '0);
            forward_q      <= forward;
            forward_data_q <= in_data_i;
        end
    end

endmodule
