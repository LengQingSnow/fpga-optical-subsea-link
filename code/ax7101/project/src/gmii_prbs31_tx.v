`timescale 1ns/1ps

module gmii_prbs31_tx #(
    parameter integer SOURCE_PORT = 1
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    output reg         gmii_tx_en,
    output wire        gmii_tx_er,
    output reg  [7:0]  gmii_txd,
    output reg  [31:0] frame_sequence,
    output reg  [31:0] frame_count
);

localparam [1:0] STATE_IDLE  = 2'd0;
localparam [1:0] STATE_FRAME = 2'd1;
localparam [1:0] STATE_IFG   = 2'd2;

localparam integer FRAME_LAST_BYTE = 1525;
localparam integer CRC_FIRST_BYTE  = 8;
localparam integer CRC_LAST_BYTE   = 1521;
localparam integer PRBS_FIRST_BYTE = 38;
localparam integer PRBS_LAST_BYTE  = 1521;

reg [1:0] state;
reg [10:0] byte_index;
reg [3:0] ifg_count;

wire [7:0] prbs_data;
wire prbs_restart;
wire prbs_advance;
wire crc_init;
wire crc_enable;
wire [31:0] crc_state;
wire [31:0] transmitted_fcs;
wire [7:0] frame_data;

assign gmii_tx_er = 1'b0;
assign prbs_restart = (state == STATE_FRAME) && (byte_index == 11'd37);
assign prbs_advance = (state == STATE_FRAME) &&
                      (byte_index >= PRBS_FIRST_BYTE) &&
                      (byte_index <= PRBS_LAST_BYTE);
assign crc_init = (state == STATE_FRAME) && (byte_index == 11'd7);
assign crc_enable = (state == STATE_FRAME) &&
                    (byte_index >= CRC_FIRST_BYTE) &&
                    (byte_index <= CRC_LAST_BYTE);
assign transmitted_fcs = ~crc_state;

prbs31_byte_source prbs_source (
    .clk(clk),
    .rst_n(rst_n),
    .restart(prbs_restart),
    .advance(prbs_advance),
    .data(prbs_data)
);

eth_crc32_8 crc_generator (
    .clk(clk),
    .rst_n(rst_n),
    .init(crc_init),
    .enable(crc_enable),
    .data(frame_data),
    .crc(crc_state)
);

function [7:0] select_frame_byte;
    input [10:0] index;
    input [31:0] frame_seq;
    input [7:0] prbs_byte;
    input [31:0] fcs;
    begin
        case (index)
            0, 1, 2, 3, 4, 5, 6:
                select_frame_byte = 8'h55;
            7:
                select_frame_byte = 8'hd5;
            8:
                select_frame_byte = 8'h02;
            9, 10, 11, 12:
                select_frame_byte = 8'h00;
            13:
                select_frame_byte = 8'h04;
            14:
                select_frame_byte = 8'h02;
            15, 16, 17, 18:
                select_frame_byte = 8'h00;
            19:
                select_frame_byte = SOURCE_PORT[7:0];
            20:
                select_frame_byte = 8'h88;
            21:
                select_frame_byte = 8'hb5;
            22:
                select_frame_byte = 8'h41;
            23:
                select_frame_byte = 8'h58;
            24:
                select_frame_byte = 8'h37;
            25:
                select_frame_byte = 8'h31;
            26:
                select_frame_byte = 8'h01;
            27:
                select_frame_byte = SOURCE_PORT[7:0];
            28:
                select_frame_byte = 8'h00;
            29:
                select_frame_byte = 8'h10;
            30:
                select_frame_byte = frame_seq[31:24];
            31:
                select_frame_byte = frame_seq[23:16];
            32:
                select_frame_byte = frame_seq[15:8];
            33:
                select_frame_byte = frame_seq[7:0];
            34:
                select_frame_byte = 8'h05;
            35:
                select_frame_byte = 8'hcc;
            36, 37:
                select_frame_byte = 8'h00;
            1522:
                select_frame_byte = fcs[7:0];
            1523:
                select_frame_byte = fcs[15:8];
            1524:
                select_frame_byte = fcs[23:16];
            1525:
                select_frame_byte = fcs[31:24];
            default:
                if ((index >= PRBS_FIRST_BYTE) &&
                    (index <= PRBS_LAST_BYTE))
                    select_frame_byte = prbs_byte;
                else
                    select_frame_byte = 8'h00;
        endcase
    end
endfunction

assign frame_data = select_frame_byte(
    byte_index,
    frame_sequence,
    prbs_data,
    transmitted_fcs
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= STATE_IDLE;
        byte_index <= 11'd0;
        ifg_count <= 4'd0;
        gmii_tx_en <= 1'b0;
        gmii_txd <= 8'd0;
        frame_sequence <= 32'd0;
        frame_count <= 32'd0;
    end else if (!enable) begin
        state <= STATE_IDLE;
        byte_index <= 11'd0;
        ifg_count <= 4'd0;
        gmii_tx_en <= 1'b0;
        gmii_txd <= 8'd0;
    end else begin
        case (state)
            STATE_IDLE: begin
                state <= STATE_FRAME;
                byte_index <= 11'd0;
                ifg_count <= 4'd0;
                gmii_tx_en <= 1'b0;
                gmii_txd <= 8'd0;
            end

            STATE_FRAME: begin
                gmii_tx_en <= 1'b1;
                gmii_txd <= frame_data;
                if (byte_index == FRAME_LAST_BYTE) begin
                    state <= STATE_IFG;
                    byte_index <= 11'd0;
                    ifg_count <= 4'd0;
                    frame_sequence <= frame_sequence + 1'b1;
                    frame_count <= frame_count + 1'b1;
                end else begin
                    byte_index <= byte_index + 1'b1;
                end
            end

            STATE_IFG: begin
                gmii_tx_en <= 1'b0;
                gmii_txd <= 8'd0;
                if (ifg_count == 4'd11) begin
                    state <= STATE_FRAME;
                    byte_index <= 11'd0;
                    ifg_count <= 4'd0;
                end else begin
                    ifg_count <= ifg_count + 1'b1;
                end
            end

            default: begin
                state <= STATE_IDLE;
                gmii_tx_en <= 1'b0;
                gmii_txd <= 8'd0;
            end
        endcase
    end
end

endmodule
