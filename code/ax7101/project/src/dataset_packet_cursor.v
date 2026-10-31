`timescale 1ns / 1ps

module dataset_packet_cursor #(
    parameter [7:0] DATASET_TYPE = 8'd1,
    parameter [7:0] SOURCE_PORT = 8'd1,
    parameter [15:0] FIRST_OBJECT_ID = 16'd1,
    parameter [15:0] LAST_OBJECT_ID = 16'd45,
    parameter [15:0] MAX_DATA_BYTES = 16'd1368
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        descriptor_ready,
    input  wire        packet_advance,
    input  wire [31:0] descriptor_object_length,
    input  wire [31:0] descriptor_object_crc32,

    output wire        metadata_valid,
    output wire [7:0]  dataset_type,
    output wire [7:0]  source_port,
    output wire [7:0]  flags,
    output reg  [31:0] dataset_cycle,
    output reg  [15:0] object_id,
    output wire [15:0] valid_data_bytes,
    output reg  [31:0] packet_sequence,
    output reg  [31:0] object_offset,
    output wire [31:0] object_total_length,
    output wire [31:0] object_crc32
);

    wire [31:0] remaining_bytes;
    wire        start_of_object;
    wire        end_of_object;

    assign dataset_type = DATASET_TYPE;
    assign source_port = SOURCE_PORT;
    assign object_total_length = descriptor_object_length;
    assign object_crc32 = descriptor_object_crc32;

    assign remaining_bytes =
        (descriptor_object_length > object_offset) ?
        (descriptor_object_length - object_offset) : 32'd0;

    assign metadata_valid =
        descriptor_ready &&
        (descriptor_object_length != 0) &&
        (remaining_bytes != 0);

    assign start_of_object = metadata_valid && (object_offset == 0);
    assign end_of_object =
        metadata_valid && (remaining_bytes <= {16'd0, MAX_DATA_BYTES});

    assign flags = metadata_valid ?
                   {6'd0, end_of_object, start_of_object} : 8'd0;

    assign valid_data_bytes =
        !metadata_valid ? 16'd0 :
        (remaining_bytes > {16'd0, MAX_DATA_BYTES}) ?
        MAX_DATA_BYTES : remaining_bytes[15:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dataset_cycle <= 32'd0;
            object_id <= FIRST_OBJECT_ID;
            packet_sequence <= 32'd0;
            object_offset <= 32'd0;
        end else if (packet_advance && metadata_valid) begin
            packet_sequence <= packet_sequence + 1'b1;

            if (end_of_object) begin
                object_offset <= 32'd0;
                if (object_id == LAST_OBJECT_ID) begin
                    object_id <= FIRST_OBJECT_ID;
                    dataset_cycle <= dataset_cycle + 1'b1;
                end else begin
                    object_id <= object_id + 1'b1;
                end
            end else begin
                object_offset <= object_offset + MAX_DATA_BYTES;
            end
        end
    end

endmodule
