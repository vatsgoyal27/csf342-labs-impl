module cpu_sc(
    input clk,
    input reset
);

// -----------------------------------------------------------------------------
// Internal Wires & Registers
// -----------------------------------------------------------------------------
reg  [31:0] PC;
wire [31:0] nextPC;
wire [31:0] PC_4;
wire [31:0] instruction;

wire [31:0] read_data1, read_data2;
wire [31:0] immOut;
wire [31:0] writeBack;

wire RegWrite, MemWrite, MemRead, ALUSrc;
wire [1:0] ALUSrcA; // 00: rs1, 01: PC (AUIPC), 10: 0 (LUI)
wire [2:0] ALUOp;
wire [2:0] ImmSel;
wire PCSrc, jal_sel;
wire beq, bne;

// -----------------------------------------------------------------------------
// 1. Fetch Stage
// -----------------------------------------------------------------------------
BankedMEM IMEM(
    .writeEn(1'b0),
    .clk(clk),
    .address(PC),
    .writeData(32'b0),
    .readData(instruction)
);

PCInc pcinc(
    .clk(clk),
    .oldPC(PC),
    .newPC(PC_4)
);

always @(posedge clk or posedge reset) begin
    if (reset) begin 
        PC <= 32'b0;
    end else begin
        PC <= nextPC;
    end
end

// -----------------------------------------------------------------------------
// 2. Control & Decode Stage
// -----------------------------------------------------------------------------
branch_comp bc(
    .rs1(read_data1),
    .rs2(read_data2),
    .beq(beq),
    .bne(bne)
);

ControlUnit ctrlunit(
    .instruction(instruction),
    .bne(bne),
    .beq(beq),
    .RegWrite(RegWrite),
    .MemWrite(MemWrite),
    .MemRead(MemRead),
    .ALUOp(ALUOp),
    .ImmSel(ImmSel),
    .ALUSrcA(ALUSrcA),
    .ALUSrcB(ALUSrc),
    .PCSrc(PCSrc),
    .jal_sel(jal_sel)
);

immGen IMM_gen(
    .instruction(instruction),
    .immSel(ImmSel),
    .immOut(immOut)
);

reg_file regfie(
    .clk(clk),
    .reset(reset),
    .we(RegWrite),
    .w_addr(instruction[11:7]),
    .data_in(writeBack),
    .read_1(instruction[19:15]),
    .read_2(instruction[24:20]),
    .rdata1(read_data1),
    .rdata2(read_data2)
);

// -----------------------------------------------------------------------------
// 3. Execution Stage
// -----------------------------------------------------------------------------
// MUX for ALU Operand B (Register rs2 vs Immediate)
wire [31:0] ALUin_B = ALUSrc ? immOut : read_data2;

// MUX for ALU Operand A (Register rs1 vs PC vs Zero)
wire [31:0] ALUin_A = (ALUSrcA == 2'b01) ? PC :
                      (ALUSrcA == 2'b10) ? 32'b0 :
                                           read_data1;

wire [31:0] ALUout;

rv32ialu ALU(
    .A(ALUin_A),
    .B(ALUin_B),
    .alu_ctrl(ALUOp),
    .Y(ALUout),
    .zero()
);

// -----------------------------------------------------------------------------
// 4. PC Target Calculation & Next PC Selection
// -----------------------------------------------------------------------------
wire [31:0] target_pc = PC + immOut;

// Next PC selection: Jump target if JAL or taken Branch, else sequential PC + 4
wire pc_sel = PCSrc || jal_sel;
assign nextPC = pc_sel ? target_pc : PC_4;

// -----------------------------------------------------------------------------
// 5. Memory Access & Write-Back Stage
// -----------------------------------------------------------------------------
wire [31:0] readDataMem;

BankedMEM DMEM(
    .writeEn(MemWrite),
    .clk(clk),
    .address(ALUout),
    .writeData(read_data2),
    .readData(readDataMem)
);

// MUX 1: Memory Read Data vs ALU Result
wire [31:0] writeBack_1 = MemRead ? readDataMem : ALUout;

// MUX 2: Final Write-back Data (PC + 4 for JAL return address, else writeBack_1)
assign writeBack = jal_sel ? PC_4 : writeBack_1;

endmodule