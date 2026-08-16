`timescale 1ns/1ps

module PCInc(input clk, input [31:0] oldPC, output reg [31:0] newPC);
    wire [31:0] pc_plus_4;
    rv32ialu rv32ialu_inst_ (
        .A      (oldPC),
        .B      (32'b100),        // 32-bit constant 4
        .alu_ctrl (3'b001),       // Add
        .Y (pc_plus_4),
        .zero   ()              // unused
    );

    always @(posedge clk) begin
        newPC <= pc_plus_4;
    end
endmodule