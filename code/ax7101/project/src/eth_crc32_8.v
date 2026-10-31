`timescale 1ns/1ps

module eth_crc32_8 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        init,
    input  wire        enable,
    input  wire [7:0]  data,
    output reg  [31:0] crc
);

function [31:0] crc32_byte;
    input [31:0] crc_in;
    input [7:0] data_in;
    reg [31:0] value;
    integer bit_index;
    begin
        value = crc_in;
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
            if (value[0] ^ data_in[bit_index])
                value = (value >> 1) ^ 32'hedb8_8320;
            else
                value = value >> 1;
        end
        crc32_byte = value;
    end
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        crc <= 32'hffff_ffff;
    else if (init)
        crc <= 32'hffff_ffff;
    else if (enable)
        crc <= crc32_byte(crc, data);
end

endmodule

