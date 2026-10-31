function report = offline_decode_data2_optical()
%OFFLINE_DECODE_DATA2_OPTICAL Decode offline optical data2 capture.
script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);
project_dir = fileparts(script_dir);
data_dir = fullfile(project_dir, 'data2');
dataset_dir = fullfile(project_dir, 'dataset2');
result_dir = fullfile(data_dir, 'offline_optical_result');
if exist(result_dir, 'dir') ~= 7
    mkdir(result_dir);
end
fprintf('Loading offline optical capture: %s\n', data_dir);
cfg = rf47_default_config(script_dir);
cfg.dataDir = data_dir;
cfg.datasetDir = dataset_dir;
cfg.opticalCma = true;
references = load_reference_dataset(dataset_dir);
if exist(fullfile(data_dir, 'capture.json'), 'file') == 2
    report = offline_decode_streamed_scpi(data_dir, dataset_dir, result_dir, cfg, references);
    return;
end
capture = load_scope_capture(data_dir, '');
fprintf('Capture: %.6g GSa/s, %d points/channel\n', ...
    capture.sampleRateHz / 1e9, capture.pointCount);
short_cfg = cfg;
short_cfg.timingScanSymbols = min(double(cfg.timingScanSymbols), 8192);
short_cfg.packingScanSymbols = min(double(cfg.packingScanSymbols), 131072);
short_cfg.resampleChunkPoints = min(double(cfg.resampleChunkPoints), 262144);
state = [];
[state, decoded] = update_realtime_decode(state, capture, short_cfg, references);
if decoded.frameCount == 0
    fprintf('Cached training did not synchronize; trying capture-local blind CMA.\n');
    [fallback_bytes, fallback_cma, fallback_packing] = ...
        try_capture_local_cma(capture, cfg);
    if ~isempty(fallback_bytes)
        parser_cfg = cfg;
        parser_cfg.useBadCrcSegments = true;
        [fallback_frames, fallback_segments] = ...
            parse_aggregate_frames_relocked(fallback_bytes, parser_cfg);
        frame_stream = fallback_frames.bytes(:);
        chunk_points = 1000000;
        chunk_count = floor(size(capture.channels, 1) / chunk_points);
        for chunk_index = 2:chunk_count
            first = (chunk_index - 1) * chunk_points + 1;
            last = chunk_index * chunk_points;
            chunk_capture = capture;
            chunk_capture.channels = capture.channels(first:last, :);
            chunk_capture.pointCount = chunk_points;
            [chunk_bytes, ~, ~] = try_capture_local_cma( ...
                chunk_capture, cfg, true);
            if isempty(chunk_bytes)
                fprintf('Chunk %d/%d: no aggregate sync\n', ...
                    chunk_index, chunk_count);
                continue;
            end
            try
                [chunk_frames, ~] = parse_aggregate_frames_relocked( ...
                    chunk_bytes, parser_cfg);
                frame_stream = [frame_stream; chunk_frames.bytes(:)]; %#ok<AGROW>
                fprintf('Chunk %d/%d: %d frames, %d CRC good\n', ...
                    chunk_index, chunk_count, chunk_frames.frameCount, ...
                    sum(chunk_frames.crcOk));
            catch exception
                fprintf('Chunk %d/%d parse failed: %s\n', ...
                    chunk_index, chunk_count, exception.message);
            end
        end
        [fallback_frames, fallback_segments] = ...
            parse_aggregate_frames_relocked(frame_stream, parser_cfg);
        state.frames = fallback_frames;
        state.segments = fallback_segments;
        state.lastRecovery = fallback_cma;
        state.lastPacking = fallback_packing;
        state.lastDecodedBytes = numel(fallback_bytes);
        [fallback_packets, ~] = reassemble_udp_packets( ...
            fallback_segments, fallback_frames, parser_cfg);
        [fallback_axds, ~] = parse_axds_packets(fallback_packets, parser_cfg);
        [state.objects, ~] = reassemble_axds_objects(fallback_axds);
        decoded = make_offline_result(state, references);
    end
