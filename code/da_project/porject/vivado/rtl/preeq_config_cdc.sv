`timescale 1ns/1ps

// Bundles all pre-equalizer coefficients and enables behind one commit toggle.
// The payload is held stable in the source domain before the toggle crosses.
module preeq_config_cdc #(
    parameter integer CONFIG_WIDTH = 452
) (
    input  logic                    src_clk,
    input  logic                    src_rst,
    input  logic [CONFIG_WIDTH-1:0] src_config,
    input  logic                    src_commit_toggle,
    input  logic                    dst_clk,
    input  logic                    dst_rst_n,
    output logic [CONFIG_WIDTH-1:0] dst_config,
    output logic                    dst_commit_pulse
);
    logic [CONFIG_WIDTH-1:0] src_snapshot;
    logic src_toggle_seen;
    (* ASYNC_REG = "TRUE" *) logic [CONFIG_WIDTH-1:0] config_meta;
    (* ASYNC_REG = "TRUE" *) logic [CONFIG_WIDTH-1:0] config_sync;
    (* ASYNC_REG = "TRUE" *) logic [3:0] commit_sync;
    logic dst_toggle_seen;

    always_ff @(posedge src_clk) begin
        if (src_rst) begin
            src_snapshot <= '0;
            src_toggle_seen <= 1'b0;
        end else if (src_commit_toggle != src_toggle_seen) begin
            src_snapshot <= src_config;
            src_toggle_seen <= src_commit_toggle;
        end
    end

    always_ff @(posedge dst_clk) begin
        if (!dst_rst_n) begin
            config_meta <= '0;
            config_sync <= '0;
            commit_sync <= '0;
            dst_toggle_seen <= 1'b0;
            dst_config <= '0;
            dst_commit_pulse <= 1'b0;
        end else begin
            config_meta <= src_snapshot;
            config_sync <= config_meta;
            commit_sync <= {commit_sync[2:0], src_commit_toggle};
            dst_commit_pulse <= 1'b0;
            if (commit_sync[3] != dst_toggle_seen) begin
                dst_config <= config_sync;
                dst_toggle_seen <= commit_sync[3];
                dst_commit_pulse <= 1'b1;
            end
        end
    end
endmodule
