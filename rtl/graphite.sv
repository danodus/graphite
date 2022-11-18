// graphite.sv
// Copyright (c) 2021-2022 Daniel Cliche
// SPDX-License-Identifier: MIT

// Ref.: https://www.scratchapixel.com/lessons/3d-basic-rendering/rasterization-practical-implementation

`include "graphite.svh"

module graphite #(
    parameter FB_WIDTH = 128,
    parameter FB_HEIGHT = 128,
    parameter TEXTURE_WIDTH = 32,
    parameter TEXTURE_HEIGHT = 32,
    parameter SUBPIXEL_PRECISION_MASK = 16'hF000
    ) (
    input  wire logic                        clk,
    input  wire logic                        reset_i,

    // AXI stream command interface (slave)
    input  wire logic                        cmd_axis_tvalid_i,
    output      logic                        cmd_axis_tready_o,
    input  wire logic [31:0]                 cmd_axis_tdata_i,

    // VRAM write
    input  wire logic                        vram_ack_i,
    output      logic                        vram_sel_o,
    output      logic                        vram_wr_o,
    output      logic  [3:0]                 vram_mask_o,
    output      logic [31:0]                 vram_addr_o,
    input       logic [15:0]                 vram_data_in_i,
    output      logic [15:0]                 vram_data_out_o,

    input  wire logic                        vsync_i,
    output      logic                        swap_o,
    output      logic [31:0]                 front_addr_o
    );

    enum { WAIT_COMMAND, PROCESS_COMMAND, SWAP0, CLEAR_FB0, CLEAR_FB1, CLEAR_DEPTH0, CLEAR_DEPTH1, WRITE_TEX, DRAW, DRAW2
    } state;

    logic signed [31:0] x0, y0, z0, x1, y1, z1, x2, y2, z2;
    logic signed [31:0] r0, g0, b0;
    logic signed [31:0] r1, g1, b1;
    logic signed [31:0] r2, g2, b2;
    logic signed [31:0] s0, t0, s1, t1, s2, t2;

    // standard rasterizer
    logic bottom_half;
    logic signed [31:0] dax_step, dbx_step;
    logic signed [31:0] ds0_step, dt0_step, dw0_step;
    logic signed [31:0] ds1_step, dt1_step, dw1_step;
    logic signed [31:0] dr0_step, dg0_step, db0_step;
    logic signed [31:0] dr1_step, dg1_step, db1_step;

    logic [31:0] front_address, back_address, depth_address, texture_address;

    logic [31:0] texture_write_address;

    assign front_addr_o = front_address;

    logic is_textured, is_clamp_s, is_clamp_t, is_depth_test;

    logic rasterizer_start, rasterizer_busy;

    logic vram_sel, rasterizer_vram_sel;
    logic vram_wr, rasterizer_vram_wr;
    logic [3:0] vram_mask, rasterizer_vram_mask;
    logic [31:0] vram_addr, rasterizer_vram_addr;
    logic [15:0] vram_data_out, rasterizer_vram_data_out;

    always_comb begin
        if (state == DRAW || state == DRAW2) begin
            vram_sel_o = rasterizer_vram_sel;
            vram_wr_o = rasterizer_vram_wr;
            vram_mask_o = rasterizer_vram_mask;
            vram_addr_o = rasterizer_vram_addr;
            vram_data_out_o = rasterizer_vram_data_out;
        end else begin
            vram_sel_o = vram_sel;
            vram_wr_o = vram_wr;
            vram_mask_o = vram_mask;
            vram_addr_o = vram_addr;
            vram_data_out_o = vram_data_out;
        end
    end

`ifdef RASTERIZER_BARYCENTRIC
    rasterizer_barycentric
