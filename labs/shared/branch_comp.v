`timescale 1ns/1ps

module branch_comp(
    input  wire [31:0] rs1,
    input  wire [31:0] rs2,
    output wire beq,   // 1 = rs1 == rs2
    output wire bne    // 1 = rs1 != rs2
);
    assign beq = (rs1 == rs2);
    assign bne = ~beq;

endmodule