`timescale 1ns / 1ps  
//////////////////////////////////////////////////////////////////////////////////
// Module Name:    ethernet_test 
//////////////////////////////////////////////////////////////////////////////////
module ethernet_test
#(
 parameter [47:0] LOCAL_MAC_ADDR = 48'h00_0a_35_01_fe_c0,
 parameter [31:0] LOCAL_IP_ADDR  = 32'hc0a80002,
 parameter [31:0] DEST_IP_ADDR   = 32'hc0a80003,
 parameter          FIXED_GIGABIT = 1'b1,
 parameter integer RXD0_DELAY_PS = 1000,
 parameter integer RXD1_DELAY_PS = 1000,
 parameter integer RXD2_DELAY_PS = 1000,
 parameter integer RXD3_DELAY_PS = 1000,
 parameter integer RX_CTL_DELAY_PS = 1000
)
(
 input          rst_n,
 input          sys_rst_n,
 input          sys_clk,   
 
 output [3:0]   led,
  
 output         e_mdc,
 inout          e_mdio,
 
 output [3:0]   rgmii_txd,
 output         rgmii_txctl,
 output         rgmii_txc,
 input  [3:0]   rgmii_rxd,
 input          rgmii_rxctl,
 input          rgmii_rxc,

 output         aggregate_clk,
 output [7:0]   aggregate_data,
 output         aggregate_valid,
 input          aggregate_ready,
 output [23:0]  aggregate_packet_data,
 output         aggregate_packet_valid,
 output [31:0]  rx_mac_good_count,
 output [31:0]  rx_mac_crc_error_count,
 output [31:0]  rx_ip_checksum_error_count,
 output [31:0]  rx_udp_checksum_error_count,
 output [31:0]  rx_udp_packet_commit_count,
 output [31:0]  rx_udp_buffer_overflow_count
);

(* MARK_DEBUG="true" *)wire   [ 7:0]   gmii_txd     ;
(* MARK_DEBUG="true" *)wire            gmii_tx_en   ;
wire            gmii_tx_er   ;
wire            gmii_tx_clk  ;
wire            gmii_crs     ;
wire            gmii_col     ;
wire   [ 7:0]   gmii_rxd     ;
wire            gmii_rx_dv   ;
wire            gmii_rx_er   ;
wire            gmii_rx_clk  ;

wire  [31:0]    pack_total_len ;
wire            duplex_mode;     // 1 full, 0 half

assign duplex_mode = 1'b1;

wire [1:0]      phy_speed  ;
wire            phy_link   ;
wire [1:0]      mac_speed  ;
wire            mac_link   ;
(* MARK_DEBUG="true" *)wire            e_rx_dv    ;
(* MARK_DEBUG="true" *)wire [7:0]      e_rxd      ;
wire            e_tx_en    ;
wire [7:0]      e_txd      ;
wire            e_rst_n    ;

assign mac_speed = FIXED_GIGABIT ? 2'b10 : phy_speed;
assign mac_link  = FIXED_GIGABIT ? 1'b1  : phy_link;



gmii_arbi arbi_inst
(
 .clk                (gmii_tx_clk      ),
 .rst_n              (rst_n            ),
 .speed              (mac_speed        ),  
 .link               (mac_link         ), 
 .pack_total_len     (pack_total_len   ), 
 .e_rst_n            (e_rst_n          ),
 .gmii_rx_dv         (gmii_rx_dv       ),
 .gmii_rxd           (gmii_rxd         ),
 .gmii_tx_en         (gmii_tx_en       ),
 .gmii_txd           (gmii_txd         ), 
 .e_rx_dv            (e_rx_dv          ),
 .e_rxd              (e_rxd            ),
 .e_tx_en            (e_tx_en          ),
 .e_txd              (e_txd            )

 
);

smi_config  smi_config_inst
       (
        .clk         (sys_clk  ),
        .rst_n       (sys_rst_n),		 
        .mdc         (e_mdc    ),
        .mdio        (e_mdio   ),
        .speed       (phy_speed),
        .link        (phy_link ),
        .led         (led      )	
       );
	
 util_gmii_to_rgmii #(
  .RXD0_DELAY_PS          (RXD0_DELAY_PS),
  .RXD1_DELAY_PS          (RXD1_DELAY_PS),
  .RXD2_DELAY_PS          (RXD2_DELAY_PS),
  .RXD3_DELAY_PS          (RXD3_DELAY_PS),
  .RX_CTL_DELAY_PS        (RX_CTL_DELAY_PS)
 ) util_gmii_to_rgmii_m0
(
 .reset                  (~rst_n           ),
 
 .rgmii_td               (rgmii_txd       ),
 .rgmii_tx_ctl           (rgmii_txctl     ),
 .rgmii_txc              (rgmii_txc       ),
 .rgmii_rd               (rgmii_rxd       ),
 .rgmii_rx_ctl           (rgmii_rxctl     ),
 .rgmii_rxc              (rgmii_rxc       ),
                                          
 .gmii_txd               (e_txd           ),
 .gmii_tx_en             (e_tx_en         ),
 .gmii_tx_er             (1'b0            ),
 .gmii_tx_clk            (gmii_tx_clk     ),
 .gmii_crs               (gmii_crs        ),
 .gmii_col               (gmii_col        ),
 .gmii_rxd               (gmii_rxd        ),
 .gmii_rx_dv             (gmii_rx_dv      ),
 .gmii_rx_er             (gmii_rx_er      ),
 .gmii_rx_clk            (gmii_rx_clk     ),
 .duplex_mode            (duplex_mode     )
);

	
mac_test #(
 .LOCAL_MAC_ADDR          (LOCAL_MAC_ADDR),
 .LOCAL_IP_ADDR           (LOCAL_IP_ADDR),
 .DEST_IP_ADDR            (DEST_IP_ADDR)
) mac_test0
(
 .gmii_tx_clk            (gmii_tx_clk     ),
 .gmii_rx_clk            (gmii_rx_clk     ),
 .rst_n                  (e_rst_n         ),

 .pack_total_len         (pack_total_len  ),
 .gmii_rx_dv             (e_rx_dv         ),
 .gmii_rxd               (e_rxd           ),
 .gmii_tx_en             (gmii_tx_en      ),
 .gmii_txd               (gmii_txd        ),
 .aggregate_data         (aggregate_data  ),
 .aggregate_valid        (aggregate_valid ),
 .aggregate_ready        (aggregate_ready ),
 .aggregate_packet_data  (aggregate_packet_data),
 .aggregate_packet_valid (aggregate_packet_valid),
 .rx_mac_good_count           (rx_mac_good_count),
 .rx_mac_crc_error_count      (rx_mac_crc_error_count),
 .rx_ip_checksum_error_count  (rx_ip_checksum_error_count),
 .rx_udp_checksum_error_count (rx_udp_checksum_error_count),
 .rx_udp_packet_commit_count  (rx_udp_packet_commit_count),
 .rx_udp_buffer_overflow_count(rx_udp_buffer_overflow_count)
 
); 

assign aggregate_clk = gmii_tx_clk;

	 
    
endmodule
