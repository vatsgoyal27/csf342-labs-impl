`timescale 1ns/1ps

module alucomp(input [31:0] a, input [31:0] b, input sign0_unsign1, output [31:0] out);
    wire [31:0] result;
    wire alessthanb;
    wire pos_ov, neg_ov, c_out;
    aluaddsub aluaddsub_inst(a, b, 1'b0, result, pos_ov, neg_ov, c_out);

    assign alessthanb = (((result[31] & ~pos_ov) | neg_ov) & ~sign0_unsign1) | (sign0_unsign1 & (~c_out));

    assign #1 out = {32{alessthanb}};
    
endmodule