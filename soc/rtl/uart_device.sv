module uart_device #(
    parameter FREQ_HZ = 50 * 1000000,
    parameter BAUDS   = 115200	       
) (
    input wire logic         clk,
    input wire logic         reset_i,

    // Bus
    input  wire logic        sel_i,
    input  wire logic        wr_en_i,
    input  wire logic [11:0] address_in_i,
    input  wire logic [31:0] data_in_i,
    output      logic [31:0] data_out_o,
    output      logic        ack_o,

    // UART interface
    output      logic       tx_o,
    input  wire logic       rx_i
);

    logic uart_tx_strobe;
    logic [7:0] uart_tx_data;
    logic [7:0] uart_rx_data;
    logic uart_busy, uart_valid;
    logic uart_wr;

    uart #(
        .FREQ_HZ(FREQ_HZ),
        .BAUDS(BAUDS)
    ) uart(
        .clk(clk),
        .reset_i(reset_i),

        .tx_o(tx_o),
        .rx_i(rx_i),

        .wr_i(uart_wr),
        .rd_i(1'b1),
        .tx_data_i(uart_tx_data),
        .rx_data_o(uart_rx_data),

        .busy_o(uart_busy),
        .valid_o(uart_valid)
    );

    logic uart_enq;
    logic uart_deq;
    logic uart_fifo_empty;
    fifo #(
        .ADDR_LEN(10),
        .DATA_WIDTH(8)
    ) uart_fifo(
        .clk(clk),
        .reset_i(reset_i),
        .reader_q_o(uart_code),
        .reader_deq_i(uart_deq),
        .reader_empty_o(uart_fifo_empty),
        .reader_alm_empty_o(),

        .writer_d_i(uart_rx_data),
        .writer_enq_i(uart_enq),
        .writer_full_o(),
        .writer_alm_full_o()
    );    

    logic       uart_req_deq;
    logic [7:0] uart_code, uart_code_r;
    always_ff @(posedge clk) begin
        if (reset_i) begin
            uart_enq     <= 1'b0;
            uart_deq     <= 1'b0;
            uart_tx_data <= 8'd0;
            uart_wr      <= 1'b0;
        end begin
            uart_enq <= 1'b0;
            if (uart_deq) begin
                uart_deq <= 1'b0;
                uart_code_r <= uart_code; 
            end
            if (uart_req_deq) begin
                if (!uart_fifo_empty) begin
                    uart_deq <= 1'b1;
                end
            end
            if (uart_valid) begin
                uart_enq <= 1'b1;
            end
        end

        if (uart_tx_strobe) begin
            uart_tx_data <= data_in_i[7:0];
            uart_wr <= 1'b1;
        end else begin
            uart_wr <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (reset_i) begin
            uart_tx_strobe <= 1'b0;
            uart_req_deq <= 1'b0;
        end else begin
            data_out_o <= 32'd0;
            ack_o <= 1'b0;
            uart_tx_strobe <= 1'b0;
            uart_req_deq <= 1'b0;
            if (sel_i) begin
                if (address_in_i == 12'd0) begin
                    // UART data
                    if (wr_en_i) begin
                        uart_tx_strobe <= 1'b1;
                    end else begin
                        data_out_o <= {24'd0, uart_code_r};
                    end
                end else if (address_in_i == 12'd4) begin
                    // UART status/control
                    if (wr_en_i) begin
                        if (!uart_fifo_empty)
                            uart_req_deq <= 1'b1;
                    end else begin
                        data_out_o <= {30'd0, ~uart_fifo_empty, uart_busy};
                    end
                end
                ack_o <= 1'b1;
            end
        end
    end

endmodule