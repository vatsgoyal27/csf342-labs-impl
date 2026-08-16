module BankedMEM(input clk, input writeEn, input [31:0] address, input [31:0] writeData, output [31:0] readData);
    //IMEM and DMEM, reads async, writes sync
    //only using 10 bit addressing for now for speed
    reg [7:0] b0 [0:1023];
    reg [7:0] b1 [0:1023];
    reg [7:0] b2 [0:1023];
    reg [7:0] b3 [0:1023];
    wire [9:0] address_actual;
    assign address_actual = address [11:2]; //indexes 1 and 0 are always 00 because of the word aware nature of the addresses 

    always @(posedge clk) begin
        if (writeEn) begin
            b0 [address_actual] <= writeData[7:0];
            b1 [address_actual] <= writeData[15:8];
            b2 [address_actual] <= writeData[23:16];
            b3 [address_actual] <= writeData[31:24];
        end
    end

    assign readData[7:0] = b0[address_actual];
    assign readData[15:8] = b1[address_actual];
    assign readData[23:16] = b2[address_actual];
    assign readData[31:24] = b3[address_actual];

endmodule