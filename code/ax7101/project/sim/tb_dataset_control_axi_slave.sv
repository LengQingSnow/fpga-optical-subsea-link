`timescale 1ns/1ps

module tb_dataset_control_axi_slave;

reg clk = 1'b0;
reg rst_n = 1'b0;
reg [31:0] awaddr = 32'd0;
reg awvalid = 1'b0;
wire awready;
reg [63:0] wdata = 64'd0;
reg [7:0] wstrb = 8'd0;
reg wvalid = 1'b0;
wire wready;
wire [1:0] bresp;
wire bvalid;
reg bready = 1'b1;
reg [31:0] araddr = 32'd0;
reg arvalid = 1'b0;
wire arready;
wire [63:0] rdata;
wire [1:0] rresp;
wire rvalid;
reg rready = 1'b1;
wire image_ready;
wire waveform_ready;
wire [1439:0] image_crc_table;
wire [31:0] waveform_crc;
wire [31:0] descriptor_version;

always #5 clk = ~clk;

dataset_control_axi_slave dut (
    .clk(clk),
    .rst_n(rst_n),
    .s_axi_awaddr(awaddr),
    .s_axi_awvalid(awvalid),
    .s_axi_awready(awready),
    .s_axi_wdata(wdata),
    .s_axi_wstrb(wstrb),
    .s_axi_wvalid(wvalid),
    .s_axi_wready(wready),
    .s_axi_bresp(bresp),
    .s_axi_bvalid(bvalid),
    .s_axi_bready(bready),
    .s_axi_araddr(araddr),
    .s_axi_arvalid(arvalid),
    .s_axi_arready(arready),
    .s_axi_rdata(rdata),
    .s_axi_rresp(rresp),
    .s_axi_rvalid(rvalid),
    .s_axi_rready(rready),
    .image_ready(image_ready),
    .waveform_ready(waveform_ready),
    .image_crc_table(image_crc_table),
    .waveform_crc32(waveform_crc),
    .descriptor_version(descriptor_version)
);

task axi_write;
    input [31:0] address;
    input [63:0] data;
    input [7:0] strobe;
    begin
        @(negedge clk);
        awaddr = address;
        awvalid = 1'b1;
        wdata = data;
        wstrb = strobe;
        wvalid = 1'b1;
        while (!(awready && wready))
            @(negedge clk);
        @(negedge clk);
        awvalid = 1'b0;
        wvalid = 1'b0;
        wait (bvalid);
        if (bresp != 2'b00)
            $fatal(1, "write response error");
        @(negedge clk);
    end
endtask

task axi_read_check;
    input [31:0] address;
    input [63:0] expected;
    begin
        @(negedge clk);
        araddr = address;
        arvalid = 1'b1;
        wait (arready);
        @(negedge clk);
        arvalid = 1'b0;
        wait (rvalid);
        if (rresp != 2'b00 || rdata !== expected)
            $fatal(1, "read %08x expected %016x got %016x",
                   address, expected, rdata);
        @(negedge clk);
    end
endtask

initial begin
    repeat (5) @(posedge clk);
    rst_n <= 1'b1;
    repeat (3) @(posedge clk);

    axi_write(32'h0000_0000, 64'h0000_0001_4444_5841, 8'hFF);
    axi_write(32'h0000_0018, 64'h0000_0000_0000_002D, 8'hFF);
    axi_write(32'h0000_0020, 64'h5566_7788_1122_3344, 8'hFF);
    axi_write(32'h0000_00D0, 64'hCAFE_BABE_0000_0000, 8'hF0);
    axi_write(32'h0000_0018, 64'h0000_0003_0000_002D, 8'hF0);

    if (descriptor_version != 32'd1)
        $fatal(1, "descriptor version mismatch");
    if (!image_ready || !waveform_ready)
        $fatal(1, "ready flags were not published");
    if (image_crc_table[31:0] != 32'h1122_3344)
        $fatal(1, "image CRC 1 mismatch");
    if (image_crc_table[63:32] != 32'h5566_7788)
        $fatal(1, "image CRC 2 mismatch");
    if (waveform_crc != 32'hCAFE_BABE)
        $fatal(1, "waveform CRC mismatch");

    axi_read_check(32'h0000_0000, 64'h0000_0001_4444_5841);
    axi_read_check(32'h0000_0020, 64'h5566_7788_1122_3344);

    $display("PASS tb_dataset_control_axi_slave");
    $finish;
end

initial begin
    #100000;
    $fatal(1, "timeout");
end

endmodule
