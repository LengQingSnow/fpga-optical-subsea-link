function [state, result, window_ber] = rf47_lms_content_decode(state, capture, cfg, references)
%RF47_LMS_CONTENT_DECODE Isolated LMS payload stream/object reconstruction.
% Only CRC-valid frames contribute; unknown/missing bytes are never filled from references.

if nargin < 1 || isempty(state)
    state = initial_state();
end
if nargin < 4
    references = [];
end
% Optional page-6-only measurement, BEFORE the cross-capture object merge.
% Existing two-output callers retain the same decoding path and cost.
if nargout > 2
    window_ber = rf47_page6_packet_ber();
end

result = empty_result(state);
cfg.opticalCma = true; % Isolated content page always rejects bad CRC frames.
short_cfg = cfg;
short_cfg.timingScanSymbols = min(double(cfg.timingScanSymbols), 8192);
short_cfg.packingScanSymbols = min(double(cfg.packingScanSymbols), 16384);
short_cfg.resampleChunkPoints = min(double(cfg.resampleChunkPoints), 262144);
if isfield(short_cfg, 'opticalCma') && short_cfg.opticalCma
    short_cfg.packingScanSymbols = min(double(cfg.packingScanSymbols), 131072);
end

% A long optical record can contain a local loss of blind-CMA convergence.
% Decode it in independent 1 Mpoint blocks so one bad interval does not
% discard valid aggregate frames recovered elsewhere in the same capture.
optical_mode = isfield(short_cfg, 'opticalCma') && short_cfg.opticalCma;
optical_block_points = 1000000;
if optical_mode && size(capture.channels, 1) > optical_block_points
    block_count = ceil(size(capture.channels, 1) / optical_block_points);
    successful_blocks = 0;
    last_block_error = '';
    for block_index = 1:block_count
        first_point = (block_index - 1) * optical_block_points + 1;
        last_point = min(size(capture.channels, 1), ...
            first_point + optical_block_points - 1);
        block_capture = capture;
        block_capture.channels = capture.channels(first_point:last_point, :);
        block_capture.pointCount = last_point - first_point + 1;
        if nargout > 2
            [state, block_result, block_ber] = rf47_lms_content_decode( ...
                state, block_capture, short_cfg, references);
            names = fieldnames(window_ber);
            for metric_index = 1:numel(names)
                name = names{metric_index};
                window_ber.(name) = window_ber.(name) + block_ber.(name);
            end
        else
            [state, block_result] = rf47_lms_content_decode( ...
                state, block_capture, short_cfg, references);
        end
        if isempty(block_result.error) && block_result.frameCount > 0
            successful_blocks = successful_blocks + 1;
        elseif ~isempty(block_result.error)
            last_block_error = block_result.error;
        end
    end
    result = build_result(state, references);
    result.laneBits = false(0, 4);
    if successful_blocks == 0
        if isempty(last_block_error)
            last_block_error = 'Optical CMA did not find aggregate sync.';
        end
        state.lastError = last_block_error;
        result.error = last_block_error;
    else
        state.lastError = '';
        result.error = '';
    end
    return;
end

state.captureCount = state.captureCount + 1;
try
    lane_bits = false(0, 4);
    [lane_bits, new_bytes, recovery, packing] = rf47_lms_content_dsp(capture, short_cfg);
    state.lastRecovery = recovery;
    state.lastPacking = packing;
    state.lastDecodedBytes = numel(new_bytes);
catch exception
    state.lastError = exception.message;
    result = build_result(state, references);
    % Physical BER still uses the recovered lane bits when content-frame
    % sync is unavailable during BER replay.
    result.laneBits = lane_bits;
    return;
end

