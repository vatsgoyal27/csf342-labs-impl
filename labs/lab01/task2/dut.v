module dut (
    input  a,
    input  b,
    input  cin,
    output sum,
    output cout
);

    // Dataflow modeling using continuous assignments (assign)
    // Sum: XOR operation across all inputs
    assign sum  = a ^ b ^ cin;

    // Carry-out: Majority function using bitwise AND/OR logic
    assign cout = (a & b) | (b & cin) | (a & cin);

endmodule