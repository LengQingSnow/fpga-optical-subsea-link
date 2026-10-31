`timescale 1ns/1ps

module aggregate_frame_aligner (
    input  logic         clk,
    input  logic         rst_n,
    input  logic [255:0] s_data,
    input  logic [31:0]  s_keep,
    input  logic         s_valid,
    output logic [255:0] m_data,
    output logic         m_valid,
    output logic         frame_start,
    output logic         frame_end,
    output logic         locked,
    output logic [31:0]  frame_count,
    output logic [31:0]  header_error_count,
    output logic [31:0]  keep_error_count
);
    localparam logic [63:0] SYNC_WORD = 64'hD5C0_1ACF_FC1D_5AA5;
    localparam logic [7:0] PROTOCOL_VERSION = 8'h01;

    logic [3:0] beat_index;
    logic header_match;

    always_comb begin
        header_match = (s_data[255:192] == SYNC_WORD) &&
                       (s_data[191:184] == PROTOCOL_VERSION);
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            m_data <= '0;
            m_valid <= 1'b0;
            frame_start <= 1'b0;
            frame_end <= 1'b0;
            locked <= 1'b0;
            beat_index <= 4'd0;
            frame_count <= 32'd0;
            header_error_count <= 32'd0;
            keep_error_count <= 32'd0;
        end else begin
            m_valid <= 1'b0;
            frame_start <= 1'b0;
            frame_end <= 1'b0;

            if (s_valid) begin
                if (!locked) begin
                    if ((s_keep == 32'hffff_ffff) && header_match) begin
                        m_data <= s_data;
                        m_valid <= 1'b1;
                        frame_start <= 1'b1;
                        locked <= 1'b1;
                        beat_index <= 4'd1;
                    end
                end else if (s_keep != 32'hffff_ffff) begin
                    locked <= 1'b0;
                    beat_index <= 4'd0;
                    keep_error_count <= keep_error_count + 1'b1;
                end else if ((beat_index == 4'd0) && !header_match) begin
                    locked <= 1'b0;
                    header_error_count <= header_error_count + 1'b1;
                end else begin
                    m_data <= s_data;
                    m_valid <= 1'b1;
                    frame_start <= (beat_index == 4'd0);
                    frame_end <= (beat_index == 4'd15);
                    if (beat_index == 4'd15) begin
                        beat_index <= 4'd0;
                        frame_count <= frame_count + 1'b1;
                    end else begin
                        beat_index <= beat_index + 1'b1;
                    end
                end
            end
        end
    end
endmodule

