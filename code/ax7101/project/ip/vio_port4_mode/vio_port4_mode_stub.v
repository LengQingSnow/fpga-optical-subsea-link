// Copyright 1986-2021 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2021.2 (win64) Build 3367213 Tue Oct 19 02:48:09 MDT 2021
// Date        : Sun Jul 26 12:51:57 2026
// Host        : LAPTOP-KMF3OJ9O running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               c:/Users/20474/Desktop/code/ax7101/project/ip/vio_port4_mode/vio_port4_mode_stub.v
// Design      : vio_port4_mode
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a100tfgg484-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "vio,Vivado 2021.2" *)
module vio_port4_mode(clk, probe_in0, probe_in1, probe_out0)
/* synthesis syn_black_box black_box_pad_pin="clk,probe_in0[0:0],probe_in1[31:0],probe_out0[0:0]" */;
  input clk;
  input [0:0]probe_in0;
  input [31:0]probe_in1;
  output [0:0]probe_out0;
endmodule
