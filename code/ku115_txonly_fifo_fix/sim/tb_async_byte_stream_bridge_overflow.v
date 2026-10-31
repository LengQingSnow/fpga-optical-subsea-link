`timescale 1ns / 1ps

module tb_async_byte_stream_bridge_overflow;

reg rst_n;
reg wr_clk;
reg rd_clk;
reg [7:0] wr_data;
reg wr_valid;
reg rd_pop;
wire [7:0] rd_data;
wire rd_valid;
wire overflow_sticky;
integer write_index;

async_byte_stream_bridge #(
    .DATA_WIDTH(8),
    .FIFO_ADDR_WIDTH(2),
    .BUFFER_ADDR_WIDTH(1)
) dut (
    .rst_n(rst_n),
    .wr_clk(wr_clk),
    .wr_data(wr_data),
    .wr_valid(wr_valid),
    .rd_clk(rd_clk),
    .rd_data(rd_data),
    .rd_valid(rd_valid),
    .rd_pop(rd_pop),
    .overflow_sticky(overflow_sticky)
);

always #2 wr_clk = ~wr_clk;
always #5 rd_clk = ~rd_clk;

initial begin
    rst_n = 1'b0;
    wr_clk = 1'b0;
    rd_clk = 1'b0;
    wr_data = 8'd0;
    wr_valid = 1'b0;
    rd_pop = 1'b0;
    #13;
    rst_n = 1'b1;

    @(negedge wr_clk);
    wr_valid = 1'b1;
    for (write_index = 0; write_index < 16; write_index = write_index + 1) begin
        wr_data = write_index[7:0];
        @(negedge wr_clk);
    end
    wr_valid = 1'b0;

    repeat (5) @(posedge rd_clk);
    if (overflow_sticky !== 1'b1)
        $fatal(1, "overflow_sticky did not cross into the read domain");

    rd_pop = 1'b1;
    repeat (10) @(posedge rd_clk);
    if (overflow_sticky !== 1'b1)
        $fatal(1, "overflow_sticky cleared after the FIFO drained");

    $display("PASS: async byte stream bridge reports sticky write overflow");
    $finish;
end

endmodule
