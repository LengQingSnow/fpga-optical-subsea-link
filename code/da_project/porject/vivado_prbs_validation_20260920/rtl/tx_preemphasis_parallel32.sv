`timescale 1ns/1ps

module tx_preemphasis_parallel32 #(
    parameter bit BYPASS = 1'b0,
    parameter logic signed [15:0] COEFF_0 = 16'sd0,
    parameter logic signed [15:0] COEFF_1 = 16'sd0,
    parameter logic signed [15:0] COEFF_2 = 16'sd0,
    parameter logic signed [15:0] COEFF_3 = 16'sd0,
    parameter logic signed [15:0] COEFF_4 = 16'sd32767,
    parameter logic signed [15:0] COEFF_5 = 16'sd0,
    parameter logic signed [15:0] COEFF_6 = 16'sd0,
    parameter logic signed [15:0] COEFF_7 = 16'sd0,
    parameter logic signed [15:0] COEFF_8 = 16'sd0
) (
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    in_valid,
    input  logic                    clear_history,
    input  logic                    bypass,
    input  logic signed [16*32-1:0] in_samples,
    output logic                    out_valid,
    output logic signed [16*32-1:0] out_samples
);
    localparam int TAP_COUNT = 9;
    localparam int HISTORY_COUNT = 16;
    localparam logic signed [15:0] COEFFS [0:TAP_COUNT-1] = '{
        COEFF_0, COEFF_1, COEFF_2, COEFF_3, COEFF_4,
        COEFF_5, COEFF_6, COEFF_7, COEFF_8
    };

    logic signed [15:0] history [0:HISTORY_COUNT-1];
    logic signed [40:0] product_comb [0:31][0:TAP_COUNT-1];
    logic signed [40:0] product_reg [0:31][0:TAP_COUNT-1];
    logic signed [40:0] partial_a_comb [0:31];
    logic signed [40:0] partial_b_comb [0:31];
    logic signed [40:0] partial_a_reg [0:31];
    logic signed [40:0] partial_b_reg [0:31];
    logic signed [15:0] bypass_comb [0:31];
    logic signed [15:0] bypass_pipe_reg [0:31];
    logic signed [15:0] bypass_reg [0:31];
    logic product_valid;
    logic partial_valid;
    logic signed [15:0] sample_value;
    integer sample_index;
    integer tap_index;
    integer source_index;
    integer history_index;

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

    always_comb begin
        for (sample_index = 0; sample_index < 32; sample_index = sample_index + 1) begin
            source_index = sample_index - 8;
            if (source_index >= 0) begin
                bypass_comb[sample_index] =
                    $signed(in_samples[source_index*16 +: 16]);
            end else begin
                history_index = HISTORY_COUNT + source_index;
                bypass_comb[sample_index] = history[history_index];
            end
            for (tap_index = 0; tap_index < TAP_COUNT; tap_index = tap_index + 1)
                product_comb[sample_index][tap_index] = '0;
        end
        sample_value = '0;
        source_index = 0;
        history_index = 0;
        for (sample_index = 0; sample_index < 32; sample_index = sample_index + 1) begin
            if (!BYPASS) begin
                for (tap_index = 0; tap_index < TAP_COUNT; tap_index = tap_index + 1) begin
                    source_index = sample_index - 2 * tap_index;
                    if (source_index >= 0) begin
                        sample_value = $signed(in_samples[source_index*16 +: 16]);
                    end else begin
                        history_index = HISTORY_COUNT + source_index;
                        sample_value = history[history_index];
                    end
                    product_comb[sample_index][tap_index] =
                        sample_value * COEFFS[tap_index];
                end
            end
        end
        // The multiplier results are registered before the two partial sums.
        // This lets Vivado use the DSP MREG/PREG stages instead of placing a
        // wide multiply-and-add cone directly on the 250 MHz RRC output.
        for (sample_index = 0; sample_index < 32; sample_index = sample_index + 1) begin
            partial_a_comb[sample_index] = '0;
            partial_b_comb[sample_index] = '0;
            for (tap_index = 0; tap_index < TAP_COUNT; tap_index = tap_index + 1) begin
                if (tap_index < 5)
                    partial_a_comb[sample_index] = partial_a_comb[sample_index] +
                        product_reg[sample_index][tap_index];
                else
                    partial_b_comb[sample_index] = partial_b_comb[sample_index] +
                        product_reg[sample_index][tap_index];
            end
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (integer index = 0; index < HISTORY_COUNT; index = index + 1)
                history[index] <= '0;
            product_valid <= 1'b0;
            partial_valid <= 1'b0;
            out_samples <= '0;
            out_valid <= 1'b0;
        end else if (clear_history) begin
            // Valid gating flushes the pipeline. Data registers intentionally
            // retain their values to avoid a wide reset fanout on clk250.
            for (integer index = 0; index < HISTORY_COUNT; index = index + 1)
                history[index] <= '0;
            product_valid <= 1'b0;
            partial_valid <= 1'b0;
            out_valid <= 1'b0;
        end else begin
            out_valid <= partial_valid;
            if (partial_valid) begin
                for (integer index = 0; index < 32; index = index + 1) begin
                    if (BYPASS || bypass)
                        out_samples[index*16 +: 16] <= bypass_reg[index];
                    else
                        out_samples[index*16 +: 16] <= saturate_q15(
                            partial_a_reg[index] + partial_b_reg[index]);
                end
            end else begin
                out_samples <= '0;
            end
            partial_valid <= product_valid;
            product_valid <= in_valid;
            if (product_valid) begin
                for (integer index = 0; index < 32; index = index + 1) begin
                    partial_a_reg[index] <= partial_a_comb[index];
                    partial_b_reg[index] <= partial_b_comb[index];
                    bypass_reg[index] <= bypass_pipe_reg[index];
                end
            end else begin
                for (integer index = 0; index < 32; index = index + 1) begin
                    partial_a_reg[index] <= '0;
                    partial_b_reg[index] <= '0;
                    bypass_reg[index] <= '0;
                end
            end
            if (in_valid) begin
                for (integer index = 0; index < 32; index = index + 1) begin
                    for (integer tap = 0; tap < TAP_COUNT; tap = tap + 1)
                        product_reg[index][tap] <= product_comb[index][tap];
                    bypass_pipe_reg[index] <= bypass_comb[index];
                end
                for (integer index = 0; index < HISTORY_COUNT; index = index + 1)
                    history[index] <= $signed(in_samples[(16 + index)*16 +: 16]);
            end else begin
                for (integer index = 0; index < 32; index = index + 1) begin
                    for (integer tap = 0; tap < TAP_COUNT; tap = tap + 1)
                        product_reg[index][tap] <= '0;
                    bypass_pipe_reg[index] <= '0;
                end
            end
        end
    end
endmodule
