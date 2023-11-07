module timer_device #(
    parameter FREQ_HZ = 50 * 1000000
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

    // Timer interrupt
    input  wire logic        timer_eoi_i,
    output      logic        timer_irq_o
);

    localparam TIMER_FREQ_HZ = 1000;

    logic [31:0] timer_value;
    logic [31:0] timer_counter;
    logic timer_intr_ena_we;
    logic timer_intr_ena;
    logic timer_wait_irq_handling;
    always_ff @(posedge clk) begin
        if (reset_i) begin
            timer_value <= FREQ_HZ / TIMER_FREQ_HZ - 1;
            timer_counter <= 32'd0;
            timer_irq_o <= 1'b0;
            timer_wait_irq_handling <= 1'b0;
        end else begin
            if (timer_wait_irq_handling) begin
                if (!timer_eoi_i)
                    timer_wait_irq_handling <= 1'b0;
            end else if (timer_irq_o && timer_eoi_i) begin
                timer_irq_o <= 1'b0;
                //$display("Timer interrupt released");
            end
            timer_value <= timer_value - 1;
            if (timer_value == 32'd0) begin
                timer_counter <= timer_counter + 1;
                if (timer_intr_ena) begin
                    if (!timer_wait_irq_handling && timer_eoi_i) begin
                        //$display("Timer interrupt");
                        timer_irq_o <= 1'b1;
                        timer_wait_irq_handling <= 1'b1;
                    end else begin
`ifndef SYNTHESIS                        
                        $display("Timer interrupt lost");
`endif
                    end
                end
                timer_value <= FREQ_HZ / TIMER_FREQ_HZ - 1;
            end
        end
    end


    always @(posedge clk) begin
        if (reset_i) begin
            timer_intr_ena <= 1'b0;
            data_out_o <= 32'd0;
            ack_o <= 1'b0;
        end else begin
            data_out_o <= 32'd0;
            ack_o <= 1'b0;
            if (sel_i) begin
                if (address_in_i == 12'd0) begin
                    if (wr_en_i) begin
                        timer_intr_ena <= data_in_i[0];
                    end else begin
                        data_out_o <= timer_counter;
                    end
                end
                ack_o <= 1'b1;
            end
        end
    end

endmodule