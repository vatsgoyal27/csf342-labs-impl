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
wire PCSrc, jal_sel;

wire [31:0] read_data1, read_data2;
wire beq, bne;

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
    .ALUSrcB(ALUSrc),   // ControlUnit's ALUSrcB == cpu_sc's ALUSrc
    .PCSrc(PCSrc),
    .jal_sel(jal_sel)
);

wire [31:0] immOut;
immGen IMM_gen(
    .instruction(instruction),
    .immSel(ImmSel),
    .immOut(immOut)
);

wire [31:0] writeBack;
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
// No JALR support currently -> target is always PC-relative (branches & JAL)
wire [31:0] target_pc = PC + immOut;

genvar l;
generate 
    for (l = 0; l < 32; l++) begin: pc_mux_loop
    mux2to1 m1(
        .a(PC_4[l]),
        .b(target_pc[l]), // Selects Target PC (branch/JAL)
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

// MUX 2: Previous Result vs PC+4 (for JAL Return Address)
genvar z;
generate for(z = 0; z < 32; z++) begin : Write_back_loop
    mux2to1 MUX_WB(
        .a(writeBack_1[z]),
        .b(PC_4[z]),
        .sel(jal_sel),
        .out(writeBack[z])   // was `.y(...)` — your mux2to1 port is `.out`, matching every other instantiation above
    );
end
endgenerate

endmodule