`timescale 1ns/1ps

module rrc_2sps_parallel32 (
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   in_valid,
    input  logic [15:0]            symbols,
    output logic                   out_valid,
    output logic signed [16*32-1:0] samples
);
    import rrc_coeffs_pkg::*;

    logic symbol_history [0:9];
    logic signed [16*32-1:0] samples_comb;
    integer accum [0:31];
    integer symbol_offset;

    always_comb begin
        samples_comb = '0;
        for (int sample_index = 0; sample_index < 32; sample_index++) begin
            accum[sample_index] = 0;
            for (int tap = 0; tap < RRC_TAPS; tap++) begin
                if (((sample_index - tap) & 1) == 0) begin
                    symbol_offset = (sample_index - tap) / 2;
                    if (symbol_offset >= 0) begin
                        if (symbols[symbol_offset])
                            accum[sample_index] = accum[sample_index] + RRC_COEFF[tap];
                        else
                            accum[sample_index] = accum[sample_index] - RRC_COEFF[tap];
                    end else begin
                        if (symbol_history[10 + symbol_offset])
                            accum[sample_index] = accum[sample_index] + RRC_COEFF[tap];
                        else
                            accum[sample_index] = accum[sample_index] - RRC_COEFF[tap];
                    end
                end
            end
            samples_comb[sample_index*16 +: 16] = accum[sample_index][15:0];
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < 10; i++)
                symbol_history[i] <= 1'b0;
            samples <= '0;
            out_valid <= 1'b0;
        end else begin
            out_valid <= in_valid;
            if (in_valid) begin
                samples <= samples_comb;
                for (int i = 0; i < 10; i++)
                    symbol_history[i] <= symbols[i + 6];
            end else begin
                samples <= '0;
            end
        end
    end
endmodule
