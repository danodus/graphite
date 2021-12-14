// z = (c[0] - a[0]) * (b[1] - a[1]) - (c[1] - a[1]) * (b[0] - a[0])
module edge_function (
    input wire logic           clk,
    input wire logic           reset_i,

    input wire logic [31:0]    a_i[2],
    input wire logic [31:0]    b_i[2],
    input wire logic [31:0]    c_i[2],

    output     logic [31:0]    z_o,

    input wire logic           exec_strobe_i,
    output     logic           done_strobe_o
    );

    // Adder

    logic [31:0] add_a, add_b, add_z;
    logic add_exec_strobe;
    logic add_done_strobe;

    adder adder(
        .clk(clk),
        .reset_i(reset_i),
        .a_value_i(add_a),
        .b_value_i(add_b),
        .z_value_o(add_z),

        .exec_strobe_i(add_exec_strobe),
        .done_strobe_o(add_done_strobe)
    );

    // Multiplier

    logic [31:0] mult_a, mult_b, mult_z;
    logic mult_exec_strobe;
    logic mult_done_strobe;

    multiplier multiplier(
        .clk(clk),
        .reset_i(reset_i),
        .a_value_i(mult_a),
        .b_value_i(mult_b),
        .z_value_o(mult_z),

        .exec_strobe_i(mult_exec_strobe),
        .done_strobe_o(mult_done_strobe)
    );

    logic [31:0] t0;        // t0 = c[0] - a[0]
    logic [31:0] t1;        // t1 = b[1] - a[1]
    logic [31:0] t2;        // t2 = t0 * t1
    logic [31:0] t3;        // t3 = c[1] - a[1]
    logic [31:0] t4;        // t4 = b[0] - a[0]
    logic [31:0] t5;        // t5 = t3 * t4
                            // z = t2 - t5

    enum { IDLE,
        CALC_T0, CALC_T0_W,
        CALC_T1, CALC_T1_W,
        CALC_T2, CALC_T2_W,
        CALC_T3, CALC_T3_W,
        CALC_T4, CALC_T4_W,
        CALC_T5, CALC_T5_W,
        CALC_Z, CALC_Z_W
    } state;

    always_ff @(posedge clk) begin
        case (state)
            IDLE: begin
                done_strobe_o <= 0;
                if (exec_strobe_i)
                    state <= CALC_T0;
            end
            CALC_T0: begin
                // t0 = c[0] - a[0]
                add_a           <= c_i[0];
                add_b           <= {1'b1, a_i[0][30:0]};
                add_exec_strobe <= 1'b1;
                state           <= CALC_T0_W;
            end
            CALC_T0_W: begin
                add_exec_strobe <= 1'b0;
                if (add_done_strobe) begin
                    t0    <= add_z;
                    state <= CALC_T1;
                end
            end
            CALC_T1: begin
                // t1 = b[1] - a[1]
                add_a           <= b_i[1];
                add_b           <= {1'b1, a_i[1][30:0]};
                add_exec_strobe <= 1'b1;
                state           <= CALC_T1_W;
            end
            CALC_T1_W: begin
                add_exec_strobe <= 1'b0;
                if (add_done_strobe) begin
                    t1    <= add_z;
                    state <= CALC_T2;
                end
            end
            CALC_T2: begin
                // t2 = t0 * t1
                mult_a           <= t0;
                mult_b           <= t1;
                mult_exec_strobe <= 1'b1;
                state            <= CALC_T2_W;
            end
            CALC_T2_W: begin
                mult_exec_strobe <= 1'b0;
                if (mult_done_strobe) begin
                    t2    <= mult_z;
                    state <= CALC_T3;
                end
            end
            CALC_T3: begin
                // t3 = c[1] - a[1]
                add_a           <= c_i[1];
                add_b           <= {1'b1, a_i[1][30:0]};
                add_exec_strobe <= 1'b1;
                state           <= CALC_T3_W;
            end
            CALC_T3_W: begin
                add_exec_strobe <= 1'b0;
                if (add_done_strobe) begin
                    t3    <= add_z;
                    state <= CALC_T4;
                end
            end
            CALC_T4: begin
                // t4 = b[0] - a[0]
                add_a           <= b_i[0];
                add_b           <= {1'b1, a_i[0][30:0]};
                add_exec_strobe <= 1'b1;
                state           <= CALC_T4_W;
            end
            CALC_T4_W: begin
                add_exec_strobe <= 1'b0;
                if (add_done_strobe) begin
                    t4    <= add_z;
                    state <= CALC_T5;
                end
            end
            CALC_T5: begin
                // t5 = t3 * t4
                mult_a           <= t3;
                mult_b           <= t4;
                mult_exec_strobe <= 1'b1;
                state            <= CALC_T5_W;
            end
            CALC_T5_W: begin
                mult_exec_strobe <= 1'b0;
                if (mult_done_strobe) begin
                    t5    <= mult_z;
                    state <= CALC_Z;
                end
            end
            CALC_Z: begin
                // z = t2 - t5
                add_a           <= t2;
                add_b           <= {1'b1, t5[30:0]};
                add_exec_strobe <= 1'b1;
                state           <= CALC_Z_W;
            end
            CALC_Z_W: begin
                add_exec_strobe <= 1'b0;
                if (add_done_strobe) begin
                    z_o           <= add_z;
                    done_strobe_o <= 1'b1;
                    state         <= IDLE;
                end
            end            
        endcase

        if (reset_i) begin
            add_exec_strobe  <= 1'b0;
            mult_exec_strobe <= 1'b0;
            done_strobe_o    <= 1'b0;
            state            <= IDLE;
        end
    end

endmodule