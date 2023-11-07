module led_device(
    input wire logic         clk,
    input wire logic         reset_i,

    // Bus
    input  wire logic        sel_i,
    input  wire logic        wr_en_i,
    input  wire logic [11:0] address_in_i,
    input  wire logic [31:0] data_in_i,
    output      logic [31:0] data_out_o,
    output      logic        ack_o,

    // LED interface
    output      logic [7:0]  led_o
);

    always @(posedge clk) begin
        if (reset_i) begin
            led_o <= 8'd0;
            data_out_o <= 32'd0;
            ack_o <= 1'b0;
        end else begin
            data_out_o <= 32'd0;
            ack_o <= 1'b0;
            if (sel_i) begin
                if (address_in_i == 12'd0) begin
                    if (wr_en_i) begin
                        led_o <= data_in_i[7:0];
                    end else begin
                        data_out_o <= {24'd0, led_o};
                    end
                end
                ack_o <= 1'b1;
            end
        end
    end

endmodule