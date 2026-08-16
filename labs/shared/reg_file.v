`timescale 1ns/1ps

module reg_file(input clk, reset, input we, input [4:0] w_addr, input [31:0] data_in, input [4:0] read_1, read_2, output [31:0] rdata1, output [31:0] rdata2);
    genvar i;
    wire [31:0] rout [31:0];
    assign rout[0] = 32'b0;
    wire[31:0] we_dec;
    decoder5to32 decoder5to32_inst(w_addr, we, we_dec);
    generate for (i = 1; i < 32; i= i+1) begin: reg32_loop
        reg32 reg32_1(clk, reset, we_dec[i], data_in, rout[i]);
    end
    endgenerate
    assign #1 rdata1 = rout[read_1];
    assign #1 rdata2 = rout[read_2];

endmodule