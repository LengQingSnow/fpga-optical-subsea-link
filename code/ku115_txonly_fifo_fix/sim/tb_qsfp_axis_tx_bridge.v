`timescale 1ns / 1ps

module tb_qsfp_axis_tx_bridge;

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

integer errors = 0;
integer beat_count = 0;
integer cycle_count = 0;
reg [255:0] expected_data [0:15];

always #4.0 source_clk = ~source_clk;
always #3.103 tx_clk = ~tx_clk;

qsfp_axis_tx_bridge dut (
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

task send_word;
    input integer word_index;
    begin
        @(negedge source_clk);
        source_valid = 1'b1;
        source_data = {32'hcafe0000 + word_index, 96'h0123456789abcdef00112233};
        source_frame_start = (word_index == 0);
        source_frame_end = (word_index == 31);
        @(negedge source_clk);
        source_valid = 1'b0;
        source_frame_start = 1'b0;
        source_frame_end = 1'b0;
    end
endtask

always @(posedge tx_clk) begin
    cycle_count <= cycle_count + 1;
    tx_tready <= (cycle_count[2:0] != 3'b011) && (cycle_count[3:0] != 4'b1001);
    if (tx_tvalid && tx_tready) begin
        if (tx_tdata !== expected_data[beat_count]) begin
            $display("ERROR: beat %0d data expected %h got %h", beat_count,
                     expected_data[beat_count], tx_tdata);
            errors = errors + 1;
        end
        if (tx_tkeep !== 32'hffffffff) begin
            $display("ERROR: beat %0d TKEEP was %h", beat_count, tx_tkeep);
            errors = errors + 1;
        end
        if (tx_tlast !== (beat_count == 15)) begin
            $display("ERROR: beat %0d TLAST was %b", beat_count, tx_tlast);
            errors = errors + 1;
        end
        beat_count = beat_count + 1;
    end
end

integer index;
integer timeout_cycles;
reg [127:0] first_word;
reg [127:0] second_word;
initial begin
    for (index = 0; index < 16; index = index + 1) begin
        first_word = {32'hcafe0000 + index*2, 96'h0123456789abcdef00112233};
        second_word = {32'hcafe0000 + index*2 + 1, 96'h0123456789abcdef00112233};
        expected_data[index] = {first_word, second_word};
    end

    repeat (8) @(posedge source_clk);
    source_rst_n = 1'b1;
    tx_rst_n = 1'b1;
    link_ready = 1'b1;
    wait (dut.fifo_wr_ready === 1'b1);
    repeat (2) @(posedge source_clk);

    for (index = 0; index < 32; index = index + 1)
        send_word(index);

    timeout_cycles = 0;
    while ((beat_count != 16) && (timeout_cycles < 2000)) begin
        @(posedge tx_clk);
        timeout_cycles = timeout_cycles + 1;
    end
    if (beat_count != 16)
        $fatal(1, "timeout waiting for AXI beats");

    repeat (5) @(posedge tx_clk);
    if (overflow_sticky || source_frame_error_sticky) begin
        $display("ERROR: unexpected bridge status overflow=%b frame_error=%b",
                 overflow_sticky, source_frame_error_sticky);
        errors = errors + 1;
    end
    if (errors == 0)
        $display("TEST PASSED: qsfp_axis_tx_bridge packing and backpressure");
    else
        $fatal(1, "qsfp_axis_tx_bridge found %0d errors", errors);
    $finish;
end

endmodule
