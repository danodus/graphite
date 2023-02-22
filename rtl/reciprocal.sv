`include "graphite.svh"

// f(x) = NUMERATOR/x
module reciprocal #(
    parameter NUMERATOR = 32'h100,
    parameter END_INTERPOLATION_REGION = 131072,     // values beyond this will return 0
    parameter NB_SUBDIVISIONS = 16384
)(
    input wire logic clk,
    input wire logic reset_i,
    input wire logic start_i,
    input wire logic [31:0] x_i,
    output     logic [31:0] z_o,
    output     logic        done_o
);
    localparam SUBDIVISION_SIZE = END_INTERPOLATION_REGION / NB_SUBDIVISIONS;
    localparam NB_BITS_PER_SUBDIVISION = $clog2(SUBDIVISION_SIZE);

    logic [31:0] m_lut[NB_SUBDIVISIONS];
    logic [31:0] b_lut[NB_SUBDIVISIONS];

    initial begin
        $readmemh("reciprocal_m_lut.hex", m_lut);
        $readmemh("reciprocal_b_lut.hex", b_lut);
    end

    function logic [31:0] reciprocal_value(logic [31:0] x);
        reciprocal_value = x > 0 ? div(NUMERATOR << 14, x) : NUMERATOR << 14;
    endfunction

    function logic [31:0] interpolated(logic [31:0] x);
        if (x[31:31-(18-$clog2(END_INTERPOLATION_REGION))+1] > 0) begin
            interpolated = 32'd0;
        end else begin
           interpolated = mul(x - {x[31:(14+NB_BITS_PER_SUBDIVISION)], {(14+NB_BITS_PER_SUBDIVISION){1'b0}}}, m_lut[x[(14 + NB_BITS_PER_SUBDIVISION + $clog2(NB_SUBDIVISIONS) - 1):(14+NB_BITS_PER_SUBDIVISION)]]) + b_lut[x[(14 + NB_BITS_PER_SUBDIVISION + $clog2(NB_SUBDIVISIONS) - 1):(14+NB_BITS_PER_SUBDIVISION)]];
        end
    endfunction

    enum {IDLE, CALC} state;
    
    always_ff @(posedge clk) begin
        if (reset_i) begin
            state <= IDLE;
            z_o <= 32'd0;
            done_o <= 1'b0;
        end else begin
            case (state)
            IDLE: begin
                done_o <= 1'b0;
                if (start_i) begin
                    //z_o <= reciprocal_value(x_i);
                    z_o <= interpolated(x_i);
                    done_o <= 1'b0;
                    state <= CALC;
                end
            end
            CALC: begin
                done_o <= 1'b1;
                state <= IDLE;
            end
            endcase
        end
    end

endmodule