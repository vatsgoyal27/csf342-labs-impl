`timescale 1ns/1ps

module alu_ctrl(input [2:0] funct3, input [6:0] funct7, output alu_ctrl[2:0]);
    assign #1 alu_ctrl[1] = funct3[1]; //buffer gate assumed
    assign #2 alu_ctrl[2] = (funct3[1]&funct3[0]) | (funct3[1]&funct3[2]); //2x1muxes in parallel -> or gate
    assign #3 alu_ctrl[0] = (~funct7_5 & ~funct3[2] & ~funct3[1] & ~funct3[0]) | (~funct3[2] &  funct3[1] &  funct3[0]) | ( funct3[2] &  funct3[1] & ~funct3[0]); // nor A and B, mux with D as select, get a'b'd', also buffer b and d, then xor them. send inputs into a mux with c as select to get a'b'c'd' + bxord.c

endmodule