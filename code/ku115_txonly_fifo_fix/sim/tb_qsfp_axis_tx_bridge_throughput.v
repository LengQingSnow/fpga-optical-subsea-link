`timescale 1ns / 1ps

module tb_qsfp_axis_tx_bridge_throughput;

localparam FRAME_COUNT = 50;
localparam SOURCE_WORD_COUNT = FRAME_COUNT * 32;
localparam TX_BEAT_COUNT = FRAME_COUNT * 16;

reg source_clk = 1'b0;
reg tx_clk = 1'b0;
reg source_rst_n = 1'b0;
reg tx_rst_n = 1'b0;
reg link_ready = 1'b0;
reg [127:0] source_data = 128'd0;
reg source_valid = 1'b0;
reg source_frame_start = 1'b0;
reg source_frame_end = 1'b0;
wire [255:0] tx_tdata;
wire [31:0] tx_tkeep;
wire tx_tvalid;
reg tx_tready = 1'b0;
wire tx_tlast;
wire overflow_sticky;
wire source_frame_error_sticky;

integer source_index;
integer tx_index = 0;
integer tx_cycle = 0;
integer timeout_cycles;
integer errors = 0;
reg [127:0] expected_first;
reg [127:0] expected_second;

always #4.0 source_clk = ~source_clk;
always #3.103 tx_clk = ~tx_clk;

qsfp_axis_tx_bridge #(
    .FIFO_ADDR_WIDTH(4)
) dut (
    .source_clk(source_clk),
    .source_rst_n(source_rst_n),
    .link_ready(link_ready),
    .source_data(source_data),
    .source_valid(source_valid),
    .source_frame_start(source_frame_start),
    .source_frame_end(source_frame_end),
    .tx_clk(tx_clk),
    .tx_rst_n(tx_rst_n),
    .tx_tdata(tx_tdata),
    .tx_tkeep(tx_tkeep),
    .tx_tvalid(tx_tvalid),
    .tx_tready(tx_tready),
    .tx_tlast(tx_tlast),
    .overflow_sticky(overflow_sticky),
    .source_frame_error_sticky(source_frame_error_sticky)
);

always @(posedge tx_clk) begin
    tx_cycle <= tx_cycle + 1;
    tx_tready <= (tx_cycle[3:0] >= 4'd4);
    if (tx_tvalid && tx_tready) begin
        expected_first = {32'h60000000 + tx_index*2,
                          96'h0123456789abcdef00112233};
        expected_second = {32'h60000000 + tx_index*2 + 1,
                           96'h0123456789abcdef00112233};
        if (tx_tdata !== {expected_first, expected_second}) begin
            $display("ERROR: throughput beat %0d data mismatch", tx_index);
            errors = errors + 1;
        end
        if (tx_tkeep !== 32'hffff_ffff || tx_tlast !== ((tx_index & 15) == 15)) begin
            $display("ERROR: throughput beat %0d keep/last mismatch", tx_index);
            errors = errors + 1;
        end
        tx_index = tx_index + 1;
    end
end

initial begin
    repeat (8) @(posedge source_clk);
    source_rst_n = 1'b1;
    tx_rst_n = 1'b1;
    link_ready = 1'b1;
    wait (dut.fifo_wr_ready === 1'b1);
    repeat (2) @(posedge source_clk);

    for (source_index = 0; source_index < SOURCE_WORD_COUNT; source_index = source_index + 1) begin
        @(negedge source_clk);
        source_valid = 1'b1;
        source_data = {32'h60000000 + source_index,
                       96'h0123456789abcdef00112233};
        source_frame_start = ((source_index & 31) == 0);
        source_frame_end = ((source_index & 31) == 31);
    end
    @(negedge source_clk);
    source_valid = 1'b0;
    source_frame_start = 1'b0;
    source_frame_end = 1'b0;

    timeout_cycles = 0;
    while ((tx_index != TX_BEAT_COUNT) && (timeout_cycles < 12000)) begin
        @(posedge tx_clk);
        timeout_cycles = timeout_cycles + 1;
    end

    if (tx_index != TX_BEAT_COUNT) begin
        $display("ERROR: expected %0d beats, received %0d", TX_BEAT_COUNT, tx_index);
        errors = errors + 1;
    end
    if (overflow_sticky || source_frame_error_sticky) begin
        $display("ERROR: sustained stream status overflow=%b frame_error=%b",
                 overflow_sticky, source_frame_error_sticky);
        errors = errors + 1;
    end

    if (errors == 0)
        $display("TEST PASSED: qsfp_axis_tx_bridge sustained 16G stream");
    else
        $fatal(1, "qsfp_axis_tx_bridge throughput found %0d errors", errors);
    $finish;
end

endmodule
