`timescale 1ns/1ps

module dataset_tx_fifo_adapter (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        packet_meta_valid,
    input  wire        packet_meta_ready,
    input  wire [15:0] packet_valid_length,
    output wire        packet_advance,

    input  wire        fifo_empty,
    input  wire [7:0]  fifo_data,
    output wire        fifo_read_enable,

    output wire        packet_data_valid,
    input  wire        packet_data_ready,
    output wire [7:0]  packet_data,
    output wire        packet_data_last
);

reg feeding;
reg [15:0] bytes_remaining;

assign packet_advance = packet_meta_valid && packet_meta_ready;
assign packet_data_valid = feeding && !fifo_empty;
assign packet_data = fifo_data;
assign packet_data_last = feeding && (bytes_remaining == 16'd1);
assign fifo_read_enable = packet_data_valid && packet_data_ready;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        feeding <= 1'b0;
        bytes_remaining <= 16'd0;
    end else begin
        if (packet_advance) begin
            bytes_remaining <= packet_valid_length;
            feeding <= (packet_valid_length != 0);
        end

        if (packet_data_valid && packet_data_ready) begin
            if (bytes_remaining == 16'd1) begin
                bytes_remaining <= 16'd0;
                feeding <= 1'b0;
            end else begin
                bytes_remaining <= bytes_remaining - 1'b1;
            end
        end
    end
end

endmodule
