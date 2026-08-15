module dut (
    input  a,
    input  b,
    input  cin,
    output reg sum,
    output reg cout
);

    // Behavioral modeling using a procedural always block
    always @(*) begin
        // Compute sum and carry-out using Boolean operators inside procedural statements
        sum  = a ^ b ^ cin;
        cout = (a & b) | (b & cin) | (a & cin);
    end

endmodule