function [frames, segments] = parse_aggregate_frames_relocked(rx_bytes, cfg)
%PARSE_AGGREGATE_FRAMES_RELOCKED Parse frames after a byte-boundary slip.
%
% Continuous sample-clock recovery can expose real byte-boundary movement in
% a long capture. Each exact sync word is therefore used as its own frame
% anchor instead of forcing one residue for the complete byte stream.

rx_bytes = uint8(rx_bytes(:));
sync_positions = strfind(double(rx_bytes(:).'), double(cfg.syncWord(:).'));
if isempty(sync_positions)
    error('parse_aggregate_frames_relocked:NoSync', ...
        'No aggregate sync word exists in the recovered byte stream.');
end

candidate_positions = zeros(numel(sync_positions), 1);
candidate_count = 0;
last_position = -inf;
for index = 1:numel(sync_positions)
    position = sync_positions(index);
    if position <= last_position + 32 || ...
            position + cfg.frameBytes - 1 > numel(rx_bytes)
        continue;
    end
    candidate_count = candidate_count + 1;
    candidate_positions(candidate_count) = position;
    last_position = position;
end
candidate_positions = candidate_positions(1:candidate_count);
if isempty(candidate_positions)
    error('parse_aggregate_frames_relocked:NoCompleteFrame', ...
        'No complete sync-anchored frame exists in the byte stream.');
end

frame_count = numel(candidate_positions);
frames.startByte = candidate_positions;
frames.sequence = zeros(frame_count, 1, 'uint32');
frames.flags = zeros(frame_count, 1, 'uint8');
frames.segmentBytes = zeros(frame_count, 1, 'uint16');
frames.syncBitErrors = zeros(frame_count, 1, 'uint8');
frames.headerOk = false(frame_count, 1);
frames.crcOk = false(frame_count, 1);
frames.segmentParseOk = false(frame_count, 1);
frames.bytes = zeros(cfg.frameBytes, frame_count, 'uint8');

segments.portId = zeros(max(16, frame_count * 2), 1, 'uint8');
segments.packetId = zeros(max(16, frame_count * 2), 1, 'uint8');
segments.sop = false(max(16, frame_count * 2), 1);
segments.eop = false(max(16, frame_count * 2), 1);
segments.frameIndex = zeros(max(16, frame_count * 2), 1, 'uint32');
segments.frameCrcOk = false(max(16, frame_count * 2), 1);
segments.recordStart = zeros(max(16, frame_count * 2), 1, 'uint16');
segments.payloadLength = zeros(max(16, frame_count * 2), 1, 'uint16');
segments.payload = cell(max(16, frame_count * 2), 1);
segment_count = 0;

for frame_index = 1:frame_count
    start_at = candidate_positions(frame_index);
    frame = rx_bytes(start_at:start_at + cfg.frameBytes - 1);
    frames.bytes(:, frame_index) = frame;
    frames.syncBitErrors(frame_index) = uint8(bit_error_count_local( ...
        frame(1:8), cfg.syncWord));
    frames.flags(frame_index) = frame(10);
    frames.segmentBytes(frame_index) = uint16(frame(11)) * 256 + ...
        uint16(frame(12));
    frames.sequence(frame_index) = read_be_u32_local(frame(13:16));
    frames.headerOk(frame_index) = ...
        frames.syncBitErrors(frame_index) <= cfg.maxSyncBitErrors && ...
        frame(9) == cfg.protocolVersion && ...
        (frame(10) == uint8(6) || frame(10) == uint8(7)) && ...
        frames.segmentBytes(frame_index) <= 492;
    frames.crcOk(frame_index) = crc32_msb(frame(1:cfg.framePayloadEnd)) == ...
        read_be_u32_local(frame(cfg.framePayloadEnd + 1:cfg.frameBytes));

    if frames.segmentBytes(frame_index) == 0 || ...
            frames.segmentBytes(frame_index) > 492 || ...
            bit_error_count_local(frame(10), uint8(7)) > 1
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
            segments = grow_relocked_segments(segments);
        end
        segments.portId(segment_count) = bitand(tag, uint8(3)) + 1;
        segments.packetId(segment_count) = frame(position + 1);
        segments.sop(segment_count) = bitand(tag, uint8(4)) ~= 0;
        segments.eop(segment_count) = bitand(tag, uint8(8)) ~= 0;
        segments.frameIndex(segment_count) = uint32(frame_index);
        segments.frameCrcOk(segment_count) = frames.crcOk(frame_index);
        segments.recordStart(segment_count) = uint16(position);
        segments.payloadLength(segment_count) = uint16(payload_length);
        segments.payload{segment_count} = frame(position + 4: ...
            position + 3 + payload_length);
        position = position + 4 + payload_length;
    end
    frames.segmentParseOk(frame_index) = parse_ok && ...
        position == segment_limit + 1;
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

frames.lockedStartByte = candidate_positions(1);
frames.lockedResidue = -1;
frames.exactSyncCount = numel(sync_positions);
frames.frameCount = frame_count;
end

function segments = grow_relocked_segments(segments)
old_count = numel(segments.payload);
new_count = max(old_count * 2, old_count + 16);
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

function count = bit_error_count_local(actual, expected)
actual = uint8(actual(:));
expected = uint8(expected(:));
count = 0;
for index = 1:min(numel(actual), numel(expected))
    count = count + sum(bitget(bitxor(actual(index), expected(index)), 1:8));
end
count = count + 8 * abs(numel(actual) - numel(expected));
end

function value = read_be_u32_local(bytes)
bytes = uint32(bytes(:));
value = bitor(bitshift(bytes(1), 24), bitor(bitshift(bytes(2), 16), ...
    bitor(bitshift(bytes(3), 8), bytes(4))));
end
