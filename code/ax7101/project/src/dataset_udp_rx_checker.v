`timescale 1ns/1ps

module dataset_udp_rx_checker #(
    parameter [31:0] IMAGE_OBJECT_BYTES = 32'd230400,
    parameter [31:0] WAVEFORM_OBJECT_BYTES = 32'd22400,
    parameter [15:0] IMAGE_OBJECT_COUNT = 16'd45
) (
    input  wire        rx_clk,
    input  wire        rst_n,
    input  wire        gmii_rx_dv,
    input  wire        gmii_rx_er,
    input  wire [7:0]  gmii_rxd,

    output reg  [1:0]  current_source,
    output reg  [31:0] image_good_frames,
    output reg  [31:0] image_good_objects,
    output reg  [31:0] image_fcs_errors,
    output reg  [31:0] image_ip_checksum_errors,
    output reg  [31:0] image_udp_checksum_errors,
    output reg  [31:0] image_header_errors,
    output reg  [31:0] image_sequence_errors,
    output reg  [31:0] image_offset_errors,
    output reg  [31:0] image_object_crc_errors,
    output reg  [31:0] waveform_good_frames,
    output reg  [31:0] waveform_good_objects,
    output reg  [31:0] waveform_fcs_errors,
    output reg  [31:0] waveform_ip_checksum_errors,
    output reg  [31:0] waveform_udp_checksum_errors,
    output reg  [31:0] waveform_header_errors,
    output reg  [31:0] waveform_sequence_errors,
    output reg  [31:0] waveform_offset_errors,
    output reg  [31:0] waveform_object_crc_errors,
    output reg  [31:0] malformed_frames,
    output reg  [31:0] gmii_rx_er_frames,
    output reg         stats_update_toggle
);

localparam [15:0] UDP_PAYLOAD_BYTES = 16'd1400;
localparam [15:0] UDP_LENGTH_BYTES = 16'd1408;
localparam [15:0] IP_TOTAL_BYTES = 16'd1428;
localparam [10:0] EXPECTED_FRAME_BYTES = 11'd1454;
localparam [10:0] FCS_FIRST_BYTE = 11'd1450;

reg in_frame;
reg [10:0] byte_index;
reg preamble_bad;
reg frame_rx_er;
reg [1:0] source_hint;

reg [47:0] destination_mac;
reg [47:0] source_mac;
reg [15:0] ether_type;
reg [7:0] ip_version_ihl;
reg [7:0] ip_tos;
reg [15:0] ip_total_length;
reg [15:0] ip_flags_fragment;
reg [7:0] ip_protocol;
reg [31:0] source_ip;
reg [31:0] destination_ip;
reg [15:0] udp_source_port;
reg [15:0] udp_destination_port;
reg [15:0] udp_length;
reg [15:0] udp_checksum;

reg [31:0] axds_magic;
reg [7:0] axds_version;
reg [7:0] axds_type;
reg [7:0] axds_source;
reg [7:0] axds_flags;
reg [31:0] axds_cycle;
reg [15:0] axds_object_id;
reg [15:0] axds_valid_bytes;
reg [31:0] axds_sequence;
reg [31:0] axds_offset;
reg [31:0] axds_object_length;
reg [31:0] axds_object_crc;

reg [31:0] ethernet_crc_state;
reg [31:0] received_fcs;
reg [31:0] ip_checksum_sum;
reg [7:0] ip_checksum_high;
reg [31:0] udp_checksum_sum;
reg [7:0] udp_checksum_high;
reg [31:0] frame_object_crc_state;

reg [31:0] image_expected_sequence;
reg [31:0] image_expected_offset;
reg [15:0] image_expected_object_id;
reg [31:0] image_expected_cycle;
reg [31:0] image_object_crc_state;

reg [31:0] waveform_expected_sequence;
reg [31:0] waveform_expected_offset;
reg [31:0] waveform_expected_cycle;
reg [31:0] waveform_object_crc_state;

reg        finalize_active;
reg [3:0]  finalize_step;
reg [1:0]  finalize_source;
reg [10:0] finalize_byte_count;
reg [31:0] finalize_udp_sum;

wire [10:0] current_index;
wire fcs_ok;
wire ip_checksum_ok;
wire image_identity_ok;
wire waveform_identity_ok;
wire common_header_ok;
wire source_header_ok;
wire axds_common_ok;
wire object_progress_ok;
wire offset_progress_ok;
wire sequence_ok;
wire object_crc_ok;

assign current_index = in_frame ? byte_index : 11'd0;
assign fcs_ok = (received_fcs == ~ethernet_crc_state);
assign ip_checksum_ok = (fold_checksum(ip_checksum_sum) == 16'hffff);

assign image_identity_ok =
    (destination_mac == 48'h000a_3501_fec1) &&
    (source_mac == 48'h000a_3502_fec1) &&
    (source_ip == 32'hc0a8_0065) &&
    (destination_ip == 32'hc0a8_0011);
assign waveform_identity_ok =
    (destination_mac == 48'h000a_3501_fec2) &&
    (source_mac == 48'h000a_3502_fec2) &&
    (source_ip == 32'hc0a8_0066) &&
    (destination_ip == 32'hc0a8_0012);

assign common_header_ok =
    (ether_type == 16'h0800) &&
    (ip_version_ihl == 8'h45) &&
    (ip_tos == 8'h00) &&
    (ip_total_length == IP_TOTAL_BYTES) &&
    (ip_flags_fragment == 16'h4000) &&
    (ip_protocol == 8'h11) &&
    (udp_source_port == 16'h1f90) &&
    (udp_destination_port == 16'h1f90) &&
    (udp_length == UDP_LENGTH_BYTES);

assign source_header_ok =
    ((source_hint == 2'd1) && image_identity_ok &&
     (axds_type == 8'd1) && (axds_source == 8'd1) &&
     (axds_object_length == IMAGE_OBJECT_BYTES) &&
     (axds_object_id >= 16'd1) &&
     (axds_object_id <= IMAGE_OBJECT_COUNT)) ||
    ((source_hint == 2'd2) && waveform_identity_ok &&
     (axds_type == 8'd2) && (axds_source == 8'd2) &&
     (axds_object_length == WAVEFORM_OBJECT_BYTES) &&
     (axds_object_id == 16'd1));

assign axds_common_ok =
    (axds_magic == 32'h4158_4453) &&
    (axds_version == 8'd1) &&
    (axds_flags[7:2] == 6'd0) &&
    (axds_valid_bytes != 16'd0) &&
    (axds_valid_bytes <= (UDP_PAYLOAD_BYTES - 16'd32)) &&
    ({16'd0, axds_valid_bytes} <= axds_object_length) &&
    common_header_ok &&
    source_header_ok;

assign sequence_ok =
    ((source_hint == 2'd1) &&
     (axds_sequence == image_expected_sequence)) ||
    ((source_hint == 2'd2) &&
     (axds_sequence == waveform_expected_sequence));

assign object_progress_ok =
    ((source_hint == 2'd1) &&
     (axds_object_id == image_expected_object_id) &&
     (axds_cycle == image_expected_cycle)) ||
    ((source_hint == 2'd2) &&
     (axds_object_id == 16'd1) &&
     (axds_cycle == waveform_expected_cycle));

assign offset_progress_ok =
    ((source_hint == 2'd1) &&
     (axds_offset == image_expected_offset) &&
     (axds_flags[0] == (image_expected_offset == 32'd0)) &&
     (axds_flags[1] ==
      ((axds_offset + axds_valid_bytes) == IMAGE_OBJECT_BYTES))) ||
    ((source_hint == 2'd2) &&
     (axds_offset == waveform_expected_offset) &&
     (axds_flags[0] == (waveform_expected_offset == 32'd0)) &&
     (axds_flags[1] ==
      ((axds_offset + axds_valid_bytes) == WAVEFORM_OBJECT_BYTES)));

assign object_crc_ok = (~frame_object_crc_state == axds_object_crc);

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

function [15:0] fold_checksum;
    input [31:0] sum_in;
    reg [31:0] sum;
    begin
        sum = sum_in;
        sum = sum[15:0] + sum[31:16];
        sum = sum[15:0] + sum[31:16];
        fold_checksum = sum[15:0];
    end
endfunction

always @(posedge rx_clk or negedge rst_n) begin
    if (!rst_n) begin
        in_frame <= 1'b0;
        byte_index <= 11'd0;
        preamble_bad <= 1'b0;
        frame_rx_er <= 1'b0;
        source_hint <= 2'd0;
        destination_mac <= 48'd0;
        source_mac <= 48'd0;
        ether_type <= 16'd0;
        ip_version_ihl <= 8'd0;
        ip_tos <= 8'd0;
        ip_total_length <= 16'd0;
        ip_flags_fragment <= 16'd0;
        ip_protocol <= 8'd0;
        source_ip <= 32'd0;
        destination_ip <= 32'd0;
        udp_source_port <= 16'd0;
        udp_destination_port <= 16'd0;
        udp_length <= 16'd0;
        udp_checksum <= 16'd0;
        axds_magic <= 32'd0;
        axds_version <= 8'd0;
        axds_type <= 8'd0;
        axds_source <= 8'd0;
        axds_flags <= 8'd0;
        axds_cycle <= 32'd0;
        axds_object_id <= 16'd0;
        axds_valid_bytes <= 16'd0;
        axds_sequence <= 32'd0;
        axds_offset <= 32'd0;
        axds_object_length <= 32'd0;
        axds_object_crc <= 32'd0;
        ethernet_crc_state <= 32'hffff_ffff;
        received_fcs <= 32'd0;
        ip_checksum_sum <= 32'd0;
        ip_checksum_high <= 8'd0;
        udp_checksum_sum <= 32'd0;
        udp_checksum_high <= 8'd0;
        frame_object_crc_state <= 32'hffff_ffff;

        image_expected_sequence <= 32'd0;
        image_expected_offset <= 32'd0;
        image_expected_object_id <= 16'd1;
        image_expected_cycle <= 32'd0;
        image_object_crc_state <= 32'hffff_ffff;
        waveform_expected_sequence <= 32'd0;
        waveform_expected_offset <= 32'd0;
        waveform_expected_cycle <= 32'd0;
        waveform_object_crc_state <= 32'hffff_ffff;
        finalize_active <= 1'b0;
        finalize_step <= 4'd0;
        finalize_source <= 2'd0;
        finalize_byte_count <= 11'd0;
        finalize_udp_sum <= 32'd0;

        current_source <= 2'd0;
        image_good_frames <= 32'd0;
        image_good_objects <= 32'd0;
        image_fcs_errors <= 32'd0;
        image_ip_checksum_errors <= 32'd0;
        image_udp_checksum_errors <= 32'd0;
        image_header_errors <= 32'd0;
        image_sequence_errors <= 32'd0;
        image_offset_errors <= 32'd0;
        image_object_crc_errors <= 32'd0;
        waveform_good_frames <= 32'd0;
        waveform_good_objects <= 32'd0;
        waveform_fcs_errors <= 32'd0;
        waveform_ip_checksum_errors <= 32'd0;
        waveform_udp_checksum_errors <= 32'd0;
        waveform_header_errors <= 32'd0;
        waveform_sequence_errors <= 32'd0;
        waveform_offset_errors <= 32'd0;
        waveform_object_crc_errors <= 32'd0;
        malformed_frames <= 32'd0;
        gmii_rx_er_frames <= 32'd0;
        stats_update_toggle <= 1'b0;
    end else begin
        if (finalize_active && !gmii_rx_dv) begin
            case (finalize_step)
                4'd0: begin
                    finalize_udp_sum <= finalize_udp_sum +
                                        source_ip[31:16] +
                                        source_ip[15:0];
                    if (frame_rx_er) begin
                        gmii_rx_er_frames <= gmii_rx_er_frames + 1'b1;
                        stats_update_toggle <= ~stats_update_toggle;
                        finalize_active <= 1'b0;
                    end else if (preamble_bad ||
                                 (finalize_byte_count !=
                                  EXPECTED_FRAME_BYTES) ||
                                 (finalize_source == 2'd0)) begin
                        malformed_frames <= malformed_frames + 1'b1;
                        stats_update_toggle <= ~stats_update_toggle;
                        finalize_active <= 1'b0;
                    end else begin
                        current_source <= finalize_source;
                        finalize_step <= 4'd1;
                    end
                end
                4'd1: begin
                    finalize_udp_sum <= finalize_udp_sum +
                                        destination_ip[31:16] +
                                        destination_ip[15:0];
                    if (!fcs_ok) begin
                        if (finalize_source == 2'd1)
                            image_fcs_errors <= image_fcs_errors + 1'b1;
                        else
                            waveform_fcs_errors <=
                                waveform_fcs_errors + 1'b1;
                        stats_update_toggle <= ~stats_update_toggle;
                        finalize_active <= 1'b0;
                    end else begin
                        finalize_step <= 4'd2;
                    end
                end
                4'd2: begin
                    finalize_udp_sum <= finalize_udp_sum +
                                        16'h0011 + udp_length;
                    if (!ip_checksum_ok) begin
                        if (finalize_source == 2'd1)
                            image_ip_checksum_errors <=
                                image_ip_checksum_errors + 1'b1;
                        else
                            waveform_ip_checksum_errors <=
                                waveform_ip_checksum_errors + 1'b1;
                        stats_update_toggle <= ~stats_update_toggle;
                        finalize_active <= 1'b0;
                    end else begin
                        finalize_step <= 4'd3;
                    end
                end
                4'd3: begin
                    if ((udp_checksum == 16'd0) ||
                        (fold_checksum(finalize_udp_sum) != 16'hffff)) begin
                        if (finalize_source == 2'd1)
                            image_udp_checksum_errors <=
                                image_udp_checksum_errors + 1'b1;
                        else
                            waveform_udp_checksum_errors <=
                                waveform_udp_checksum_errors + 1'b1;
                        stats_update_toggle <= ~stats_update_toggle;
                        finalize_active <= 1'b0;
                    end else begin
                        finalize_step <= 4'd4;
                    end
                end
                4'd4: begin
                    if (!axds_common_ok) begin
                        if (finalize_source == 2'd1)
                            image_header_errors <=
                                image_header_errors + 1'b1;
                        else
                            waveform_header_errors <=
                                waveform_header_errors + 1'b1;
                        stats_update_toggle <= ~stats_update_toggle;
                        finalize_active <= 1'b0;
                    end else begin
                        finalize_step <= 4'd5;
                    end
                end
                4'd5: begin
                    if (!object_progress_ok) begin
                        if (finalize_source == 2'd1)
                            image_header_errors <=
                                image_header_errors + 1'b1;
                        else
                            waveform_header_errors <=
                                waveform_header_errors + 1'b1;
                        stats_update_toggle <= ~stats_update_toggle;
                        finalize_active <= 1'b0;
                    end else begin
                        finalize_step <= 4'd6;
                    end
                end
                4'd6: begin
                    if (!sequence_ok) begin
                        if (finalize_source == 2'd1)
                            image_sequence_errors <=
                                image_sequence_errors + 1'b1;
                        else
                            waveform_sequence_errors <=
                                waveform_sequence_errors + 1'b1;
                        stats_update_toggle <= ~stats_update_toggle;
                        finalize_active <= 1'b0;
                    end else begin
                        finalize_step <= 4'd7;
                    end
                end
                4'd7: begin
                    if (!offset_progress_ok) begin
                        if (finalize_source == 2'd1)
                            image_offset_errors <=
                                image_offset_errors + 1'b1;
                        else
                            waveform_offset_errors <=
                                waveform_offset_errors + 1'b1;
                        stats_update_toggle <= ~stats_update_toggle;
                        finalize_active <= 1'b0;
                    end else begin
                        finalize_step <= 4'd8;
                    end
                end
                4'd8: begin
                    stats_update_toggle <= ~stats_update_toggle;
                    finalize_active <= 1'b0;
                    if (axds_flags[1] && !object_crc_ok) begin
                        if (finalize_source == 2'd1)
                            image_object_crc_errors <=
                                image_object_crc_errors + 1'b1;
                        else
                            waveform_object_crc_errors <=
                                waveform_object_crc_errors + 1'b1;
                    end else if (finalize_source == 2'd1) begin
                        image_good_frames <= image_good_frames + 1'b1;
                        image_expected_sequence <=
                            image_expected_sequence + 1'b1;
                        if (axds_flags[1]) begin
                            image_good_objects <=
                                image_good_objects + 1'b1;
                            image_expected_offset <= 32'd0;
                            image_object_crc_state <= 32'hffff_ffff;
                            if (image_expected_object_id ==
                                IMAGE_OBJECT_COUNT) begin
                                image_expected_object_id <= 16'd1;
                                image_expected_cycle <=
                                    image_expected_cycle + 1'b1;
                            end else begin
                                image_expected_object_id <=
                                    image_expected_object_id + 1'b1;
                            end
                        end else begin
                            image_expected_offset <=
                                image_expected_offset + axds_valid_bytes;
                            image_object_crc_state <=
                                frame_object_crc_state;
                        end
                    end else begin
                        waveform_good_frames <=
                            waveform_good_frames + 1'b1;
                        waveform_expected_sequence <=
                            waveform_expected_sequence + 1'b1;
                        if (axds_flags[1]) begin
                            waveform_good_objects <=
                                waveform_good_objects + 1'b1;
                            waveform_expected_offset <= 32'd0;
                            waveform_expected_cycle <=
                                waveform_expected_cycle + 1'b1;
                            waveform_object_crc_state <= 32'hffff_ffff;
                        end else begin
                            waveform_expected_offset <=
                                waveform_expected_offset +
                                axds_valid_bytes;
                            waveform_object_crc_state <=
                                frame_object_crc_state;
                        end
                    end
                end
                default: begin
                    finalize_active <= 1'b0;
                end
            endcase
        end

        if (gmii_rx_dv) begin
            if (!in_frame) begin
                in_frame <= 1'b1;
                byte_index <= 11'd1;
                preamble_bad <= (gmii_rxd != 8'h55);
                frame_rx_er <= gmii_rx_er;
                source_hint <= 2'd0;
                destination_mac <= 48'd0;
                source_mac <= 48'd0;
                ether_type <= 16'd0;
                ip_version_ihl <= 8'd0;
                ip_tos <= 8'd0;
                ip_total_length <= 16'd0;
                ip_flags_fragment <= 16'd0;
                ip_protocol <= 8'd0;
                source_ip <= 32'd0;
                destination_ip <= 32'd0;
                udp_source_port <= 16'd0;
                udp_destination_port <= 16'd0;
                udp_length <= 16'd0;
                udp_checksum <= 16'd0;
                axds_magic <= 32'd0;
                axds_version <= 8'd0;
                axds_type <= 8'd0;
                axds_source <= 8'd0;
                axds_flags <= 8'd0;
                axds_cycle <= 32'd0;
                axds_object_id <= 16'd0;
                axds_valid_bytes <= 16'd0;
                axds_sequence <= 32'd0;
                axds_offset <= 32'd0;
                axds_object_length <= 32'd0;
                axds_object_crc <= 32'd0;
                ethernet_crc_state <= 32'hffff_ffff;
                received_fcs <= 32'd0;
                ip_checksum_sum <= 32'd0;
                ip_checksum_high <= 8'd0;
                udp_checksum_sum <= 32'd0;
                udp_checksum_high <= 8'd0;
                frame_object_crc_state <= 32'hffff_ffff;
            end else begin
                byte_index <= byte_index + 1'b1;
                if (gmii_rx_er)
                    frame_rx_er <= 1'b1;

                if ((current_index >= 11'd1) &&
                    (current_index <= 11'd6) &&
                    (gmii_rxd != 8'h55))
                    preamble_bad <= 1'b1;
                if ((current_index == 11'd7) &&
                    (gmii_rxd != 8'hd5))
                    preamble_bad <= 1'b1;

                if ((current_index >= 11'd8) &&
                    (current_index <= 11'd1449))
                    ethernet_crc_state <=
                        crc32_byte(ethernet_crc_state, gmii_rxd);

                if ((current_index >= 11'd22) &&
                    (current_index <= 11'd41)) begin
                    if (!current_index[0])
                        ip_checksum_high <= gmii_rxd;
                    else
                        ip_checksum_sum <= ip_checksum_sum +
                                           {ip_checksum_high, gmii_rxd};
                end

                if ((current_index >= 11'd42) &&
                    (current_index <= 11'd1449)) begin
                    if (!current_index[0])
                        udp_checksum_high <= gmii_rxd;
                    else
                        udp_checksum_sum <= udp_checksum_sum +
                                            {udp_checksum_high, gmii_rxd};
                end

                case (current_index)
                    8: destination_mac[47:40] <= gmii_rxd;
                    9: destination_mac[39:32] <= gmii_rxd;
                    10: destination_mac[31:24] <= gmii_rxd;
                    11: destination_mac[23:16] <= gmii_rxd;
                    12: destination_mac[15:8] <= gmii_rxd;
                    13: begin
                        destination_mac[7:0] <= gmii_rxd;
                        if (gmii_rxd == 8'hc1)
                            source_hint <= 2'd1;
                        else if (gmii_rxd == 8'hc2)
                            source_hint <= 2'd2;
                    end
                    14: source_mac[47:40] <= gmii_rxd;
                    15: source_mac[39:32] <= gmii_rxd;
                    16: source_mac[31:24] <= gmii_rxd;
                    17: source_mac[23:16] <= gmii_rxd;
                    18: source_mac[15:8] <= gmii_rxd;
                    19: source_mac[7:0] <= gmii_rxd;
                    20: ether_type[15:8] <= gmii_rxd;
                    21: ether_type[7:0] <= gmii_rxd;
                    22: ip_version_ihl <= gmii_rxd;
                    23: ip_tos <= gmii_rxd;
                    24: ip_total_length[15:8] <= gmii_rxd;
                    25: ip_total_length[7:0] <= gmii_rxd;
                    28: ip_flags_fragment[15:8] <= gmii_rxd;
                    29: ip_flags_fragment[7:0] <= gmii_rxd;
                    31: ip_protocol <= gmii_rxd;
                    34: source_ip[31:24] <= gmii_rxd;
                    35: source_ip[23:16] <= gmii_rxd;
                    36: source_ip[15:8] <= gmii_rxd;
                    37: source_ip[7:0] <= gmii_rxd;
                    38: destination_ip[31:24] <= gmii_rxd;
                    39: destination_ip[23:16] <= gmii_rxd;
                    40: destination_ip[15:8] <= gmii_rxd;
                    41: destination_ip[7:0] <= gmii_rxd;
                    42: udp_source_port[15:8] <= gmii_rxd;
                    43: udp_source_port[7:0] <= gmii_rxd;
                    44: udp_destination_port[15:8] <= gmii_rxd;
                    45: udp_destination_port[7:0] <= gmii_rxd;
                    46: udp_length[15:8] <= gmii_rxd;
                    47: udp_length[7:0] <= gmii_rxd;
                    48: udp_checksum[15:8] <= gmii_rxd;
                    49: udp_checksum[7:0] <= gmii_rxd;
                    50: axds_magic[31:24] <= gmii_rxd;
                    51: axds_magic[23:16] <= gmii_rxd;
                    52: axds_magic[15:8] <= gmii_rxd;
                    53: axds_magic[7:0] <= gmii_rxd;
                    54: axds_version <= gmii_rxd;
                    55: axds_type <= gmii_rxd;
                    56: axds_source <= gmii_rxd;
                    57: axds_flags <= gmii_rxd;
                    58: axds_cycle[31:24] <= gmii_rxd;
                    59: axds_cycle[23:16] <= gmii_rxd;
                    60: axds_cycle[15:8] <= gmii_rxd;
                    61: axds_cycle[7:0] <= gmii_rxd;
                    62: axds_object_id[15:8] <= gmii_rxd;
                    63: axds_object_id[7:0] <= gmii_rxd;
                    64: axds_valid_bytes[15:8] <= gmii_rxd;
                    65: axds_valid_bytes[7:0] <= gmii_rxd;
                    66: axds_sequence[31:24] <= gmii_rxd;
                    67: axds_sequence[23:16] <= gmii_rxd;
                    68: axds_sequence[15:8] <= gmii_rxd;
                    69: axds_sequence[7:0] <= gmii_rxd;
                    70: axds_offset[31:24] <= gmii_rxd;
                    71: axds_offset[23:16] <= gmii_rxd;
                    72: axds_offset[15:8] <= gmii_rxd;
                    73: axds_offset[7:0] <= gmii_rxd;
                    74: axds_object_length[31:24] <= gmii_rxd;
                    75: axds_object_length[23:16] <= gmii_rxd;
                    76: axds_object_length[15:8] <= gmii_rxd;
                    77: axds_object_length[7:0] <= gmii_rxd;
                    78: axds_object_crc[31:24] <= gmii_rxd;
                    79: axds_object_crc[23:16] <= gmii_rxd;
                    80: axds_object_crc[15:8] <= gmii_rxd;
                    81: begin
                        axds_object_crc[7:0] <= gmii_rxd;
                        if (axds_flags[0])
                            frame_object_crc_state <= 32'hffff_ffff;
                        else if (source_hint == 2'd1)
                            frame_object_crc_state <= image_object_crc_state;
                        else
                            frame_object_crc_state <=
                                waveform_object_crc_state;
                    end
                    1450: received_fcs[7:0] <= gmii_rxd;
                    1451: received_fcs[15:8] <= gmii_rxd;
                    1452: received_fcs[23:16] <= gmii_rxd;
                    1453: received_fcs[31:24] <= gmii_rxd;
                    default: begin
                    end
                endcase

                if ((current_index >= 11'd82) &&
                    ((current_index - 11'd82) < axds_valid_bytes))
                    frame_object_crc_state <=
                        crc32_byte(frame_object_crc_state, gmii_rxd);
            end
        end else if (in_frame) begin
            in_frame <= 1'b0;
            byte_index <= 11'd0;

            if (ether_type == 16'h0806) begin
                // ARP is handled in parallel by dual_ip_arp_responder.
            end else begin
                finalize_active <= 1'b1;
                finalize_step <= 4'd0;
                finalize_source <= source_hint;
                finalize_byte_count <= byte_index;
                finalize_udp_sum <= udp_checksum_sum;
            end
        end
    end
end

endmodule
