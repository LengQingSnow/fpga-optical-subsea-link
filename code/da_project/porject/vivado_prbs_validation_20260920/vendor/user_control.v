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
output reg [55:0]   lane_delay_codes,
output reg          delay_commit_toggle,
output reg [447:0]  preeq_coeffs,
output reg [3:0]    preeq_enable_mask,
output reg          preeq_commit_toggle,
output reg          ber_capture_toggle,
output reg          ber_replay_enable,
output [5:0]        ber_reference_address,
//register in
input  [31:0]       sdr_info,
input  [31:0]       fw_ver,
input [7:0]         adc_over_volt,
input               dev_clk_locked,
input [63:0]        ber_reference_data,
input               ber_reference_ready,
input               ber_replay_active
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
    lane_delay_codes<=56'd0;
    delay_commit_toggle<=1'b0;
    preeq_coeffs<=448'd0;
    preeq_enable_mask<=4'd0;
    preeq_commit_toggle<=1'b0;
    ber_capture_toggle<=1'b0;
    ber_replay_enable<=1'b0;
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
      7'd10:lane_delay_codes[0*7 +: 7] <=up_wdata[6:0];
      7'd11:lane_delay_codes[1*7 +: 7] <=up_wdata[6:0];
      7'd12:lane_delay_codes[2*7 +: 7] <=up_wdata[6:0];
      7'd13:lane_delay_codes[3*7 +: 7] <=up_wdata[6:0];
      7'd14:lane_delay_codes[4*7 +: 7] <=up_wdata[6:0];
      7'd15:lane_delay_codes[5*7 +: 7] <=up_wdata[6:0];
      7'd16:lane_delay_codes[6*7 +: 7] <=up_wdata[6:0];
      7'd17:lane_delay_codes[7*7 +: 7] <=up_wdata[6:0];
      // up_wreq remains asserted until the delayed up_wack is observed.  Only
      // toggle once for that transaction or an even-length request disappears.
      7'd18:if(up_wdata[0] && !up_wack) delay_commit_toggle <= ~delay_commit_toggle;
      7'd47:preeq_enable_mask <=up_wdata[3:0];
      7'd48:if(up_wdata[0] && !up_wack) preeq_commit_toggle <= ~preeq_commit_toggle;
      14'd65:begin
          ber_replay_enable <= up_wdata[1];
          if(up_wdata[0] && !up_wack)
              ber_capture_toggle <= ~ber_capture_toggle;
      end
      default: if ((up_waddr[15:2] >= 7'd19) && (up_waddr[15:2] <= 7'd46))
          preeq_coeffs[(up_waddr[15:2]-7'd19)*16 +: 16] <= up_wdata[15:0];
    endcase
end else
  begin end
  
//read register
assign axi_rd_stb=1'b1;
assign ber_reference_address=(up_raddr[15:2]-14'd68)>>1;
wire [31:0] rx_data_rd;
always @ (posedge axi_gp_clk)
if(axi_rst) begin
    up_rdata<=32'd0;
end else begin
    case(up_raddr[15:2])
      7'd0    :up_rdata<=sdr_info        ;
      7'd1    :up_rdata<=mtime_start     ;
      7'd2    :up_rdata<=pps_select      ;
      7'd3    :up_rdata<={31'd0,dev_clk_locked};
      7'd4    :up_rdata<=clock_1pps      ;
      7'd5    :up_rdata<=phase           ;
      7'd6    :up_rdata<=rf_mode         ;
      7'd7    :up_rdata<=config_done     ;
      7'd8    :up_rdata<=adc_freeze      ;
      7'd9    :up_rdata<=adc_over_volt   ;
      7'd10   :up_rdata<={25'd0,lane_delay_codes[0*7 +: 7]};
      7'd11   :up_rdata<={25'd0,lane_delay_codes[1*7 +: 7]};
      7'd12   :up_rdata<={25'd0,lane_delay_codes[2*7 +: 7]};
      7'd13   :up_rdata<={25'd0,lane_delay_codes[3*7 +: 7]};
      7'd14   :up_rdata<={25'd0,lane_delay_codes[4*7 +: 7]};
      7'd15   :up_rdata<={25'd0,lane_delay_codes[5*7 +: 7]};
      7'd16   :up_rdata<={25'd0,lane_delay_codes[6*7 +: 7]};
      7'd17   :up_rdata<={25'd0,lane_delay_codes[7*7 +: 7]};
      7'd18   :up_rdata<={31'd0,delay_commit_toggle};
      7'd47   :up_rdata<={28'd0,preeq_enable_mask};
      7'd48   :up_rdata<={31'd0,preeq_commit_toggle};
      7'd64   :up_rdata<=fw_ver          ;
      14'd65  :up_rdata<={30'd0,ber_replay_enable,ber_capture_toggle};
      14'd66  :up_rdata<={30'd0,ber_replay_active,ber_reference_ready};
      14'd67  :up_rdata<=32'd64;
      // Test-only identity and full-period metadata (prefix window stays 64).
      14'd196 :up_rdata<=32'h5052424c;
      14'd197 :up_rdata<=32'd262144;
      14'd198 :up_rdata<=32'h13579bdf;
      14'd199 :up_rdata<=32'h2468ace1;
      14'd200 :up_rdata<=32'h5a6b7c1d;
      14'd201 :up_rdata<=32'h73c951a7;
      14'd202 :up_rdata<=32'h10000009;
      14'd203 :up_rdata<=32'd16;
      default: if ((up_raddr[15:2] >= 14'd68) && (up_raddr[15:2] <= 14'd195)) begin
          if (up_raddr[2])
              up_rdata<=ber_reference_data[63:32];
          else
              up_rdata<=ber_reference_data[31:0];
        end else if ((up_raddr[15:2] >= 7'd19) && (up_raddr[15:2] <= 7'd46))
          up_rdata<={16'd0,preeq_coeffs[(up_raddr[15:2]-7'd19)*16 +: 16]};
        else
          up_rdata<=32'haabbccdd;
    endcase
end    
        
endmodule
