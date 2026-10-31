`timescale 1ns/1ps

// Rectangular bipolar NRZ at two DAC samples per symbol. Fractional delay is
// retained without an RRC convolution by linearly interpolating only the
// first sample at each symbol transition. One delay code is 1/32 of a DAC
// sample (nominally 3.90625 ps at 8 GS/s).
module nrz_2sps_parallel32_configurable #(
    parameter logic signed [15:0] AMPLITUDE = 16'sd14779
) (
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
    logic previous_symbol;
    logic signed [15:0] transition_level;
    logic signed [15:0] sample_comb [0:31];

    function automatic logic signed [15:0] level_for_phase(
        input logic [4:0] phase
    );
        logic signed [6:0] phase_delta;
        logic signed [23:0] product;
        logic signed [23:0] magnitude;
        begin
            // A * (1 - phase/16) is equivalent to the linear interpolation
            // between the previous and current bipolar NRZ sample.
            phase_delta = 7'sd16 - $signed({1'b0, phase});
            product = $signed(AMPLITUDE) * phase_delta;
            if (product >= 0)
                level_for_phase = (product + 24'sd8) >>> 4;
            else begin
                magnitude = -product;
                level_for_phase = -((magnitude + 24'sd8) >>> 4);
            end
        end
    endfunction

    always_comb begin
        for (int sample_index = 0; sample_index < 32; sample_index++) begin
            int symbol_index;
            logic current_symbol;
            logic prior_symbol;

            symbol_index = sample_index / 2;
            current_symbol = symbols[symbol_index];
            if (sample_index == 0)
                prior_symbol = previous_symbol;
            else
                prior_symbol = symbols[(sample_index - 1) / 2];

            if (current_symbol == prior_symbol)
                sample_comb[sample_index] = current_symbol ? AMPLITUDE : -AMPLITUDE;
            else
                sample_comb[sample_index] = current_symbol ?
                    transition_level : -transition_level;
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            previous_symbol <= 1'b0;
            transition_level <= AMPLITUDE;
            samples <= '0;
            out_valid <= 1'b0;
        end else begin
            if (config_load)
                transition_level <= level_for_phase(fractional_delay);

            if (clear_history) begin
                previous_symbol <= 1'b0;
                samples <= '0;
                out_valid <= 1'b0;
            end else begin
                out_valid <= in_valid;
                if (in_valid) begin
                    for (int sample_index = 0; sample_index < 32; sample_index++)
                        samples[sample_index*16 +: 16] <= sample_comb[sample_index];
                    previous_symbol <= symbols[15];
                end else begin
                    samples <= '0;
                end
            end
        end
    end
endmodule
