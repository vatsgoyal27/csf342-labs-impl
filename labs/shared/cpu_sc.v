module CPU_sc(
    input clk,reset
);

wire [31:0] instruction;
reg [31:0] PC;
wire [31:0] nextPC;
wire [31:0] PC_4;

// fetch
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

wire RegWrite;
wire MemRead;
wire MemWrite;
wire [2:0] ALUOp;
wire [2:0] ImmSel;
wire [1:0] ALUSrcA;
wire ALUSrcB;
wire bne,beq;
wire PCSrc; 
wire jal_sel;
// decode

ControlUnit ctrlunit(
    .instruction(instruction),
    .bne(bne),
    .beq(beq),
    .RegWrite(RegWrite),
    .MemRead(MemRead),
    .MemWrite(MemWrite),
    .ALUOp(ALUOp),
    .ALUSrcA(ALUSrcA),
    .ALUSrcB(ALUSrcB),
    .ImmSel(ImmSel),
    .PCSrc(PCSrc),
    .jal_sel(jal_sel)
);

wire [31:0] immOut;
immGen immgen(
    .instruction(instruction),
    .immSel(ImmSel),
    .immOut(immOut)
);


wire [31:0] writeBack,read_data1,read_data2;
reg_file regfie(
    .clk(clk),
    .reset(reset),
    .we(RegWrite),
    .w_addr(instruction[11:7]),
    .read_1(instruction[19:15]),
    .read_2(instruction[24:20]),
    .data_in(writeBack),
    .rdata1(read_data1),
    .rdata2(read_data2)
);

branch_comp bc(
    .rs1(read_data1),
    .rs2(read_data2),
    .bne(bne),
    .beq(beq)
);

// execute
wire [31:0] ALUin,ALUout;
genvar j;
generate for(j = 0;j<32;j++) begin : ALU_inLoop1
    mux2to1 MUX_IMM(
        .a(read_data2[j]),
        .b(immOut[j]),
        .sel(ALUSrcB),
        .out(ALUin[j])
    );
end
endgenerate

wire [31:0] ALUin_rs1_pc;
genvar t;
generate for(t = 0;t<32;t++) begin : ALU_inLoop
    mux2to1 MUX_PC(
        .a(read_data1[t]),
        .b(PC[t]),
        .sel(ALUSrcA[0]),
        .out(ALUin_rs1_pc[t])
    );
end
endgenerate

wire [31:0] ALUin_1;
genvar m;
generate for(m = 0;m<32;m++) begin : ALU_inLoop2
    mux2to1 MUX_ZERO(
        .a(ALUin_rs1_pc[m]),
        .b(1'b0),
        .sel(ALUSrcA[1]),
        .out(ALUin_1[m])
    );
end
endgenerate

rv32ialu ALU(
    .A(ALUin_1),
    .B(ALUin),
    .alu_ctrl(ALUOp),
    .Y(ALUout)
);

genvar l;
generate 
    for (l = 0; l<32;l++) begin: mux_loop
    mux2to1 m1(.a(PC_4[l]),.b(ALUout[l]),.sel(PCSrc),.out(nextPC[l]));
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

// memory access
wire [31:0] readDataMem;
BankedMEM DMEM(
    .writeEn(MemWrite),
    .clk(clk),
    .address(ALUout),
    .writeData(read_data2),
    .readData(readDataMem)
);

//write back
wire [31:0] writeBack_1;
genvar k;
generate 
    for(k = 0;k<32;k++) begin : Write_back_loop1
    mux2to1 MUX_MEM(
        .b(readDataMem[k]),
        .a(ALUout[k]),
        .sel(MemRead),
        .out(writeBack_1[k])
    );
end
endgenerate

genvar z;
generate for(z=0;z<32;z++) begin : Write_back_loop
    mux2to1 MUX_WB(
        .b(PC_4[z]),
        .a(writeBack_1[z]),
        .sel(jal_sel),
        .out(writeBack[z])
    );
end
endgenerate

endmodule