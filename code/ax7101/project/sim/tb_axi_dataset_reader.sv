`timescale 1ns/1ps

module tb_axi_dataset_reader;

reg clk = 1'b0;
reg rst_n = 1'b0;
reg calib = 1'b0;
reg image_full = 1'b0;
reg waveform_full = 1'b0;
wire [31:0] araddr;
wire [7:0] arlen;
wire [2:0] arsize;
wire [1:0] arburst;
wire arvalid;
reg arready = 1'b1;
reg [63:0] rdata = 64'd0;
reg rvalid = 1'b0;
reg rlast = 1'b0;
reg [1:0] rresp = 2'b00;
wire rready;
wire [63:0] image_wdata;
wire image_wen;
wire [63:0] waveform_wdata;
wire waveform_wen;
wire image_ready;
wire waveform_ready;
wire [1439:0] image_crc_table;
wire [31:0] waveform_crc;
wire [31:0] descriptor_reads;
wire [31:0] read_errors;

integer beat = 0;
integer total = 0;
integer active_kind = 0;
integer image_writes = 0;
integer waveform_writes = 0;
reg response_active = 1'b0;

always #5 clk = ~clk;

axi_dataset_reader #(
    .AXI_DATA_WIDTH(64),
    .BURST_BEATS(4),
    .IMAGE_BYTES(64),
    .WAVEFORM_BYTES(64),
    .POLL_DELAY_CYCLES(8)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .init_calib_complete(calib),
    .image_fifo_almost_full(image_full),
    .waveform_fifo_almost_full(waveform_full),
    .m_axi_araddr(araddr),
    .m_axi_arlen(arlen),
    .m_axi_arsize(arsize),
    .m_axi_arburst(arburst),
    .m_axi_arvalid(arvalid),
    .m_axi_arready(arready),
    .m_axi_rdata(rdata),
    .m_axi_rvalid(rvalid),
    .m_axi_rlast(rlast),
    .m_axi_rresp(rresp),
    .m_axi_rready(rready),
    .image_fifo_wdata(image_wdata),
    .image_fifo_wen(image_wen),
    .waveform_fifo_wdata(waveform_wdata),
    .waveform_fifo_wen(waveform_wen),
    .image_ready(image_ready),
    .waveform_ready(waveform_ready),
    .image_crc_table(image_crc_table),
    .waveform_crc32(waveform_crc),
    .descriptor_read_count(descriptor_reads),
    .read_error_count(read_errors)
);

function [63:0] descriptor_word;
    input integer index;
    begin
        descriptor_word = 64'd0;
        case (index)
            0: descriptor_word = 64'h0000_0001_4444_5841;
            3: descriptor_word = 64'h0000_0003_0000_002D;
            4: descriptor_word = 64'hA000_0002_A000_0001;
            26: descriptor_word = 64'hB000_0001_A000_002D;
            default: descriptor_word = 64'd0;
        endcase
    end
endfunction

always @(posedge clk) begin
    rvalid <= 1'b0;
    rlast <= 1'b0;

    if (!response_active && arvalid && arready) begin
        response_active <= 1'b1;
        beat <= 0;
        total <= arlen + 1;
        if (araddr == 32'h0000_0000)
            active_kind <= 0;
        else if (araddr == 32'h0010_0000)
            active_kind <= 1;
        else if (araddr == 32'h0200_0000)
            active_kind <= 2;
        else
            $fatal(1, "unexpected AXI address %08x", araddr);
    end else if (response_active && rready) begin
        rvalid <= 1'b1;
        if (active_kind == 0)
            rdata <= descriptor_word(beat);
        else
            rdata <= {32'hDADA_0000 | beat, 32'hCACA_0000 | beat};
        rlast <= (beat == total - 1);
        beat <= beat + 1;
        if (beat == total - 1)
            response_active <= 1'b0;
    end

    if (image_wen)
        image_writes <= image_writes + 1;
    if (waveform_wen)
        waveform_writes <= waveform_writes + 1;
end

initial begin
    repeat (5) @(posedge clk);
    rst_n <= 1'b1;
    calib <= 1'b1;

    wait (image_ready && waveform_ready);
    if (descriptor_reads != 1)
        $fatal(1, "expected one descriptor read");
    if (image_crc_table[31:0] != 32'hA000_0001 ||
        image_crc_table[63:32] != 32'hA000_0002 ||
        image_crc_table[44*32 +: 32] != 32'hA000_002D)
        $fatal(1, "image CRC table parse failed");
    if (waveform_crc != 32'hB000_0001)
        $fatal(1, "waveform CRC parse failed");

    wait (image_writes >= 4 && waveform_writes >= 4);
    if (read_errors != 0)
        $fatal(1, "unexpected read errors");
    if (arsize != 3'd3 || arburst != 2'b01)
        $fatal(1, "incorrect AXI attributes");

    $display("PASS tb_axi_dataset_reader");
    $finish;
end

initial begin
    #200000;
    $fatal(1, "timeout");
end

endmodule