end
report = struct('capture', capture, 'decoded', decoded, 'state', state);
fprintf('Decoded frames: %d, CRC good: %d, CRC bad: %d\n', ...
    decoded.frameCount, decoded.crcGoodFrames, decoded.crcBadFrames);
fprintf('Decoded bytes: %d, objects: %d\n', ...
    decoded.decodedBytes, decoded.objectCount);
print_dataset_result('Underwater image', decoded.image);
print_dataset_result('Earthquake waveform', decoded.waveform);
known = struct();
if ~isempty(state.frames) && isstruct(state.frames) && ...
        ~isempty(state.segments)
    try
        [known, ~] = analyze_known_frame_errors(state.frames, ...
            state.segments, references, result_dir, cfg);
        fprintf('Known aggregate/PRBS31 BER: %.6e (%d/%d bits)\n', ...
            known.ber, known.bitErrors, known.comparedBits);
    catch exception
        known.error = exception.message;
        fprintf('Known aggregate/PRBS31 analysis unavailable: %s\n', ...
            exception.message);
    end
else
    known.error = 'No parseable aggregate frames were recovered.';
    fprintf('%s\n', known.error);
end

function [bytes, cma, packing] = try_capture_local_cma(capture, cfg, fixed)
bytes = uint8([]);
packing = struct();
if nargin < 3
    fixed = false;
end
point_count = min(size(capture.channels, 1), 1000000);
local_capture = capture;
local_capture.channels = capture.channels(1:point_count, :);
best_score = -inf;
best_cma = struct();
if fixed
    tap_candidates = 41;
    step_candidates = 2.5e-2;
else
    tap_candidates = [21 31 41];
    step_candidates = [2.5e-2 5e-2];
end
for tap_index = 1:numel(tap_candidates)
    for step_index = 1:numel(step_candidates)
        options = struct('symbolRateHz', cfg.symbolRateHz, ...
            'taps', tap_candidates(tap_index), ...
            'stepSize', step_candidates(step_index), ...
            'refineStepSize', step_candidates(step_index) / 8, ...
            'phaseScanSymbols', 8000, 'phaseBlockSymbols', 8, ...
            'phaseCandidateCount', 32);
        try
            candidate_cma = cma_mimo_equalize(local_capture, options);
            symbols = candidate_cma.equalizedSymbols;
            for swap = 0:1
                source = symbols;
                if swap
                    source = source(:, [2 1]);
                end
                for first_iq = 0:1
                    for second_iq = 0:1
                        z1 = source(:, 1);
                        z2 = source(:, 2);
                        if first_iq
                            z1 = 1i * conj(z1);
                        end
                        if second_iq
                            z2 = 1i * conj(z2);
                        end
                        bits = [real(z1) >= 0, imag(z1) >= 0, ...
                            real(z2) >= 0, imag(z2) >= 0];
                        try
                            [candidate, candidate_packing] = ...
                                optical_pack_dpqpsk_bytes(bits, cfg);
                            [trial_frames, ~] = ...
                                parse_aggregate_frames_relocked( ...
                                uint8(candidate(:)), cfg);
                            score = sum(trial_frames.headerOk) + ...
                                sum(trial_frames.segmentParseOk) + ...
                                100 * sum(trial_frames.crcOk);
                            if score > best_score
                                best_score = score;
                                bytes = uint8(candidate(:));
                                packing = candidate_packing;
                                best_cma = candidate_cma;
                                best_cma.opticalMappingIndex = swap * 4 + ...
                                    first_iq * 2 + second_iq + 1;
                            end
                        catch
                        end
                    end
                end
            end
        catch exception
            fprintf('CMA candidate failed: %s\n', exception.message);
        end
    end
end
if isinf(best_score)
    cma = struct('error', 'No CMA candidate reached aggregate sync.');
else
    cma = best_cma;
    fprintf('Best capture-local CMA parse score: %.0f\n', best_score);
