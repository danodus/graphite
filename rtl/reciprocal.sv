`include "graphite.svh"

// f(x) = 1/x
module reciprocal(
    input wire logic clk,
    input wire logic [31:0] x_i,
    output     logic [31:0] z_o
);
    localparam NUMERATOR = 32'h0x100;
    localparam NB_BITS_PER_SUBDIVISION = 5;
    localparam NB_SUBDIVISIONS = 65536 / (2 ** NB_BITS_PER_SUBDIVISION);
    localparam ADJ_BITS = 16 + NB_BITS_PER_SUBDIVISION;

    logic [15:0] m_lut[NB_SUBDIVISIONS];
    logic [23:0] b_lut[NB_SUBDIVISIONS];

    logic [31:0] m, b;

    initial begin
        $readmemh("reciprocal_m_lut.hex", m_lut);
        $readmemh("reciprocal_b_lut.hex", b_lut);
    end

    function logic [31:0] reciprocal_value(logic [31:0] x);
        reciprocal_value = x > 0 ? rdiv(NUMERATOR << 16, x) : 32'd1 << 16;
    endfunction

    function logic [31:0] interpolated(logic [31:0] x);
        interpolated = rmul(x - {x[31:ADJ_BITS], {(ADJ_BITS){1'b0}}}, {16'hFFFF, m_lut[x[31:ADJ_BITS]]}) + {8'h00, b_lut[x[31:ADJ_BITS]]};
    endfunction

/*
    initial begin
        m_lut[0] = 16'hFFFF;
        b_lut[0] = 24'hFFFFFF;
        for (int i = 1; i < NB_SUBDIVISIONS; i++) begin
            m = (rdiv(NUMERATOR << 16, 32'((i + 1) * 65536/NB_SUBDIVISIONS) << 16) - rdiv(NUMERATOR << 16, 32'(i * 65536/NB_SUBDIVISIONS) << 16)) >>> NB_BITS_PER_SUBDIVISION;
            m_lut[i] = m[31:16];
            b = rdiv(NUMERATOR << 16, 32'(i * 65536/NB_SUBDIVISIONS) << 16);
            b_lut[i] = b[23:0];

            // For some unknown reasons, the following does not work:
            //m_lut[i] = (reciprocal_value(32'((i + 1) * 65536/NB_SUBDIVISIONS) << 16) - reciprocal_value(32'(i * 65536/NB_SUBDIVISIONS) << 16)) >>> NB_BITS_PER_SUBDIVISION;
            //b_lut[i] = reciprocal_value(32'(i * 65536/NB_SUBDIVISIONS) << 16);
        end

        for (int i = 0; i < NB_SUBDIVISIONS; i++) begin
            $display("%h", m_lut[i]);
        end
    end
*/    

    always_ff @(posedge clk) begin
        //z_o = reciprocal_value(x_i);
        z_o = interpolated(x_i);
        //z_o = 32'd0;
    end

endmodule