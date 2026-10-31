`timescale 1ns/1ps

module clock_gen_200_to_125 (
    input  wire sys_clk_p,
    input  wire sys_clk_n,
    input  wire reset_n,
    output wire sys_clk_200,
    output wire tx_clk_125,
    output wire locked
);

wire sys_clk_ibuf;
wire sys_clk_global;
wire clkfb_unbuffered;
wire clkfb_buffered;
wire tx_clk_unbuffered;

IBUFDS u_sys_clk_ibuf (
    .I(sys_clk_p),
    .IB(sys_clk_n),
    .O(sys_clk_ibuf)
);

BUFG u_sys_clk_bufg (
    .I(sys_clk_ibuf),
    .O(sys_clk_global)
);

MMCME2_BASE #(
    .BANDWIDTH("OPTIMIZED"),
    .CLKFBOUT_MULT_F(5.000),
    .CLKIN1_PERIOD(5.000),
    .CLKOUT0_DIVIDE_F(8.000),
    .DIVCLK_DIVIDE(1),
    .STARTUP_WAIT("FALSE")
) u_mmcm (
    .CLKIN1(sys_clk_global),
    .CLKFBIN(clkfb_buffered),
    .RST(!reset_n),
    .PWRDWN(1'b0),
    .CLKFBOUT(clkfb_unbuffered),
    .CLKOUT0(tx_clk_unbuffered),
    .LOCKED(locked)
);

BUFG u_clkfb_bufg (
    .I(clkfb_unbuffered),
    .O(clkfb_buffered)
);

BUFG u_tx_bufg (
    .I(tx_clk_unbuffered),
    .O(tx_clk_125)
);

assign sys_clk_200 = sys_clk_global;

endmodule

