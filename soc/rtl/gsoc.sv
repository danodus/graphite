// gsoc.sv
// Copyright (c) 2023 Daniel Cliche
// SPDX-License-Identifier: MIT

module gsoc(
    input wire logic clk_cpu,
    input wire logic clk_sdram,
    input wire logic clk_pixel,
    input wire logic reset_i,

    // LED
    output      logic [7:0]  led_o,

    // UART    
    output      logic        tx_o,
    input  wire logic        rx_i,

    // SDRAM
    output      logic        sdram_cs_n_o,
    output      logic        sdram_we_n_o,
    output      logic        sdram_ras_n_o,
    output      logic        sdram_cas_n_o,
    output      logic [12:0] sdram_a_o,
    output      logic [1:0]  sdram_ba_o,
    output      logic [1:0]  sdram_dqm_o,
    inout       logic [15:0] sdram_dq_io
);

    // Interrupts (2)
    logic [1:0] irq;   // interrupt request
    logic [1:0] eoi;   // end of interrupt

    // Bus
    logic        sel;
    logic [31:0] addr;
    logic        mem_we, cpu_we;
    logic [31:0] cpu_data_in;
    logic [31:0] bios_rom_data_out, bios_ram_data_out, ram_data_out, mem_data_out, cpu_data_out;
    logic [3:0]  wr_mask;
    logic        bios_rom_ack, bios_ram_ack, ram_ack, device_ack;

    // BIOS ROM
    bram #(
        .SIZE(1024),
        .INIT_FILE("prom.mem")
    ) bios_rom(
        .clk(clk_cpu),
        .sel_i(sel && (addr[31:28] == 4'hF)),
        .wr_en_i(1'b0),
        .wr_mask_i(wr_mask),
        .address_in_i(32'(addr[27:0] >> 2)),
        .data_in_i(cpu_data_out), 
        .data_out_o(bios_rom_data_out),
        .ack_o(bios_rom_ack)
    );

    // BIOS RAM
    bram #(
        .SIZE(512)
    ) bios_ram(
        .clk(clk_cpu),
        .sel_i(sel && (addr[31:28] == 4'hD)),
        .wr_en_i(mem_we),
        .wr_mask_i(wr_mask),
        .address_in_i(32'(addr[27:0] >> 2)),
        .data_in_i(cpu_data_out), 
        .data_out_o(bios_ram_data_out),
        .ack_o(bios_ram_ack)
    );

    // RAM
    sdram ram(
        .clk(clk_cpu),
        .reset_i(reset_i),
        .sel_i(sel && (addr[31:28] == 4'h0)),
        .address_in_i(32'(addr[27:0] >> 2)),
        .wr_en_i(mem_we),
        .wr_mask_i(wr_mask),
        .data_in_i(cpu_data_out), 
        .data_out_o(ram_data_out),
        .ack_o(ram_ack),

        // SDRAM interface
        .sdram_clk(clk_sdram),
        .ba_o(sdram_ba_o),
        .a_o(sdram_a_o),
        .cs_n_o(sdram_cs_n_o),
        .ras_n_o(sdram_ras_n_o),
        .cas_n_o(sdram_cas_n_o),
        .we_n_o(sdram_we_n_o),
        .dq_io(sdram_dq_io),
        .dqm_o(sdram_dqm_o),
        .cke_o(),
        .sdram_clk_o()
    );

    processor #(
        .RESET_VEC_ADDR(32'hF0000000),
        .IRQ_VEC_ADDR(32'h00000010)   // IRQ vector in RAM
    ) cpu(
        .clk(clk_cpu),
        .reset_i(reset_i),
        .irq_i(irq),
        .eoi_o(eoi),
        .sel_o(sel),
        .addr_o(addr),
        .we_o(cpu_we),
        .data_in_i(cpu_data_in),
        .data_out_o(cpu_data_out),
        .wr_mask_o(wr_mask),
        .ack_i(bios_rom_ack || bios_ram_ack || ram_ack || device_ack)
    );

    always_comb begin
        mem_data_out =
            (addr[31:28] == 4'h0) ? ram_data_out
            : (addr[31:28] == 4'hD) ? bios_ram_data_out
            : bios_rom_data_out;
    end

    ///////////////////////////////////////////////////////////////////////////
    // Devices
    ///////////////////////////////////////////////////////////////////////////

    assign irq[1] = 1'b0;

    // Address decoding
    logic timer_device_sel;
    logic led_device_sel;
    logic uart_device_sel;
    always_comb begin
        timer_device_sel = 1'b0;
        led_device_sel = 1'b0;
        uart_device_sel = 1'b0;
        mem_we = 1'b0;
        if (addr[31:28] == 4'hE) begin
            // Device
            if (addr[15:12] == 4'h0)
                timer_device_sel = 1'b1;
            if (addr[15:12] == 4'h1)
                led_device_sel = 1'b1;
            else if (addr[15:12] == 4'h2)
                uart_device_sel = 1'b1;
        end else begin
            mem_we = cpu_we;
        end
    end

    logic [31:0] timer_device_data_out;
    logic timer_device_ack;
    timer_device #(
`ifdef FAST_CPU
        .FREQ_HZ(50 * 1000000)
`else
        .FREQ_HZ(25 * 1000000)
`endif
    ) timer_device(
        .clk(clk_cpu),
        .reset_i(reset_i),

        .sel_i(sel && timer_device_sel),
        .wr_en_i(cpu_we),
        .address_in_i(addr[11:0]),
        .data_in_i(cpu_data_out),
        .data_out_o(timer_device_data_out),
        .ack_o(timer_device_ack),

        .timer_eoi_i(eoi[0]),
        .timer_irq_o(irq[0])
    );

    logic [31:0] led_device_data_out;
    logic led_device_ack;
    led_device led_device(
        .clk(clk_cpu),
        .reset_i(reset_i),
        
        .sel_i(sel && led_device_sel),
        .wr_en_i(cpu_we),
        .address_in_i(addr[11:0]),
        .data_in_i(cpu_data_out),
        .data_out_o(led_device_data_out),
        .ack_o(led_device_ack),

        .led_o(led_o)
    );

    logic [31:0] uart_device_data_out;
    logic uart_device_ack;
    uart_device #(
`ifdef FAST_CPU
        .FREQ_HZ(50 * 1000000)
`else
        .FREQ_HZ(25 * 1000000)
`endif
    ) uart_device(
        .clk(clk_cpu),
        .reset_i(reset_i),

        .sel_i(sel && uart_device_sel),
        .wr_en_i(cpu_we),
        .address_in_i(addr[11:0]),
        .data_in_i(cpu_data_out),
        .data_out_o(uart_device_data_out),
        .ack_o(uart_device_ack),

        .tx_o(tx_o),
        .rx_i(rx_i)
    );

    always_comb begin
        cpu_data_in = mem_data_out;
        if (!cpu_we) begin
            if (timer_device_sel)
                cpu_data_in = timer_device_data_out;
            if (led_device_sel)
                cpu_data_in = led_device_data_out;
            else if (uart_device_sel)
                cpu_data_in = uart_device_data_out;
        end
    end

    assign device_ack = timer_device_ack | led_device_ack | uart_device_ack;

endmodule
