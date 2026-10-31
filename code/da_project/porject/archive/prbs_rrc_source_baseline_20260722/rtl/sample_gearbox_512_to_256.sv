`timescale 1ns/1ps

module sample_gearbox_512_to_256 (
    input  logic         wr_clk,
    input  logic         wr_rst_n,
    input  logic [511:0] s_data,
    input  logic         s_valid,
    output logic         s_ready,
    input  logic         rd_clk,
    input  logic         rd_rst_n,
    output logic [255:0] m_data,
    output logic         m_valid,
    input  logic         m_ready,
    output logic         overflow,
    output logic         underflow
);
    logic fifo_full;
    logic fifo_empty;
    logic fifo_prog_empty;
    logic fifo_wr_busy;
    logic fifo_rd_busy;
    logic fifo_overflow;
    logic fifo_underflow;
    logic read_started;
    logic fifo_reset;

    assign fifo_reset = !wr_rst_n || !rd_rst_n;
    assign s_ready = !fifo_full && !fifo_wr_busy;
    assign m_valid = read_started && !fifo_empty && !fifo_rd_busy;

    always_ff @(posedge rd_clk) begin
        if (!rd_rst_n || fifo_rd_busy)
            read_started <= 1'b0;
        else if (!fifo_prog_empty)
            read_started <= 1'b1;
    end

    assign overflow = fifo_overflow;
    assign underflow = fifo_underflow;

    xpm_fifo_async #(
        .FIFO_MEMORY_TYPE("block"),
        .ECC_MODE("no_ecc"),
        .RELATED_CLOCKS(1),
        .SIM_ASSERT_CHK(0),
        .FIFO_WRITE_DEPTH(64),
        .WRITE_DATA_WIDTH(512),
        .WR_DATA_COUNT_WIDTH(7),
        .PROG_FULL_THRESH(56),
        .FULL_RESET_VALUE(0),
        .USE_ADV_FEATURES("0707"),
        .READ_MODE("fwft"),
        .FIFO_READ_LATENCY(0),
        .READ_DATA_WIDTH(256),
        .RD_DATA_COUNT_WIDTH(8),
        .PROG_EMPTY_THRESH(16),
        .DOUT_RESET_VALUE("0"),
        .CDC_SYNC_STAGES(2),
        .WAKEUP_TIME(0)
    ) fifo_i (
        .sleep(1'b0),
        .rst(fifo_reset),
        .wr_clk(wr_clk),
        .wr_en(wr_rst_n && s_valid && s_ready),
        .din(s_data),
        .full(fifo_full),
        .prog_full(),
        .wr_data_count(),
        .overflow(fifo_overflow),
        .wr_rst_busy(fifo_wr_busy),
        .almost_full(),
        .wr_ack(),
        .rd_clk(rd_clk),
        .rd_en(rd_rst_n && m_valid && m_ready),
        .dout(m_data),
        .empty(fifo_empty),
        .prog_empty(fifo_prog_empty),
        .rd_data_count(),
        .underflow(fifo_underflow),
        .rd_rst_busy(fifo_rd_busy),
        .almost_empty(),
        .data_valid(),
        .injectsbiterr(1'b0),
        .injectdbiterr(1'b0),
        .sbiterr(),
        .dbiterr()
    );
endmodule
