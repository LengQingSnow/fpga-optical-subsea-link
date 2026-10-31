`timescale 1ns / 1ps

module internet_checksum (
    input  wire [15:0] sum_in,
    input  wire [15:0] word_in,
    output wire [15:0] sum_out,
    output wire [15:0] checksum_out
);

wire [16:0] extended_sum;

assign extended_sum = {1'b0, sum_in} + {1'b0, word_in};
assign sum_out = extended_sum[15:0] + extended_sum[16];
assign checksum_out = ~sum_out;

endmodule
