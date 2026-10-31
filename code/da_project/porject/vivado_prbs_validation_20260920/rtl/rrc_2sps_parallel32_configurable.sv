`timescale 1ns/1ps

module rrc_2sps_parallel32_configurable (
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    in_valid,
    input  logic [15:0]             symbols,
    input  logic                    clear_history,
    input  logic                    config_load,
    input  logic [4:0]              fractional_delay,
    output logic                    out_valid,
    output logic signed [16*32-1:0] samples
);
    import rrc_phase_coeffs_pkg::*;

    logic symbol_history [0:9];
    logic signed [15:0] active_coeff [0:RRC_PHASE_TAPS-1];
    logic signed [15:0] partial_lo_comb [0:31];
    logic signed [15:0] partial_hi_comb [0:31];
    logic signed [15:0] partial_lo_reg [0:31];
    logic signed [15:0] partial_hi_reg [0:31];
    logic partial_valid;
    integer symbol_offset;

    always_comb begin
        for (int sample_index = 0; sample_index < 32; sample_index++) begin
            partial_lo_comb[sample_index] = '0;
            partial_hi_comb[sample_index] = '0;
            for (int tap = 0; tap < RRC_PHASE_TAPS; tap++) begin
                if (((sample_index - tap) & 1) == 0) begin
                    symbol_offset = (sample_index - tap) / 2;
                    if (tap < (RRC_PHASE_TAPS / 2)) begin
                        if (symbol_offset >= 0) begin
                            if (symbols[symbol_offset])
                                partial_lo_comb[sample_index] =
                                    partial_lo_comb[sample_index] + active_coeff[tap];
                            else
                                partial_lo_comb[sample_index] =
                                    partial_lo_comb[sample_index] - active_coeff[tap];
                        end else begin
                            if (symbol_history[10 + symbol_offset])
                                partial_lo_comb[sample_index] =
                                    partial_lo_comb[sample_index] + active_coeff[tap];
                            else
                                partial_lo_comb[sample_index] =
                                    partial_lo_comb[sample_index] - active_coeff[tap];
                        end
                    end else begin
                        if (symbol_offset >= 0) begin
                            if (symbols[symbol_offset])
                                partial_hi_comb[sample_index] =
                                    partial_hi_comb[sample_index] + active_coeff[tap];
                            else
                                partial_hi_comb[sample_index] =
                                    partial_hi_comb[sample_index] - active_coeff[tap];
                        end else begin
                            if (symbol_history[10 + symbol_offset])
                                partial_hi_comb[sample_index] =
                                    partial_hi_comb[sample_index] + active_coeff[tap];
                            else
                                partial_hi_comb[sample_index] =
                                    partial_hi_comb[sample_index] - active_coeff[tap];
                        end
                    end
                end
            end
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < 10; i++)
                symbol_history[i] <= 1'b0;
            for (int tap = 0; tap < RRC_PHASE_TAPS; tap++)
                active_coeff[tap] <= RRC_PHASE_COEFF[0][tap];
            for (int sample = 0; sample < 32; sample++) begin
                partial_lo_reg[sample] <= '0;
                partial_hi_reg[sample] <= '0;
            end
            partial_valid <= 1'b0;
            samples <= '0;
            out_valid <= 1'b0;
        end else begin
            if (config_load) begin
                for (int tap = 0; tap < RRC_PHASE_TAPS; tap++)
                    active_coeff[tap] <=
                        RRC_PHASE_COEFF[fractional_delay][tap];
            end
            if (clear_history) begin
                for (int i = 0; i < 10; i++)
                    symbol_history[i] <= 1'b0;
                for (int sample = 0; sample < 32; sample++) begin
                    partial_lo_reg[sample] <= '0;
                    partial_hi_reg[sample] <= '0;
                end
                partial_valid <= 1'b0;
                samples <= '0;
                out_valid <= 1'b0;
            end else begin
                out_valid <= partial_valid;
                if (partial_valid) begin
                    for (int sample = 0; sample < 32; sample++)
                        samples[sample*16 +: 16] <=
                            partial_lo_reg[sample] + partial_hi_reg[sample];
                end else begin
                    samples <= '0;
                end

                partial_valid <= in_valid;
                if (in_valid) begin
                    for (int sample = 0; sample < 32; sample++) begin
                        partial_lo_reg[sample] <= partial_lo_comb[sample];
                        partial_hi_reg[sample] <= partial_hi_comb[sample];
                    end
                    for (int i = 0; i < 10; i++)
                        symbol_history[i] <= symbols[i + 6];
                end else begin
                    for (int sample = 0; sample < 32; sample++) begin
                        partial_lo_reg[sample] <= '0;
                        partial_hi_reg[sample] <= '0;
                    end
                end
            end
        end
    end
endmodule
