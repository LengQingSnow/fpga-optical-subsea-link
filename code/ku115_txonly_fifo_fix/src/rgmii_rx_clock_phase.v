`timescale 1ps / 1ps

module rgmii_rx_clock_phase #(
    parameter real CLKOUT_PHASE_DEGREES = -90.0
) (
    input  wire clk_in,
    input  wire reset,
    output wire clk_out,
    output wire locked
);

wire clk_feedback_unbuffered;
wire clk_feedback;
wire clk_out_unbuffered;

PLLE3_BASE #(
    .CLKFBOUT_MULT(8),
    .CLKFBOUT_PHASE(0.0),
    .CLKIN_PERIOD(8.0),
    .CLKOUT0_DIVIDE(8),
    .CLKOUT0_DUTY_CYCLE(0.5),
    .CLKOUT0_PHASE(CLKOUT_PHASE_DEGREES),
    .CLKOUT1_DIVIDE(8),
    .CLKOUT1_DUTY_CYCLE(0.5),
    .CLKOUT1_PHASE(0.0),
    .DIVCLK_DIVIDE(1),
    .REF_JITTER(0.010),
    .STARTUP_WAIT("FALSE")
) rx_pll_inst (
    .CLKFBOUT(clk_feedback_unbuffered),
    .CLKOUT0(clk_out_unbuffered),
    .CLKOUT0B(),
    .CLKOUT1(),
    .CLKOUT1B(),
    .CLKOUTPHY(),
    .LOCKED(locked),
    .CLKFBIN(clk_feedback),
    .CLKIN(clk_in),
    .CLKOUTPHYEN(1'b0),
    .PWRDWN(1'b0),
    .RST(reset)
);

(* DONT_TOUCH = "true" *)
BUFGCE #(
    .CE_TYPE("SYNC"),
    .IS_CE_INVERTED(1'b0),
    .IS_I_INVERTED(1'b0),
    .SIM_DEVICE("ULTRASCALE")
) feedback_bufg_inst (
    .I(clk_feedback_unbuffered),
    .CE(1'b1),
    .O(clk_feedback)
);

BUFGCE #(
    .CE_TYPE("SYNC"),
    .IS_CE_INVERTED(1'b0),
    .IS_I_INVERTED(1'b0),
    .SIM_DEVICE("ULTRASCALE")
) output_bufg_inst (
    .I(clk_out_unbuffered),
    .CE(1'b1),
    .O(clk_out)
);

endmodule
