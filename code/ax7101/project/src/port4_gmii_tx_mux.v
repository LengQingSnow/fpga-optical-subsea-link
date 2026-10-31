`timescale 1ns/1ps

module port4_gmii_tx_mux (
    input  wire       select_prbs,
    input  wire       arp_tx_en,
    input  wire       arp_tx_er,
    input  wire [7:0] arp_txd,
    input  wire       prbs_tx_en,
    input  wire       prbs_tx_er,
    input  wire [7:0] prbs_txd,
    output wire       gmii_tx_en,
    output wire       gmii_tx_er,
    output wire [7:0] gmii_txd
);

assign gmii_tx_en = select_prbs ? prbs_tx_en : arp_tx_en;
assign gmii_tx_er = select_prbs ? prbs_tx_er : arp_tx_er;
assign gmii_txd = select_prbs ? prbs_txd : arp_txd;

endmodule
