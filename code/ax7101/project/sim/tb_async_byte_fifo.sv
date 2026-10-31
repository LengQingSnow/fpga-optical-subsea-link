`timescale 1ns/1ps

module tb_async_byte_fifo;

reg wr_clk = 1'b0;
reg rd_clk = 1'b0;
reg rst_n = 1'b0;
reg [127:0] wr_data = 128'd0;
reg wr_en = 1'b0;
reg rd_en = 1'b0;
wire wr_almost_full;
wire [7:0] rd_data;
wire rd_empty;
wire rd_valid;
wire [31:0] overflow_count;
wire [31:0] underflow_count;

integer i;
integer j;
integer received = 0;

always #2.5 wr_clk = ~wr_clk;
always #4.0 rd_clk = ~rd_clk;

async_byte_fifo #(
    .WRITE_WIDTH(128),
    .DEPTH_BYTES(4096),
    .ALMOST_FULL_FREE_BYTES(256)
) dut (
    .wr_clk(wr_clk),
    .wr_rst_n(rst_n),
    .wr_data(wr_data),
    .wr_en(wr_en),
    .wr_almost_full(wr_almost_full),
    .overflow_count(overflow_count),
    .rd_clk(rd_clk),
    .rd_rst_n(rst_n),
    .rd_data(rd_data),
    .rd_en(rd_en),
    .rd_empty(rd_empty),
    .rd_valid(rd_valid),
    .underflow_count(underflow_count)
);

always @(posedge rd_clk) begin
    if (rd_valid) begin
        if (rd_data !== received[7:0])
            $fatal(1, "byte %0d expected %02x got %02x",
                   received, received[7:0], rd_data);
        received <= received + 1;
    end
end

initial begin
    #200;
    repeat (8) @(posedge wr_clk);
    rst_n <= 1'b1;
    wait (!wr_almost_full);
    repeat (2) @(posedge wr_clk);

    for (i = 0; i < 16; i = i + 1) begin
        @(negedge wr_clk);
        for (j = 0; j < 16; j = j + 1)
            wr_data[j*8 +: 8] = i*16+j;
        wr_en = 1'b1;
    end
    @(negedge wr_clk);
    wr_en = 1'b0;

    wait (!rd_empty);
    @(negedge rd_clk);
    rd_en = 1'b1;
    wait (received == 256);
    @(negedge rd_clk);
    rd_en = 1'b0;

    repeat (8) @(posedge rd_clk);
    if (overflow_count != 0 || underflow_count != 0)
        $fatal(1, "unexpected FIFO diagnostics overflow=%0d underflow=%0d",
               overflow_count, underflow_count);
    $display("PASS tb_async_byte_fifo bytes=%0d", received);
    $finish;
end

initial begin
    #100000;
    $fatal(1, "timeout");
end

endmodule