end
end

function result = make_offline_result(state, references)
result = struct('frameCount', 0, 'crcGoodFrames', 0, ...
    'crcBadFrames', 0, 'decodedBytes', state.lastDecodedBytes, ...
    'objectCount', numel(state.objects), 'image', empty_dataset_result(), ...
    'waveform', empty_dataset_result());
if isempty(state.frames)
    return;
end
result.frameCount = state.frames.frameCount;
result.crcGoodFrames = sum(state.frames.crcOk);
result.crcBadFrames = result.frameCount - result.crcGoodFrames;
if isempty(state.objects)
    return;
end
image_index = find([state.objects.datasetType] == 1, 1, 'first');
wave_index = find([state.objects.datasetType] == 2 & ...
    [state.objects.objectId] == 1, 1, 'first');
if ~isempty(image_index)
    result.image = object_result(state.objects(image_index), references, 1);
end
if ~isempty(wave_index)
    result.waveform = object_result(state.objects(wave_index), references, 2);
end
end

function result = object_result(object, references, dataset_type)
result = empty_dataset_result();
result.available = true;
result.data = uint8(object.data(:));
result.validMask = logical(object.validMask(:));
result.coverage = sum(result.validMask) / max(1, numel(result.validMask));
result.objectId = double(object.objectId);
result.cycle = uint32(object.datasetCycle);
if dataset_type == 1 && result.objectId <= numel(references.images)
    expected = uint8(references.images{result.objectId});
elseif dataset_type == 2 && result.objectId == 1
    expected = uint8(references.waveformBytes);
else
    expected = uint8([]);
end
count = min(numel(expected), numel(result.data));
mask = result.validMask(1:count);
if any(mask)
    result.bitErrors = sum(popcount8(bitxor(result.data(1:count), ...
        expected(1:count))) .* mask);
    result.comparedBits = 8 * sum(mask);
    result.ber = result.bitErrors / result.comparedBits;
end
end

function result = empty_dataset_result()
result = struct('available', false, 'data', uint8([]), ...
    'validMask', false(0, 1), 'coverage', 0, 'ber', NaN, ...
    'bitErrors', 0, 'comparedBits', 0, 'objectId', 0, 'cycle', uint32(0));
end

function summary = summarize_idle_frames(frames, cfg)
summary = struct('ber', NaN, 'bitErrors', 0, 'comparedBits', 0, ...
    'frameCount', 0, 'crcGoodFrames', 0);
if isempty(frames) || ~isfield(frames, 'frameCount')
    return;
end
summary.frameCount = frames.frameCount;
summary.crcGoodFrames = sum(frames.crcOk);
errors = 0;
bits = 0;
for index = 1:summary.frameCount
    expected = zeros(cfg.frameBytes, 1, 'uint8');
    expected(1:8) = reshape(cfg.syncWord, 1, []);
    expected(9) = cfg.protocolVersion;
    expected(10) = uint8(6);
    expected(13:16) = write_be_u32_local(frames.sequence(index));
    expected(17:cfg.framePayloadEnd) = aggregate_prbs31_bytes( ...
        frames.sequence(index), cfg.framePayloadEnd - 16);
    expected(cfg.framePayloadEnd + 1:cfg.frameBytes) = write_be_u32_local( ...
        crc32_msb(expected(1:cfg.framePayloadEnd)));
    errors = errors + sum(popcount8(bitxor(frames.bytes(:, index), expected)));
    bits = bits + 8 * numel(expected);
end
summary.bitErrors = errors;
summary.comparedBits = bits;
summary.ber = errors / max(1, bits);
end

function bytes = write_be_u32_local(value)
value = uint32(value);
bytes = uint8([bitshift(value, -24), bitand(bitshift(value, -16), 255), ...
    bitand(bitshift(value, -8), 255), bitand(value, 255)]).';
end

function values = popcount8(input)
values = zeros(size(input));
for bit = 1:8
    values = values + double(bitget(input, bit));
