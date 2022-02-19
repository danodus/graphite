/*
 *  Copyright (C) 2017  Clifford Wolf <clifford@clifford.at>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

 // October 2019, Matthias Koch: Renamed wires
 // December 2020, Bruno Levy: parameterization with freq and bauds
 // January 2022, Daniel Cliche: Conversion to SV

module uart #(
  parameter FREQ_MHZ = 12,
  parameter BAUDS    = 115200	       
) (
    input  wire logic       clk,
    input  wire logic       reset_i,

    output      logic       tx_o,
    input  wire logic       rx_i,

    input  wire logic       wr_i,
    input  wire logic       rd_i,
    input  wire logic [7:0] tx_data_i,
    output      logic [7:0] rx_data_o,

    output      logic       busy_o,
    output      logic       valid_o
);

    parameter divider = FREQ_MHZ * 1000000 / BAUDS;
   
    logic [3:0] recv_state;
    logic [31:0] recv_divcnt;   // Counts to divider. Reserve enough bytes !
    logic [7:0] recv_pattern;
    logic [7:0] recv_buf_data;
    logic recv_buf_valid;

    logic [9:0] send_pattern;
    logic send_dummy;
    logic [3:0] send_bitcnt;
    logic [31:0] send_divcnt;   // Counts to divider. Reserve enough bytes !

    always_comb begin
        rx_data_o = recv_buf_data;
        valid_o   = recv_buf_valid;
        busy_o    = (send_bitcnt || send_dummy);
    end

    always_ff @(posedge clk) begin
        if (reset_i) begin

            recv_state     <= 0;
            recv_divcnt    <= 0;
            recv_pattern   <= 0;
            recv_buf_data  <= 0;
            recv_buf_valid <= 0;

        end else begin
            recv_divcnt <= recv_divcnt + 1;

            if (rd_i) recv_buf_valid <= 0;

            case (recv_state)
                0: begin
                    if (!rx_i)
                        recv_state <= 1;
                end
                1: begin
                    if (recv_divcnt > divider/2) begin
                        recv_state  <= 2;
                        recv_divcnt <= 0;
                    end
                end
                10: begin
                    if (recv_divcnt > divider) begin
                        recv_buf_data  <= recv_pattern;
                        recv_buf_valid <= 1;
                        recv_state     <= 0;
                    end
                end
                default: begin
                   if (recv_divcnt > divider) begin
                        recv_pattern <= {rx_i, recv_pattern[7:1]};
                        recv_state   <= recv_state + 1;
                        recv_divcnt  <= 0;
                    end
                end
            endcase
        end
    end

    assign tx_o = send_pattern[0];

    always_ff @(posedge clk) begin
        send_divcnt <= send_divcnt + 1;
        if (reset_i) begin
            send_pattern <= ~0;
            send_bitcnt  <= 0;
            send_divcnt  <= 0;
            send_dummy   <= 1;
        end else begin
            if (send_dummy && !send_bitcnt) begin
                send_pattern <= ~0;
                send_bitcnt  <= 15;
                send_divcnt  <= 0;
                send_dummy   <= 0;
            end else if (wr_i && !send_bitcnt) begin
                send_pattern <= {1'b1, tx_data_i[7:0], 1'b0};
                send_bitcnt  <= 10;
                send_divcnt  <= 0;
            end else if (send_divcnt > divider && send_bitcnt) begin
                send_pattern <= {1'b1, send_pattern[9:1]};
                send_bitcnt  <= send_bitcnt - 1;
                send_divcnt  <= 0;
            end
        end 
    end

endmodule

