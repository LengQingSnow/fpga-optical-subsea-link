`timescale 1ns/1ps

module dual_ip_arp_responder (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        gmii_rx_dv,
    input  wire        gmii_rx_er,
    input  wire [7:0]  gmii_rxd,

    output reg         gmii_tx_en,
    output reg         gmii_tx_er,
    output reg  [7:0]  gmii_txd,
    output reg  [31:0] arp_requests,
    output reg  [31:0] arp_replies,
    output reg  [31:0] arp_fcs_errors,
    output reg  [31:0] arp_malformed_frames
);

localparam [10:0] ARP_FRAME_BYTES = 11'd72;

reg rx_in_frame;
reg [10:0] rx_byte_index;
reg rx_preamble_bad;
reg rx_frame_error;
reg [47:0] rx_destination_mac;
reg [47:0] rx_source_mac;
reg [15:0] rx_ether_type;
reg [15:0] rx_hardware_type;
reg [15:0] rx_protocol_type;
reg [7:0] rx_hardware_length;
reg [7:0] rx_protocol_length;
reg [15:0] rx_operation;
reg [47:0] rx_sender_mac;
reg [31:0] rx_sender_ip;
reg [31:0] rx_target_ip;
reg [31:0] rx_crc_state;
reg [31:0] rx_received_fcs;

reg reply_request_pulse;
reg reply_pending;
reg [47:0] reply_target_mac;
reg [31:0] reply_target_ip;
reg [47:0] reply_source_mac;
reg [31:0] reply_source_ip;

reg tx_active;
reg [3:0] ifg_count;
reg [6:0] tx_byte_index;
reg [31:0] tx_crc_state;
reg [31:0] tx_fcs;

wire [10:0] rx_current_index;
wire rx_fcs_ok;
wire target_is_ip_17;
wire target_is_ip_18;
wire target_is_local;
wire destination_is_valid;
wire arp_header_ok;
wire [7:0] reply_byte;

assign rx_current_index = rx_in_frame ? rx_byte_index : 11'd0;
assign rx_fcs_ok = (rx_received_fcs == ~rx_crc_state);
assign target_is_ip_17 = (rx_target_ip == 32'hc0a8_0011);
assign target_is_ip_18 = (rx_target_ip == 32'hc0a8_0012);
assign target_is_local = target_is_ip_17 || target_is_ip_18;
assign destination_is_valid =
    (rx_destination_mac == 48'hffff_ffff_ffff) ||
    (target_is_ip_17 &&
     (rx_destination_mac == 48'h000a_3501_fec1)) ||
    (target_is_ip_18 &&
     (rx_destination_mac == 48'h000a_3501_fec2));
assign arp_header_ok =
    (rx_ether_type == 16'h0806) &&
    (rx_hardware_type == 16'h0001) &&
    (rx_protocol_type == 16'h0800) &&
    (rx_hardware_length == 8'd6) &&
    (rx_protocol_length == 8'd4) &&
    (rx_operation == 16'h0001) &&
    destination_is_valid &&
    target_is_local;
assign reply_byte = reply_frame_byte(tx_byte_index);

function [31:0] crc32_byte;
    input [31:0] crc_in;
    input [7:0] data_in;
    reg [31:0] value;
    integer bit_number;
    begin
        value = crc_in;
        for (bit_number = 0; bit_number < 8;
             bit_number = bit_number + 1) begin
            if (value[0] ^ data_in[bit_number])
                value = (value >> 1) ^ 32'hedb8_8320;
            else
                value = value >> 1;
        end
        crc32_byte = value;
    end
endfunction

function [7:0] reply_frame_byte;
    input [6:0] index;
    begin
        case (index)
            0, 1, 2, 3, 4, 5, 6:
                reply_frame_byte = 8'h55;
            7:
                reply_frame_byte = 8'hd5;
            8: reply_frame_byte = reply_target_mac[47:40];
            9: reply_frame_byte = reply_target_mac[39:32];
            10: reply_frame_byte = reply_target_mac[31:24];
            11: reply_frame_byte = reply_target_mac[23:16];
            12: reply_frame_byte = reply_target_mac[15:8];
            13: reply_frame_byte = reply_target_mac[7:0];
            14: reply_frame_byte = reply_source_mac[47:40];
            15: reply_frame_byte = reply_source_mac[39:32];
            16: reply_frame_byte = reply_source_mac[31:24];
            17: reply_frame_byte = reply_source_mac[23:16];
            18: reply_frame_byte = reply_source_mac[15:8];
            19: reply_frame_byte = reply_source_mac[7:0];
            20: reply_frame_byte = 8'h08;
            21: reply_frame_byte = 8'h06;
            22: reply_frame_byte = 8'h00;
            23: reply_frame_byte = 8'h01;
            24: reply_frame_byte = 8'h08;
            25: reply_frame_byte = 8'h00;
            26: reply_frame_byte = 8'h06;
            27: reply_frame_byte = 8'h04;
            28: reply_frame_byte = 8'h00;
            29: reply_frame_byte = 8'h02;
            30: reply_frame_byte = reply_source_mac[47:40];
            31: reply_frame_byte = reply_source_mac[39:32];
            32: reply_frame_byte = reply_source_mac[31:24];
            33: reply_frame_byte = reply_source_mac[23:16];
            34: reply_frame_byte = reply_source_mac[15:8];
            35: reply_frame_byte = reply_source_mac[7:0];
            36: reply_frame_byte = reply_source_ip[31:24];
            37: reply_frame_byte = reply_source_ip[23:16];
            38: reply_frame_byte = reply_source_ip[15:8];
            39: reply_frame_byte = reply_source_ip[7:0];
            40: reply_frame_byte = reply_target_mac[47:40];
            41: reply_frame_byte = reply_target_mac[39:32];
            42: reply_frame_byte = reply_target_mac[31:24];
            43: reply_frame_byte = reply_target_mac[23:16];
            44: reply_frame_byte = reply_target_mac[15:8];
            45: reply_frame_byte = reply_target_mac[7:0];
            46: reply_frame_byte = reply_target_ip[31:24];
            47: reply_frame_byte = reply_target_ip[23:16];
            48: reply_frame_byte = reply_target_ip[15:8];
            49: reply_frame_byte = reply_target_ip[7:0];
            50, 51, 52, 53, 54, 55, 56, 57, 58,
            59, 60, 61, 62, 63, 64, 65, 66, 67:
                reply_frame_byte = 8'h00;
            68: reply_frame_byte = tx_fcs[7:0];
            69: reply_frame_byte = tx_fcs[15:8];
            70: reply_frame_byte = tx_fcs[23:16];
            71: reply_frame_byte = tx_fcs[31:24];
            default:
                reply_frame_byte = 8'h00;
        endcase
    end
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_in_frame <= 1'b0;
        rx_byte_index <= 11'd0;
        rx_preamble_bad <= 1'b0;
        rx_frame_error <= 1'b0;
        rx_destination_mac <= 48'd0;
        rx_source_mac <= 48'd0;
        rx_ether_type <= 16'd0;
        rx_hardware_type <= 16'd0;
        rx_protocol_type <= 16'd0;
        rx_hardware_length <= 8'd0;
        rx_protocol_length <= 8'd0;
        rx_operation <= 16'd0;
        rx_sender_mac <= 48'd0;
        rx_sender_ip <= 32'd0;
        rx_target_ip <= 32'd0;
        rx_crc_state <= 32'hffff_ffff;
        rx_received_fcs <= 32'd0;
        reply_request_pulse <= 1'b0;
        reply_target_mac <= 48'd0;
        reply_target_ip <= 32'd0;
        reply_source_mac <= 48'd0;
        reply_source_ip <= 32'd0;
        arp_requests <= 32'd0;
        arp_fcs_errors <= 32'd0;
        arp_malformed_frames <= 32'd0;
    end else begin
        reply_request_pulse <= 1'b0;
        if (gmii_rx_dv) begin
            if (!rx_in_frame) begin
                rx_in_frame <= 1'b1;
                rx_byte_index <= 11'd1;
                rx_preamble_bad <= (gmii_rxd != 8'h55);
                rx_frame_error <= gmii_rx_er;
                rx_destination_mac <= 48'd0;
                rx_source_mac <= 48'd0;
                rx_ether_type <= 16'd0;
                rx_hardware_type <= 16'd0;
                rx_protocol_type <= 16'd0;
                rx_hardware_length <= 8'd0;
                rx_protocol_length <= 8'd0;
                rx_operation <= 16'd0;
                rx_sender_mac <= 48'd0;
                rx_sender_ip <= 32'd0;
                rx_target_ip <= 32'd0;
                rx_crc_state <= 32'hffff_ffff;
                rx_received_fcs <= 32'd0;
            end else begin
                rx_byte_index <= rx_byte_index + 1'b1;
                if (gmii_rx_er)
                    rx_frame_error <= 1'b1;
                if ((rx_current_index >= 11'd1) &&
                    (rx_current_index <= 11'd6) &&
                    (gmii_rxd != 8'h55))
                    rx_preamble_bad <= 1'b1;
                if ((rx_current_index == 11'd7) &&
                    (gmii_rxd != 8'hd5))
                    rx_preamble_bad <= 1'b1;
                if ((rx_current_index >= 11'd8) &&
                    (rx_current_index <= 11'd67))
                    rx_crc_state <= crc32_byte(rx_crc_state, gmii_rxd);

                case (rx_current_index)
                    8: rx_destination_mac[47:40] <= gmii_rxd;
                    9: rx_destination_mac[39:32] <= gmii_rxd;
                    10: rx_destination_mac[31:24] <= gmii_rxd;
                    11: rx_destination_mac[23:16] <= gmii_rxd;
                    12: rx_destination_mac[15:8] <= gmii_rxd;
                    13: rx_destination_mac[7:0] <= gmii_rxd;
                    14: rx_source_mac[47:40] <= gmii_rxd;
                    15: rx_source_mac[39:32] <= gmii_rxd;
                    16: rx_source_mac[31:24] <= gmii_rxd;
                    17: rx_source_mac[23:16] <= gmii_rxd;
                    18: rx_source_mac[15:8] <= gmii_rxd;
                    19: rx_source_mac[7:0] <= gmii_rxd;
                    20: rx_ether_type[15:8] <= gmii_rxd;
                    21: rx_ether_type[7:0] <= gmii_rxd;
                    22: rx_hardware_type[15:8] <= gmii_rxd;
                    23: rx_hardware_type[7:0] <= gmii_rxd;
                    24: rx_protocol_type[15:8] <= gmii_rxd;
                    25: rx_protocol_type[7:0] <= gmii_rxd;
                    26: rx_hardware_length <= gmii_rxd;
                    27: rx_protocol_length <= gmii_rxd;
                    28: rx_operation[15:8] <= gmii_rxd;
                    29: rx_operation[7:0] <= gmii_rxd;
                    30: rx_sender_mac[47:40] <= gmii_rxd;
                    31: rx_sender_mac[39:32] <= gmii_rxd;
                    32: rx_sender_mac[31:24] <= gmii_rxd;
                    33: rx_sender_mac[23:16] <= gmii_rxd;
                    34: rx_sender_mac[15:8] <= gmii_rxd;
                    35: rx_sender_mac[7:0] <= gmii_rxd;
                    36: rx_sender_ip[31:24] <= gmii_rxd;
                    37: rx_sender_ip[23:16] <= gmii_rxd;
                    38: rx_sender_ip[15:8] <= gmii_rxd;
                    39: rx_sender_ip[7:0] <= gmii_rxd;
                    46: rx_target_ip[31:24] <= gmii_rxd;
                    47: rx_target_ip[23:16] <= gmii_rxd;
                    48: rx_target_ip[15:8] <= gmii_rxd;
                    49: rx_target_ip[7:0] <= gmii_rxd;
                    68: rx_received_fcs[7:0] <= gmii_rxd;
                    69: rx_received_fcs[15:8] <= gmii_rxd;
                    70: rx_received_fcs[23:16] <= gmii_rxd;
                    71: rx_received_fcs[31:24] <= gmii_rxd;
                    default: begin
                    end
                endcase
            end
        end else if (rx_in_frame) begin
            rx_in_frame <= 1'b0;
            rx_byte_index <= 11'd0;
            if (rx_ether_type == 16'h0806) begin
                if (rx_frame_error ||
                    rx_preamble_bad ||
                    (rx_byte_index != ARP_FRAME_BYTES) ||
                    !arp_header_ok) begin
                    arp_malformed_frames <=
                        arp_malformed_frames + 1'b1;
                end else if (!rx_fcs_ok) begin
                    arp_fcs_errors <= arp_fcs_errors + 1'b1;
                end else if (!reply_pending) begin
                    arp_requests <= arp_requests + 1'b1;
                    reply_request_pulse <= 1'b1;
                    reply_target_mac <= rx_sender_mac;
                    reply_target_ip <= rx_sender_ip;
                    if (target_is_ip_17) begin
                        reply_source_mac <= 48'h000a_3501_fec1;
                        reply_source_ip <= 32'hc0a8_0011;
                    end else begin
                        reply_source_mac <= 48'h000a_3501_fec2;
                        reply_source_ip <= 32'hc0a8_0012;
                    end
                end
            end
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        gmii_tx_en <= 1'b0;
        gmii_tx_er <= 1'b0;
        gmii_txd <= 8'd0;
        tx_active <= 1'b0;
        reply_pending <= 1'b0;
        ifg_count <= 4'd0;
        tx_byte_index <= 7'd0;
        tx_crc_state <= 32'hffff_ffff;
        tx_fcs <= 32'd0;
        arp_replies <= 32'd0;
    end else begin
        gmii_tx_en <= 1'b0;
        gmii_tx_er <= 1'b0;
        gmii_txd <= 8'd0;

        if (reply_request_pulse)
            reply_pending <= 1'b1;

        if (tx_active) begin
            gmii_tx_en <= 1'b1;
            gmii_txd <= reply_byte;

            if (tx_byte_index == 7'd8)
                tx_crc_state <=
                    crc32_byte(32'hffff_ffff, reply_byte);
            else if ((tx_byte_index > 7'd8) &&
                     (tx_byte_index < 7'd67))
                tx_crc_state <= crc32_byte(tx_crc_state, reply_byte);
            else if (tx_byte_index == 7'd67) begin
                tx_crc_state <= crc32_byte(tx_crc_state, reply_byte);
                tx_fcs <= ~crc32_byte(tx_crc_state, reply_byte);
            end

            if (tx_byte_index == 7'd71) begin
                tx_active <= 1'b0;
                tx_byte_index <= 7'd0;
                ifg_count <= 4'd0;
                arp_replies <= arp_replies + 1'b1;
            end else begin
                tx_byte_index <= tx_byte_index + 1'b1;
            end
        end else if (reply_pending) begin
            if (ifg_count == 4'd11) begin
                reply_pending <= 1'b0;
                tx_active <= 1'b1;
                tx_byte_index <= 7'd1;
                tx_crc_state <= 32'hffff_ffff;
                tx_fcs <= 32'd0;
                gmii_tx_en <= 1'b1;
                gmii_txd <= 8'h55;
            end else begin
                ifg_count <= ifg_count + 1'b1;
            end
        end else begin
            ifg_count <= 4'd0;
        end
    end
end

endmodule
