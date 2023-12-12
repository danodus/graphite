// processor.sv
// Copyright (c) 2022-2023 Daniel Cliche
// SPDX-License-Identifier: MIT

module processor #(
    parameter IRQ_VEC_ADDR = 32'h00000010
) (
    input wire logic       clk,
    input wire logic       ce_i,
    input wire logic       reset_i,

    // interrupts (2)
    input wire logic  [1:0]  irq_i,
    output     logic  [1:0]  eoi_o,

    // memory
    output      logic        sel_o,
    output      logic [31:0] addr_o,
    output      logic        we_o,
    output      logic [3:0]  wr_mask_o,
    input  wire logic [31:0] data_in_i,
    output      logic [31:0] data_out_o,
    input  wire logic        ack_i
    );

    // instruction memory bus
    logic [31:0] instr_address;
    logic instr_read;
    logic [31:0] instr_read_value;
    logic instr_ready;
    logic instr_fault;

    // data memory bus
    logic [31:0] data_address;
    logic data_read;
    logic data_write;
    logic [31:0] data_read_value;
    logic [3:0] data_write_mask;
    logic [31:0] data_write_value;
    logic data_ready;
    logic data_fault;

    // memory bus
    logic [31:0] mem_address;
    logic mem_read;
    logic mem_write;
    logic [31:0] mem_read_value;
    logic [3:0] mem_write_mask;
    logic [31:0] mem_write_value;
    logic mem_ready;
    logic mem_fault;

    assign mem_read_value = data_in_i;

    assign addr_o = mem_address;
    assign we_o = mem_write;
    assign wr_mask_o = mem_write_mask;
    assign data_out_o = mem_write_value;



    always_ff @(posedge clk) begin
        if (ce_i) begin
            if (mem_read || mem_write)
                sel_o <= 1'b1;
            if (sel_o) begin
                sel_o <= 1'b0;
                mem_ready <= 1'b1;
            end
            if (mem_ready)
                mem_ready <= 1'b0;
`ifndef SYNTHESIS
            if (mem_fault)
                $display("******** MEM FAULT");
`endif
        end

        if (reset_i) begin
            sel_o <= 1'b0;
            mem_ready <= 1'b0;
        end
    end
/*
    assign sel_o = mem_read || mem_write;
    assign mem_ready = ce_i;
*/
    logic [63:0] cycle;

    bus_arbiter bus_arbiter(
        .clk(clk),
        .ce_i(ce_i),
        .reset(reset_i),

        // instruction memory bus
        .instr_address_in(instr_address),
        .instr_read_in(instr_read),
        .instr_read_value_out(instr_read_value),
        .instr_ready_out(instr_ready),
        .instr_fault_out(instr_fault),

        // data memory bus
        .data_address_in(data_address),
        .data_read_in(data_read),
        .data_write_in(data_write),
        .data_read_value_out(data_read_value),
        .data_write_mask_in(data_write_mask),
        .data_write_value_in(data_write_value),
        .data_ready_out(data_ready),
        .data_fault_out(data_fault),

        // common memory bus
        .address_out(mem_address),
        .read_out(mem_read),
        .write_out(mem_write),
        .read_value_in(mem_read_value),
        .write_mask_out(mem_write_mask),
        .write_value_out(mem_write_value),
        .ready_in(mem_ready),
        .fault_in(mem_fault)
    );

    rv32 #(
        .RESET_VECTOR(32'hF0000000)
    ) rv32(
        .clk(clk),
        .ce_i(ce_i),
        .reset(reset_i),

        // instruction memory bus
        .instr_address_out(instr_address),
        .instr_read_out(instr_read),
        .instr_read_value_in(instr_read_value),
        .instr_ready_in(instr_ready),
        .instr_fault_in(instr_fault),

        // data memory bus
        .data_address_out(data_address),
        .data_read_out(data_read),
        .data_write_out(data_write),
        .data_read_value_in(data_read_value),
        .data_write_mask_out(data_write_mask),
        .data_write_value_out(data_write_value),
        .data_ready_in(data_ready),
        .data_fault_in(data_fault),

        // timer
        .cycle_out(cycle)
    );
/*
    always_ff @(posedge clk) begin
        if (ce_i) begin
            $display("cycle: %d, sel_o: %x, addr_o: %x, we_o: %x, wr_mask_o: %x, data_in_i: %x, data_out_o: %x, ack_i: %x, inst_address: %x", cycle, sel_o, addr_o, we_o, wr_mask_o, data_in_i, data_out_o, ack_i, instr_address);
            if (cycle > 1024)
                $finish;
        end
    end
*/
endmodule