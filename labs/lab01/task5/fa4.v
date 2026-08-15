module fa4(input [3:0]a,
           input [3:0]b,
           input cin,
           output [3:0]sum,
           output cout);

wire[3:1]cint;

fa FA0(a[0],b[0],cin,sum[0],cint[1]);
fa FA1(a[1],b[1],cint[1],sum[1],cint[2]); 
fa FA2(a[2],b[2],cint[2],sum[2],cint[3]); 
fa FA3(a[3],b[3],cint[3],sum[3],cout);     

endmodule