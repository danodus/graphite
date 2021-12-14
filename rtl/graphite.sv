`include "graphite_pkg.sv"

module graphite #(
    parameter FB_WIDTH = 128,
    parameter FB_HEIGHT = 128,
    parameter CMD_STREAM_WIDTH = 16
    ) (
    input  wire logic                        clk,
    input  wire logic                        reset_i,

    // AXI stream command interface (slave)
    input  wire logic                        cmd_axis_tvalid_i,
    output      logic                        cmd_axis_tready_o,
    input  wire logic [CMD_STREAM_WIDTH-1:0] cmd_axis_tdata_i,

    // VRAM write
    //input  wire logic                        vram_ack_i,
    output      logic                        vram_sel_o,
    output      logic                        vram_wr_o,
    output      logic  [3:0]                 vram_mask_o,
    output      logic [15:0]                 vram_addr_o,
    output      logic [15:0]                 vram_data_out_o
    );

    enum { WAIT_COMMAND, PROCESS_COMMAND, CLEAR } state;

    always_ff @(posedge clk) begin

        case (state)
            WAIT_COMMAND: begin
                cmd_axis_tready_o <= 1;
                if (cmd_axis_tvalid_i)
                    state <= PROCESS_COMMAND;
            end

            PROCESS_COMMAND: begin
                cmd_axis_tready_o <= 0;
                case (cmd_axis_tdata_i[OP_POS+:OP_SIZE])
                    OP_NOP: begin
                        $display("NOP opcode received");
                        state <= WAIT_COMMAND;
                    end
                    OP_CLEAR: begin
                        $display("Clear opcode received");
                        vram_addr_o     <= 16'h0;
                        vram_data_out_o <= {4'hF, cmd_axis_tdata_i[OP_POS - 1:0]};
                        vram_mask_o     <= 4'hF;
                        vram_sel_o      <= 1'b1;
                        vram_wr_o       <= 1'b1;
                        state           <= CLEAR;
                    end
                    default:
                        state <= WAIT_COMMAND;
                endcase
            end

            CLEAR: begin
                if (vram_addr_o < FB_WIDTH * FB_HEIGHT - 1) begin
                    vram_addr_o <= vram_addr_o + 1;
                end else begin
                    vram_sel_o <= 1'b0;
                    vram_wr_o  <= 1'b0;
                    state      <= WAIT_COMMAND;
                end
            end

        endcase

        if (reset_i) begin
            cmd_axis_tready_o <= 0;
            vram_sel_o <= 1'b0;
            state <= WAIT_COMMAND;
        end
    end


endmodule

