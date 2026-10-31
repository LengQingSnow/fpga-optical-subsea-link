`timescale 1ns/1ps

module tb_axi_dataset_read_scheduler;

localparam integer ADDR_WIDTH = 32;
localparam integer DATA_WIDTH = 128;
localparam integer BEAT_BYTES = DATA_WIDTH / 8;

reg clk = 1'b0;
reg rst_n = 1'b0;
reg enable_image = 1'b0;
reg enable_waveform = 1'b0;
reg image_fifo_almost_full = 1'b0;
reg waveform_fifo_almost_full = 1'b0;
reg [DATA_WIDTH-1:0] m_axi_rdata = {DATA_WIDTH{1'b0}};
reg m_axi_rvalid = 1'b0;
reg m_axi_rlast = 1'b0;
reg [1:0] m_axi_rresp = 2'b00;
reg m_axi_arready = 1'b1;

wire [ADDR_WIDTH-1:0] m_axi_araddr;
wire [7:0] m_axi_arlen;
wire [2:0] m_axi_arsize;
wire [1:0] m_axi_arburst;
wire m_axi_arvalid;
wire m_axi_rready;
wire [DATA_WIDTH-1:0] image_fifo_wdata;
wire image_fifo_wen;
wire [DATA_WIDTH-1:0] waveform_fifo_wdata;
wire waveform_fifo_wen;
wire image_wrap_pulse;
wire waveform_wrap_pulse;
wire [31:0] read_error_count;

integer image_bursts = 0;
integer waveform_bursts = 0;
integer image_beats = 0;
integer waveform_beats = 0;
integer cycle_count = 0;
integer response_beats = 0;
integer response_total = 0;
integer active_kind = -1;
reg response_active = 1'b0;
reg [31:0] expected_image_addr = 32'h0010_0000;
reg [31:0] expected_waveform_addr = 32'h0200_0000;

always #2.5 clk = ~clk;

axi_dataset_read_scheduler #(
    .AXI_ADDR_WIDTH(ADDR_WIDTH),
    .AXI_DATA_WIDTH(DATA_WIDTH),
    .BURST_BEATS(4),
    .IMAGE_BASE(32'h0010_0000),
    .IMAGE_BYTES(160),
    .WAVEFORM_BASE(32'h0200_0000),
    .WAVEFORM_BYTES(96)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .enable_image(enable_image),
    .enable_waveform(enable_waveform),
    .image_fifo_almost_full(image_fifo_almost_full),
    .waveform_fifo_almost_full(waveform_fifo_almost_full),
    .m_axi_araddr(m_axi_araddr),
    .m_axi_arlen(m_axi_arlen),
    .m_axi_arsize(m_axi_arsize),
    .m_axi_arburst(m_axi_arburst),
    .m_axi_arvalid(m_axi_arvalid),
    .m_axi_arready(m_axi_arready),
    .m_axi_rdata(m_axi_rdata),
    .m_axi_rvalid(m_axi_rvalid),
    .m_axi_rlast(m_axi_rlast),
    .m_axi_rresp(m_axi_rresp),
    .m_axi_rready(m_axi_rready),
    .image_fifo_wdata(image_fifo_wdata),
    .image_fifo_wen(image_fifo_wen),
    .waveform_fifo_wdata(waveform_fifo_wdata),
    .waveform_fifo_wen(waveform_fifo_wen),
    .image_wrap_pulse(image_wrap_pulse),
    .waveform_wrap_pulse(waveform_wrap_pulse),
    .read_error_count(read_error_count)
);

always @(posedge clk) begin
    cycle_count <= cycle_count + 1;
    m_axi_rvalid <= 1'b0;
    m_axi_rlast <= 1'b0;

    if (!response_active && m_axi_arvalid && m_axi_arready) begin
        response_active <= 1'b1;
        response_beats <= 0;
        response_total <= m_axi_arlen + 1;
        if (m_axi_araddr[31:24] == 8'h02) begin
            active_kind <= 1;
            if (m_axi_araddr !== expected_waveform_addr) begin
                $fatal(1, "waveform address expected %08x got %08x",
                       expected_waveform_addr, m_axi_araddr);
            end
            expected_waveform_addr <= expected_waveform_addr +
                                      ((m_axi_arlen + 1) * BEAT_BYTES);
            if (expected_waveform_addr +
                ((m_axi_arlen + 1) * BEAT_BYTES) >= 32'h0200_0060)
                expected_waveform_addr <= 32'h0200_0000;
            waveform_bursts <= waveform_bursts + 1;
        end else begin
            active_kind <= 0;
            if (m_axi_araddr !== expected_image_addr) begin
                $fatal(1, "image address expected %08x got %08x",
                       expected_image_addr, m_axi_araddr);
            end
            expected_image_addr <= expected_image_addr +
                                   ((m_axi_arlen + 1) * BEAT_BYTES);
            if (expected_image_addr +
                ((m_axi_arlen + 1) * BEAT_BYTES) >= 32'h0010_00A0)
                expected_image_addr <= 32'h0010_0000;
            image_bursts <= image_bursts + 1;
        end
    end else if (response_active && m_axi_rready) begin
        m_axi_rvalid <= 1'b1;
        m_axi_rdata <= {
            32'hC000_0000 | cycle_count[31:0],
            32'hB000_0000 | cycle_count[31:0],
            32'hA000_0000 | cycle_count[31:0],
            cycle_count[31:0]
        };
        m_axi_rlast <= (response_beats == response_total - 1);
        response_beats <= response_beats + 1;
        if (response_beats == response_total - 1)
            response_active <= 1'b0;
    end

    if (image_fifo_wen) begin
        image_beats <= image_beats + 1;
        if (active_kind != 0)
            $fatal(1, "image FIFO written during waveform burst");
        if (image_fifo_wdata !== m_axi_rdata)
            $fatal(1, "image FIFO data mismatch");
    end
    if (waveform_fifo_wen) begin
        waveform_beats <= waveform_beats + 1;
        if (active_kind != 1)
            $fatal(1, "waveform FIFO written during image burst");
        if (waveform_fifo_wdata !== m_axi_rdata)
            $fatal(1, "waveform FIFO data mismatch");
    end
end

initial begin
    repeat (8) @(posedge clk);
    rst_n <= 1'b1;
    enable_image <= 1'b1;
    enable_waveform <= 1'b1;

    // A FIFO may cross its almost-full threshold after an AXI burst has
    // started.  The accepted burst must still drain completely; otherwise
    // the shared AXI read channel deadlocks and blocks the other dataset.
    wait (response_active && (active_kind == 1) &&
          (response_beats == 1));
    waveform_fifo_almost_full <= 1'b1;
    wait (!response_active);
    repeat (20) @(posedge clk);
    waveform_fifo_almost_full <= 1'b0;

    wait (image_bursts >= 4 && waveform_bursts >= 4);
    image_fifo_almost_full <= 1'b1;
    repeat (80) @(posedge clk);
    if (waveform_bursts < 8)
        $fatal(1, "waveform did not continue while image FIFO was full");
    image_fifo_almost_full <= 1'b0;

    wait (image_bursts >= 8 && waveform_bursts >= 10);
    if (image_beats == 0 || waveform_beats == 0)
        $fatal(1, "both streams must receive data");
    if (read_error_count != 0)
        $fatal(1, "unexpected AXI read errors: %0d", read_error_count);
    if (m_axi_arsize != 3'd4 || m_axi_arburst != 2'b01)
        $fatal(1, "invalid AXI burst attributes");

    $display("PASS tb_axi_dataset_read_scheduler image_bursts=%0d waveform_bursts=%0d",
             image_bursts, waveform_bursts);
    $finish;
end

initial begin
    #200000;
    $fatal(1, "timeout");
end

endmodule
