`timescale 1ns/1ps

module tb_aggregate_frame_aligner;
    localparam logic [63:0] SYNC = 64'hD5C0_1ACF_FC1D_5AA5;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic [255:0] s_data = '0;
    logic [31:0] s_keep = '0;
    logic s_valid = 1'b0;
    logic [255:0] m_data;
    logic m_valid;
    logic frame_start;
    logic frame_end;
    logic locked;
    logic [31:0] frame_count;
    logic [31:0] header_error_count;
    logic [31:0] keep_error_count;
    integer output_beats = 0;

    always #3.2 clk = ~clk;

    aggregate_frame_aligner dut (
        .clk(clk), .rst_n(rst_n),
        .s_data(s_data), .s_keep(s_keep), .s_valid(s_valid),
        .m_data(m_data), .m_valid(m_valid),
        .frame_start(frame_start), .frame_end(frame_end), .locked(locked),
        .frame_count(frame_count), .header_error_count(header_error_count),
        .keep_error_count(keep_error_count)
    );

    task send_beat(input logic [255:0] data, input logic [31:0] keep);
        begin
            @(negedge clk);
            s_data = data;
            s_keep = keep;
            s_valid = 1'b1;
            @(negedge clk);
            s_valid = 1'b0;
        end
    endtask

    always @(posedge clk) begin
        if (m_valid) begin
            if (output_beats == 0 && (!frame_start || m_data[255:192] != SYNC))
                $fatal(1, "first aligned beat is not the frame header");
            if (frame_start !== ((output_beats % 16) == 0))
                $fatal(1, "frame_start mismatch at output beat %0d", output_beats);
            if (frame_end !== ((output_beats % 16) == 15))
                $fatal(1, "frame_end mismatch at output beat %0d", output_beats);
            output_beats++;
        end
    end

    initial begin
        repeat (5) @(posedge clk);
        rst_n = 1'b1;

        send_beat(256'h1234, 32'hffff_ffff);
        if (m_valid || locked)
            $fatal(1, "garbage beat was accepted");

        for (int beat = 0; beat < 16; beat++) begin
            if (beat == 0)
                send_beat({SYNC, 8'h01, 8'h07, 16'h0010, 32'h00000001, 128'h55},
                          32'hffff_ffff);
            else
                send_beat({8{32'h10000000 + beat}}, 32'hffff_ffff);
        end
        repeat (3) @(posedge clk);
        if (output_beats != 16 || frame_count != 1 || !locked)
            $fatal(1, "valid frame was not aligned: beats=%0d frames=%0d lock=%b",
                   output_beats, frame_count, locked);

        send_beat({SYNC, 8'h01, 184'h0}, 32'hffff_fffe);
        repeat (2) @(posedge clk);
        if (locked || keep_error_count != 1)
            $fatal(1, "bad keep did not drop lock/count error");

        $display("PASS: 512-byte frame alignment and error recovery");
        $finish;
    end
endmodule

