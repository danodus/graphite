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

    // Pop/push only in the GPU clock-enable domain. in_ready must also require
    // ce_i: otherwise a host handshake can retire a beat while the FIFO is
    // frozen, dropping the command (missing triangles on later frames).
    wire will_pop  = ce_i && (count != 0) && out_ready_i;
    wire will_push = ce_i && in_valid_i && ((count < DEPTH) || will_pop);

    assign in_ready_o  = ce_i && ((count < DEPTH) || will_pop);
    assign out_valid_o = (count != 0);
    assign out_data_o  = data_mem[read_ptr];

    always_ff @(posedge clk) begin
        if (reset_i) begin
            write_ptr <= '0;
            read_ptr  <= '0;
            count     <= '0;
        end else if (ce_i) begin
            if (will_push) begin
                data_mem[write_ptr] <= in_data_i;
                if (write_ptr == LAST_PTR)
                    write_ptr <= '0;
                else
                    write_ptr <= write_ptr + 1'b1;
            end

            if (will_pop) begin
                if (read_ptr == LAST_PTR)
                    read_ptr <= '0;
                else
                    read_ptr <= read_ptr + 1'b1;
            end

            case ({will_push, will_pop})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end

endmodule