try
    parser_cfg = cfg;
    optical_mode = isfield(short_cfg, 'opticalCma') && ...
        short_cfg.opticalCma;
    parser_cfg.useBadCrcSegments = ~optical_mode;
    [new_frames, new_segments] = parse_aggregate_frames_relocked( ...
        uint8(new_bytes(:)), parser_cfg);
    [new_frames, new_segments] = deduplicate_frames(new_frames, new_segments);
    [state.frames, state.segments] = merge_frame_records( ...
        state.frames, state.segments, new_frames, new_segments);
    [state.frames, state.segments] = trim_frame_records( ...
        state.frames, state.segments, state.maximumFrameRecords);

    [new_packets, ~] = reassemble_udp_packets( ...
        new_segments, new_frames, parser_cfg);
    % ax7101 sends a complete 1400-byte UDP payload, including final padding.
    new_packets = complete_crc_packets(new_packets, new_frames);
    if nargout > 2
        window_ber = rf47_page6_packet_ber( ...
            new_packets, new_frames, references, parser_cfg);
    end
    state.packets = merge_packet_records(state.packets, new_packets);
    state.packets = trim_packet_records( ...
        state.packets, state.maximumPacketRecords);
    if isempty(state.packets)
        state.objects = struct([]);
        state.udpStats = struct('packetCount', 0, 'packetCountByPort', zeros(1, 4));
        state.axdsStats = struct('validPacketCount', 0);
        state.objectStats = struct('objectCount', 0);
        state.lastError = '';
        result = build_result(state, references);
        result.laneBits = lane_bits;
        return;
    end
    [axds, axds_stats] = parse_axds_packets(state.packets, parser_cfg);
    [objects, object_stats] = reassemble_axds_objects(axds);
    state.objects = objects;
    state.udpStats = packet_stats(state.packets);
    state.axdsStats = axds_stats;
    state.objectStats = object_stats;
    state.lastError = '';
catch exception
    state.lastError = exception.message;
end

result = build_result(state, references);
result.laneBits = lane_bits;
end

function state = initial_state()
state = struct();
state.captureCount = 0;
state.maximumFrameRecords = 20000;
state.maximumPacketRecords = 4096;
state.lastDecodedBytes = 0;
state.lastError = '';
state.frames = [];
state.segments = [];
state.packets = [];
state.objects = struct([]);
state.lastRecovery = [];
state.lastPacking = [];
state.udpStats = [];
state.axdsStats = [];
state.objectStats = [];
end

function result = empty_result(state)
result = struct();
result.frameCount = 0;
result.crcGoodFrames = 0;
result.crcBadFrames = 0;
result.badFrameRate = NaN;
result.packetCount = 0;
result.objectCount = 0;
result.image = empty_dataset_result();
result.images = repmat(empty_dataset_result(),1,3);
result.waveform = empty_dataset_result();
result.cameraLeft = empty_camera_result();
result.cameraRight = empty_camera_result();
result.captureCount = state.captureCount;
result.decodedBytes = state.lastDecodedBytes;
result.error = state.lastError;
result.laneBits = false(0, 4);
end

function result = build_result(state, references)
result = empty_result(state);
if isempty(state.frames) || ~isstruct(state.frames)
    return;
end

result.frameCount = state.frames.frameCount;
result.crcGoodFrames = sum(state.frames.crcOk);
result.crcBadFrames = result.frameCount - result.crcGoodFrames;
if isempty(state.packets)
    result.packetCount = 0;
else
    result.packetCount = numel(state.packets.bytes);
end
result.objectCount = numel(state.objects);
if result.frameCount > 0
    result.badFrameRate = result.crcBadFrames / result.frameCount;
end
if isempty(state.objects)
    return;
end

result.image = make_image_result(state.objects, references);
for image_id = 1:3
    candidates = find([state.objects.datasetType] == 1 & ...
        [state.objects.objectId] == image_id);
    if ~isempty(candidates)
        [~, best] = max(object_score(state.objects(candidates)));
        result.images(image_id) = dataset_result( ...
            state.objects(candidates(best)), references, 1);
    end
end
result.waveform = make_waveform_result(state.objects, references);
result.image = attach_frame_stats(result.image, state.frames, ...
    state.segments, 1);
