`timescale 1ns/1ps

// Capture 64 accepted 64-bit DA-input words, then replay that exact block
// cyclically. The live input remains ready during replay so the upstream
// elastic buffer continues to drain without overflow.
module ber_reference_replay #(
    parameter int WORD_COUNT = 64,
    parameter int ADDRESS_WIDTH = 6
) (
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     capture_pulse,
    input  logic                     replay_enable,
    input  logic [63:0]              live_data,
    input  logic                     live_valid,
    output logic                     live_ready,
    input  logic                     downstream_ready,
    output logic [63:0]              output_data,
    output logic                     output_valid,
    input  logic [ADDRESS_WIDTH-1:0] reference_address,
    output logic [63:0]              reference_data,
    output logic                     reference_ready,
    output logic                     replay_active
);
    (* ram_style = "distributed" *) logic [63:0] reference_memory [0:WORD_COUNT-1];
    logic capture_active;
    logic [ADDRESS_WIDTH-1:0] capture_index;
    logic [ADDRESS_WIDTH-1:0] replay_index;

    assign replay_active = reference_ready && replay_enable && !capture_active;
    assign reference_data = reference_memory[reference_address];

    always_comb begin
        if (replay_active) begin
            output_data = reference_memory[replay_index];
            output_valid = 1'b1;
            live_ready = 1'b1;
        end else begin
            output_data = live_data;
            output_valid = live_valid;
            live_ready = downstream_ready;
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            capture_active <= 1'b0;
            capture_index <= '0;
            replay_index <= '0;
            reference_ready <= 1'b0;
        end else begin
            if (capture_pulse) begin
                capture_active <= 1'b1;
                capture_index <= '0;
                replay_index <= '0;
                reference_ready <= 1'b0;
            end else if (capture_active && live_valid && downstream_ready) begin
                reference_memory[capture_index] <= live_data;
                if (capture_index == WORD_COUNT - 1) begin
                    capture_active <= 1'b0;
                    capture_index <= '0;
                    replay_index <= '0;
                    reference_ready <= 1'b1;
                end else begin
                    capture_index <= capture_index + 1'b1;
                end
            end

            if (replay_active && downstream_ready) begin
                if (replay_index == WORD_COUNT - 1)
                    replay_index <= '0;
                else
                    replay_index <= replay_index + 1'b1;
            end else if (!replay_active) begin
                replay_index <= '0;
            end
        end
    end
endmodule
