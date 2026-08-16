`timescale 1ns/1ps

module branch_comp(
    input  wire [31:0] rs1,
    input  wire [31:0] rs2,
    output wire beq,   // 1 = rs1 == rs2
    output wire bne    // 1 = rs1 != rs2
);
    wire [31:0] zero_check;
    wire zero;
    rv32ialu ALU(
    .A(rs1),
    .B(rs2),
    .alu_ctrl(3'b000),
    .Y(zero_check),
    .zero(zero)
    );

    assign bne = (zero_check) ? 1'b1 : 1'b0;
    assign beq = (zero_check) ? 1'b0 : 1'b1;

endmodule