end
end
report.knownFrame = known;
if decoded.frameCount > 0 && decoded.objectCount == 0
    report.idleFrame = summarize_idle_frames(state.frames, cfg);
    fprintf('Idle/PRBS31 filler BER: %.6e (%d/%d bits)\n', ...
        report.idleFrame.ber, report.idleFrame.bitErrors, ...
        report.idleFrame.comparedBits);
else
    report.idleFrame = struct();
end
save(fullfile(result_dir, 'offline_optical_report.mat'), 'report', '-v7.3');
fprintf('Report written to: %s\n', result_dir);
end

function print_dataset_result(label, value)
if ~isfield(value, 'available') || ~value.available
    fprintf('%s: not recovered\n', label);
    return;
end
fprintf('%s: coverage %.3f%%, BER %.6e (%d/%d bits), object %d cycle %d\n', ...
    label, 100 * value.coverage, value.ber, value.bitErrors, ...
    value.comparedBits, value.objectId, value.cycle);
end

function report = offline_decode_streamed_scpi( ...
        data_dir, dataset_dir, result_dir, cfg, references)
metadata = fileread(fullfile(data_dir, 'capture.json'));
point_count = parse_json_number(metadata, 'pointCount');
x_increment = parse_json_number(metadata, 'xIncrement');
sample_rate = 1 / x_increment;
chunk_points = 1000000;
chunk_count = ceil(point_count / chunk_points);
chunk_stride = 10;
file_ids = zeros(1, 4);
cleanup_files = onCleanup(@() close_files(file_ids));
for channel = 1:4
    file_ids(channel) = fopen(fullfile(data_dir, ...
        sprintf('ch%d.bin', channel)), 'r');
    if file_ids(channel) < 0
        error('offline_decode_data2_optical:ChannelOpen', ...
            'Cannot open channel %d file.', channel);
    end
end
scaling = parse_channel_scaling(metadata);
frame_stream = uint8([]);
total_input_frames = 0;
total_crc_good = 0;
last_cma = struct();
last_packing = struct();
checkpoint_file = fullfile(result_dir, 'stream_checkpoint.mat');
fprintf('Streamed capture: %.6g GSa/s, %d points, %d chunks\n', ...
    sample_rate / 1e9, point_count, chunk_count);
for chunk_index = 1:chunk_count
    if mod(chunk_index - 1, chunk_stride) ~= 0
        for channel = 1:4
            fseek(file_ids(channel), chunk_points, 'cof');
        end
        continue;
    end
    this_count = min(chunk_points, ...
        point_count - (chunk_index - 1) * chunk_points);
    capture = struct();
    capture.channels = zeros(this_count, 4, 'single');
    capture.sampleRateHz = sample_rate;
    capture.pointCount = this_count;
    for channel = 1:4
        raw = fread(file_ids(channel), this_count, '*uint8');
        if numel(raw) ~= this_count
            error('offline_decode_data2_optical:ShortRead', ...
                'CH%d chunk %d is incomplete.', channel, chunk_index);
        end
        capture.channels(:, channel) = single((double(raw) - ...
            scaling(channel, 3) - scaling(channel, 2)) * ...
            scaling(channel, 1));
    end
    [chunk_bytes, chunk_cma, chunk_packing] = ...
        offline_try_capture_local_cma(capture, cfg, true);
    chunk_frames = [];
    if ~isempty(chunk_bytes)
        try
            [chunk_frames, ~] = parse_aggregate_frames_relocked( ...
                chunk_bytes, cfg);
        catch
            chunk_frames = [];
        end
    end
    if isempty(chunk_frames) || sum(chunk_frames.crcOk) == 0
        [chunk_bytes, chunk_cma, chunk_packing] = ...
            offline_try_capture_local_cma(capture, cfg, false);
        if ~isempty(chunk_bytes)
            try
                [chunk_frames, ~] = parse_aggregate_frames_relocked( ...
                    chunk_bytes, cfg);
            catch
                chunk_frames = [];
            end
        end
    end
    if isempty(chunk_frames)
        fprintf('Chunk %d/%d: no frame\n', chunk_index, chunk_count);
    else
        frame_stream = [frame_stream; chunk_frames.bytes(:)]; %#ok<AGROW>
        total_input_frames = total_input_frames + chunk_frames.frameCount;
        total_crc_good = total_crc_good + sum(chunk_frames.crcOk);
        last_cma = chunk_cma;
        last_packing = chunk_packing;
        fprintf('Chunk %d/%d: %d frames, %d CRC good, %d content\n', ...
            chunk_index, chunk_count, chunk_frames.frameCount, ...
            sum(chunk_frames.crcOk), sum(chunk_frames.segmentBytes > 0));
        save(checkpoint_file, 'frame_stream', 'total_input_frames', ...
            'total_crc_good', 'last_cma', 'last_packing', 'chunk_index', ...
            '-v7.3');
    end
