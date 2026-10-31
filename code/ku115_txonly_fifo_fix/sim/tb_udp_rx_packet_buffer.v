`timescale 1ns / 1ps

module tb_udp_rx_packet_buffer;

reg rx_clk = 1'b0;
reg tx_clk = 1'b0;
reg rx_rst_n = 1'b0;
reg tx_rst_n = 1'b0;
reg rx_packet_start = 1'b0;
reg rx_payload_wr_en = 1'b0;
reg [10:0] rx_payload_wr_addr = 11'd0;
reg [7:0] rx_payload_wr_data = 8'd0;
reg rx_packet_commit = 1'b0;
reg rx_packet_abort = 1'b0;
reg [15:0] rx_payload_length = 16'd0;
reg [10:0] tx_payload_rd_addr = 11'd0;
reg tx_payload_rd_en = 1'b0;
reg tx_packet_done = 1'b0;

wire [7:0] tx_payload_rd_data;
wire tx_payload_rd_valid;
wire tx_packet_valid;
wire [15:0] tx_payload_length;
wire overflow_sticky;
wire [31:0] overflow_count;

integer byte_index;
integer timeout;

always #4.0 rx_clk = ~rx_clk;
always #3.5 tx_clk = ~tx_clk;

udp_rx_packet_buffer dut (
    .rx_clk(rx_clk),
    .rx_rst_n(rx_rst_n),
    .rx_packet_start(rx_packet_start),
    .rx_payload_wr_en(rx_payload_wr_en),
    .rx_payload_wr_addr(rx_payload_wr_addr),
    .rx_payload_wr_data(rx_payload_wr_data),
    .rx_packet_commit(rx_packet_commit),
    .rx_packet_abort(rx_packet_abort),
    .rx_payload_length(rx_payload_length),
    .overflow_sticky(overflow_sticky),
    .overflow_count(overflow_count),
    .tx_clk(tx_clk),
    .tx_rst_n(tx_rst_n),
    .tx_payload_rd_addr(tx_payload_rd_addr),
    .tx_payload_rd_en(tx_payload_rd_en),
    .tx_payload_rd_data(tx_payload_rd_data),
    .tx_payload_rd_valid(tx_payload_rd_valid),
    .tx_packet_valid(tx_packet_valid),
    .tx_payload_length(tx_payload_length),
    .tx_packet_done(tx_packet_done)
);

task write_packet;
    input integer payload_length;
    input [7:0] seed;
    input commit_packet;
    begin
        @(negedge rx_clk);
        rx_packet_start = 1'b1;
        @(negedge rx_clk);
        rx_packet_start = 1'b0;
        for (byte_index = 0; byte_index < payload_length;
             byte_index = byte_index + 1) begin
            rx_payload_wr_en = 1'b1;
            rx_payload_wr_addr = byte_index[10:0];
            rx_payload_wr_data = seed + byte_index[7:0];
            @(negedge rx_clk);
        end
        rx_payload_wr_en = 1'b0;
        rx_payload_length = payload_length[15:0];
        if (commit_packet)
            rx_packet_commit = 1'b1;
        else
            rx_packet_abort = 1'b1;
        @(negedge rx_clk);
        rx_packet_commit = 1'b0;
        rx_packet_abort = 1'b0;
    end
endtask

task wait_and_check_packet;
    input integer expected_length;
    input [7:0] seed;
    begin
        timeout = 0;
        while (!tx_packet_valid && timeout < 500) begin
            @(posedge tx_clk);
            timeout = timeout + 1;
        end
        if (!tx_packet_valid)
            $fatal(1, "committed packet was not published");
        if (tx_payload_length != expected_length)
            $fatal(1, "payload length mismatch: expected %0d got %0d",
                   expected_length, tx_payload_length);

        for (byte_index = 0; byte_index < expected_length;
             byte_index = byte_index + 1) begin
            @(negedge tx_clk);
            tx_payload_rd_addr = byte_index[10:0];
            tx_payload_rd_en = 1'b1;
            @(posedge tx_clk);
            #1;
            if (!tx_payload_rd_valid)
                $fatal(1, "missing read valid at %0d", byte_index);
            if (tx_payload_rd_data !== (seed + byte_index[7:0]))
                $fatal(1, "payload mismatch at %0d: %02x", byte_index,
                       tx_payload_rd_data);
        end
        @(negedge tx_clk);
        tx_payload_rd_en = 1'b0;
        @(posedge tx_clk);
        #1;
        if (tx_payload_rd_valid)
            $fatal(1, "read valid remained high without a request");

        @(negedge tx_clk);
        tx_packet_done = 1'b1;
        @(negedge tx_clk);
        tx_packet_done = 1'b0;
    end
endtask

initial begin
    repeat (5) @(posedge rx_clk);
    rx_rst_n = 1'b1;
    repeat (5) @(posedge tx_clk);
    tx_rst_n = 1'b1;

    write_packet(64, 8'h40, 1'b1);
    wait_and_check_packet(64, 8'h40);

    repeat (200) begin
        @(posedge tx_clk);
        if (tx_packet_valid)
            $fatal(1, "completed packet was replayed");
    end
    if (overflow_sticky || overflow_count != 0)
        $fatal(1, "unexpected overflow");

    // An aborted packet must not publish a descriptor and its bank must be
    // reusable by the next committed packet.
    write_packet(32, 8'ha0, 1'b0);
    repeat (20) @(posedge tx_clk);
    if (tx_packet_valid)
        $fatal(1, "aborted packet was published");
    write_packet(64, 8'h50, 1'b1);
    wait_and_check_packet(64, 8'h50);

    repeat (20) @(posedge rx_clk);

    // Two banks must preserve unrelated payloads and descriptor order.
    write_packet(256, 8'h10, 1'b1);
    write_packet(1400, 8'h80, 1'b1);
    wait_and_check_packet(256, 8'h10);
    wait_and_check_packet(1400, 8'h80);

    repeat (20) @(posedge rx_clk);

    // Hold both committed banks, then prove a third packet is dropped without
    // corrupting either owner.
    write_packet(32, 8'h21, 1'b1);
    write_packet(48, 8'h31, 1'b1);
    write_packet(16, 8'he0, 1'b1);
    repeat (5) @(posedge rx_clk);
    if (!overflow_sticky || overflow_count != 32'd1)
        $fatal(1, "full-buffer overflow was not reported exactly once");
    wait_and_check_packet(32, 8'h21);
    wait_and_check_packet(48, 8'h31);

    repeat (20) @(posedge rx_clk);
    write_packet(64, 8'h70, 1'b1);
    wait_and_check_packet(64, 8'h70);
    if (overflow_count != 32'd1)
        $fatal(1, "overflow count changed after bank reuse");

    $display("TEST PASSED: udp_rx_packet_buffer exact-once CDC and ownership");
    $finish;
end

endmodule
