module cpu_pip(
    input clk, reset
);

//========================================================
// FORWARD DECLARATIONS
//========================================================
reg [31:0] ex_mem_ALUout, ex_mem_rs2_val, ex_mem_PC_4;
reg [4:0]  ex_mem_rd;
reg        ex_mem_RegWrite, ex_mem_MemRead, ex_mem_MemWrite, ex_mem_jal_sel;

reg [31:0] mem_wb_MemData, mem_wb_ALUout, mem_wb_PC_4;
reg [4:0]  mem_wb_rd;
reg        mem_wb_RegWrite, mem_wb_MemRead, mem_wb_jal_sel;

wire [31:0] writeBack;
wire [31:0] readDataMem;

//========================================================
// IF STAGE
//========================================================
reg  [31:0] PC;
wire [31:0] nextPC;
wire [31:0] PC_4;
wire [31:0] instruction;
wire        stall; // Master stall signal
wire        flush; // Flushes IF/ID and ID/EX on valid taken branch/jump

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

// PC Register with Stall logic
always @(posedge clk) begin
    if (reset) begin 
        PC <= 32'b0;
    end else if (!stall) begin
        PC <= nextPC;
    end
end

//========================================================
// IF/ID Pipeline Register
//========================================================
reg [31:0] if_id_PC, if_id_instruction, if_id_PC_4;

always @(posedge clk) begin
    if (reset || flush) begin
        if_id_PC          <= 32'b0;
        if_id_instruction <= 32'h00000013; // Safe NOP (addi x0, x0, 0)
        if_id_PC_4        <= 32'b0;
    end else if (!stall) begin
        if_id_PC          <= PC;
        if_id_instruction <= instruction;
        if_id_PC_4        <= PC_4;
    end
end

//========================================================
// ID STAGE
//========================================================
wire RegWrite, MemRead, MemWrite, ALUSrcB, bne, beq, PCSrc, jal_sel;
wire [2:0] ALUOp, ImmSel;
wire [1:0] ALUSrcA;
wire [31:0] immOut, read_data1, read_data2;

wire [4:0] rs1_addr = if_id_instruction[19:15];
wire [4:0] rs2_addr = if_id_instruction[24:20];
wire [4:0] rd_addr  = if_id_instruction[11:7];

