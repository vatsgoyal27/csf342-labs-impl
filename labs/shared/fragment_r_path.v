`timescale 1ns/1ps

module fragment_r_path(input [31:0] inst, input clk, input reset, output [31:0] alu_result);
    wire [6:0] funct7;
    wire [2:0] funct3;
    wire [4:0] rs1, rs2, rd;
    wire [6:0] opcode;
    assign funct7 = inst[31:25] ;
    assign rs2 = inst[24:20];
    assign rs1 = inst[19:15];
    assign funct3 = inst[14:12];
    assign rd = inst[11:7];
    assign opcode = inst[6:0];

    wire [31:0] rdata1;
    wire [31:0] rdata2;
    reg_file reg_file_inst(clk, reset, 1'b1, rd, alu_result, rs1, rs2, rdata1, rdata2); //alu_result is for writeback

    wire [2:0] alu_ctrlw;
    alu_ctrl alu_ctrl_inst(funct3, funct7, alu_ctrlw);

    rv32ialu rv32ialu_inst(rdata1, rdata2, alu_ctrlw, alu_result);
endmodule