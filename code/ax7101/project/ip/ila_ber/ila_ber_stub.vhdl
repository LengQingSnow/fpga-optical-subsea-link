-- Copyright 1986-2021 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2021.2 (win64) Build 3367213 Tue Oct 19 02:48:09 MDT 2021
-- Date        : Sat Jul 25 00:18:24 2026
-- Host        : LAPTOP-KMF3OJ9O running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub c:/Users/20474/Desktop/code/ax7101/project/ip/ila_ber/ila_ber_stub.vhdl
-- Design      : ila_ber
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7a100tfgg484-2
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ila_ber is
  Port ( 
    clk : in STD_LOGIC;
    probe0 : in STD_LOGIC_VECTOR ( 11 downto 0 );
    probe1 : in STD_LOGIC_VECTOR ( 1 downto 0 );
    probe2 : in STD_LOGIC_VECTOR ( 31 downto 0 );
    probe3 : in STD_LOGIC_VECTOR ( 31 downto 0 );
    probe4 : in STD_LOGIC_VECTOR ( 31 downto 0 );
    probe5 : in STD_LOGIC_VECTOR ( 31 downto 0 );
    probe6 : in STD_LOGIC_VECTOR ( 31 downto 0 );
    probe7 : in STD_LOGIC_VECTOR ( 31 downto 0 );
    probe8 : in STD_LOGIC_VECTOR ( 31 downto 0 );
    probe9 : in STD_LOGIC_VECTOR ( 31 downto 0 );
    probe10 : in STD_LOGIC_VECTOR ( 31 downto 0 );
    probe11 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe12 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe13 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe14 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe15 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe16 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe17 : in STD_LOGIC_VECTOR ( 31 downto 0 );
    probe18 : in STD_LOGIC_VECTOR ( 31 downto 0 );
    probe19 : in STD_LOGIC_VECTOR ( 95 downto 0 )
  );

end ila_ber;

architecture stub of ila_ber is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "clk,probe0[11:0],probe1[1:0],probe2[31:0],probe3[31:0],probe4[31:0],probe5[31:0],probe6[31:0],probe7[31:0],probe8[31:0],probe9[31:0],probe10[31:0],probe11[63:0],probe12[63:0],probe13[63:0],probe14[63:0],probe15[63:0],probe16[63:0],probe17[31:0],probe18[31:0],probe19[95:0]";
attribute X_CORE_INFO : string;
attribute X_CORE_INFO of stub : architecture is "ila,Vivado 2021.2";
begin
end;
