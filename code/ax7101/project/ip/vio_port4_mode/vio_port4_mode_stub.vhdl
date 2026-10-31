-- Copyright 1986-2021 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2021.2 (win64) Build 3367213 Tue Oct 19 02:48:09 MDT 2021
-- Date        : Sun Jul 26 12:51:57 2026
-- Host        : LAPTOP-KMF3OJ9O running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub
--               c:/Users/20474/Desktop/code/ax7101/project/ip/vio_port4_mode/vio_port4_mode_stub.vhdl
-- Design      : vio_port4_mode
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7a100tfgg484-2
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity vio_port4_mode is
  Port ( 
    clk : in STD_LOGIC;
    probe_in0 : in STD_LOGIC_VECTOR ( 0 to 0 );
    probe_in1 : in STD_LOGIC_VECTOR ( 31 downto 0 );
    probe_out0 : out STD_LOGIC_VECTOR ( 0 to 0 )
  );

end vio_port4_mode;

architecture stub of vio_port4_mode is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "clk,probe_in0[0:0],probe_in1[31:0],probe_out0[0:0]";
attribute X_CORE_INFO : string;
attribute X_CORE_INFO of stub : architecture is "vio,Vivado 2021.2";
begin
end;
