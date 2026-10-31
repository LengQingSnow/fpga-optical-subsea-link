`timescale 1ns / 1ps

module qsfp_loopback_monitor #(
    parameter FIFO_ADDR_WIDTH = 10
) (
    input              tx_clk,
    input              tx_rst_n,
    input      [255:0] tx_tdata,
    input              tx_tvalid,
    input              tx_tready,
    input              tx_tlast,

    input              rx_clk,
    input              rx_rst_n,
    input      [255:0] rx_tdata,
    input      [31:0]  rx_tkeep,
    input              rx_tvalid,
    input              rx_tlast,

    output     [31:0]  tx_frame_count,
    output reg [31:0]  rx_frame_count,
    output reg [31:0]  data_error_count,
    output reg [31:0]  half_swap_error_count,
    output reg [31:0]  boundary_error_count,
    output reg [31:0]  underflow_count,
    output reg [31:0]  idle_frame_count,
    output reg [31:0]  data_frame_count,
    output             reference_overflow_sticky,
    output reg          header_error_sticky,
    output reg [255:0]  expected_data_debug,
    output reg          expected_tlast_debug,
    output reg          expected_valid_debug
);

localparam [63:0] SYNC_WORD = 64'hd5c0_1acf_fc1d_5aa5;

wire tx_take;
wire reference_full;
wire reference_empty;
wire [256:0] reference_read_data;
wire reference_read_valid;
wire reference_read_enable;
reg reference_overflow_tx;
reg [31:0] tx_frame_count_bin;
reg [31:0] tx_frame_count_gray;
(* ASYNC_REG = "TRUE" *) reg [31:0] tx_frame_gray_sync1;
(* ASYNC_REG = "TRUE" *) reg [31:0] tx_frame_gray_sync2;
(* ASYNC_REG = "TRUE" *) reg reference_overflow_sync1;
(* ASYNC_REG = "TRUE" *) reg reference_overflow_sync2;

reg [255:0] rx_data_pipe;
reg [31:0] rx_keep_pipe;
reg rx_last_pipe;
reg expected_at_frame_start;

assign tx_take = tx_tvalid && tx_tready;
assign reference_read_enable = rx_tvalid && !reference_empty;
assign reference_overflow_sticky = reference_overflow_sync2;

function [31:0] gray_to_binary;
    input [31:0] gray;
    integer bit_index;
    begin
        gray_to_binary[31] = gray[31];
        for (bit_index = 30; bit_index >= 0; bit_index = bit_index - 1)
            gray_to_binary[bit_index] = gray_to_binary[bit_index+1] ^ gray[bit_index];
    end
endfunction

assign tx_frame_count = gray_to_binary(tx_frame_gray_sync2);

async_byte_fifo #(
    .ADDR_WIDTH(FIFO_ADDR_WIDTH),
    .DATA_WIDTH(257)
) expected_fifo (
    .wr_clk(tx_clk),
    .wr_rst_n(tx_rst_n),
    .wr_en(tx_take),
    .wr_data({tx_tlast, tx_tdata}),
    .wr_full(reference_full),
    .rd_clk(rx_clk),
    .rd_rst_n(rx_rst_n),
    .rd_en(reference_read_enable),
    .rd_data(reference_read_data),
    .rd_valid(reference_read_valid),
    .rd_empty(reference_empty)
);

always @(posedge tx_clk or negedge tx_rst_n) begin
    if (!tx_rst_n) begin
        reference_overflow_tx <= 1'b0;
        tx_frame_count_bin <= 32'd0;
        tx_frame_count_gray <= 32'd0;
    end else begin
        if (tx_take && reference_full)
            reference_overflow_tx <= 1'b1;
        if (tx_take && tx_tlast) begin
            tx_frame_count_bin <= tx_frame_count_bin + 1'b1;
            tx_frame_count_gray <= ((tx_frame_count_bin + 1'b1) >> 1) ^
                                   (tx_frame_count_bin + 1'b1);
        end
    end
end

always @(posedge rx_clk or negedge rx_rst_n) begin
    if (!rx_rst_n) begin
        tx_frame_gray_sync1 <= 32'd0;
        tx_frame_gray_sync2 <= 32'd0;
        reference_overflow_sync1 <= 1'b0;
        reference_overflow_sync2 <= 1'b0;
    end else begin
        tx_frame_gray_sync1 <= tx_frame_count_gray;
        tx_frame_gray_sync2 <= tx_frame_gray_sync1;
        reference_overflow_sync1 <= reference_overflow_tx;
        reference_overflow_sync2 <= reference_overflow_sync1;
    end
end

always @(posedge rx_clk or negedge rx_rst_n) begin
    if (!rx_rst_n) begin
        rx_data_pipe <= 256'd0;
        rx_keep_pipe <= 32'd0;
        rx_last_pipe <= 1'b0;
        expected_at_frame_start <= 1'b1;
        rx_frame_count <= 32'd0;
        data_error_count <= 32'd0;
        half_swap_error_count <= 32'd0;
        boundary_error_count <= 32'd0;
        underflow_count <= 32'd0;
        idle_frame_count <= 32'd0;
        data_frame_count <= 32'd0;
        header_error_sticky <= 1'b0;
        expected_data_debug <= 256'd0;
        expected_tlast_debug <= 1'b0;
        expected_valid_debug <= 1'b0;
    end else begin
        expected_valid_debug <= reference_read_valid;
        if (rx_tvalid) begin
            rx_data_pipe <= rx_tdata;
            rx_keep_pipe <= rx_tkeep;
            rx_last_pipe <= rx_tlast;
            if (reference_empty)
                underflow_count <= underflow_count + 1'b1;
        end

        if (reference_read_valid) begin
            expected_data_debug <= reference_read_data[255:0];
            expected_tlast_debug <= reference_read_data[256];
            if (reference_read_data[256])
                rx_frame_count <= rx_frame_count + 1'b1;
            if (expected_at_frame_start) begin
                if (rx_data_pipe[255:192] != SYNC_WORD)
                    header_error_sticky <= 1'b1;
                case (rx_data_pipe[183:176])
                    8'h06: idle_frame_count <= idle_frame_count + 1'b1;
                    8'h07: data_frame_count <= data_frame_count + 1'b1;
                    default: header_error_sticky <= 1'b1;
                endcase
            end
            expected_at_frame_start <= reference_read_data[256];
            if (rx_data_pipe != reference_read_data[255:0])
                data_error_count <= data_error_count + 1'b1;
            if ({rx_data_pipe[127:0], rx_data_pipe[255:128]} !=
                reference_read_data[255:0])
                half_swap_error_count <= half_swap_error_count + 1'b1;
            if ((rx_keep_pipe != 32'hffff_ffff) || rx_last_pipe)
                boundary_error_count <= boundary_error_count + 1'b1;
        end
    end
end

endmodule
