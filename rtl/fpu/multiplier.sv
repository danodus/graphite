// Based on https://github.com/dawsonjon/fpu/blob/master/multiplier/multiplier.v

module multiplier(
    input wire logic clk,
    input wire logic reset_i,

    input wire logic [31:0] a_value_i,
    input wire logic [31:0] b_value_i,
    output logic     [31:0] z_value_o,

    input wire logic        exec_strobe_i,
    output logic            done_strobe_o
    );

    enum {IDLE, UNPACK, SPECIAL_CASES, NORMALIZE_A, NORMALIZE_B, MULTIPLY_0, MULTIPLY_1, NORMALIZE_0, NORMALIZE_1,
          ROUND, PACK, DONE} state;

    logic        [23:0] a_m, b_m, z_m;
    logic signed [9:0]  a_e, b_e, z_e;
    logic               a_s, b_s, z_s;
    logic        [47:0] product;
   
    logic guard, round_bit, sticky;
    
    always_ff @(posedge clk) begin

        case (state)
            IDLE: begin
                done_strobe_o <= 0;
                if (exec_strobe_i)
                    state <= UNPACK;
            end

            UNPACK: begin
                a_m   <= {1'd0, a_value_i[22:0]};
                b_m   <= {1'd0, b_value_i[22:0]};
                a_e   <= {2'd0, a_value_i[30:23]} - 10'd127;
                b_e   <= {2'd0, b_value_i[30:23]} - 10'd127;
                a_s   <= a_value_i[31];
                b_s   <= b_value_i[31];
                state <= SPECIAL_CASES;
            end

            SPECIAL_CASES: begin
                // if a is NaN or b is NaN return NaN
                if ((a_e == 128 && a_m != 0) || (b_e == 128 && b_m != 0)) begin
                    z_value_o[31]    <= 1;
                    z_value_o[30:23] <= 255;
                    z_value_o[22]    <= 1;
                    z_value_o[21:0]  <= 0;
                    state            <= DONE;
                end
                // if a is inf return inf
                else if (a_e == 128) begin
                    z_value_o[31]    <= a_s ^ b_s;
                    z_value_o[30:23] <= 255;
                    z_value_o[22:0]  <= 0;
                    // if b is zero return NaN
                    if ((b_e == -127) && (b_m == 0)) begin
                        z_value_o[31]    <= 1;
                        z_value_o[30:23] <= 255;
                        z_value_o[22]    <= 1;
                        z_value_o[21:0]  <= 0;
                    end
                    state <= DONE;
                end
                // if b is inf return inf
                else if (b_e == 128) begin
                    z_value_o[31]    <= a_s ^ b_s;
                    z_value_o[30:23] <= 255;
                    z_value_o[22:0]  <= 0;
                    // if a is zero return NaN
                    if (a_e == -127 && a_m == 0) begin
                        z_value_o[31]    <= 1;
                        z_value_o[30:23] <= 255;
                        z_value_o[22]    <= 1;
                        z_value_o[21:0]  <= 0;                        
                    end
                    state            <= DONE;
                end
                // if a is zero return zero
                else if (a_e == -127 && a_m == 0) begin
                    z_value_o[31]    <= a_s ^ b_s;
                    z_value_o[30:23] <= 0;
                    z_value_o[22:0]  <= 0;
                    state    <= DONE;
                end
                // if b is zero return zero
                else if (b_e == -127 && b_m == 0) begin
                    z_value_o[31]    <= a_s ^ b_s;
                    z_value_o[30:23] <= 0;
                    z_value_o[22:0]  <= 0;
                    state    <= DONE;
                end else begin
                    // denormalized number
                    if (a_e == -127) begin
                        a_e <= -126;
                    end else begin
                        a_m[23] <= 1;
                    end
                    // denormalized number
                    if (b_e == -127) begin
                        b_e <= -126;
                    end else begin
                        b_m[23] <= 1;
                    end
                    state <= NORMALIZE_A;
                end
            end

            NORMALIZE_A: begin
                if (a_m[23]) begin
                    state <= NORMALIZE_B;
                end else begin
                    a_m <= a_m << 1;
                    a_e <= a_e - 1;
                end
            end

            NORMALIZE_B: begin
                if (b_m[23]) begin
                    state <= MULTIPLY_0;
                end else begin
                    b_m <= b_m << 1;
                    b_e <= b_e - 1;
                end
            end

            MULTIPLY_0: begin
                z_s     <= a_s ^ b_s;
                z_e     <= a_e + b_e + 1;
                product <= a_m * b_m;
                state   <= MULTIPLY_1;
            end

            MULTIPLY_1: begin
                z_m       <= product[47:24];
                guard     <= product[23];
                round_bit <= product[22];
                sticky    <= product[21:0] != 0;
                state     <= NORMALIZE_0;
            end

            NORMALIZE_0: begin
                if (z_m[23] == 0) begin
                    z_e       <= z_e - 1;
                    z_m       <= z_m << 1;
                    z_m[0]    <= guard;
                    guard     <= round_bit;
                    round_bit <= 0;
                end else begin
                    state     <= NORMALIZE_1;
                end
            end

            NORMALIZE_1: begin
                if (z_e < -126) begin
                    z_e       <= z_e + 1;
                    z_m       <= z_m >> 1;
                    guard     <= z_m[0];
                    round_bit <= guard;
                    sticky    <= sticky | round_bit;
                end else begin
                    state     <= ROUND;
                end
            end

            ROUND: begin
                if (guard && (round_bit | sticky | z_m[0])) begin
                    z_m <= z_m + 1;
                    if (z_m == 24'hffffff) begin
                        z_e <= z_e + 1;
                    end
                end
                state <= PACK;
            end

            PACK: begin
                z_value_o[22:0]  <= z_m[22:0];
                z_value_o[30:23] <= z_e[7:0] + 127;
                z_value_o[31]    <= z_s;
                if (z_e == -126 && z_m[23] == 0) begin
                    z_value_o[30:23] <= 0;
                end
                // if overflow occurs, return inf
                if (z_e > 127) begin
                    z_value_o[22:0]  <= 0;
                    z_value_o[30:23] <= 255;
                    z_value_o[31]    <= z_s;
                end
                state <= DONE;
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

