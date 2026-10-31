`timescale 1ns/1ps

// Resource-reduced measured TX pre-emphasis. The three non-zero taps are
// delayed by 6, 8 and 10 samples (2 samples/symbol at the 250 MHz stage).
// The centre coefficient, 32767/32768, is implemented as x - x/32768 so it
// does not consume a DSP48. Two side taps remain fully pipelined multiplies.
module tx_preemphasis_3tap_parallel32 #(
    parameter bit BYPASS = 1'b0,
    parameter logic signed [15:0] COEFF_PRE = -16'sd1642,
    parameter logic signed [15:0] COEFF_POST = -16'sd3569
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
    localparam int HISTORY_COUNT = 16;

    logic signed [15:0] history [0:HISTORY_COUNT-1];
    logic signed [15:0] pre_value_comb [0:31];
    logic signed [15:0] center_value_comb [0:31];
    logic signed [15:0] post_value_comb [0:31];
    logic signed [15:0] bypass_comb [0:31];
    logic signed [40:0] pre_product_comb [0:31];
    logic signed [40:0] post_product_comb [0:31];
    logic signed [40:0] center_product_comb [0:31];
    logic signed [40:0] pre_product_reg [0:31];
    logic signed [40:0] post_product_reg [0:31];
    logic signed [40:0] center_product_reg [0:31];
    logic signed [40:0] sum_reg [0:31];
    logic signed [15:0] bypass_pipe_reg [0:31];
    logic signed [15:0] bypass_reg [0:31];
    logic product_valid;
    logic sum_valid;
    integer sample_index;
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
            pre_value_comb[sample_index] = '0;
            center_value_comb[sample_index] = '0;
            post_value_comb[sample_index] = '0;
            bypass_comb[sample_index] = '0;
            pre_product_comb[sample_index] = '0;
            post_product_comb[sample_index] = '0;
            center_product_comb[sample_index] = '0;

            source_index = sample_index - 6;
            if (source_index >= 0)
                pre_value_comb[sample_index] = $signed(in_samples[source_index*16 +: 16]);
            else begin
                history_index = HISTORY_COUNT + source_index;
                pre_value_comb[sample_index] = history[history_index];
            end

            source_index = sample_index - 8;
            if (source_index >= 0)
                center_value_comb[sample_index] = $signed(in_samples[source_index*16 +: 16]);
            else begin
                history_index = HISTORY_COUNT + source_index;
                center_value_comb[sample_index] = history[history_index];
            end
            bypass_comb[sample_index] = center_value_comb[sample_index];

            source_index = sample_index - 10;
            if (source_index >= 0)
                post_value_comb[sample_index] = $signed(in_samples[source_index*16 +: 16]);
            else begin
                history_index = HISTORY_COUNT + source_index;
                post_value_comb[sample_index] = history[history_index];
            end

            if (!BYPASS) begin
                pre_product_comb[sample_index] =
                    pre_value_comb[sample_index] * COEFF_PRE;
                post_product_comb[sample_index] =
                    post_value_comb[sample_index] * COEFF_POST;
                // Exact 32767/32768 Q15 centre gain without a DSP multiplier.
                center_product_comb[sample_index] =
                    ($signed({{25{center_value_comb[sample_index][15]}},
                        center_value_comb[sample_index]}) <<< 15) -
                    $signed({{25{center_value_comb[sample_index][15]}},
                        center_value_comb[sample_index]});
            end
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (integer index = 0; index < HISTORY_COUNT; index = index + 1)
                history[index] <= '0;
            product_valid <= 1'b0;
            sum_valid <= 1'b0;
            out_valid <= 1'b0;
            out_samples <= '0;
        end else if (clear_history) begin
            for (integer index = 0; index < HISTORY_COUNT; index = index + 1)
                history[index] <= '0;
            product_valid <= 1'b0;
            sum_valid <= 1'b0;
            out_valid <= 1'b0;
        end else begin
            out_valid <= sum_valid;
            if (sum_valid) begin
                for (integer index = 0; index < 32; index = index + 1) begin
                    if (BYPASS || bypass)
                        out_samples[index*16 +: 16] <= bypass_reg[index];
                    else
                        out_samples[index*16 +: 16] <= saturate_q15(sum_reg[index]);
                end
            end

            sum_valid <= product_valid;
            if (product_valid) begin
                for (integer index = 0; index < 32; index = index + 1) begin
                    sum_reg[index] <= pre_product_reg[index] +
                        center_product_reg[index] + post_product_reg[index];
                    bypass_reg[index] <= bypass_pipe_reg[index];
                end
            end

            product_valid <= in_valid;
            if (in_valid) begin
                for (integer index = 0; index < 32; index = index + 1) begin
                    pre_product_reg[index] <= pre_product_comb[index];
                    center_product_reg[index] <= center_product_comb[index];
                    post_product_reg[index] <= post_product_comb[index];
                    bypass_pipe_reg[index] <= bypass_comb[index];
                end
                for (integer index = 0; index < HISTORY_COUNT; index = index + 1)
                    history[index] <= $signed(in_samples[(16 + index)*16 +: 16]);
            end
        end
    end
endmodule
