`timescale 1ns/1ps

module tb_sample_gearbox_512_to_256;
    logic wr_clk = 1'b0;
    logic rd_clk = 1'b0;
    logic wr_rst_n = 1'b0;
    logic rd_rst_n = 1'b0;
    logic [511:0] s_data = '0;
    logic s_valid = 1'b0;
    logic s_ready;
    logic read_start = 1'b0;
    logic start_ready;
    logic [255:0] m_data;
    logic m_valid;
    logic m_ready = 1'b1;
    logic overflow;
    logic underflow;
    integer received = 0;

    always #2 wr_clk = ~wr_clk;
    always #1 rd_clk = ~rd_clk;

    sample_gearbox_512_to_256 dut (
        .wr_clk(wr_clk),
        .wr_rst_n(wr_rst_n),
        .s_data(s_data),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .rd_clk(rd_clk),
        .rd_rst_n(rd_rst_n),
        .read_start(read_start),
        .start_ready(start_ready),
        .m_data(m_data),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .overflow(overflow),
        .underflow(underflow)
    );

    function automatic [255:0] expected_half(input integer half_index);
        reg [255:0] value;
        value = '0;
        for (int lane = 0; lane < 16; lane++)
            value[lane*16 +: 16] = half_index*16 + lane;
        return value;
    endfunction

    always @(posedge rd_clk) begin
        if (rd_rst_n && m_valid && m_ready) begin
            if (m_data !== expected_half(received)) begin
                $error("half %0d ordering mismatch", received);
                $fatal(1);
            end
            received <= received + 1;
        end
    end

    initial begin
        #120;
        repeat (8) @(posedge rd_clk);
        wr_rst_n <= 1'b1;
        rd_rst_n <= 1'b1;
        repeat (4) @(posedge wr_clk);

        for (int block = 0; block < 20; block++) begin
            while (!s_ready) @(posedge wr_clk);
            for (int lane = 0; lane < 32; lane++)
                s_data[lane*16 +: 16] <= block*32 + lane;
            s_valid <= 1'b1;
            @(posedge wr_clk);
        end
        s_valid <= 1'b0;

        wait (start_ready);
        repeat (4) begin
            @(posedge rd_clk);
            if (m_valid)
                $fatal(1, "gearbox read before common read_start");
        end
        read_start <= 1'b1;

        wait (received == 7);
        m_ready <= 1'b0;
        repeat (12) @(posedge rd_clk);
        m_ready <= 1'b1;

        wait (received == 40);
        repeat (4) @(posedge rd_clk);
        if (overflow || underflow)
            $fatal(1, "unexpected FIFO error overflow=%0b underflow=%0b",
                   overflow, underflow);

        $display("PASS: 512b/250MHz to 256b/500MHz ordering and continuity");
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "gearbox timeout, received %0d halves", received);
    end
endmodule
