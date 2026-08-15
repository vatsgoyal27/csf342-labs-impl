`timescale 1ns/1ps

module alulogic(input [31:0] a, input [31:0] b, input and0_or1, output [31:0] out);
    wire [31:0] out_raw;
    
    assign out_mid = and0_or1 ? a | b : a & b;

    assign #1 out = out_raw;
endmodule