result.waveform = attach_frame_stats(result.waveform, state.frames, ...
    state.segments, 2);
result.error = state.lastError;
end

function output = empty_dataset_result()
output = struct('available', false, 'data', zeros(0, 1, 'uint8'), ...
    'validMask', false(0, 1), 'ber', NaN, 'bitErrors', 0, ...
    'comparedBits', 0, 'coverage', 0, 'objectId', 0, 'cycle', uint32(0), ...
    'frameCount', 0, 'badFrames', 0, 'badFrameRate', NaN);
end

function output = empty_camera_result()
output = struct('available', false, 'image', zeros(480, 640, 3, 'uint8'), ...
    'coverage', 0, 'objectId', 0, 'cycle', uint32(0));
end

function output = make_image_result(objects, references)
output = empty_dataset_result();
candidates = find([objects.datasetType] == 1);
if isempty(candidates)
    return;
end
[~, order] = sort(object_score(objects(candidates)), 'descend');
index = candidates(order(1));
object = objects(index);
output = dataset_result(object, references, 1);
end

function output = make_waveform_result(objects, references)
output = empty_dataset_result();
candidates = find([objects.datasetType] == 2 & [objects.objectId] == 1);
if isempty(candidates)
    return;
end
[~, order] = sort(object_score(objects(candidates)), 'descend');
index = candidates(order(1));
object = objects(index);
output = dataset_result(object, references, 2);
end

function output = dataset_result(object, references, dataset_type)
output = empty_dataset_result();
output.available = true;
output.data = uint8(object.data(:));
output.validMask = logical(object.validMask(:));
output.objectId = double(object.objectId);
output.cycle = uint32(object.datasetCycle);
output.coverage = sum(output.validMask) / max(1, numel(output.validMask));

expected = zeros(0, 1, 'uint8');
if ~isempty(references)
    if dataset_type == 1 && output.objectId >= 1 && ...
            output.objectId <= numel(references.images)
        expected = uint8(references.images{output.objectId}(:));
    elseif dataset_type == 2 && output.objectId == 1
        expected = uint8(references.waveformBytes(:));
    end
end
compared = min(numel(expected), numel(output.data));
mask = output.validMask(1:compared);
if compared > 0 && any(mask)
    difference = bitxor(output.data(1:compared), expected(1:compared));
    output.bitErrors = population_count(difference(mask));
    output.comparedBits = 8 * sum(mask);
    output.ber = output.bitErrors / output.comparedBits;
end
end

function output = make_camera_result(objects, object_id)
output = empty_camera_result();
candidates = find([objects.datasetType] == 3 & ...
    [objects.objectId] == object_id);
if isempty(candidates)
    return;
end
[~, order] = sort(object_score(objects(candidates)), 'descend');
object = objects(candidates(order(1)));
output.available = true;
output.objectId = double(object.objectId);
output.cycle = uint32(object.datasetCycle);
output.coverage = sum(object.validMask) / max(1, numel(object.validMask));
output.image = decode_camera_rgb565(object.data, object.validMask);
end

function output = attach_frame_stats(output, frames, segments, port_id)
selected = false(frames.frameCount, 1);
for segment_index = 1:numel(segments.frameIndex)
    frame_index = double(segments.frameIndex(segment_index));
    if segments.portId(segment_index) == port_id && ...
            frame_index >= 1 && frame_index <= frames.frameCount
        selected(frame_index) = true;
    end
end
output.frameCount = sum(selected);
if output.frameCount > 0
    output.badFrames = sum(~frames.crcOk(selected));
    output.badFrameRate = output.badFrames / output.frameCount;
end
end

function image = decode_camera_rgb565(data, valid_mask)
% ax7101 dual OV5640 stream is VGA RGB565, high byte first.
width = 640;
height = 480;
image = zeros(height, width, 3, 'uint8');
data = uint8(data(:));
valid_mask = logical(valid_mask(:));
count = min(floor(numel(data) / 2), floor(width * height));
if count < 1
    return;
