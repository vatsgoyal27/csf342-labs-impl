`timescale 1ns/1ps

module dut (
    input  wire       clk,
    input  wire       reset, // Changed reset_n -> reset
    output wire [7:0] count  // Changed q -> count
);

    wire [7:0] next_count;

    // Increment logic
    assign next_count = count + 1'b1;

    // Instantiate 8 DFFs
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : counter_reg
            dff dff_inst (
                .clk    (clk),
                .reset_n(reset), // Connects testbench reset to DFF reset_n
                .d      (next_count[i]),
                .q      (count[i])
            );
        end
    endgenerate

endmodule