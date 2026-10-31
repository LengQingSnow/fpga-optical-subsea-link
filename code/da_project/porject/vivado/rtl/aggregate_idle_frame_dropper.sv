`timescale 1ns/1ps

module aggregate_idle_frame_dropper (
    input  logic         clk,
    input  logic         rst_n,
    input  logic [255:0] s_data,
    input  logic         s_valid,
    input  logic         s_frame_start,
    input  logic         s_frame_end,
    input  logic         near_full,
    output logic [255:0] m_data,
    output logic         m_valid,
    output logic         m_frame_start,
    output logic         m_frame_end,
    output logic         dropping_idle_frame,
    output logic         idle_frame_dropped,
    output logic [31:0]  dropped_idle_frame_count
);
    localparam logic [7:0] FRAME_FLAGS_IDLE = 8'h06;

    logic start_idle_frame;
    logic start_drop;
    logic drop_this_beat;

    always_comb begin
        start_idle_frame = s_frame_start &&
                           (s_data[183:176] == FRAME_FLAGS_IDLE);
        start_drop = s_valid && near_full && start_idle_frame &&
                     !dropping_idle_frame;
        drop_this_beat = dropping_idle_frame || start_drop;

        m_data = s_data;
        m_valid = s_valid && !drop_this_beat;
        m_frame_start = s_frame_start && m_valid;
        m_frame_end = s_frame_end && m_valid;
    end

    // A drop decision is made only on an idle-frame header. Once selected,
    // the entire 4096-bit frame is removed even if near_full clears midway.
    // Data frames are never discarded by this rate matcher.
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            dropping_idle_frame <= 1'b0;
            idle_frame_dropped <= 1'b0;
            dropped_idle_frame_count <= 32'd0;
        end else begin
            idle_frame_dropped <= 1'b0;

            if (start_drop) begin
                dropping_idle_frame <= !s_frame_end;
                idle_frame_dropped <= 1'b1;
                dropped_idle_frame_count <= dropped_idle_frame_count + 1'b1;
            end else if (s_valid && dropping_idle_frame && s_frame_end) begin
                dropping_idle_frame <= 1'b0;
            end
        end
    end
endmodule
