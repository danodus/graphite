`include "graphite.svh"

// z = (c[0] - a[0]) * (b[1] - a[1]) - (c[1] - a[1]) * (b[0] - a[0])
module edge_function (
    input wire logic           clk,
    input wire logic           reset_i,

    input wire logic [31:0]    a_i[2],
    input wire logic [31:0]    b_i[2],
    input wire logic [31:0]    c_i[2],

    output     logic [31:0]    z_o,

    input wire logic           exec_strobe_i,
    output     logic           done_strobe_o,

    // FPU
    output     logic [3:0]     fpu_op_o,
    output     logic [31:0]    fpu_a_value_o,
    output     logic [31:0]    fpu_b_value_o,
    input wire logic [31:0]    fpu_z_value_i,
    output     logic           fpu_exec_strobe_o,
    input      logic           fpu_done_strobe_i
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
                fpu_op_o          <= FPU_OP_ADD;
                fpu_a_value_o     <= c_i[0];
                fpu_b_value_o     <= {~a_i[0][31], a_i[0][30:0]};
                fpu_exec_strobe_o <= 1'b1;
                state             <= CALC_T0_W;
            end
            CALC_T0_W: begin
                fpu_exec_strobe_o <= 1'b0;
                if (fpu_done_strobe_i) begin
                    t0    <= fpu_z_value_i;
                    state <= CALC_T1;
                end
            end
            CALC_T1: begin
                // t1 = b[1] - a[1]
                fpu_op_o          <= FPU_OP_ADD;
                fpu_a_value_o     <= b_i[1];
                fpu_b_value_o     <= {~a_i[1][31], a_i[1][30:0]};
                fpu_exec_strobe_o <= 1'b1;
                state             <= CALC_T1_W;
            end
            CALC_T1_W: begin
                fpu_exec_strobe_o <= 1'b0;
                if (fpu_done_strobe_i) begin
                    t1    <= fpu_z_value_i;
                    state <= CALC_T2;
                end
            end
            CALC_T2: begin
                // t2 = t0 * t1
                fpu_op_o          <= FPU_OP_MULTIPLY;
                fpu_a_value_o     <= t0;
                fpu_b_value_o     <= t1;
                fpu_exec_strobe_o <= 1'b1;
                state             <= CALC_T2_W;
            end
            CALC_T2_W: begin
                fpu_exec_strobe_o <= 1'b0;
                if (fpu_done_strobe_i) begin
                    t2    <= fpu_z_value_i;
                    state <= CALC_T3;
                end
            end
            CALC_T3: begin
                // t3 = c[1] - a[1]
                fpu_op_o          <= FPU_OP_ADD;
                fpu_a_value_o     <= c_i[1];
                fpu_b_value_o     <= {~a_i[1][31], a_i[1][30:0]};
                fpu_exec_strobe_o <= 1'b1;
                state             <= CALC_T3_W;
            end
            CALC_T3_W: begin
                fpu_exec_strobe_o <= 1'b0;
                if (fpu_done_strobe_i) begin
                    t3    <= fpu_z_value_i;
                    state <= CALC_T4;
                end
            end
            CALC_T4: begin
                // t4 = b[0] - a[0]
                fpu_op_o          <= FPU_OP_ADD;
                fpu_a_value_o     <= b_i[0];
                fpu_b_value_o     <= {~a_i[0][31], a_i[0][30:0]};
                fpu_exec_strobe_o <= 1'b1;
                state             <= CALC_T4_W;
            end
            CALC_T4_W: begin
                fpu_exec_strobe_o <= 1'b0;
                if (fpu_done_strobe_i) begin
                    t4    <= fpu_z_value_i;
                    state <= CALC_T5;
                end
            end
            CALC_T5: begin
                // t5 = t3 * t4
                fpu_op_o          <= FPU_OP_MULTIPLY;
                fpu_a_value_o     <= t3;
                fpu_b_value_o     <= t4;
                fpu_exec_strobe_o <= 1'b1;
                state             <= CALC_T5_W;
            end
            CALC_T5_W: begin
                fpu_exec_strobe_o <= 1'b0;
                if (fpu_done_strobe_i) begin
                    t5    <= fpu_z_value_i;
                    state <= CALC_Z;
                end
            end
            CALC_Z: begin
                // z = t2 - t5
                fpu_op_o          <= FPU_OP_ADD;
                fpu_a_value_o     <= t2;
                fpu_b_value_o     <= {~t5[31], t5[30:0]};
                fpu_exec_strobe_o <= 1'b1;
                state             <= CALC_Z_W;
            end
            CALC_Z_W: begin
                fpu_exec_strobe_o <= 1'b0;
                if (fpu_done_strobe_i) begin
                    z_o           <= fpu_z_value_i;
                    done_strobe_o <= 1'b1;
                    state         <= IDLE;
                end
            end            
        endcase

        if (reset_i) begin
            fpu_exec_strobe_o <= 1'b0;
            done_strobe_o     <= 1'b0;
            state             <= IDLE;
        end
    end

endmodule