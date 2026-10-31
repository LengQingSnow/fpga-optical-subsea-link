`timescale 1ns/1ps

module prbs31_byte_source #(
    parameter [30:0] SEED = 31'h7fff_ffff
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       restart,
    input  wire       advance,
    output wire [7:0] data
);

reg [30:0] state;

function [7:0] make_byte;
    input [30:0] state_in;
    reg [30:0] value;
    integer bit_index;
    begin
        value = state_in;
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
            make_byte[7-bit_index] = value[30];
            value = {value[29:0], value[30] ^ value[27]};
        end
    end
endfunction

function [30:0] advance_byte;
    input [30:0] state_in;
    reg [30:0] value;
    integer bit_index;
    begin
        value = state_in;
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
            value = {value[29:0], value[30] ^ value[27]};
        advance_byte = value;
    end
endfunction

assign data = make_byte(state);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= SEED;
    else if (restart)
        state <= SEED;
    else if (advance)
        state <= advance_byte(state);
end

endmodule

