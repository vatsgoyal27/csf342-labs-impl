`timescale 1ns/1ps

module immGen (
    input  wire [1:0]  immSel,        // 00 -> imm_i, 01 -> imm_j, 10 -> imm_b, 11 -> imm_s
    input  wire [31:0] instruction,
    output wire [31:0] immOut
);

    wire [31:0] imm_i, imm_j, imm_b, imm_s;

    // 1. I-Type (12-bit immediate: inst[31:20]) -> 20 sign bits + 12 bits = 32
    assign imm_i = {{20{instruction[31]}}, instruction[31:20]};

    // 2. J-Type (20-bit scrambled immediate + implicit 0) -> 12 sign bits + 20 bits = 32
    assign imm_j = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};

    // 3. B-Type (12-bit scrambled immediate + implicit 0) -> 19 sign bits + 13 bits = 32
    assign imm_b = {{19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};

    // 4. S-Type (12-bit split immediate) -> 20 sign bits + 12 bits = 32
    assign imm_s = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};

    // Multiplexer routing (maps immSel values 00, 01, 10, 11 to inputs a, b, c, d)
    mux32_4to1 mux32_4to1_inst (
        .sel (immSel),
        .a   (imm_i),
        .b   (imm_j),
        .c   (imm_b),
        .d   (imm_s),
        .out (immOut)
    );

endmodule