end
high = uint16(data(1:2:2 * count));
low = uint16(data(2:2:2 * count));
words = bitor(bitshift(high, 8), low);
valid = valid_mask(1:2:2 * count) & valid_mask(2:2:2 * count);
red = uint8(round(double(bitshift(words, -11)) * 255 / 31));
green = uint8(round(double(bitand(bitshift(words, -5), 63)) * 255 / 63));
blue = uint8(round(double(bitand(words, 31)) * 255 / 31));
red(~valid) = 0;
green(~valid) = 0;
blue(~valid) = 0;
image(:, :, 1) = reshape(red, [width, height]).';
image(:, :, 2) = reshape(green, [width, height]).';
image(:, :, 3) = reshape(blue, [width, height]).';
end

function score = object_score(objects)
score = zeros(numel(objects), 1);
for index = 1:numel(objects)
    score(index) = sum(objects(index).validMask) + ...
        1e-6 * double(objects(index).datasetCycle);
end
end

function count = population_count(bytes)
count = 0;
for bit_index = 1:8
    count = count + sum(bitget(uint8(bytes), bit_index));
end
end

function [frames, segments] = deduplicate_frames(frames, segments)
if frames.frameCount <= 1
    return;
end

keep = false(frames.frameCount, 1);
sequences = zeros(0, 1, 'uint32');
chosen = zeros(0, 1);
for index = 1:frames.frameCount
    match = find(sequences == frames.sequence(index), 1);
    if isempty(match)
        sequences(end + 1, 1) = frames.sequence(index); %#ok<AGROW>
        chosen(end + 1, 1) = index; %#ok<AGROW>
        keep(index) = true;
    elseif ~frames.crcOk(chosen(match)) && frames.crcOk(index)
        keep(chosen(match)) = false;
        chosen(match) = index;
        keep(index) = true;
    end
end

old_to_new = zeros(frames.frameCount, 1);
old_to_new(keep) = 1:sum(keep);
frame_fields = fieldnames(frames);
for field_index = 1:numel(frame_fields)
    name = frame_fields{field_index};
    value = frames.(name);
    if strcmp(name, 'bytes')
        frames.(name) = value(:, keep);
    elseif numel(value) == frames.frameCount
        frames.(name) = value(keep, :);
    end
end
frames.frameCount = sum(keep);

segment_keep = false(numel(segments.frameIndex), 1);
for index = 1:numel(segments.frameIndex)
    old_index = double(segments.frameIndex(index));
    if old_index >= 1 && old_index <= numel(keep) && keep(old_index)
        segments.frameIndex(index) = uint32(old_to_new(old_index));
        segment_keep(index) = true;
    end
end
segment_fields = fieldnames(segments);
for field_index = 1:numel(segment_fields)
    name = segment_fields{field_index};
    value = segments.(name);
    if strcmp(name, 'payload')
        segments.(name) = value(segment_keep);
    elseif numel(value) == numel(segment_keep)
        segments.(name) = value(segment_keep, :);
    end
end
end

function [frames, segments] = merge_frame_records( ...
    frames, segments, new_frames, new_segments)
if isempty(frames)
    frames = new_frames;
    segments = new_segments;
    return;
end

