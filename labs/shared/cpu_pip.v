module cpu_pip(
    input clk, reset
);

// -----------------------------------------------------------------------
// IF
// -----------------------------------------------------------------------
reg [31:0] PC;
wire [31:0] nextPC;
wire [31:0] PC_4;
wire [31:0] instruction;

wire pc_enable, if_id_enable, if_id_flush;

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

always @(posedge clk) begin
    if (reset) PC <= 0;
    else if (pc_enable) PC <= nextPC;
end

// IF/ID Pipeline Register
reg [31:0] if_id_PC, if_id_instruction, if_id_PC_4;

always @(posedge clk) begin
    if (reset || if_id_flush) begin
        if_id_PC          <= 32'b0;
        if_id_instruction <= 32'b0; // opcode 0 -> default case in ControlUnit -> NOP
        if_id_PC_4        <= 32'b0;
    end else if (if_id_enable) begin
        if_id_PC          <= PC;
        if_id_instruction <= instruction;
        if_id_PC_4        <= PC_4;
    end
end

// -----------------------------------------------------------------------
// ID
// -----------------------------------------------------------------------
wire RegWrite, MemRead, MemWrite, ALUSrcB, bne, beq, PCSrc, jal_sel;
wire [1:0] ALUSrcA;
wire [2:0] ALUOp;
wire [2:0] ImmSel;
wire [31:0] immOut;
wire [31:0] read_data1, read_data2;

wire [4:0] rs1_id = if_id_instruction[19:15];
wire [4:0] rs2_id = if_id_instruction[24:20];
wire [4:0] rd_id  = if_id_instruction[11:7];

ControlUnit ctrlunit(
    .instruction(if_id_instruction),
    .bne(bne),
    .beq(beq),
    .RegWrite(RegWrite),
    .MemWrite(MemWrite),
    .MemRead(MemRead),
    .ALUOp(ALUOp),
    .ImmSel(ImmSel),
    .ALUSrcA(ALUSrcA),
    .ALUSrcB(ALUSrcB),
    .PCSrc(PCSrc),
    .jal_sel(jal_sel)
);

immGen immgen(
    .instruction(if_id_instruction),
    .immSel(ImmSel),
    .immOut(immOut)
);

wire [31:0] writeBack;
reg_file regfie(
    .clk(clk),
    .reset(reset),
    .we(mem_wb_RegWrite),
    .w_addr(mem_wb_rd),
    .data_in(writeBack),
    .read_1(rs1_id),
    .read_2(rs2_id),
    .rdata1(read_data1),
    .rdata2(read_data2)
);

// ---- Branch-operand forwarding into ID (branches resolve here via branch_comp) ----
wire [31:0] read_data1_fwd, read_data2_fwd;

