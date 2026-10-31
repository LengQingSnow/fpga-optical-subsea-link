//Copyright 1986-2021 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2021.2 (win64) Build 3367213 Tue Oct 19 02:48:09 MDT 2021
//Date        : Sat Jul 25 10:44:26 2026
//Host        : LAPTOP-KMF3OJ9O running 64-bit major release  (build 9200)
//Command     : generate_target memory_subsystem_wrapper.bd
//Design      : memory_subsystem_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module memory_subsystem_wrapper
   (DDR3_addr,
    DDR3_ba,
    DDR3_cas_n,
    DDR3_ck_n,
    DDR3_ck_p,
    DDR3_cke,
    DDR3_cs_n,
    DDR3_dm,
    DDR3_dq,
    DDR3_dqs_n,
    DDR3_dqs_p,
    DDR3_odt,
    DDR3_ras_n,
    DDR3_reset_n,
    DDR3_we_n,
    S_AXI_SCHED_araddr,
    S_AXI_SCHED_arburst,
    S_AXI_SCHED_arcache,
    S_AXI_SCHED_arid,
    S_AXI_SCHED_arlen,
    S_AXI_SCHED_arlock,
    S_AXI_SCHED_arprot,
    S_AXI_SCHED_arqos,
    S_AXI_SCHED_arready,
    S_AXI_SCHED_arsize,
    S_AXI_SCHED_arvalid,
    S_AXI_SCHED_awaddr,
    S_AXI_SCHED_awburst,
    S_AXI_SCHED_awcache,
    S_AXI_SCHED_awid,
    S_AXI_SCHED_awlen,
    S_AXI_SCHED_awlock,
    S_AXI_SCHED_awprot,
    S_AXI_SCHED_awqos,
    S_AXI_SCHED_awready,
    S_AXI_SCHED_awsize,
    S_AXI_SCHED_awvalid,
    S_AXI_SCHED_bid,
    S_AXI_SCHED_bready,
    S_AXI_SCHED_bresp,
    S_AXI_SCHED_bvalid,
    S_AXI_SCHED_rdata,
    S_AXI_SCHED_rid,
    S_AXI_SCHED_rlast,
    S_AXI_SCHED_rready,
    S_AXI_SCHED_rresp,
    S_AXI_SCHED_rvalid,
    S_AXI_SCHED_wdata,
    S_AXI_SCHED_wlast,
    S_AXI_SCHED_wready,
    S_AXI_SCHED_wstrb,
    S_AXI_SCHED_wvalid,
    init_calib_complete,
    sys_clk_i,
    sys_rst_n,
    ui_clk,
    ui_clk_sync_rst);
  output [14:0]DDR3_addr;
  output [2:0]DDR3_ba;
  output DDR3_cas_n;
  output [0:0]DDR3_ck_n;
  output [0:0]DDR3_ck_p;
  output [0:0]DDR3_cke;
  output [0:0]DDR3_cs_n;
  output [3:0]DDR3_dm;
  inout [31:0]DDR3_dq;
  inout [3:0]DDR3_dqs_n;
  inout [3:0]DDR3_dqs_p;
  output [0:0]DDR3_odt;
  output DDR3_ras_n;
  output DDR3_reset_n;
  output DDR3_we_n;
  input [31:0]S_AXI_SCHED_araddr;
  input [1:0]S_AXI_SCHED_arburst;
  input [3:0]S_AXI_SCHED_arcache;
  input [0:0]S_AXI_SCHED_arid;
  input [7:0]S_AXI_SCHED_arlen;
  input [0:0]S_AXI_SCHED_arlock;
  input [2:0]S_AXI_SCHED_arprot;
  input [3:0]S_AXI_SCHED_arqos;
  output S_AXI_SCHED_arready;
  input [2:0]S_AXI_SCHED_arsize;
  input S_AXI_SCHED_arvalid;
  input [31:0]S_AXI_SCHED_awaddr;
  input [1:0]S_AXI_SCHED_awburst;
  input [3:0]S_AXI_SCHED_awcache;
  input [0:0]S_AXI_SCHED_awid;
  input [7:0]S_AXI_SCHED_awlen;
  input [0:0]S_AXI_SCHED_awlock;
  input [2:0]S_AXI_SCHED_awprot;
  input [3:0]S_AXI_SCHED_awqos;
  output S_AXI_SCHED_awready;
  input [2:0]S_AXI_SCHED_awsize;
  input S_AXI_SCHED_awvalid;
  output [0:0]S_AXI_SCHED_bid;
  input S_AXI_SCHED_bready;
  output [1:0]S_AXI_SCHED_bresp;
  output S_AXI_SCHED_bvalid;
  output [63:0]S_AXI_SCHED_rdata;
  output [0:0]S_AXI_SCHED_rid;
  output S_AXI_SCHED_rlast;
  input S_AXI_SCHED_rready;
  output [1:0]S_AXI_SCHED_rresp;
  output S_AXI_SCHED_rvalid;
  input [63:0]S_AXI_SCHED_wdata;
  input S_AXI_SCHED_wlast;
  output S_AXI_SCHED_wready;
  input [7:0]S_AXI_SCHED_wstrb;
  input S_AXI_SCHED_wvalid;
  output init_calib_complete;
  input sys_clk_i;
  input sys_rst_n;
  output ui_clk;
  output ui_clk_sync_rst;

  wire [14:0]DDR3_addr;
  wire [2:0]DDR3_ba;
  wire DDR3_cas_n;
  wire [0:0]DDR3_ck_n;
  wire [0:0]DDR3_ck_p;
  wire [0:0]DDR3_cke;
  wire [0:0]DDR3_cs_n;
  wire [3:0]DDR3_dm;
  wire [31:0]DDR3_dq;
  wire [3:0]DDR3_dqs_n;
  wire [3:0]DDR3_dqs_p;
  wire [0:0]DDR3_odt;
  wire DDR3_ras_n;
  wire DDR3_reset_n;
  wire DDR3_we_n;
  wire [31:0]S_AXI_SCHED_araddr;
  wire [1:0]S_AXI_SCHED_arburst;
  wire [3:0]S_AXI_SCHED_arcache;
  wire [0:0]S_AXI_SCHED_arid;
  wire [7:0]S_AXI_SCHED_arlen;
  wire [0:0]S_AXI_SCHED_arlock;
  wire [2:0]S_AXI_SCHED_arprot;
  wire [3:0]S_AXI_SCHED_arqos;
  wire S_AXI_SCHED_arready;
  wire [2:0]S_AXI_SCHED_arsize;
  wire S_AXI_SCHED_arvalid;
  wire [31:0]S_AXI_SCHED_awaddr;
  wire [1:0]S_AXI_SCHED_awburst;
  wire [3:0]S_AXI_SCHED_awcache;
  wire [0:0]S_AXI_SCHED_awid;
  wire [7:0]S_AXI_SCHED_awlen;
  wire [0:0]S_AXI_SCHED_awlock;
  wire [2:0]S_AXI_SCHED_awprot;
  wire [3:0]S_AXI_SCHED_awqos;
  wire S_AXI_SCHED_awready;
  wire [2:0]S_AXI_SCHED_awsize;
  wire S_AXI_SCHED_awvalid;
  wire [0:0]S_AXI_SCHED_bid;
  wire S_AXI_SCHED_bready;
  wire [1:0]S_AXI_SCHED_bresp;
  wire S_AXI_SCHED_bvalid;
  wire [63:0]S_AXI_SCHED_rdata;
  wire [0:0]S_AXI_SCHED_rid;
  wire S_AXI_SCHED_rlast;
  wire S_AXI_SCHED_rready;
  wire [1:0]S_AXI_SCHED_rresp;
  wire S_AXI_SCHED_rvalid;
  wire [63:0]S_AXI_SCHED_wdata;
  wire S_AXI_SCHED_wlast;
  wire S_AXI_SCHED_wready;
  wire [7:0]S_AXI_SCHED_wstrb;
  wire S_AXI_SCHED_wvalid;
  wire init_calib_complete;
  wire sys_clk_i;
  wire sys_rst_n;
  wire ui_clk;
  wire ui_clk_sync_rst;

  memory_subsystem memory_subsystem_i
       (.DDR3_addr(DDR3_addr),
        .DDR3_ba(DDR3_ba),
        .DDR3_cas_n(DDR3_cas_n),
        .DDR3_ck_n(DDR3_ck_n),
        .DDR3_ck_p(DDR3_ck_p),
        .DDR3_cke(DDR3_cke),
        .DDR3_cs_n(DDR3_cs_n),
        .DDR3_dm(DDR3_dm),
        .DDR3_dq(DDR3_dq),
        .DDR3_dqs_n(DDR3_dqs_n),
        .DDR3_dqs_p(DDR3_dqs_p),
        .DDR3_odt(DDR3_odt),
        .DDR3_ras_n(DDR3_ras_n),
        .DDR3_reset_n(DDR3_reset_n),
        .DDR3_we_n(DDR3_we_n),
        .S_AXI_SCHED_araddr(S_AXI_SCHED_araddr),
        .S_AXI_SCHED_arburst(S_AXI_SCHED_arburst),
        .S_AXI_SCHED_arcache(S_AXI_SCHED_arcache),
        .S_AXI_SCHED_arid(S_AXI_SCHED_arid),
        .S_AXI_SCHED_arlen(S_AXI_SCHED_arlen),
        .S_AXI_SCHED_arlock(S_AXI_SCHED_arlock),
        .S_AXI_SCHED_arprot(S_AXI_SCHED_arprot),
        .S_AXI_SCHED_arqos(S_AXI_SCHED_arqos),
        .S_AXI_SCHED_arready(S_AXI_SCHED_arready),
        .S_AXI_SCHED_arsize(S_AXI_SCHED_arsize),
        .S_AXI_SCHED_arvalid(S_AXI_SCHED_arvalid),
        .S_AXI_SCHED_awaddr(S_AXI_SCHED_awaddr),
        .S_AXI_SCHED_awburst(S_AXI_SCHED_awburst),
        .S_AXI_SCHED_awcache(S_AXI_SCHED_awcache),
        .S_AXI_SCHED_awid(S_AXI_SCHED_awid),
        .S_AXI_SCHED_awlen(S_AXI_SCHED_awlen),
        .S_AXI_SCHED_awlock(S_AXI_SCHED_awlock),
        .S_AXI_SCHED_awprot(S_AXI_SCHED_awprot),
        .S_AXI_SCHED_awqos(S_AXI_SCHED_awqos),
        .S_AXI_SCHED_awready(S_AXI_SCHED_awready),
        .S_AXI_SCHED_awsize(S_AXI_SCHED_awsize),
        .S_AXI_SCHED_awvalid(S_AXI_SCHED_awvalid),
        .S_AXI_SCHED_bid(S_AXI_SCHED_bid),
        .S_AXI_SCHED_bready(S_AXI_SCHED_bready),
        .S_AXI_SCHED_bresp(S_AXI_SCHED_bresp),
        .S_AXI_SCHED_bvalid(S_AXI_SCHED_bvalid),
        .S_AXI_SCHED_rdata(S_AXI_SCHED_rdata),
        .S_AXI_SCHED_rid(S_AXI_SCHED_rid),
        .S_AXI_SCHED_rlast(S_AXI_SCHED_rlast),
        .S_AXI_SCHED_rready(S_AXI_SCHED_rready),
        .S_AXI_SCHED_rresp(S_AXI_SCHED_rresp),
        .S_AXI_SCHED_rvalid(S_AXI_SCHED_rvalid),
        .S_AXI_SCHED_wdata(S_AXI_SCHED_wdata),
        .S_AXI_SCHED_wlast(S_AXI_SCHED_wlast),
        .S_AXI_SCHED_wready(S_AXI_SCHED_wready),
        .S_AXI_SCHED_wstrb(S_AXI_SCHED_wstrb),
        .S_AXI_SCHED_wvalid(S_AXI_SCHED_wvalid),
        .init_calib_complete(init_calib_complete),
        .sys_clk_i(sys_clk_i),
        .sys_rst_n(sys_rst_n),
        .ui_clk(ui_clk),
        .ui_clk_sync_rst(ui_clk_sync_rst));
endmodule
