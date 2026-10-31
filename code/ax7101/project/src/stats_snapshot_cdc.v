`timescale 1ns/1ps

module stats_snapshot_cdc #(
    parameter integer WIDTH = 32
) (
    input  wire                 src_clk,
    input  wire                 src_rst_n,
    input  wire [WIDTH-1:0]     src_data,
    input  wire                 src_toggle,
    input  wire                 dst_clk,
    input  wire                 dst_rst_n,
    output reg  [WIDTH-1:0]     dst_data,
    output reg                  dst_update_pulse
);

(* ASYNC_REG = "TRUE" *) reg toggle_meta;
(* ASYNC_REG = "TRUE" *) reg toggle_sync;
(* ASYNC_REG = "TRUE" *) reg [WIDTH-1:0] data_meta;
(* ASYNC_REG = "TRUE" *) reg [WIDTH-1:0] data_sync;
reg toggle_seen;

wire unused_src_clock;
wire unused_src_reset;
assign unused_src_clock = src_clk;
assign unused_src_reset = src_rst_n;

always @(posedge dst_clk or negedge dst_rst_n) begin
    if (!dst_rst_n) begin
        toggle_meta <= 1'b0;
        toggle_sync <= 1'b0;
        toggle_seen <= 1'b0;
        data_meta <= {WIDTH{1'b0}};
        data_sync <= {WIDTH{1'b0}};
        dst_data <= {WIDTH{1'b0}};
        dst_update_pulse <= 1'b0;
    end else begin
        toggle_meta <= src_toggle;
        toggle_sync <= toggle_meta;
        data_meta <= src_data;
        data_sync <= data_meta;
        dst_update_pulse <= 1'b0;

        if (toggle_sync != toggle_seen) begin
            dst_data <= data_sync;
            toggle_seen <= toggle_sync;
            dst_update_pulse <= 1'b1;
        end
    end
end

endmodule