`else
    rasterizer_standard
`endif
    #(
        .FB_WIDTH(FB_WIDTH),
        .FB_HEIGHT(FB_HEIGHT),
        .TEXTURE_WIDTH(TEXTURE_WIDTH),
        .TEXTURE_HEIGHT(TEXTURE_HEIGHT),
        .SUBPIXEL_PRECISION_MASK(SUBPIXEL_PRECISION_MASK)
    ) rasterizer(
        .clk(clk),
        .reset_i(reset_i),

        .start_i(rasterizer_start),
        .busy_o(rasterizer_busy),

`ifdef RASTERIZER_BARYCENTRIC
        .vv00_i(x0), 
        .vv01_i(y0),
        .vv02_i(z0),
        .vv10_i(x1),
        .vv11_i(y1),
        .vv12_i(z1),
        .vv20_i(x2),
        .vv21_i(y2),
        .vv22_i(z2),
        
        .c00_i(r0),
        .c01_i(g0),
        .c02_i(b0),

        .c10_i(r1),
        .c11_i(g1),
        .c12_i(b1),

        .c20_i(r2),
        .c21_i(g2),
        .c22_i(b2),
        
        .st00_i(s0),
        .st01_i(t0),
        .st10_i(s1),
        .st11_i(t1),
        .st20_i(s2),
        .st21_i(t2),

`else // RASTERIZER_BARYCENTRIC

        .bottom_half_i(bottom_half),

        .y0_i(y0 >>> 16), 
        .y1_i(y1 >>> 16),
        .y2_i(y2 >>> 16),
        .x0_i(x0 >>> 16),
        .x1_i(x1 >>> 16),
        .s0_i(s0),
        .t0_i(t0),
        .w0_i(z0),
        .s1_i(s1),
        .t1_i(t1),
        .w1_i(z1),
        .r0_i(r0),
        .g0_i(g0),
        .b0_i(b0),
        .r1_i(r1),
        .g1_i(g1),
        .b1_i(b1),
        .dax_step_i(dax_step),
        .dbx_step_i(dbx_step),
        .ds0_step_i(ds0_step),
        .dt0_step_i(dt0_step),
        .dw0_step_i(dw0_step),
        .ds1_step_i(ds1_step),
        .dt1_step_i(dt1_step),
        .dw1_step_i(dw1_step),
        .dr0_step_i(dr0_step),
        .dg0_step_i(dg0_step),
        .db0_step_i(db0_step),
        .dr1_step_i(dr1_step),
        .dg1_step_i(dg1_step),
        .db1_step_i(db1_step),
`endif

        .is_textured_i(is_textured),
        .is_clamp_s_i(is_clamp_s),
        .is_clamp_t_i(is_clamp_t),
        .is_depth_test_i(is_depth_test),

        .back_address_i(back_address),
        .depth_address_i(depth_address),
        .texture_address_i(texture_address),        

        // VRAM write
        .vram_ack_i(vram_ack_i),
        .vram_sel_o(rasterizer_vram_sel),
        .vram_wr_o(rasterizer_vram_wr),
        .vram_mask_o(rasterizer_vram_mask),
        .vram_addr_o(rasterizer_vram_addr),
        .vram_data_in_i(vram_data_in_i),
        .vram_data_out_o(rasterizer_vram_data_out)
    );

    assign cmd_axis_tready_o = state == WAIT_COMMAND;

    always_ff @(posedge clk) begin
        case (state)
            WAIT_COMMAND: begin
                swap_o <= 1'b0;
                if (cmd_axis_tvalid_i)
                    state <= PROCESS_COMMAND;
            end

            PROCESS_COMMAND: begin
                case (cmd_axis_tdata_i[OP_POS+:OP_SIZE])
                    OP_SET_X0: begin
                        if (cmd_axis_tdata_i[16]) begin
                            x0[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            x0[15:0] <= cmd_axis_tdata_i[15:0] & SUBPIXEL_PRECISION_MASK;
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_Y0: begin
                        if (cmd_axis_tdata_i[16]) begin
                            y0[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            y0[15:0] <= cmd_axis_tdata_i[15:0] & SUBPIXEL_PRECISION_MASK;
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_Z0: begin
                        if (cmd_axis_tdata_i[16]) begin
                            z0[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            z0[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_X1: begin
                        if (cmd_axis_tdata_i[16]) begin
                            x1[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            x1[15:0] <= cmd_axis_tdata_i[15:0] & SUBPIXEL_PRECISION_MASK;
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_Y1: begin
                        if (cmd_axis_tdata_i[16]) begin
                            y1[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            y1[15:0] <= cmd_axis_tdata_i[15:0] & SUBPIXEL_PRECISION_MASK;
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_Z1: begin
                        if (cmd_axis_tdata_i[16]) begin
                            z1[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            z1[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_X2: begin
                        if (cmd_axis_tdata_i[16]) begin
                            x2[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            x2[15:0] <= cmd_axis_tdata_i[15:0] & SUBPIXEL_PRECISION_MASK;
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_Y2: begin
                        if (cmd_axis_tdata_i[16]) begin
                            y2[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            y2[15:0] <= cmd_axis_tdata_i[15:0] & SUBPIXEL_PRECISION_MASK;
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_Z2: begin
                        if (cmd_axis_tdata_i[16]) begin
                            z2[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            z2[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_R0: begin
                        if (cmd_axis_tdata_i[16]) begin
                            r0[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            r0[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_G0: begin
                        if (cmd_axis_tdata_i[16]) begin
                            g0[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            g0[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_B0: begin
                        if (cmd_axis_tdata_i[16]) begin
                            b0[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            b0[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_R1: begin
                        if (cmd_axis_tdata_i[16]) begin
                            r1[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            r1[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_G1: begin
                        if (cmd_axis_tdata_i[16]) begin
                            g1[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            g1[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_B1: begin
                        if (cmd_axis_tdata_i[16]) begin
                            b1[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            b1[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_R2: begin
                        if (cmd_axis_tdata_i[16]) begin
                            r2[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            r2[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_G2: begin
                        if (cmd_axis_tdata_i[16]) begin
                            g2[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            g2[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_B2: begin
                        if (cmd_axis_tdata_i[16]) begin
                            b2[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            b2[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_S0: begin
                        if (cmd_axis_tdata_i[16]) begin
                            s0[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            s0[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_T0: begin
                        if (cmd_axis_tdata_i[16]) begin
                            t0[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            t0[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_S1: begin
                        if (cmd_axis_tdata_i[16]) begin
                            s1[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            s1[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_T1: begin
                        if (cmd_axis_tdata_i[16]) begin
                            t1[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            t1[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_S2: begin
                        if (cmd_axis_tdata_i[16]) begin
                            s2[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            s2[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_T2: begin
                        if (cmd_axis_tdata_i[16]) begin
                            t2[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            t2[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DAX_STEP: begin
                        if (cmd_axis_tdata_i[16]) begin
                            dax_step[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            dax_step[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DBX_STEP: begin
                        if (cmd_axis_tdata_i[16]) begin
                            dbx_step[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            dbx_step[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DS0_STEP: begin
                        if (cmd_axis_tdata_i[16]) begin
                            ds0_step[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            ds0_step[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DT0_STEP: begin
                        if (cmd_axis_tdata_i[16]) begin
                            dt0_step[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            dt0_step[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DW0_STEP: begin
                        if (cmd_axis_tdata_i[16]) begin
                            dw0_step[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            dw0_step[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DS1_STEP: begin
                        if (cmd_axis_tdata_i[16]) begin
                            ds1_step[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            ds1_step[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DT1_STEP: begin
                        if (cmd_axis_tdata_i[16]) begin
                            dt1_step[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            dt1_step[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DW1_STEP: begin
                        if (cmd_axis_tdata_i[16]) begin
                            dw1_step[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            dw1_step[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DR0_STEP: begin
                        if (cmd_axis_tdata_i[16]) begin
                            dr0_step[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            dr0_step[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DG0_STEP: begin
                        if (cmd_axis_tdata_i[16]) begin
                            dg0_step[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            dg0_step[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DB0_STEP: begin
                        if (cmd_axis_tdata_i[16]) begin
                            db0_step[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            db0_step[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DR1_STEP: begin
                        if (cmd_axis_tdata_i[16]) begin
                            dr1_step[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            dr1_step[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DG1_STEP: begin
                        if (cmd_axis_tdata_i[16]) begin
                            dg1_step[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            dg1_step[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_SET_DB1_STEP: begin
                        if (cmd_axis_tdata_i[16]) begin
                            db1_step[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            db1_step[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_CLEAR: begin
                        vram_addr     <= (cmd_axis_tdata_i[16] == 0) ? back_address : 32'(2 * FB_WIDTH * FB_HEIGHT);
                        vram_data_out <= cmd_axis_tdata_i[15:0];
                        vram_mask     <= 4'hF;
                        vram_sel      <= 1'b1;
                        vram_wr       <= 1'b1;
                        state           <= (cmd_axis_tdata_i[16] == 0) ? CLEAR_FB0 : CLEAR_DEPTH0;
                    end
                    OP_DRAW: begin
                        is_textured     <= cmd_axis_tdata_i[0];
                        is_clamp_t      <= cmd_axis_tdata_i[1];
                        is_clamp_s      <= cmd_axis_tdata_i[2];
                        is_depth_test   <= cmd_axis_tdata_i[3];
                        bottom_half     <= cmd_axis_tdata_i[4];
                        rasterizer_start <= 1'b1;
                        state <= DRAW;
                    end
                    OP_SWAP: begin
                        if (vsync_i || !cmd_axis_tdata_i[0]) begin
                            swap_o <= 1'b1;
                            front_address <= back_address;
                            back_address  <= front_address;
                            state         <= SWAP0;
                        end
                    end
                    OP_SET_TEX_ADDR: begin
                        if (cmd_axis_tdata_i[16]) begin
                            texture_address[31:16] <= cmd_axis_tdata_i[15:0];
                            texture_write_address[31:16] <= cmd_axis_tdata_i[15:0];
                        end else begin
                            texture_address[15:0] <= cmd_axis_tdata_i[15:0];
                            texture_write_address[15:0] <= cmd_axis_tdata_i[15:0];
                        end
                        state <= WAIT_COMMAND;
                    end
                    OP_WRITE_TEX: begin
                        vram_addr <= texture_write_address;
                        vram_data_out <= cmd_axis_tdata_i[15:0];
                        vram_mask <= 4'hF;
                        vram_sel <= 1'b1;
                        vram_wr  <= 1'b1;
                        state <= WRITE_TEX;
                    end
                    default:
                        state <= WAIT_COMMAND;
                endcase
            end

            SWAP0: begin
                if (vsync_i) begin
                    state  <= WAIT_COMMAND;
                end
            end

            CLEAR_FB0: begin
                if (vram_ack_i) begin
                    vram_sel <= 1'b0;
                    vram_wr  <= 1'b0;
                    state <= CLEAR_FB1;
                end
            end

            CLEAR_FB1: begin
                if (vram_addr_o < back_address + FB_WIDTH * FB_HEIGHT - 1) begin
                    vram_addr <= vram_addr_o + 1;
                    vram_sel  <= 1'b1;
                    vram_wr   <= 1'b1;
                    state       <= CLEAR_FB0;
                end else begin
                    state       <= WAIT_COMMAND;
                end
            end

            CLEAR_DEPTH0: begin
                if (vram_ack_i) begin
                    vram_sel <= 1'b0;
                    vram_wr  <= 1'b0;
                    state  <= CLEAR_DEPTH1;
                end
            end

            CLEAR_DEPTH1: begin
                if (vram_addr_o < 3 * FB_WIDTH * FB_HEIGHT - 1) begin
                    vram_addr <= vram_addr_o + 1;
                    vram_sel  <= 1'b1;
                    vram_wr   <= 1'b1;
                    state       <= CLEAR_DEPTH0;
                end else begin
                    state      <= WAIT_COMMAND;
                end
            end

            WRITE_TEX: begin
                if (vram_ack_i) begin
                    vram_sel <= 1'b0;
                    vram_wr  <= 1'b0;
                    texture_write_address <= texture_write_address + 1;
                    state <= WAIT_COMMAND;
                end
            end

            DRAW: begin
                rasterizer_start <= 1'b0;
                state <= DRAW2;
            end

            DRAW2: begin
                if (!rasterizer_busy)
                    state <= WAIT_COMMAND;
            end
        endcase

        if (reset_i) begin
            swap_o              <= 1'b0;
            vram_sel          <= 1'b0;
            vram_wr           <= 1'b0;
            front_address       <= 32'h0;
            back_address        <= FB_WIDTH * FB_HEIGHT;
            depth_address       <= 2 * FB_WIDTH * FB_HEIGHT;
            texture_address     <= 3 * FB_WIDTH * FB_HEIGHT;
            state               <= WAIT_COMMAND;
            rasterizer_start    <= 1'b0;
        end
    end

endmodule

