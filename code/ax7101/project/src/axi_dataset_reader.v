`timescale 1ns/1ps

module axi_dataset_reader #(
    parameter integer AXI_ADDR_WIDTH = 32,
    parameter integer AXI_DATA_WIDTH = 64,
    parameter integer BURST_BEATS = 32,
    parameter [AXI_ADDR_WIDTH-1:0] IMAGE_BASE = 32'h0010_0000,
    parameter integer IMAGE_BYTES = 172_800,
    parameter [AXI_ADDR_WIDTH-1:0] WAVEFORM_BASE = 32'h0200_0000,
    parameter integer WAVEFORM_BYTES = 22_400,
    parameter integer POLL_DELAY_CYCLES = 1024
) (
    input  wire                      clk,
    input  wire                      rst_n,
    input  wire                      init_calib_complete,
    input  wire                      image_fifo_almost_full,
    input  wire                      waveform_fifo_almost_full,

    output wire [AXI_ADDR_WIDTH-1:0] m_axi_araddr,
    output wire [7:0]                m_axi_arlen,
    output wire [2:0]                m_axi_arsize,
    output wire [1:0]                m_axi_arburst,
    output wire                      m_axi_arvalid,
    input  wire                      m_axi_arready,
    input  wire [AXI_DATA_WIDTH-1:0] m_axi_rdata,
    input  wire                      m_axi_rvalid,
    input  wire                      m_axi_rlast,
    input  wire [1:0]                m_axi_rresp,
    output wire                      m_axi_rready,

    output wire [AXI_DATA_WIDTH-1:0] image_fifo_wdata,
    output wire                      image_fifo_wen,
    output wire [AXI_DATA_WIDTH-1:0] waveform_fifo_wdata,
    output wire                      waveform_fifo_wen,
    output reg                       image_ready,
    output reg                       waveform_ready,
    output reg  [1439:0]             image_crc_table,
    output reg  [31:0]               waveform_crc32,
    output reg  [31:0]               descriptor_read_count,
    output wire [31:0]               read_error_count
);

localparam [1:0] STATE_WAIT = 2'd0;
localparam [1:0] STATE_DESC_ADDR = 2'd1;
localparam [1:0] STATE_DESC_DATA = 2'd2;
localparam [1:0] STATE_ACTIVE = 2'd3;

reg [1:0] state;
reg [31:0] poll_count;
reg [5:0] descriptor_beat;
reg [31:0] descriptor_magic;
reg [31:0] descriptor_version;
reg [31:0] descriptor_ready_flags;
reg descriptor_response_error;
reg [31:0] descriptor_error_count;

wire [AXI_ADDR_WIDTH-1:0] scheduler_araddr;
wire [7:0] scheduler_arlen;
wire [2:0] scheduler_arsize;
wire [1:0] scheduler_arburst;
wire scheduler_arvalid;
wire scheduler_arready;
wire scheduler_rready;
wire [31:0] scheduler_error_count;
wire descriptor_mode;

assign descriptor_mode = (state != STATE_ACTIVE);
assign m_axi_araddr = descriptor_mode ? {AXI_ADDR_WIDTH{1'b0}}
                                      : scheduler_araddr;
assign m_axi_arlen = descriptor_mode ? 8'd31 : scheduler_arlen;
assign m_axi_arsize = descriptor_mode ? 3'd3 : scheduler_arsize;
assign m_axi_arburst = 2'b01;
assign m_axi_arvalid = (state == STATE_DESC_ADDR) ? 1'b1 :
                       (state == STATE_ACTIVE) ? scheduler_arvalid : 1'b0;
assign m_axi_rready = (state == STATE_DESC_DATA) ? 1'b1 :
                      (state == STATE_ACTIVE) ? scheduler_rready : 1'b0;

assign scheduler_arready = (state == STATE_ACTIVE) && m_axi_arready;
assign read_error_count = descriptor_error_count +
                          scheduler_error_count;

axi_dataset_read_scheduler #(
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .BURST_BEATS(BURST_BEATS),
    .IMAGE_BASE(IMAGE_BASE),
    .IMAGE_BYTES(IMAGE_BYTES),
    .WAVEFORM_BASE(WAVEFORM_BASE),
    .WAVEFORM_BYTES(WAVEFORM_BYTES)
) u_scheduler (
    .clk(clk),
    .rst_n(rst_n),
    .enable_image(image_ready),
    .enable_waveform(waveform_ready),
    .image_fifo_almost_full(image_fifo_almost_full),
    .waveform_fifo_almost_full(waveform_fifo_almost_full),
    .m_axi_araddr(scheduler_araddr),
    .m_axi_arlen(scheduler_arlen),
    .m_axi_arsize(scheduler_arsize),
    .m_axi_arburst(scheduler_arburst),
    .m_axi_arvalid(scheduler_arvalid),
    .m_axi_arready(scheduler_arready),
    .m_axi_rdata(m_axi_rdata),
    .m_axi_rvalid(m_axi_rvalid && (state == STATE_ACTIVE)),
    .m_axi_rlast(m_axi_rlast),
    .m_axi_rresp(m_axi_rresp),
    .m_axi_rready(scheduler_rready),
    .image_fifo_wdata(image_fifo_wdata),
    .image_fifo_wen(image_fifo_wen),
    .waveform_fifo_wdata(waveform_fifo_wdata),
    .waveform_fifo_wen(waveform_fifo_wen),
    .image_wrap_pulse(),
    .waveform_wrap_pulse(),
    .read_error_count(scheduler_error_count)
);

integer table_index;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= STATE_WAIT;
        poll_count <= 32'd0;
        descriptor_beat <= 6'd0;
        descriptor_magic <= 32'd0;
        descriptor_version <= 32'd0;
        descriptor_ready_flags <= 32'd0;
        descriptor_response_error <= 1'b0;
        descriptor_error_count <= 32'd0;
        descriptor_read_count <= 32'd0;
        image_ready <= 1'b0;
        waveform_ready <= 1'b0;
        image_crc_table <= 1440'd0;
        waveform_crc32 <= 32'd0;
    end else begin
        case (state)
            STATE_WAIT: begin
                image_ready <= 1'b0;
                waveform_ready <= 1'b0;
                if (!init_calib_complete) begin
                    poll_count <= 32'd0;
                end else if (poll_count >= POLL_DELAY_CYCLES - 1) begin
                    poll_count <= 32'd0;
                    descriptor_beat <= 6'd0;
                    descriptor_magic <= 32'd0;
                    descriptor_version <= 32'd0;
                    descriptor_ready_flags <= 32'd0;
                    descriptor_response_error <= 1'b0;
                    state <= STATE_DESC_ADDR;
                end else begin
                    poll_count <= poll_count + 1'b1;
                end
            end

            STATE_DESC_ADDR: begin
                if (m_axi_arready)
                    state <= STATE_DESC_DATA;
            end

            STATE_DESC_DATA: begin
                if (m_axi_rvalid) begin
                    if (m_axi_rresp != 2'b00) begin
                        descriptor_response_error <= 1'b1;
                        descriptor_error_count <=
                            descriptor_error_count + 1'b1;
                    end

                    case (descriptor_beat)
                        6'd0: begin
                            descriptor_magic <= m_axi_rdata[31:0];
                            descriptor_version <= m_axi_rdata[63:32];
                        end
                        6'd3:
                            descriptor_ready_flags <= m_axi_rdata[63:32];
                        6'd26: begin
                            image_crc_table[44*32 +: 32] <=
                                m_axi_rdata[31:0];
                            waveform_crc32 <= m_axi_rdata[63:32];
                        end
                        default: begin
                            if ((descriptor_beat >= 6'd4) &&
                                (descriptor_beat <= 6'd25)) begin
                                table_index = (descriptor_beat - 4) * 2;
                                image_crc_table[table_index*32 +: 32] <=
                                    m_axi_rdata[31:0];
                                image_crc_table[(table_index+1)*32 +: 32] <=
                                    m_axi_rdata[63:32];
                            end
                        end
                    endcase

                    if (m_axi_rlast || (descriptor_beat == 6'd31)) begin
                        descriptor_read_count <=
                            descriptor_read_count + 1'b1;
                        if (!descriptor_response_error &&
                            (m_axi_rresp == 2'b00) &&
                            (descriptor_magic == 32'h4444_5841) &&
                            (descriptor_version == 32'd1) &&
                            (descriptor_ready_flags[1:0] == 2'b11)) begin
                            image_ready <= 1'b1;
                            waveform_ready <= 1'b1;
                            state <= STATE_ACTIVE;
                        end else begin
                            state <= STATE_WAIT;
                        end
                    end else begin
                        descriptor_beat <= descriptor_beat + 1'b1;
                    end
                end
            end

            STATE_ACTIVE: begin
                if (!init_calib_complete) begin
                    image_ready <= 1'b0;
                    waveform_ready <= 1'b0;
                    state <= STATE_WAIT;
                end
            end

            default: state <= STATE_WAIT;
        endcase
    end
end

endmodule
