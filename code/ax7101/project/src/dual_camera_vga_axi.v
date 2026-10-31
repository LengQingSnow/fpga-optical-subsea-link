//////////////////////////////////////////////////////////////////////////////////
//  an5642 vga display                                                          //
//                                                                              //
//  Author: meisq                                                               //
//          msq@qq.com                                                          //
//          ALINX(shanghai) Technology Co.,Ltd                                  //
//          heijin                                                              //
//     WEB: http://www.alinx.cn/                                                //
//     BBS: http://www.heijin.org/                                              //
//                                                                              //
//////////////////////////////////////////////////////////////////////////////////
//                                                                              //
// Copyright (c) 2017,ALINX(shanghai) Technology Co.,Ltd                        //
//                    All rights reserved                                       //
//                                                                              //
// This source file may be used and distributed without restriction provided    //
// that this copyright statement is not removed from the file and that any      //
// derivative work contains the original copyright notice and the associated    //
// disclaimer.                                                                  //
//                                                                              //
//////////////////////////////////////////////////////////////////////////////////

//================================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------------
//  2019/09/19     lhj          1.1         ver1.1
//*******************************************************************************/
module dual_camera_vga_axi
(
input                            sys_clk,
input                            rst_n,                  //reset input，low active
input                            ui_clk,
input                            ui_clk_sync_rst,
input                            init_calib_complete,
inout                            cmos1_scl,              //cmos i2c clock
inout                            cmos1_sda,              //cmos i2c data
input                            cmos1_vsync,            //cmos vsync
input                            cmos1_href,             //cmos hsync refrence,data valid
input                            cmos1_pclk,             //cmos pxiel clock
input   [9:0]                    cmos1_db,               //cmos data
output                           cmos1_rst_n,            //cmos reset
inout                            cmos2_scl,              //cmos i2c clock
inout                            cmos2_sda,              //cmos i2c data
input                            cmos2_vsync,            //cmos vsync
input                            cmos2_href,             //cmos hsync refrence,data valid
input                            cmos2_pclk,             //cmos pxiel clock
input   [9:0]                    cmos2_db,               //cmos data
output                           cmos2_rst_n,            //cmos reset
//vga output
output                           vga_out_hs,             //vga horizontal synchronization
output                           vga_out_vs,             //vga vertical synchronization
output[4:0]                      vga_out_r,              //vga red
output[5:0]                      vga_out_g,              //vga green
output[4:0]                      vga_out_b,              //vga blue
output[15:0]                     camera1_pixel,
output                           camera1_pixel_valid,
output[15:0]                     camera2_pixel,
output                           camera2_pixel_valid,

output [0:0]                     m_axi_awid,
output [31:0]                    m_axi_awaddr,
output [7:0]                     m_axi_awlen,
output [2:0]                     m_axi_awsize,
output [1:0]                     m_axi_awburst,
output                           m_axi_awlock,
output [3:0]                     m_axi_awcache,
output [2:0]                     m_axi_awprot,
output [3:0]                     m_axi_awqos,
output                           m_axi_awvalid,
input                            m_axi_awready,
output [63:0]                    m_axi_wdata,
output [7:0]                     m_axi_wstrb,
output                           m_axi_wlast,
output                           m_axi_wvalid,
input                            m_axi_wready,
input [0:0]                      m_axi_bid,
input [1:0]                      m_axi_bresp,
input                            m_axi_bvalid,
output                           m_axi_bready,
output [0:0]                     m_axi_arid,
output [31:0]                    m_axi_araddr,
output [7:0]                     m_axi_arlen,
output [2:0]                     m_axi_arsize,
output [1:0]                     m_axi_arburst,
output [1:0]                     m_axi_arlock,
output [3:0]                     m_axi_arcache,
output [2:0]                     m_axi_arprot,
output [3:0]                     m_axi_arqos,
output                           m_axi_arvalid,
input                            m_axi_arready,
input [0:0]                      m_axi_rid,
input [63:0]                     m_axi_rdata,
input [1:0]                      m_axi_rresp,
input                            m_axi_rlast,
input                            m_axi_rvalid,
output                           m_axi_rready
);
parameter MEM_DATA_BITS          = 64;                 //external memory user interface data width
parameter ADDR_BITS              = 25;                 //external memory user interface address width
parameter BUSRT_BITS             = 10;                 //external memory user interface burst width
wire                            wr_burst_data_req;      // write burst data request       
wire                            wr_burst_finish;        // write burst finish flag
wire                            rd_burst_finish;        //read burst finish flag
wire                            rd_burst_req;           //read burst request
wire                            wr_burst_req;           //write burst request
wire[BUSRT_BITS - 1:0]          rd_burst_len;           //read burst length
wire[BUSRT_BITS - 1:0]          wr_burst_len;           //write burst length
wire[ADDR_BITS - 1:0]           rd_burst_addr;          //read burst address
wire[ADDR_BITS - 1:0]           wr_burst_addr;          //write burst address
wire                            rd_burst_data_valid;    //read burst data valid
wire[MEM_DATA_BITS - 1 : 0]     rd_burst_data;          //read burst data
wire[MEM_DATA_BITS - 1 : 0]     wr_burst_data;          //write burst data

