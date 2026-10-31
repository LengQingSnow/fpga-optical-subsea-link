`timescale 1ns/1ps

module tb_port4_gmii_tx_mux;

reg select_prbs;
reg arp_tx_en;
reg arp_tx_er;
reg [7:0] arp_txd;
reg prbs_tx_en;
reg prbs_tx_er;
reg [7:0] prbs_txd;
wire gmii_tx_en;
wire gmii_tx_er;
wire [7:0] gmii_txd;

port4_gmii_tx_mux dut (
    .select_prbs(select_prbs),
    .arp_tx_en(arp_tx_en),
    .arp_tx_er(arp_tx_er),
    .arp_txd(arp_txd),
    .prbs_tx_en(prbs_tx_en),
    .prbs_tx_er(prbs_tx_er),
    .prbs_txd(prbs_txd),
    .gmii_tx_en(gmii_tx_en),
    .gmii_tx_er(gmii_tx_er),
    .gmii_txd(gmii_txd)
);

initial begin
    arp_tx_en = 1'b1;
    arp_tx_er = 1'b0;
    arp_txd = 8'ha5;
    prbs_tx_en = 1'b0;
    prbs_tx_er = 1'b1;
    prbs_txd = 8'h3c;

    select_prbs = 1'b0;
    #1;
    if ({gmii_tx_en, gmii_tx_er, gmii_txd} !== {1'b1, 1'b0, 8'ha5})
        $fatal(1, "Receive mode did not select ARP transmitter");

    select_prbs = 1'b1;
    #1;
    if ({gmii_tx_en, gmii_tx_er, gmii_txd} !== {1'b0, 1'b1, 8'h3c})
        $fatal(1, "Transmit mode did not select PRBS transmitter");

    arp_tx_en = 1'b0;
    arp_tx_er = 1'b1;
    arp_txd = 8'hff;
    prbs_tx_en = 1'b1;
    prbs_tx_er = 1'b0;
    prbs_txd = 8'h69;
    #1;
    if ({gmii_tx_en, gmii_tx_er, gmii_txd} !== {1'b1, 1'b0, 8'h69})
        $fatal(1, "ARP activity leaked into PRBS mode");

    $display("PASS tb_port4_gmii_tx_mux");
    $finish;
end

endmodule
