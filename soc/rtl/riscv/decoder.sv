// decoder.sv
// Copyright (c) 2022-2023 Daniel Cliche
// SPDX-License-Identifier: MIT

module decoder #(
    parameter IRQ_VEC_ADDR = 32'h00000010
) (
    input  wire logic        en_i,
    input  wire logic        irq_i,
    input  wire logic [0:0]  irq_num_i,
    input  wire logic [31:0] instr_i,
    input  wire logic [31:0] reg_out1_i,
    input  wire logic [31:0] reg_out2_i,
    output      logic [1:0]  next_pc_sel_o,
    output      logic [1:0]  reg_in_source_o,   // 0: ALU out, 1: memory data out, 2: PC + 4
    output      logic [5:0]  reg_in_sel_o,
    output      logic        reg_in_en_o,
    output      logic [5:0]  reg_out1_sel_o,
    output      logic [5:0]  reg_out2_sel_o,
    output      logic [2:0]  alu_op_o,
    output      logic        alu_op_qual_o,
    output      logic        alu_op_ext_o,
    output      logic        d_we_o,
    output      logic        addr_valid_o,
    output      logic [31:0] addr_o,
    output      logic [31:0] imm_o,
    output      logic        alu_in1_sel_o,   // 0: RF out1, 1: PC
    output      logic        alu_in2_sel_o,   // 0: RF out2, 1: immediate
    output      logic [3:0]  mask_o,
    output      logic        sext_o,
    output      logic        eoi_o
    );

    logic [4:0] rd;
    logic [4:0] rs1;
    logic [4:0] rs2;

    logic [31:0] i_imm;
    logic [31:0] s_imm;
    logic [31:0] b_imm;
    logic [31:0] u_imm;
    logic [31:0] j_imm;

    logic [2:0] branch_predicate;
    logic is_branch_taken;
    
    always_comb begin
        rd   = instr_i[11:7];
        rs1 = instr_i[19:15];
        rs2 = instr_i[24:20];

        i_imm = {{21{instr_i[31]}}, instr_i[30:20]};
        s_imm = {{21{instr_i[31]}}, instr_i[30:25], instr_i[11:7]};
        b_imm = {{20{instr_i[31]}}, instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0};
        u_imm = {instr_i[31:12], {12{1'b0}}};
        j_imm = {{12{instr_i[31]}}, instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0};
    end

    always_comb begin
        next_pc_sel_o   = 2'b00;
        
        reg_in_source_o = 2'b00;
        reg_in_en_o     = 1'b0;

        alu_op_o        = 3'b000;
        alu_op_qual_o   = 1'b0;
        alu_op_ext_o    = 1'b0;

        addr_valid_o    = 1'b0;
        d_we_o          = 1'b0;

        addr_o          = 32'd0;

        imm_o           = 32'd0;
        alu_in1_sel_o   = 1'b0;
        alu_in2_sel_o   = 1'b0;

        is_branch_taken = 1'b0;

        reg_in_sel_o    = 6'b000000;
        reg_out1_sel_o  = 6'b000000;
        reg_out2_sel_o  = 6'b000000;

        mask_o          = 4'b1111;
        sext_o          = 1'b0;
        eoi_o           = 1'b0;

        if (en_i) begin
            // decode the instruction and assert the relevent control signals
            if (irq_i) begin
                reg_in_source_o = 2'b11;    // write PC in RF
                reg_in_sel_o    = 6'd32;    // q0
                reg_in_en_o     = 1'b1;     // write to RF
                addr_o          = IRQ_VEC_ADDR + irq_num_i * 4;
                next_pc_sel_o   = 2'b11;    // set PC to the addr field
            end else begin
                case (instr_i[6:0])

                    // LUI
                    7'b0110111: begin
                        reg_in_sel_o    = {1'b0, rd};
                        reg_out1_sel_o  = 6'b000000; // zero in ALU in1
                        imm_o           = u_imm;
                        alu_in2_sel_o   = 1'b1;     // immediate value in ALU in2
                        alu_op_o        = 3'b000;   // ALU add operation
                        reg_in_source_o = 2'b00;    // write ALU result to RF
                        reg_in_en_o     = 1'b1;     // enable write to RF
                    end

                    // AUIPC
                    7'b0010111: begin
                        reg_in_sel_o    = {1'b0, rd};
                        imm_o           = u_imm;
                        alu_in1_sel_o   = 1'b1;     // PC value in ALU in1
                        alu_in2_sel_o   = 1'b1;     // immediate value in ALU in2
                        alu_op_o        = 3'b000;   // ALU add operation
                        reg_in_source_o = 2'b00;    // write ALU result to RF
                        reg_in_en_o     = 1'b1;     // enable write to RF
                    end

                    // JAL
                    7'b1101111: begin
                        reg_in_source_o = 2'b10; // write PC + 4 in RF
                        reg_in_sel_o    = {1'b0, rd};
                        reg_in_en_o     = 1'b1;  // write to RF
                        addr_o          = j_imm;
                        next_pc_sel_o   = 2'b01; // add the addr field to PC
                    end

                    // JALR
                    7'b1100111: begin
                        reg_in_source_o = 2'b10; // write PC + 4 in RF
                        reg_in_sel_o    = {1'b0, rd};
                        reg_in_en_o     = 1'b1;  // write to RF
                        reg_out1_sel_o  = {1'b0, rs1};
                        addr_o          = reg_out1_i + i_imm;
                        addr_o          = {addr_o[31:1], 1'b0};
                        next_pc_sel_o   = 2'b11; // set PC to the addr field
                    end

                    // BEQ, BNE, BLT, BGE, BLTU, BGEU
                    7'b1100011: begin
                        reg_out1_sel_o = {1'b0, rs1};
                        reg_out2_sel_o = {1'b0, rs2};

                        addr_o = b_imm;
                        case (instr_i[14:12])
                            // BEQ
                            3'b000:
                                if (reg_out1_i == reg_out2_i)
                                    is_branch_taken = 1'b1;
                                    
                            // BNE
                            3'b001:
                                if (reg_out1_i != reg_out2_i)
                                    is_branch_taken = 1'b1;
                            
                            // BLT
                            3'b100:
                                if ($signed(reg_out1_i) < $signed(reg_out2_i))
                                    is_branch_taken = 1'b1;

                            // BGE
                            3'b101:
                                if ($signed(reg_out1_i) >= $signed(reg_out2_i))
                                    is_branch_taken = 1'b1;

                            // BLTU
                            3'b110:
                                if (reg_out1_i < reg_out2_i)
                                    is_branch_taken = 1'b1;
                            
                            // BGEU
                            3'b111:
                                if (reg_out1_i >= reg_out2_i)
                                    is_branch_taken = 1'b1;
                        endcase

                        if (is_branch_taken)
                            next_pc_sel_o = 2'b01; // add the addr field to PC
                    end

                    // LB, LH, LW, LBU, LHU
                    7'b0000011: begin
                        reg_in_sel_o = {1'b0, rd};                
                        reg_out1_sel_o = {1'b0, rs1};

                        addr_o = reg_out1_i + i_imm;
                        case (instr_i[14:12])
                            // LB
                            3'b000: begin
                                addr_valid_o    = 1'b1; // address valid
                                d_we_o          = 1'b0; // do not write to memory
                                reg_in_source_o = 2'b01; // write memory data to RF
                                reg_in_en_o     = 1'b1; // enable RF write
                                mask_o          = 4'b0001;
                                sext_o          = 1'b1;
                            end

                            // LH
                            3'b001: begin
                                addr_valid_o    = 1'b1; // address valid
                                d_we_o          = 1'b0; // do not write to memory
                                reg_in_source_o = 2'b01; // write memory data to RF
                                reg_in_en_o     = 1'b1; // enable RF write
                                mask_o          = 4'b0011;
                                sext_o          = 1'b1;
                            end

                            // LW
                            3'b010: begin
                                addr_valid_o    = 1'b1; // address valid
                                d_we_o          = 1'b0; // do not write to memory
                                reg_in_source_o = 2'b01; // write memory data to RF
                                reg_in_en_o     = 1'b1; // enable RF write
                            end

                            // LBU
                            3'b100: begin
                                addr_valid_o    = 1'b1; // address valid
                                d_we_o          = 1'b0; // do not write to memory
                                reg_in_source_o = 2'b01; // write memory data to RF
                                reg_in_en_o     = 1'b1; // enable RF write
                                mask_o          = 4'b0001;
                            end

                            // LHU
                            3'b101: begin
                                addr_valid_o    = 1'b1; // address valid
                                d_we_o          = 1'b0; // do not write to memory
                                reg_in_source_o = 2'b01; // write memory data to RF
                                reg_in_en_o     = 1'b1; // enable RF write
                                mask_o          = 4'b0011;
                            end
                        endcase                
                    end

                    // SB, SH, SW
                    7'b0100011: begin
                        reg_out1_sel_o = {1'b0, rs1};
                        reg_out2_sel_o = {1'b0, rs2};
                        addr_o = reg_out1_i + s_imm;
                        case (instr_i[14:12])
                            // SB
                            3'b000: begin
                                addr_valid_o    = 1'b1; // address valid
                                d_we_o          = 1'b1; // write to memory
                                mask_o          = 4'b0001;
                            end

                            // SH
                            3'b001: begin
                                addr_valid_o    = 1'b1; // address valid
                                d_we_o          = 1'b1; // write to memory
                                mask_o          = 4'b0011;
                            end

                            // SW
                            3'b010: begin
                                addr_valid_o    = 1'b1; // address valid
                                d_we_o          = 1'b1; // write to memory
                            end
                        endcase
                    end

                    // ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
                    7'b0010011: begin
                        reg_in_sel_o    = {1'b0, rd};
                        reg_out1_sel_o  = {1'b0, rs1};
                        alu_op_o        = instr_i[14:12];
                        reg_in_source_o = 2'b00; // write ALU result to RF
                        reg_in_en_o     = 1'b1; // write to RF
                        imm_o           = i_imm;
                        alu_in2_sel_o   = 1'b1; // immediate value in ALU in2
                        // Set opcode qualifier for SRLI and SRAI only
                        if (instr_i[14:12] == 3'b101) begin
                            alu_op_qual_o   = instr_i[30];
                        end
                    end

                    // ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
                    7'b0110011: begin
                        reg_in_sel_o    = {1'b0, rd};
                        reg_out1_sel_o  = {1'b0, rs1};
                        reg_out2_sel_o  = {1'b0, rs2};
                        alu_op_o        = instr_i[14:12];
                        alu_op_qual_o   = instr_i[30];
                        alu_op_ext_o    = instr_i[25];
                        reg_in_source_o = 2'b00; // write ALU result to RF
                        reg_in_en_o     = 1'b1; // write to RF
                        alu_in2_sel_o   = 1'b0; // register out2 in ALU in2
                    end

                    // FENCE
                    7'b0001111: begin
                        // TODO
                    end

                    // ECALL, EBREAK, SRET or MRET
                    7'b1110011: begin
                        case (instr_i[31:20])
                            12'b000000000000,
                            12'b000000000001: begin
                                // ECALL, EBREAK
                                reg_in_source_o = 2'b10;    // write PC+4 in RF
                                reg_in_sel_o    = 6'd33;    // q1
                                reg_in_en_o     = 1'b1;     // write to RF
                                addr_o          = IRQ_VEC_ADDR + (instr_i[20] ? 3 : 2) * 4;
                                next_pc_sel_o   = 2'b11;    // set PC to the addr field
                            end
                            12'b000100000010,
                            12'b001100000010: begin
                                // SRET, MRET
                                reg_out1_sel_o  = instr_i[29] ? 6'd32 : 6'd33;  // MRET in q0, SRET in q1
                                addr_o          = reg_out1_i;
                                addr_o          = {addr_o[31:1], 1'b0};
                                next_pc_sel_o   = 2'b11;                // set PC to the addr field
                                eoi_o           = 1'b1;
                            end
                        endcase
                    end
                endcase
            end // not irq
        end // if enabled
    end

endmodule