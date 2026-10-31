`timescale 1ns/1ps

module ax7101_dataset_top (
    input  wire        sys_clk_p,
    input  wire        sys_clk_n,
    input  wire        rst_n,
    output wire [1:0]  led,

    inout  wire        cmos1_scl,
    inout  wire        cmos1_sda,
    input  wire        cmos1_vsync,
    input  wire        cmos1_href,
    input  wire        cmos1_pclk,
    input  wire [9:0]  cmos1_db,
    output wire        cmos1_rst_n,
    inout  wire        cmos2_scl,
    inout  wire        cmos2_sda,
    input  wire        cmos2_vsync,
    input  wire        cmos2_href,
    input  wire        cmos2_pclk,
    input  wire [9:0]  cmos2_db,
    output wire        cmos2_rst_n,
    output wire        vga_out_hs,
    output wire        vga_out_vs,
    output wire [4:0]  vga_out_r,
    output wire [5:0]  vga_out_g,
    output wire [4:0]  vga_out_b,

    inout  wire [31:0] ddr3_dq,
    inout  wire [3:0]  ddr3_dqs_n,
    inout  wire [3:0]  ddr3_dqs_p,
    output wire [14:0] ddr3_addr,
    output wire [2:0]  ddr3_ba,
    output wire        ddr3_ras_n,
    output wire        ddr3_cas_n,
    output wire        ddr3_we_n,
    output wire        ddr3_reset_n,
    output wire [0:0]  ddr3_ck_p,
    output wire [0:0]  ddr3_ck_n,
    output wire [0:0]  ddr3_cke,
    output wire [0:0]  ddr3_cs_n,
    output wire [3:0]  ddr3_dm,
    output wire [0:0]  ddr3_odt,

    output wire        e1_reset,
    output wire        e1_mdc,
    inout  wire        e1_mdio,
    input  wire        e1_rxc,
    input  wire        e1_rxdv,
    input  wire        e1_rxer,
    input  wire [7:0]  e1_rxd,
    input  wire        e1_txc,
    output wire        e1_gtxc,
    output reg         e1_txen,
    output wire        e1_txer,
    output reg  [7:0]  e1_txd,

    output wire        e2_reset,
    output wire        e2_mdc,
    inout  wire        e2_mdio,
    input  wire        e2_rxc,
    input  wire        e2_rxdv,
    input  wire        e2_rxer,
    input  wire [7:0]  e2_rxd,
    input  wire        e2_txc,
    output wire        e2_gtxc,
    output reg         e2_txen,
    output wire        e2_txer,
    output reg  [7:0]  e2_txd,

    output wire        e3_reset,
    output wire        e3_mdc,
    inout  wire        e3_mdio,
    input  wire        e3_rxc,
    input  wire        e3_rxdv,
    input  wire        e3_rxer,
    input  wire [7:0]  e3_rxd,
    input  wire        e3_txc,
    output wire        e3_gtxc,
    output wire        e3_txen,
    output wire        e3_txer,
    output wire [7:0]  e3_txd,

    output wire        e4_reset,
    output wire        e4_mdc,
    inout  wire        e4_mdio,
    input  wire        e4_rxc,
    input  wire        e4_rxdv,
    input  wire        e4_rxer,
    input  wire [7:0]  e4_rxd,
    input  wire        e4_txc,
    output wire        e4_gtxc,
    output wire        e4_txen,
    output wire        e4_txer,
    output wire [7:0]  e4_txd
);

wire sys_clk_200;
wire tx_clk_125;
wire clocks_locked;
wire phy_reset_n;
wire sys_reset_n;
wire tx_reset_n;
wire rx4_reset_n;
wire ui_clk;
wire ui_clk_sync_rst;
wire ui_reset_n;
wire init_calib_complete;

wire [1:0] phy_speed_1;
wire [1:0] phy_speed_2;
wire [1:0] phy_speed_3;
wire [1:0] phy_speed_4;
wire phy_link_1;
wire phy_link_2;
wire phy_link_3;
wire phy_link_4;
wire [3:0] phy_led_1;
wire [3:0] phy_led_2;
wire [3:0] phy_led_3;
wire [3:0] phy_led_4;
wire [11:0] phy_status_tx;
wire tx_link_1;
wire tx_link_2;
wire tx_link_3;
wire tx_link_4;
wire [1:0] tx_speed_1;
wire [1:0] tx_speed_2;
wire [1:0] tx_speed_3;
wire [1:0] tx_speed_4;
wire tx_enable_1;
wire tx_enable_2;
wire tx_enable_3;

wire [31:0] mem_araddr;
wire [7:0] mem_arlen;
wire [2:0] mem_arsize;
wire [1:0] mem_arburst;
wire mem_arvalid;
wire mem_arready;
wire [63:0] mem_rdata;
wire mem_rvalid;
wire mem_rlast;
wire [1:0] mem_rresp;
wire mem_rready;
wire [0:0] camera_axi_awid;
wire [31:0] camera_axi_awaddr;
wire [7:0] camera_axi_awlen;
wire [2:0] camera_axi_awsize;
wire [1:0] camera_axi_awburst;
wire camera_axi_awlock;
wire [3:0] camera_axi_awcache;
wire [2:0] camera_axi_awprot;
wire [3:0] camera_axi_awqos;
wire camera_axi_awvalid;
wire camera_axi_awready;
wire [63:0] camera_axi_wdata;
wire [7:0] camera_axi_wstrb;
wire camera_axi_wlast;
wire camera_axi_wvalid;
wire camera_axi_wready;
wire [0:0] camera_axi_bid;
wire [1:0] camera_axi_bresp;
wire camera_axi_bvalid;
wire camera_axi_bready;
wire [0:0] camera_axi_arid;
wire [31:0] camera_axi_araddr;
wire [7:0] camera_axi_arlen;
wire [2:0] camera_axi_arsize;
wire [1:0] camera_axi_arburst;
wire [1:0] camera_axi_arlock;
wire [3:0] camera_axi_arcache;
wire [2:0] camera_axi_arprot;
wire [3:0] camera_axi_arqos;
wire camera_axi_arvalid;
wire camera_axi_arready;
wire [0:0] camera_axi_rid;
wire [63:0] camera_axi_rdata;
wire [1:0] camera_axi_rresp;
wire camera_axi_rlast;
wire camera_axi_rvalid;
wire camera_axi_rready;

wire [15:0] camera1_pixel;
wire camera1_pixel_valid;
wire [15:0] camera2_pixel;
wire camera2_pixel_valid;
wire camera_metadata_valid;
wire camera_metadata_ready;
wire [7:0] camera_packet_type;
wire [7:0] camera_packet_flags;
wire [31:0] camera_packet_cycle;
wire [15:0] camera_packet_object_id;
wire [15:0] camera_packet_valid_length;
wire [31:0] camera_packet_sequence;
wire [31:0] camera_packet_offset;
wire [31:0] camera_packet_object_length;
wire [31:0] camera_packet_object_crc;
wire camera_packet_data_valid;
wire camera_packet_data_ready;
wire [7:0] camera_packet_data;
wire camera_packet_data_last;
wire [31:0] camera1_fifo_overflows;
wire [31:0] camera2_fifo_overflows;
wire [31:0] camera1_fifo_overflows_rx;
wire [31:0] camera2_fifo_overflows_rx;
wire [31:0] camera1_resyncs;
wire [31:0] camera2_resyncs;
wire [31:0] camera_packets_issued;
wire [31:0] camera_packets_issued_rx;
wire [63:0] image_fifo_wdata;
wire image_fifo_wen;
wire [63:0] waveform_fifo_wdata;
wire waveform_fifo_wen;
wire image_fifo_almost_full;
wire waveform_fifo_almost_full;
wire [31:0] image_fifo_overflow;
wire [31:0] waveform_fifo_overflow;
wire [7:0] image_fifo_data;
wire [7:0] waveform_fifo_data;
wire image_fifo_empty;
wire waveform_fifo_empty;
wire image_fifo_read;
wire waveform_fifo_read;
wire [31:0] image_fifo_underflow;
wire [31:0] waveform_fifo_underflow;
wire image_descriptor_ready_ui;
wire waveform_descriptor_ready_ui;
wire [1439:0] image_crc_table;
wire [31:0] waveform_object_crc;
wire [1439:0] image_crc_table_tx;
wire [31:0] waveform_object_crc_tx;
wire [31:0] descriptor_read_count;
wire [31:0] memory_read_error_count;
wire [1:0] descriptor_ready_tx;
reg [1:0] descriptor_ready_tx_stable;

wire image_metadata_valid;
wire image_metadata_ready;
wire [7:0] image_type;
wire [7:0] image_source_port;
wire [7:0] image_flags;
wire [31:0] image_cycle;
wire [15:0] image_object_id;
wire [15:0] image_valid_length;
wire [31:0] image_packet_sequence;
wire [31:0] image_object_offset;
wire [31:0] image_object_length;
wire [31:0] image_object_crc;
wire image_packet_advance;
wire image_packet_data_valid;
wire image_packet_data_ready;
wire [7:0] image_packet_data;
wire image_packet_data_last;

wire waveform_metadata_valid;
wire waveform_metadata_ready;
wire [7:0] waveform_type;
wire [7:0] waveform_source_port;
wire [7:0] waveform_flags;
wire [31:0] waveform_cycle;
wire [15:0] waveform_object_id;
wire [15:0] waveform_valid_length;
wire [31:0] waveform_packet_sequence;
wire [31:0] waveform_object_offset;
wire [31:0] waveform_object_length;
wire [31:0] waveform_packet_crc;
wire waveform_packet_advance;
wire waveform_packet_data_valid;
wire waveform_packet_data_ready;
wire [7:0] waveform_packet_data;
wire waveform_packet_data_last;

wire tx1_en_internal;
wire tx1_er_internal;
wire [7:0] tx1_data_internal;
wire tx2_en_internal;
wire tx2_er_internal;
wire [7:0] tx2_data_internal;
wire tx1_arp_resolved;
wire tx2_arp_resolved;
wire [47:0] tx1_resolved_mac;
wire [47:0] tx2_resolved_mac;
wire tx1_packet_sent;
wire tx2_packet_sent;
wire [31:0] tx1_arp_request_count;
wire [31:0] tx2_arp_request_count;
wire [31:0] tx1_udp_packet_count;
wire [31:0] tx2_udp_packet_count;
wire [31:0] tx1_input_error_count;
wire [31:0] tx2_input_error_count;
wire tx3_en_internal;
wire tx3_er_internal;
wire [7:0] tx3_data_internal;
wire tx3_arp_resolved;
wire [47:0] tx3_resolved_mac;
wire tx3_packet_sent;
wire [31:0] tx3_arp_request_count;
wire [31:0] tx3_udp_packet_count;
wire [31:0] tx3_udp_packet_count_rx;
wire [31:0] tx3_input_error_count;

(* IOB = "TRUE" *) reg [7:0] e4_rxd_iob;
(* IOB = "TRUE" *) reg e4_rxdv_iob;
(* IOB = "TRUE" *) reg e4_rxer_iob;

wire [1:0] rx_current_source;
wire [31:0] image_good_frames;
wire [31:0] image_good_objects;
wire [31:0] image_fcs_errors;
wire [31:0] image_ip_checksum_errors;
wire [31:0] image_udp_checksum_errors;
wire [31:0] image_header_errors;
wire [31:0] image_sequence_errors;
wire [31:0] image_offset_errors;
wire [31:0] image_object_crc_errors;
wire [31:0] waveform_good_frames;
wire [31:0] waveform_good_objects;
wire [31:0] waveform_fcs_errors;
wire [31:0] waveform_ip_checksum_errors;
wire [31:0] waveform_udp_checksum_errors;
wire [31:0] waveform_header_errors;
wire [31:0] waveform_sequence_errors;
wire [31:0] waveform_offset_errors;
wire [31:0] waveform_object_crc_errors;
wire [31:0] rx_malformed_frames;
wire [31:0] rx_gmii_er_frames;
wire rx_stats_toggle;
wire [31:0] arp_requests;
wire [31:0] arp_replies;
wire [31:0] arp_fcs_errors;
wire [31:0] arp_malformed_frames;
wire [1:0] camera_rx_current_source;
wire [31:0] camera1_good_packets;
wire [31:0] camera1_good_frames;
wire [31:0] camera1_fcs_errors;
wire [31:0] camera1_ip_errors;
wire [31:0] camera1_udp_errors;
wire [31:0] camera1_header_errors;
wire [31:0] camera1_sequence_errors;
wire [31:0] camera1_offset_errors;
wire [31:0] camera1_crc_errors;
wire [31:0] camera2_good_packets;
wire [31:0] camera2_good_frames;
wire [31:0] camera2_fcs_errors;
wire [31:0] camera2_ip_errors;
wire [31:0] camera2_udp_errors;
wire [31:0] camera2_header_errors;
wire [31:0] camera2_sequence_errors;
wire [31:0] camera2_offset_errors;
wire [31:0] camera2_crc_errors;
wire [31:0] camera_rx_malformed;
wire [31:0] camera_rx_gmii_er;
wire camera_rx_stats_toggle;
wire [31:0] camera_last_header_failure;
wire [31:0] camera_last_header_identity;
wire [31:0] camera_last_header_lengths;
wire [31:0] camera_last_header_object_length;
wire port4_tx_mode_request;
wire port4_tx_mode_active;
wire port4_prbs_enable;
wire port4_prbs_tx_en;
wire port4_prbs_tx_er;
wire [7:0] port4_prbs_txd;
wire [31:0] port4_prbs_frame_sequence;
wire [31:0] port4_prbs_frame_count;
wire port4_arp_tx_en;
wire port4_arp_tx_er;
wire [7:0] port4_arp_txd;
wire port4_arp_reset_n;
wire port4_mux_tx_en;
wire port4_mux_tx_er;
wire [7:0] port4_mux_txd;

function [31:0] select_image_crc;
    input [1439:0] crc_table;
    input [15:0] object_number;
    integer bit_offset;
    begin
        if ((object_number >= 1) && (object_number <= 3)) begin
            bit_offset = (object_number - 1) * 32;
            select_image_crc = crc_table[bit_offset +: 32];
        end else begin
            select_image_crc = 32'd0;
        end
    end
endfunction

clock_gen_200_to_125 u_clock_gen (
    .sys_clk_p(sys_clk_p),
    .sys_clk_n(sys_clk_n),
    .reset_n(rst_n),
    .sys_clk_200(sys_clk_200),
    .tx_clk_125(tx_clk_125),
    .locked(clocks_locked)
);

phy_reset_controller #(
    .RESET_CYCLES(4_000_000)
) u_phy_reset (
    .clk(sys_clk_200),
    .external_reset_n(rst_n && clocks_locked),
    .phy_reset_n(phy_reset_n)
);

async_reset_sync u_sys_reset_sync (
    .clk(sys_clk_200),
    .async_reset_n(phy_reset_n),
    .sync_reset_n(sys_reset_n)
);

async_reset_sync u_tx_reset_sync (
    .clk(tx_clk_125),
    .async_reset_n(phy_reset_n),
    .sync_reset_n(tx_reset_n)
);

async_reset_sync u_rx4_reset_sync (
    .clk(e4_rxc),
    .async_reset_n(phy_reset_n),
    .sync_reset_n(rx4_reset_n)
);

assign ui_reset_n = !ui_clk_sync_rst;
assign e1_reset = phy_reset_n;
assign e2_reset = phy_reset_n;
assign e3_reset = phy_reset_n;
assign e4_reset = phy_reset_n;

smi_config #(.REF_CLK(200), .MDC_CLK(500)) u_mdio_1 (
    .clk(sys_clk_200), .rst_n(sys_reset_n),
    .mdc(e1_mdc), .mdio(e1_mdio),
    .speed(phy_speed_1), .link(phy_link_1), .led(phy_led_1)
);

smi_config #(.REF_CLK(200), .MDC_CLK(500)) u_mdio_2 (
    .clk(sys_clk_200), .rst_n(sys_reset_n),
    .mdc(e2_mdc), .mdio(e2_mdio),
    .speed(phy_speed_2), .link(phy_link_2), .led(phy_led_2)
);

smi_config #(.REF_CLK(200), .MDC_CLK(500)) u_mdio_3 (
    .clk(sys_clk_200), .rst_n(sys_reset_n),
    .mdc(e3_mdc), .mdio(e3_mdio),
    .speed(phy_speed_3), .link(phy_link_3), .led(phy_led_3)
);

smi_config #(.REF_CLK(200), .MDC_CLK(500)) u_mdio_4 (
    .clk(sys_clk_200), .rst_n(sys_reset_n),
    .mdc(e4_mdc), .mdio(e4_mdio),
    .speed(phy_speed_4), .link(phy_link_4), .led(phy_led_4)
);

sync_bits #(.WIDTH(12)) u_status_to_tx (
    .clk(tx_clk_125),
    .rst_n(tx_reset_n),
    .async_data({
        phy_link_4, phy_speed_4,
        phy_link_3, phy_speed_3,
        phy_link_2, phy_speed_2,
        phy_link_1, phy_speed_1
    }),
    .sync_data(phy_status_tx)
);

assign {
    tx_link_4, tx_speed_4,
    tx_link_3, tx_speed_3,
    tx_link_2, tx_speed_2,
    tx_link_1, tx_speed_1
} = phy_status_tx;

fixed_gigabit_tx_gate u_tx_gate_1 (
    .link(tx_link_1),
    .descriptor_ready(descriptor_ready_tx[0]),
    .enable(tx_enable_1)
);

fixed_gigabit_tx_gate u_tx_gate_2 (
    .link(tx_link_2),
    .descriptor_ready(descriptor_ready_tx[1]),
    .enable(tx_enable_2)
);

assign tx_enable_3 = tx_link_3;

memory_subsystem_wrapper u_memory_subsystem (
    .DDR3_addr(ddr3_addr),
    .DDR3_ba(ddr3_ba),
    .DDR3_cas_n(ddr3_cas_n),
    .DDR3_ck_n(ddr3_ck_n),
    .DDR3_ck_p(ddr3_ck_p),
    .DDR3_cke(ddr3_cke),
    .DDR3_cs_n(ddr3_cs_n),
    .DDR3_dm(ddr3_dm),
    .DDR3_dq(ddr3_dq),
    .DDR3_dqs_n(ddr3_dqs_n),
    .DDR3_dqs_p(ddr3_dqs_p),
    .DDR3_odt(ddr3_odt),
    .DDR3_ras_n(ddr3_ras_n),
    .DDR3_reset_n(ddr3_reset_n),
    .DDR3_we_n(ddr3_we_n),
    .S_AXI_CAMERA_araddr(camera_axi_araddr),
    .S_AXI_CAMERA_arburst(camera_axi_arburst),
    .S_AXI_CAMERA_arcache(camera_axi_arcache),
    .S_AXI_CAMERA_arid(camera_axi_arid),
    .S_AXI_CAMERA_arlen(camera_axi_arlen),
    .S_AXI_CAMERA_arlock(camera_axi_arlock[0]),
    .S_AXI_CAMERA_arprot(camera_axi_arprot),
    .S_AXI_CAMERA_arqos(camera_axi_arqos),
    .S_AXI_CAMERA_arready(camera_axi_arready),
    .S_AXI_CAMERA_arsize(camera_axi_arsize),
    .S_AXI_CAMERA_arvalid(camera_axi_arvalid),
    .S_AXI_CAMERA_awaddr(camera_axi_awaddr),
    .S_AXI_CAMERA_awburst(camera_axi_awburst),
    .S_AXI_CAMERA_awcache(camera_axi_awcache),
    .S_AXI_CAMERA_awid(camera_axi_awid),
    .S_AXI_CAMERA_awlen(camera_axi_awlen),
    .S_AXI_CAMERA_awlock(camera_axi_awlock),
    .S_AXI_CAMERA_awprot(camera_axi_awprot),
    .S_AXI_CAMERA_awqos(camera_axi_awqos),
    .S_AXI_CAMERA_awready(camera_axi_awready),
    .S_AXI_CAMERA_awsize(camera_axi_awsize),
    .S_AXI_CAMERA_awvalid(camera_axi_awvalid),
    .S_AXI_CAMERA_bid(camera_axi_bid),
    .S_AXI_CAMERA_bready(camera_axi_bready),
    .S_AXI_CAMERA_bresp(camera_axi_bresp),
    .S_AXI_CAMERA_bvalid(camera_axi_bvalid),
    .S_AXI_CAMERA_rdata(camera_axi_rdata),
    .S_AXI_CAMERA_rid(camera_axi_rid),
    .S_AXI_CAMERA_rlast(camera_axi_rlast),
    .S_AXI_CAMERA_rready(camera_axi_rready),
    .S_AXI_CAMERA_rresp(camera_axi_rresp),
    .S_AXI_CAMERA_rvalid(camera_axi_rvalid),
    .S_AXI_CAMERA_wdata(camera_axi_wdata),
    .S_AXI_CAMERA_wlast(camera_axi_wlast),
    .S_AXI_CAMERA_wready(camera_axi_wready),
    .S_AXI_CAMERA_wstrb(camera_axi_wstrb),
    .S_AXI_CAMERA_wvalid(camera_axi_wvalid),
    .S_AXI_SCHED_araddr(mem_araddr),
    .S_AXI_SCHED_arburst(mem_arburst),
    .S_AXI_SCHED_arcache(4'b0011),
    .S_AXI_SCHED_arid(1'b0),
    .S_AXI_SCHED_arlen(mem_arlen),
    .S_AXI_SCHED_arlock(1'b0),
    .S_AXI_SCHED_arprot(3'b000),
    .S_AXI_SCHED_arqos(4'b0000),
    .S_AXI_SCHED_arready(mem_arready),
    .S_AXI_SCHED_arsize(mem_arsize),
    .S_AXI_SCHED_arvalid(mem_arvalid),
    .S_AXI_SCHED_awaddr(32'd0),
    .S_AXI_SCHED_awburst(2'b01),
    .S_AXI_SCHED_awcache(4'b0000),
    .S_AXI_SCHED_awid(1'b0),
    .S_AXI_SCHED_awlen(8'd0),
    .S_AXI_SCHED_awlock(1'b0),
    .S_AXI_SCHED_awprot(3'b000),
    .S_AXI_SCHED_awqos(4'b0000),
    .S_AXI_SCHED_awready(),
    .S_AXI_SCHED_awsize(3'd3),
    .S_AXI_SCHED_awvalid(1'b0),
    .S_AXI_SCHED_bid(),
    .S_AXI_SCHED_bready(1'b1),
    .S_AXI_SCHED_bresp(),
    .S_AXI_SCHED_bvalid(),
    .S_AXI_SCHED_rdata(mem_rdata),
    .S_AXI_SCHED_rid(),
    .S_AXI_SCHED_rlast(mem_rlast),
    .S_AXI_SCHED_rready(mem_rready),
    .S_AXI_SCHED_rresp(mem_rresp),
    .S_AXI_SCHED_rvalid(mem_rvalid),
    .S_AXI_SCHED_wdata(64'd0),
    .S_AXI_SCHED_wlast(1'b0),
    .S_AXI_SCHED_wready(),
    .S_AXI_SCHED_wstrb(8'd0),
    .S_AXI_SCHED_wvalid(1'b0),
    .init_calib_complete(init_calib_complete),
    .sys_clk_i(sys_clk_200),
    .sys_rst_n(rst_n),
    .ui_clk(ui_clk),
    .ui_clk_sync_rst(ui_clk_sync_rst)
);

dual_camera_vga_axi u_dual_camera (
    .sys_clk(sys_clk_200),
    .rst_n(sys_reset_n),
    .ui_clk(ui_clk),
    .ui_clk_sync_rst(ui_clk_sync_rst),
    .init_calib_complete(init_calib_complete),
    .cmos1_scl(cmos1_scl),
    .cmos1_sda(cmos1_sda),
    .cmos1_vsync(cmos1_vsync),
    .cmos1_href(cmos1_href),
    .cmos1_pclk(cmos1_pclk),
    .cmos1_db(cmos1_db),
    .cmos1_rst_n(cmos1_rst_n),
    .cmos2_scl(cmos2_scl),
    .cmos2_sda(cmos2_sda),
    .cmos2_vsync(cmos2_vsync),
    .cmos2_href(cmos2_href),
    .cmos2_pclk(cmos2_pclk),
    .cmos2_db(cmos2_db),
    .cmos2_rst_n(cmos2_rst_n),
    .vga_out_hs(vga_out_hs),
    .vga_out_vs(vga_out_vs),
    .vga_out_r(vga_out_r),
    .vga_out_g(vga_out_g),
    .vga_out_b(vga_out_b),
    .camera1_pixel(camera1_pixel),
    .camera1_pixel_valid(camera1_pixel_valid),
    .camera2_pixel(camera2_pixel),
    .camera2_pixel_valid(camera2_pixel_valid),
    .m_axi_awid(camera_axi_awid),
    .m_axi_awaddr(camera_axi_awaddr),
    .m_axi_awlen(camera_axi_awlen),
    .m_axi_awsize(camera_axi_awsize),
    .m_axi_awburst(camera_axi_awburst),
    .m_axi_awlock(camera_axi_awlock),
    .m_axi_awcache(camera_axi_awcache),
    .m_axi_awprot(camera_axi_awprot),
    .m_axi_awqos(camera_axi_awqos),
    .m_axi_awvalid(camera_axi_awvalid),
    .m_axi_awready(camera_axi_awready),
    .m_axi_wdata(camera_axi_wdata),
    .m_axi_wstrb(camera_axi_wstrb),
    .m_axi_wlast(camera_axi_wlast),
    .m_axi_wvalid(camera_axi_wvalid),
    .m_axi_wready(camera_axi_wready),
    .m_axi_bid(camera_axi_bid),
    .m_axi_bresp(camera_axi_bresp),
    .m_axi_bvalid(camera_axi_bvalid),
    .m_axi_bready(camera_axi_bready),
    .m_axi_arid(camera_axi_arid),
    .m_axi_araddr(camera_axi_araddr),
    .m_axi_arlen(camera_axi_arlen),
    .m_axi_arsize(camera_axi_arsize),
    .m_axi_arburst(camera_axi_arburst),
    .m_axi_arlock(camera_axi_arlock),
    .m_axi_arcache(camera_axi_arcache),
    .m_axi_arprot(camera_axi_arprot),
    .m_axi_arqos(camera_axi_arqos),
    .m_axi_arvalid(camera_axi_arvalid),
    .m_axi_arready(camera_axi_arready),
    .m_axi_rid(camera_axi_rid),
    .m_axi_rdata(camera_axi_rdata),
    .m_axi_rresp(camera_axi_rresp),
    .m_axi_rlast(camera_axi_rlast),
    .m_axi_rvalid(camera_axi_rvalid),
    .m_axi_rready(camera_axi_rready)
);

axi_dataset_reader #(
    .AXI_DATA_WIDTH(64),
    .BURST_BEATS(32)
) u_dataset_reader (
    .clk(ui_clk),
    .rst_n(ui_reset_n),
    .init_calib_complete(init_calib_complete),
    .image_fifo_almost_full(image_fifo_almost_full),
    .waveform_fifo_almost_full(waveform_fifo_almost_full),
    .m_axi_araddr(mem_araddr),
    .m_axi_arlen(mem_arlen),
    .m_axi_arsize(mem_arsize),
    .m_axi_arburst(mem_arburst),
    .m_axi_arvalid(mem_arvalid),
    .m_axi_arready(mem_arready),
    .m_axi_rdata(mem_rdata),
    .m_axi_rvalid(mem_rvalid),
    .m_axi_rlast(mem_rlast),
    .m_axi_rresp(mem_rresp),
    .m_axi_rready(mem_rready),
    .image_fifo_wdata(image_fifo_wdata),
    .image_fifo_wen(image_fifo_wen),
    .waveform_fifo_wdata(waveform_fifo_wdata),
    .waveform_fifo_wen(waveform_fifo_wen),
    .image_ready(image_descriptor_ready_ui),
    .waveform_ready(waveform_descriptor_ready_ui),
    .image_crc_table(image_crc_table),
    .waveform_crc32(waveform_object_crc),
    .descriptor_read_count(descriptor_read_count),
    .read_error_count(memory_read_error_count)
);

async_byte_fifo #(
    .WRITE_WIDTH(64),
    .DEPTH_BYTES(32768),
    .ALMOST_FULL_FREE_BYTES(4096)
) u_image_fifo (
    .wr_clk(ui_clk),
    .wr_rst_n(ui_reset_n),
    .wr_data(image_fifo_wdata),
    .wr_en(image_fifo_wen),
    .wr_almost_full(image_fifo_almost_full),
    .overflow_count(image_fifo_overflow),
    .rd_clk(tx_clk_125),
    .rd_rst_n(tx_reset_n),
    .rd_data(image_fifo_data),
    .rd_en(image_fifo_read),
    .rd_empty(image_fifo_empty),
    .rd_valid(),
    .underflow_count(image_fifo_underflow)
);

async_byte_fifo #(
    .WRITE_WIDTH(64),
    .DEPTH_BYTES(32768),
    .ALMOST_FULL_FREE_BYTES(4096)
) u_waveform_fifo (
    .wr_clk(ui_clk),
    .wr_rst_n(ui_reset_n),
    .wr_data(waveform_fifo_wdata),
    .wr_en(waveform_fifo_wen),
    .wr_almost_full(waveform_fifo_almost_full),
    .overflow_count(waveform_fifo_overflow),
    .rd_clk(tx_clk_125),
    .rd_rst_n(tx_reset_n),
    .rd_data(waveform_fifo_data),
    .rd_en(waveform_fifo_read),
    .rd_empty(waveform_fifo_empty),
    .rd_valid(),
    .underflow_count(waveform_fifo_underflow)
);

sync_bits #(.WIDTH(2)) u_descriptor_ready_to_tx (
    .clk(tx_clk_125),
    .rst_n(tx_reset_n),
    .async_data({
        waveform_descriptor_ready_ui,
        image_descriptor_ready_ui
    }),
    .sync_data(descriptor_ready_tx)
);

sync_bits #(.WIDTH(1472)) u_descriptor_data_to_tx (
    .clk(tx_clk_125),
    .rst_n(tx_reset_n),
    .async_data({image_crc_table, waveform_object_crc}),
    .sync_data({image_crc_table_tx, waveform_object_crc_tx})
);

always @(posedge tx_clk_125 or negedge tx_reset_n) begin
    if (!tx_reset_n)
        descriptor_ready_tx_stable <= 2'b00;
    else
        descriptor_ready_tx_stable <= descriptor_ready_tx;
end

assign image_object_crc =
    select_image_crc(image_crc_table_tx, image_object_id);
assign waveform_packet_crc = waveform_object_crc_tx;

dataset_packet_cursor #(
    .DATASET_TYPE(8'd1),
    .SOURCE_PORT(8'd1),
    .FIRST_OBJECT_ID(16'd1),
    .LAST_OBJECT_ID(16'd3)
) u_image_cursor (
    .clk(tx_clk_125),
    .rst_n(tx_reset_n),
    .descriptor_ready(descriptor_ready_tx_stable[0]),
    .packet_advance(image_packet_advance),
    .descriptor_object_length(32'd57600),
    .descriptor_object_crc32(image_object_crc),
    .metadata_valid(image_metadata_valid),
    .dataset_type(image_type),
    .source_port(image_source_port),
    .flags(image_flags),
    .dataset_cycle(image_cycle),
    .object_id(image_object_id),
    .valid_data_bytes(image_valid_length),
    .packet_sequence(image_packet_sequence),
    .object_offset(image_object_offset),
    .object_total_length(image_object_length),
    .object_crc32()
);

dataset_packet_cursor #(
    .DATASET_TYPE(8'd2),
    .SOURCE_PORT(8'd2),
    .FIRST_OBJECT_ID(16'd1),
    .LAST_OBJECT_ID(16'd1)
) u_waveform_cursor (
    .clk(tx_clk_125),
    .rst_n(tx_reset_n),
    .descriptor_ready(descriptor_ready_tx_stable[1]),
    .packet_advance(waveform_packet_advance),
    .descriptor_object_length(32'd22400),
    .descriptor_object_crc32(waveform_packet_crc),
    .metadata_valid(waveform_metadata_valid),
    .dataset_type(waveform_type),
    .source_port(waveform_source_port),
    .flags(waveform_flags),
    .dataset_cycle(waveform_cycle),
    .object_id(waveform_object_id),
    .valid_data_bytes(waveform_valid_length),
    .packet_sequence(waveform_packet_sequence),
    .object_offset(waveform_object_offset),
    .object_total_length(waveform_object_length),
    .object_crc32()
);

dataset_tx_fifo_adapter u_image_adapter (
    .clk(tx_clk_125),
    .rst_n(tx_reset_n),
    .packet_meta_valid(image_metadata_valid),
    .packet_meta_ready(image_metadata_ready),
    .packet_valid_length(image_valid_length),
    .packet_advance(image_packet_advance),
    .fifo_empty(image_fifo_empty),
    .fifo_data(image_fifo_data),
    .fifo_read_enable(image_fifo_read),
    .packet_data_valid(image_packet_data_valid),
    .packet_data_ready(image_packet_data_ready),
    .packet_data(image_packet_data),
    .packet_data_last(image_packet_data_last)
);

dataset_tx_fifo_adapter u_waveform_adapter (
    .clk(tx_clk_125),
    .rst_n(tx_reset_n),
    .packet_meta_valid(waveform_metadata_valid),
    .packet_meta_ready(waveform_metadata_ready),
    .packet_valid_length(waveform_valid_length),
    .packet_advance(waveform_packet_advance),
    .fifo_empty(waveform_fifo_empty),
    .fifo_data(waveform_fifo_data),
    .fifo_read_enable(waveform_fifo_read),
    .packet_data_valid(waveform_packet_data_valid),
    .packet_data_ready(waveform_packet_data_ready),
    .packet_data(waveform_packet_data),
    .packet_data_last(waveform_packet_data_last)
);

dataset_udp_tx #(
    .SOURCE_MAC(48'h000A3502FEC1),
    .SOURCE_IP(32'hC0A80065),
    .DEST_IP(32'hC0A80011),
    .SOURCE_PORT_ID(8'd1),
    .STATIC_DEST_MAC(48'h000A3501FEC1),
    .USE_STATIC_DEST_MAC(1)
) u_image_tx (
    .clk(tx_clk_125),
    .rst_n(tx_reset_n),
    .enable(tx_enable_1),
    .link_up(tx_link_1),
    .clear_arp_cache(1'b0),
    .packet_meta_valid(image_metadata_valid),
    .packet_meta_ready(image_metadata_ready),
    .packet_type(image_type),
    .packet_flags(image_flags),
    .packet_cycle(image_cycle),
    .packet_object_id(image_object_id),
    .packet_valid_length(image_valid_length),
    .packet_sequence(image_packet_sequence),
    .packet_object_offset(image_object_offset),
    .packet_object_length(image_object_length),
    .packet_object_crc32(image_object_crc),
    .packet_data_valid(image_packet_data_valid),
    .packet_data_ready(image_packet_data_ready),
    .packet_data(image_packet_data),
    .packet_data_last(image_packet_data_last),
    .gmii_rx_dv(1'b0),
    .gmii_rx_er(1'b0),
    .gmii_rxd(8'd0),
    .gmii_tx_en(tx1_en_internal),
    .gmii_tx_er(tx1_er_internal),
    .gmii_txd(tx1_data_internal),
    .arp_resolved(tx1_arp_resolved),
    .resolved_mac(tx1_resolved_mac),
    .packet_sent(tx1_packet_sent),
    .arp_request_count(tx1_arp_request_count),
    .udp_packet_count(tx1_udp_packet_count),
    .input_error_count(tx1_input_error_count)
);

dataset_udp_tx #(
    .SOURCE_MAC(48'h000A3502FEC2),
    .SOURCE_IP(32'hC0A80066),
    .DEST_IP(32'hC0A80012),
    .SOURCE_PORT_ID(8'd2),
    .STATIC_DEST_MAC(48'h000A3501FEC2),
    .USE_STATIC_DEST_MAC(1)
) u_waveform_tx (
    .clk(tx_clk_125),
    .rst_n(tx_reset_n),
    .enable(tx_enable_2),
    .link_up(tx_link_2),
    .clear_arp_cache(1'b0),
    .packet_meta_valid(waveform_metadata_valid),
    .packet_meta_ready(waveform_metadata_ready),
    .packet_type(waveform_type),
    .packet_flags(waveform_flags),
    .packet_cycle(waveform_cycle),
    .packet_object_id(waveform_object_id),
    .packet_valid_length(waveform_valid_length),
    .packet_sequence(waveform_packet_sequence),
    .packet_object_offset(waveform_object_offset),
    .packet_object_length(waveform_object_length),
    .packet_object_crc32(waveform_packet_crc),
    .packet_data_valid(waveform_packet_data_valid),
    .packet_data_ready(waveform_packet_data_ready),
    .packet_data(waveform_packet_data),
    .packet_data_last(waveform_packet_data_last),
    .gmii_rx_dv(1'b0),
    .gmii_rx_er(1'b0),
    .gmii_rxd(8'd0),
    .gmii_tx_en(tx2_en_internal),
    .gmii_tx_er(tx2_er_internal),
    .gmii_txd(tx2_data_internal),
    .arp_resolved(tx2_arp_resolved),
    .resolved_mac(tx2_resolved_mac),
    .packet_sent(tx2_packet_sent),
    .arp_request_count(tx2_arp_request_count),
    .udp_packet_count(tx2_udp_packet_count),
    .input_error_count(tx2_input_error_count)
);

camera_udp_packet_source u_camera_packet_source (
    .rst_n(phy_reset_n),
    .camera1_pclk(cmos1_pclk),
    .camera1_vsync(cmos1_vsync),
    .camera1_pixel(camera1_pixel),
    .camera1_pixel_valid(camera1_pixel_valid),
    .camera2_pclk(cmos2_pclk),
    .camera2_vsync(cmos2_vsync),
    .camera2_pixel(camera2_pixel),
    .camera2_pixel_valid(camera2_pixel_valid),
    .tx_clk(tx_clk_125),
    .tx_rst_n(tx_reset_n),
    .packet_meta_valid(camera_metadata_valid),
    .packet_meta_ready(camera_metadata_ready),
    .packet_type(camera_packet_type),
    .packet_flags(camera_packet_flags),
    .packet_cycle(camera_packet_cycle),
    .packet_object_id(camera_packet_object_id),
    .packet_valid_length(camera_packet_valid_length),
    .packet_sequence(camera_packet_sequence),
    .packet_object_offset(camera_packet_offset),
    .packet_object_length(camera_packet_object_length),
    .packet_object_crc32(camera_packet_object_crc),
    .packet_data_valid(camera_packet_data_valid),
    .packet_data_ready(camera_packet_data_ready),
    .packet_data(camera_packet_data),
    .packet_data_last(camera_packet_data_last),
    .camera1_fifo_overflows(camera1_fifo_overflows),
    .camera2_fifo_overflows(camera2_fifo_overflows),
    .camera1_resyncs(camera1_resyncs),
    .camera2_resyncs(camera2_resyncs),
    .packets_issued(camera_packets_issued)
);

dataset_udp_tx #(
    .SOURCE_MAC(48'h000A3502FEC3),
    .SOURCE_IP(32'hC0A80067),
    .DEST_IP(32'hC0A80014),
    .SOURCE_PORT_ID(8'd3),
    .STATIC_DEST_MAC(48'h000A3501FEC4),
    .USE_STATIC_DEST_MAC(1)
) u_camera_tx (
    .clk(tx_clk_125),
    .rst_n(tx_reset_n),
    .enable(tx_enable_3),
    .link_up(tx_link_3),
    .clear_arp_cache(1'b0),
    .packet_meta_valid(camera_metadata_valid),
    .packet_meta_ready(camera_metadata_ready),
    .packet_type(camera_packet_type),
    .packet_flags(camera_packet_flags),
    .packet_cycle(camera_packet_cycle),
    .packet_object_id(camera_packet_object_id),
    .packet_valid_length(camera_packet_valid_length),
    .packet_sequence(camera_packet_sequence),
    .packet_object_offset(camera_packet_offset),
    .packet_object_length(camera_packet_object_length),
    .packet_object_crc32(camera_packet_object_crc),
    .packet_data_valid(camera_packet_data_valid),
    .packet_data_ready(camera_packet_data_ready),
    .packet_data(camera_packet_data),
    .packet_data_last(camera_packet_data_last),
    .gmii_rx_dv(1'b0),
    .gmii_rx_er(1'b0),
    .gmii_rxd(8'd0),
    .gmii_tx_en(tx3_en_internal),
    .gmii_tx_er(tx3_er_internal),
    .gmii_txd(tx3_data_internal),
    .arp_resolved(tx3_arp_resolved),
    .resolved_mac(tx3_resolved_mac),
    .packet_sent(tx3_packet_sent),
    .arp_request_count(tx3_arp_request_count),
    .udp_packet_count(tx3_udp_packet_count),
    .input_error_count(tx3_input_error_count)
);

always @(posedge tx_clk_125 or negedge tx_reset_n) begin
    if (!tx_reset_n) begin
        e1_txen <= 1'b0;
        e2_txen <= 1'b0;
        e1_txd <= 8'd0;
        e2_txd <= 8'd0;
    end else begin
        e1_txen <= tx1_en_internal;
        e2_txen <= tx2_en_internal;
        e1_txd <= tx1_data_internal;
        e2_txd <= tx2_data_internal;
    end
end

assign e1_txer = tx1_er_internal;
assign e2_txer = tx2_er_internal;
assign e3_txen = tx3_en_internal;
assign e3_txer = tx3_er_internal;
assign e3_txd = tx3_data_internal;

gmii_clock_forward u_gtxc_1 (
    .clk_125(tx_clk_125),
    .reset_n(tx_reset_n),
    .gmii_gtxc(e1_gtxc)
);

gmii_clock_forward u_gtxc_2 (
    .clk_125(tx_clk_125),
    .reset_n(tx_reset_n),
    .gmii_gtxc(e2_gtxc)
);

gmii_clock_forward u_gtxc_3 (
    .clk_125(tx_clk_125),
    .reset_n(tx_reset_n),
    .gmii_gtxc(e3_gtxc)
);

gmii_clock_forward u_gtxc_4 (
    .clk_125(e4_rxc),
    .reset_n(rx4_reset_n),
    .gmii_gtxc(e4_gtxc)
);

always @(posedge e4_rxc) begin
    e4_rxd_iob <= e4_rxd;
    e4_rxdv_iob <= e4_rxdv;
    e4_rxer_iob <= e4_rxer;
end

dataset_udp_rx_checker #(
    .IMAGE_OBJECT_BYTES(32'd57600),
    .IMAGE_OBJECT_COUNT(16'd3)
) u_rx_checker (
    .rx_clk(e4_rxc),
    .rst_n(rx4_reset_n),
    .gmii_rx_dv(e4_rxdv_iob),
    .gmii_rx_er(e4_rxer_iob),
    .gmii_rxd(e4_rxd_iob),
    .current_source(rx_current_source),
    .image_good_frames(image_good_frames),
    .image_good_objects(image_good_objects),
    .image_fcs_errors(image_fcs_errors),
    .image_ip_checksum_errors(image_ip_checksum_errors),
    .image_udp_checksum_errors(image_udp_checksum_errors),
    .image_header_errors(image_header_errors),
    .image_sequence_errors(image_sequence_errors),
    .image_offset_errors(image_offset_errors),
    .image_object_crc_errors(image_object_crc_errors),
    .waveform_good_frames(waveform_good_frames),
    .waveform_good_objects(waveform_good_objects),
    .waveform_fcs_errors(waveform_fcs_errors),
    .waveform_ip_checksum_errors(waveform_ip_checksum_errors),
    .waveform_udp_checksum_errors(waveform_udp_checksum_errors),
    .waveform_header_errors(waveform_header_errors),
    .waveform_sequence_errors(waveform_sequence_errors),
    .waveform_offset_errors(waveform_offset_errors),
    .waveform_object_crc_errors(waveform_object_crc_errors),
    .malformed_frames(rx_malformed_frames),
    .gmii_rx_er_frames(rx_gmii_er_frames),
    .stats_update_toggle(rx_stats_toggle)
);

camera_udp_rx_checker u_camera_rx_checker (
    .rx_clk(e4_rxc),
    .rst_n(rx4_reset_n),
    .gmii_rx_dv(e4_rxdv_iob),
    .gmii_rx_er(e4_rxer_iob),
    .gmii_rxd(e4_rxd_iob),
    .current_source(camera_rx_current_source),
    .camera1_good_frames(camera1_good_packets),
    .camera1_good_objects(camera1_good_frames),
    .camera1_fcs_errors(camera1_fcs_errors),
    .camera1_ip_checksum_errors(camera1_ip_errors),
    .camera1_udp_checksum_errors(camera1_udp_errors),
    .camera1_header_errors(camera1_header_errors),
    .camera1_sequence_errors(camera1_sequence_errors),
    .camera1_offset_errors(camera1_offset_errors),
    .camera1_object_crc_errors(camera1_crc_errors),
    .camera2_good_frames(camera2_good_packets),
    .camera2_good_objects(camera2_good_frames),
    .camera2_fcs_errors(camera2_fcs_errors),
    .camera2_ip_checksum_errors(camera2_ip_errors),
    .camera2_udp_checksum_errors(camera2_udp_errors),
    .camera2_header_errors(camera2_header_errors),
    .camera2_sequence_errors(camera2_sequence_errors),
    .camera2_offset_errors(camera2_offset_errors),
    .camera2_object_crc_errors(camera2_crc_errors),
    .malformed_frames(camera_rx_malformed),
    .gmii_rx_er_frames(camera_rx_gmii_er),
    .stats_update_toggle(camera_rx_stats_toggle),
    .last_header_failure(camera_last_header_failure),
    .last_header_identity(camera_last_header_identity),
    .last_header_lengths(camera_last_header_lengths),
    .last_header_object_length(camera_last_header_object_length)
);

assign port4_arp_reset_n = rx4_reset_n && !port4_tx_mode_active;

dual_ip_arp_responder u_arp_responder (
    .clk(e4_rxc),
    .rst_n(port4_arp_reset_n),
    .gmii_rx_dv(e4_rxdv_iob),
    .gmii_rx_er(e4_rxer_iob),
    .gmii_rxd(e4_rxd_iob),
    .gmii_tx_en(port4_arp_tx_en),
    .gmii_tx_er(port4_arp_tx_er),
    .gmii_txd(port4_arp_txd),
    .arp_requests(arp_requests),
    .arp_replies(arp_replies),
    .arp_fcs_errors(arp_fcs_errors),
    .arp_malformed_frames(arp_malformed_frames)
);

gmii_prbs31_tx #(
    .SOURCE_PORT(4)
) u_port4_prbs_tx (
    .clk(e4_rxc),
    .rst_n(rx4_reset_n),
    .enable(port4_prbs_enable),
    .gmii_tx_en(port4_prbs_tx_en),
    .gmii_tx_er(port4_prbs_tx_er),
    .gmii_txd(port4_prbs_txd),
    .frame_sequence(port4_prbs_frame_sequence),
    .frame_count(port4_prbs_frame_count)
);

port4_runtime_mode_control u_port4_mode_control (
    .clk(e4_rxc),
    .rst_n(rx4_reset_n),
    .request_tx(port4_tx_mode_request),
    .arp_tx_en(port4_arp_tx_en),
    .prbs_tx_en(port4_prbs_tx_en),
    .active_tx_mode(port4_tx_mode_active),
    .prbs_enable(port4_prbs_enable)
);

port4_gmii_tx_mux u_port4_tx_mux (
    .select_prbs(port4_tx_mode_active),
    .arp_tx_en(port4_arp_tx_en),
    .arp_tx_er(port4_arp_tx_er),
    .arp_txd(port4_arp_txd),
    .prbs_tx_en(port4_prbs_tx_en),
    .prbs_tx_er(port4_prbs_tx_er),
    .prbs_txd(port4_prbs_txd),
    .gmii_tx_en(port4_mux_tx_en),
    .gmii_tx_er(port4_mux_tx_er),
    .gmii_txd(port4_mux_txd)
);

gmii_tx_output_register u_port4_tx_output (
    .clk(e4_rxc),
    .rst_n(rx4_reset_n),
    .input_tx_en(port4_mux_tx_en),
    .input_tx_er(port4_mux_tx_er),
    .input_txd(port4_mux_txd),
    .output_tx_en(e4_txen),
    .output_tx_er(e4_txer),
    .output_txd(e4_txd)
);

vio_port4_mode u_vio_port4_mode (
    .clk(e4_rxc),
    .probe_in0(port4_tx_mode_active),
    .probe_in1(port4_prbs_frame_count),
    .probe_out0(port4_tx_mode_request)
);

assign led[0] = init_calib_complete;
assign led[1] = descriptor_ready_tx[0] && descriptor_ready_tx[1];

ila_dataset_rx u_ila_dataset_rx (
    .clk(e4_rxc),
    .probe0(rx_current_source),
    .probe1(image_good_frames),
    .probe2(image_good_objects),
    .probe3(image_fcs_errors),
    .probe4(image_ip_checksum_errors),
    .probe5(image_udp_checksum_errors),
    .probe6(image_header_errors),
    .probe7(image_sequence_errors),
    .probe8(image_offset_errors),
    .probe9(image_object_crc_errors),
    .probe10(waveform_good_frames),
    .probe11(waveform_good_objects),
    .probe12(waveform_fcs_errors),
    .probe13(waveform_ip_checksum_errors),
    .probe14(waveform_udp_checksum_errors),
    .probe15(waveform_header_errors),
    .probe16(waveform_sequence_errors),
    .probe17(waveform_offset_errors),
    .probe18(waveform_object_crc_errors),
    .probe19({
        arp_malformed_frames,
        arp_fcs_errors,
        arp_replies,
        arp_requests,
        rx_gmii_er_frames,
        rx_malformed_frames
    })
);

ila_dataset_tx u_ila_dataset_tx (
    .clk(tx_clk_125),
    .probe0(descriptor_ready_tx),
    .probe1(tx1_udp_packet_count),
    .probe2(tx2_udp_packet_count),
    .probe3(tx1_input_error_count),
    .probe4(tx2_input_error_count),
    .probe5(image_fifo_underflow),
    .probe6(waveform_fifo_underflow),
    .probe7({
        tx_enable_1,
        tx_link_1,
        tx_speed_1
    })
);

ila_dataset_mem u_ila_dataset_mem (
    .clk(ui_clk),
    .probe0(init_calib_complete),
    .probe1({
        waveform_descriptor_ready_ui,
        image_descriptor_ready_ui
    }),
    .probe2(descriptor_read_count),
    .probe3(memory_read_error_count),
    .probe4(image_fifo_overflow),
    .probe5(waveform_fifo_overflow)
);

gray_counter_cdc #(.WIDTH(32)) u_camera1_fifo_overflows_cdc (
    .src_clk(cmos1_pclk),
    .src_rst_n(phy_reset_n),
    .src_binary(camera1_fifo_overflows),
    .dst_clk(e4_rxc),
    .dst_rst_n(rx4_reset_n),
    .dst_binary(camera1_fifo_overflows_rx)
);

gray_counter_cdc #(.WIDTH(32)) u_camera2_fifo_overflows_cdc (
    .src_clk(cmos2_pclk),
    .src_rst_n(phy_reset_n),
    .src_binary(camera2_fifo_overflows),
    .dst_clk(e4_rxc),
    .dst_rst_n(rx4_reset_n),
    .dst_binary(camera2_fifo_overflows_rx)
);

gray_counter_cdc #(.WIDTH(32)) u_tx3_udp_packet_count_cdc (
    .src_clk(tx_clk_125),
    .src_rst_n(tx_reset_n),
    .src_binary(tx3_udp_packet_count),
    .dst_clk(e4_rxc),
    .dst_rst_n(rx4_reset_n),
    .dst_binary(tx3_udp_packet_count_rx)
);

gray_counter_cdc #(.WIDTH(32)) u_camera_packets_issued_cdc (
    .src_clk(tx_clk_125),
    .src_rst_n(tx_reset_n),
    .src_binary(camera_packets_issued),
    .dst_clk(e4_rxc),
    .dst_rst_n(rx4_reset_n),
    .dst_binary(camera_packets_issued_rx)
);

ila_camera u_ila_camera (
    .clk(e4_rxc),
    .probe0(camera_rx_current_source),
    .probe1(camera1_good_packets),
    .probe2(camera1_good_frames),
    .probe3(camera1_fcs_errors),
    .probe4(camera1_ip_errors),
    .probe5(camera1_udp_errors),
    .probe6(camera1_header_errors),
    .probe7(camera1_sequence_errors),
    .probe8(camera1_offset_errors),
    .probe9(camera1_crc_errors),
    .probe10(camera2_good_packets),
    .probe11(camera2_good_frames),
    .probe12(camera2_fcs_errors),
    .probe13(camera2_ip_errors),
    .probe14(camera2_udp_errors),
    .probe15(camera2_header_errors),
    .probe16(camera2_sequence_errors),
    .probe17(camera2_offset_errors),
    .probe18(camera2_crc_errors),
    .probe19({
        camera_rx_gmii_er,
        camera_rx_malformed,
        camera2_fifo_overflows_rx,
        camera1_fifo_overflows_rx,
        tx3_udp_packet_count_rx,
        camera_packets_issued_rx
    }),
    .probe20(camera_last_header_failure),
    .probe21(camera_last_header_identity),
    .probe22(camera_last_header_lengths),
    .probe23(camera_last_header_object_length)
);

endmodule
