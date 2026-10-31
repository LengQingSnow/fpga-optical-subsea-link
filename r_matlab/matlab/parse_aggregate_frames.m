function [frames, segments] = parse_aggregate_frames(rx_bytes, cfg)
%PARSE_AGGREGATE_FRAMES Lock to 512-byte frames and decode segment records.

rx_bytes = uint8(rx_bytes(:));
sync_positions = strfind(double(rx_bytes(:).'), double(cfg.syncWord(:).'));
if isempty(sync_positions)
    error('parse_aggregate_frames:NoSync', ...
        'No aggregate sync word exists in the recovered byte stream.');
end

residues = mod(sync_positions - 1, cfg.frameBytes);
counts = accumarray(residues(:) + 1, 1, [cfg.frameBytes, 1]);
[~, best_residue_index] = max(counts);
best_residue = best_residue_index - 1;
locked_candidates = sync_positions(residues == best_residue);
frame_start = locked_candidates(1);
while frame_start - cfg.frameBytes >= 1
    frame_start = frame_start - cfg.frameBytes;
end
frame_count = floor((numel(rx_bytes) - frame_start + 1) / cfg.frameBytes);
if frame_count < 1
    error('parse_aggregate_frames:NoCompleteFrame', ...
        'No complete 512-byte aggregate frame was captured.');
end

frames.startByte = zeros(frame_count, 1);
frames.sequence = zeros(frame_count, 1, 'uint32');
frames.flags = zeros(frame_count, 1, 'uint8');
frames.segmentBytes = zeros(frame_count, 1, 'uint16');
frames.syncBitErrors = zeros(frame_count, 1, 'uint8');
frames.headerOk = false(frame_count, 1);
frames.crcOk = false(frame_count, 1);
frames.segmentParseOk = false(frame_count, 1);
frames.bytes = zeros(cfg.frameBytes, frame_count, 'uint8');

estimated_segments = max(16, frame_count * 2);
segments.portId = zeros(estimated_segments, 1, 'uint8');
segments.packetId = zeros(estimated_segments, 1, 'uint8');
segments.sop = false(estimated_segments, 1);
segments.eop = false(estimated_segments, 1);
segments.frameIndex = zeros(estimated_segments, 1, 'uint32');
segments.frameCrcOk = false(estimated_segments, 1);
segments.recordStart = zeros(estimated_segments, 1, 'uint16');
segments.payloadLength = zeros(estimated_segments, 1, 'uint16');
segments.payload = cell(estimated_segments, 1);
segment_count = 0;

for frame_index = 1:frame_count
    start_at = frame_start + (frame_index - 1) * cfg.frameBytes;
    frame = rx_bytes(start_at:start_at + cfg.frameBytes - 1);
    frames.bytes(:, frame_index) = frame;
    frames.startByte(frame_index) = start_at;
    frames.syncBitErrors(frame_index) = uint8(bit_error_count( ...
        frame(1:8), cfg.syncWord));
    frames.flags(frame_index) = frame(10);
    frames.segmentBytes(frame_index) = uint16(frame(11)) * 256 + ...
        uint16(frame(12));
    frames.sequence(frame_index) = read_be_u32(frame(13:16));
    frames.headerOk(frame_index) = ...
        frames.syncBitErrors(frame_index) <= cfg.maxSyncBitErrors && ...
        frame(9) == cfg.protocolVersion && ...
        (frame(10) == uint8(6) || frame(10) == uint8(7)) && ...
        frames.segmentBytes(frame_index) <= 492;

    expected_crc = crc32_msb(frame(1:cfg.framePayloadEnd));
    received_crc = read_be_u32(frame(cfg.framePayloadEnd + 1:cfg.frameBytes));
    frames.crcOk(frame_index) = expected_crc == received_crc;

    data_flag_distance = bit_error_count(frame(10), uint8(7));
    can_parse_data = frames.segmentBytes(frame_index) > 0 && ...
        frames.segmentBytes(frame_index) <= 492 && data_flag_distance <= 1;
    if ~can_parse_data
        frames.segmentParseOk(frame_index) = frames.headerOk(frame_index) && ...
            frame(10) == uint8(6) && frames.segmentBytes(frame_index) == 0;
        continue;
    end

    segment_limit = 16 + double(frames.segmentBytes(frame_index));
    position = 17;
    parse_ok = true;
    while position <= segment_limit
        if position + 3 > segment_limit
            parse_ok = false;
            break;
        end
        tag = frame(position);
        payload_length = double(uint16(frame(position + 2)) * 256 + ...
            uint16(frame(position + 3)));
        if bitand(tag, uint8(240)) ~= 0 || ...
                position + 3 + payload_length > segment_limit
            parse_ok = false;
            break;
        end

        segment_count = segment_count + 1;
        if segment_count > numel(segments.payload)
            segments = grow_segments(segments);
        end
        segments.portId(segment_count) = bitand(tag, uint8(3)) + 1;
        segments.packetId(segment_count) = frame(position + 1);
        segments.sop(segment_count) = bitand(tag, uint8(4)) ~= 0;
        segments.eop(segment_count) = bitand(tag, uint8(8)) ~= 0;
        segments.frameIndex(segment_count) = uint32(frame_index);
        segments.frameCrcOk(segment_count) = frames.crcOk(frame_index);
        segments.recordStart(segment_count) = uint16(position);
        segments.payloadLength(segment_count) = uint16(payload_length);
        segments.payload{segment_count} = frame( ...
            position + 4:position + 3 + payload_length);
        position = position + 4 + payload_length;
    end
    frames.segmentParseOk(frame_index) = parse_ok && position == segment_limit + 1;
end

segments.portId = segments.portId(1:segment_count);
segments.packetId = segments.packetId(1:segment_count);
segments.sop = segments.sop(1:segment_count);
segments.eop = segments.eop(1:segment_count);
segments.frameIndex = segments.frameIndex(1:segment_count);
segments.frameCrcOk = segments.frameCrcOk(1:segment_count);
segments.recordStart = segments.recordStart(1:segment_count);
segments.payloadLength = segments.payloadLength(1:segment_count);
segments.payload = segments.payload(1:segment_count);

frames.lockedStartByte = frame_start;
frames.lockedResidue = best_residue;
frames.exactSyncCount = numel(locked_candidates);
frames.frameCount = frame_count;
end

function segments = grow_segments(segments)
old_count = numel(segments.payload);
new_count = max(16, old_count * 2);
segments.portId(new_count, 1) = uint8(0);
segments.packetId(new_count, 1) = uint8(0);
segments.sop(new_count, 1) = false;
segments.eop(new_count, 1) = false;
segments.frameIndex(new_count, 1) = uint32(0);
segments.frameCrcOk(new_count, 1) = false;
segments.recordStart(new_count, 1) = uint16(0);
segments.payloadLength(new_count, 1) = uint16(0);
segments.payload{new_count, 1} = [];
end

function count = bit_error_count(actual, expected)
difference = bitxor(uint8(actual(:)), uint8(expected(:)));
count = 0;
for bit_index = 1:8
    count = count + sum(bitget(difference, bit_index));
end
end

function value = read_be_u32(bytes)
bytes = uint32(bytes(:));
value = bitshift(bytes(1), 24) + bitshift(bytes(2), 16) + ...
    bitshift(bytes(3), 8) + bytes(4);
end
