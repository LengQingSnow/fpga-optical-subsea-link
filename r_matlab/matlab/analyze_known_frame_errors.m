function [summary, details] = analyze_known_frame_errors( ...
    frames, segments, references, result_dir, cfg)
%ANALYZE_KNOWN_FRAME_ERRORS Compare bad frames against deterministic bytes.

if ~isfield(frames, 'bytes') || size(frames.bytes, 1) ~= cfg.frameBytes
    error('analyze_known_frame_errors:FrameBytes', ...
        'parse_aggregate_frames must retain the 512-byte frame matrix.');
end
if nargin < 4
    result_dir = '';
end
if ~isempty(result_dir) && exist(result_dir, 'dir') ~= 7
    mkdir(result_dir);
end

frame_count = frames.frameCount;
expected_sequence = infer_frame_sequences(frames);
expected_bytes = zeros(cfg.frameBytes, frame_count, 'uint8');
known_mask = false(cfg.frameBytes, frame_count);
source_port_map = zeros(cfg.frameBytes, frame_count, 'uint8');
frame_resolved_packets = zeros(frame_count, 1, 'uint16');
frame_layout_known = false(frame_count, 1);
frame_idle_reconstructed = false(frame_count, 1);
frame_segment_indices = cell(frame_count, 1);
for segment_index = 1:numel(segments.payload)
    frame_index = double(segments.frameIndex(segment_index));
    frame_segment_indices{frame_index}(end + 1, 1) = segment_index;
end
frame_segment_count = cellfun(@numel, frame_segment_indices);

for frame_index = 1:frame_count
    if frames.crcOk(frame_index)
        expected_bytes(:, frame_index) = frames.bytes(:, frame_index);
        known_mask(:, frame_index) = true;
        frame_layout_known(frame_index) = true;
        continue;
    end

    expected_bytes(1:8, frame_index) = cfg.syncWord(:);
    expected_bytes(9, frame_index) = cfg.protocolVersion;
    expected_bytes(13:16, frame_index) = ...
        write_be_u32(expected_sequence(frame_index));
    known_mask([1:9, 13:16], frame_index) = true;

    idle_frame = build_idle_frame(expected_sequence(frame_index), cfg);
    idle_errors = bit_error_count(frames.bytes(:, frame_index), idle_frame);
    if idle_errors <= floor(cfg.knownFrameMaximumPayloadBer * ...
            cfg.frameBytes * 8)
        expected_bytes(:, frame_index) = idle_frame;
        known_mask(:, frame_index) = true;
        frame_layout_known(frame_index) = true;
        frame_idle_reconstructed(frame_index) = true;
        continue;
    end

    segment_indices = frame_segment_indices{frame_index};
    if frames.segmentParseOk(frame_index) && ...
            validate_frame_layout(segments, segment_indices)
        segment_bytes = sum(4 + double(segments.payloadLength( ...
            segment_indices)));
        expected_bytes(10, frame_index) = uint8(7);
        expected_bytes(11:12, frame_index) = write_be_u16(segment_bytes);
        known_mask(10:12, frame_index) = true;
        filler_start = 17 + segment_bytes;
        if filler_start <= cfg.framePayloadEnd
            filler = aggregate_prbs31_bytes( ...
                expected_sequence(frame_index), cfg.framePayloadEnd - 16);
            expected_bytes(filler_start:cfg.framePayloadEnd, frame_index) = ...
                filler(filler_start - 16:end);
            known_mask(filler_start:cfg.framePayloadEnd, frame_index) = true;
        end
        frame_layout_known(frame_index) = true;
    end
end

all_cfg = cfg;
all_cfg.useBadCrcSegments = true;
[packets, packet_reassembly_stats] = reassemble_udp_packets( ...
    segments, frames, all_cfg);
catalog = build_known_axds_catalog(references);
anchors = find_packet_anchors(packets, catalog);

