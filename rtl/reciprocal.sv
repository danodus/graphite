`include "graphite.svh"

// f(x) = NUMERATOR/x
module reciprocal #(
    parameter NUMERATOR = 32'h100
)(
    input wire logic clk,
    input wire logic [31:0] x_i,
    output     logic [31:0] z_o
);
    localparam NB_SUBDIVISIONS = 2048;
    localparam SUBDIVISION_SIZE = 16384 / NB_SUBDIVISIONS;
    localparam NB_BITS_PER_SUBDIVISION = 3;

    logic [23:0] m_lut[NB_SUBDIVISIONS];
    logic [31:0] b_lut[NB_SUBDIVISIONS];

    logic [31:0] m;

    initial begin
        $readmemh("reciprocal_m_lut.hex", m_lut);
        $readmemh("reciprocal_b_lut.hex", b_lut);
    end

    function logic [31:0] reciprocal_value(logic [31:0] x);
        reciprocal_value = x > 0 ? rdiv(NUMERATOR << 16, x) : NUMERATOR << 16;
    endfunction

    function logic [31:0] interpolated(logic [31:0] x);
        if (x[31:30] > 0) begin
            interpolated = 32'd0;
        end else begin
            interpolated = rmul(x - {x[31:19], {(19){1'b0}}}, {8'hFF, m_lut[x[29:19]]}) + b_lut[x[29:19]];
        end
    endfunction

/*
    initial begin
        m = signed'(rdiv(NUMERATOR << 16, 32'((1) * SUBDIVISION_SIZE) << 16) - (NUMERATOR << 16)) >>> NB_BITS_PER_SUBDIVISION;
        m_lut[0] = m[23:0];
        b_lut[0] = NUMERATOR << 16;

        for (int i = 1; i < NB_SUBDIVISIONS; i++) begin
            m = signed'(rdiv(NUMERATOR << 16, 32'((i + 1) * SUBDIVISION_SIZE) << 16) - rdiv(NUMERATOR << 16, 32'(i * SUBDIVISION_SIZE) << 16)) >>> NB_BITS_PER_SUBDIVISION;
            m_lut[i] = m[23:0];
            b_lut[i] = rdiv(NUMERATOR << 16, 32'(i * SUBDIVISION_SIZE) << 16);
        end

        //for (int i = 0; i < NB_SUBDIVISIONS; i++) begin
        //    $display("%h", b_lut[i]);
        //end

        //for (int i = 0; i < 256; i++) begin
        //    $display("%0d,%0d,%0d", i, reciprocal_value(i << 16), interpolated(i << 16));
        //end
    end
*/
 
     always_ff @(posedge clk) begin
        //z_o = reciprocal_value(x_i);
        z_o = interpolated(x_i);
        //z_o = 32'd0;
    end

endmodule