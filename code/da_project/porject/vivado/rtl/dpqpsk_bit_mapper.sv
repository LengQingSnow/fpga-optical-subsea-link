`timescale 1ns/1ps

module dpqpsk_bit_mapper (
    input  logic [63:0] stream_word,
    output logic [15:0] xi_symbols,
    output logic [15:0] xq_symbols,
    output logic [15:0] yi_symbols,
    output logic [15:0] yq_symbols
);
    always_comb begin
        for (int symbol = 0; symbol < 16; symbol++) begin
            xi_symbols[symbol] = stream_word[63-symbol*4];
            xq_symbols[symbol] = stream_word[62-symbol*4];
            yi_symbols[symbol] = stream_word[61-symbol*4];
            yq_symbols[symbol] = stream_word[60-symbol*4];
        end
    end
endmodule

