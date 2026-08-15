`timescale 1ns/1ps
module dff (
    input wire clk,
    input wire d,
    input wire reset_n, // Active-low reset input
    output reg q
);
    always @(posedge clk) begin
        if (!reset_n)
            q <= 1'b0;
        else
            q <= d;
    end
endmodule