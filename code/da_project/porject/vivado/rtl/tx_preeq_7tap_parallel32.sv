`timescale 1ns/1ps

// Runtime TX FFE on the 8 GS/s, 32-sample parallel stream.
// The 250 MHz clock carries 32 consecutive samples. At 4 Gbaud each tap is
// 0.5 UI, and the seven-tap window spans the centre sample +/-1.5 UI.
// This covers the centre symbol and a finite set of adjacent-symbol samples.
module tx_preeq_7tap_parallel32 #(
    parameter bit BYPASS = 1'b0
) (
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic                         in_valid,
    input  logic                         clear_history,
    input  logic                         config_load,
    input  logic                         bypass,
    input  logic signed [16*7-1:0]       coeffs,
    input  logic signed [16*32-1:0]      in_samples,
    output logic                         out_valid,
    output logic signed [16*32-1:0]      out_samples
);
    localparam int TAP_COUNT = 7;
    localparam int HISTORY_COUNT = 6;
    localparam int CENTER_TAP = 3;

    logic signed [15:0] history [0:HISTORY_COUNT-1];
    logic signed [15:0] sample_reg [0:31];
    logic signed [15:0] history_reg [0:HISTORY_COUNT-1];
    // Keep one coefficient bank local to each component FFE. MAX_FANOUT lets
    // implementation replicate these registers near groups of DSP columns.
    (* MAX_FANOUT = 8 *) logic signed [15:0] coeff_reg [0:TAP_COUNT-1];
    logic signed [15:0] tap_value_comb [0:31][0:TAP_COUNT-1];
    logic signed [40:0] product_comb [0:31][0:TAP_COUNT-1];
    logic signed [40:0] product_reg [0:31][0:TAP_COUNT-1];
    logic signed [40:0] pair_sum_reg [0:31][0:3];
    logic signed [40:0] level1_reg [0:31][0:1];
    logic signed [40:0] total_sum_reg [0:31];
    logic signed [15:0] bypass_stage1 [0:31];
    logic signed [15:0] bypass_stage2 [0:31];
    logic signed [15:0] bypass_stage3 [0:31];
    logic signed [15:0] bypass_stage4 [0:31];
    logic sample_valid;
    logic product_valid;
    logic pair_valid;
    logic level1_valid;
    logic total_valid;

    function automatic logic signed [15:0] saturate_q15(
        input logic signed [40:0] value
    );
        logic signed [40:0] scaled;
        begin
            scaled = value >>> 15;
            if (scaled > 41'sd32767)
                saturate_q15 = 16'sh7fff;
            else if (scaled < -41'sd32768)
                saturate_q15 = 16'sh8000;
            else
                saturate_q15 = scaled[15:0];
        end
    endfunction

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int tap = 0; tap < TAP_COUNT; tap++)
                coeff_reg[tap] <= '0;
        end else if (config_load) begin
            for (int tap = 0; tap < TAP_COUNT; tap++)
                coeff_reg[tap] <= $signed(coeffs[tap*16 +: 16]);
        end
    end

    always_comb begin
        for (int sample_index = 0; sample_index < 32; sample_index++) begin
            for (int tap_index = 0; tap_index < TAP_COUNT; tap_index++) begin
                int source_index;
                int history_index;
                source_index = sample_index - tap_index;
                if (source_index >= 0) begin
                    tap_value_comb[sample_index][tap_index] =
                        sample_reg[source_index];
                end else begin
                    history_index = HISTORY_COUNT + source_index;
                    tap_value_comb[sample_index][tap_index] =
                        history_reg[history_index];
                end
                if (BYPASS)
                    product_comb[sample_index][tap_index] = '0;
                else
                    product_comb[sample_index][tap_index] =
                        $signed(tap_value_comb[sample_index][tap_index]) *
                        $signed(coeff_reg[tap_index]);
            end
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int index = 0; index < HISTORY_COUNT; index++) begin
                history[index] <= '0;
                history_reg[index] <= '0;
            end
            for (int index = 0; index < 32; index++) begin
                sample_reg[index] <= '0;
                for (int tap = 0; tap < TAP_COUNT; tap++)
                    product_reg[index][tap] <= '0;
                for (int pair = 0; pair < 4; pair++)
                    pair_sum_reg[index][pair] <= '0;
                for (int pair = 0; pair < 2; pair++)
                    level1_reg[index][pair] <= '0;
                total_sum_reg[index] <= '0;
                bypass_stage1[index] <= '0;
                bypass_stage2[index] <= '0;
                bypass_stage3[index] <= '0;
                bypass_stage4[index] <= '0;
            end
            sample_valid <= 1'b0;
            product_valid <= 1'b0;
            pair_valid <= 1'b0;
            level1_valid <= 1'b0;
            total_valid <= 1'b0;
            out_valid <= 1'b0;
            out_samples <= '0;
        end else if (clear_history) begin
            for (int index = 0; index < HISTORY_COUNT; index++) begin
                history[index] <= '0;
                history_reg[index] <= '0;
            end
            for (int index = 0; index < 32; index++) begin
                sample_reg[index] <= '0;
                bypass_stage1[index] <= '0;
                bypass_stage2[index] <= '0;
                bypass_stage3[index] <= '0;
                bypass_stage4[index] <= '0;
            end
            sample_valid <= 1'b0;
            product_valid <= 1'b0;
            pair_valid <= 1'b0;
            level1_valid <= 1'b0;
            total_valid <= 1'b0;
            out_valid <= 1'b0;
        end else begin
            out_valid <= total_valid;
            if (total_valid) begin
                for (int index = 0; index < 32; index++) begin
                    if (BYPASS || bypass)
                        out_samples[index*16 +: 16] <= bypass_stage4[index];
                    else
                        out_samples[index*16 +: 16] <=
                            saturate_q15(total_sum_reg[index]);
                end
            end

            total_valid <= level1_valid;
            if (level1_valid) begin
                for (int index = 0; index < 32; index++) begin
                    total_sum_reg[index] <= level1_reg[index][0] +
                                            level1_reg[index][1];
                    bypass_stage4[index] <= bypass_stage3[index];
                end
            end

            level1_valid <= pair_valid;
            if (pair_valid) begin
                for (int index = 0; index < 32; index++) begin
                    level1_reg[index][0] <= pair_sum_reg[index][0] +
                                            pair_sum_reg[index][1];
                    level1_reg[index][1] <= pair_sum_reg[index][2] +
                                            pair_sum_reg[index][3];
                    bypass_stage3[index] <= bypass_stage2[index];
                end
            end

            pair_valid <= product_valid;
            if (product_valid) begin
                for (int index = 0; index < 32; index++) begin
                    for (int pair = 0; pair < 3; pair++)
                        pair_sum_reg[index][pair] <=
                            product_reg[index][pair*2] +
                            product_reg[index][pair*2+1];
                    pair_sum_reg[index][3] <= product_reg[index][6];
                    bypass_stage2[index] <= bypass_stage1[index];
                end
            end

            product_valid <= sample_valid;
            if (sample_valid) begin
                for (int index = 0; index < 32; index++) begin
                    for (int tap = 0; tap < TAP_COUNT; tap++)
                        product_reg[index][tap] <= product_comb[index][tap];
                    bypass_stage1[index] <= tap_value_comb[index][CENTER_TAP];
                end
            end

            sample_valid <= in_valid;
            if (in_valid) begin
                for (int index = 0; index < 32; index++)
                    sample_reg[index] <= $signed(in_samples[index*16 +: 16]);
                for (int index = 0; index < HISTORY_COUNT; index++) begin
                    history_reg[index] <= history[index];
                    history[index] <= $signed(in_samples[(26 + index)*16 +: 16]);
                end
            end
        end
    end
endmodule
