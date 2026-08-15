`timescale 1ns/1ps

module alushift(input [31:0] a, input [31:0] b, input sll0_srl1, output [31:0] out);
    wire [4:0] shift_amt;
    wire [31:0] out_raw;
    assign shift_amt = b[4:0];
    assign out_raw  = sll0_srl1 ? (a >> shift_amt) : (a << shift_amt);
    assign #1 out = out_raw;
endmodule