wire                            ch0_wr_burst_data_req;  // ch0 write burst data request 
wire                            ch0_wr_burst_finish;    // ch0 write burst finish flag
wire                            ch0_rd_burst_finish;    //ch0 read burst finish flag
wire                            ch0_rd_burst_req;       //ch0 read burst request
wire                            ch0_wr_burst_req;       //ch0 write burst request
wire[BUSRT_BITS - 1:0]          ch0_rd_burst_len;       //ch0 read burst length
wire[BUSRT_BITS - 1:0]          ch0_wr_burst_len;       //ch0 write burst length
wire[ADDR_BITS - 1:0]           ch0_rd_burst_addr;      //ch0 read burst address
wire[ADDR_BITS - 1:0]           ch0_wr_burst_addr;      //ch0 write burst address
wire                            ch0_rd_burst_data_valid;//ch0 read burst data valid
wire[MEM_DATA_BITS - 1 : 0]     ch0_rd_burst_data;      //ch0 read burst data
wire[MEM_DATA_BITS - 1 : 0]     ch0_wr_burst_data;      //ch0 write burst data
wire                            ch0_read_req;           //ch0 read request
wire                            ch0_read_req_ack_raw;   //ch0 read request response
wire                            ch0_read_req_ack;
wire                            ch0_read_en;            //ch0 read enable
wire[15:0]                      ch0_read_data;          //ch0 read data
wire                            ch0_write_en;           //ch0 write enable
wire[15:0]                      ch0_write_data;         //ch0 write data
wire                            ch0_write_req;          //ch0 write request
wire                            ch0_write_req_ack_raw;  //ch0 write request response
wire                            ch0_write_req_ack;
wire[1:0]                       ch0_write_addr_index;   //ch0 write address index
wire[1:0]                       ch0_read_addr_index;    //ch0 read address index
//comment is similar to the ch0 channel above
wire                            ch1_wr_burst_data_req;
wire                            ch1_wr_burst_finish;
wire                            ch1_rd_burst_finish;
wire                            ch1_rd_burst_req;
wire                            ch1_wr_burst_req;
wire[BUSRT_BITS - 1:0]          ch1_rd_burst_len;
wire[BUSRT_BITS - 1:0]          ch1_wr_burst_len;
wire[ADDR_BITS - 1:0]           ch1_rd_burst_addr;
wire[ADDR_BITS - 1:0]           ch1_wr_burst_addr;
wire                            ch1_rd_burst_data_valid;
wire[MEM_DATA_BITS - 1 : 0]     ch1_rd_burst_data;
wire[MEM_DATA_BITS - 1 : 0]     ch1_wr_burst_data;
wire                            ch1_read_req;
wire                            ch1_read_req_ack_raw;
wire                            ch1_read_req_ack;
wire                            ch1_read_en;
wire[15:0]                      ch1_read_data;
wire                            ch1_write_en;
wire[15:0]                      ch1_write_data;
wire                            ch1_write_req;
wire                            ch1_write_req_ack_raw;
wire                            ch1_write_req_ack;
wire[1:0]                       ch1_write_addr_index;
wire[1:0]                       ch1_read_addr_index;
wire                             video_clk;              //video pixel clock
wire                             video_locked;
wire                             video_reset_n;
wire                             camera1_reset_n;
wire                             camera2_reset_n;
wire                             ui_domain_reset_n;
wire                             hs;                     //horizontal synchronization
wire                             vs;                     //vertical synchronization
wire                             de;                     //video valid
wire[15:0]                      vout_data;               //video data
wire[15:0]                      cmos1_16bit_data;        //camera coms1 data
wire                            cmos1_16bit_wr;          //camera coms1 write enable
wire[9:0]                       cmos1_lut_index;         //camera coms1 look up table address
wire[31:0]                      cmos1_lut_data;          //camera coms1 Device address,register address, register data

