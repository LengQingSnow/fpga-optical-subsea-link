`timescale 1ns/1ps

module sample_gearbox_512_to_256 (
    input  logic         wr_clk,
    input  logic         wr_rst_n,
    input  logic [511:0] s_data,
    input  logic         s_valid,
    output logic         s_ready,
    input  logic         rd_clk,
    input  logic         rd_rst_n,
    input  logic         read_start,
    output logic         start_ready,
    output logic [255:0] m_data,
    output logic         m_valid,
    input  logic         m_ready,
    output logic         overflow,
    output logic         underflow
);
    localparam integer RESPONSE_DEPTH = 8;

    logic fifo_full;
    logic fifo_empty;
    logic fifo_prog_empty;
    logic fifo_wr_busy;
    logic fifo_rd_busy;
    logic fifo_overflow;
    logic fifo_underflow;
    logic [255:0] fifo_dout;
    logic fifo_data_valid;
    logic fifo_read_enable;
    logic read_active;
    logic fifo_reset;
    (* ram_style = "distributed" *) logic [255:0] response_mem [0:RESPONSE_DEPTH-1];
    logic [2:0] response_write_ptr;
    logic [2:0] response_read_ptr;
    logic [3:0] output_count;
    logic [3:0] pending_count;
    logic output_valid;
    logic output_consume;
    logic [4:0] reserved_count;

    // XPM requires rst to be synchronous to wr_clk. The macro propagates
    // reset into its read domain internally; rd_rst_n only resets read logic.
    assign fifo_reset = !wr_rst_n;
    assign s_ready = !fifo_full && !fifo_wr_busy;
    assign start_ready = !fifo_prog_empty && !fifo_rd_busy;
    assign m_data = response_mem[response_read_ptr];
    assign m_valid = read_active && output_valid;
    assign output_consume = m_valid && m_ready;

    // Standard-mode XPM reads insert three registered cycles between the BRAM
    // and this interface. Track those in-flight responses together with a
    // shallow distributed-RAM queue. One spare slot lets the BRAM read enable
    // depend only on registered local credits, not the downstream ready path.
    assign reserved_count = output_count + pending_count;

    assign fifo_read_enable = read_active && !fifo_empty && !fifo_rd_busy &&
                              (reserved_count < RESPONSE_DEPTH-1);

    always_ff @(posedge rd_clk) begin
        if (!rd_rst_n || fifo_rd_busy)
            read_active <= 1'b0;
        else if (read_start)
            read_active <= 1'b1;
    end

    always_ff @(posedge rd_clk) begin
        if (!rd_rst_n || fifo_rd_busy) begin
            response_write_ptr <= 3'd0;
            response_read_ptr <= 3'd0;
            output_count <= 4'd0;
            pending_count <= 4'd0;
            output_valid <= 1'b0;
        end else begin
            case ({fifo_read_enable, fifo_data_valid})
                2'b10: pending_count <= pending_count + 1'b1;
                2'b01: pending_count <= pending_count - 1'b1;
                default: pending_count <= pending_count;
            endcase

            if (fifo_data_valid) begin
                response_mem[response_write_ptr] <= fifo_dout;
                response_write_ptr <= response_write_ptr + 1'b1;
            end

            if (output_consume)
                response_read_ptr <= response_read_ptr + 1'b1;

            case ({fifo_data_valid, output_consume})
                2'b10: output_count <= output_count + 1'b1;
                2'b01: output_count <= output_count - 1'b1;
                default: output_count <= output_count;
            endcase

            case ({fifo_data_valid, output_consume})
                2'b10: output_valid <= 1'b1;
                2'b01: output_valid <= (output_count != 1);
                default: output_valid <= output_valid;
            endcase
        end
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
        .USE_ADV_FEATURES("1707"),
        .READ_MODE("std"),
        .FIFO_READ_LATENCY(3),
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
        // Keeping rd_rst_n out of rd_en avoids a global reset-to-BRAM-enable
        // path; fifo_read_enable is credit-limited by the response queue.
        .rd_en(fifo_read_enable),
        .dout(fifo_dout),
        .empty(fifo_empty),
        .prog_empty(fifo_prog_empty),
        .rd_data_count(),
        .underflow(fifo_underflow),
        .rd_rst_busy(fifo_rd_busy),
        .almost_empty(),
        .data_valid(fifo_data_valid),
        .injectsbiterr(1'b0),
        .injectdbiterr(1'b0),
        .sbiterr(),
        .dbiterr()
    );
endmodule
