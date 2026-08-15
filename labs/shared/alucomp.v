`timescale 1ns/1ps

module alucomp(input [31:0] a, input [31:0] b, output [31:0] out);
    wire [31:0] result;
    wire alessthanb;
    wire pos_ov, neg_ov;
    aluaddsub aluaddsub_inst(a, b, 1'b1, result, pos_ov, neg_ov);

    assign alessthanb = (result[31] & ~pos_ov) | neg_ov;

    assign #1 out = alessthanb ? 32'b1:32'b0;
    
endmodule