ControlUnit ctrlunit(
    .instruction(if_id_instruction),
    .bne(bne),
    .beq(beq),
    .RegWrite(RegWrite),
    .MemRead(MemRead),
    .MemWrite(MemWrite),
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

reg_file regfie(
    .clk(clk),
    .reset(reset),
    .we(mem_wb_RegWrite),
    .w_addr(mem_wb_rd),
    .read1(rs1_addr),
    .read2(rs2_addr),
    .data_in(writeBack),
    .rdata1(read_data1),
    .rdata2(read_data2)
);

// --- Branch Forwarding ---
// Forward ALU results directly from MEM or WB stages for branch comparison.
// We DO NOT forward Memory Loads here. If it's a load, the stall logic guarantees a delay.
wire [31:0] bc_rs1 = (ex_mem_RegWrite && !ex_mem_MemRead && (ex_mem_rd != 0) && (ex_mem_rd == rs1_addr)) ? ex_mem_ALUout :
                     (mem_wb_RegWrite && (mem_wb_rd != 0) && (mem_wb_rd == rs1_addr)) ? writeBack :
                                                                                        read_data1;

wire [31:0] bc_rs2 = (ex_mem_RegWrite && !ex_mem_MemRead && (ex_mem_rd != 0) && (ex_mem_rd == rs2_addr)) ? ex_mem_ALUout :
                     (mem_wb_RegWrite && (mem_wb_rd != 0) && (mem_wb_rd == rs2_addr)) ? writeBack :
                                                                                        read_data2;

branch_comp bc(
    .rs1(bc_rs1),
    .rs2(bc_rs2),
    .bne(bne),
    .beq(beq)
);

//========================================================
// HAZARD DETECTION UNIT (Stall Logic)
//========================================================
reg id_ex_MemRead, id_ex_RegWrite;
reg [4:0] id_ex_rd;
wire is_branch = (if_id_instruction[6:0] == 7'b1100011);

// 1. Standard Load-Use Hazard (Load in EX, dependent instruction in ID)
wire stall_load_use_alu = id_ex_MemRead && (id_ex_rd != 5'd0) && 
                          ((id_ex_rd == rs1_addr) || (id_ex_rd == rs2_addr));

// 2. Branch Data Hazard (ALU instruction in EX, dependent Branch in ID)
wire stall_branch_ex = is_branch && id_ex_RegWrite && (id_ex_rd != 5'd0) &&
                       ((id_ex_rd == rs1_addr) || (id_ex_rd == rs2_addr));

// 3. Branch Data Hazard (Load instruction in MEM, dependent Branch in ID)
wire stall_branch_mem = is_branch && ex_mem_MemRead && (ex_mem_rd != 5'd0) &&
                        ((ex_mem_rd == rs1_addr) || (ex_mem_rd == rs2_addr));

assign stall = stall_load_use_alu || stall_branch_ex || stall_branch_mem;

// Validate PCSrc ONLY if we are not currently stalling to prevent accidental flushes
wire actual_PCSrc = PCSrc && !stall;
assign flush = actual_PCSrc;

// PC Redirect Mux (JAL and Branches only, strict PC + imm)
assign nextPC = actual_PCSrc ? (if_id_PC + immOut) : PC_4;

//========================================================
// ID/EX Pipeline Register
//========================================================
reg [31:0] id_ex_PC, id_ex_PC_4, id_ex_rs1_val, id_ex_rs2_val, id_ex_imm;
reg [4:0]  id_ex_rs1_addr, id_ex_rs2_addr;
reg [2:0]  id_ex_ALUOp;
reg [1:0]  id_ex_ALUSrcA;
reg        id_ex_ALUSrcB, id_ex_MemWrite, id_ex_jal_sel;

always @(posedge clk) begin
    if (reset || flush || stall) begin
        id_ex_PC       <= 0; id_ex_PC_4       <= 0;
        id_ex_rs1_val  <= 0; id_ex_rs2_val  <= 0; id_ex_imm <= 0;
        id_ex_rd       <= 0; id_ex_rs1_addr <= 0; id_ex_rs2_addr <= 0;
        id_ex_ALUOp    <= 0; id_ex_ALUSrcA  <= 0; id_ex_ALUSrcB <= 0;
        id_ex_MemRead  <= 0; id_ex_MemWrite <= 0; id_ex_RegWrite <= 0;
        id_ex_jal_sel  <= 0;
    end else begin
        id_ex_PC       <= if_id_PC;
        id_ex_PC_4     <= if_id_PC_4;
        id_ex_rs1_val  <= read_data1;
        id_ex_rs2_val  <= read_data2;
        id_ex_imm      <= immOut;
        id_ex_rd       <= rd_addr;
        id_ex_rs1_addr <= rs1_addr;
        id_ex_rs2_addr <= rs2_addr;
        id_ex_ALUOp    <= ALUOp;
        id_ex_ALUSrcA  <= ALUSrcA;
        id_ex_ALUSrcB  <= ALUSrcB;
        id_ex_MemRead  <= MemRead;
        id_ex_MemWrite <= MemWrite;
        id_ex_RegWrite <= RegWrite;
        id_ex_jal_sel  <= jal_sel;
    end
end

//========================================================
// EX STAGE (+ Forwarding Unit)
//========================================================
wire fwdA_from_EXMEM = ex_mem_RegWrite && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs1_addr);
wire fwdA_from_MEMWB = mem_wb_RegWrite && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs1_addr) && !fwdA_from_EXMEM;

wire fwdB_from_EXMEM = ex_mem_RegWrite && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs2_addr);
wire fwdB_from_MEMWB = mem_wb_RegWrite && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs2_addr) && !fwdB_from_EXMEM;

// Normal Forwarding (Load dependencies are handled by the stall logic letting WB catch up)
wire [31:0] rs1_fwd = fwdA_from_EXMEM ? ex_mem_ALUout :
                      fwdA_from_MEMWB ? writeBack :
                                        id_ex_rs1_val;

wire [31:0] rs2_fwd = fwdB_from_EXMEM ? ex_mem_ALUout :
                      fwdB_from_MEMWB ? writeBack :
                                        id_ex_rs2_val;

// ALUSrcA Mux (rs1 vs PC vs Zero)
wire [31:0] ALUin_A = (id_ex_ALUSrcA == 2'b10) ? 32'b0 :
                      (id_ex_ALUSrcA == 2'b01) ? id_ex_PC :
                                                 rs1_fwd;

// ALUSrcB Mux (rs2 vs Immediate)
wire [31:0] ALUin_B = id_ex_ALUSrcB ? id_ex_imm : rs2_fwd;

wire [31:0] ALUout;

rv32ialu ALU(
    .A(ALUin_A),
    .B(ALUin_B),
    .alu_ctrl(id_ex_ALUOp),
    .Y(ALUout),
    .zero()
);

//========================================================
// EX/MEM Pipeline Register
//========================================================
always @(posedge clk) begin
    if (reset) begin
        ex_mem_ALUout   <= 0; ex_mem_rs2_val  <= 0; ex_mem_PC_4    <= 0;
        ex_mem_rd       <= 0; ex_mem_MemRead  <= 0; ex_mem_MemWrite <= 0;
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

//========================================================
// MEM STAGE
//========================================================
BankedMEM DMEM(
    .writeEn(ex_mem_MemWrite),
    .clk(clk),
    .address(ex_mem_ALUout),
    .writeData(ex_mem_rs2_val),
    .readData(readDataMem)
);

//========================================================
// MEM/WB Pipeline Register
//========================================================
always @(posedge clk) begin
    if (reset) begin
        mem_wb_MemData  <= 0; mem_wb_ALUout   <= 0; mem_wb_PC_4     <= 0;
        mem_wb_rd       <= 0; mem_wb_RegWrite <= 0; mem_wb_MemRead  <= 0;
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

//========================================================
// WB STAGE
//========================================================
wire [31:0] mem_or_alu = mem_wb_MemRead ? mem_wb_MemData : mem_wb_ALUout;
assign writeBack = mem_wb_jal_sel ? mem_wb_PC_4 : mem_or_alu;

endmodule