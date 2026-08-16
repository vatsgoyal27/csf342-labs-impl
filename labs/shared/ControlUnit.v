module ControlUnit(
    input  [31:0] instruction,
    input bne, beq,

    output reg        RegWrite,
    output reg        MemWrite,
    output reg        MemRead,
    output reg  [2:0] ALUOp,
    output reg  [2:0] ImmSel,   // 000=I, 001=J, 010=B, 011=S, 100=U
    output reg  [1:0] ALUSrcA,  // 00=rs1, 01=PC, 10=Zero
    output reg        ALUSrcB,  // 0=rs2, 1=Immediate
    output reg        PCSrc,
    output reg        jal_sel
);

wire [6:0] opcode = instruction[6:0];
wire [2:0] func3  = instruction[14:12];
wire [6:0] func7  = instruction[31:25];

always @(*) begin
    // Default values to prevent unwanted latches
    RegWrite = 0; MemWrite = 0; MemRead = 0;
    ALUOp = 3'b000; ImmSel = 3'b000;
    ALUSrcA = 2'b00; ALUSrcB = 0;
    PCSrc = 0; jal_sel = 0;

    case(opcode)
        // R-type
        7'b0110011: begin
            RegWrite = 1;
            ALUSrcA  = 2'b00; // rs1
            ALUSrcB  = 0;     // rs2
            case(func3)
                3'b000: ALUOp = (func7[5]) ? 3'b000 : 3'b001; // SUB : ADD
                3'b001: ALUOp = 3'b100; // SLL
                3'b010: ALUOp = 3'b110; // SLT
                3'b101: ALUOp = 3'b101; // SRL
                3'b110: ALUOp = 3'b011; // OR
                3'b111: ALUOp = 3'b010; // AND
            endcase
        end

        // I-type: Load
        7'b0000011: begin
            RegWrite = 1;
            MemRead  = 1;
            ALUSrcA  = 2'b00; // rs1
            ALUSrcB  = 1;
            ImmSel   = 3'b000; // imm_i
            ALUOp    = 3'b001; // ADD
        end

        // I-type: Immediate Arithmetic
        7'b0010011: begin
            RegWrite = 1;
            ALUSrcA  = 2'b00; // rs1
            ALUSrcB  = 1;
            ImmSel   = 3'b000; // imm_i
            case(func3)
                3'b000: ALUOp = 3'b001; // ADDI
                3'b110: ALUOp = 3'b011; // ORI
                3'b111: ALUOp = 3'b010; // ANDI
                default: ALUOp = 3'b001;
            endcase
        end

        // S-type: Store
        7'b0100011: begin
            RegWrite = 0;
            MemWrite = 1;
            ALUSrcA  = 2'b00; // rs1
            ALUSrcB  = 1;
            ImmSel   = 3'b011; // imm_s
            ALUOp    = 3'b001; // ADD
        end

        // B-type: Branch
        7'b1100011: begin
            RegWrite = 0;
            ALUSrcA  = 2'b00; // rs1
            ALUSrcB  = 1;     // imm (kept as in your original; comparator handled outside ALU)
            ImmSel   = 3'b010; // imm_b
            ALUOp    = 3'b001; // ADD
            case(func3)
                3'b000: PCSrc = beq;
                3'b001: PCSrc = bne;
                default: PCSrc = 1'b0;
            endcase
        end

        // J-type: JAL
        7'b1101111: begin
            RegWrite = 1;
            ALUSrcA  = 2'b00;
            ALUSrcB  = 1;
            ImmSel   = 3'b001; // imm_j
            ALUOp    = 3'b001;
            PCSrc    = 1;
            jal_sel  = 1;
        end

        // U-type: LUI
        7'b0110111: begin
            RegWrite = 1;
            ALUSrcA  = 2'b10; // zero
            ALUSrcB  = 1;     // imm_u
            ImmSel   = 3'b100;
            ALUOp    = 3'b001; // ADD -> 0 + imm_u
        end

        // U-type: AUIPC
        7'b0010111: begin
            RegWrite = 1;
            ALUSrcA  = 2'b01; // PC
            ALUSrcB  = 1;     // imm_u
            ImmSel   = 3'b100;
            ALUOp    = 3'b001; // ADD -> PC + imm_u
        end

        default: begin
            RegWrite = 0;
        end
    endcase
end
endmodule