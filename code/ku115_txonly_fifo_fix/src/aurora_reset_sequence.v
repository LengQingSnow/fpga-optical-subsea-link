`timescale 1ns / 1ps

module aurora_reset_sequence #(
    parameter integer PMA_HOLD_CYCLES = 1024,
    parameter integer CORE_HOLD_CYCLES = 128,
    parameter integer COUNTER_WIDTH = 16
) (
    input  init_clk,
    input  reset_request,
    output reg pma_init,
    output reg reset_pb,
    output reg ready
);

localparam [1:0] STATE_PMA = 2'd0;
localparam [1:0] STATE_CORE = 2'd1;
localparam [1:0] STATE_RUN = 2'd2;

reg [1:0] state = STATE_PMA;
reg [COUNTER_WIDTH-1:0] counter = {COUNTER_WIDTH{1'b0}};

always @(posedge init_clk) begin
    if (reset_request) begin
        state <= STATE_PMA;
        counter <= {COUNTER_WIDTH{1'b0}};
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
                    counter <= {COUNTER_WIDTH{1'b0}};
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
                    counter <= {COUNTER_WIDTH{1'b0}};
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
