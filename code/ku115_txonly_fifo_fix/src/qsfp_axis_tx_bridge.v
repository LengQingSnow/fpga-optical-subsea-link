`timescale 1ns / 1ps

module qsfp_axis_tx_bridge #(
    parameter FIFO_ADDR_WIDTH = 10
) (
    input              source_clk,
    input              source_rst_n,
    input              link_ready,
    input      [127:0] source_data,
    input              source_valid,
    input              source_frame_start,
    input              source_frame_end,

    input              tx_clk,
    input              tx_rst_n,
    output reg [255:0] tx_tdata,
    output     [31:0]  tx_tkeep,
    output reg         tx_tvalid,
    input              tx_tready,
    output reg         tx_tlast,

    output reg         overflow_sticky,
    output reg         source_frame_error_sticky
);

reg capture_active;
reg have_first_word;
reg [127:0] first_word;
reg fifo_wr_en;
reg [256:0] fifo_wr_data;
wire fifo_wr_full;
wire fifo_wr_ready;

wire [256:0] fifo_rd_data;
wire fifo_rd_valid;
wire fifo_rd_empty;
wire fifo_rd_en;
wire tx_take;
wire [2:0] buffered_after_edge;
reg prefetch_valid;
reg [255:0] prefetch_data;
reg prefetch_last;

assign tx_tkeep = 32'hffff_ffff;
assign tx_take = tx_tvalid && tx_tready;
assign buffered_after_edge = {2'b00, tx_tvalid} +
                             {2'b00, prefetch_valid} -
                             {2'b00, tx_take} +
                             {2'b00, fifo_rd_valid};
assign fifo_rd_en = !fifo_rd_empty && (buffered_after_edge < 3'd2);

qsfp_payload_fifo_xpm #(
    .ADDR_WIDTH(FIFO_ADDR_WIDTH),
    .DATA_WIDTH(257)
) payload_fifo (
    .wr_clk(source_clk),
    .wr_rst_n(source_rst_n),
    .wr_en(fifo_wr_en),
    .wr_data(fifo_wr_data),
    .wr_full(fifo_wr_full),
    .wr_ready(fifo_wr_ready),
    .rd_clk(tx_clk),
    .rd_rst_n(tx_rst_n),
    .rd_en(fifo_rd_en),
    .rd_data(fifo_rd_data),
    .rd_valid(fifo_rd_valid),
    .rd_empty(fifo_rd_empty)
);

always @(posedge source_clk or negedge source_rst_n) begin
    if (!source_rst_n) begin
        capture_active <= 1'b0;
        have_first_word <= 1'b0;
        first_word <= 128'd0;
        fifo_wr_en <= 1'b0;
        fifo_wr_data <= 257'd0;
        overflow_sticky <= 1'b0;
        source_frame_error_sticky <= 1'b0;
    end else begin
        fifo_wr_en <= 1'b0;
        if (!link_ready || !fifo_wr_ready) begin
            capture_active <= 1'b0;
            have_first_word <= 1'b0;
        end else if (source_valid) begin
            if (!capture_active) begin
                if (source_frame_start) begin
                    capture_active <= 1'b1;
                    have_first_word <= 1'b1;
                    first_word <= source_data;
                    if (source_frame_end) begin
                        capture_active <= 1'b0;
                        have_first_word <= 1'b0;
                        source_frame_error_sticky <= 1'b1;
                    end
                end
            end else if (!have_first_word) begin
                if (source_frame_start)
                    source_frame_error_sticky <= 1'b1;
                first_word <= source_data;
                have_first_word <= 1'b1;
                if (source_frame_end) begin
                    capture_active <= 1'b0;
                    have_first_word <= 1'b0;
                    source_frame_error_sticky <= 1'b1;
                end
            end else begin
                if (source_frame_start)
                    source_frame_error_sticky <= 1'b1;
                if (fifo_wr_full) begin
                    overflow_sticky <= 1'b1;
                    capture_active <= 1'b0;
                    have_first_word <= 1'b0;
                end else begin
                    fifo_wr_data <= {source_frame_end, first_word, source_data};
                    fifo_wr_en <= 1'b1;
                    have_first_word <= 1'b0;
                    if (source_frame_end)
                        capture_active <= 1'b0;
                end
            end
        end
    end
end

always @(posedge tx_clk or negedge tx_rst_n) begin
    if (!tx_rst_n) begin
        tx_tdata <= 256'd0;
        tx_tvalid <= 1'b0;
        tx_tlast <= 1'b0;
        prefetch_valid <= 1'b0;
        prefetch_data <= 256'd0;
        prefetch_last <= 1'b0;
    end else begin
        case ({fifo_rd_valid, tx_take})
            2'b01: begin
                if (prefetch_valid) begin
                    tx_tdata <= prefetch_data;
                    tx_tlast <= prefetch_last;
                    tx_tvalid <= 1'b1;
                    prefetch_valid <= 1'b0;
                end else begin
                    tx_tvalid <= 1'b0;
                    tx_tlast <= 1'b0;
                end
            end
            2'b10: begin
                if (!tx_tvalid) begin
                    tx_tdata <= fifo_rd_data[255:0];
                    tx_tlast <= fifo_rd_data[256];
                    tx_tvalid <= 1'b1;
                end else begin
                    prefetch_data <= fifo_rd_data[255:0];
                    prefetch_last <= fifo_rd_data[256];
                    prefetch_valid <= 1'b1;
                end
            end
            2'b11: begin
                if (prefetch_valid) begin
                    tx_tdata <= prefetch_data;
                    tx_tlast <= prefetch_last;
                    prefetch_data <= fifo_rd_data[255:0];
                    prefetch_last <= fifo_rd_data[256];
                    prefetch_valid <= 1'b1;
                end else begin
                    tx_tdata <= fifo_rd_data[255:0];
                    tx_tlast <= fifo_rd_data[256];
                    prefetch_valid <= 1'b0;
                end
                tx_tvalid <= 1'b1;
            end
            default: begin
            end
        endcase
    end
end

endmodule