packet_count = numel(packets.bytes);
packet_resolved = false(packet_count, 1);
packet_sequence = zeros(packet_count, 1, 'uint32');
packet_bit_errors = zeros(packet_count, 1);
packet_compared_bits = zeros(packet_count, 1);
packet_candidate_margin = zeros(packet_count, 1);
packet_touches_bad = false(packet_count, 1);

for packet_index = 1:packet_count
    port = double(packets.portId(packet_index));
    if port < 1 || port > 2
        continue;
    end
    segment_indices = double(packets.segmentIndices{packet_index}(:));
    if isempty(segment_indices)
        continue;
    end
    packet_frames = double(segments.frameIndex(segment_indices));
    packet_touches_bad(packet_index) = any(~frames.crcOk(packet_frames));

    [resolved, sequence, expected_packet, errors, margin] = ...
        resolve_known_packet(packet_index, packets, catalog(port), ...
        anchors(port), cfg);
    if ~resolved || ~validate_packet_fragment_lengths(expected_packet, ...
            segment_indices, segments, frame_segment_count)
        continue;
    end

    packet_resolved(packet_index) = true;
    packet_sequence(packet_index) = sequence;
    packet_bit_errors(packet_index) = errors;
    packet_compared_bits(packet_index) = numel(expected_packet) * 8;
    packet_candidate_margin(packet_index) = margin;

    packet_offset = 1;
    for item_index = 1:numel(segment_indices)
        segment_index = segment_indices(item_index);
        frame_index = double(segments.frameIndex(segment_index));
        payload_length = double(segments.payloadLength(segment_index));
        expected_payload = expected_packet(packet_offset: ...
            packet_offset + payload_length - 1);
        record_start = double(segments.recordStart(segment_index));
        payload_positions = record_start + 4: ...
            record_start + 3 + payload_length;

        if ~frames.crcOk(frame_index)
            is_sop = packet_offset == 1;
            is_eop = packet_offset + payload_length - 1 == ...
                numel(expected_packet);
            expected_tag = uint8(port - 1 + 4 * is_sop + 8 * is_eop);
            expected_bytes(record_start, frame_index) = expected_tag;
            known_mask(record_start, frame_index) = true;
            source_port_map(record_start, frame_index) = uint8(port);

            if anchors(port).valid
                expected_packet_id = mod(double(sequence) + ...
                    anchors(port).packetIdMinusSequence, 256);
                expected_bytes(record_start + 1, frame_index) = ...
                    uint8(expected_packet_id);
                known_mask(record_start + 1, frame_index) = true;
                source_port_map(record_start + 1, frame_index) = uint8(port);
            end

            expected_bytes(record_start + 2:record_start + 3, ...
                frame_index) = write_be_u16(payload_length);
            known_mask(record_start + 2:record_start + 3, frame_index) = true;
            source_port_map(record_start + 2:record_start + 3, ...
                frame_index) = uint8(port);

            expected_bytes(payload_positions, frame_index) = expected_payload;
            known_mask(payload_positions, frame_index) = true;
            source_port_map(payload_positions, frame_index) = uint8(port);
            frame_resolved_packets(frame_index) = ...
                frame_resolved_packets(frame_index) + 1;
        end
        packet_offset = packet_offset + payload_length;
    end
end

for frame_index = 1:frame_count
    if frames.crcOk(frame_index)
        continue;
    end
    if all(known_mask(1:cfg.framePayloadEnd, frame_index))
        expected_crc = crc32_msb(expected_bytes(1:cfg.framePayloadEnd, ...
            frame_index));
        expected_bytes(cfg.framePayloadEnd + 1:cfg.frameBytes, ...
            frame_index) = write_be_u32(expected_crc);
        known_mask(cfg.framePayloadEnd + 1:cfg.frameBytes, frame_index) = true;
    end
end

[frame_compared_bits, frame_bit_errors, frame_lane_errors, ...
    byte_compared_bits, byte_bit_errors, lane_compared_bits, ...
    lane_bit_errors] = summarize_error_maps(frames.bytes, expected_bytes, ...
    known_mask);

