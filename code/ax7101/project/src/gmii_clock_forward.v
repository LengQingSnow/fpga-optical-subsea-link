`timescale 1ns/1ps

module gmii_clock_forward (
    input  wire clk_125,
    input  wire reset_n,
    output wire gmii_gtxc
);

ODDR #(
    .DDR_CLK_EDGE("SAME_EDGE"),
    .INIT(1'b0),
    .SRTYPE("ASYNC")
) u_oddr (
    .Q(gmii_gtxc),
    .C(clk_125),
    .CE(1'b1),
    .D1(1'b0),
    .D2(1'b1),
    .R(!reset_n),
    .S(1'b0)
);

endmodule

