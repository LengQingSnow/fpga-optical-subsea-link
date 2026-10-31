`timescale 1ns / 1ps

module tb_async_byte_fifo;

reg wr_clk;
reg rd_clk;
reg wr_rst_n;
reg rd_rst_n;
reg wr_en;
reg [7:0] wr_data;
reg rd_en;
wire wr_full;
wire [7:0] rd_data;
wire rd_valid;
wire rd_empty;
integer errors;
integer read_count;

async_byte_fifo #(
    .ADDR_WIDTH(4)
) dut (
    .wr_clk    (wr_clk),
    .wr_rst_n  (wr_rst_n),
    .wr_en     (wr_en),
    .wr_data   (wr_data),
    .wr_full   (wr_full),
    .rd_clk    (rd_clk),
    .rd_rst_n  (rd_rst_n),
    .rd_en     (rd_en),
    .rd_data   (rd_data),
    .rd_valid  (rd_valid),
    .rd_empty  (rd_empty)
);

always #5 wr_clk = ~wr_clk;
always #7 rd_clk = ~rd_clk;

always @(posedge rd_clk) begin
    if (rd_valid) begin
        if (rd_data !== (8'h40 + read_count[7:0])) begin
            $display("ERROR: expected %02x got %02x", 8'h40 + read_count[7:0], rd_data);
            errors = errors + 1;
        end
        read_count = read_count + 1;
    end
end

initial begin
    wr_clk = 1'b0;
    rd_clk = 1'b0;
    wr_rst_n = 1'b0;
    rd_rst_n = 1'b0;
    wr_en = 1'b0;
    wr_data = 8'd0;
    rd_en = 1'b0;
    errors = 0;
    read_count = 0;

    repeat (3) @(posedge wr_clk);
    wr_rst_n = 1'b1;
    repeat (3) @(posedge rd_clk);
    rd_rst_n = 1'b1;

    repeat (4) @(posedge wr_clk);
    @(negedge wr_clk);
    wr_en = 1'b1;
    wr_data = 8'h40;
    @(negedge wr_clk); wr_data = 8'h41;
    @(negedge wr_clk); wr_data = 8'h42;
    @(negedge wr_clk); wr_data = 8'h43;
    @(negedge wr_clk); wr_data = 8'h44;
    @(negedge wr_clk); wr_data = 8'h45;
    @(negedge wr_clk); wr_data = 8'h46;
    @(negedge wr_clk); wr_data = 8'h47;
    @(negedge wr_clk);
    wr_en = 1'b0;

    repeat (5) @(posedge rd_clk);
    rd_en = 1'b1;
    wait (read_count == 8);
    @(posedge rd_clk);
    rd_en = 1'b0;

    repeat (3) @(posedge rd_clk);
    if (!rd_empty) begin
        $display("ERROR: FIFO did not return to empty");
        errors = errors + 1;
    end
    if (errors == 0)
        $display("PASS: async_byte_fifo simulation completed");
    else
        $display("FAIL: async_byte_fifo found %0d errors", errors);
    $finish;
end

endmodule
