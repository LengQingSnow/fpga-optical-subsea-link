`timescale 1ns / 1ps

module udp_rx_packet_buffer #(
    parameter ADDR_WIDTH = 11,
    parameter FIFO_ADDR_WIDTH = 2
) (
    input                       rx_clk,
    input                       rx_rst_n,
    input                       rx_packet_start,
    input                       rx_payload_wr_en,
    input      [ADDR_WIDTH-1:0] rx_payload_wr_addr,
    input      [7:0]            rx_payload_wr_data,
    input                       rx_packet_commit,
    input                       rx_packet_abort,
    input      [15:0]           rx_payload_length,
    output reg                  overflow_sticky,
    output reg [31:0]           overflow_count,

    input                       tx_clk,
    input                       tx_rst_n,
    input      [ADDR_WIDTH-1:0] tx_payload_rd_addr,
    input                       tx_payload_rd_en,
    output     [7:0]            tx_payload_rd_data,
    output reg                  tx_payload_rd_valid,
    output reg                  tx_packet_valid,
    output reg [15:0]           tx_payload_length,
    input                       tx_packet_done
);

localparam DEPTH = (1 << ADDR_WIDTH);

(* ram_style = "block" *) reg [7:0] payload_bank0 [0:DEPTH-1];
(* ram_style = "block" *) reg [7:0] payload_bank1 [0:DEPTH-1];

reg [1:0] rx_bank_busy;
reg rx_write_active;
reg rx_write_bank;

reg descriptor_wr_en;
reg [16:0] descriptor_wr_data;
wire descriptor_full;
wire descriptor_empty;
wire descriptor_rd_en;
wire [16:0] descriptor_rd_data;
wire descriptor_rd_valid;

reg release_wr_en;
reg release_wr_data;
wire release_full;
wire release_empty;
wire release_rd_en;
wire release_rd_data;
wire release_rd_valid;

reg descriptor_read_pending;
reg tx_active_bank;
reg [7:0] tx_bank0_rd_data;
reg [7:0] tx_bank1_rd_data;

wire rx_free_available;
wire rx_selected_bank;

assign rx_free_available = !rx_bank_busy[0] || !rx_bank_busy[1];
assign rx_selected_bank = rx_bank_busy[0] ? 1'b1 : 1'b0;
assign descriptor_rd_en = !tx_packet_valid && !descriptor_read_pending &&
                          !descriptor_empty;
assign release_rd_en = !release_empty;
assign tx_payload_rd_data = tx_active_bank ? tx_bank1_rd_data :
                                               tx_bank0_rd_data;

async_byte_fifo #(
    .ADDR_WIDTH(FIFO_ADDR_WIDTH),
    .DATA_WIDTH(17)
) descriptor_fifo (
    .wr_clk(rx_clk),
    .wr_rst_n(rx_rst_n),
    .wr_en(descriptor_wr_en),
    .wr_data(descriptor_wr_data),
    .wr_full(descriptor_full),
    .rd_clk(tx_clk),
    .rd_rst_n(tx_rst_n),
    .rd_en(descriptor_rd_en),
    .rd_data(descriptor_rd_data),
    .rd_valid(descriptor_rd_valid),
    .rd_empty(descriptor_empty)
);

async_byte_fifo #(
    .ADDR_WIDTH(FIFO_ADDR_WIDTH),
    .DATA_WIDTH(1)
) release_fifo (
    .wr_clk(tx_clk),
    .wr_rst_n(tx_rst_n),
    .wr_en(release_wr_en),
    .wr_data(release_wr_data),
    .wr_full(release_full),
    .rd_clk(rx_clk),
    .rd_rst_n(rx_rst_n),
    .rd_en(release_rd_en),
    .rd_data(release_rd_data),
    .rd_valid(release_rd_valid),
    .rd_empty(release_empty)
);

always @(posedge rx_clk) begin
    if (rx_payload_wr_en && rx_write_active && !rx_write_bank)
        payload_bank0[rx_payload_wr_addr] <= rx_payload_wr_data;
end

always @(posedge rx_clk) begin
    if (rx_payload_wr_en && rx_write_active && rx_write_bank)
        payload_bank1[rx_payload_wr_addr] <= rx_payload_wr_data;
end

always @(posedge rx_clk or negedge rx_rst_n) begin
    if (!rx_rst_n) begin
        rx_bank_busy <= 2'b00;
        rx_write_active <= 1'b0;
        rx_write_bank <= 1'b0;
        descriptor_wr_en <= 1'b0;
        descriptor_wr_data <= 17'd0;
        overflow_sticky <= 1'b0;
        overflow_count <= 32'd0;
    end else begin
        descriptor_wr_en <= 1'b0;

        if (release_rd_valid)
            rx_bank_busy[release_rd_data] <= 1'b0;

        if (rx_packet_start) begin
            if (rx_free_available && !rx_write_active) begin
                rx_write_active <= 1'b1;
                rx_write_bank <= rx_selected_bank;
                rx_bank_busy[rx_selected_bank] <= 1'b1;
            end else begin
                rx_write_active <= 1'b0;
                overflow_sticky <= 1'b1;
                overflow_count <= overflow_count + 1'b1;
            end
        end

        if (rx_packet_abort && rx_write_active) begin
            rx_bank_busy[rx_write_bank] <= 1'b0;
            rx_write_active <= 1'b0;
        end

        if (rx_packet_commit && rx_write_active) begin
            if (!descriptor_full && rx_payload_length <= DEPTH) begin
                descriptor_wr_en <= 1'b1;
                descriptor_wr_data <= {rx_write_bank, rx_payload_length};
            end else begin
                rx_bank_busy[rx_write_bank] <= 1'b0;
                overflow_sticky <= 1'b1;
                overflow_count <= overflow_count + 1'b1;
            end
            rx_write_active <= 1'b0;
        end
    end
end

always @(posedge tx_clk) begin
    if (tx_payload_rd_en && tx_packet_valid)
        tx_bank0_rd_data <= payload_bank0[tx_payload_rd_addr];
end

always @(posedge tx_clk) begin
    if (tx_payload_rd_en && tx_packet_valid)
        tx_bank1_rd_data <= payload_bank1[tx_payload_rd_addr];
end

always @(posedge tx_clk or negedge tx_rst_n) begin
    if (!tx_rst_n) begin
        descriptor_read_pending <= 1'b0;
        tx_payload_rd_valid <= 1'b0;
        tx_packet_valid <= 1'b0;
        tx_payload_length <= 16'd0;
        tx_active_bank <= 1'b0;
        release_wr_en <= 1'b0;
        release_wr_data <= 1'b0;
    end else begin
        release_wr_en <= 1'b0;
        tx_payload_rd_valid <= tx_payload_rd_en && tx_packet_valid;

        if (descriptor_rd_en)
            descriptor_read_pending <= 1'b1;

        if (descriptor_rd_valid) begin
            descriptor_read_pending <= 1'b0;
            tx_active_bank <= descriptor_rd_data[16];
            tx_payload_length <= descriptor_rd_data[15:0];
            tx_packet_valid <= 1'b1;
        end

        if (tx_packet_done && tx_packet_valid && !release_full) begin
            release_wr_en <= 1'b1;
            release_wr_data <= tx_active_bank;
            tx_packet_valid <= 1'b0;
        end
    end
end

endmodule
