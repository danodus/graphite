// Based on https://github.com/dawsonjon/fpu/blob/master/adder/adder.v

module adder(
    input wire logic clk,
    input wire logic reset_i,

    input wire logic [31:0] a_value_i,
    input wire logic [31:0] b_value_i,
    output logic     [31:0] z_value_o,

    input wire logic        exec_strobe_i,
    output logic            done_strobe_o
    );

    enum {IDLE, UNPACK, SPECIAL_CASES, ALIGN, ADD_0, ADD_1, NORMALIZE_0, NORMALIZE_1, ROUND, PACK, DONE} state;

    logic        [26:0] a_m, b_m;
    logic        [23:0] z_m;
    logic signed [9:0]  a_e, b_e, z_e;
    logic               a_s, b_s, z_s;
    logic        [27:0] sum;
   
    logic guard, round_bit, sticky;
    
    always_ff @(posedge clk) begin

        case (state)
            IDLE: begin
                done_strobe_o <= 0;
                if (exec_strobe_i)
                    state <= UNPACK;
            end

            UNPACK: begin
                a_m   <= {1'd0, a_value_i[22:0], 3'd0};
                b_m   <= {1'd0, b_value_i[22:0], 3'd0};
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
                    z_value_o[31]    <= a_s;
                    z_value_o[30:23] <= 255;
                    z_value_o[22:0]  <= 0;
                    // if b is inf and signs don't match return NaN
                    if ((b_e == 128) && (a_s != b_s)) begin
                        z_value_o[31]    <= 1;
                        z_value_o[30:23] <= 255;
                        z_value_o[22]    <= 1;
                        z_value_o[21:0]  <= 0;
                    end
                    state <= DONE;
                end
                // if b is inf return inf
                else if (b_e == 128) begin
                    z_value_o[31]    <= a_s;
                    z_value_o[30:23] <= 255;
                    z_value_o[22:0]  <= 0;
                    state            <= DONE;
                end
                // if a is zero and b is zero return b (zero) with proper sign
                else if (a_e == -127 && a_m == 0 && b_e == -127 && b_m == 0) begin
                    z_value_o[31]    <= a_s & b_s;
                    z_value_o[30:23] <= b_e[7:0] + 127;
                    z_value_o[22:0]  <= b_m[25:3];
                    state    <= DONE;
                end
                // if a is zero return b
                else if (a_e == -127 && a_m == 0) begin
                    z_value_o[31]    <= b_s;
                    z_value_o[30:23] <= b_e[7:0] + 127;
                    z_value_o[22:0]  <= b_m[25:3];
                    state    <= DONE;
                end
                // if b is zero return a
                else if (b_e == -127 && b_m == 0) begin
                    z_value_o[31]    <= a_s;
                    z_value_o[30:23] <= a_e[7:0] + 127;
                    z_value_o[22:0]  <= a_m[25:3];
                    state <= DONE;
                end else begin
                    // denormalized number
                    if (a_e == -127) begin
                        a_e <= -126;
                    end else begin
                        a_m[26] <= 1;
                    end
                    // denormalized number
                    if (b_e == -127) begin
                        b_e <= -126;
                    end else begin
                        b_m[26] <= 1;
                    end
                    state <= ALIGN;
                end
            end

            ALIGN: begin
                if (a_e > b_e) begin
                    b_e    <= b_e + 1;
                    b_m    <= b_m >> 1;
                    b_m[0] <= b_m[0] | b_m[1];
                end else if (a_e < b_e) begin
                    a_e    <= a_e + 1;
                    a_m    <= a_m >> 1;
                    a_m[0] <= a_m[0] | a_m[1];
                end else begin
                    state <= ADD_0;
                end
            end

            ADD_0: begin
                z_e <= a_e;
                if (a_s == b_s) begin
                    sum <= a_m + b_m;
                    z_s <= a_s;
                end else begin
                    if (a_m >= b_m) begin
                        sum <= a_m - b_m;
                        z_s <= a_s;
                    end else begin
                        sum <= b_m - a_m;
                        z_s <= b_s;
                    end
                end
                state <= ADD_1;
            end

            ADD_1: begin
                if (sum[27]) begin
                    z_m       <= sum[27:4];
                    guard     <= sum[3];
                    round_bit <= sum[2];
                    sticky    <= sum[1] | sum[0];
                    z_e       <= z_e + 1;
                end else begin
                    z_m       <= sum[26:3];
                    guard     <= sum[2];
                    round_bit <= sum[1];
                    sticky    <= sum[0];
                end
                state <= NORMALIZE_0;
            end

            NORMALIZE_0: begin
                if (z_m[23] == 0 && z_e > -126) begin
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
                if (z_e == -126 && z_m[23:0] == 24'h0) begin
                    z_value_o[31] <= 1'b0;
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

