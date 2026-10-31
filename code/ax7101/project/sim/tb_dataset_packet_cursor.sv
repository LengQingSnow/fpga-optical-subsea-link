`timescale 1ns / 1ps

module tb_dataset_packet_cursor;

    localparam [31:0] IMAGE_LENGTH    = 32'd230400;
    localparam [31:0] WAVEFORM_LENGTH = 32'd28800;
    localparam [31:0] IMAGE_CRC_BASE  = 32'hA100_0000;
    localparam [31:0] WAVEFORM_CRC    = 32'hB200_0001;

    reg clk;
    reg rst_n;

    reg image_ready;
    reg image_advance;
    wire image_valid;
    wire [7:0] image_type;
    wire [7:0] image_source_port;
    wire [7:0] image_flags;
    wire [31:0] image_cycle;
    wire [15:0] image_object_id;
    wire [15:0] image_valid_bytes;
    wire [31:0] image_packet_sequence;
    wire [31:0] image_object_offset;
    wire [31:0] image_object_length;
    wire [31:0] image_object_crc32;
    wire [31:0] image_descriptor_crc32;

    reg waveform_ready;
    reg waveform_advance;
    wire waveform_valid;
    wire [7:0] waveform_type;
    wire [7:0] waveform_source_port;
    wire [7:0] waveform_flags;
    wire [31:0] waveform_cycle;
    wire [15:0] waveform_object_id;
    wire [15:0] waveform_valid_bytes;
    wire [31:0] waveform_packet_sequence;
    wire [31:0] waveform_object_offset;
    wire [31:0] waveform_object_length;
    wire [31:0] waveform_object_crc32;

    integer checks;
    integer image_packet;
    integer image_id;
    integer waveform_packet;
    reg [31:0] expected_offset;
    reg [31:0] expected_sequence;
    reg [15:0] expected_valid_bytes;
    reg [7:0] expected_flags;

    assign image_descriptor_crc32 = IMAGE_CRC_BASE + image_object_id;

    dataset_packet_cursor #(
        .DATASET_TYPE(8'd1),
        .SOURCE_PORT(8'd1),
        .FIRST_OBJECT_ID(16'd1),
        .LAST_OBJECT_ID(16'd45),
        .MAX_DATA_BYTES(16'd1368)
    ) image_cursor (
        .clk(clk),
        .rst_n(rst_n),
        .descriptor_ready(image_ready),
        .packet_advance(image_advance),
        .descriptor_object_length(IMAGE_LENGTH),
        .descriptor_object_crc32(image_descriptor_crc32),
        .metadata_valid(image_valid),
        .dataset_type(image_type),
        .source_port(image_source_port),
        .flags(image_flags),
        .dataset_cycle(image_cycle),
        .object_id(image_object_id),
        .valid_data_bytes(image_valid_bytes),
        .packet_sequence(image_packet_sequence),
        .object_offset(image_object_offset),
        .object_total_length(image_object_length),
        .object_crc32(image_object_crc32)
    );

    dataset_packet_cursor #(
        .DATASET_TYPE(8'd2),
        .SOURCE_PORT(8'd2),
        .FIRST_OBJECT_ID(16'd1),
        .LAST_OBJECT_ID(16'd1),
        .MAX_DATA_BYTES(16'd1368)
    ) waveform_cursor (
        .clk(clk),
        .rst_n(rst_n),
        .descriptor_ready(waveform_ready),
        .packet_advance(waveform_advance),
        .descriptor_object_length(WAVEFORM_LENGTH),
        .descriptor_object_crc32(WAVEFORM_CRC),
        .metadata_valid(waveform_valid),
        .dataset_type(waveform_type),
        .source_port(waveform_source_port),
        .flags(waveform_flags),
        .dataset_cycle(waveform_cycle),
        .object_id(waveform_object_id),
        .valid_data_bytes(waveform_valid_bytes),
        .packet_sequence(waveform_packet_sequence),
        .object_offset(waveform_object_offset),
        .object_total_length(waveform_object_length),
        .object_crc32(waveform_object_crc32)
    );

    always #4 clk = ~clk;

    task check;
        input condition;
        input [8*96-1:0] message;
        begin
            checks = checks + 1;
            if (!condition) begin
                $display("FAIL: %0s at time %0t", message, $time);
                $fatal(1);
            end
        end
    endtask

    task advance_image;
        begin
            @(negedge clk);
            image_advance = 1'b1;
            @(negedge clk);
            image_advance = 1'b0;
        end
    endtask

    task advance_waveform;
        begin
            @(negedge clk);
            waveform_advance = 1'b1;
            @(negedge clk);
            waveform_advance = 1'b0;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        image_ready = 1'b0;
        image_advance = 1'b0;
        waveform_ready = 1'b0;
        waveform_advance = 1'b0;
        checks = 0;

        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(negedge clk);

        check(!image_valid, "image metadata must be invalid before descriptor ready");
        check(!waveform_valid, "waveform metadata must be invalid before descriptor ready");

        image_advance = 1'b1;
        waveform_advance = 1'b1;
        repeat (2) @(negedge clk);
        image_advance = 1'b0;
        waveform_advance = 1'b0;
        check(image_object_id == 16'd1 && image_object_offset == 0,
              "image cursor must freeze while descriptor is not ready");
        check(waveform_object_id == 16'd1 && waveform_object_offset == 0,
              "waveform cursor must freeze while descriptor is not ready");

        image_ready = 1'b1;
        waveform_ready = 1'b1;
        #1;
        check(image_valid, "image metadata must become valid");
        check(image_type == 8'd1 && image_source_port == 8'd1,
              "image type and source port");
        check(image_flags == 8'b0000_0001, "first image packet must assert SOP only");
        check(image_cycle == 0 && image_object_id == 1,
              "first image cycle and object id");
        check(image_valid_bytes == 16'd1368, "full image segment length");
        check(image_packet_sequence == 0 && image_object_offset == 0,
              "first image sequence and offset");
        check(image_object_length == IMAGE_LENGTH, "image object length");
        check(image_object_crc32 == IMAGE_CRC_BASE + 1, "image object CRC");

        expected_offset = 0;
        expected_sequence = 0;
        for (image_id = 1; image_id <= 45; image_id = image_id + 1) begin
            for (image_packet = 0; image_packet < 169; image_packet = image_packet + 1) begin
                expected_offset = image_packet * 1368;
                expected_sequence = ((image_id - 1) * 169) + image_packet;
                expected_valid_bytes = (image_packet == 168) ? 16'd576 : 16'd1368;
                expected_flags = 8'd0;
                if (image_packet == 0)
                    expected_flags = expected_flags | 8'b0000_0001;
                if (image_packet == 168)
                    expected_flags = expected_flags | 8'b0000_0010;

                check(image_valid, "image metadata valid during complete cycle");
                check(image_cycle == 0, "image cycle remains zero through image 45");
                check(image_object_id == image_id, "image object id progression");
                check(image_packet_sequence == expected_sequence,
                      "image packet sequence progression");
                check(image_object_offset == expected_offset, "image byte offset progression");
                check(image_valid_bytes == expected_valid_bytes,
                      "image final segment must be 576 bytes");
                check(image_flags == expected_flags, "image SOP/EOP flags");
                check(image_object_crc32 == IMAGE_CRC_BASE + image_id,
                      "image CRC follows current descriptor entry");

                advance_image();
            end
        end

        check(image_cycle == 1, "image cycle increments after image 45");
        check(image_object_id == 1, "image 45 wraps to image 1");
        check(image_object_offset == 0, "wrapped image starts at offset zero");
        check(image_packet_sequence == 32'd7605,
              "image packet sequence remains monotonic across cycle wrap");
        check(image_flags == 8'b0000_0001, "wrapped image packet asserts SOP");

        check(waveform_valid, "waveform metadata valid");
        check(waveform_type == 8'd2 && waveform_source_port == 8'd2,
              "waveform type and source port");
        for (waveform_packet = 0; waveform_packet < 22; waveform_packet = waveform_packet + 1) begin
            expected_offset = waveform_packet * 1368;
            expected_valid_bytes = (waveform_packet == 21) ? 16'd72 : 16'd1368;
            expected_flags = 8'd0;
            if (waveform_packet == 0)
                expected_flags = expected_flags | 8'b0000_0001;
            if (waveform_packet == 21)
                expected_flags = expected_flags | 8'b0000_0010;

            check(waveform_cycle == 0, "waveform cycle before wrap");
            check(waveform_object_id == 1, "waveform object id is always one");
            check(waveform_packet_sequence == waveform_packet,
                  "waveform packet sequence progression");
            check(waveform_object_offset == expected_offset,
                  "waveform byte offset progression");
            check(waveform_valid_bytes == expected_valid_bytes,
                  "waveform final segment must be 72 bytes");
            check(waveform_flags == expected_flags, "waveform SOP/EOP flags");
            check(waveform_object_length == WAVEFORM_LENGTH, "waveform object length");
            check(waveform_object_crc32 == WAVEFORM_CRC, "waveform object CRC");

            advance_waveform();
        end

        check(waveform_cycle == 1, "waveform cycle increments on object wrap");
        check(waveform_object_id == 1 && waveform_object_offset == 0,
              "waveform restarts object one at offset zero");
        check(waveform_packet_sequence == 22,
              "waveform packet sequence remains monotonic across wrap");
        check(waveform_flags == 8'b0000_0001,
              "wrapped waveform packet asserts SOP only");

        $display("PASS tb_dataset_packet_cursor (%0d checks)", checks);
        $finish;
    end

endmodule
