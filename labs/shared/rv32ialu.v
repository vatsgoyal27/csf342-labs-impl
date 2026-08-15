`timescale 1ns/1ps

module rv32ialu(input signed [31:0] A, input signed [31:0] B, input [2:0] alu_ctrl, output signed [31:0] Y, output zero);
    wire pos_ovf, neg_ovf;
    wire [31:0] Y_addsub, Y_comp, Y_logic, Y_shift;
    reg signed  [31:0] out_reg;
    aluaddsub aluaddsub_inp(A, B, alu_ctrl[0], Y_addsub, pos_ovf, neg_ovf);
    alucomp alucomp_inp(A, B, Y_comp);
    alulogic alulogic_inp(A, B, alu_ctrl[0], Y_logic);
    alushift alushift_inp(A, B, alu_ctrl[0], Y_shift);

    always @(*) begin
        case (alu_ctrl)
            3'b000: out_reg = Y_addsub;
            3'b001: out_reg = Y_addsub;
            3'b010: out_reg = Y_logic;
            3'b011: out_reg = Y_logic;
            3'b100: out_reg = Y_shift;
            3'b101: out_reg = Y_shift;
            3'b110: out_reg = Y_comp;
            3'b111: out_reg = 32'b0;
        endcase
    end
    assign #1 Y = out_reg;
    assign zero = (Y == 32'b0);
endmodule