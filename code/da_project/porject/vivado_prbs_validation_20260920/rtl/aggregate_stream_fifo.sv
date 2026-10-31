`timescale 1ns/1ps

module aggregate_stream_fifo #(
    parameter integer FIFO_WRITE_DEPTH = 2048,
    parameter integer START_THRESHOLD_READ_WORDS = 256,
    parameter integer HIGH_WATER_HEADROOM_WRITE_WORDS = 16
) (
    input  logic         wr_clk,
    input  logic         wr_rst_n,
    input  logic [255:0] s_data,
    input  logic         s_valid,
    output logic         s_ready,
    input  logic         rd_clk,
    input  logic         rd_rst_n,
    output logic [63:0]  m_data,
    output logic         m_valid,
    input  logic         m_ready,
    output logic         streaming,
    output logic         near_full,
    output logic         overflow,
    output logic         underflow
);
    localparam integer RD_COUNT_WIDTH = $clog2(FIFO_WRITE_DEPTH * 4) + 1;
    localparam integer RESPONSE_DEPTH = 8;
    localparam integer RESPONSE_PTR_WIDTH = $clog2(RESPONSE_DEPTH);

    logic fifo_full;
    logic fifo_empty;
    logic fifo_prog_empty;
    logic fifo_prog_full;
    logic fifo_wr_busy;
    logic fifo_rd_busy;
    logic fifo_reset;
    logic [255:0] fifo_write_data;
    logic [63:0] fifo_read_data;
    logic fifo_read_valid;
    logic fifo_read_enable;
    logic xpm_overflow;
    logic xpm_underflow;
    (* ram_style = "distributed" *) logic [63:0] response_mem [0:RESPONSE_DEPTH-1];
    logic [RESPONSE_PTR_WIDTH-1:0] response_write_ptr;
    logic [RESPONSE_PTR_WIDTH-1:0] response_read_ptr;
    logic [RESPONSE_PTR_WIDTH:0] response_count;
    logic [RESPONSE_PTR_WIDTH:0] pending_count;
    logic [RESPONSE_PTR_WIDTH+1:0] reserved_count;
    logic response_consume;

    // XPM requires rst to be synchronous to wr_clk. The macro propagates
    // reset into its read domain internally; rd_rst_n only resets read logic.
    assign fifo_reset = !wr_rst_n;
    assign s_ready = !fifo_full && !fifo_wr_busy;
    assign near_full = fifo_prog_full;
    assign m_data = response_mem[response_read_ptr];
    assign m_valid = streaming && (response_count != 0);
    assign response_consume = m_valid && m_ready;
    assign reserved_count = response_count + pending_count;

    // Read credits depend only on local registered occupancy. In particular,
    // downstream m_ready never reaches the block-RAM enable path.
    assign fifo_read_enable = rd_rst_n && streaming && !fifo_empty &&
                              !fifo_rd_busy &&
                              (reserved_count < RESPONSE_DEPTH);

    // XPM emits the least-significant narrow word first. Reverse only the
    // four 64-bit chunks so the earliest Aurora bytes remain first in time.
    assign fifo_write_data = {s_data[63:0], s_data[127:64],
                              s_data[191:128], s_data[255:192]};

    always_ff @(posedge wr_clk) begin
        if (!wr_rst_n || fifo_wr_busy)
            overflow <= 1'b0;
        else if ((s_valid && !s_ready) || xpm_overflow)
            overflow <= 1'b1;
    end

    always_ff @(posedge rd_clk) begin
        if (!rd_rst_n || fifo_rd_busy) begin
            streaming <= 1'b0;
            underflow <= 1'b0;
        end else begin
            // Do not start the read side merely because the prefetch
            // threshold is reached.  During RFDC/gearbox startup the
            // downstream path can still deassert m_ready; starting then
            // fills the shallow response queue and eventually overflows the
            // aggregate FIFO while Aurora continues to deliver data.
            if (!streaming && !fifo_prog_empty && m_ready)
                streaming <= 1'b1;
            else if (streaming && fifo_empty && (reserved_count == 0) &&
                     !fifo_read_valid)
                streaming <= 1'b0;

            if (xpm_underflow)
                underflow <= 1'b1;
        end
    end

    always_ff @(posedge rd_clk) begin
        if (!rd_rst_n || fifo_rd_busy) begin
            response_write_ptr <= '0;
            response_read_ptr <= '0;
            response_count <= '0;
            pending_count <= '0;
        end else begin
            if (fifo_read_valid) begin
                response_mem[response_write_ptr] <= fifo_read_data;
                response_write_ptr <= response_write_ptr + 1'b1;
            end

            if (response_consume)
                response_read_ptr <= response_read_ptr + 1'b1;

            case ({fifo_read_valid, response_consume})
                2'b10: response_count <= response_count + 1'b1;
                2'b01: response_count <= response_count - 1'b1;
                default: response_count <= response_count;
            endcase

            case ({fifo_read_enable, fifo_read_valid})
                2'b10: pending_count <= pending_count + 1'b1;
                2'b01: pending_count <= pending_count - 1'b1;
                default: pending_count <= pending_count;
            endcase
        end
    end

    xpm_fifo_async #(
        .FIFO_MEMORY_TYPE("block"),
        .ECC_MODE("no_ecc"),
        .RELATED_CLOCKS(0),
        .SIM_ASSERT_CHK(0),
        .FIFO_WRITE_DEPTH(FIFO_WRITE_DEPTH),
        .WRITE_DATA_WIDTH(256),
        .WR_DATA_COUNT_WIDTH($clog2(FIFO_WRITE_DEPTH) + 1),
        .PROG_FULL_THRESH(FIFO_WRITE_DEPTH - HIGH_WATER_HEADROOM_WRITE_WORDS),
        .FULL_RESET_VALUE(0),
        .USE_ADV_FEATURES("1707"),
        .READ_MODE("std"),
        .FIFO_READ_LATENCY(3),
        .READ_DATA_WIDTH(64),
        .RD_DATA_COUNT_WIDTH(RD_COUNT_WIDTH),
        .PROG_EMPTY_THRESH(START_THRESHOLD_READ_WORDS),
        .DOUT_RESET_VALUE("0"),
        .CDC_SYNC_STAGES(2),
        .WAKEUP_TIME(0)
    ) fifo_i (
        .sleep(1'b0),
        .rst(fifo_reset),
        .wr_clk(wr_clk),
        .wr_en(wr_rst_n && s_valid && s_ready),
        .din(fifo_write_data),
        .full(fifo_full),
        .prog_full(fifo_prog_full),
        .wr_data_count(),
        .overflow(xpm_overflow),
        .wr_rst_busy(fifo_wr_busy),
        .almost_full(),
        .wr_ack(),
        .rd_clk(rd_clk),
        .rd_en(fifo_read_enable),
        .dout(fifo_read_data),
        .empty(fifo_empty),
        .prog_empty(fifo_prog_empty),
        .rd_data_count(),
        .underflow(xpm_underflow),
        .rd_rst_busy(fifo_rd_busy),
        .almost_empty(),
        .data_valid(fifo_read_valid),
        .injectsbiterr(1'b0),
        .injectdbiterr(1'b0),
        .sbiterr(),
        .dbiterr()
    );
endmodule
