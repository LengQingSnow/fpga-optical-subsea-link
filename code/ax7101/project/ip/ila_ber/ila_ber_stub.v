// Copyright 1986-2021 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2021.2 (win64) Build 3367213 Tue Oct 19 02:48:09 MDT 2021
// Date        : Sat Jul 25 00:18:24 2026
// Host        : LAPTOP-KMF3OJ9O running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub c:/Users/20474/Desktop/code/ax7101/project/ip/ila_ber/ila_ber_stub.v
// Design      : ila_ber
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a100tfgg484-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "ila,Vivado 2021.2" *)
module ila_ber(clk, probe0, probe1, probe2, probe3, probe4, probe5, 
  probe6, probe7, probe8, probe9, probe10, probe11, probe12, probe13, probe14, probe15, probe16, probe17, 
  probe18, probe19)
/* synthesis syn_black_box black_box_pad_pin="clk,probe0[11:0],probe1[1:0],probe2[31:0],probe3[31:0],probe4[31:0],probe5[31:0],probe6[31:0],probe7[31:0],probe8[31:0],probe9[31:0],probe10[31:0],probe11[63:0],probe12[63:0],probe13[63:0],probe14[63:0],probe15[63:0],probe16[63:0],probe17[31:0],probe18[31:0],probe19[95:0]" */;
  input clk;
  input [11:0]probe0;
  input [1:0]probe1;
  input [31:0]probe2;
  input [31:0]probe3;
  input [31:0]probe4;
  input [31:0]probe5;
  input [31:0]probe6;
  input [31:0]probe7;
  input [31:0]probe8;
  input [31:0]probe9;
  input [31:0]probe10;
  input [63:0]probe11;
  input [63:0]probe12;
  input [63:0]probe13;
  input [63:0]probe14;
  input [63:0]probe15;
  input [63:0]probe16;
  input [31:0]probe17;
  input [31:0]probe18;
  input [95:0]probe19;
endmodule
