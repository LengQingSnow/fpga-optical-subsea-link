`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/08/09 00:38:59
// Design Name: 
// Module Name: adaloop_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module adaloop_top(
//global clock
input           pl_clk_n,
input           pl_clk_p,
input           pl_sysref_n,
input           pl_sysref_p,

//rf signal
input           adc1_clk_n,
input           adc1_clk_p,
input           dac2_clk_n,
input           dac2_clk_p,
input           sysref_in_n,
input           sysref_in_p,

input           vin0_01_n,
input           vin0_01_p,
input           vin0_23_n,
input           vin0_23_p,
input           vin1_01_n,
input           vin1_01_p,
input           vin1_23_n,
input           vin1_23_p,
input           vin2_01_n,
input           vin2_01_p,
input           vin2_23_n,
input           vin2_23_p,
input           vin3_01_n,
input           vin3_01_p,
input           vin3_23_n,
input           vin3_23_p,
output          vout00_n,
output          vout00_p,
output          vout02_n,
output          vout02_p,
output          vout10_n,
output          vout10_p,
output          vout12_n,
output          vout12_p,
output          vout20_n,
output          vout20_p,
output          vout22_n,
output          vout22_p,
output          vout30_n,
output          vout30_p,
output          vout32_n,
output          vout32_p,

//
inout           lmk_sync,
output [3:0]    led,
output          user_io7,
output          user_io6,
output          user_io5,
output          user_io4,
inout  [3:0]    user_io,
inout           trig_out,
input           trig_in,
input           gps_1pps,
input           txd_gps
);


    wire [63:0]     m00_axis_tdata;
    wire            m00_axis_tready=1'b1;
    wire            m00_axis_tvalid;
    wire [63:0]     m01_axis_tdata;
    wire            m01_axis_tready=1'b1;
    wire            m01_axis_tvalid;
    wire [63:0]     m02_axis_tdata;
    wire            m02_axis_tready=1'b1;
    wire            m02_axis_tvalid;
    wire [63:0]     m03_axis_tdata;
    wire            m03_axis_tready=1'b1;
    wire            m03_axis_tvalid;
    wire [63:0]     m10_axis_tdata;
    wire            m10_axis_tready=1'b1;
    wire            m10_axis_tvalid;
    wire [63:0]     m11_axis_tdata;
    wire            m11_axis_tready=1'b1;
    wire            m11_axis_tvalid;
    wire [63:0]     m12_axis_tdata;
    wire            m12_axis_tready=1'b1;
    wire            m12_axis_tvalid;
    wire [63:0]     m13_axis_tdata;
    wire            m13_axis_tready=1'b1;
    wire            m13_axis_tvalid;
    wire [63:0]     m20_axis_tdata;
    wire            m20_axis_tready=1'b1;
    wire            m20_axis_tvalid;
    wire [63:0]     m21_axis_tdata;
    wire            m21_axis_tready=1'b1;
    wire            m21_axis_tvalid;
    wire [63:0]     m22_axis_tdata;
    wire            m22_axis_tready=1'b1;
    wire            m22_axis_tvalid;
    wire [63:0]     m23_axis_tdata;
    wire            m23_axis_tready=1'b1;
    wire            m23_axis_tvalid;
    wire [63:0]     m30_axis_tdata;
    wire            m30_axis_tready=1'b1;
    wire            m30_axis_tvalid;
    wire [63:0]     m31_axis_tdata;
    wire            m31_axis_tready=1'b1;
    wire            m31_axis_tvalid;
    wire [63:0]     m32_axis_tdata;
    wire            m32_axis_tready=1'b1;
    wire            m32_axis_tvalid;
    wire [63:0]     m33_axis_tdata;
    wire            m33_axis_tready=1'b1;
    wire            m33_axis_tvalid;
    wire [127:0]    s00_axis_tdata;
    wire            s00_axis_tready;
    wire            s00_axis_tvalid;
    wire [127:0]    s02_axis_tdata;
    wire            s02_axis_tready;
    wire            s02_axis_tvalid;
    wire [127:0]    s10_axis_tdata;
    wire            s10_axis_tready;
    wire            s10_axis_tvalid;
    wire [127:0]    s12_axis_tdata;
    wire            s12_axis_tready;
    wire            s12_axis_tvalid;
    wire [127:0]    s20_axis_tdata;
    wire            s20_axis_tready;
    wire            s20_axis_tvalid;
    wire [127:0]    s22_axis_tdata;
    wire            s22_axis_tready;
    wire            s22_axis_tvalid;
    wire [127:0]    s30_axis_tdata;
    wire            s30_axis_tready;
    wire            s30_axis_tvalid;
    wire [127:0]    s32_axis_tdata;
    wire            s32_axis_tready;
    wire            s32_axis_tvalid;
// Local Parameters derived from user selection
localparam C_NUM_CHNL         = 8;
wire                      fclk_100m;
reg  [C_NUM_CHNL*128-1:0] dac_tdata;
wire [C_NUM_CHNL-1:0]     dac_tvalid=8'hff;
wire [C_NUM_CHNL-1:0]     dac_tready;
wire [C_NUM_CHNL*2-1:0]   adc_tvalid;
wire [C_NUM_CHNL-1:0]     adc_tready=8'hff;
wire [C_NUM_CHNL*64-1:0]  adc_tdata_i;
wire [C_NUM_CHNL*64-1:0]  adc_tdata_q;

wire [15:0]                   gpio_tri_i;
wire [15:0]                   gpio_tri_o;
wire [15:0]                   gpio_tri_t;
wire [ 6:0]                   axi_rd_addr;
wire [ 6:0]                   axi_wr_addr;
wire [31:0]                   axi_rd_data;
wire [31:0]                   axi_wr_data;
wire [7:0]                    adc_freeze;
wire [7:0]                    adc_clear_ov;
wire [7:0]                    adc_over_volt;

assign adc_tdata_i[64*0+:64] = m00_axis_tdata;
assign adc_tdata_q[64*0+:64] = m01_axis_tdata;
assign adc_tdata_i[64*1+:64] = m02_axis_tdata;
assign adc_tdata_q[64*1+:64] = m03_axis_tdata;
assign adc_tdata_i[64*2+:64] = m10_axis_tdata;
assign adc_tdata_q[64*2+:64] = m11_axis_tdata;
assign adc_tdata_i[64*3+:64] = m12_axis_tdata;
assign adc_tdata_q[64*3+:64] = m13_axis_tdata;
assign adc_tdata_i[64*4+:64] = m20_axis_tdata;
assign adc_tdata_q[64*4+:64] = m21_axis_tdata;
assign adc_tdata_i[64*5+:64] = m22_axis_tdata;
assign adc_tdata_q[64*5+:64] = m23_axis_tdata;
assign adc_tdata_i[64*6+:64] = m30_axis_tdata;
assign adc_tdata_q[64*6+:64] = m31_axis_tdata;
assign adc_tdata_i[64*7+:64] = m32_axis_tdata;
assign adc_tdata_q[64*7+:64] = m33_axis_tdata;

assign adc_tvalid[ 3:0]  = {m03_axis_tvalid,m02_axis_tvalid,m01_axis_tvalid,m00_axis_tvalid};
assign adc_tvalid[ 7:4]  = {m13_axis_tvalid,m12_axis_tvalid,m11_axis_tvalid,m10_axis_tvalid};
assign adc_tvalid[11:8]  = {m23_axis_tvalid,m22_axis_tvalid,m21_axis_tvalid,m20_axis_tvalid};
assign adc_tvalid[15:12] = {m33_axis_tvalid,m32_axis_tvalid,m31_axis_tvalid,m30_axis_tvalid};

assign s00_axis_tdata = dac_tdata[128*0+:128];
assign s02_axis_tdata = dac_tdata[128*1+:128];
assign s10_axis_tdata = dac_tdata[128*2+:128];
assign s12_axis_tdata = dac_tdata[128*3+:128];
assign s20_axis_tdata = dac_tdata[128*4+:128];
assign s22_axis_tdata = dac_tdata[128*5+:128];
assign s30_axis_tdata = dac_tdata[128*6+:128];
assign s32_axis_tdata = dac_tdata[128*7+:128];

assign s00_axis_tvalid = dac_tvalid[0];
assign s02_axis_tvalid = dac_tvalid[1];
assign s10_axis_tvalid = dac_tvalid[2];
assign s12_axis_tvalid = dac_tvalid[3];
assign s20_axis_tvalid = dac_tvalid[4];
assign s22_axis_tvalid = dac_tvalid[5];
assign s30_axis_tvalid = dac_tvalid[6];
assign s32_axis_tvalid = dac_tvalid[7];

assign dac_tready[0] = s00_axis_tready;
assign dac_tready[1] = s02_axis_tready;
assign dac_tready[2] = s10_axis_tready;
assign dac_tready[3] = s12_axis_tready;
assign dac_tready[4] = s20_axis_tready;
assign dac_tready[5] = s22_axis_tready;
assign dac_tready[6] = s30_axis_tready;
assign dac_tready[7] = s32_axis_tready;

reg            user_sysref_adc;
reg            user_sysref_dac;

  wire          up_rack;
  wire [15:0]   up_raddr;
  wire [31:0]   up_rdata;
  wire          up_rreq;
  wire          up_wack;
  wire [15:0]   up_waddr;
  wire [31:0]   up_wdata;
  wire          up_wreq;
    
system system_i(
    .GPIO0_tri_i        (gpio_tri_i),
    .GPIO0_tri_o        (gpio_tri_o),
    .GPIO0_tri_t        (gpio_tri_t),
    .adc1_clk_clk_n     (adc1_clk_n),
    .adc1_clk_clk_p     (adc1_clk_p),
    .dac2_clk_clk_n     (dac2_clk_n),
    .dac2_clk_clk_p     (dac2_clk_p),
    .data_clk           (data_clk),
    .pl_resetn0         (fclk_reset0),
    .m00_axis_tdata     (m00_axis_tdata),
    .m00_axis_tready    (m00_axis_tready),
    .m00_axis_tvalid    (m00_axis_tvalid),
    .m01_axis_tdata     (m01_axis_tdata),
    .m01_axis_tready    (m01_axis_tready),
    .m01_axis_tvalid    (m01_axis_tvalid),
    .m02_axis_tdata     (m02_axis_tdata),
    .m02_axis_tready    (m02_axis_tready),
    .m02_axis_tvalid    (m02_axis_tvalid),
    .m03_axis_tdata     (m03_axis_tdata),
    .m03_axis_tready    (m03_axis_tready),
    .m03_axis_tvalid    (m03_axis_tvalid),
    .m10_axis_tdata     (m10_axis_tdata),
    .m10_axis_tready    (m10_axis_tready),
    .m10_axis_tvalid    (m10_axis_tvalid),
    .m11_axis_tdata     (m11_axis_tdata),
    .m11_axis_tready    (m11_axis_tready),
    .m11_axis_tvalid    (m11_axis_tvalid),
    .m12_axis_tdata     (m12_axis_tdata),
    .m12_axis_tready    (m12_axis_tready),
    .m12_axis_tvalid    (m12_axis_tvalid),
    .m13_axis_tdata     (m13_axis_tdata),
    .m13_axis_tready    (m13_axis_tready),
    .m13_axis_tvalid    (m13_axis_tvalid),
    .m20_axis_tdata     (m20_axis_tdata),
    .m20_axis_tready    (m20_axis_tready),
    .m20_axis_tvalid    (m20_axis_tvalid),
    .m21_axis_tdata     (m21_axis_tdata),
    .m21_axis_tready    (m21_axis_tready),
    .m21_axis_tvalid    (m21_axis_tvalid),
    .m22_axis_tdata     (m22_axis_tdata),
    .m22_axis_tready    (m22_axis_tready),
    .m22_axis_tvalid    (m22_axis_tvalid),
    .m23_axis_tdata     (m23_axis_tdata),
    .m23_axis_tready    (m23_axis_tready),
    .m23_axis_tvalid    (m23_axis_tvalid),
    .m30_axis_tdata     (m30_axis_tdata),
    .m30_axis_tready    (m30_axis_tready),
    .m30_axis_tvalid    (m30_axis_tvalid),
    .m31_axis_tdata     (m31_axis_tdata),
    .m31_axis_tready    (m31_axis_tready),
    .m31_axis_tvalid    (m31_axis_tvalid),
    .m32_axis_tdata     (m32_axis_tdata),
    .m32_axis_tready    (m32_axis_tready),
    .m32_axis_tvalid    (m32_axis_tvalid),
    .m33_axis_tdata     (m33_axis_tdata),
    .m33_axis_tready    (m33_axis_tready),
    .m33_axis_tvalid    (m33_axis_tvalid),
    .s00_axis_tdata     (s00_axis_tdata),
    .s00_axis_tready    (s00_axis_tready),
    .s00_axis_tvalid    (s00_axis_tvalid),
    .s02_axis_tdata     (s02_axis_tdata),
    .s02_axis_tready    (s02_axis_tready),
    .s02_axis_tvalid    (s02_axis_tvalid),
    .s10_axis_tdata     (s10_axis_tdata),
    .s10_axis_tready    (s10_axis_tready),
    .s10_axis_tvalid    (s10_axis_tvalid),
    .s12_axis_tdata     (s12_axis_tdata),
    .s12_axis_tready    (s12_axis_tready),
    .s12_axis_tvalid    (s12_axis_tvalid),
    .s20_axis_tdata     (s20_axis_tdata),
    .s20_axis_tready    (s20_axis_tready),
    .s20_axis_tvalid    (s20_axis_tvalid),
    .s22_axis_tdata     (s22_axis_tdata),
    .s22_axis_tready    (s22_axis_tready),
    .s22_axis_tvalid    (s22_axis_tvalid),
    .s30_axis_tdata     (s30_axis_tdata),
    .s30_axis_tready    (s30_axis_tready),
    .s30_axis_tvalid    (s30_axis_tvalid),
    .s32_axis_tdata     (s32_axis_tdata),
    .s32_axis_tready    (s32_axis_tready),
    .s32_axis_tvalid    (s32_axis_tvalid),
    .sysref_in_diff_n   (sysref_in_n),
    .sysref_in_diff_p   (sysref_in_p),
    .fclk_100m          (fclk_100m),
    .up_rack            (up_rack),
    .up_raddr           (up_raddr),
    .up_rdata           (up_rdata),
    .up_rreq            (up_rreq),
    .up_wack            (up_wack),
    .up_waddr           (up_waddr),
    .up_wdata           (up_wdata),
    .up_wreq            (up_wreq),
    .user_sysref_adc_0  (user_sysref_adc),
    .user_sysref_dac_0  (user_sysref_dac),
    .vin0_01_v_n        (vin0_01_n),
    .vin0_01_v_p        (vin0_01_p),
    .vin0_23_v_n        (vin0_23_n),
    .vin0_23_v_p        (vin0_23_p),
    .vin1_01_v_n        (vin1_01_n),
    .vin1_01_v_p        (vin1_01_p),
    .vin1_23_v_n        (vin1_23_n),
    .vin1_23_v_p        (vin1_23_p),
    .vin2_01_v_n        (vin2_01_n),
    .vin2_01_v_p        (vin2_01_p),
    .vin2_23_v_n        (vin2_23_n),
    .vin2_23_v_p        (vin2_23_p),
    .vin3_01_v_n        (vin3_01_n),
    .vin3_01_v_p        (vin3_01_p),
    .vin3_23_v_n        (vin3_23_n),
    .vin3_23_v_p        (vin3_23_p),
    .vout00_v_n         (vout00_n),
    .vout00_v_p         (vout00_p),
    .vout02_v_n         (vout02_n),
    .vout02_v_p         (vout02_p),
    .vout10_v_n         (vout10_n),
    .vout10_v_p         (vout10_p),
    .vout12_v_n         (vout12_n),
    .vout12_v_p         (vout12_p),
    .vout20_v_n         (vout20_n),
    .vout20_v_p         (vout20_p),
    .vout22_v_n         (vout22_n),
    .vout22_v_p         (vout22_p),
    .vout30_v_n         (vout30_n),
    .vout30_v_p         (vout30_p),
    .vout32_v_n         (vout32_n),
    .vout32_v_p         (vout32_p)
);

// Multi-tile sync logic
  IBUFDS pl_clk_i (
    .I          (pl_clk_p),
    .IB         (pl_clk_n),
    .O          (pl_clk));

  IBUFDS pl_sysref_i (
    .I          (pl_sysref_p),
    .IB         (pl_sysref_n),
    .O          (pl_sysref));

  reg pl_sysref_r;  
  always @(posedge pl_clk) begin
    pl_sysref_r <= pl_sysref;
  end

  always @(posedge pl_clk) begin
    user_sysref_adc <= pl_sysref_r;
  end

  always @(posedge pl_clk) begin
    user_sysref_dac <= pl_sysref_r;
  end

//gpio
ad_iobuf #(.DATA_WIDTH(7)) i_iobuf (
.dio_t (gpio_tri_t[6:0]),
.dio_i (gpio_tri_o[6:0]),
.dio_o (gpio_tri_i[6:0]),
.dio_p ({
user_io       ,//6:3
fddtdd_sw     ,//2
trx_sw_ps     ,//1
lmk_sync       //0
}));
assign rf1_fddtdd_sw = gpio_tri_o[2];
assign rf2_fddtdd_sw = gpio_tri_o[2];
assign rf1_trx_sw    = gpio_tri_o[4];
assign rf2_trx_sw    = gpio_tri_o[4];
assign user_io7      = gpio_tri_o[4];
assign user_io6      = gpio_tri_o[4];
assign user_io5      = gpio_tri_o[4];
assign user_io4      = gpio_tri_o[4];
//register defination
wire [31:0] sdr_info={16'h1000,16'd840};
wire        mtime_start;
wire [ 1:0] pps_select;
wire [31:0] clock_1pps;
wire [11:0] phase;
wire [3:0]  rf_mode;

user_control user_control(
.axi_gp_clk       (fclk_100m      ),//global
.axi_rst          (~fclk_reset0    ),
.up_rack          (up_rack),
.up_raddr         (up_raddr),
.up_rdata         (up_rdata),
.up_rreq          (up_rreq),
.up_wack          (up_wack),
.up_waddr         (up_waddr),
.up_wdata         (up_wdata),
.up_wreq          (up_wreq),
.mtime_start      (mtime_start    ),//register out
.pps_select       (pps_select     ),
.clock_1pps       (clock_1pps     ),
.phase            (phase          ),
.rf_mode          (rf_mode        ),
.config_done      (config_done    ),
.adc_freeze       (adc_freeze     ),
.adc_clear_ov     (adc_clear_ov   ),
.sdr_info         (sdr_info       ),//register in
.fw_ver           (fw_ver         ),
.adc_over_volt    (adc_over_volt  )
);

//tx dds
reg [63:0] phase1;
always @ (posedge data_clk)
if(!mtime_start)
  begin
    phase1[16*0 +:16]<=16'd0;
    phase1[16*1 +:16]<=phase;
    phase1[16*2 +:16]<=phase+phase;
    phase1[16*3 +:16]<=phase+phase+phase;
  end
else
  begin
    phase1[16*0 +:16]<=phase1[16*0 +:16]+{phase,2'd0};
    phase1[16*1 +:16]<=phase1[16*1 +:16]+{phase,2'd0};
    phase1[16*2 +:16]<=phase1[16*2 +:16]+{phase,2'd0};
    phase1[16*3 +:16]<=phase1[16*3 +:16]+{phase,2'd0};
  end
  
wire [127:0] dds_data;
genvar chnl;
generate
  for (chnl = 0; chnl < 4; chnl = chnl + 1) begin : dds_chan
    dds_compiler_0 dds_compiler_0 (
    .aclk                 (data_clk            ),// input wire aclk
    .aresetn              (mtime_start          ),// input wire aresetn
    .s_axis_phase_tvalid  (1'b1                 ),// input wire s_axis_phase_tvalid
    .s_axis_phase_tdata   (phase1[16*chnl +:16] ),// input wire [7 : 0] s_axis_phase_tdata
    .m_axis_data_tvalid   (           ),// output wire m_axis_data_tvalid
    .m_axis_data_tdata    (dds_data[32*chnl +:32])// output wire [31 : 0] m_axis_data_tdata
    );
  end
endgenerate
always @ (posedge data_clk)
if(!mtime_start)
  begin
    dac_tdata[128*0 +:128]<=128'd0;
    dac_tdata[128*1 +:128]<=128'd0;
    dac_tdata[128*2 +:128]<=128'd0;
    dac_tdata[128*3 +:128]<=128'd0;
    dac_tdata[128*4 +:128]<=128'd0;
    dac_tdata[128*5 +:128]<=128'd0;
    dac_tdata[128*6 +:128]<=128'd0;
    dac_tdata[128*7 +:128]<=128'd0;
  end
else
  begin
    
    case(rf_mode)
      4'd0 :begin
              dac_tdata[128*0 +:128]<=128'd0;
              dac_tdata[128*1 +:128]<=128'd0;
              dac_tdata[128*2 +:128]<=128'd0;
              dac_tdata[128*3 +:128]<=128'd0;
              dac_tdata[128*4 +:128]<=128'd0;
              dac_tdata[128*5 +:128]<=128'd0;
              dac_tdata[128*6 +:128]<=128'd0;
              dac_tdata[128*7 +:128]<=128'd0;
            end
      4'd1 :begin
              dac_tdata[128*0 +:128]<=dds_data;
              dac_tdata[128*1 +:128]<=dds_data;
              dac_tdata[128*2 +:128]<=dds_data;
              dac_tdata[128*3 +:128]<=dds_data;
              dac_tdata[128*4 +:128]<=dds_data;
              dac_tdata[128*5 +:128]<=dds_data;
              dac_tdata[128*6 +:128]<=dds_data;
              dac_tdata[128*7 +:128]<=dds_data;
            end
      default:
            begin
              dac_tdata[128*0 +:128]<=128'd0;
              dac_tdata[128*1 +:128]<=128'd0;
              dac_tdata[128*2 +:128]<=128'd0;
              dac_tdata[128*3 +:128]<=128'd0;
              dac_tdata[128*4 +:128]<=128'd0;
              dac_tdata[128*5 +:128]<=128'd0;
              dac_tdata[128*6 +:128]<=128'd0;
              dac_tdata[128*7 +:128]<=128'd0;
            end
    endcase
  end
//led
assign led[0]=& adc_tvalid;
assign led[1]=& dac_tready;
assign led[2]=config_done;
assign led[3]=1'b1;
//chipscope
ila_0 ila_0 (
.clk(data_clk),
.probe0({
adc_tdata_i[16*0  +:16],
adc_tdata_q[16*0  +:16],
adc_tdata_i[16*4  +:16],
adc_tdata_q[16*4  +:16],
adc_tdata_i[16*8  +:16],
adc_tdata_q[16*8  +:16],
adc_tdata_i[16*12 +:16],
adc_tdata_q[16*12 +:16],

adc_tdata_i[16*16  +:16],
adc_tdata_q[16*16  +:16],
adc_tdata_i[16*20  +:16],
adc_tdata_q[16*20  +:16],
adc_tdata_i[16*24  +:16],
adc_tdata_q[16*24  +:16],
adc_tdata_i[16*28  +:16],
adc_tdata_q[16*28  +:16]
}),
.probe1({
adc_tvalid      ,//8
dac_tready      ,//4
user_sysref_adc ,//1
mtime_start      //1
}));  

endmodule
