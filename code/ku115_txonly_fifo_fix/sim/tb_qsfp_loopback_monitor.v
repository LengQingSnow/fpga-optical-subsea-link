`timescale 1ns / 1ps

module tb_qsfp_loopback_monitor;

reg tx_clk = 1'b0;
reg rx_clk = 1'b0;
reg tx_rst_n = 1'b0;
reg rx_rst_n = 1'b0;
reg [255:0] tx_tdata = 256'd0;
reg tx_tvalid = 1'b0;
reg tx_tready = 1'b0;
reg tx_tlast = 1'b0;
reg [255:0] rx_tdata = 256'd0;
reg [31:0] rx_tkeep = 32'hffff_ffff;
reg rx_tvalid = 1'b0;
reg rx_tlast = 1'b0;

wire [31:0] tx_frame_count;
wire [31:0] rx_frame_count;
wire [31:0] data_error_count;
wire [31:0] half_swap_error_count;
wire [31:0] boundary_error_count;
wire [31:0] underflow_count;
wire [31:0] idle_frame_count;
wire [31:0] data_frame_count;
wire reference_overflow_sticky;
wire header_error_sticky;
wire [255:0] expected_data_debug;
wire expected_tlast_debug;
wire expected_valid_debug;

integer errors = 0;
integer index;
reg [255:0] frame_data [0:15];

always #3.103 tx_clk = ~tx_clk;
always #3.107 rx_clk = ~rx_clk;

qsfp_loopback_monitor dut (
    .tx_clk(tx_clk),
    .tx_rst_n(tx_rst_n),
    .tx_tdata(tx_tdata),
    .tx_tvalid(tx_tvalid),
    .tx_tready(tx_tready),
    .tx_tlast(tx_tlast),
    .rx_clk(rx_clk),
    .rx_rst_n(rx_rst_n),
    .rx_tdata(rx_tdata),
    .rx_tkeep(rx_tkeep),
    .rx_tvalid(rx_tvalid),
    .rx_tlast(rx_tlast),
    .tx_frame_count(tx_frame_count),
    .rx_frame_count(rx_frame_count),
    .data_error_count(data_error_count),
    .half_swap_error_count(half_swap_error_count),
    .boundary_error_count(boundary_error_count),
    .underflow_count(underflow_count),
    .idle_frame_count(idle_frame_count),
    .data_frame_count(data_frame_count),
    .reference_overflow_sticky(reference_overflow_sticky),
    .header_error_sticky(header_error_sticky),
    .expected_data_debug(expected_data_debug),
    .expected_tlast_debug(expected_tlast_debug),
    .expected_valid_debug(expected_valid_debug)
);

task send_tx_beat;
    input [255:0] data;
    input last;
    begin
        @(negedge tx_clk);
        tx_tdata = data;
        tx_tlast = last;
        tx_tvalid = 1'b1;
        tx_tready = 1'b1;
        @(negedge tx_clk);
        tx_tvalid = 1'b0;
        tx_tready = 1'b0;
        tx_tlast = 1'b0;
    end
endtask

task send_rx_beat;
    input [255:0] data;
    input [31:0] keep;
    input last;
    begin
        @(negedge rx_clk);
        rx_tdata = data;
        rx_tkeep = keep;
        rx_tlast = last;
        rx_tvalid = 1'b1;
        @(negedge rx_clk);
        rx_tvalid = 1'b0;
        rx_tlast = 1'b0;
        rx_tkeep = 32'hffff_ffff;
    end
endtask

initial begin
    frame_data[0] = {64'hd5c01acffc1d5aa5, 8'h01, 8'h06, 16'h0000,
                     32'h00000001, 128'h112233445566778899aabbccddeeff00};
    for (index = 1; index < 16; index = index + 1)
        frame_data[index] = {32'h10000000 + index,
                             224'h01234567_89abcdef_00112233_44556677_8899aabb_ccddeeff_12345678};

    repeat (8) @(posedge tx_clk);
    tx_rst_n = 1'b1;
    rx_rst_n = 1'b1;

    for (index = 0; index < 16; index = index + 1)
        send_tx_beat(frame_data[index], index == 15);
    repeat (12) @(posedge rx_clk);
    // The Aurora link carries one continuous custom-frame byte stream.  Its
    // RX AXI interface therefore does not provide the custom 512-byte TLAST.
    for (index = 0; index < 16; index = index + 1)
        send_rx_beat(frame_data[index], 32'hffff_ffff, 1'b0);
    repeat (12) @(posedge rx_clk);

    if (tx_frame_count != 1 || rx_frame_count != 1 || idle_frame_count != 1) begin
        $display("ERROR: exact frame counters tx=%0d rx=%0d idle=%0d",
                 tx_frame_count, rx_frame_count, idle_frame_count);
        errors = errors + 1;
    end
    if (data_error_count != 0 || boundary_error_count != 0 || underflow_count != 0) begin
        $display("ERROR: exact frame produced errors data=%0d boundary=%0d underflow=%0d",
                 data_error_count, boundary_error_count, underflow_count);
        errors = errors + 1;
    end
    if (half_swap_error_count != 16) begin
        $display("ERROR: half-swap diagnostic expected 16 mismatches got %0d",
                 half_swap_error_count);
        errors = errors + 1;
    end

    send_tx_beat({64'hd5c01acffc1d5aa5, 8'h01, 8'h07, 16'h0004,
                  32'h00000002, 128'h00112233445566778899aabbccddeeff}, 1'b1);
    repeat (8) @(posedge rx_clk);
    send_rx_beat({64'hd5c01acffc1d5aa5, 8'h01, 8'h07, 16'h0004,
                  32'h00000002, 128'h00112233445566778899aabbccddeefe},
                 32'hffff_fffe, 1'b0);
    repeat (8) @(posedge rx_clk);

    if (data_error_count != 1 || boundary_error_count != 1 || data_frame_count != 1) begin
        $display("ERROR: corruption counters data=%0d boundary=%0d data_frames=%0d",
                 data_error_count, boundary_error_count, data_frame_count);
        errors = errors + 1;
    end

    send_rx_beat(256'hdeadbeef, 32'hffff_ffff, 1'b1);
    repeat (8) @(posedge rx_clk);
    if (underflow_count != 1) begin
        $display("ERROR: expected one underflow got %0d", underflow_count);
        errors = errors + 1;
    end
    if (reference_overflow_sticky || header_error_sticky) begin
        $display("ERROR: unexpected sticky flags overflow=%b header=%b",
                 reference_overflow_sticky, header_error_sticky);
        errors = errors + 1;
    end

    if (errors == 0)
        $display("TEST PASSED: qsfp_loopback_monitor exact and fault cases");
    else
        $fatal(1, "qsfp_loopback_monitor found %0d errors", errors);
    $finish;
end

endmodule
