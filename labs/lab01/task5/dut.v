module dut(input [3:0]a,
           input [3:0]b,
           input m,
           output [3:0]sum,
           output cout);
    wire [3:0] b_mod;
    assign b_mod = b ^ {4{m}};

    fa4 fulladder4inst(a, b_mod, m, sum, cout);
endmodule