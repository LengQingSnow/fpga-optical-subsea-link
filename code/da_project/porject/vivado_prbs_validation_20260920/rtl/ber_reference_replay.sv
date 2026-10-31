`timescale 1ns/1ps

// ISOLATED VALIDATION BUILD ONLY: 262144 symbols/lane from PRBS31.
// The 64-word JTAG window is a prefix, NOT the full replay period.
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
    localparam int FRAGMENT_WORDS = 16384;
    logic capture_active;
    logic [ADDRESS_WIDTH-1:0] capture_index;
    logic [13:0] replay_index;
    logic [30:0] state [0:3];
    logic [30:0] next_state [0:3];
    logic [63:0] prbs_word;

    function automatic logic [30:0] seed(input integer lane);
        case (lane)
            0: seed = 31'h13579bdf;
            1: seed = 31'h2468ace1;
            2: seed = 31'h5a6b7c1d;
            default: seed = 31'h73c951a7;
        endcase
    endfunction
    // MSB first, x^31+x^28+1; nibble order XI,XQ,YI,YQ.
    always_comb begin
        for (int lane=0; lane<4; lane++) begin
            next_state[lane] = state[lane];
            for (int sym=0; sym<16; sym++) begin
                prbs_word[63-4*sym-lane] = next_state[lane][30];
                next_state[lane] = {next_state[lane][29:0],
                    next_state[lane][30] ^ next_state[lane][27]};
            end
        end
    end

    assign replay_active = reference_ready && replay_enable && !capture_active;
    assign reference_data = reference_memory[reference_address];

    always_comb begin
        if (replay_active) begin
            output_data = prbs_word;
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
            for (int lane=0; lane<4; lane++) state[lane] <= seed(lane);
        end else begin
            if (capture_pulse) begin
                capture_active <= 1'b1;
                capture_index <= '0;
                replay_index <= '0;
                reference_ready <= 1'b0;
                for (int lane=0; lane<4; lane++) state[lane] <= seed(lane);
            end else if (capture_active) begin
                reference_memory[capture_index] <= prbs_word;
                if (capture_index == WORD_COUNT - 1) begin
                    capture_active <= 1'b0;
                    capture_index <= '0;
                    replay_index <= '0;
                    reference_ready <= 1'b1;
                    for (int lane=0; lane<4; lane++) state[lane] <= seed(lane);
                end else begin
                    capture_index <= capture_index + 1'b1;
                    for (int lane=0; lane<4; lane++) state[lane] <= next_state[lane];
                end
            end else if (replay_active && downstream_ready) begin
                if (replay_index == FRAGMENT_WORDS - 1) begin
                    replay_index <= '0;
                    for (int lane=0; lane<4; lane++) state[lane] <= seed(lane);
                end else begin
                    replay_index <= replay_index + 1'b1;
                    for (int lane=0; lane<4; lane++) state[lane] <= next_state[lane];
                end
            end else if (!replay_active) begin
                replay_index <= '0;
                for (int lane=0; lane<4; lane++) state[lane] <= seed(lane);
            end
        end
    end
endmodule
