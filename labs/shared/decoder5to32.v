`timescale 1ns/1ps

module decoder5to32(input [4:0] rd, input register_write_en, output [31:0] dec_out);
    assign #1 dec_out = (reg_write_en) ? (32'b1 <<rd): 32'b0;
endmodule