`timescale 1ns/1ps

module immGen (
    input  wire [2:0]  immSel,        // 000 -> imm_i, 001 -> imm_j, 010 -> imm_b, 011 -> imm_s, 100 -> imm_u
    input  wire [31:0] instruction,
    output wire [31:0] immOut
);

    wire [31:0] imm_i, imm_j, imm_b, imm_s, imm_u;
    wire [31:0] mux4_out;

    // 1. I-Type (12-bit immediate: inst[31:20]) -> 20 sign bits + 12 bits = 32
    assign imm_i = {{20{instruction[31]}}, instruction[31:20]};

    // 2. J-Type (20-bit scrambled immediate + implicit 0) -> 12 sign bits + 20 bits = 32
    assign imm_j = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};

    // 3. B-Type (12-bit scrambled immediate + implicit 0) -> 19 sign bits + 13 bits = 32
    assign imm_b = {{19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};

    // 4. S-Type (12-bit split immediate) -> 20 sign bits + 12 bits = 32
    assign imm_s = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};

    // 5. U-Type (20-bit upper immediate padded with 12 trailing zeros) -> 32 bits
    assign imm_u = {instruction[31:12], 12'h000};

    // Primary Stage: Existing 4-to-1 MUX handling immSel[1:0] (00=i, 01=j, 10=b, 11=s)
    mux32_4to1 mux32_4to1_inst (
        .sel (immSel[1:0]),
        .a   (imm_i),
        .b   (imm_j),
        .c   (imm_b),
        .d   (imm_s),
        .out (mux4_out)
    );

    // Secondary Stage: Selects between 4-to-1 output (immSel[2] == 0) and imm_u (immSel[2] == 1)
    assign #1 immOut = (immSel[2]) ? imm_u : mux4_out;

endmodule