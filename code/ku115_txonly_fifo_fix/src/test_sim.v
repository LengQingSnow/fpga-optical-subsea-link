`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/08/15 14:12:24
// Design Name: 
// Module Name: test_sim
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module test_sim;
 reg clk;
 reg rst_n;
 wire [1:0]speed;    
 wire [1:0]link;
 wire [3:0]led;   
 
 initial begin
 clk = 0;
 rst_n=0;
 #1000
 rst_n=1;
 #20000;
 end
 
 always #10 clk = ~clk;
 
 
  smi_config m1

       (
                        . clk(clk),
                        . rst_n(rst_n)  , 
                        .mdc(),      //mdc interface
                        . mdio(),     //mdio interface
                        .speed(speed),    //ethernet speed 00:10M 01:100M 10:1000M
                        .link(link),     //ethernet link signal
                        .led(led)       //led 1110: 10M  1100: 100M 1000:1000M  1111: not link
		 
       );
endmodule
