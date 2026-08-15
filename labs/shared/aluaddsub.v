`timescale 1ns/1ps

module aluaddsub (
    input  signed [31:0] a,
    input  signed [31:0] b,
    input                m,     // 0 = subtract, 1 = add
    output signed [31:0] sum,
    output               pos_ovf, // Positive Overflow
    output               neg_ovf  // Negative Overflow
);
    wire signed [31:0] b_mod;
    wire        [32:0] c;
    wire signed [31:0] sum_raw;

    assign b_mod = b ^ {32{~m}};
    assign c[0]  = ~m;

    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : add_loop
            assign c[i+1]    = (a[i] & b_mod[i]) | (c[i] & (a[i] ^ b_mod[i]));
            assign sum_raw[i] = a[i] ^ b_mod[i] ^ c[i];
        end
    endgenerate

    // Canonical delay (#3)
    assign #3 sum     = sum_raw;
    assign #3 pos_ovf = (~c[31]) & c[32]; // Cin into MSB is 0, Cout from MSB is 1
    assign #3 neg_ovf = c[31] & (~c[32]); // Cin into MSB is 1, Cout from MSB is 0

endmodule