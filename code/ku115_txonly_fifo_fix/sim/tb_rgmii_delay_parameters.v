`timescale 1ns / 1ps

module tb_rgmii_delay_parameters;

reg reset;
reg rgmii_rxc;
reg [3:0] rgmii_rd;
reg rgmii_rx_ctl;
reg [7:0] gmii_txd;
reg gmii_tx_en;
reg gmii_tx_er;
reg [1:0] speed_selection;
reg duplex_mode;

wire [3:0] rgmii_td;
wire rgmii_tx_ctl;
wire rgmii_txc;
wire gmii_rx_clk;
wire gmii_tx_clk;
wire gmii_crs;
wire gmii_col;
wire [7:0] gmii_rxd;
wire gmii_rx_dv;
wire gmii_rx_er;

util_gmii_to_rgmii #(
    .RXD0_DELAY_PS(600),
    .RXD1_DELAY_PS(700),
    .RXD2_DELAY_PS(800),
    .RXD3_DELAY_PS(900),
    .RX_CTL_DELAY_PS(1000)
) dut (
    .reset(reset),
    .rgmii_td(rgmii_td),
    .rgmii_tx_ctl(rgmii_tx_ctl),
    .rgmii_txc(rgmii_txc),
    .rgmii_rd(rgmii_rd),
    .rgmii_rx_ctl(rgmii_rx_ctl),
    .gmii_rx_clk(gmii_rx_clk),
    .rgmii_rxc(rgmii_rxc),
    .gmii_txd(gmii_txd),
    .gmii_tx_en(gmii_tx_en),
    .gmii_tx_er(gmii_tx_er),
    .gmii_tx_clk(gmii_tx_clk),
    .gmii_crs(gmii_crs),
    .gmii_col(gmii_col),
    .gmii_rxd(gmii_rxd),
    .gmii_rx_dv(gmii_rx_dv),
    .gmii_rx_er(gmii_rx_er),
    .speed_selection(speed_selection),
    .duplex_mode(duplex_mode)
);

initial begin
    reset = 1'b1;
    rgmii_rxc = 1'b0;
    rgmii_rd = 4'd0;
    rgmii_rx_ctl = 1'b0;
    gmii_txd = 8'd0;
    gmii_tx_en = 1'b0;
    gmii_tx_er = 1'b0;
    speed_selection = 2'b10;
    duplex_mode = 1'b1;

    #1;
    if (dut.RXD0_DELAY_PS != 600 || dut.RXD1_DELAY_PS != 700 ||
        dut.RXD2_DELAY_PS != 800 || dut.RXD3_DELAY_PS != 900 ||
        dut.RX_CTL_DELAY_PS != 1000) begin
        $display("FAIL: independent RGMII lane delay parameters were not retained");
        $finish;
    end

    $display("PASS: RGMII RXD and RX_CTL delays are independently parameterized");
    $finish;
end

endmodule
