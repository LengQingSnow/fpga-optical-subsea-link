`timescale 1ns/1ps

module tb_dataset_tx_fifo_adapter;

reg clk = 1'b0;
reg rst_n = 1'b0;
reg meta_valid = 1'b0;
reg meta_ready = 1'b0;
reg [15:0] valid_length = 16'd0;
wire packet_advance;
reg fifo_empty = 1'b1;
reg [7:0] fifo_data = 8'd0;
wire fifo_read_enable;
wire data_valid;
reg data_ready = 1'b0;
wire [7:0] data;
wire data_last;
integer accepted = 0;

always #5 clk = ~clk;

dataset_tx_fifo_adapter dut (
    .clk(clk),
    .rst_n(rst_n),
    .packet_meta_valid(meta_valid),
    .packet_meta_ready(meta_ready),
    .packet_valid_length(valid_length),
    .packet_advance(packet_advance),
    .fifo_empty(fifo_empty),
    .fifo_data(fifo_data),
    .fifo_read_enable(fifo_read_enable),
    .packet_data_valid(data_valid),
    .packet_data_ready(data_ready),
    .packet_data(data),
    .packet_data_last(data_last)
);

always @(posedge clk) begin
    if (data_valid && data_ready) begin
        if (data != accepted[7:0])
            $fatal(1, "data mismatch");
        if (data_last != (accepted == 4))
            $fatal(1, "last mismatch at byte %0d", accepted);
        accepted <= accepted + 1;
        fifo_data <= fifo_data + 1'b1;
    end
    if (fifo_read_enable != (data_valid && data_ready))
        $fatal(1, "FIFO read enable must match data handshake");
end

initial begin
    repeat (4) @(posedge clk);
    rst_n <= 1'b1;
    @(negedge clk);
    valid_length = 5;
    meta_valid = 1'b1;
    meta_ready = 1'b1;
    @(negedge clk);
    if (!packet_advance)
        $fatal(1, "metadata handshake did not advance cursor");
    meta_valid = 1'b0;
    meta_ready = 1'b0;

    repeat (3) @(posedge clk);
    if (data_valid)
        $fatal(1, "empty FIFO must stall");
    fifo_empty = 1'b0;
    data_ready = 1'b1;
    wait (accepted == 5);
    @(negedge clk);
    fifo_empty = 1'b1;
    data_ready = 1'b0;
    repeat (3) @(posedge clk);

    $display("PASS tb_dataset_tx_fifo_adapter");
    $finish;
end

initial begin
    #10000;
    $fatal(1, "timeout");
end

endmodule