new_to_old = zeros(new_frames.frameCount, 1);
for index = 1:new_frames.frameCount
    match = find(frames.sequence == new_frames.sequence(index), 1);
    if isempty(match)
        frames.startByte(end + 1, 1) = new_frames.startByte(index);
        frames.sequence(end + 1, 1) = new_frames.sequence(index);
        frames.flags(end + 1, 1) = new_frames.flags(index);
        frames.segmentBytes(end + 1, 1) = new_frames.segmentBytes(index);
        frames.syncBitErrors(end + 1, 1) = new_frames.syncBitErrors(index);
        frames.headerOk(end + 1, 1) = new_frames.headerOk(index);
        frames.crcOk(end + 1, 1) = new_frames.crcOk(index);
        frames.segmentParseOk(end + 1, 1) = new_frames.segmentParseOk(index);
        frames.bytes(:, end + 1) = new_frames.bytes(:, index);
        frames.frameCount = frames.frameCount + 1;
        new_to_old(index) = frames.frameCount;
    else
        new_to_old(index) = match;
        if ~frames.crcOk(match) && new_frames.crcOk(index)
            frames.startByte(match) = new_frames.startByte(index);
            frames.flags(match) = new_frames.flags(index);
            frames.segmentBytes(match) = new_frames.segmentBytes(index);
            frames.syncBitErrors(match) = new_frames.syncBitErrors(index);
            frames.headerOk(match) = new_frames.headerOk(index);
            frames.crcOk(match) = true;
            frames.segmentParseOk(match) = new_frames.segmentParseOk(index);
            frames.bytes(:, match) = new_frames.bytes(:, index);
        end
    end
end

new_segments = remap_segments(new_segments, new_to_old);
segments = append_segments(segments, new_segments);
end

function segments = remap_segments(segments, frame_map)
for index = 1:numel(segments.frameIndex)
    old_index = double(segments.frameIndex(index));
    if old_index >= 1 && old_index <= numel(frame_map)
        segments.frameIndex(index) = uint32(frame_map(old_index));
    end
end
end

function segments = append_segments(first, second)
if isempty(first)
    segments = second;
    return;
end
segments = first;
names = fieldnames(first);
for field_index = 1:numel(names)
    name = names{field_index};
    segments.(name) = [first.(name); second.(name)];
end
end

function packets = merge_packet_records(first, second)
if isempty(first)
    packets = second;
    return;
end
packets = first;
for index = 1:numel(second.bytes)
    incoming_key = packet_key(second, index);
    match = 0;
    for candidate = 1:numel(packets.bytes)
        if strcmp(incoming_key, packet_key(packets, candidate))
            match = candidate;
            break;
        end
    end
    if match == 0
        packets = append_packet(packets, second, index);
    elseif ~packets.allFramesCrcOk(match) && second.allFramesCrcOk(index)
        packets = replace_packet(packets, second, match, index);
    end
end
end

function packets = append_packet(packets, source, source_index)
names = fieldnames(packets);
for field_index = 1:numel(names)
    name = names{field_index};
    if strcmp(name, 'bytes') || strcmp(name, 'segmentIndices')
        packets.(name){end + 1, 1} = source.(name){source_index};
    else
        packets.(name)(end + 1, 1) = source.(name)(source_index);
    end
end
end

function packets = replace_packet(packets, source, packet_index, source_index)
names = fieldnames(packets);
for field_index = 1:numel(names)
    name = names{field_index};
    if strcmp(name, 'bytes') || strcmp(name, 'segmentIndices')
        packets.(name){packet_index} = source.(name){source_index};
    else
        packets.(name)(packet_index) = source.(name)(source_index);
    end
end
end

function key = packet_key(packets, index)
bytes = uint8(packets.bytes{index});
sequence = uint32(0);
if numel(bytes) >= 20
    sequence = bitor(bitshift(uint32(bytes(17)), 24), ...
        bitor(bitshift(uint32(bytes(18)), 16), ...
        bitor(bitshift(uint32(bytes(19)), 8), uint32(bytes(20)))));
end
key = sprintf('%d:%d:%u', packets.portId(index), packets.packetId(index), sequence);
end

function packets = complete_crc_packets(packets, frames)
keep = false(numel(packets.bytes),1);
for index = 1:numel(keep)
    first = double(packets.firstFrame(index));
    last = double(packets.lastFrame(index));
    if numel(packets.bytes{index}) ~= 1400 || ...
            ~packets.allFramesCrcOk(index) || first < 1 || ...
            last > frames.frameCount || last < first
        continue;
    end
    range = first:last;
    continuous = all(mod(diff(double(frames.sequence(range))),2^32)==1);
    keep(index) = continuous && all(frames.crcOk(range));
