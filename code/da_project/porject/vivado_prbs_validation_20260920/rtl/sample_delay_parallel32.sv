`timescale 1ns/1ps

module sample_delay_parallel32 (
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    in_valid,
    input  logic                    clear_history,
    input  logic signed [16*32-1:0] samples,
    input  logic [1:0]              delay_samples,
    output logic                    out_valid,
    output logic signed [16*32-1:0] delayed_samples
);
    logic signed [16*32-1:0] previous_samples;
    logic signed [16*32-1:0] delayed_comb;
    integer source_index;

    always_comb begin
        delayed_comb = '0;
        for (int sample_index = 0; sample_index < 32; sample_index++) begin
            source_index = sample_index - delay_samples;
            if (source_index >= 0)
                delayed_comb[sample_index*16 +: 16] =
                    samples[source_index*16 +: 16];
            else
                delayed_comb[sample_index*16 +: 16] =
                    previous_samples[(32 + source_index)*16 +: 16];
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            previous_samples <= '0;
            delayed_samples <= '0;
            out_valid <= 1'b0;
        end else if (clear_history) begin
            previous_samples <= '0;
            delayed_samples <= '0;
            out_valid <= 1'b0;
        end else begin
            out_valid <= in_valid;
            if (in_valid) begin
                delayed_samples <= delayed_comb;
                previous_samples <= samples;
            end else begin
                delayed_samples <= '0;
            end
        end
    end
endmodule
