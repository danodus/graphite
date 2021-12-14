// Based on https://github.com/dawsonjon/fpu/blob/master/float_to_int/float_to_int.v

module float_to_int(
    input wire logic clk,
    input wire logic reset_i,

    input wire logic [31:0] a_value_i,
    output logic     [31:0] z_value_o,

    input wire logic        exec_strobe_i,
    output logic            done_strobe_o
    );

    enum {IDLE, UNPACK, SPECIAL_CASES, CONVERT, DONE} state;

    logic        [31:0] a_m;   // mantissa
    logic signed [8:0]  a_e;   // exponent
    logic               a_s;   // sign

    always_ff @(posedge clk) begin

        case (state)
            IDLE: begin
                done_strobe_o <= 0;
                if (exec_strobe_i)
                    state <= UNPACK;
            end

            UNPACK: begin
                a_m[31:8] <= {1'b1, a_value_i[22:0]};
                a_m[7:0]  <= 0;
                a_e       <= a_value_i[30:23] - 127;
                a_s       <= a_value_i[31];
                state     <= SPECIAL_CASES;
            end

            SPECIAL_CASES: begin
                if (a_e == -127) begin
                    z_value_o <= 32'h00000000;
                    state <= DONE;
                end else if (a_e > 31) begin
                    z_value_o <= 32'h80000000;
                    state <= DONE;
                end else begin
                    state <= CONVERT;
                end
            end

            CONVERT: begin
                if (a_e < 31 && a_m != 0) begin
                    a_e <= a_e + 1;
                    a_m <= a_m >> 1;
                end else begin
                    if (a_m[31]) begin
                        z_value_o <= 32'h80000000;
                    end else begin
                        z_value_o <= a_s ? -a_m : a_m;
                    end
                    state <= DONE;
                end
            end

            DONE: begin
                done_strobe_o <= 1;
                state <= IDLE;
            end

        endcase

        
        if (reset_i) begin
            state <= IDLE;
            done_strobe_o <= 0;
        end
    end




endmodule

