module fragment_shader #(
    parameter FB_WIDTH = 128,
    parameter FB_HEIGHT = 128,
    parameter TEXTURE_WIDTH = 32,
    parameter TEXTURE_HEIGHT = 32,
    parameter SUBPIXEL_PRECISION_MASK = 16'hF000
    ) (
    input  wire logic                        clk,
    input  wire logic                        reset_i,

    input wire logic               start_i,
    output     logic               busy_o,
    );

    enum { IDLE, DRAW,
           DRAW_TRIANGLE00, DRAW_TRIANGLE01, DRAW_TRIANGLE02, DRAW_TRIANGLE03, DRAW_TRIANGLE04, DRAW_TRIANGLE05,
           DRAW_TRIANGLE06, DRAW_TRIANGLE07, DRAW_TRIANGLE08, DRAW_TRIANGLE09, DRAW_TRIANGLE10, DRAW_TRIANGLE11,
           DRAW_TRIANGLE12, DRAW_TRIANGLE13, DRAW_TRIANGLE14, DRAW_TRIANGLE15, DRAW_TRIANGLE16, DRAW_TRIANGLE17,
           DRAW_TRIANGLE18, DRAW_TRIANGLE19, DRAW_TRIANGLE20, DRAW_TRIANGLE21, DRAW_TRIANGLE22, DRAW_TRIANGLE23,
           DRAW_TRIANGLE24, DRAW_TRIANGLE25, DRAW_TRIANGLE26, DRAW_TRIANGLE27, DRAW_TRIANGLE28, DRAW_TRIANGLE29,
           DRAW_TRIANGLE30, DRAW_TRIANGLE31, DRAW_TRIANGLE32, DRAW_TRIANGLE33, DRAW_TRIANGLE34, DRAW_TRIANGLE35,
           DRAW_TRIANGLE36, DRAW_TRIANGLE37, DRAW_TRIANGLE38, DRAW_TRIANGLE39, DRAW_TRIANGLE40, DRAW_TRIANGLE41,
           DRAW_TRIANGLE42, DRAW_TRIANGLE43, DRAW_TRIANGLE44, DRAW_TRIANGLE45, DRAW_TRIANGLE46, DRAW_TRIANGLE47,
           DRAW_TRIANGLE48, DRAW_TRIANGLE49, DRAW_TRIANGLE50, DRAW_TRIANGLE51, DRAW_TRIANGLE52, DRAW_TRIANGLE53,
           DRAW_TRIANGLE54, DRAW_TRIANGLE55, DRAW_TRIANGLE56, DRAW_TRIANGLE57, DRAW_TRIANGLE58, DRAW_TRIANGLE59,
           DRAW_TRIANGLE60
    } state;

    always_ff @(posedge clk) begin
        case (state)
            DRAW_TRIANGLE35: begin
                vram_addr_o <= depth_address_i + 32'(y) * FB_WIDTH + 32'(x);
                if (is_depth_test_i) begin
                    vram_wr_o <= 1'b0;
                    vram_sel_o <= 1'b1;
                    state <= DRAW_TRIANGLE36;
                end else begin
                    state <= DRAW_TRIANGLE39;
                end
            end

            DRAW_TRIANGLE36: begin
                // wait memory access
                if (vram_ack_i) begin
                    vram_sel_o <= 1'b0;
                    state <= DRAW_TRIANGLE37;
                end
            end

            DRAW_TRIANGLE37: begin
                depth <= 16'(vram_data_in_i);
                state <= DRAW_TRIANGLE38;
            end

            DRAW_TRIANGLE38: begin
                if (16'(z) > depth) begin
                    state <= DRAW_TRIANGLE39;
                end else begin
                    state <= DRAW_TRIANGLE59;
                end
            end

            DRAW_TRIANGLE39: begin
                vram_data_out_o <= 16'(z);
                vram_wr_o <= 1'b1;
                vram_sel_o <= 1'b1;
                state <= DRAW_TRIANGLE40;
            end

            DRAW_TRIANGLE40: begin
                // wait memory access
                if (vram_ack_i) begin
                    vram_sel_o <= 1'b0;
                    state <= DRAW_TRIANGLE41;
                end
            end

            DRAW_TRIANGLE41: begin
                reciprocal_x <= z << 12;
                state <= DRAW_TRIANGLE42;
            end

            DRAW_TRIANGLE42: begin
                dsp_mul_p0 <= r;
                dsp_mul_p1 <= (reciprocal_z << 12);
                state <= DRAW_TRIANGLE43;
            end

            DRAW_TRIANGLE43: begin
                r <= dsp_mul_z >> 8;
                dsp_mul_p0 <= g;
                state <= DRAW_TRIANGLE44;
            end

            DRAW_TRIANGLE44: begin
                g <= dsp_mul_z >> 8;
                dsp_mul_p0 <= b;
                state <= DRAW_TRIANGLE45;
            end

            DRAW_TRIANGLE45: begin
                b <= dsp_mul_z >> 8;
                dsp_mul_p0 <= s;
                state <= DRAW_TRIANGLE46;
            end

            DRAW_TRIANGLE46: begin
                s <= dsp_mul_z >> 8;
                dsp_mul_p0 <= t;
                state <= DRAW_TRIANGLE47;
            end

            DRAW_TRIANGLE47: begin
                t <= dsp_mul_z >> 8;
                state <= DRAW_TRIANGLE48;
            end

            DRAW_TRIANGLE48: begin
                if (is_textured_i) begin
                    state <= DRAW_TRIANGLE49;
                end else begin
                    state <= DRAW_TRIANGLE54;
                end
            end

            DRAW_TRIANGLE49: begin
                // t0 = rmul(mul((TEXTURE_HEIGHT - 1) << 16, clamp(t)), TEXTURE_WIDTH << 16)
                dsp_mul_p0 <= ((TEXTURE_HEIGHT - 1) << 16);
                dsp_mul_p1 <= (is_clamp_t_i ? clamp(t) : wrap(t));
                state <= DRAW_TRIANGLE50;
            end

            DRAW_TRIANGLE50: begin
                t0 <= mul(dsp_mul_z & 32'hFFFF0000, TEXTURE_WIDTH << 16);
                // t1 = mul((TEXTURE_WIDTH - 1) << 16, clamp(s))
                dsp_mul_p0 <= ((TEXTURE_WIDTH - 1) << 16);
                dsp_mul_p1 <= (is_clamp_s_i ? clamp(s) : wrap(s));
                state <= DRAW_TRIANGLE51;
            end

            DRAW_TRIANGLE51: begin
                vram_sel_o <= 1'b1;
                vram_wr_o  <= 1'b0;
                vram_addr_o <= texture_address_i + 32'((t0 + dsp_mul_z) >> 16);
                state <= DRAW_TRIANGLE52;
            end

            DRAW_TRIANGLE52: begin
                // wait memory access
                if (vram_ack_i) begin
                    state <= DRAW_TRIANGLE53;
                    vram_sel_o <= 1'b0;
                end
            end

            DRAW_TRIANGLE53: begin
                sample <= vram_data_in_i;
                state <= DRAW_TRIANGLE54;
            end

            DRAW_TRIANGLE54: begin
                vram_data_out_o[15:12] <= 4'hF;
                // vram_data_out_o[11:8] = 4'(mul({12'd0, sample[11:8], 16'd0}, r) >> 16)
                // vram_data_out_o[7:4] = 4'(mul({12'd0, sample[7:4], 16'd0}, g) >> 16)
                // vram_data_out_o[3:0] = 4'(mul({12'd0, sample[3:0], 16'd0}, b) >> 16)
                dsp_mul_p0 <= {12'd0, sample[11:8], 16'd0};
                dsp_mul_p1 <= r;
                state <= DRAW_TRIANGLE55;
            end

            DRAW_TRIANGLE55: begin
                vram_data_out_o[11:8] <= 4'(dsp_mul_z >> 16);
                dsp_mul_p0 <= {12'd0, sample[7:4], 16'd0};
                dsp_mul_p1 <= g;
                state <= DRAW_TRIANGLE56;
            end

            DRAW_TRIANGLE56: begin
                vram_data_out_o[7:4] <= 4'(dsp_mul_z >> 16);
                dsp_mul_p0 <= {12'd0, sample[3:0], 16'd0};
                dsp_mul_p1 <= b;
                state <= DRAW_TRIANGLE57;
            end

            DRAW_TRIANGLE57: begin
                vram_data_out_o[3:0] <= 4'(dsp_mul_z >> 16);
                vram_sel_o <= 1'b1;
                vram_wr_o  <= 1'b1;
                vram_addr_o <= back_address_i + raster_rel_address;
                state <= DRAW_TRIANGLE58;
            end

            DRAW_TRIANGLE58: begin
                // wait memory access
                if (vram_ack_i) begin
                    state <= DRAW_TRIANGLE59;
                    vram_sel_o <= 1'b0;
                    vram_wr_o  <= 1'b0;
                end
            end

        endcase

        if (reset_i) begin
            state               <= IDLE;
            vram_sel_o          <= 1'b0;
            vram_wr_o           <= 1'b0; 
            vram_mask_o         <= 4'hF;                       
        end        
    end



endmodule