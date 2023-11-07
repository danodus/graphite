// sdram.sv
// Copyright (c) 2022-2023 Daniel Cliche
// SPDX-License-Identifier: MIT

module sdram(
    input  wire logic        clk,
    input  wire logic        reset_i,
    input  wire logic        sel_i,
    input  wire logic        wr_en_i,
    input  wire logic [3:0]  wr_mask_i,
    input  wire logic [31:0] address_in_i,
    input  wire logic [31:0] data_in_i,
    output      logic [31:0] data_out_o,
    output      logic        ack_o,

    // SDRAM interface
    input  wire logic                   sdram_clk,
    output	    logic [1:0]	            ba_o,
    output	    logic [12:0]            a_o,
    output	    logic                   cs_n_o,
    output      logic                   ras_n_o,
    output      logic                   cas_n_o,
    output	    logic                   we_n_o,
    output      logic [1:0]	            dqm_o,
    inout  wire	logic [15:0]	        dq_io,
    output      logic                   cke_o,
    output      logic                   sdram_clk_o
);

    logic [15:0] sdram_din;
    logic [15:0] sdram_dout;
    logic [23:0] sdram_ad;
    logic sdram_get;
    logic sdram_put;
    logic sdram_rd;
    logic sdram_wr;

    logic mem_write;
    logic mem_read;
    logic mem_busy;

    logic wait_mem_done;

    assign mem_read = sel_i & !wr_en_i;
    assign mem_write = sel_i & wr_en_i;
    
    always_ff @(posedge clk) begin
        if (reset_i) begin
            ack_o <= 1'b0;
            wait_mem_done <= 1'b0;
        end else begin
            if (sel_i && !wait_mem_done)
                wait_mem_done <= 1'b1;
            if (wait_mem_done) begin
                if (!mem_busy) begin
                    ack_o <= 1'b1;
                end
            end
            if (ack_o) begin
                ack_o <= 1'b0;
                wait_mem_done <= 1'b0;
            end
        end
    end

    cache_ctrl cache_ctrl(
        // CPU interface
        .cpu_clk(clk),
        .ram_clk(sdram_clk),
        .rst(reset_i),

        .m_addr({address_in_i[29:0], 2'd0}),
        .m_din(data_in_i),
        .m_dout(data_out_o),
        .m_ctrl(wr_mask_i),
        .m_rd(mem_read),
        .m_wr(mem_write),
        .m_bsy(mem_busy),

        // RAM interface
        .ram_din_o(sdram_din),
        .ram_dout_i(sdram_dout),
        .ram_addr_o(sdram_ad),
        .ram_get_i(sdram_get),
        .ram_put_i(sdram_put),
        .ram_rd_o(sdram_rd),
        .ram_wr_o(sdram_wr)
    );

    sdram_ctrl sdram_ctrl(
        .clk_in(sdram_clk),
        .din(sdram_din),
        .dout(sdram_dout),
        .ad(sdram_ad),
        .get(sdram_get),
        .put(sdram_put),
        .rd(sdram_rd),
        .wr(sdram_wr),
        .rst(reset_i),
        .calib(),

        // interface to the chip
        .sd_data(dq_io),
        .sd_addr(a_o),
        .sd_dqm(dqm_o),
        .sd_ba(ba_o),
        .sd_cs(cs_n_o),
        .sd_we(we_n_o),
        .sd_ras(ras_n_o),
        .sd_cas(cas_n_o),
        .sd_cke(cke_o),
        .sd_clk(sdram_clk_o)
    );

endmodule