assign read_data1_fwd =
    (ex_mem_RegWrite && (ex_mem_rd != 5'd0) && (ex_mem_rd == rs1_id)) ? ex_mem_ALUout :
    (mem_wb_RegWrite && (mem_wb_rd != 5'd0) && (mem_wb_rd == rs1_id)) ? writeBack     :
                                                                         read_data1;

assign read_data2_fwd =
    (ex_mem_RegWrite && (ex_mem_rd != 5'd0) && (ex_mem_rd == rs2_id)) ? ex_mem_ALUout :
    (mem_wb_RegWrite && (mem_wb_rd != 5'd0) && (mem_wb_rd == rs2_id)) ? writeBack     :
                                                                         read_data2;

branch_comp bc(
    .rs1(read_data1_fwd),
    .rs2(read_data2_fwd),
    .bne(bne),
    .beq(beq)
);

// ---- Load-use hazard ----
wire load_use_stall =
    id_ex_MemRead && (id_ex_rd != 5'd0) &&
    ( (id_ex_rd == rs1_id) || (id_ex_rd == rs2_id) );

assign pc_enable    = !load_use_stall;
assign if_id_enable = !load_use_stall;
assign if_id_flush  = PCSrc;
wire   id_ex_flush   = load_use_stall || PCSrc;

// nextPC: branch/JAL target computed off the ID-stage instruction directly,
// since PCSrc/jal_sel resolve combinationally in ID here.
wire [31:0] branch_target = if_id_PC + immOut;

genvar l;
generate for (l = 0; l < 32; l++) begin: mux_loop
    mux2to1 m1(
        .a(PC_4[l]),
        .b(branch_target[l]),
        .sel(PCSrc),
        .out(nextPC[l])
    );
end
endgenerate

// -----------------------------------------------------------------------
// ID/EX Pipeline Register
// -----------------------------------------------------------------------
reg [31:0] id_ex_PC, id_ex_PC_4, id_ex_rs1_val, id_ex_rs2_val, id_ex_imm;
reg [4:0]  id_ex_rd, id_ex_rs1, id_ex_rs2;
reg [2:0]  id_ex_ALUOp;
reg [1:0]  id_ex_ALUSrcA;
reg id_ex_ALUSrcB, id_ex_MemRead, id_ex_MemWrite, id_ex_RegWrite, id_ex_jal_sel;

always @(posedge clk) begin
    if (reset || id_ex_flush) begin
        id_ex_PC       <= 0; id_ex_PC_4     <= 0;
        id_ex_rs1_val  <= 0; id_ex_rs2_val  <= 0;
        id_ex_imm      <= 0; id_ex_rd       <= 0;
        id_ex_rs1      <= 0; id_ex_rs2      <= 0;
        id_ex_ALUOp    <= 0; id_ex_ALUSrcA  <= 0; id_ex_ALUSrcB <= 0;
        id_ex_MemRead  <= 0; id_ex_MemWrite <= 0;
        id_ex_RegWrite <= 0; id_ex_jal_sel  <= 0;
    end else begin
        id_ex_PC       <= if_id_PC;
        id_ex_PC_4     <= if_id_PC_4;
        id_ex_rs1_val  <= read_data1_fwd;
        id_ex_rs2_val  <= read_data2_fwd;
        id_ex_imm      <= immOut;
        id_ex_rd       <= rd_id;
        id_ex_rs1      <= rs1_id;
        id_ex_rs2      <= rs2_id;

        id_ex_ALUOp    <= ALUOp;
        id_ex_ALUSrcA  <= ALUSrcA;
        id_ex_ALUSrcB  <= ALUSrcB;
        id_ex_MemRead  <= MemRead;
        id_ex_MemWrite <= MemWrite;
        id_ex_RegWrite <= RegWrite;
        id_ex_jal_sel  <= jal_sel;
    end
end

// -----------------------------------------------------------------------
// EX
// -----------------------------------------------------------------------
wire [31:0] rs1_fwd =
    (mem_wb_RegWrite && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs1)) ? writeBack : id_ex_rs1_val;
wire [31:0] rs2_fwd =
    (mem_wb_RegWrite && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs2)) ? writeBack : id_ex_rs2_val;

// ALUSrcA: 00 = rs1(fwd), 01 = PC, 10 = zero
wire [31:0] ALUin_A =
    (id_ex_ALUSrcA == 2'b01) ? id_ex_PC :
    (id_ex_ALUSrcA == 2'b10) ? 32'b0    :
                               rs1_fwd;

// ALUSrcB: 0 = rs2(fwd), 1 = immediate
wire [31:0] ALUin_B = id_ex_ALUSrcB ? id_ex_imm : rs2_fwd;

wire [31:0] ALUout;
rv32ialu ALU(
    .A(ALUin_A),
    .B(ALUin_B),
    .alu_ctrl(id_ex_ALUOp),
    .Y(ALUout),
    .zero()
);

// -----------------------------------------------------------------------
// EX/MEM Pipeline Register
// -----------------------------------------------------------------------
reg [31:0] ex_mem_ALUout, ex_mem_rs2_val, ex_mem_PC_4;
reg [4:0]  ex_mem_rd;
reg ex_mem_MemRead, ex_mem_MemWrite, ex_mem_RegWrite, ex_mem_jal_sel;

always @(posedge clk) begin
    if (reset) begin
        ex_mem_ALUout   <= 0; ex_mem_rs2_val  <= 0;
        ex_mem_PC_4     <= 0; ex_mem_rd       <= 0;
        ex_mem_MemRead  <= 0; ex_mem_MemWrite <= 0;
        ex_mem_RegWrite <= 0; ex_mem_jal_sel  <= 0;
    end else begin
        ex_mem_ALUout   <= ALUout;
        ex_mem_rs2_val  <= rs2_fwd;
        ex_mem_PC_4     <= id_ex_PC_4;
        ex_mem_rd       <= id_ex_rd;

        ex_mem_MemRead  <= id_ex_MemRead;
        ex_mem_MemWrite <= id_ex_MemWrite;
        ex_mem_RegWrite <= id_ex_RegWrite;
        ex_mem_jal_sel  <= id_ex_jal_sel;
    end
end

// -----------------------------------------------------------------------
// MEM
// -----------------------------------------------------------------------
wire [31:0] readDataMem;

BankedMEM DMEM(
    .writeEn(ex_mem_MemWrite),
    .clk(clk),
    .address(ex_mem_ALUout),
    .writeData(ex_mem_rs2_val),
    .readData(readDataMem)
);

reg [31:0] mem_wb_MemData, mem_wb_ALUout, mem_wb_PC_4;
reg [4:0]  mem_wb_rd;
reg mem_wb_RegWrite, mem_wb_MemRead, mem_wb_jal_sel;

always @(posedge clk) begin
    if (reset) begin
        mem_wb_MemData  <= 0; mem_wb_ALUout  <= 0;
        mem_wb_PC_4     <= 0; mem_wb_rd      <= 0;
        mem_wb_RegWrite <= 0; mem_wb_MemRead <= 0;
        mem_wb_jal_sel  <= 0;
    end else begin
        mem_wb_MemData  <= readDataMem;
        mem_wb_ALUout   <= ex_mem_ALUout;
        mem_wb_PC_4     <= ex_mem_PC_4;
        mem_wb_rd       <= ex_mem_rd;

        mem_wb_RegWrite <= ex_mem_RegWrite;
        mem_wb_MemRead  <= ex_mem_MemRead;
        mem_wb_jal_sel  <= ex_mem_jal_sel;
    end
end

// -----------------------------------------------------------------------
// WB
// -----------------------------------------------------------------------
wire [31:0] writeBack_1;

genvar k;
generate for(k = 0; k < 32; k++) begin : Write_back_loop1
    mux2to1 MUX_MEM(
        .a(mem_wb_ALUout[k]),
        .b(mem_wb_MemData[k]),
        .sel(mem_wb_MemRead),
        .out(writeBack_1[k])
    );
end
endgenerate

genvar z;
generate for(z = 0; z < 32; z++) begin : Write_back_loop
    mux2to1 MUX_WB(
        .a(writeBack_1[z]),
        .b(mem_wb_PC_4[z]),
        .sel(mem_wb_jal_sel),
        .out(writeBack[z])
    );
end
endgenerate

endmodule