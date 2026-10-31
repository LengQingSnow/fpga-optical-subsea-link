`timescale 1ns / 1ps

module debug_counter_cdc #(
    parameter COUNTER_COUNT = 1
) (
    input                              src_clk,
    input                              src_rst_n,
    input      [COUNTER_COUNT*32-1:0]  src_counts,
    input                              dest_clk,
    input                              dest_rst_n,
    output     [COUNTER_COUNT*32-1:0]  dest_counts
);

function [31:0] gray_to_binary;
    input [31:0] gray_value;
    integer bit_index;
    begin
        gray_to_binary[31] = gray_value[31];
        for (bit_index = 30; bit_index >= 0; bit_index = bit_index - 1)
            gray_to_binary[bit_index] = gray_to_binary[bit_index + 1] ^
                                        gray_value[bit_index];
    end
endfunction

genvar counter_index;
generate
    for (counter_index = 0; counter_index < COUNTER_COUNT;
         counter_index = counter_index + 1) begin : g_counter
        reg [31:0] source_gray;
        (* ASYNC_REG = "TRUE" *) reg [31:0] gray_sync1;
        (* ASYNC_REG = "TRUE" *) reg [31:0] gray_sync2;

        always @(posedge src_clk or negedge src_rst_n) begin
            if (!src_rst_n)
                source_gray <= 32'd0;
            else
                source_gray <=
                    src_counts[counter_index*32 +: 32] ^
                    (src_counts[counter_index*32 +: 32] >> 1);
        end

        always @(posedge dest_clk or negedge dest_rst_n) begin
            if (!dest_rst_n) begin
                gray_sync1 <= 32'd0;
                gray_sync2 <= 32'd0;
            end else begin
                gray_sync1 <= source_gray;
                gray_sync2 <= gray_sync1;
            end
        end

        assign dest_counts[counter_index*32 +: 32] =
            gray_to_binary(gray_sync2);
    end
endgenerate

endmodule
