`timescale 1ns/1ps

module mux32_4to1(input [1:0] sel, input [31:0] a, input [31:0] b, input [31:0] c, input [31:0] d, output [31:0] out);
    genvar i;
    generate 
        for (i =0; i < 32; i= i+1) begin: gen_mux4to1
        mux4to1 mux4to1_inst(sel, a[i], b[i], c[i], d[i], out[i]);
        end
    endgenerate
endmodule

module mux4to1(input [1:0] sel, input a, b, c, d, output out);
    //assign #2 out = (a& (~sel[1] & ~sel[0])) | (b& (~sel[1] & sel[0])) | (c& (sel[1] & ~sel[0])) | (d& (sel[1] & sel[0]));
    wire [1:0] middle;
    mux2to1 mux2to1_0a(sel[0], a, b, middle[0]);
    mux2to1 mux2to1_0b(sel[0], c, d, middle[1]);
    mux2to1 mux2to1_1a(sel[1], middle[0], middle[1], out);
endmodule

module mux2to1(input sel, input a, b, output out);
    assign #1 out = sel ? b:a;
endmodule