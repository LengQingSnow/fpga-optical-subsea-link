`timescale 1ns/1ps

module tb_dpqpsk_bit_mapper;
    logic [63:0] stream_word;
    logic [15:0] xi_symbols;
    logic [15:0] xq_symbols;
    logic [15:0] yi_symbols;
    logic [15:0] yq_symbols;

    dpqpsk_bit_mapper dut (
        .stream_word(stream_word),
        .xi_symbols(xi_symbols),
        .xq_symbols(xq_symbols),
        .yi_symbols(yi_symbols),
        .yq_symbols(yq_symbols)
    );

    initial begin
        stream_word = '0;
        for (int i = 0; i < 16; i++)
            stream_word[63-i*4 -: 4] = i[3:0];
        #1;

        for (int i = 0; i < 16; i++) begin
            if ({xi_symbols[i], xq_symbols[i], yi_symbols[i], yq_symbols[i]} !== i[3:0])
                $fatal(1, "symbol %0d mapping mismatch: %b", i,
                       {xi_symbols[i], xq_symbols[i], yi_symbols[i], yq_symbols[i]});
        end

        $display("PASS: 64-bit stream maps MSB-first to XI/XQ/YI/YQ");
        $finish;
    end
endmodule

