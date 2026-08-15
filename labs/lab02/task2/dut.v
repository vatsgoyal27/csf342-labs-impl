`timescale 1ns/1ps

module dut (
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] d,
    output wire [7:0] q
);

    // Generate block to instantiate 8 individual D Flip-Flops
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : dff_gen
            dff dff_inst (
                .clk    (clk),
                .reset(reset),
                .d      (d[i]),
                .q      (q[i])
            );
        end
    endgenerate

endmodule