crc_good_count = sum(frames.crcOk);
bad_mask = ~frames.crcOk;
fully_reconstructed_bad = bad_mask & ...
    (sum(known_mask, 1).' == cfg.frameBytes);
bad_with_payload = bad_mask & frame_resolved_packets > 0;
ambiguous_bad = bad_mask & ~fully_reconstructed_bad & ...
    frame_resolved_packets == 0;

summary.totalFrames = frame_count;
summary.crcGoodFrames = crc_good_count;
summary.crcBadFrames = sum(bad_mask);
summary.fullyReconstructedBadFrames = sum(fully_reconstructed_bad);
summary.idleReconstructedBadFrames = sum(frame_idle_reconstructed);
summary.badFramesWithKnownPayload = sum(bad_with_payload);
summary.ambiguousBadFrames = sum(ambiguous_bad);
summary.resolvedImagePackets = sum(packet_resolved & packets.portId == 1);
summary.resolvedWaveformPackets = sum(packet_resolved & packets.portId == 2);
summary.unresolvedKnownPackets = sum((packets.portId == 1 | ...
    packets.portId == 2) & ~packet_resolved);
summary.comparedBits = sum(frame_compared_bits);
summary.bitErrors = sum(frame_bit_errors);
summary.ber = safe_ratio(summary.bitErrors, summary.comparedBits);
summary.badFrameComparedBits = sum(frame_compared_bits(bad_mask));
summary.badFrameBitErrors = sum(frame_bit_errors(bad_mask));
summary.badFrameBer = safe_ratio(summary.badFrameBitErrors, ...
    summary.badFrameComparedBits);
summary.comparedCoverage = safe_ratio(summary.comparedBits, ...
    frame_count * cfg.frameBytes * 8);
summary.sequenceAnchorMismatches = count_sequence_anchor_mismatches( ...
    frames, expected_sequence);
summary.packetReassembly = packet_reassembly_stats;

details.expectedSequence = expected_sequence;
details.frameComparedBits = frame_compared_bits;
details.frameBitErrors = frame_bit_errors;
details.frameLaneErrors = frame_lane_errors;
details.frameResolvedPackets = frame_resolved_packets;
details.frameLayoutKnown = frame_layout_known;
details.frameIdleReconstructed = frame_idle_reconstructed;
details.fullyReconstructedBad = fully_reconstructed_bad;
details.packetResolved = packet_resolved;
details.packetSequence = packet_sequence;
details.packetBitErrors = packet_bit_errors;
details.packetComparedBits = packet_compared_bits;
details.packetCandidateMargin = packet_candidate_margin;
details.packetTouchesBad = packet_touches_bad;
details.byteComparedBits = byte_compared_bits;
details.byteBitErrors = byte_bit_errors;
details.laneComparedBits = lane_compared_bits;
details.laneBitErrors = lane_bit_errors;

if ~isempty(result_dir)
    write_known_frame_outputs(result_dir, summary, details, frames, ...
        packets, source_port_map, expected_bytes, known_mask);
end
end

function expected_sequence = infer_frame_sequences(frames)
good = frames.crcOk;
if ~any(good)
    good = frames.headerOk;
end
if ~any(good)
    error('analyze_known_frame_errors:SequenceAnchor', ...
        'No CRC-good or structurally valid frame sequence is available.');
end
modulus = 2 ^ 32;
expected_sequence = zeros(frames.frameCount, 1, 'uint32');
expected_sequence(good) = frames.sequence(good);

bad = ~good;
run_starts = find(bad & [true; ~bad(1:end - 1)]);
run_ends = find(bad & [~bad(2:end); true]);
for run_index = 1:numel(run_starts)
    first = run_starts(run_index);
    last = run_ends(run_index);
    indices = (first:last)';
    previous = first - 1;
    following = last + 1;
    has_previous = previous >= 1 && good(previous);
    has_following = following <= frames.frameCount && good(following);

    if has_previous
        previous_candidate = uint32(mod(double(frames.sequence(previous)) + ...
            double(indices - previous), modulus));
    else
        previous_candidate = zeros(numel(indices), 1, 'uint32');
    end
    if has_following
        following_candidate = uint32(mod(double(frames.sequence(following)) - ...
            double(following - indices), modulus));
    else
        following_candidate = zeros(numel(indices), 1, 'uint32');
    end

    if has_previous && has_following
        if isequal(previous_candidate, following_candidate)
            expected_sequence(indices) = previous_candidate;
        else
            previous_cost = sequence_candidate_cost( ...
                frames.bytes(13:16, indices), previous_candidate);
            following_cost = sequence_candidate_cost( ...
                frames.bytes(13:16, indices), following_candidate);
            prefix_cost = [0; cumsum(previous_cost)];
            suffix_cost = [flipud(cumsum(flipud(following_cost))); 0];
            [~, split_index] = min(prefix_cost + suffix_cost);
            split_count = split_index - 1;
            if split_count > 0
                expected_sequence(indices(1:split_count)) = ...
                    previous_candidate(1:split_count);
            end
            if split_count < numel(indices)
                expected_sequence(indices(split_count + 1:end)) = ...
                    following_candidate(split_count + 1:end);
            end
        end
    elseif has_previous
        expected_sequence(indices) = previous_candidate;
    else
        expected_sequence(indices) = following_candidate;
    end
end
end

function costs = sequence_candidate_cost(actual_bytes, candidates)
costs = zeros(numel(candidates), 1);
for item_index = 1:numel(candidates)
    costs(item_index) = bit_error_count(actual_bytes(:, item_index), ...
        write_be_u32(candidates(item_index)));
end
end

function count = count_sequence_anchor_mismatches(frames, expected_sequence)
anchors = find(frames.crcOk);
count = sum(frames.sequence(anchors) ~= expected_sequence(anchors));
end

function frame = build_idle_frame(sequence, cfg)
frame = zeros(cfg.frameBytes, 1, 'uint8');
frame(1:8) = cfg.syncWord(:);
frame(9) = cfg.protocolVersion;
frame(10) = uint8(6);
frame(11:12) = uint8(0);
frame(13:16) = write_be_u32(sequence);
frame(17:cfg.framePayloadEnd) = aggregate_prbs31_bytes( ...
    sequence, cfg.framePayloadEnd - 16);
frame(cfg.framePayloadEnd + 1:cfg.frameBytes) = write_be_u32( ...
    crc32_msb(frame(1:cfg.framePayloadEnd)));
end

function valid = validate_frame_layout(segments, indices)
if isempty(indices) || numel(indices) > 4
    valid = false;
    return;
end
ports = double(segments.portId(indices));
if numel(unique(ports)) ~= numel(ports)
    valid = false;
    return;
end
quota_table = [488, 242, 160, 119];
quota = quota_table(numel(indices));
expected_start = 17;
for item_index = 1:numel(indices)
    index = indices(item_index);
    length_value = double(segments.payloadLength(index));
    if double(segments.recordStart(index)) ~= expected_start || ...
            length_value < 1 || length_value > quota || ...
            (~segments.eop(index) && length_value ~= quota)
        valid = false;
        return;
    end
    expected_start = expected_start + 4 + length_value;
end
cyclic_distance = mod(diff(ports), 4);
valid = all(cyclic_distance > 0) && sum(cyclic_distance) <= 3 && ...
    expected_start <= 509;
end

function valid = validate_packet_fragment_lengths(expected_packet, ...
    indices, segments, frame_segment_count)
quota_table = [488, 242, 160, 119];
packet_offset = 1;
valid = true;
for item_index = 1:numel(indices)
    segment_index = indices(item_index);
    frame_index = segments.frameIndex(segment_index);
    segment_count = frame_segment_count(double(frame_index));
    if segment_count < 1 || segment_count > 4
        valid = false;
        return;
    end
    quota = quota_table(segment_count);
    expected_length = min(quota, numel(expected_packet) - packet_offset + 1);
    actual_length = double(segments.payloadLength(segment_index));
    if expected_length ~= actual_length
        valid = false;
        return;
    end
    packet_offset = packet_offset + actual_length;
end
valid = valid && packet_offset == numel(expected_packet) + 1;
end

function anchors = find_packet_anchors(packets, catalog)
anchors = repmat(struct('valid', false, 'frame', [], 'packetId', [], ...
    'sequence', [], 'packetIdMinusSequence', 0), 2, 1);
for port = 1:2
    packet_indices = find(packets.portId == port & packets.allFramesCrcOk);
    frames_value = [];
    packet_ids = [];
    sequences = [];
    for item_index = 1:numel(packet_indices)
        packet_index = packet_indices(item_index);
        received = uint8(packets.bytes{packet_index}(:));
        if ~valid_axds_identity(received, port)
            continue;
        end
        sequence = read_be_u32(received(17:20));
        expected = build_expected_axds_packet(catalog(port), sequence);
        if numel(expected) ~= numel(received) || any(expected ~= received)
            continue;
        end
        frames_value(end + 1, 1) = double(packets.firstFrame(packet_index));
        packet_ids(end + 1, 1) = double(packets.packetId(packet_index));
        sequences(end + 1, 1) = double(sequence);
    end
    if isempty(sequences)
        continue;
    end
    [frames_value, order] = sort(frames_value);
    packet_ids = packet_ids(order);
    sequences = sequences(order);
    offsets = mod(packet_ids - mod(sequences, 256), 256);
    anchors(port).valid = true;
    anchors(port).frame = frames_value;
    anchors(port).packetId = packet_ids;
    anchors(port).sequence = sequences;
    anchors(port).packetIdMinusSequence = mode(offsets);
end
end

function valid = valid_axds_identity(bytes, port)
valid = numel(bytes) >= 32 && ...
    isequal(bytes(1:4), uint8([hex2dec('41'); hex2dec('58'); ...
        hex2dec('44'); hex2dec('53')])) && ...
    bytes(5) == 1 && bytes(6) == port && bytes(7) == port;
end

function [resolved, sequence, expected, best_errors, margin] = ...
    resolve_known_packet(packet_index, packets, catalog_entry, anchor, cfg)
received = uint8(packets.bytes{packet_index}(:));
candidates = packet_sequence_candidates(packet_index, packets, anchor);
best_errors = inf;
second_errors = inf;
sequence = uint32(0);
expected = zeros(0, 1, 'uint8');
for candidate_index = 1:numel(candidates)
    trial_sequence = uint32(candidates(candidate_index));
    trial_expected = build_expected_axds_packet( ...
        catalog_entry, trial_sequence);
    if numel(trial_expected) ~= numel(received)
        continue;
    end
    errors = bit_error_count(received, trial_expected);
    if errors < best_errors
        second_errors = best_errors;
        best_errors = errors;
        sequence = trial_sequence;
        expected = trial_expected;
    elseif errors < second_errors
        second_errors = errors;
    end
end

if isinf(best_errors)
    resolved = false;
    margin = 0;
    return;
end
if isinf(second_errors)
    margin = inf;
else
    margin = second_errors - best_errors;
end
ber = best_errors / (numel(received) * 8);
resolved = ber <= cfg.knownFrameMaximumPayloadBer && ...
    (isinf(margin) || margin >= ...
        cfg.knownFrameMinimumCandidateMarginBits || best_errors == 0);
end

function candidates = packet_sequence_candidates(packet_index, packets, anchor)
received = uint8(packets.bytes{packet_index}(:));
packet_id = double(packets.packetId(packet_index));
frame_value = double(packets.firstFrame(packet_index));
candidates = zeros(0, 1);
if numel(received) >= 20
    candidates(end + 1, 1) = double(read_be_u32(received(17:20)));
end
if ~anchor.valid
    candidates = unique(candidates);
    return;
end

previous = find(anchor.frame <= frame_value, 1, 'last');
following = find(anchor.frame >= frame_value, 1, 'first');
anchor_indices = unique([previous; following]);
for item_index = 1:numel(anchor_indices)
    anchor_index = anchor_indices(item_index);
    if isempty(anchor_index)
        continue;
    end
    anchor_sequence = anchor.sequence(anchor_index);
    anchor_packet_id = anchor.packetId(anchor_index);
    if frame_value >= anchor.frame(anchor_index)
        delta = mod(packet_id - anchor_packet_id, 256);
        base = anchor_sequence + delta;
        for wrap = 0:2
            candidates(end + 1, 1) = base + 256 * wrap;
        end
    else
        delta = mod(anchor_packet_id - packet_id, 256);
        base = anchor_sequence - delta;
        for wrap = 0:2
            candidate = base - 256 * wrap;
            if candidate >= 0
                candidates(end + 1, 1) = candidate;
            end
        end
    end
end

if numel(received) >= 20
    direct = double(read_be_u32(received(17:20)));
    target_low = mod(packet_id - anchor.packetIdMinusSequence, 256);
    direct_low = mod(direct, 256);
    correction = mod(target_low - direct_low + 128, 256) - 128;
    corrected = direct + correction;
    for wrap = -1:1
        candidate = corrected + 256 * wrap;
        if candidate >= 0 && candidate <= 2 ^ 32 - 1
            candidates(end + 1, 1) = candidate;
        end
    end
end
candidates = unique(candidates(candidates >= 0 & ...
    candidates <= 2 ^ 32 - 1));
end

function [frame_compared_bits, frame_bit_errors, frame_lane_errors, ...
    byte_compared_bits, byte_bit_errors, lane_compared_bits, ...
    lane_bit_errors] = summarize_error_maps(actual, expected, known)
frame_count = size(actual, 2);
frame_compared_bits = zeros(frame_count, 1);
frame_bit_errors = zeros(frame_count, 1);
frame_lane_errors = zeros(frame_count, 4);
byte_compared_bits = 8 * sum(known, 2);
byte_bit_errors = zeros(size(actual, 1), 1);
lane_compared_bits = repmat(2 * sum(known(:)), 4, 1);
lane_bit_errors = zeros(4, 1);

difference = bitxor(actual, expected);
difference(~known) = uint8(0);
table = popcount_table();
for frame_index = 1:frame_count
    frame_compared_bits(frame_index) = 8 * sum(known(:, frame_index));
    counts = table(double(difference(:, frame_index)) + 1);
    frame_bit_errors(frame_index) = sum(counts);
    for lane = 1:4
        upper_bit = 9 - lane;
        lower_bit = 5 - lane;
        errors = sum(bitget(difference(:, frame_index), upper_bit)) + ...
            sum(bitget(difference(:, frame_index), lower_bit));
        frame_lane_errors(frame_index, lane) = errors;
        lane_bit_errors(lane) = lane_bit_errors(lane) + errors;
    end
    byte_bit_errors = byte_bit_errors + counts;
end
end

function table = popcount_table()
persistent stored;
if isempty(stored)
    stored = zeros(256, 1);
    for value = 0:255
        count = 0;
        for bit_index = 1:8
            count = count + bitget(uint8(value), bit_index);
        end
        stored(value + 1) = count;
    end
end
table = stored;
end

function count = bit_error_count(actual, expected)
difference = bitxor(uint8(actual(:)), uint8(expected(:)));
table = popcount_table();
count = sum(table(double(difference) + 1));
end

function value = safe_ratio(numerator, denominator)
if denominator == 0
    value = NaN;
else
    value = double(numerator) / double(denominator);
end
end

function write_known_frame_outputs(result_dir, summary, details, frames, ...
    packets, source_port_map, expected_bytes, known_mask)
summary_path = fullfile(result_dir, 'known_frame_ber_summary.csv');
file_id = fopen(summary_path, 'w');
if file_id < 0
    error('analyze_known_frame_errors:SummaryOpen', ...
        'Cannot create %s.', summary_path);
end
cleanup = onCleanup(@() fclose(file_id));
fprintf(file_id, 'metric,value\n');
names = {'totalFrames', 'crcGoodFrames', 'crcBadFrames', ...
    'fullyReconstructedBadFrames', 'idleReconstructedBadFrames', ...
    'badFramesWithKnownPayload', 'ambiguousBadFrames', ...
    'resolvedImagePackets', 'resolvedWaveformPackets', ...
    'unresolvedKnownPackets', 'comparedBits', 'bitErrors', 'ber', ...
    'badFrameComparedBits', 'badFrameBitErrors', 'badFrameBer', ...
    'comparedCoverage', 'sequenceAnchorMismatches'};
for item_index = 1:numel(names)
    fprintf(file_id, '%s,%.15g\n', names{item_index}, ...
        double(summary.(names{item_index})));
end
clear cleanup;

frame_path = fullfile(result_dir, 'known_frame_error_by_frame.csv');
file_id = fopen(frame_path, 'w');
if file_id < 0
    error('analyze_known_frame_errors:FrameOpen', ...
        'Cannot create %s.', frame_path);
end
cleanup = onCleanup(@() fclose(file_id));
fprintf(file_id, ['frame_index,sequence,crc_ok,header_ok,' ...
    'segment_parse_ok,layout_known,idle_reconstructed,' ...
    'fully_reconstructed,resolved_packets,compared_bits,' ...
    'bit_errors,ber,lane1_errors,lane2_errors,lane3_errors,' ...
    'lane4_errors\n']);
for frame_index = 1:frames.frameCount
    compared = details.frameComparedBits(frame_index);
    errors = details.frameBitErrors(frame_index);
    fprintf(file_id, ['%d,%u,%d,%d,%d,%d,%d,%d,%d,%d,%d,' ...
        '%.15g,%d,%d,%d,%d\n'], frame_index, ...
        details.expectedSequence(frame_index), frames.crcOk(frame_index), ...
        frames.headerOk(frame_index), frames.segmentParseOk(frame_index), ...
        details.frameLayoutKnown(frame_index), ...
        details.frameIdleReconstructed(frame_index), ...
        all(known_mask(:, frame_index)), ...
        details.frameResolvedPackets(frame_index), compared, errors, ...
        safe_ratio(errors, compared), ...
        details.frameLaneErrors(frame_index, 1), ...
        details.frameLaneErrors(frame_index, 2), ...
        details.frameLaneErrors(frame_index, 3), ...
        details.frameLaneErrors(frame_index, 4));
end
clear cleanup;

byte_path = fullfile(result_dir, 'known_frame_error_by_byte.csv');
file_id = fopen(byte_path, 'w');
if file_id < 0
    error('analyze_known_frame_errors:ByteOpen', ...
        'Cannot create %s.', byte_path);
end
cleanup = onCleanup(@() fclose(file_id));
fprintf(file_id, 'frame_byte,compared_bits,bit_errors,ber\n');
for byte_index = 1:numel(details.byteComparedBits)
    fprintf(file_id, '%d,%d,%d,%.15g\n', byte_index, ...
        details.byteComparedBits(byte_index), ...
        details.byteBitErrors(byte_index), ...
        safe_ratio(details.byteBitErrors(byte_index), ...
        details.byteComparedBits(byte_index)));
end
clear cleanup;

lane_path = fullfile(result_dir, 'known_frame_error_by_lane.csv');
file_id = fopen(lane_path, 'w');
if file_id < 0
    error('analyze_known_frame_errors:LaneOpen', ...
        'Cannot create %s.', lane_path);
end
cleanup = onCleanup(@() fclose(file_id));
fprintf(file_id, 'lane,compared_bits,bit_errors,ber\n');
for lane = 1:4
    fprintf(file_id, '%d,%d,%d,%.15g\n', lane, ...
        details.laneComparedBits(lane), details.laneBitErrors(lane), ...
        safe_ratio(details.laneBitErrors(lane), ...
        details.laneComparedBits(lane)));
end
clear cleanup;

packet_path = fullfile(result_dir, 'known_packet_comparison.csv');
file_id = fopen(packet_path, 'w');
if file_id < 0
    error('analyze_known_frame_errors:PacketOpen', ...
        'Cannot create %s.', packet_path);
end
cleanup = onCleanup(@() fclose(file_id));
fprintf(file_id, ['packet_index,port,packet_id,sequence,first_frame,' ...
    'last_frame,all_frames_crc_ok,touches_bad,resolved,' ...
    'compared_bits,bit_errors,ber,candidate_margin_bits\n']);
for packet_index = 1:numel(packets.bytes)
    compared = details.packetComparedBits(packet_index);
    errors = details.packetBitErrors(packet_index);
    fprintf(file_id, ['%d,%d,%d,%u,%u,%u,%d,%d,%d,%d,%d,' ...
        '%.15g,%.15g\n'], packet_index, packets.portId(packet_index), ...
        packets.packetId(packet_index), details.packetSequence(packet_index), ...
        packets.firstFrame(packet_index), packets.lastFrame(packet_index), ...
        packets.allFramesCrcOk(packet_index), ...
        details.packetTouchesBad(packet_index), ...
        details.packetResolved(packet_index), compared, errors, ...
        safe_ratio(errors, compared), ...
        details.packetCandidateMargin(packet_index));
end
clear cleanup;

save(fullfile(result_dir, 'known_frame_analysis.mat'), 'summary', ...
    'details', 'expected_bytes', 'known_mask', 'source_port_map', '-v7.3');
write_bit_error_positions(fullfile(result_dir, ...
    'known_bit_error_positions.csv'), frames.bytes, expected_bytes, ...
    known_mask, source_port_map, details.expectedSequence);
end

function write_bit_error_positions(file_path, actual, expected, known, ...
    source_port, expected_sequence)
file_id = fopen(file_path, 'w');
if file_id < 0
    error('analyze_known_frame_errors:PositionOpen', ...
        'Cannot create %s.', file_path);
end
cleanup = onCleanup(@() fclose(file_id));
fprintf(file_id, ['frame_index,sequence,frame_byte,bit_number,' ...
    'lane,source_port,expected_byte,received_byte\n']);
difference = bitxor(actual, expected);
difference(~known) = uint8(0);
for frame_index = 1:size(actual, 2)
    byte_indices = find(difference(:, frame_index) ~= 0);
    for item_index = 1:numel(byte_indices)
        byte_index = byte_indices(item_index);
        for bit_position = 8:-1:1
            if bitget(difference(byte_index, frame_index), bit_position)
                lane = mod(8 - bit_position, 4) + 1;
                fprintf(file_id, '%d,%u,%d,%d,%d,%d,%d,%d\n', ...
                    frame_index, expected_sequence(frame_index), ...
                    byte_index, bit_position - 1, lane, ...
                    source_port(byte_index, frame_index), ...
                    expected(byte_index, frame_index), ...
                    actual(byte_index, frame_index));
            end
        end
    end
end
clear cleanup;
end

function value = read_be_u32(bytes)
bytes = uint32(bytes(:));
value = bitshift(bytes(1), 24) + bitshift(bytes(2), 16) + ...
    bitshift(bytes(3), 8) + bytes(4);
end

function bytes = write_be_u16(value)
value = uint16(value);
bytes = uint8([bitshift(value, -8); bitand(value, uint16(255))]);
end

function bytes = write_be_u32(value)
value = uint32(value);
bytes = uint8([bitshift(value, -24); ...
    bitand(bitshift(value, -16), uint32(255)); ...
    bitand(bitshift(value, -8), uint32(255)); ...
    bitand(value, uint32(255))]);
end
