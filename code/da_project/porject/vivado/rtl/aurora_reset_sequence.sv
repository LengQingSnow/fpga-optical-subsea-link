`timescale 1ns/1ps

module aurora_reset_sequence #(
    parameter integer PMA_HOLD_CYCLES = 1024,
    parameter integer CORE_HOLD_CYCLES = 128,
    parameter integer COUNTER_WIDTH = 16
) (
    input  logic init_clk,
    input  logic reset_request,
    output logic pma_init,
    output logic reset_pb,
    output logic ready
);
    localparam logic [1:0] STATE_PMA = 2'd0;
    localparam logic [1:0] STATE_CORE = 2'd1;
    localparam logic [1:0] STATE_RUN = 2'd2;

    logic [1:0] state = STATE_PMA;
    logic [COUNTER_WIDTH-1:0] counter = '0;

    always_ff @(posedge init_clk) begin
        if (reset_request) begin
            state <= STATE_PMA;
            counter <= '0;
            pma_init <= 1'b1;
            reset_pb <= 1'b1;
            ready <= 1'b0;
        end else begin
            case (state)
                STATE_PMA: begin
                    pma_init <= 1'b1;
                    reset_pb <= 1'b1;
                    ready <= 1'b0;
                    if (counter == PMA_HOLD_CYCLES-1) begin
                        state <= STATE_CORE;
                        counter <= '0;
                    end else begin
                        counter <= counter + 1'b1;
                    end
                end
                STATE_CORE: begin
                    pma_init <= 1'b0;
                    reset_pb <= 1'b1;
                    ready <= 1'b0;
                    if (counter == CORE_HOLD_CYCLES-1) begin
                        state <= STATE_RUN;
                        counter <= '0;
                    end else begin
                        counter <= counter + 1'b1;
                    end
                end
                default: begin
                    pma_init <= 1'b0;
                    reset_pb <= 1'b0;
                    ready <= 1'b1;
                end
            endcase
        end
    end
endmodule

