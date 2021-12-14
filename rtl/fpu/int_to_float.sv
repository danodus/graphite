// Based on https://github.com/dawsonjon/fpu/blob/master/int_to_float/int_to_float.v

module int_to_float(
    input wire logic clk,
    input wire logic reset_i,

    input wire logic [31:0] a_value_i,
    output logic     [31:0] z_value_o,

    input wire logic        exec_strobe_i,
    output logic            done_strobe_o
    );

    enum {IDLE, CONVERT_0, CONVERT_1, CONVERT_2, ROUND, PACK, DONE} state;

    logic        [31:0] value;
    logic        [23:0] z_m;
    logic        [7:0]  z_r;
    logic signed [7:0]  z_e;
    logic               z_s;

    logic guard, round_bit, sticky;

    always_ff @(posedge clk) begin

        case (state)
            IDLE: begin
                done_strobe_o <= 0;
                if (exec_strobe_i)
                    state <= CONVERT_0;
            end

            CONVERT_0: begin
                if (a_value_i == 32'h00000000) begin
                    z_s   <= 0;
                    z_m   <= 0;
                    z_e   <= -127;
                    state <= PACK;
                end else begin
                    value <= a_value_i[31] ? -a_value_i : a_value_i;
                    z_s   <= a_value_i[31];
                    state <= CONVERT_1;
                end
            end

            CONVERT_1: begin
                z_e   <= 31;
                z_m   <= value[31:8];
                z_r   <= value[7:0];
                state <= CONVERT_2;
            end

            CONVERT_2: begin
                if (!z_m[23]) begin
                    z_e    <= z_e - 1;
                    z_m    <= z_m << 1;
                    z_m[0] <= z_r[7];
                    z_r    <= z_r << 1;
                end else begin
                    guard     <= z_r[7];
                    round_bit <= z_r[6];
                    sticky    <= z_r[5:0] != 0;
                    state     <= ROUND;
                end
            end

            ROUND: begin
                if (guard && (round_bit || sticky || z_m[0])) begin
                    z_m <= z_m + 1;
                    if (z_m == 24'hffffff) begin
                        z_e <= z_e + 1;
                    end
                end
                state <= PACK;
            end

            PACK: begin
                z_value_o[22:0]  <= z_m[22:0];
                z_value_o[30:23] <= z_e + 127;
                z_value_o[31]    <= z_s;
                state            <= DONE;
            end

            DONE: begin
                done_strobe_o <= 1;
                state         <= IDLE;
            end

        endcase
       
        if (reset_i) begin
            state <= IDLE;
            done_strobe_o <= 0;
        end
    end

endmodule

