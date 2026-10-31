`timescale 1ns/1ps

module prbs31_parallel16 #(
    parameter logic [30:0] SEED = 31'h7fffffff
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,
    output logic [15:0] bits,
    output logic [30:0] state
);
    logic [30:0] next_state;
    logic [15:0] next_bits;

    always_comb begin
        next_state = state;
        next_bits = '0;
        for (int i = 0; i < 16; i++) begin
            next_bits[i] = next_state[30];
            next_state = {next_state[29:0],
                          next_state[30] ^ next_state[27]};
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= SEED;
            bits <= '0;
        end else if (enable) begin
            state <= next_state;
            bits <= next_bits;
        end else begin
            bits <= '0;
        end
    end
endmodule
