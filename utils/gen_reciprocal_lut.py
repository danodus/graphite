#!/usr/bin/env python3
import math

def generate_sst1_lut():
    filename = "reciprocal_lut.v"
    print(f"Generating {filename}...")
    
    f = open(filename, "w")
    
    # -------------------------------------------------------------------------
    # WRITE VERILOG MODULE HEADER & DOCUMENTATION
    # -------------------------------------------------------------------------
    f.write("`timescale 1ns / 1ps\n\n")
    f.write("// =========================================================================\n")
    f.write("// Automatically Generated Piecewise Linear Reciprocal LUT\n")
    f.write("// \n")
    f.write("// Mathematical Architecture:\n")
    f.write("//   Input index (idx) represents a uniform sub-interval slice in the range [1.0, 2.0).\n")
    f.write("//   Normalized Coordinate Value: x = 1.0 + (idx / 256.0)\n")
    f.write("// \n")
    f.write("// Equations:\n")
    f.write("//   lut_base(idx)  = round( 2^30 / x )\n")
    f.write("//   lut_slope(idx) = lut_base(idx) - lut_base(idx + 1)\n")
    f.write("// =========================================================================\n\n")
    
    f.write("module reciprocal_lut (\n")
    f.write("    input  wire        clk,        // Synchronous BRAM clock\n")
    f.write("    input  wire        stall,      // Stall input (from reciprocal_lerp)\n")
    f.write("    input  wire [7:0]  idx,        // 8-bit normalization interval index\n")
    f.write("    output reg  [31:0] base,       // 32-bit segment base anchor point\n")
    f.write("    output reg  [23:0] slope       // 24-bit linear downward correction scale factor\n")
    f.write(");\n\n")
    
    f.write("    // Inferred Block RAM Look-Up Table Structure\n")
    f.write("    always @(posedge clk) if (!stall) begin\n")
    f.write("        case (idx)\n")
    
    # -------------------------------------------------------------------------
    # COMPUTE LUT ENTRIES FOR THE 256 INTERVALS
    # -------------------------------------------------------------------------
    for i in range(256):
        # Current interval normalized x position
        x_current = 1.0 + (float(i) / 256.0)
        
        # Next interval normalized x position (for slope delta calculation)
        x_next = 1.0 + (float(i + 1) / 256.0)
        
        # Calculate Base value (fixed-point format matching 32-bit width)
        base_val = int(round((1 << 30) / x_current))
        
        # Calculate next Base value to evaluate slope
        next_base_val = int(round((1 << 30) / x_next))
        
        # Slope is the downward distance delta across this specific interval
        slope_val = base_val - next_base_val
        
        # Write format compatible with clean Verilog case matching synthesis tools
        f.write("            8'h%02X: begin base <= 32'h%08X; slope <= 24'h%06X; end\n" % (i, base_val, slope_val))
        
    f.write("            default: begin base <= 32'h00000000; slope <= 24'h000000; end\n")
    f.write("        endcase\n")
    f.write("    end\n\n")
    f.write("endmodule\n")
    
    f.close()
    print(f"Success! {filename} generated flawlessly.")

if __name__ == "__main__":
    generate_sst1_lut()
