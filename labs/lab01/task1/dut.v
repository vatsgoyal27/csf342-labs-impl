module dut(input a, input b, input cin, output sum, output cout);
    wire [4:0] temp;
    xor(temp[0], a, b);
    xor(sum, temp[0], cin);
    and(temp[1], a, b);
    and(temp[2], b, cin);
    and(temp[3], cin, a);
    or(temp[4], temp[1], temp[2]);
    or(cout, temp[4], temp[3]);
endmodule