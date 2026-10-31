`timescale 1ns/1ps

module dataset_control_axi_slave (
    input  wire          clk,
    input  wire          rst_n,

    input  wire [31:0]   s_axi_awaddr,
    input  wire          s_axi_awvalid,
    output wire          s_axi_awready,
    input  wire [63:0]   s_axi_wdata,
    input  wire [7:0]    s_axi_wstrb,
    input  wire          s_axi_wvalid,
    output wire          s_axi_wready,
    output wire [1:0]    s_axi_bresp,
    output reg           s_axi_bvalid,
    input  wire          s_axi_bready,

    input  wire [31:0]   s_axi_araddr,
    input  wire          s_axi_arvalid,
    output wire          s_axi_arready,
    output reg  [63:0]   s_axi_rdata,
    output wire [1:0]    s_axi_rresp,
    output reg           s_axi_rvalid,
    input  wire          s_axi_rready,

    output wire          image_ready,
    output wire          waveform_ready,
    output wire [1439:0] image_crc_table,
    output wire [31:0]   waveform_crc32,
    output wire [31:0]   descriptor_version
);

reg [7:0] control_memory [0:255];
reg [31:0] pending_awaddr;
reg [63:0] pending_wdata;
reg [7:0] pending_wstrb;
reg aw_pending;
reg w_pending;
integer i;

wire write_commit;
wire [7:0] write_base;
wire [7:0] read_base;

assign s_axi_awready = !aw_pending && !s_axi_bvalid;
assign s_axi_wready = !w_pending && !s_axi_bvalid;
assign s_axi_bresp = 2'b00;
assign s_axi_arready = !s_axi_rvalid;
assign s_axi_rresp = 2'b00;

assign write_commit = aw_pending && w_pending && !s_axi_bvalid;
assign write_base = {pending_awaddr[7:3], 3'b000};
assign read_base = {s_axi_araddr[7:3], 3'b000};

assign descriptor_version = {
    control_memory[7], control_memory[6],
    control_memory[5], control_memory[4]
};
assign image_ready = control_memory[28];
assign waveform_ready = control_memory[28][1];
assign waveform_crc32 = {
    control_memory[215], control_memory[214],
    control_memory[213], control_memory[212]
};

genvar crc_index;
generate
    for (crc_index = 0; crc_index < 45; crc_index = crc_index + 1) begin
        assign image_crc_table[crc_index*32 +: 32] = {
            control_memory[32 + crc_index*4 + 3],
            control_memory[32 + crc_index*4 + 2],
            control_memory[32 + crc_index*4 + 1],
            control_memory[32 + crc_index*4]
        };
    end
endgenerate

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pending_awaddr <= 32'd0;
        pending_wdata <= 64'd0;
        pending_wstrb <= 8'd0;
        aw_pending <= 1'b0;
        w_pending <= 1'b0;
        s_axi_bvalid <= 1'b0;
        s_axi_rdata <= 64'd0;
        s_axi_rvalid <= 1'b0;
        for (i = 0; i < 256; i = i + 1)
            control_memory[i] <= 8'd0;
    end else begin
        if (s_axi_awvalid && s_axi_awready) begin
            pending_awaddr <= s_axi_awaddr;
            aw_pending <= 1'b1;
        end

        if (s_axi_wvalid && s_axi_wready) begin
            pending_wdata <= s_axi_wdata;
            pending_wstrb <= s_axi_wstrb;
            w_pending <= 1'b1;
        end

        if (write_commit) begin
            for (i = 0; i < 8; i = i + 1) begin
                if (pending_wstrb[i])
                    control_memory[write_base + i] <=
                        pending_wdata[i*8 +: 8];
            end
            aw_pending <= 1'b0;
            w_pending <= 1'b0;
            s_axi_bvalid <= 1'b1;
        end else if (s_axi_bvalid && s_axi_bready) begin
            s_axi_bvalid <= 1'b0;
        end

        if (s_axi_arvalid && s_axi_arready) begin
            s_axi_rdata <= {
                control_memory[read_base + 7],
                control_memory[read_base + 6],
                control_memory[read_base + 5],
                control_memory[read_base + 4],
                control_memory[read_base + 3],
                control_memory[read_base + 2],
                control_memory[read_base + 1],
                control_memory[read_base]
            };
            s_axi_rvalid <= 1'b1;
        end else if (s_axi_rvalid && s_axi_rready) begin
            s_axi_rvalid <= 1'b0;
        end
    end
end

endmodule
