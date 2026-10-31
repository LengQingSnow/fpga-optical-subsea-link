`timescale 1ns/1ps

module axi_dataset_read_scheduler #(
    parameter integer AXI_ADDR_WIDTH = 32,
    parameter integer AXI_DATA_WIDTH = 128,
    parameter integer BURST_BEATS = 16,
    parameter [AXI_ADDR_WIDTH-1:0] IMAGE_BASE = 32'h0010_0000,
    parameter integer IMAGE_BYTES = 172_800,
    parameter [AXI_ADDR_WIDTH-1:0] WAVEFORM_BASE = 32'h0200_0000,
    parameter integer WAVEFORM_BYTES = 22_400
) (
    input  wire                      clk,
    input  wire                      rst_n,
    input  wire                      enable_image,
    input  wire                      enable_waveform,
    input  wire                      image_fifo_almost_full,
    input  wire                      waveform_fifo_almost_full,

    output reg  [AXI_ADDR_WIDTH-1:0] m_axi_araddr,
    output reg  [7:0]                m_axi_arlen,
    output wire [2:0]                m_axi_arsize,
    output wire [1:0]                m_axi_arburst,
    output reg                       m_axi_arvalid,
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
    output reg                       image_wrap_pulse,
    output reg                       waveform_wrap_pulse,
    output reg  [31:0]               read_error_count
);

localparam integer BEAT_BYTES = AXI_DATA_WIDTH / 8;
localparam integer ADDR_LSB = $clog2(BEAT_BYTES);
localparam integer IMAGE_BEATS = IMAGE_BYTES / BEAT_BYTES;
localparam integer WAVEFORM_BEATS = WAVEFORM_BYTES / BEAT_BYTES;
localparam [1:0] STATE_IDLE = 2'd0;
localparam [1:0] STATE_PREP = 2'd1;
localparam [1:0] STATE_ADDR = 2'd2;
localparam [1:0] STATE_DATA = 2'd3;

reg [1:0] state;
reg active_port;
reg last_grant;
reg [AXI_ADDR_WIDTH-1:0] image_address;
reg [AXI_ADDR_WIDTH-1:0] waveform_address;
reg [31:0] image_beats_remaining;
reg [31:0] waveform_beats_remaining;
reg [31:0] pending_beats_remaining;
reg [12:0] pending_boundary_beats;
reg [8:0] active_beats;
reg [8:0] received_beats;

wire [8:0] remaining_burst_cap;
wire [8:0] boundary_burst_cap;
wire [8:0] prepared_beats;

assign m_axi_arsize = ADDR_LSB[2:0];
assign m_axi_arburst = 2'b01;
// FIFO headroom is checked before issuing an address.  Once the address is
// accepted, drain the complete AXI burst even if prog_full asserts meanwhile;
// pausing an outstanding burst can otherwise block both dataset streams.
assign m_axi_rready = (state == STATE_DATA);

assign image_fifo_wdata = m_axi_rdata;
assign waveform_fifo_wdata = m_axi_rdata;
assign image_fifo_wen = m_axi_rvalid && m_axi_rready && !active_port;
assign waveform_fifo_wen = m_axi_rvalid && m_axi_rready && active_port;

assign remaining_burst_cap =
    (pending_beats_remaining > BURST_BEATS)
        ? BURST_BEATS[8:0]
        : pending_beats_remaining[8:0];
assign boundary_burst_cap =
    (pending_boundary_beats > BURST_BEATS)
        ? BURST_BEATS[8:0]
        : pending_boundary_beats[8:0];
assign prepared_beats =
    (remaining_burst_cap < boundary_burst_cap)
        ? remaining_burst_cap
        : boundary_burst_cap;

function [12:0] beats_before_4k;
    input [AXI_ADDR_WIDTH-1:0] address;
    begin
        beats_before_4k =
            (13'd4096 - {1'b0, address[11:0]}) >> ADDR_LSB;
    end
endfunction

task select_burst;
    input select_waveform;
    begin
        active_port <= select_waveform;
        if (select_waveform) begin
            m_axi_araddr <= waveform_address;
            pending_beats_remaining <= waveform_beats_remaining;
            pending_boundary_beats <=
                beats_before_4k(waveform_address);
        end else begin
            m_axi_araddr <= image_address;
            pending_beats_remaining <= image_beats_remaining;
            pending_boundary_beats <= beats_before_4k(image_address);
        end
        state <= STATE_PREP;
    end
endtask

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= STATE_IDLE;
        active_port <= 1'b0;
        last_grant <= 1'b1;
        image_address <= IMAGE_BASE;
        waveform_address <= WAVEFORM_BASE;
        image_beats_remaining <= IMAGE_BEATS;
        waveform_beats_remaining <= WAVEFORM_BEATS;
        pending_beats_remaining <= 32'd0;
        pending_boundary_beats <= 13'd0;
        active_beats <= 9'd0;
        received_beats <= 9'd0;
        m_axi_araddr <= {AXI_ADDR_WIDTH{1'b0}};
        m_axi_arlen <= 8'd0;
        m_axi_arvalid <= 1'b0;
        image_wrap_pulse <= 1'b0;
        waveform_wrap_pulse <= 1'b0;
        read_error_count <= 32'd0;
    end else begin
        image_wrap_pulse <= 1'b0;
        waveform_wrap_pulse <= 1'b0;

        case (state)
            STATE_IDLE: begin
                m_axi_arvalid <= 1'b0;
                received_beats <= 9'd0;
                if (enable_image && !image_fifo_almost_full &&
                    enable_waveform && !waveform_fifo_almost_full) begin
                    select_burst(!last_grant);
                end else if (enable_image && !image_fifo_almost_full) begin
                    select_burst(1'b0);
                end else if (enable_waveform &&
                             !waveform_fifo_almost_full) begin
                    select_burst(1'b1);
                end
            end

            STATE_PREP: begin
                if (prepared_beats == 9'd0) begin
                    m_axi_arlen <= 8'd0;
                    active_beats <= 9'd1;
                end else begin
                    m_axi_arlen <= prepared_beats[7:0] - 1'b1;
                    active_beats <= prepared_beats;
                end
                m_axi_arvalid <= 1'b1;
                state <= STATE_ADDR;
            end

            STATE_ADDR: begin
                if (m_axi_arvalid && m_axi_arready) begin
                    m_axi_arvalid <= 1'b0;
                    received_beats <= 9'd0;
                    state <= STATE_DATA;
                end
            end

            STATE_DATA: begin
                if (m_axi_rvalid && m_axi_rready) begin
                    if (m_axi_rresp != 2'b00)
                        read_error_count <= read_error_count + 1'b1;
                    received_beats <= received_beats + 1'b1;

                    if (m_axi_rlast ||
                        (received_beats + 1'b1 == active_beats)) begin
                        if (active_port) begin
                            if (waveform_beats_remaining <=
                                active_beats) begin
                                waveform_address <= WAVEFORM_BASE;
                                waveform_beats_remaining <=
                                    WAVEFORM_BEATS;
                                waveform_wrap_pulse <= 1'b1;
                            end else begin
                                waveform_address <= waveform_address +
                                                    (active_beats *
                                                     BEAT_BYTES);
                                waveform_beats_remaining <=
                                    waveform_beats_remaining -
                                    active_beats;
                            end
                        end else begin
                            if (image_beats_remaining <= active_beats) begin
                                image_address <= IMAGE_BASE;
                                image_beats_remaining <= IMAGE_BEATS;
                                image_wrap_pulse <= 1'b1;
                            end else begin
                                image_address <= image_address +
                                                 (active_beats * BEAT_BYTES);
                                image_beats_remaining <=
                                    image_beats_remaining - active_beats;
                            end
                        end
                        last_grant <= active_port;
                        state <= STATE_IDLE;
                    end
                end
            end

            default: state <= STATE_IDLE;
        endcase
    end
end

endmodule
