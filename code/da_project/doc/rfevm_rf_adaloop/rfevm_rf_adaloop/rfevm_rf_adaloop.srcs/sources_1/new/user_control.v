`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/08/09 10:24:54
// Design Name: 
// Module Name: user_control
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

module user_control(
//global
input               axi_gp_clk,
input               axi_rst,
  // AXI Lite Master Interface connections
input               up_wreq,
input  [15:0]       up_waddr,
input  [31:0]       up_wdata,
output reg          up_wack,
 
input               up_rreq,
input  [15:0]       up_raddr,
output reg  [31:0]  up_rdata,
output reg          up_rack,
//register out
output reg          mtime_start,
output reg [1:0]    pps_select,
output reg [31:0]   clock_1pps,
output reg [11:0]   phase,
output reg [3:0]    rf_mode,
output reg          config_done,
output reg [7:0]    adc_freeze,
output reg [7:0]    adc_clear_ov,
//register in
input  [31:0]       sdr_info,
input  [31:0]       fw_ver,
input [7:0]         adc_over_volt,
input               dev_clk_locked
    );
// Register Interface
always @(posedge axi_gp_clk) begin
  if (axi_rst == 1'b1) begin
    up_wack <= 1'b0;
  end else begin
    up_wack <= up_wreq;
  end
end    
     
always @(posedge axi_gp_clk) begin
  if (axi_rst == 1'b1) begin
    up_rack <= 'd0;
  end else begin
    up_rack <= up_rreq;
  end
end

//write register
always @ (posedge axi_gp_clk)
if(axi_rst) begin
    mtime_start<=1'b0;
    pps_select<=2'd0;
    clock_1pps<=32'd30720000;
    phase<=12'd16;
    rf_mode<=4'd0;
    config_done<=1'b0;
    adc_freeze<=8'd0;
    adc_clear_ov<=8'd0;
end else if(up_wreq) begin
    case(up_waddr[15:2])
      7'd1 :mtime_start   <=up_wdata[0];
      7'd2 :pps_select    <=up_wdata[1:0];
      7'd4 :clock_1pps    <=up_wdata;
      7'd5 :phase         <=up_wdata[11:0];
      7'd6 :rf_mode       <=up_wdata[3:0];
      7'd7 :config_done   <=up_wdata[0];
      7'd8 :adc_freeze    <=up_wdata[7:0];
      7'd9 :adc_clear_ov  <=up_wdata[7:0];
    endcase
end else
  begin end
  
//read register
assign axi_rd_stb=1'b1;
wire [31:0] rx_data_rd;
always @ (posedge axi_gp_clk)
if(axi_rst) begin
    up_rdata<=32'd0;
end else begin
    case(up_raddr[15:2])
      7'd0    :up_rdata<=sdr_info        ;
      7'd1    :up_rdata<=mtime_start     ;
      7'd2    :up_rdata<=pps_select      ;
      7'd4    :up_rdata<=clock_1pps      ;
      7'd5    :up_rdata<=phase           ;
      7'd6    :up_rdata<=rf_mode         ;
      7'd7    :up_rdata<=config_done     ;
      7'd8    :up_rdata<=adc_freeze      ;
      7'd9    :up_rdata<=adc_over_volt   ;
      7'd64   :up_rdata<=fw_ver          ;
      default :up_rdata<=32'haabbccdd    ;
    endcase
end    
        
endmodule