wire[15:0]                      cmos2_16bit_data;        //camera coms2 data
wire                            cmos2_16bit_wr;          //camera coms2 write enable
wire[9:0]                       cmos2_lut_index;         //camera coms2 look up table address
wire[31:0]                      cmos2_lut_data;          //camera coms2 Device address,register address, register data

assign vga_out_hs                = hs;
assign vga_out_vs                = vs;
assign vga_out_r                 = vout_data[15:11];
assign vga_out_g                 = vout_data[10:5];
assign vga_out_b                 = vout_data[4:0];

assign cmos1_rst_n               = 1'b1;
assign cmos2_rst_n               = 1'b1;
assign camera1_pixel             = cmos1_16bit_data;
assign camera1_pixel_valid       = cmos1_16bit_wr;
assign camera2_pixel             = cmos2_16bit_data;
assign camera2_pixel_valid       = cmos2_16bit_wr;
assign ch0_write_en              = cmos1_16bit_wr;
assign ch0_write_data            = {cmos1_16bit_data[4:0],cmos1_16bit_data[10:5],cmos1_16bit_data[15:11]};

assign ch1_write_en              = cmos2_16bit_wr;
assign ch1_write_data            = {cmos2_16bit_data[4:0],cmos2_16bit_data[10:5],cmos2_16bit_data[15:11]};
/*************************************************************************
generate 50MHz clock and video pixel clock with xilinx IP
**************************************************************************/
video_pll video_pll_m0
(
.clk_in1                        (sys_clk                  ),
.clk_out1                       (video_clk                ),
.reset                          (1'b0                     ),
.locked                         (video_locked             )
);

reset_level_cdc video_read_ack_cdc_m0
(
.dst_clk                        (video_clk                ),
.async_reset_n                  (rst_n && video_locked    ),
.async_level                    (ch0_read_req_ack_raw     ),
.dst_reset_n                    (video_reset_n            ),
.dst_level                      (ch0_read_req_ack         )
);

sync_bits #(.WIDTH(1)) video_read_ack_cdc_m1
(
.clk                            (video_clk                ),
.rst_n                          (video_reset_n            ),
.async_data                     (ch1_read_req_ack_raw     ),
.sync_data                      (ch1_read_req_ack         )
);

reset_level_cdc camera_write_ack_cdc_m0
(
.dst_clk                        (cmos1_pclk               ),
.async_reset_n                  (rst_n                    ),
.async_level                    (ch0_write_req_ack_raw    ),
.dst_reset_n                    (camera1_reset_n          ),
.dst_level                      (ch0_write_req_ack        )
);

reset_level_cdc camera_write_ack_cdc_m1
(
.dst_clk                        (cmos2_pclk               ),
.async_reset_n                  (rst_n                    ),
.async_level                    (ch1_write_req_ack_raw    ),
.dst_reset_n                    (camera2_reset_n          ),
.dst_level                      (ch1_write_req_ack        )
);

async_reset_sync ui_domain_reset_sync
(
.clk                            (ui_clk                   ),
.async_reset_n                  (rst_n && init_calib_complete &&
                                 !ui_clk_sync_rst         ),
.sync_reset_n                   (ui_domain_reset_n        )
);
/*************************************************************************
Configure the register of camera coms1
****************************************************************************/
i2c_config i2c_config_m0
(
.rst                            (~rst_n                   ),
.clk                            (sys_clk                  ),
.clk_div_cnt                    (16'd500                  ),
.i2c_addr_2byte                 (1'b1                     ),
.lut_index                      (cmos1_lut_index          ),
.lut_dev_addr                   (cmos1_lut_data[31:24]    ),
.lut_reg_addr                   (cmos1_lut_data[23:8]     ),
.lut_reg_data                   (cmos1_lut_data[7:0]      ),
.error                          (                         ),
.done                           (                         ),
.i2c_scl                        (cmos1_scl                ),
.i2c_sda                        (cmos1_sda                )
);
/*************************************************************************
look-up table of camera coms1 
****************************************************************************/
lut_ov5640_rgb565_640_480 lut_ov5640_m0
(
.lut_index                      (cmos1_lut_index          ),
.lut_data                       (cmos1_lut_data           )
);
/*************************************************************************
Configure the register of camera coms2
****************************************************************************/
i2c_config i2c_config_m1
(
.rst                            (~rst_n                   ),
.clk                            (sys_clk                  ),
.clk_div_cnt                    (16'd500                  ),
.i2c_addr_2byte                 (1'b1                     ),
.lut_index                      (cmos2_lut_index          ),
.lut_dev_addr                   (cmos2_lut_data[31:24]    ),
.lut_reg_addr                   (cmos2_lut_data[23:8]     ),
.lut_reg_data                   (cmos2_lut_data[7:0]      ),
.error                          (                         ),
.done                           (                         ),
.i2c_scl                        (cmos2_scl                ),
.i2c_sda                        (cmos2_sda                )
);
/*************************************************************************
look-up table of camera coms2
****************************************************************************/
lut_ov5640_rgb565_640_480 lut_ov5640_m1
(
.lut_index                      (cmos2_lut_index          ),
.lut_data                       (cmos2_lut_data           )
);
/*************************************************************************
CMOS1 sensor 8bit data is converted to 16bit data
****************************************************************************/  
cmos_8_16bit cmos_8_16bit_m0
(
.rst                            (~camera1_reset_n         ),
.pclk                           (cmos1_pclk               ),
.pdata_i                        (cmos1_db[9:2]            ),
.de_i                           (cmos1_href               ),
.pdata_o                        (cmos1_16bit_data         ),
.hblank                         (                         ),
.de_o                           (cmos1_16bit_wr           )
);
/*************************************************************************
CMOS2 sensor 8bit data is converted to 16bit data
****************************************************************************/ 
cmos_8_16bit cmos_8_16bit_m1
(
.rst                            (~camera2_reset_n         ),
.pclk                           (cmos2_pclk               ),
.pdata_i                        (cmos2_db[9:2]            ),
.de_i                           (cmos2_href               ),
.pdata_o                        (cmos2_16bit_data         ),
.hblank                         (                         ),
.de_o                           (cmos2_16bit_wr           )
);
/*************************************************************************
CMOS1 sensor writes the request and generates the read and write address index
****************************************************************************/ 
cmos_write_req_gen cmos_write_req_gen_m0
(
.rst                            (~camera1_reset_n         ),
.pclk                           (cmos1_pclk               ),
.cmos_vsync                     (cmos1_vsync              ),
.write_req                      (ch0_write_req            ),
.write_addr_index               (ch0_write_addr_index     ),
.read_addr_index                (ch0_read_addr_index      ),
.write_req_ack                  (ch0_write_req_ack        )
);
/*************************************************************************
CMOS2 sensor writes the request and generates the read and write address index
****************************************************************************/ 
cmos_write_req_gen cmos_write_req_gen_m1(
.rst                            (~camera2_reset_n         ),
.pclk                           (cmos2_pclk               ),
.cmos_vsync                     (cmos2_vsync              ),
.write_req                      (ch1_write_req            ),
.write_addr_index               (ch1_write_addr_index     ),
.read_addr_index                (ch1_read_addr_index      ),
.write_req_ack                  (ch1_write_req_ack        )
);

wire                            color_bar_hs;
wire                            color_bar_vs;
wire                            color_bar_de;
wire[7:0]                       color_bar_r;
wire[7:0]                       color_bar_g;
wire[7:0]                       color_bar_b;
wire                            v0_hs;
wire                            v0_vs;
wire                            v0_de;
wire[23:0]                      v0_data;
/*************************************************************************
video output timing generator
****************************************************************************/
color_bar color_bar_m0
(
.clk                            (video_clk                ),
.rst                            (~video_reset_n           ),
.hs                             (color_bar_hs             ),
.vs                             (color_bar_vs             ),
.de                             (color_bar_de             ),
.rgb_r                          (color_bar_r              ),
.rgb_g                          (color_bar_g              ),
.rgb_b                          (color_bar_b              )
);
/*************************************************************************
generate a frame read data request
****************************************************************************/
video_rect_read_data video_rect_read_data_m0
(
.video_clk                      (video_clk                ),
.rst                            (~video_reset_n           ),
.video_left_offset              (12'd0                    ),
.video_top_offset               (12'd0                    ),
.video_width                    (12'd640                  ),
.video_height	                (12'd480                  ),
.read_req                       (ch0_read_req             ),
.read_req_ack                   (ch0_read_req_ack_raw     ),
.read_en                        (ch0_read_en              ),
.read_data                      (ch0_read_data            ),
.timing_hs                      (color_bar_hs             ),
.timing_vs                      (color_bar_vs             ),
.timing_de                      (color_bar_de             ),
.timing_data 	                ({color_bar_r[4:0],color_bar_g[5:0],color_bar_b[4:0]}),
.hs                             (v0_hs                    ),
.vs                             (v0_vs                    ),
.de                             (v0_de                    ),
.vout_data                      (v0_data                  )
);
/*************************************************************************
generate a frame read data request
****************************************************************************/
video_rect_read_data video_rect_read_data_m1
(
.video_clk                      (video_clk                ),
.rst                            (~video_reset_n           ),
.video_left_offset              (12'd640                  ),
.video_top_offset               (12'd0                    ),
.video_width                    (12'd640                  ),
.video_height	                (12'd480                  ),
.read_req                       (ch1_read_req             ),
.read_req_ack                   (ch1_read_req_ack         ),
.read_en                        (ch1_read_en              ),
.read_data                      (ch1_read_data            ),
.timing_hs                      (v0_hs                    ),
.timing_vs                      (v0_vs                    ),
.timing_de                      (v0_de                    ),
.timing_data 	                (v0_data                  ),
.hs                             (hs                       ),
.vs                             (vs                       ),
.de                             (de                       ),
.vout_data                      (vout_data                )
);
/*************************************************************************
video frame data read-write control
/****************************************************************************/
frame_read_write frame_read_write_m0
(
.rst                            (~ui_domain_reset_n       ),
.mem_clk                        (ui_clk                   ),
.rd_burst_req                   (ch0_rd_burst_req         ),
.rd_burst_len                   (ch0_rd_burst_len         ),
.rd_burst_addr                  (ch0_rd_burst_addr        ),
.rd_burst_data_valid            (ch0_rd_burst_data_valid  ),
.rd_burst_data                  (ch0_rd_burst_data        ),
.rd_burst_finish                (ch0_rd_burst_finish      ),
.read_clk                       (video_clk                ),
.read_req                       (ch0_read_req             ),
.read_req_ack                   (ch0_read_req_ack         ),
.read_finish                    (                         ),
.read_addr_0                    (25'd16777216             ),
.read_addr_1                    (25'd16908288             ),
.read_addr_2                    (25'd17039360             ),
.read_addr_3                    (25'd17170432             ),
.read_addr_index                (ch0_read_addr_index      ),
.read_len                       (25'd76800                ),//640 * 480 * 16 / 64
.read_en                        (ch0_read_en              ),
.read_data                      (ch0_read_data            ),

.wr_burst_req                   (ch0_wr_burst_req         ),
.wr_burst_len                   (ch0_wr_burst_len         ),
.wr_burst_addr                  (ch0_wr_burst_addr        ),
.wr_burst_data_req              (ch0_wr_burst_data_req    ),
.wr_burst_data                  (ch0_wr_burst_data        ),
.wr_burst_finish                (ch0_wr_burst_finish      ),
.write_clk                      (cmos1_pclk               ),
.write_req                      (ch0_write_req            ),
.write_req_ack                  (ch0_write_req_ack_raw    ),
.write_finish                   (                         ),
.write_addr_0                   (25'd16777216             ),
.write_addr_1                   (25'd16908288             ),
.write_addr_2                   (25'd17039360             ),
.write_addr_3                   (25'd17170432             ),
.write_addr_index               (ch0_write_addr_index     ),
.write_len                      (25'd76800                ),
.write_en                       (ch0_write_en             ),
.write_data                     (ch0_write_data           )
);
/*************************************************************************
video frame data read-write control
/****************************************************************************/
frame_read_write frame_read_write_m1
(
.rst                            (~ui_domain_reset_n       ),
.mem_clk                        (ui_clk                   ),
.rd_burst_req                   (ch1_rd_burst_req         ),
.rd_burst_len                   (ch1_rd_burst_len         ),
.rd_burst_addr                  (ch1_rd_burst_addr        ),
.rd_burst_data_valid            (ch1_rd_burst_data_valid  ),
.rd_burst_data                  (ch1_rd_burst_data        ),
.rd_burst_finish                (ch1_rd_burst_finish      ),
.read_clk                       (video_clk                ),
.read_req                       (ch1_read_req             ),
.read_req_ack                   (ch1_read_req_ack_raw     ),
.read_finish                    (                         ),
.read_addr_0                    (25'd17301504             ),
.read_addr_1                    (25'd17432576             ),
.read_addr_2                    (25'd17563648             ),
.read_addr_3                    (25'd17694720             ),
.read_addr_index                (ch1_read_addr_index      ),
.read_len                       (25'd76800                ),//640 * 480 * 16 / 64
.read_en                        (ch1_read_en              ),
.read_data                      (ch1_read_data            ),

.wr_burst_req                   (ch1_wr_burst_req         ),
.wr_burst_len                   (ch1_wr_burst_len         ),
.wr_burst_addr                  (ch1_wr_burst_addr        ),
.wr_burst_data_req              (ch1_wr_burst_data_req    ),
.wr_burst_data                  (ch1_wr_burst_data        ),
.wr_burst_finish                (ch1_wr_burst_finish      ),
.write_clk                      (cmos2_pclk               ),
.write_req                      (ch1_write_req            ),
.write_req_ack                  (ch1_write_req_ack_raw    ),
.write_finish                   (                         ),
.write_addr_0                   (25'd17301504             ),
.write_addr_1                   (25'd17432576             ),
.write_addr_2                   (25'd17563648             ),
.write_addr_3                   (25'd17694720             ),
.write_addr_index               (ch1_write_addr_index     ),
.write_len                      (25'd76800                ),
.write_en                       (ch1_write_en             ),
.write_data                     (ch1_write_data           )
);
/*************************************************************************
AXI User Interface Conversion 
****************************************************************************/
aq_axi_master u_aq_axi_master
(
.ARESETN                        (~ui_clk_sync_rst         ),
.ACLK                           (ui_clk                   ),
.M_AXI_AWID                     (m_axi_awid               ),
.M_AXI_AWADDR                   (m_axi_awaddr             ),
.M_AXI_AWLEN                    (m_axi_awlen              ),
.M_AXI_AWSIZE                   (m_axi_awsize             ),
.M_AXI_AWBURST                  (m_axi_awburst            ),
.M_AXI_AWLOCK                   (m_axi_awlock             ),
.M_AXI_AWCACHE                  (m_axi_awcache            ),
.M_AXI_AWPROT                   (m_axi_awprot             ),
.M_AXI_AWQOS                    (m_axi_awqos              ),
.M_AXI_AWUSER                   (                         ),
.M_AXI_AWVALID                  (m_axi_awvalid            ),
.M_AXI_AWREADY                  (m_axi_awready            ),
.M_AXI_WDATA                    (m_axi_wdata              ),
.M_AXI_WSTRB                    (m_axi_wstrb              ),
.M_AXI_WLAST                    (m_axi_wlast              ),
.M_AXI_WUSER                    (                         ),
.M_AXI_WVALID                   (m_axi_wvalid             ),
.M_AXI_WREADY                   (m_axi_wready             ),
.M_AXI_BID                      (m_axi_bid                ),
.M_AXI_BRESP                    (m_axi_bresp              ),
.M_AXI_BUSER                    (1'b0                     ),
.M_AXI_BVALID                   (m_axi_bvalid             ),
.M_AXI_BREADY                   (m_axi_bready             ),
.M_AXI_ARID                     (m_axi_arid               ),
.M_AXI_ARADDR                   (m_axi_araddr             ),
.M_AXI_ARLEN                    (m_axi_arlen              ),
.M_AXI_ARSIZE                   (m_axi_arsize             ),
.M_AXI_ARBURST                  (m_axi_arburst            ),
.M_AXI_ARLOCK                   (m_axi_arlock             ),
.M_AXI_ARCACHE                  (m_axi_arcache            ),
.M_AXI_ARPROT                   (m_axi_arprot             ),
.M_AXI_ARQOS                    (m_axi_arqos              ),
.M_AXI_ARUSER                   (                         ),
.M_AXI_ARVALID                  (m_axi_arvalid            ),
.M_AXI_ARREADY                  (m_axi_arready            ),
.M_AXI_RID                      (m_axi_rid                ),
.M_AXI_RDATA                    (m_axi_rdata              ),
.M_AXI_RRESP                    (m_axi_rresp              ),
.M_AXI_RLAST                    (m_axi_rlast              ),
.M_AXI_RUSER                    (1'b0                     ),
.M_AXI_RVALID                   (m_axi_rvalid             ),
.M_AXI_RREADY                   (m_axi_rready             ),
.MASTER_RST                     (1'b0                     ),
.WR_START                       (wr_burst_req             ),
.WR_ADRS                        ({wr_burst_addr,3'd0}     ),
.WR_LEN                         ({wr_burst_len,3'd0}      ),
.WR_READY                       (                         ),
.WR_FIFO_RE                     (wr_burst_data_req        ),
.WR_FIFO_EMPTY                  (1'b0                     ),
.WR_FIFO_AEMPTY                 (1'b0                     ),
.WR_FIFO_DATA                   (wr_burst_data            ),
.WR_DONE                        (wr_burst_finish          ),
.RD_START                       (rd_burst_req             ),
.RD_ADRS                        ({rd_burst_addr,3'd0}     ),
.RD_LEN                         ({rd_burst_len,3'd0}      ),
.RD_READY                       (                         ),
.RD_FIFO_WE                     (rd_burst_data_valid      ),
.RD_FIFO_FULL                   (1'b0                     ),
.RD_FIFO_AFULL                  (1'b0                     ),
.RD_FIFO_DATA                   (rd_burst_data            ),
.RD_DONE                        (rd_burst_finish          ),
.DEBUG                          (                         )
);
/*************************************************************************
read us arbitration
****************************************************************************/
mem_read_arbi 
#(
.MEM_DATA_BITS                  (MEM_DATA_BITS            ),
.ADDR_BITS                      (ADDR_BITS                ),
.BUSRT_BITS                     (BUSRT_BITS               )
)
mem_read_arbi_m0
(
.rst_n                          (ui_domain_reset_n        ),
.mem_clk                        (ui_clk                   ),
.ch0_rd_burst_req               (ch0_rd_burst_req         ),
.ch0_rd_burst_len               (ch0_rd_burst_len         ),
.ch0_rd_burst_addr              (ch0_rd_burst_addr        ),
.ch0_rd_burst_data_valid        (ch0_rd_burst_data_valid  ),
.ch0_rd_burst_data              (ch0_rd_burst_data        ),
.ch0_rd_burst_finish            (ch0_rd_burst_finish      ),

.ch1_rd_burst_req               (ch1_rd_burst_req         ),
.ch1_rd_burst_len               (ch1_rd_burst_len         ),
.ch1_rd_burst_addr              (ch1_rd_burst_addr        ),
.ch1_rd_burst_data_valid        (ch1_rd_burst_data_valid  ),
.ch1_rd_burst_data              (ch1_rd_burst_data        ),
.ch1_rd_burst_finish            (ch1_rd_burst_finish      ),

.rd_burst_req                   (rd_burst_req             ),
.rd_burst_len                   (rd_burst_len             ),
.rd_burst_addr                  (rd_burst_addr            ),
.rd_burst_data_valid            (rd_burst_data_valid      ),
.rd_burst_data                  (rd_burst_data            ),
.rd_burst_finish                (rd_burst_finish          )	
);
/*************************************************************************
write bus arbitration
****************************************************************************/
mem_write_arbi
#(
.MEM_DATA_BITS                  (MEM_DATA_BITS            ),
.ADDR_BITS                      (ADDR_BITS                ),
.BUSRT_BITS                     (BUSRT_BITS               )
)
mem_write_arbi_m0
(
.rst_n                          (ui_domain_reset_n        ),
.mem_clk                        (ui_clk                   ),

.ch0_wr_burst_req               (ch0_wr_burst_req         ),
.ch0_wr_burst_len               (ch0_wr_burst_len         ),
.ch0_wr_burst_addr              (ch0_wr_burst_addr        ),
.ch0_wr_burst_data_req          (ch0_wr_burst_data_req    ),
.ch0_wr_burst_data              (ch0_wr_burst_data        ),
.ch0_wr_burst_finish            (ch0_wr_burst_finish      ),

.ch1_wr_burst_req               (ch1_wr_burst_req         ),
.ch1_wr_burst_len               (ch1_wr_burst_len         ),
.ch1_wr_burst_addr              (ch1_wr_burst_addr        ),
.ch1_wr_burst_data_req          (ch1_wr_burst_data_req    ),
.ch1_wr_burst_data              (ch1_wr_burst_data        ),
.ch1_wr_burst_finish            (ch1_wr_burst_finish      ),

.wr_burst_req                   (wr_burst_req             ),
.wr_burst_len                   (wr_burst_len             ),
.wr_burst_addr                  (wr_burst_addr            ),
.wr_burst_data_req              (wr_burst_data_req        ),
.wr_burst_data                  (wr_burst_data            ),
.wr_burst_finish                (wr_burst_finish          )	
);
endmodule
