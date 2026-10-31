`timescale 1ns/1ps

module gmii_prbs31_rx_checker (
    input  wire        rx_clk,
    input  wire        rst_n,
    input  wire        gmii_rx_dv,
    input  wire        gmii_rx_er,
    input  wire [7:0]  gmii_rxd,

    output reg  [1:0]  current_source,
    output reg  [31:0] good_frames_1,
    output reg  [31:0] good_frames_2,
    output reg  [31:0] good_frames_3,
    output reg  [31:0] fcs_errors_1,
    output reg  [31:0] fcs_errors_2,
    output reg  [31:0] fcs_errors_3,
    output reg  [31:0] sequence_errors_1,
    output reg  [31:0] sequence_errors_2,
    output reg  [31:0] sequence_errors_3,
    output reg  [63:0] bit_errors_1,
    output reg  [63:0] bit_errors_2,
    output reg  [63:0] bit_errors_3,
    output reg  [63:0] bits_checked_1,
    output reg  [63:0] bits_checked_2,
    output reg  [63:0] bits_checked_3,
    output reg  [31:0] malformed_frames,
    output reg  [31:0] gmii_rx_er_frames,
    output reg         stats_update_toggle
);

localparam integer FRAME_BYTES = 1526;
localparam integer CRC_FIRST_BYTE = 8;
localparam integer CRC_LAST_BYTE = 1521;
localparam integer PRBS_FIRST_BYTE = 38;
localparam integer PRBS_LAST_BYTE = 1521;

reg in_frame;
reg [10:0] byte_index;
reg header_bad;
reg frame_rx_er;
reg [7:0] source_mac_port;
reg [7:0] header_source_port;
reg [31:0] received_sequence;
reg [31:0] received_fcs;
reg [63:0] frame_bit_errors;
reg [63:0] frame_bits_checked;

reg sequence_seen_1;
reg sequence_seen_2;
reg sequence_seen_3;
reg [31:0] expected_sequence_1;
reg [31:0] expected_sequence_2;
reg [31:0] expected_sequence_3;

wire [10:0] current_index;
wire crc_init;
wire crc_enable;
wire [31:0] crc_state;
wire prbs_restart;
wire prbs_advance;
wire [7:0] expected_prbs_data;
wire [7:0] prbs_difference;

assign current_index = in_frame ? byte_index : 11'd0;
assign crc_init = gmii_rx_dv && (current_index == 11'd7);
assign crc_enable = gmii_rx_dv &&
                    (current_index >= CRC_FIRST_BYTE) &&
                    (current_index <= CRC_LAST_BYTE);
assign prbs_restart = gmii_rx_dv && (current_index == 11'd37);
assign prbs_advance = gmii_rx_dv &&
                      (current_index >= PRBS_FIRST_BYTE) &&
                      (current_index <= PRBS_LAST_BYTE);
assign prbs_difference = gmii_rxd ^ expected_prbs_data;

eth_crc32_8 crc_checker (
    .clk(rx_clk),
    .rst_n(rst_n),
    .init(crc_init),
    .enable(crc_enable),
    .data(gmii_rxd),
    .crc(crc_state)
);

prbs31_byte_source expected_prbs (
    .clk(rx_clk),
    .rst_n(rst_n),
    .restart(prbs_restart),
    .advance(prbs_advance),
    .data(expected_prbs_data)
);

function [3:0] popcount8;
    input [7:0] value;
    integer bit_index;
    begin
        popcount8 = 4'd0;
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
            popcount8 = popcount8 + value[bit_index];
    end
endfunction

function [31:0] sequence_gap;
    input [31:0] received;
    input [31:0] expected;
    begin
        if (received > expected)
            sequence_gap = received - expected;
        else if (received != expected)
            sequence_gap = 32'd1;
        else
            sequence_gap = 32'd0;
    end
endfunction

always @(posedge rx_clk or negedge rst_n) begin
    if (!rst_n) begin
        in_frame <= 1'b0;
        byte_index <= 11'd0;
        header_bad <= 1'b0;
        frame_rx_er <= 1'b0;
        source_mac_port <= 8'd0;
        header_source_port <= 8'd0;
        received_sequence <= 32'd0;
        received_fcs <= 32'd0;
        frame_bit_errors <= 64'd0;
        frame_bits_checked <= 64'd0;

        sequence_seen_1 <= 1'b0;
        sequence_seen_2 <= 1'b0;
        sequence_seen_3 <= 1'b0;
        expected_sequence_1 <= 32'd0;
        expected_sequence_2 <= 32'd0;
        expected_sequence_3 <= 32'd0;

        current_source <= 2'd0;
        good_frames_1 <= 32'd0;
        good_frames_2 <= 32'd0;
        good_frames_3 <= 32'd0;
        fcs_errors_1 <= 32'd0;
        fcs_errors_2 <= 32'd0;
        fcs_errors_3 <= 32'd0;
        sequence_errors_1 <= 32'd0;
        sequence_errors_2 <= 32'd0;
        sequence_errors_3 <= 32'd0;
        bit_errors_1 <= 64'd0;
        bit_errors_2 <= 64'd0;
        bit_errors_3 <= 64'd0;
        bits_checked_1 <= 64'd0;
        bits_checked_2 <= 64'd0;
        bits_checked_3 <= 64'd0;
        malformed_frames <= 32'd0;
        gmii_rx_er_frames <= 32'd0;
        stats_update_toggle <= 1'b0;
    end else begin
        if (gmii_rx_dv) begin
            if (!in_frame) begin
                in_frame <= 1'b1;
                byte_index <= 11'd1;
                header_bad <= (gmii_rxd != 8'h55);
                frame_rx_er <= gmii_rx_er;
                source_mac_port <= 8'd0;
                header_source_port <= 8'd0;
                received_sequence <= 32'd0;
                received_fcs <= 32'd0;
                frame_bit_errors <= 64'd0;
                frame_bits_checked <= 64'd0;
            end else begin
                byte_index <= byte_index + 1'b1;
                if (gmii_rx_er)
                    frame_rx_er <= 1'b1;

                case (current_index)
                    1, 2, 3, 4, 5, 6:
                        if (gmii_rxd != 8'h55)
                            header_bad <= 1'b1;
                    7:
                        if (gmii_rxd != 8'hd5)
                            header_bad <= 1'b1;
                    8:
                        if (gmii_rxd != 8'h02)
                            header_bad <= 1'b1;
                    9, 10, 11, 12:
                        if (gmii_rxd != 8'h00)
                            header_bad <= 1'b1;
                    13:
                        if (gmii_rxd != 8'h04)
                            header_bad <= 1'b1;
                    14:
                        if (gmii_rxd != 8'h02)
                            header_bad <= 1'b1;
                    15, 16, 17, 18:
                        if (gmii_rxd != 8'h00)
                            header_bad <= 1'b1;
                    19:
                        source_mac_port <= gmii_rxd;
                    20:
                        if (gmii_rxd != 8'h88)
                            header_bad <= 1'b1;
                    21:
                        if (gmii_rxd != 8'hb5)
                            header_bad <= 1'b1;
                    22:
                        if (gmii_rxd != 8'h41)
                            header_bad <= 1'b1;
                    23:
                        if (gmii_rxd != 8'h58)
                            header_bad <= 1'b1;
                    24:
                        if (gmii_rxd != 8'h37)
                            header_bad <= 1'b1;
                    25:
                        if (gmii_rxd != 8'h31)
                            header_bad <= 1'b1;
                    26:
                        if (gmii_rxd != 8'h01)
                            header_bad <= 1'b1;
                    27: begin
                        header_source_port <= gmii_rxd;
                        if (gmii_rxd != source_mac_port)
                            header_bad <= 1'b1;
                    end
                    28:
                        if (gmii_rxd != 8'h00)
                            header_bad <= 1'b1;
                    29:
                        if (gmii_rxd != 8'h10)
                            header_bad <= 1'b1;
                    30:
                        received_sequence[31:24] <= gmii_rxd;
                    31:
                        received_sequence[23:16] <= gmii_rxd;
                    32:
                        received_sequence[15:8] <= gmii_rxd;
                    33:
                        received_sequence[7:0] <= gmii_rxd;
                    34:
                        if (gmii_rxd != 8'h05)
                            header_bad <= 1'b1;
                    35:
                        if (gmii_rxd != 8'hcc)
                            header_bad <= 1'b1;
                    36, 37:
                        if (gmii_rxd != 8'h00)
                            header_bad <= 1'b1;
                    1522:
                        received_fcs[7:0] <= gmii_rxd;
                    1523:
                        received_fcs[15:8] <= gmii_rxd;
                    1524:
                        received_fcs[23:16] <= gmii_rxd;
                    1525:
                        received_fcs[31:24] <= gmii_rxd;
                    default: begin
                    end
                endcase

                if ((current_index >= PRBS_FIRST_BYTE) &&
                    (current_index <= PRBS_LAST_BYTE)) begin
                    frame_bit_errors <= frame_bit_errors +
                                        popcount8(prbs_difference);
                    frame_bits_checked <= frame_bits_checked + 4'd8;
                end
            end
        end else if (in_frame) begin
            in_frame <= 1'b0;
            byte_index <= 11'd0;
            stats_update_toggle <= ~stats_update_toggle;

            if (frame_rx_er)
                gmii_rx_er_frames <= gmii_rx_er_frames + 1'b1;

            if (header_bad ||
                (byte_index != FRAME_BYTES) ||
                (source_mac_port < 8'd1) ||
                (source_mac_port > 8'd3) ||
                (header_source_port != source_mac_port)) begin
                malformed_frames <= malformed_frames + 1'b1;
            end else begin
                current_source <= source_mac_port[1:0];
                case (source_mac_port)
                    8'd1: begin
                        bit_errors_1 <= bit_errors_1 + frame_bit_errors;
                        bits_checked_1 <= bits_checked_1 + frame_bits_checked;
                        if (received_fcs == ~crc_state && !frame_rx_er)
                            good_frames_1 <= good_frames_1 + 1'b1;
                        else if (received_fcs != ~crc_state)
                            fcs_errors_1 <= fcs_errors_1 + 1'b1;

                        if (sequence_seen_1)
                            sequence_errors_1 <= sequence_errors_1 +
                                sequence_gap(received_sequence,
                                             expected_sequence_1);
                        sequence_seen_1 <= 1'b1;
                        expected_sequence_1 <= received_sequence + 1'b1;
                    end

                    8'd2: begin
                        bit_errors_2 <= bit_errors_2 + frame_bit_errors;
                        bits_checked_2 <= bits_checked_2 + frame_bits_checked;
                        if (received_fcs == ~crc_state && !frame_rx_er)
                            good_frames_2 <= good_frames_2 + 1'b1;
                        else if (received_fcs != ~crc_state)
                            fcs_errors_2 <= fcs_errors_2 + 1'b1;

                        if (sequence_seen_2)
                            sequence_errors_2 <= sequence_errors_2 +
                                sequence_gap(received_sequence,
                                             expected_sequence_2);
                        sequence_seen_2 <= 1'b1;
                        expected_sequence_2 <= received_sequence + 1'b1;
                    end

                    8'd3: begin
                        bit_errors_3 <= bit_errors_3 + frame_bit_errors;
                        bits_checked_3 <= bits_checked_3 + frame_bits_checked;
                        if (received_fcs == ~crc_state && !frame_rx_er)
                            good_frames_3 <= good_frames_3 + 1'b1;
                        else if (received_fcs != ~crc_state)
                            fcs_errors_3 <= fcs_errors_3 + 1'b1;

                        if (sequence_seen_3)
                            sequence_errors_3 <= sequence_errors_3 +
                                sequence_gap(received_sequence,
                                             expected_sequence_3);
                        sequence_seen_3 <= 1'b1;
                        expected_sequence_3 <= received_sequence + 1'b1;
                    end

                    default: begin
                    end
                endcase
            end
        end
    end
end

endmodule