end
names = fieldnames(packets);
for index = 1:numel(names)
    packets.(names{index}) = packets.(names{index})(keep,:);
end
end

function stats = packet_stats(packets)
stats.packetCount = numel(packets.bytes);
stats.packetCountByPort = zeros(1, 4);
for port = 1:4
    stats.packetCountByPort(port) = sum(packets.portId == port);
end
end

function [frames, segments] = trim_frame_records(frames, segments, maximum)
if frames.frameCount <= maximum
    return;
end
first = frames.frameCount - maximum + 1;
keep = first:frames.frameCount;
names = fieldnames(frames);
for field_index = 1:numel(names)
    name = names{field_index};
    value = frames.(name);
    if strcmp(name, 'bytes')
        frames.(name) = value(:, keep);
    elseif numel(value) == frames.frameCount
        frames.(name) = value(keep, :);
    end
end
frames.frameCount = maximum;

segment_keep = double(segments.frameIndex) >= first;
names = fieldnames(segments);
for field_index = 1:numel(names)
    name = names{field_index};
    value = segments.(name);
    if strcmp(name, 'payload')
        segments.(name) = value(segment_keep);
    elseif numel(value) == numel(segment_keep)
        segments.(name) = value(segment_keep, :);
    end
end
segments.frameIndex = uint32(double(segments.frameIndex) - first + 1);
end

function packets = trim_packet_records(packets, maximum)
if isempty(packets) || numel(packets.bytes) <= maximum
    return;
end

keep = numel(packets.bytes) - maximum + 1:numel(packets.bytes);
names = fieldnames(packets);
for field_index = 1:numel(names)
    name = names{field_index};
    if strcmp(name, 'bytes') || strcmp(name, 'segmentIndices')
        packets.(name) = packets.(name)(keep);
    else
        packets.(name) = packets.(name)(keep, :);
    end
end
end

function [lane_bits, diagnostics] = recover_optical_cma_bits(capture, cfg)
point_count = min(size(capture.channels, 1), 1000000);
cma_capture = capture;
cma_capture.channels = capture.channels(1:point_count, :);
options = struct('symbolRateHz', cfg.symbolRateHz, 'taps', 21, ...
    'stepSize', 5e-2, 'refineStepSize', 6.25e-3, ...
    'phaseScanSymbols', 8000, 'phaseBlockSymbols', 8, ...
    'phaseCandidateCount', 32, 'syncWord', cfg.syncWord, ...
    'frameBytes', cfg.frameBytes);
cma = optical_cma_mimo_equalize(cma_capture, options);
symbols = cma.equalizedSymbols;
if isempty(symbols) || size(symbols, 2) ~= 2
    error('update_realtime_decode:OpticalCma', ...
        'CMA did not return two polarization streams.');
end
last_error = '';
for swap = 0:1
    if swap == 0
        source = symbols;
    else
        source = symbols(:, [2 1]);
    end
    for swap_first_iq = 0:1
        for swap_second_iq = 0:1
            z1 = source(:, 1);
            z2 = source(:, 2);
            if swap_first_iq
                z1 = 1i * conj(z1);
            end
            if swap_second_iq
                z2 = 1i * conj(z2);
            end
            candidate = false(size(source, 1), 4);
            candidate(:, 1) = real(z1) >= 0;
            candidate(:, 2) = imag(z1) >= 0;
            candidate(:, 3) = real(z2) >= 0;
            candidate(:, 4) = imag(z2) >= 0;
            try
                [~, packing] = optical_pack_dpqpsk_bytes(candidate, cfg);
                lane_bits = candidate;
                diagnostics = cma;
                diagnostics.packing = packing;
                diagnostics.opticalMappingIndex = swap * 4 + ...
                    swap_first_iq * 2 + swap_second_iq + 1;
                return;
            catch exception
                last_error = exception.message;
            end
        end
    end
end
error('update_realtime_decode:OpticalSync', ...
    'Optical CMA did not find aggregate sync (%s).', last_error);
end
