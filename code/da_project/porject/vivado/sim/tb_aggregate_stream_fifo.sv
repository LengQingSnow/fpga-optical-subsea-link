`timescale 1ns/1ps

module tb_aggregate_stream_fifo;
    logic wr_clk = 1'b0;
    logic rd_clk = 1'b0;
    logic wr_rst_n = 1'b0;
    logic rd_rst_n = 1'b0;
    logic [255:0] s_data = '0;
    logic s_valid = 1'b0;
    logic s_ready;
    logic [63:0] m_data;
    logic m_valid;
    logic m_ready = 1'b1;
    logic streaming;
    logic near_full;
    logic overflow;
    logic underflow;
    integer received = 0;
    integer ready_cycle = 0;

    always #3.2 wr_clk = ~wr_clk;
    always #2.0 rd_clk = ~rd_clk;

    // Exercise output backpressure independently of the FIFO prefetch path.
    always @(negedge rd_clk) begin
        if (!rd_rst_n) begin
            ready_cycle = 0;
            m_ready = 1'b0;
        end else begin
            ready_cycle = ready_cycle + 1;
            m_ready = ((ready_cycle % 5) != 0) &&
                      ((ready_cycle % 7) != 0);
        end
    end

    aggregate_stream_fifo #(
        .FIFO_WRITE_DEPTH(64),
        .START_THRESHOLD_READ_WORDS(16)
    ) dut (
        .wr_clk(wr_clk), .wr_rst_n(wr_rst_n),
        .s_data(s_data), .s_valid(s_valid), .s_ready(s_ready),
        .rd_clk(rd_clk), .rd_rst_n(rd_rst_n),
        .m_data(m_data), .m_valid(m_valid), .m_ready(m_ready),
        .streaming(streaming), .near_full(near_full),
        .overflow(overflow), .underflow(underflow)
    );

    task send_word(input int index);
        begin
            @(negedge wr_clk);
            while (!s_ready) @(negedge wr_clk);
            s_data = {64'hA000000000000000 + index,
                      64'hB000000000000000 + index,
                      64'hC000000000000000 + index,
                      64'hD000000000000000 + index};
            s_valid = 1'b1;
            @(negedge wr_clk);
            s_valid = 1'b0;
        end
    endtask

    always @(posedge rd_clk) begin
        logic [63:0] expected;
        if (m_valid && m_ready) begin
            case (received % 4)
                0: expected = 64'hA000000000000000 + (received/4);
                1: expected = 64'hB000000000000000 + (received/4);
                2: expected = 64'hC000000000000000 + (received/4);
                default: expected = 64'hD000000000000000 + (received/4);
            endcase
            if (m_data !== expected)
                $fatal(1, "FIFO time order mismatch at %0d: %h != %h",
                       received, m_data, expected);
            received++;
        end
    end

    initial begin
        repeat (8) @(posedge wr_clk);
        wr_rst_n = 1'b1;
        rd_rst_n = 1'b1;
        for (int i = 0; i < 8; i++)
            send_word(i);
        wait (received == 32);
        if (overflow || underflow)
            $fatal(1, "unexpected FIFO error overflow=%b underflow=%b", overflow, underflow);
        $display("PASS: Aurora 256-bit words drain as MSB-first 64-bit time words");
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "FIFO timeout, received=%0d", received);
    end
endmodule
