`timescale 1ns/1ps

module runtime_config_cdc (
    input  logic        src_clk,
    input  logic        src_rst,
    input  logic [55:0] src_delay_codes,
    input  logic        src_commit_toggle,
    input  logic        dst_clk,
    input  logic        dst_rst_n,
    output logic [55:0] dst_delay_codes,
    output logic        dst_commit_pulse
);
    logic [55:0] src_snapshot;
    logic src_toggle_seen;
    (* ASYNC_REG = "TRUE" *) logic [55:0] delay_meta;
    (* ASYNC_REG = "TRUE" *) logic [55:0] delay_sync;
    (* ASYNC_REG = "TRUE" *) logic [3:0] commit_sync;
    logic dst_toggle_seen;

    always_ff @(posedge src_clk) begin
        if (src_rst) begin
            src_snapshot <= '0;
            src_toggle_seen <= 1'b0;
        end else if (src_commit_toggle != src_toggle_seen) begin
            src_snapshot <= src_delay_codes;
            src_toggle_seen <= src_commit_toggle;
        end
    end

    always_ff @(posedge dst_clk) begin
        if (!dst_rst_n) begin
            delay_meta <= '0;
            delay_sync <= '0;
            commit_sync <= '0;
            dst_toggle_seen <= 1'b0;
            dst_delay_codes <= '0;
            dst_commit_pulse <= 1'b0;
        end else begin
            delay_meta <= src_snapshot;
            delay_sync <= delay_meta;
            commit_sync <= {commit_sync[2:0], src_commit_toggle};
            dst_commit_pulse <= 1'b0;
            if (commit_sync[3] != dst_toggle_seen) begin
                dst_delay_codes <= delay_sync;
                dst_toggle_seen <= commit_sync[3];
                dst_commit_pulse <= 1'b1;
            end
        end
    end
endmodule
