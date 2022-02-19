`include "graphite.svh"

// f(x) = 1/x
module reciprocal(
    input wire logic [31:0] x_i,
    output     logic [31:0] z_o
);
    localparam NB_BITS_PER_SUBDIVISION = 6;
    localparam NB_SUBDIVISIONS = 65536 / (2 ** NB_BITS_PER_SUBDIVISION);
    localparam ADJ_BITS = 16 + NB_BITS_PER_SUBDIVISION;

    logic [31:0] m_lut[NB_SUBDIVISIONS];
    logic [31:0] b_lut[NB_SUBDIVISIONS];

    function logic [31:0] reciprocal_value(logic [31:0] x);
        reciprocal_value = x > 0 ? rdiv(32'd1 << 16, x) : 32'd1 << 16;
    endfunction

    function logic [31:0] interpolated(logic [31:0] x);
        interpolated = rmul(x - {x[31:ADJ_BITS], {(ADJ_BITS){1'b0}}}, m_lut[x[31:ADJ_BITS]]) + b_lut[x[31:ADJ_BITS]];
    endfunction
/*
    initial begin
        m_lut[0] = 32'd0;
        b_lut[0] = 32'd1 << 16;
        for (int i = 1; i < NB_SUBDIVISIONS; i++) begin
            m_lut[i] = (rdiv(32'd1 << 16, 32'((i + 1) * 65536/NB_SUBDIVISIONS) << 16) - rdiv(32'd1 << 16, 32'(i * 65536/NB_SUBDIVISIONS) << 16)) >>> NB_BITS_PER_SUBDIVISION;
            b_lut[i] = rdiv(32'd1 << 16, 32'(i * 65536/NB_SUBDIVISIONS) << 16);
            // For some unknown reasons, the following does not work:
            //m_lut[i] = (reciprocal_value(32'((i + 1) * 65536/NB_SUBDIVISIONS) << 16) - reciprocal_value(32'(i * 65536/NB_SUBDIVISIONS) << 16)) >>> NB_BITS_PER_SUBDIVISION;
            //b_lut[i] = reciprocal_value(32'(i * 65536/NB_SUBDIVISIONS) << 16);
        end

        //for (int i = 0; i < 256; i++) begin
        //    $display("%d, %d, %d", i, reciprocal_value(i << 16), interpolated(i << 16));
        //end
    end
*/
    always_comb begin
        z_o = reciprocal_value(x_i);
        //z_o = interpolated(x_i);
        //z_o = 32'd0;
    end

endmodule