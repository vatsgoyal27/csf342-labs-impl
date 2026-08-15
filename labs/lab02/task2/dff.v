`timescale 1ns/1ps
module dff (
    input wire clk,
    input wire d,
    input wire reset, // Active-low reset input
    output reg q
);
    always @(posedge clk) begin
        if (!reset)
            q <= 1'b0;
        else
            q <= d;
    end
endmodule