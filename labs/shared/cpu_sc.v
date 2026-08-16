module cpu_sc(
    input clk, reset
);
wire [31:0] instruction;
reg  [31:0] PC;
wire [31:0] nextPC;
wire [31:0] PC_4;
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
// -----------------------------------------------------------------------------
// 2. Control & Decode Stage
// -----------------------------------------------------------------------------
wire RegWrite, MemRead, MemWrite, ALUSrc;
wire [1:0] ALUSrcA; // 00: rs1, 01: PC (AUIPC), 10: 0 (LUI)
wire [2:0] ALUOp;
wire [2:0] ImmSel;
wire [2:0] funct3;  // passed through from ControlUnit for branch_comp

wire Branch, Jal, Jalr;

ControlUnit ctrlunit(
    .instruction(instruction),
    .RegWrite(RegWrite),
    .ALUSrcA(ALUSrcA),
    .ALUSrcB(ALUSrc),    // ControlUnit calls this ALUSrcB; CPU_sc calls it ALUSrc - same wire
    .MemWrite(MemWrite),
    .MemRead(MemRead),
    .Branch(Branch),
    .Jal(Jal),
    .Jalr(Jalr),
    .ALUop(ALUOp),       // ControlUnit calls this ALUop (lowercase op); CPU_sc calls it ALUOp
    .ImmSel(ImmSel),
    .funct3(funct3)
);

wire branch_taken;
branch_comp bc(
    .rs1(read_data1),
    .rs2(read_data2),
    .funct3(funct3),
    .branch_taken(branch_taken)
);

// ControlUnit doesn't know about branch outcome or PC-mux
//     conventions, so derive CPU_sc's PCSrc/jal_sel/jalr_sel here.

// PCSrc: take the branch/jump path whenever it's JAL, JALR, or a branch
// instruction whose condition actually evaluates true.
wire PCSrc  = (Branch & branch_taken) | Jal | Jalr;
wire jal_sel  = Jal | Jalr;   // both write PC+4 back to rd
wire jalr_sel = Jalr;         // only JALR targets rs1+imm instead of PC+imm
wire [31:0] immOut;
immGen IMM_gen(
    .instruction(instruction),
    .immSel(ImmSel),
    .immOut(immOut)
);
wire [31:0] writeBack, read_data1, read_data2;
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
// ALU Input B MUX (rs2 vs Immediate)
wire [31:0] ALUin_B;
genvar j;
generate for(j = 0; j < 32; j++) begin : ALU_inLoop1
    mux2to1 MUX_IMM(
        .a(read_data2[j]),
        .b(immOut[j]),
        .sel(ALUSrc),
        .out(ALUin_B[j])
    );
end
endgenerate
// ALU Input A Selection (rs1 vs PC vs 0)
wire [31:0] ALUin_A;
assign ALUin_A = (ALUSrcA == 2'b01) ? PC :
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
// 4. PC Update Logic (Branch/Jump Target Calculation)
// -----------------------------------------------------------------------------
wire [31:0] target_pc = PC + immOut; // PC-relative target: branches, JAL, AUIPC-style
wire [31:0] jump_target = jalr_sel ? ALUout : target_pc;

genvar l;
generate 
    for (l = 0; l < 32; l++) begin: pc_mux_loop
    mux2to1 m1(
        .a(PC_4[l]),
        .b(jump_target[l]), // Selects Target PC (branch/JAL) or ALU result (JALR)
        .sel(PCSrc),
        .out(nextPC[l])
    );
end
endgenerate
always @(posedge clk) begin
    if(reset) begin 
        PC <= 0;
    end
    else begin
        PC <= nextPC;
    end
end
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
// MUX 1: ALU Result vs Memory Read Data (for LW)
wire [31:0] writeBack_1;
generate 
    genvar k;
    for(k = 0; k < 32; k++) begin : Write_back_loop1
    mux2to1 MUX_MEM(
        .a(ALUout[k]),
        .b(readDataMem[k]),
        .sel(MemRead),
        .out(writeBack_1[k])
    );
end
endgenerate
// MUX 2: Previous Result vs PC+4 (for JAL/JALR Return Address)
genvar z;
generate for(z = 0; z < 32; z++) begin : Write_back_loop
    mux2to1 MUX_WB(
        .a(writeBack_1[z]),
        .b(PC_4[z]),
        .sel(jal_sel),
        .y(writeBack[z])
    );
end
endgenerate
endmodule