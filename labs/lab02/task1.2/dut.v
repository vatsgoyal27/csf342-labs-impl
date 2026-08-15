`timescale 1ns/1ps
module dut (
    input wire clk,
    input wire d,
    input wire reset_n, // Active-low reset input
    output reg q
);
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            q <= 1'b0;
        else
            q <= d;
    end
endmodule