`timescale 1ns / 1ps

module dataset_udp_tx #(
    parameter [47:0] SOURCE_MAC = 48'h000A3502FEC1,
    parameter [31:0] SOURCE_IP = 32'hC0A80065,
    parameter [31:0] DEST_IP = 32'hC0A80011,
    parameter [15:0] UDP_SOURCE_PORT = 16'd8080,
    parameter [15:0] UDP_DEST_PORT = 16'd8080,
    parameter [7:0] SOURCE_PORT_ID = 8'd1,
    parameter [47:0] STATIC_DEST_MAC = 48'd0,
    parameter integer USE_STATIC_DEST_MAC = 0,
    parameter integer ARP_RETRY_CYCLES = 125000000
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire        link_up,
    input  wire        clear_arp_cache,

    input  wire        packet_meta_valid,
    output wire        packet_meta_ready,
    input  wire [7:0]  packet_type,
    input  wire [7:0]  packet_flags,
    input  wire [31:0] packet_cycle,
    input  wire [15:0] packet_object_id,
    input  wire [15:0] packet_valid_length,
    input  wire [31:0] packet_sequence,
    input  wire [31:0] packet_object_offset,
    input  wire [31:0] packet_object_length,
    input  wire [31:0] packet_object_crc32,

    input  wire        packet_data_valid,
    output wire        packet_data_ready,
    input  wire [7:0]  packet_data,
    input  wire        packet_data_last,

    input  wire        gmii_rx_dv,
    input  wire        gmii_rx_er,
    input  wire [7:0]  gmii_rxd,
    output reg         gmii_tx_en,
    output wire        gmii_tx_er,
    output reg  [7:0]  gmii_txd,

    output reg         arp_resolved,
    output reg  [47:0] resolved_mac,
    output reg         packet_sent,
    output reg  [31:0] arp_request_count,
    output reg  [31:0] udp_packet_count,
    output reg  [31:0] input_error_count
);

localparam integer DATA_BYTES = 1368;
localparam integer UDP_PAYLOAD_BYTES = 1400;
localparam [15:0] UDP_LENGTH = 16'd1408;
localparam [15:0] IP_TOTAL_LENGTH = 16'd1428;
localparam [10:0] UDP_LAST_FRAME_INDEX = 11'd1441;
localparam [10:0] ARP_LAST_FRAME_INDEX = 11'd59;

localparam [2:0] TX_IDLE = 3'd0;
localparam [2:0] TX_PREAMBLE = 3'd1;
localparam [2:0] TX_FRAME = 3'd2;
localparam [2:0] TX_FCS = 3'd3;
localparam [2:0] TX_IFG = 3'd4;

localparam FRAME_ARP = 1'b0;
localparam FRAME_UDP = 1'b1;

reg [11:0] payload_read_addr;
wire [7:0] payload_read_data;

reg [1:0] slot_full;
reg [7:0] slot_type [0:1];
reg [7:0] slot_flags [0:1];
reg [31:0] slot_cycle [0:1];
reg [15:0] slot_object_id [0:1];
reg [15:0] slot_valid_length [0:1];
reg [31:0] slot_sequence [0:1];
reg [31:0] slot_object_offset [0:1];
reg [31:0] slot_object_length [0:1];
reg [31:0] slot_object_crc32 [0:1];
reg [15:0] slot_udp_checksum [0:1];
reg [15:0] slot_ip_checksum [0:1];

reg fill_active;
reg fill_slot;
reg next_fill_slot;
reg [15:0] fill_count;
reg [15:0] fill_expected;
reg [7:0] fill_pending_high;
reg [15:0] fill_checksum_sum;
reg checksum_init_active;
reg [4:0] checksum_init_index;
reg [15:0] checksum_init_word;
reg [15:0] checksum_init_word_reg;
reg checksum_init_primed;

reg [2:0] tx_state;
reg tx_frame_kind;
reg tx_slot;
reg next_tx_slot;
reg [3:0] preamble_index;
reg [10:0] tx_frame_index;
reg [1:0] fcs_index;
reg [3:0] ifg_index;
reg [31:0] tx_crc;
reg [31:0] arp_retry_countdown;

reg rx_active;
reg [7:0] rx_index;
reg rx_bad;
reg [15:0] rx_ethertype;
reg [15:0] rx_arp_opcode;
reg [47:0] rx_sender_mac;
reg [31:0] rx_sender_ip;
reg [31:0] rx_target_ip;

reg [7:0] current_frame_byte;
integer payload_index;

wire selected_fill_slot;
wire selected_tx_slot;
wire fill_last_expected;
wire fill_checksum_add;
wire [15:0] fill_checksum_word;
wire [15:0] fill_checksum_sum_next;
wire [15:0] fill_checksum_unused;
wire [15:0] checksum_init_sum_next;
wire payload_write_enable;
wire want_udp_frame;
wire want_arp_frame;

assign gmii_tx_er = 1'b0;
assign selected_fill_slot = slot_full[next_fill_slot] ?
                            ~next_fill_slot : next_fill_slot;
assign selected_tx_slot = slot_full[next_tx_slot] ?
                          next_tx_slot : ~next_tx_slot;
assign packet_meta_ready = enable && !fill_active &&
                           (slot_full != 2'b11);
assign packet_data_ready = fill_active && !checksum_init_active;
assign fill_last_expected = fill_active &&
                            ((fill_count + 1'b1) == fill_expected);
assign fill_checksum_add = fill_count[0] || fill_last_expected;
assign fill_checksum_word = fill_count[0] ?
                            {fill_pending_high, packet_data} :
                            {packet_data, 8'h00};
assign payload_write_enable = packet_data_valid && packet_data_ready &&
                              (packet_data_last == fill_last_expected);
assign want_udp_frame = enable && link_up && arp_resolved &&
                        (slot_full != 2'b00);
assign want_arp_frame = enable && link_up && !arp_resolved &&
                        (arp_retry_countdown == 0);

internet_checksum u_fill_checksum (
    .sum_in(fill_checksum_sum),
    .word_in(fill_checksum_word),
    .sum_out(fill_checksum_sum_next),
    .checksum_out(fill_checksum_unused)
);

function [15:0] checksum_add;
    input [15:0] sum_in;
    input [15:0] word_in;
    reg [16:0] value;
    begin
        value = {1'b0, sum_in} + {1'b0, word_in};
        checksum_add = value[15:0] + value[16];
    end
endfunction

function [15:0] checksum_finish_udp;
    input [15:0] sum_in;
    reg [15:0] value;
    begin
        value = ~sum_in;
        checksum_finish_udp = (value == 16'h0000) ? 16'hFFFF : value;
    end
endfunction

assign checksum_init_sum_next =
    checksum_add(fill_checksum_sum, checksum_init_word_reg);

always @* begin
    case (checksum_init_index)
        5'd0: checksum_init_word = SOURCE_IP[31:16];
        5'd1: checksum_init_word = SOURCE_IP[15:0];
        5'd2: checksum_init_word = DEST_IP[31:16];
        5'd3: checksum_init_word = DEST_IP[15:0];
        5'd4: checksum_init_word = 16'h0011;
        5'd5: checksum_init_word = UDP_LENGTH;
        5'd6: checksum_init_word = UDP_SOURCE_PORT;
        5'd7: checksum_init_word = UDP_DEST_PORT;
        5'd8: checksum_init_word = UDP_LENGTH;
        5'd9: checksum_init_word = 16'h0000;
        5'd10: checksum_init_word = 16'h4158;
        5'd11: checksum_init_word = 16'h4453;
        5'd12: checksum_init_word = {8'h01, slot_type[fill_slot]};
        5'd13: checksum_init_word = {
            SOURCE_PORT_ID, slot_flags[fill_slot]
        };
        5'd14: checksum_init_word = slot_cycle[fill_slot][31:16];
        5'd15: checksum_init_word = slot_cycle[fill_slot][15:0];
        5'd16: checksum_init_word = slot_object_id[fill_slot];
        5'd17: checksum_init_word = slot_valid_length[fill_slot];
        5'd18: checksum_init_word = slot_sequence[fill_slot][31:16];
        5'd19: checksum_init_word = slot_sequence[fill_slot][15:0];
        5'd20: checksum_init_word = slot_object_offset[fill_slot][31:16];
        5'd21: checksum_init_word = slot_object_offset[fill_slot][15:0];
        5'd22: checksum_init_word = slot_object_length[fill_slot][31:16];
        5'd23: checksum_init_word = slot_object_length[fill_slot][15:0];
        5'd24: checksum_init_word = slot_object_crc32[fill_slot][31:16];
        5'd25: checksum_init_word = slot_object_crc32[fill_slot][15:0];
        default: checksum_init_word = 16'h0000;
    endcase
end

function [15:0] ipv4_checksum;
    input [15:0] identification;
    reg [15:0] sum;
    begin
        sum = 16'd0;
        sum = checksum_add(sum, 16'h4500);
        sum = checksum_add(sum, IP_TOTAL_LENGTH);
        sum = checksum_add(sum, 16'h4000);
        sum = checksum_add(sum, 16'h4011);
        sum = checksum_add(sum, 16'h0000);
        sum = checksum_add(sum, SOURCE_IP[31:16]);
        sum = checksum_add(sum, SOURCE_IP[15:0]);
        sum = checksum_add(sum, DEST_IP[31:16]);
        sum = checksum_add(sum, DEST_IP[15:0]);
        sum = checksum_add(sum, identification);
        ipv4_checksum = ~sum;
    end
endfunction

function [31:0] crc32_byte;
    input [31:0] crc_in;
    input [7:0] data_in;
    integer bit_index;
    reg [31:0] value;
    begin
        value = crc_in;
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
            if (value[0] ^ data_in[bit_index])
                value = (value >> 1) ^ 32'hEDB88320;
            else
                value = value >> 1;
        end
        crc32_byte = value;
    end
endfunction

always @* begin
    current_frame_byte = 8'h00;
    payload_index = 0;

    if (tx_frame_kind == FRAME_ARP) begin
        case (tx_frame_index)
            11'd0, 11'd1, 11'd2, 11'd3, 11'd4, 11'd5:
                current_frame_byte = 8'hFF;
            11'd6: current_frame_byte = SOURCE_MAC[47:40];
            11'd7: current_frame_byte = SOURCE_MAC[39:32];
            11'd8: current_frame_byte = SOURCE_MAC[31:24];
            11'd9: current_frame_byte = SOURCE_MAC[23:16];
            11'd10: current_frame_byte = SOURCE_MAC[15:8];
            11'd11: current_frame_byte = SOURCE_MAC[7:0];
            11'd12: current_frame_byte = 8'h08;
            11'd13: current_frame_byte = 8'h06;
            11'd14: current_frame_byte = 8'h00;
            11'd15: current_frame_byte = 8'h01;
            11'd16: current_frame_byte = 8'h08;
            11'd17: current_frame_byte = 8'h00;
            11'd18: current_frame_byte = 8'h06;
            11'd19: current_frame_byte = 8'h04;
            11'd20: current_frame_byte = 8'h00;
            11'd21: current_frame_byte = 8'h01;
            11'd22: current_frame_byte = SOURCE_MAC[47:40];
            11'd23: current_frame_byte = SOURCE_MAC[39:32];
            11'd24: current_frame_byte = SOURCE_MAC[31:24];
            11'd25: current_frame_byte = SOURCE_MAC[23:16];
            11'd26: current_frame_byte = SOURCE_MAC[15:8];
            11'd27: current_frame_byte = SOURCE_MAC[7:0];
            11'd28: current_frame_byte = SOURCE_IP[31:24];
            11'd29: current_frame_byte = SOURCE_IP[23:16];
            11'd30: current_frame_byte = SOURCE_IP[15:8];
            11'd31: current_frame_byte = SOURCE_IP[7:0];
            11'd38: current_frame_byte = DEST_IP[31:24];
            11'd39: current_frame_byte = DEST_IP[23:16];
            11'd40: current_frame_byte = DEST_IP[15:8];
            11'd41: current_frame_byte = DEST_IP[7:0];
            default: current_frame_byte = 8'h00;
        endcase
    end else begin
        case (tx_frame_index)
            11'd0: current_frame_byte = resolved_mac[47:40];
            11'd1: current_frame_byte = resolved_mac[39:32];
            11'd2: current_frame_byte = resolved_mac[31:24];
            11'd3: current_frame_byte = resolved_mac[23:16];
            11'd4: current_frame_byte = resolved_mac[15:8];
            11'd5: current_frame_byte = resolved_mac[7:0];
            11'd6: current_frame_byte = SOURCE_MAC[47:40];
            11'd7: current_frame_byte = SOURCE_MAC[39:32];
            11'd8: current_frame_byte = SOURCE_MAC[31:24];
            11'd9: current_frame_byte = SOURCE_MAC[23:16];
            11'd10: current_frame_byte = SOURCE_MAC[15:8];
            11'd11: current_frame_byte = SOURCE_MAC[7:0];
            11'd12: current_frame_byte = 8'h08;
            11'd13: current_frame_byte = 8'h00;
            11'd14: current_frame_byte = 8'h45;
            11'd15: current_frame_byte = 8'h00;
            11'd16: current_frame_byte = IP_TOTAL_LENGTH[15:8];
            11'd17: current_frame_byte = IP_TOTAL_LENGTH[7:0];
            11'd18: current_frame_byte = slot_sequence[tx_slot][15:8];
            11'd19: current_frame_byte = slot_sequence[tx_slot][7:0];
            11'd20: current_frame_byte = 8'h40;
            11'd21: current_frame_byte = 8'h00;
            11'd22: current_frame_byte = 8'h40;
            11'd23: current_frame_byte = 8'h11;
            11'd24: current_frame_byte = slot_ip_checksum[tx_slot][15:8];
            11'd25: current_frame_byte = slot_ip_checksum[tx_slot][7:0];
            11'd26: current_frame_byte = SOURCE_IP[31:24];
            11'd27: current_frame_byte = SOURCE_IP[23:16];
            11'd28: current_frame_byte = SOURCE_IP[15:8];
            11'd29: current_frame_byte = SOURCE_IP[7:0];
            11'd30: current_frame_byte = DEST_IP[31:24];
            11'd31: current_frame_byte = DEST_IP[23:16];
            11'd32: current_frame_byte = DEST_IP[15:8];
            11'd33: current_frame_byte = DEST_IP[7:0];
            11'd34: current_frame_byte = UDP_SOURCE_PORT[15:8];
            11'd35: current_frame_byte = UDP_SOURCE_PORT[7:0];
            11'd36: current_frame_byte = UDP_DEST_PORT[15:8];
            11'd37: current_frame_byte = UDP_DEST_PORT[7:0];
            11'd38: current_frame_byte = UDP_LENGTH[15:8];
            11'd39: current_frame_byte = UDP_LENGTH[7:0];
            11'd40: current_frame_byte = slot_udp_checksum[tx_slot][15:8];
            11'd41: current_frame_byte = slot_udp_checksum[tx_slot][7:0];
            11'd42: current_frame_byte = 8'h41;
            11'd43: current_frame_byte = 8'h58;
            11'd44: current_frame_byte = 8'h44;
            11'd45: current_frame_byte = 8'h53;
            11'd46: current_frame_byte = 8'h01;
            11'd47: current_frame_byte = slot_type[tx_slot];
            11'd48: current_frame_byte = SOURCE_PORT_ID;
            11'd49: current_frame_byte = slot_flags[tx_slot];
            11'd50: current_frame_byte = slot_cycle[tx_slot][31:24];
            11'd51: current_frame_byte = slot_cycle[tx_slot][23:16];
            11'd52: current_frame_byte = slot_cycle[tx_slot][15:8];
            11'd53: current_frame_byte = slot_cycle[tx_slot][7:0];
            11'd54: current_frame_byte = slot_object_id[tx_slot][15:8];
            11'd55: current_frame_byte = slot_object_id[tx_slot][7:0];
            11'd56: current_frame_byte = slot_valid_length[tx_slot][15:8];
            11'd57: current_frame_byte = slot_valid_length[tx_slot][7:0];
            11'd58: current_frame_byte = slot_sequence[tx_slot][31:24];
            11'd59: current_frame_byte = slot_sequence[tx_slot][23:16];
            11'd60: current_frame_byte = slot_sequence[tx_slot][15:8];
            11'd61: current_frame_byte = slot_sequence[tx_slot][7:0];
            11'd62: current_frame_byte = slot_object_offset[tx_slot][31:24];
            11'd63: current_frame_byte = slot_object_offset[tx_slot][23:16];
            11'd64: current_frame_byte = slot_object_offset[tx_slot][15:8];
            11'd65: current_frame_byte = slot_object_offset[tx_slot][7:0];
            11'd66: current_frame_byte = slot_object_length[tx_slot][31:24];
            11'd67: current_frame_byte = slot_object_length[tx_slot][23:16];
            11'd68: current_frame_byte = slot_object_length[tx_slot][15:8];
            11'd69: current_frame_byte = slot_object_length[tx_slot][7:0];
            11'd70: current_frame_byte = slot_object_crc32[tx_slot][31:24];
            11'd71: current_frame_byte = slot_object_crc32[tx_slot][23:16];
            11'd72: current_frame_byte = slot_object_crc32[tx_slot][15:8];
            11'd73: current_frame_byte = slot_object_crc32[tx_slot][7:0];
            default: begin
                payload_index = tx_frame_index - 11'd74;
                if ((payload_index >= 0) &&
                    (payload_index < slot_valid_length[tx_slot])) begin
                    current_frame_byte = payload_read_data;
                end else begin
                    current_frame_byte = 8'h00;
                end
            end
        endcase
    end
end

always @* begin
    payload_read_addr = {tx_slot, 11'd0};
    if ((tx_state == TX_FRAME) && (tx_frame_kind == FRAME_UDP) &&
        (tx_frame_index >= 11'd73) &&
        (tx_frame_index < 11'd73 + slot_valid_length[tx_slot])) begin
        payload_read_addr = {
            tx_slot,
            tx_frame_index - 11'd73
        };
    end
end

dataset_pingpong_bram u_payload_buffer (
    .clk(clk),
    .write_enable(payload_write_enable),
    .write_address({fill_slot, fill_count[10:0]}),
    .write_data(packet_data),
    .read_address(payload_read_addr),
    .read_data(payload_read_data)
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_active <= 1'b0;
        rx_index <= 8'd0;
        rx_bad <= 1'b0;
        rx_ethertype <= 16'd0;
        rx_arp_opcode <= 16'd0;
        rx_sender_mac <= 48'd0;
        rx_sender_ip <= 32'd0;
        rx_target_ip <= 32'd0;
        arp_resolved <= USE_STATIC_DEST_MAC != 0;
        resolved_mac <= STATIC_DEST_MAC;
    end else if (!link_up || clear_arp_cache) begin
        rx_active <= 1'b0;
        rx_index <= 8'd0;
        rx_bad <= 1'b0;
        arp_resolved <= USE_STATIC_DEST_MAC != 0;
        resolved_mac <= STATIC_DEST_MAC;
    end else if (gmii_rx_dv) begin
        if (!rx_active) begin
            rx_active <= 1'b1;
            rx_index <= 8'd0;
            rx_bad <= gmii_rx_er || (gmii_rxd != 8'h55);
            rx_ethertype <= 16'd0;
            rx_arp_opcode <= 16'd0;
            rx_sender_mac <= 48'd0;
            rx_sender_ip <= 32'd0;
            rx_target_ip <= 32'd0;
        end else begin
            rx_index <= rx_index + 1'b1;
            if (gmii_rx_er)
                rx_bad <= 1'b1;
            if ((rx_index < 8'd6) && (gmii_rxd != 8'h55))
                rx_bad <= 1'b1;
            if ((rx_index == 8'd6) && (gmii_rxd != 8'hD5))
                rx_bad <= 1'b1;
            case (rx_index + 1'b1)
                8'd20: rx_ethertype[15:8] <= gmii_rxd;
                8'd21: rx_ethertype[7:0] <= gmii_rxd;
                8'd28: rx_arp_opcode[15:8] <= gmii_rxd;
                8'd29: rx_arp_opcode[7:0] <= gmii_rxd;
                8'd30: rx_sender_mac[47:40] <= gmii_rxd;
                8'd31: rx_sender_mac[39:32] <= gmii_rxd;
                8'd32: rx_sender_mac[31:24] <= gmii_rxd;
                8'd33: rx_sender_mac[23:16] <= gmii_rxd;
                8'd34: rx_sender_mac[15:8] <= gmii_rxd;
                8'd35: rx_sender_mac[7:0] <= gmii_rxd;
                8'd36: rx_sender_ip[31:24] <= gmii_rxd;
                8'd37: rx_sender_ip[23:16] <= gmii_rxd;
                8'd38: rx_sender_ip[15:8] <= gmii_rxd;
                8'd39: rx_sender_ip[7:0] <= gmii_rxd;
                8'd46: rx_target_ip[31:24] <= gmii_rxd;
                8'd47: rx_target_ip[23:16] <= gmii_rxd;
                8'd48: rx_target_ip[15:8] <= gmii_rxd;
                8'd49: rx_target_ip[7:0] <= gmii_rxd;
                default: begin end
            endcase
        end
    end else if (rx_active) begin
        rx_active <= 1'b0;
        if (!rx_bad && (rx_index >= 8'd49) &&
            (rx_ethertype == 16'h0806) &&
            (rx_arp_opcode == 16'h0002) &&
            (rx_sender_ip == DEST_IP) &&
            (rx_target_ip == SOURCE_IP)) begin
            arp_resolved <= 1'b1;
            resolved_mac <= rx_sender_mac;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        slot_full <= 2'b00;
        fill_active <= 1'b0;
        fill_slot <= 1'b0;
        next_fill_slot <= 1'b0;
        fill_count <= 16'd0;
        fill_expected <= 16'd0;
        fill_pending_high <= 8'd0;
        fill_checksum_sum <= 16'd0;
        checksum_init_active <= 1'b0;
        checksum_init_index <= 5'd0;
        checksum_init_word_reg <= 16'd0;
        checksum_init_primed <= 1'b0;

        tx_state <= TX_IDLE;
        tx_frame_kind <= FRAME_ARP;
        tx_slot <= 1'b0;
        next_tx_slot <= 1'b0;
        preamble_index <= 4'd0;
        tx_frame_index <= 11'd0;
        fcs_index <= 2'd0;
        ifg_index <= 4'd0;
        tx_crc <= 32'hFFFFFFFF;
        arp_retry_countdown <= 32'd0;

        gmii_tx_en <= 1'b0;
        gmii_txd <= 8'd0;
        packet_sent <= 1'b0;
        arp_request_count <= 32'd0;
        udp_packet_count <= 32'd0;
        input_error_count <= 32'd0;
    end else begin
        packet_sent <= 1'b0;

        if (arp_retry_countdown != 0)
            arp_retry_countdown <= arp_retry_countdown - 1'b1;

        if (packet_meta_valid && packet_meta_ready) begin
            if (packet_valid_length > DATA_BYTES) begin
                input_error_count <= input_error_count + 1'b1;
            end else begin
                fill_slot <= selected_fill_slot;
                next_fill_slot <= ~selected_fill_slot;
                fill_count <= 16'd0;
                fill_expected <= packet_valid_length;
                fill_checksum_sum <= 16'd0;
                checksum_init_active <= 1'b1;
                checksum_init_index <= 5'd0;
                checksum_init_word_reg <= 16'd0;
                checksum_init_primed <= 1'b0;
                slot_type[selected_fill_slot] <= packet_type;
                slot_flags[selected_fill_slot] <= packet_flags;
                slot_cycle[selected_fill_slot] <= packet_cycle;
                slot_object_id[selected_fill_slot] <= packet_object_id;
                slot_valid_length[selected_fill_slot] <= packet_valid_length;
                slot_sequence[selected_fill_slot] <= packet_sequence;
                slot_object_offset[selected_fill_slot] <= packet_object_offset;
                slot_object_length[selected_fill_slot] <= packet_object_length;
                slot_object_crc32[selected_fill_slot] <= packet_object_crc32;
                slot_ip_checksum[selected_fill_slot] <=
                    ipv4_checksum(packet_sequence[15:0]);
                fill_active <= 1'b1;
            end
        end

        if (checksum_init_active) begin
            if (!checksum_init_primed) begin
                checksum_init_word_reg <= checksum_init_word;
                checksum_init_primed <= 1'b1;
                checksum_init_index <= checksum_init_index + 1'b1;
            end else if (checksum_init_index <= 5'd25) begin
                fill_checksum_sum <= checksum_init_sum_next;
                checksum_init_word_reg <= checksum_init_word;
                checksum_init_index <= checksum_init_index + 1'b1;
            end else begin
                fill_checksum_sum <= checksum_init_sum_next;
                checksum_init_active <= 1'b0;
                checksum_init_primed <= 1'b0;
                if (fill_expected == 0) begin
                    slot_udp_checksum[fill_slot] <=
                        checksum_finish_udp(checksum_init_sum_next);
                    slot_full[fill_slot] <= 1'b1;
                    fill_active <= 1'b0;
                end
            end
        end

        if (packet_data_valid && packet_data_ready) begin
            if (packet_data_last != fill_last_expected) begin
                fill_active <= 1'b0;
                slot_full[fill_slot] <= 1'b0;
                input_error_count <= input_error_count + 1'b1;
            end else begin
                if (!fill_count[0])
                    fill_pending_high <= packet_data;
                if (fill_checksum_add)
                    fill_checksum_sum <= fill_checksum_sum_next;

                if (fill_last_expected) begin
                    slot_udp_checksum[fill_slot] <=
                        checksum_finish_udp(fill_checksum_sum_next);
                    slot_full[fill_slot] <= 1'b1;
                    fill_active <= 1'b0;
                end else begin
                    fill_count <= fill_count + 1'b1;
                end
            end
        end

        if (!enable || !link_up) begin
            tx_state <= TX_IDLE;
            gmii_tx_en <= 1'b0;
            gmii_txd <= 8'd0;
            preamble_index <= 4'd0;
            tx_frame_index <= 11'd0;
            fcs_index <= 2'd0;
            ifg_index <= 4'd0;
            arp_retry_countdown <= 32'd0;
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    gmii_tx_en <= 1'b0;
                    gmii_txd <= 8'd0;
                    if (want_udp_frame) begin
                        tx_frame_kind <= FRAME_UDP;
                        tx_slot <= selected_tx_slot;
                        preamble_index <= 4'd0;
                        tx_state <= TX_PREAMBLE;
                    end else if (want_arp_frame) begin
                        tx_frame_kind <= FRAME_ARP;
                        preamble_index <= 4'd0;
                        tx_state <= TX_PREAMBLE;
                    end
                end

                TX_PREAMBLE: begin
                    gmii_tx_en <= 1'b1;
                    gmii_txd <= (preamble_index == 4'd7) ?
                               8'hD5 : 8'h55;
                    if (preamble_index == 4'd7) begin
                        tx_frame_index <= 11'd0;
                        tx_crc <= 32'hFFFFFFFF;
                        tx_state <= TX_FRAME;
                    end else begin
                        preamble_index <= preamble_index + 1'b1;
                    end
                end

                TX_FRAME: begin
                    gmii_tx_en <= 1'b1;
                    gmii_txd <= current_frame_byte;
                    tx_crc <= crc32_byte(tx_crc, current_frame_byte);
                    if ((tx_frame_kind == FRAME_ARP &&
                         tx_frame_index == ARP_LAST_FRAME_INDEX) ||
                        (tx_frame_kind == FRAME_UDP &&
                         tx_frame_index == UDP_LAST_FRAME_INDEX)) begin
                        fcs_index <= 2'd0;
                        tx_state <= TX_FCS;
                    end else begin
                        tx_frame_index <= tx_frame_index + 1'b1;
                    end
                end

                TX_FCS: begin
                    gmii_tx_en <= 1'b1;
                    case (fcs_index)
                        2'd0: gmii_txd <= ~tx_crc[7:0];
                        2'd1: gmii_txd <= ~tx_crc[15:8];
                        2'd2: gmii_txd <= ~tx_crc[23:16];
                        default: gmii_txd <= ~tx_crc[31:24];
                    endcase
                    if (fcs_index == 2'd3) begin
                        if (tx_frame_kind == FRAME_UDP) begin
                            slot_full[tx_slot] <= 1'b0;
                            next_tx_slot <= ~tx_slot;
                            udp_packet_count <= udp_packet_count + 1'b1;
                            packet_sent <= 1'b1;
                        end else begin
                            arp_request_count <= arp_request_count + 1'b1;
                            if (ARP_RETRY_CYCLES > 0)
                                arp_retry_countdown <= ARP_RETRY_CYCLES - 1;
                        end
                        ifg_index <= 4'd0;
                        tx_state <= TX_IFG;
                    end else begin
                        fcs_index <= fcs_index + 1'b1;
                    end
                end

                TX_IFG: begin
                    gmii_tx_en <= 1'b0;
                    gmii_txd <= 8'd0;
                    if (ifg_index == 4'd11) begin
                        if (want_udp_frame) begin
                            tx_frame_kind <= FRAME_UDP;
                            tx_slot <= selected_tx_slot;
                            preamble_index <= 4'd0;
                            tx_state <= TX_PREAMBLE;
                        end else if (want_arp_frame) begin
                            tx_frame_kind <= FRAME_ARP;
                            preamble_index <= 4'd0;
                            tx_state <= TX_PREAMBLE;
                        end else begin
                            tx_state <= TX_IDLE;
                        end
                    end else begin
                        ifg_index <= ifg_index + 1'b1;
                    end
                end

                default: begin
                    tx_state <= TX_IDLE;
                    gmii_tx_en <= 1'b0;
                    gmii_txd <= 8'd0;
                end
            endcase
        end
    end
end

endmodule

module dataset_pingpong_bram (
    input  wire        clk,
    input  wire        write_enable,
    input  wire [11:0] write_address,
    input  wire [7:0]  write_data,
    input  wire [11:0] read_address,
    output reg  [7:0]  read_data
);

(* ram_style = "block" *) reg [7:0] memory [0:4095];

always @(posedge clk) begin
    if (write_enable)
        memory[write_address] <= write_data;
    read_data <= memory[read_address];
end

endmodule
