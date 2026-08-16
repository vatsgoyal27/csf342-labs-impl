`timescale 1ns/1ps

module ControlUnit (
    input  wire [31:0] instruction,

    // Control Signals
    output reg        RegWrite,   // 1 = Write to Register File
    output reg  [1:0] ALUSrcA,    // 00 = rs1, 01 = PC (AUIPC), 10 = Zero (LUI)
    output reg        ALUSrcB,    // 0 = rs2, 1 = Immediate
    output reg        MemWrite,   // 1 = Write to Data Memory
    output reg        MemRead,    // 1 = Read from Data Memory
    output reg        Branch,     // 1 = Branch instruction (condition NOT yet evaluated)
    output reg        Jal,        // 1 = JAL instruction executed
    output reg        Jalr,       // 1 = JALR instruction executed
    output reg  [2:0] ALUop,      // Operation passed to ALU (e.g., 001=ADD, 010=SUB)
    output reg  [2:0] ImmSel,     // ImmGen selector: 000=I, 001=J, 010=B, 011=S, 100=U
    output wire [2:0] funct3      // passed for branch differentation
);

    // Extract opcode and funct fields
    wire [6:0] opcode = instruction[6:0];
    assign     funct3 = instruction[14:12];
    wire [6:0] funct7 = instruction[31:25];

    always @(*) begin
        RegWrite = 1'b0;
        ALUSrcA  = 2'b00;
        ALUSrcB  = 1'b0;
        MemWrite = 1'b0;
        MemRead  = 1'b0;
        Branch   = 1'b0;
        Jal      = 1'b0;
        Jalr     = 1'b0;
        ALUop    = 3'b000;
        ImmSel   = 3'b000;

        case (opcode)
            // -------------------------------------------------------------
            // 1. R-Type (add, sub, xor, or, and, sll, srl, sra, slt, sltu)
            // -------------------------------------------------------------
            7'b0110011: begin
                RegWrite = 1'b1;
                ALUSrcA  = 2'b00; // rs1
                ALUSrcB  = 1'b0;  // rs2

                case (funct3)
                    3'b000: ALUop = (funct7[5]) ? 3'b010 : 3'b001; // SUB if funct7[5]=1, else ADD
                    3'b001: ALUop = 3'b101; // SLL
                    3'b010: ALUop = 3'b110; // SLT
                    3'b011: ALUop = 3'b111; // SLTU
                    3'b100: ALUop = 3'b100; // XOR
                    3'b101: ALUop = (funct7[5]) ? 3'b000 : 3'b011; // SRA if funct7[5]=1, else SRL
                    3'b110: ALUop = 3'b011; // OR
                    3'b111: ALUop = 3'b010; // AND
                    default: ALUop = 3'b001;
                endcase
            end

            // -------------------------------------------------------------
            // 2. I-Type Arithmetic (addi, xori, ori, andi, slli, srli, srai)
            // -------------------------------------------------------------
            7'b0010011: begin
                RegWrite = 1'b1;
                ALUSrcA  = 2'b00; // rs1
                ALUSrcB  = 1'b1;  // Immediate
                ImmSel   = 3'b000; // I-Type format

                case (funct3)
                    3'b000: ALUop = 3'b001; // ADDI
                    3'b001: ALUop = 3'b101; // SLLI
                    3'b010: ALUop = 3'b110; // SLTI
                    3'b011: ALUop = 3'b111; // SLTIU
                    3'b100: ALUop = 3'b100; // XORI
                    3'b101: ALUop = (funct7[5]) ? 3'b000 : 3'b011; // SRAI if funct7[5]=1, else SRLI
                    3'b110: ALUop = 3'b011; // ORI
                    3'b111: ALUop = 3'b010; // ANDI
                    default: ALUop = 3'b001;
                endcase
            end

            // -------------------------------------------------------------
            // 3. Loads (lb, lh, lw, lbu, lhu)
            // -------------------------------------------------------------
            7'b0000011: begin
                RegWrite = 1'b1;
                ALUSrcA  = 2'b00; // rs1
                ALUSrcB  = 1'b1;  // Immediate (offset)
                MemRead  = 1'b1;
                ImmSel   = 3'b000; // I-Type format
                ALUop    = 3'b001; // Address calculation: rs1 + imm
            end

            // -------------------------------------------------------------
            // 4. Stores (sb, sh, sw)
            // -------------------------------------------------------------
            7'b0100011: begin
                RegWrite = 1'b0;
                ALUSrcA  = 2'b00; // rs1
                ALUSrcB  = 1'b1;  // Immediate (offset)
                MemWrite = 1'b1;
                ImmSel   = 3'b011; // S-Type format
                ALUop    = 3'b001; // Address calculation: rs1 + imm
            end

            // -------------------------------------------------------------
            // 5. Branches (beq, bne, blt, bge, bltu, bgeu)
            // -------------------------------------------------------------
            7'b1100011: begin
                RegWrite = 1'b0;
                ALUSrcA  = 2'b00; // rs1
                ALUSrcB  = 1'b0;  // rs2
                Branch   = 1'b1;  // Flag as branch instruction;
                ImmSel   = 3'b010; // B-Type format
            end

            // -------------------------------------------------------------
            // 6. JAL (Jump and Link)
            // -------------------------------------------------------------
            7'b1101111: begin
                RegWrite = 1'b1;
                Jal      = 1'b1;
                ImmSel   = 3'b001; // J-Type format
            end

            // -------------------------------------------------------------
            // 7. JALR (Jump and Link Register)
            // -------------------------------------------------------------
            7'b1100111: begin
                RegWrite = 1'b1;
                ALUSrcA  = 2'b00; // rs1
                ALUSrcB  = 1'b1;  // Immediate
                Jalr     = 1'b1;
                ImmSel   = 3'b000; // I-Type format
                ALUop    = 3'b001; // Calculate target address: rs1 + imm
            end

            // -------------------------------------------------------------
            // 8. LUI (Load Upper Immediate)
            // -------------------------------------------------------------
            7'b0110111: begin
                RegWrite = 1'b1;
                ALUSrcA  = 2'b10; // Constant 32'b0
                ALUSrcB  = 1'b1;  // imm_u
                ImmSel   = 3'b100; // U-Type format
                ALUop    = 3'b001; // ADD (0 + imm_u)
            end

            // -------------------------------------------------------------
            // 9. AUIPC (Add Upper Immediate to PC)
            // -------------------------------------------------------------
            7'b0010111: begin
                RegWrite = 1'b1;
                ALUSrcA  = 2'b01; // PC
                ALUSrcB  = 1'b1;  // imm_u
                ImmSel   = 3'b100; // U-Type format
                ALUop    = 3'b001; // ADD (PC + imm_u)
            end

            default: begin
                // All signals maintain safe initial values
            end
        endcase
    end

endmodule