end
clear cleanup_files;
close_files(file_ids);

parser_cfg = cfg;
parser_cfg.useBadCrcSegments = true;
[frames, segments] = parse_aggregate_frames_relocked(frame_stream, parser_cfg);
[packets, udp_stats] = reassemble_udp_packets(segments, frames, parser_cfg);
[axds, axds_stats] = parse_axds_packets(packets, parser_cfg);
[objects, object_stats] = reassemble_axds_objects(axds);
state = struct('frames', frames, 'segments', segments, 'packets', packets, ...
    'objects', objects, 'lastRecovery', last_cma, ...
    'lastPacking', last_packing, 'lastDecodedBytes', numel(frame_stream), ...
    'udpStats', udp_stats, 'axdsStats', axds_stats, ...
    'objectStats', object_stats);
decoded = offline_make_decode_result(state, references);
report = struct('capture', struct('sampleRateHz', sample_rate, ...
    'pointCount', point_count, 'directory', data_dir), ...
    'decoded', decoded, 'state', state, 'knownFrame', struct(), ...
    'inputFrameCount', total_input_frames, ...
    'inputCrcGoodFrames', total_crc_good);
fprintf('Decoded frames: %d, CRC good: %d, CRC bad: %d\n', ...
    decoded.frameCount, decoded.crcGoodFrames, decoded.crcBadFrames);
print_dataset_result('Underwater image', decoded.image);
print_dataset_result('Earthquake waveform', decoded.waveform);
if decoded.frameCount > 0 && decoded.objectCount == 0
    report.idleFrame = offline_summarize_idle_frames(frames, cfg);
else
    report.idleFrame = struct();
end
save(fullfile(result_dir, 'offline_optical_report.mat'), 'report', '-v7.3');
fprintf('Report written to: %s\n', result_dir);
end

function value = parse_json_number(text, name)
token = regexp(text, ['"' name '"\s*:\s*([-+0-9.Ee]+)'], ...
    'tokens', 'once');
if isempty(token)
    error('offline_decode_data2_optical:Metadata', ...
        'Missing metadata field %s.', name);
end
value = str2double(token{1});
end

function scaling = parse_channel_scaling(text)
scaling = zeros(4, 3);
for channel = 1:4
    pattern = ['(?s)"channel"\s*:\s*' num2str(channel) '.*?' ...
        '"yIncrement"\s*:\s*([-+0-9.Ee]+).*?' ...
        '"yOrigin"\s*:\s*([-+0-9.Ee]+).*?' ...
        '"yReference"\s*:\s*([-+0-9.Ee]+)'];
    token = regexp(text, pattern, 'tokens', 'once');
    if isempty(token)
        error('offline_decode_data2_optical:Scaling', ...
            'Missing scaling for channel %d.', channel);
    end
    scaling(channel, :) = str2double(token);
end
end

function close_files(file_ids)
for index = 1:numel(file_ids)
    if file_ids(index) > 0
        try
            fclose(file_ids(index));
        catch
        end
    end
end
end
