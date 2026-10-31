`timescale 1ns / 1ps

module tb_mac_test_udp_exact_once;

reg rst_n = 1'b0;
reg gmii_tx_clk = 1'b0;
reg gmii_rx_clk = 1'b0;
reg gmii_rx_dv = 1'b0;
reg [7:0] gmii_rxd = 8'd0;
wire gmii_tx_en;
wire [7:0] gmii_txd;
wire [7:0] aggregate_data;
wire aggregate_valid;
reg aggregate_ready = 1'b1;
wire [23:0] aggregate_packet_data;
wire aggregate_packet_valid;

reg model_packet_valid = 1'b0;
reg [15:0] model_packet_length = 16'd8;
reg model_read_valid = 1'b0;
reg [7:0] model_read_data = 8'd0;
reg [7:0] model_seed = 8'd0;

integer observed_bytes;
integer observed_packets;
integer timeout;

always #4.0 gmii_tx_clk = ~gmii_tx_clk;
always #4.3 gmii_rx_clk = ~gmii_rx_clk;

mac_test dut (
    .rst_n(rst_n),
    .pack_total_len(32'd200),
    .gmii_tx_clk(gmii_tx_clk),
    .gmii_rx_clk(gmii_rx_clk),
    .gmii_rx_dv(gmii_rx_dv),
    .gmii_rxd(gmii_rxd),
    .gmii_tx_en(gmii_tx_en),
    .gmii_txd(gmii_txd),
    .aggregate_data(aggregate_data),
    .aggregate_valid(aggregate_valid),
    .aggregate_ready(aggregate_ready),
    .aggregate_packet_data(aggregate_packet_data),
    .aggregate_packet_valid(aggregate_packet_valid)
);

always @(posedge gmii_tx_clk) begin
    model_read_valid <= dut.udp_rec_ram_read_en;
    if (dut.udp_rec_ram_read_en)
        model_read_data <= model_seed + dut.udp_rec_ram_read_addr[7:0];
end

task send_and_check_packet;
    input integer payload_length;
    input [7:0] seed;
    begin
        @(negedge gmii_tx_clk);
        model_seed = seed;
        model_packet_length = payload_length + 8;
        model_packet_valid = 1'b1;
        observed_bytes = 0;
        timeout = 0;

        while (observed_packets == 0 && timeout < payload_length + 500) begin
            @(posedge gmii_tx_clk);
            #1;
            if (aggregate_valid && aggregate_ready) begin
                if (aggregate_data !== (seed + observed_bytes[7:0]))
                    $fatal(1, "aggregate byte mismatch at %0d: %02x",
                           observed_bytes, aggregate_data);
                observed_bytes = observed_bytes + 1;
            end
            if (aggregate_packet_valid) begin
                observed_packets = observed_packets + 1;
                if (aggregate_packet_data[15:0] != payload_length)
                    $fatal(1, "descriptor length mismatch: %0d",
                           aggregate_packet_data[15:0]);
                if (observed_bytes != payload_length)
                    $fatal(1, "descriptor published after %0d of %0d bytes",
                           observed_bytes, payload_length);
            end
            timeout = timeout + 1;
        end

        if (observed_packets != 1)
            $fatal(1, "packet descriptor count mismatch: %0d",
                   observed_packets);

        @(negedge gmii_tx_clk);
        model_packet_valid = 1'b0;
        repeat (500) begin
            @(posedge gmii_tx_clk);
            #1;
            if (aggregate_valid || aggregate_packet_valid)
                $fatal(1, "completed packet was replayed by MAC scheduler");
        end
    end
endtask

initial begin
    force dut.udp_rec_data_valid = model_packet_valid;
    force dut.udp_rec_data_length = model_packet_length;
    force dut.udp_rec_ram_read_valid = model_read_valid;
    force dut.udp_rec_ram_rdata = model_read_data;
    force dut.mac_not_exist = 1'b0;
    force dut.almost_full = 1'b0;
    force dut.udp_ram_data_req = 1'b1;
    force dut.mac_send_end = 1'b1;

    repeat (10) @(posedge gmii_tx_clk);
    rst_n = 1'b1;
    repeat (5) @(posedge gmii_tx_clk);

    observed_packets = 0;
    aggregate_ready = 1'b1;
    send_and_check_packet(64, 8'h20);

    observed_packets = 0;
    fork
        begin
            repeat (20) @(posedge gmii_tx_clk);
            repeat (12) begin
                aggregate_ready = 1'b0;
                repeat (17) @(posedge gmii_tx_clk);
                aggregate_ready = 1'b1;
                repeat (29) @(posedge gmii_tx_clk);
            end
        end
        begin
            send_and_check_packet(1400, 8'h80);
        end
    join
    aggregate_ready = 1'b1;

    if (dut.aggregate_packet_id != 8'd2)
        $fatal(1, "packet ID did not advance exactly twice: %0d",
               dut.aggregate_packet_id);

    $display("TEST PASSED: mac_test exact-once UDP dispatch and byte count");
    $finish;
end

endmodule
