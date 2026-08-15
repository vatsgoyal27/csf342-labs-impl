`timescale 1ns/1ps

module alucomp(input [31:0] a, input [31:0] b, output [31:0] out);
    wire [31:0] result;
    wire slt_result;
    wire [1:0] pos_ov, neg_ov;
    aluaddsub aluaddsub_inst(a, b, 1'b1, result, pos_ov, neg_ov);

    if no, b>a. if +, a>b, if b>a
    

endmodule