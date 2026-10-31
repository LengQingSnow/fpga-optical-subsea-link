`timescale 1ns / 1ps

module camera_udp_packet_source #(
    parameter integer FIFO_DEPTH_PIXELS = 8192,
    parameter integer FRAME_BYTES = 614400,
    parameter integer MAX_PACKET_BYTES = 1368
) (
    input  wire        rst_n,

    input  wire        camera1_pclk,
    input  wire        camera1_vsync,
    input  wire [15:0] camera1_pixel,
    input  wire        camera1_pixel_valid,

    input  wire        camera2_pclk,
    input  wire        camera2_vsync,
    input  wire [15:0] camera2_pixel,
    input  wire        camera2_pixel_valid,

    input  wire        tx_clk,
    input  wire        tx_rst_n,

    output reg         packet_meta_valid,
    input  wire        packet_meta_ready,
    output wire [7:0]  packet_type,
    output reg  [7:0]  packet_flags,
    output reg  [31:0] packet_cycle,
    output reg  [15:0] packet_object_id,
    output reg  [15:0] packet_valid_length,
    output reg  [31:0] packet_sequence,
    output reg  [31:0] packet_object_offset,
    output wire [31:0] packet_object_length,
    output wire [31:0] packet_object_crc32,

    output wire        packet_data_valid,
    input  wire        packet_data_ready,
    output wire [7:0]  packet_data,
    output wire        packet_data_last,

    output wire [31:0] camera1_fifo_overflows,
    output wire [31:0] camera2_fifo_overflows,
    output reg  [31:0] camera1_resyncs,
    output reg  [31:0] camera2_resyncs,
    output reg  [31:0] packets_issued
);

localparam [1:0] STATE_SELECT = 2'd0;
localparam [1:0] STATE_META = 2'd1;
localparam [1:0] STATE_DATA = 2'd2;
localparam [15:0] LAST_PACKET_INDEX =
    (FRAME_BYTES - 1) / MAX_PACKET_BYTES;
localparam [15:0] LAST_PACKET_BYTES =
    FRAME_BYTES - (LAST_PACKET_INDEX * MAX_PACKET_BYTES);
localparam [15:0] MAX_PACKET_BYTES_16 = MAX_PACKET_BYTES;

wire [16:0] fifo1_data;
wire [16:0] fifo2_data;
wire fifo1_empty;
wire fifo2_empty;
wire [13:0] fifo1_count;
wire [13:0] fifo2_count;
reg fifo1_read;
reg fifo2_read;

reg [1:0] state;
reg selected_camera;
reg next_camera;
reg pixel_wait;
reg [15:0] data_count;
reg [31:0] camera1_offset;
reg [31:0] camera2_offset;
reg [31:0] camera1_current_cycle;
reg [31:0] camera2_current_cycle;
reg [31:0] camera1_next_cycle;
reg [31:0] camera2_next_cycle;
reg [15:0] camera1_packet_index;
reg [15:0] camera2_packet_index;
reg camera1_discarding;
reg camera2_discarding;

wire [15:0] camera1_next_length;
wire [15:0] camera2_next_length;
wire [13:0] camera1_pixels_needed;
wire [13:0] camera2_pixels_needed;
wire camera1_last_packet;
wire camera2_last_packet;
wire camera1_boundary_ok;
wire camera2_boundary_ok;
wire camera1_ready;
wire camera2_ready;
wire [16:0] selected_fifo_data;

assign packet_type = 8'd3;
assign packet_object_length = FRAME_BYTES;
assign packet_object_crc32 = 32'd0;

assign camera1_last_packet =
    (camera1_packet_index == LAST_PACKET_INDEX);
assign camera2_last_packet =
    (camera2_packet_index == LAST_PACKET_INDEX);
assign camera1_next_length =
    camera1_last_packet ? LAST_PACKET_BYTES : MAX_PACKET_BYTES_16;
assign camera2_next_length =
    camera2_last_packet ? LAST_PACKET_BYTES : MAX_PACKET_BYTES_16;
assign camera1_pixels_needed = (camera1_next_length + 1'b1) >> 1;
assign camera2_pixels_needed = (camera2_next_length + 1'b1) >> 1;

assign camera1_boundary_ok =
    (camera1_packet_index == 0) ?
    (!fifo1_empty && fifo1_data[16]) :
    (!fifo1_empty && !fifo1_data[16]);
assign camera2_boundary_ok =
    (camera2_packet_index == 0) ?
    (!fifo2_empty && fifo2_data[16]) :
    (!fifo2_empty && !fifo2_data[16]);
assign camera1_ready = camera1_boundary_ok &&
                       (fifo1_count >= camera1_pixels_needed);
assign camera2_ready = camera2_boundary_ok &&
                       (fifo2_count >= camera2_pixels_needed);

assign selected_fifo_data = selected_camera ? fifo2_data : fifo1_data;
assign packet_data_valid = (state == STATE_DATA) && !pixel_wait;
assign packet_data = data_count[0] ?
                     selected_fifo_data[7:0] :
                     selected_fifo_data[15:8];
assign packet_data_last = packet_data_valid &&
                          ((data_count + 1'b1) == packet_valid_length);

camera_pixel_async_fifo #(
    .DEPTH(FIFO_DEPTH_PIXELS)
) u_camera1_fifo (
    .rst_n(rst_n),
    .wr_clk(camera1_pclk),
    .vsync(camera1_vsync),
    .pixel(camera1_pixel),
    .pixel_valid(camera1_pixel_valid),
    .rd_clk(tx_clk),
    .rd_rst_n(tx_rst_n),
    .rd_en(fifo1_read),
    .rd_data(fifo1_data),
    .rd_empty(fifo1_empty),
    .rd_count(fifo1_count),
    .overflow_count(camera1_fifo_overflows)
);

camera_pixel_async_fifo #(
    .DEPTH(FIFO_DEPTH_PIXELS)
) u_camera2_fifo (
    .rst_n(rst_n),
    .wr_clk(camera2_pclk),
    .vsync(camera2_vsync),
    .pixel(camera2_pixel),
    .pixel_valid(camera2_pixel_valid),
    .rd_clk(tx_clk),
    .rd_rst_n(tx_rst_n),
    .rd_en(fifo2_read),
    .rd_data(fifo2_data),
    .rd_empty(fifo2_empty),
    .rd_count(fifo2_count),
    .overflow_count(camera2_fifo_overflows)
);

always @(posedge tx_clk or negedge tx_rst_n) begin
    if (!tx_rst_n) begin
        state <= STATE_SELECT;
        selected_camera <= 1'b0;
        next_camera <= 1'b0;
        pixel_wait <= 1'b0;
        packet_meta_valid <= 1'b0;
        packet_flags <= 8'd0;
        packet_cycle <= 32'd0;
        packet_object_id <= 16'd0;
        packet_valid_length <= 16'd0;
        packet_sequence <= 32'd0;
        packet_object_offset <= 32'd0;
        data_count <= 16'd0;
        fifo1_read <= 1'b0;
        fifo2_read <= 1'b0;
        camera1_offset <= 32'd0;
        camera2_offset <= 32'd0;
        camera1_current_cycle <= 32'd0;
        camera2_current_cycle <= 32'd0;
        camera1_next_cycle <= 32'd0;
        camera2_next_cycle <= 32'd0;
        camera1_packet_index <= 16'd0;
        camera2_packet_index <= 16'd0;
        camera1_discarding <= 1'b0;
        camera2_discarding <= 1'b0;
        camera1_resyncs <= 32'd0;
        camera2_resyncs <= 32'd0;
        packets_issued <= 32'd0;
    end else begin
        fifo1_read <= 1'b0;
        fifo2_read <= 1'b0;
        if (pixel_wait)
            pixel_wait <= 1'b0;

        case (state)
            STATE_SELECT: begin
                packet_meta_valid <= 1'b0;
                if ((camera1_packet_index == 0) && !fifo1_empty &&
                    !fifo1_data[16]) begin
                    fifo1_read <= 1'b1;
                    if (!camera1_discarding) begin
                        camera1_discarding <= 1'b1;
                        camera1_resyncs <= camera1_resyncs + 1'b1;
                    end
                end else if ((camera1_packet_index == 0) &&
                             !fifo1_empty && fifo1_data[16]) begin
                    camera1_discarding <= 1'b0;
                end

                if ((camera2_packet_index == 0) && !fifo2_empty &&
                    !fifo2_data[16]) begin
                    fifo2_read <= 1'b1;
                    if (!camera2_discarding) begin
                        camera2_discarding <= 1'b1;
                        camera2_resyncs <= camera2_resyncs + 1'b1;
                    end
                end else if ((camera2_packet_index == 0) &&
                             !fifo2_empty && fifo2_data[16]) begin
                    camera2_discarding <= 1'b0;
                end

                if ((!next_camera && camera1_ready) ||
                    (next_camera && !camera2_ready && camera1_ready)) begin
                    selected_camera <= 1'b0;
                    packet_flags <= {
                        6'd0,
                        camera1_last_packet,
                        camera1_packet_index == 0
                    };
                    packet_cycle <= (camera1_packet_index == 0) ?
                                    camera1_next_cycle :
                                    camera1_current_cycle;
                    packet_object_id <= 16'd1;
                    packet_valid_length <= camera1_next_length;
                    packet_object_offset <= camera1_offset;
                    if (camera1_packet_index == 0) begin
                        camera1_current_cycle <= camera1_next_cycle;
                        camera1_next_cycle <= camera1_next_cycle + 1'b1;
                    end
                    packet_meta_valid <= 1'b1;
                    state <= STATE_META;
                end else if ((next_camera && camera2_ready) ||
                             (!next_camera && !camera1_ready &&
                              camera2_ready)) begin
                    selected_camera <= 1'b1;
                    packet_flags <= {
                        6'd0,
                        camera2_last_packet,
                        camera2_packet_index == 0
                    };
                    packet_cycle <= (camera2_packet_index == 0) ?
                                    camera2_next_cycle :
                                    camera2_current_cycle;
                    packet_object_id <= 16'd2;
                    packet_valid_length <= camera2_next_length;
                    packet_object_offset <= camera2_offset;
                    if (camera2_packet_index == 0) begin
                        camera2_current_cycle <= camera2_next_cycle;
                        camera2_next_cycle <= camera2_next_cycle + 1'b1;
                    end
                    packet_meta_valid <= 1'b1;
                    state <= STATE_META;
                end else begin
                    if ((camera1_offset != 0) && !fifo1_empty &&
                        fifo1_data[16]) begin
                        camera1_offset <= 32'd0;
                        camera1_packet_index <= 16'd0;
                        camera1_discarding <= 1'b0;
                        camera1_resyncs <= camera1_resyncs + 1'b1;
                    end
                    if ((camera2_offset != 0) && !fifo2_empty &&
                        fifo2_data[16]) begin
                        camera2_offset <= 32'd0;
                        camera2_packet_index <= 16'd0;
                        camera2_discarding <= 1'b0;
                        camera2_resyncs <= camera2_resyncs + 1'b1;
                    end
                end
            end

            STATE_META: begin
                if (packet_meta_valid && packet_meta_ready) begin
                    packet_meta_valid <= 1'b0;
                    data_count <= 16'd0;
                    state <= STATE_DATA;
                end
            end

            STATE_DATA: begin
                if (packet_data_valid && packet_data_ready) begin
                    if (data_count[0]) begin
                        if (selected_camera)
                            fifo2_read <= 1'b1;
                        else
                            fifo1_read <= 1'b1;
                        if (!packet_data_last)
                            pixel_wait <= 1'b1;
                    end

                    if (packet_data_last) begin
                        packets_issued <= packets_issued + 1'b1;
                        packet_sequence <= packet_sequence + 1'b1;
                        next_camera <= ~selected_camera;
                        if (selected_camera) begin
                            if (packet_flags[1]) begin
                                camera2_offset <= 32'd0;
                                camera2_packet_index <= 16'd0;
                            end else begin
                                camera2_offset <= camera2_offset +
                                                  packet_valid_length;
                                camera2_packet_index <=
                                    camera2_packet_index + 1'b1;
                            end
                        end else begin
                            if (packet_flags[1]) begin
                                camera1_offset <= 32'd0;
                                camera1_packet_index <= 16'd0;
                            end else begin
                                camera1_offset <= camera1_offset +
                                                  packet_valid_length;
                                camera1_packet_index <=
                                    camera1_packet_index + 1'b1;
                            end
                        end
                        state <= STATE_SELECT;
                    end else begin
                        data_count <= data_count + 1'b1;
                    end
                end
            end

            default: state <= STATE_SELECT;
        endcase
    end
end

endmodule

module camera_pixel_async_fifo #(
    parameter integer DEPTH = 8192
) (
    input  wire        rst_n,
    input  wire        wr_clk,
    input  wire        vsync,
    input  wire [15:0] pixel,
    input  wire        pixel_valid,
    input  wire        rd_clk,
    input  wire        rd_rst_n,
    input  wire        rd_en,
    output wire [16:0] rd_data,
    output wire        rd_empty,
    output wire [13:0] rd_count,
    output reg  [31:0] overflow_count
);

reg vsync_d;
reg frame_start_pending;
wire fifo_full;
wire fifo_wr_reset_busy;
wire fifo_write;
wire [13:0] fifo_rd_count;

assign fifo_write = pixel_valid && !fifo_full && !fifo_wr_reset_busy;
assign rd_count = fifo_rd_count;

always @(posedge wr_clk or negedge rst_n) begin
    if (!rst_n) begin
        vsync_d <= 1'b0;
        frame_start_pending <= 1'b1;
        overflow_count <= 32'd0;
    end else begin
        vsync_d <= vsync;
        if (vsync && !vsync_d)
            frame_start_pending <= 1'b1;
        if (fifo_write)
            frame_start_pending <= 1'b0;
        if (pixel_valid && fifo_full && !fifo_wr_reset_busy)
            overflow_count <= overflow_count + 1'b1;
    end
end

xpm_fifo_async #(
    .CDC_SYNC_STAGES(2),
    .DOUT_RESET_VALUE("0"),
    .ECC_MODE("no_ecc"),
    .FIFO_MEMORY_TYPE("block"),
    .FIFO_READ_LATENCY(0),
    .FIFO_WRITE_DEPTH(DEPTH),
    .FULL_RESET_VALUE(0),
    .PROG_EMPTY_THRESH(10),
    .PROG_FULL_THRESH(DEPTH - 16),
    .RD_DATA_COUNT_WIDTH(14),
    .READ_DATA_WIDTH(17),
    .READ_MODE("fwft"),
    .RELATED_CLOCKS(0),
    .SIM_ASSERT_CHK(0),
    .USE_ADV_FEATURES("0404"),
    .WAKEUP_TIME(0),
    .WRITE_DATA_WIDTH(17),
    .WR_DATA_COUNT_WIDTH(14)
) u_fifo (
    .almost_empty(),
    .almost_full(),
    .data_valid(),
    .dbiterr(),
    .din({frame_start_pending, pixel}),
    .dout(rd_data),
    .empty(rd_empty),
    .full(fifo_full),
    .injectdbiterr(1'b0),
    .injectsbiterr(1'b0),
    .overflow(),
    .prog_empty(),
    .prog_full(),
    .rd_data_count(fifo_rd_count),
    .rd_en(rd_en),
    .rd_rst_busy(),
    .rst(!rst_n || !rd_rst_n),
    .sbiterr(),
    .sleep(1'b0),
    .underflow(),
    .wr_ack(),
    .wr_data_count(),
    .wr_en(fifo_write),
    .wr_rst_busy(fifo_wr_reset_busy),
    .wr_clk(wr_clk),
    .rd_clk(rd_clk)
);

endmodule
