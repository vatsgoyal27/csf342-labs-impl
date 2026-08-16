`timescale 1ns/1ps
 
module branch_comp(
    input  wire [31:0] rs1,
    input  wire [31:0] rs2,
    input  wire [2:0]  funct3,      // selects which of the 6 branch comparisons to run
    output reg branch_taken // 1 = condition holds; drive into PCSrc alongside Branch
);
    // Reuse alucomp for less-than: instantiate it twice, once per sign mode
    wire [31:0] lt_signed_bus, lt_unsigned_bus;
    alucomp cmp_signed  (.a(rs1), .b(rs2), .sign0_unsign1(1'b0), .out(lt_signed_bus));
    alucomp cmp_unsigned(.a(rs1), .b(rs2), .sign0_unsign1(1'b1), .out(lt_unsigned_bus));
 
    // alucomp broadcasts its 1-bit result across all 32 bits ({32{alessthanb}});
    // bit 0 alone carries the real comparison result.
    wire lt_signed   = lt_signed_bus[0];
    wire lt_unsigned = lt_unsigned_bus[0];
 
    // alucomp only exposes less-than, not equality, so equality is computed
    wire equal = (rs1 == rs2);
 
    always @(*) begin
        case (funct3)
            3'b000: branch_taken = equal;          // BEQ
            3'b001: branch_taken = ~equal;         // BNE
            3'b100: branch_taken = lt_signed;      // BLT
            3'b101: branch_taken = ~lt_signed;     // BGE
            3'b110: branch_taken = lt_unsigned;    // BLTU
            3'b111: branch_taken = ~lt_unsigned;   // BGEU
            default: branch_taken = 1'b0;          // funct3=010/011 unused by branches
        endcase
    end
 
endmodule
