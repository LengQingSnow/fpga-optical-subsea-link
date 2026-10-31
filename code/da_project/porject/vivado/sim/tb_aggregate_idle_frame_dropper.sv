`timescale 1ns/1ps

module tb_aggregate_idle_frame_dropper;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic [255:0] s_data = '0;
    logic s_valid = 1'b0;
    logic s_frame_start = 1'b0;
    logic s_frame_end = 1'b0;
    logic near_full = 1'b0;
    logic [255:0] m_data;
    logic m_valid;
    logic m_frame_start;
    logic m_frame_end;
    logic dropping_idle_frame;
    logic idle_frame_dropped;
    logic [31:0] dropped_idle_frame_count;
    integer forwarded_beats = 0;
    integer forwarded_starts = 0;
    integer forwarded_ends = 0;
    integer drop_pulses = 0;

    always #4 clk = ~clk;

    aggregate_idle_frame_dropper dut (
        .clk(clk), .rst_n(rst_n),
        .s_data(s_data), .s_valid(s_valid),
        .s_frame_start(s_frame_start), .s_frame_end(s_frame_end),
        .near_full(near_full),
        .m_data(m_data), .m_valid(m_valid),
        .m_frame_start(m_frame_start), .m_frame_end(m_frame_end),
        .dropping_idle_frame(dropping_idle_frame),
        .idle_frame_dropped(idle_frame_dropped),
        .dropped_idle_frame_count(dropped_idle_frame_count)
    );

    task send_frame(
        input logic [7:0] flags,
        input logic high_at_start,
        input integer near_full_change_beat,
        input logic changed_near_full
    );
        begin
            for (int beat = 0; beat < 16; beat++) begin
                @(negedge clk);
                if (beat == 0)
                    near_full = high_at_start;
                if (beat == near_full_change_beat)
                    near_full = changed_near_full;
                s_data = {64'hD5C01ACFFC1D5AA5,
                          64'(beat), 64'(forwarded_beats), 64'h1234};
                s_data[191:184] = 8'h01;
                s_data[183:176] = flags;
                s_valid = 1'b1;
                s_frame_start = (beat == 0);
                s_frame_end = (beat == 15);
            end
            @(negedge clk);
            s_valid = 1'b0;
            s_frame_start = 1'b0;
            s_frame_end = 1'b0;
        end
    endtask

    always @(posedge clk) begin
        if (m_valid) begin
            forwarded_beats++;
            if (m_frame_start)
                forwarded_starts++;
            if (m_frame_end)
                forwarded_ends++;
        end
        if (idle_frame_dropped)
            drop_pulses++;
    end

    initial begin
        repeat (4) @(posedge clk);
        rst_n = 1'b1;

        // A high-water condition must never remove a data frame.
        send_frame(8'h07, 1'b1, -1, 1'b1);
        if (forwarded_beats != 16 || dropped_idle_frame_count != 0)
            $fatal(1, "data frame was not forwarded intact");

        // An idle frame selected at its header must be removed in full.
        send_frame(8'h06, 1'b1, 8, 1'b0);
        if (forwarded_beats != 16 || dropped_idle_frame_count != 1)
            $fatal(1, "high-water idle frame was not dropped intact");

        // Raising high water in the middle cannot create a partial drop.
        send_frame(8'h06, 1'b0, 8, 1'b1);
        if (forwarded_beats != 32 || dropped_idle_frame_count != 1)
            $fatal(1, "mid-frame high water caused a partial drop");

        repeat (2) @(posedge clk);
        if (forwarded_starts != 2 || forwarded_ends != 2)
            $fatal(1, "forwarded frame boundary mismatch");
        if (drop_pulses != 1 || dropping_idle_frame)
            $fatal(1, "idle drop state/count mismatch");

        $display("PASS: rate matcher drops only complete idle frames");
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "idle-frame dropper timeout");
    end
endmodule
