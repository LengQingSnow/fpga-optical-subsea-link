function [rx_bytes, diagnostics, packing] = ...
    recover_dpqpsk_capture(capture, cfg)
%RECOVER_DPQPSK_CAPTURE Recover long captures with segmented timing tracking.

validateattributes(capture.channels, {'single', 'double'}, ...
    {'2d', 'nonempty', 'finite'}, mfilename, 'capture.channels');
if size(capture.channels, 2) ~= 4
    error('recover_dpqpsk_capture:ChannelCount', ...
        'Expected four columns ordered as TX0, TX2, TX4 and TX6.');
end

samples_per_symbol = double(capture.sampleRateHz) / double(cfg.symbolRateHz);
symbols_per_frame = 2 * double(cfg.frameBytes);
chunk_symbols = symbols_per_frame * double(cfg.timingChunkFrames);
chunk_points = max(1, round(chunk_symbols * samples_per_symbol));
chunk_count = ceil(double(capture.pointCount) / chunk_points);
minimum_points = ceil((4096 + numel(cfg.rrcCoefficients)) * ...
    samples_per_symbol);
if isfield(cfg, 'pulseShape') && strcmpi(cfg.pulseShape, 'nrz')
    minimum_points = ceil(4096 * samples_per_symbol);
end

estimated_bytes = ceil(double(capture.pointCount) / ...
    samples_per_symbol / 2) + cfg.frameBytes;
rx_bytes = zeros(estimated_bytes, 1, 'uint8');
write_index = 1;

chunk_start_points = zeros(chunk_count, 1);
chunk_point_counts = zeros(chunk_count, 1);
chunk_processed = false(chunk_count, 1);
chunk_phases = nan(chunk_count, 4);
chunk_sync_errors = nan(chunk_count, 4);
chunk_lane_offsets = nan(chunk_count, 4);
chunk_lane_polarity = nan(chunk_count, 4);
chunk_frame_count = zeros(chunk_count, 1);
chunk_crc_good = zeros(chunk_count, 1);
chunk_header_good = zeros(chunk_count, 1);
chunk_error_id = cell(chunk_count, 1);
total_symbols = 0;
successful_packing = struct();

local_cfg = cfg;
local_cfg.timingScanSymbols = cfg.chunkTimingScanSymbols;
local_cfg.packingScanSymbols = cfg.chunkPackingScanSymbols;

for chunk_index = 1:chunk_count
    first_point = (chunk_index - 1) * chunk_points + 1;
    last_point = min(capture.pointCount, first_point + chunk_points - 1);
    point_count = last_point - first_point + 1;
    chunk_start_points(chunk_index) = first_point;
    chunk_point_counts(chunk_index) = point_count;
    if point_count < minimum_points
        chunk_error_id{chunk_index} = ...
            'recover_dpqpsk_capture:ShortFinalChunk';
        continue;
    end

    chunk_capture = capture;
    chunk_capture.channels = capture.channels(first_point:last_point, :);
    chunk_capture.pointCount = point_count;
    chunk_capture.xOriginSeconds = capture.xOriginSeconds + ...
        (first_point - 1) / capture.sampleRateHz;

    try
        [lane_bits, local_recovery] = recover_dpqpsk_symbols( ...
            chunk_capture, local_cfg);
        [local_bytes, local_packing] = pack_dpqpsk_bytes( ...
            lane_bits, local_cfg);
        [local_frames, ~] = parse_aggregate_frames(local_bytes, local_cfg);
    catch error_info
        chunk_error_id{chunk_index} = error_info.identifier;
        warning('recover_dpqpsk_capture:ChunkSkipped', ...
            'Chunk %d was skipped: %s', chunk_index, error_info.message);
        continue;
    end

    first_byte = local_frames.lockedStartByte;
    byte_count = local_frames.frameCount * cfg.frameBytes;
    selected = local_bytes(first_byte:first_byte + byte_count - 1);
    rx_bytes(write_index:write_index + byte_count - 1) = selected;
    write_index = write_index + byte_count;

    phase_indices = round(local_recovery.timingPhaseSymbols * ...
        local_cfg.timingPhaseCount) + 1;
    for lane = 1:4
        chunk_sync_errors(chunk_index, lane) = ...
            local_recovery.laneSyncErrorRates(phase_indices(lane), lane);
    end
    chunk_processed(chunk_index) = true;
    chunk_phases(chunk_index, :) = local_recovery.timingPhaseSymbols;
    chunk_lane_offsets(chunk_index, :) = local_packing.laneSymbolOffsets;
    chunk_lane_polarity(chunk_index, :) = local_packing.lanePolarity;
    chunk_frame_count(chunk_index) = local_frames.frameCount;
    chunk_crc_good(chunk_index) = sum(local_frames.crcOk);
    chunk_header_good(chunk_index) = sum(local_frames.headerOk);
    total_symbols = total_symbols + local_recovery.symbolCount;
    successful_packing = local_packing;

    fprintf(['Timing chunk %d/%d: %.6f ms, %d frames, ' ...
        '%d CRC good (%.3f%%)\n'], chunk_index, chunk_count, ...
        (first_point - 1) / capture.sampleRateHz * 1e3, ...
        local_frames.frameCount, chunk_crc_good(chunk_index), ...
        100 * chunk_crc_good(chunk_index) / local_frames.frameCount);
end

if write_index == 1
    error('recover_dpqpsk_capture:NoRecoveredChunks', ...
        'No timing chunk produced a recoverable aggregate frame.');
end
segmented_rx_bytes = rx_bytes(1:write_index - 1);

timing_model = struct();
continuous_recovery = struct();
if isfield(cfg, 'useContinuousCdr') && cfg.useContinuousCdr
    timing_model = estimate_continuous_cdr(chunk_start_points, ...
        chunk_phases, chunk_processed, capture.sampleRateHz, cfg);
    fprintf(['Continuous CDR clock estimate: %.9f ppm, ' ...
        'symbol rate %.6f Hz.\n'], timing_model.clockOffsetPpm, ...
        timing_model.estimatedSymbolRateHz);
    [lane_bits, continuous_recovery] = recover_dpqpsk_continuous( ...
        capture, cfg, timing_model);
    [initial_bytes, initial_packing] = pack_dpqpsk_bytes(lane_bits, cfg);
    rx_bytes = initial_bytes;
    packing = initial_packing;
    equalizer_diagnostics = struct();
    equalizer_diagnostics.enabled = false;
    equalizer_diagnostics.accepted = false;
    if isfield(cfg, 'usePostEqualizer') && cfg.usePostEqualizer
        try
            [equalized_bits, equalizer_diagnostics] = ...
                equalize_dpqpsk_symbols(continuous_recovery.softSymbols, ...
                initial_bytes, initial_packing, cfg);
            [equalized_bytes, equalized_packing] = ...
                pack_dpqpsk_bytes(equalized_bits, cfg);
            [pre_frames, ~] = parse_aggregate_frames_relocked( ...
                initial_bytes, cfg);
            [post_frames, ~] = parse_aggregate_frames_relocked( ...
                equalized_bytes, cfg);
            pre_crc_good = sum(pre_frames.crcOk);
            post_crc_good = sum(post_frames.crcOk);
            pre_frame_count = pre_frames.frameCount;
            post_frame_count = post_frames.frameCount;
            mse_non_regression = all(equalizer_diagnostics.validationMse <= ...
                equalizer_diagnostics.baselineValidationMse + 1e-9);
            accept = post_crc_good >= pre_crc_good && ...
                post_frame_count >= pre_frame_count && mse_non_regression;
            equalizer_diagnostics.accepted = accept;
            equalizer_diagnostics.preCrcGood = pre_crc_good;
            equalizer_diagnostics.postCrcGood = post_crc_good;
            equalizer_diagnostics.preFrameCount = pre_frame_count;
            equalizer_diagnostics.postFrameCount = post_frame_count;
            if accept
                rx_bytes = equalized_bytes;
                packing = equalized_packing;
            end
            fprintf(['Post-equalizer %s: CRC %d -> %d, frames %d -> %d, ' ...
                'validation MSE improvement %.3f/%.3f/%.3f/%.3f\n'], ...
                ternary_text(accept), pre_crc_good, post_crc_good, ...
                pre_frame_count, post_frame_count, ...
                equalizer_diagnostics.validationMseImprovement);
            clear equalized_bits equalized_bytes equalized_packing;
        catch equalizer_error
            equalizer_diagnostics.enabled = false;
            equalizer_diagnostics.accepted = false;
            equalizer_diagnostics.errorIdentifier = equalizer_error.identifier;
            warning('recover_dpqpsk_capture:EqualizerSkipped', ...
                'Post-equalizer skipped: %s', equalizer_error.message);
        end
    end
    continuous_recovery.equalizer = equalizer_diagnostics;
    if isfield(continuous_recovery, 'softSymbols')
        continuous_recovery = rmfield(continuous_recovery, 'softSymbols');
    end
    clear lane_bits;
else
    rx_bytes = segmented_rx_bytes;
    packing = successful_packing;
end

diagnostics.sampleRateHz = double(capture.sampleRateHz);
diagnostics.samplesPerSymbol = samples_per_symbol;
if isfield(cfg, 'pulseShape')
    diagnostics.pulseShape = cfg.pulseShape;
else
    diagnostics.pulseShape = 'rrc';
end
if isfield(cfg, 'useContinuousCdr') && cfg.useContinuousCdr
    diagnostics.timingTracking = 'continuous_cdr';
    diagnostics.symbolCount = continuous_recovery.symbolCount;
    diagnostics.timingPhaseSymbols = ...
        continuous_recovery.timingPhaseSymbols;
    diagnostics.clockOffsetPpm = timing_model.clockOffsetPpm;
    diagnostics.estimatedSymbolRateHz = ...
        timing_model.estimatedSymbolRateHz;
    diagnostics.effectiveSamplesPerSymbol = ...
        timing_model.effectiveSamplesPerSymbol;
    diagnostics.cdrAnchorSymbols = timing_model.anchorSymbols;
    diagnostics.cdrAnchorPhaseSymbols = ...
        timing_model.anchorPhaseSymbols;
    diagnostics.cdrMeasuredPhaseSymbols = ...
        timing_model.measuredPhaseSymbols;
    diagnostics.cdrInlierMask = timing_model.inlierMask;
    diagnostics.cdrAnchorResidualRmsUi = ...
        timing_model.anchorResidualRmsUi;
    diagnostics.cdrTrackedResidualRmsUi = ...
        timing_model.trackedResidualRmsUi;
    diagnostics.channelCenter = continuous_recovery.channelCenter;
    diagnostics.channelScale = continuous_recovery.channelScale;
    diagnostics.decisionAbsMean = continuous_recovery.decisionAbsMean;
    diagnostics.decisionAbsStd = continuous_recovery.decisionAbsStd;
    diagnostics.equalizer = continuous_recovery.equalizer;
else
    diagnostics.timingTracking = 'segmented';
    diagnostics.symbolCount = total_symbols;
    diagnostics.timingPhaseSymbols = first_valid_row( ...
        chunk_phases, chunk_processed);
end
diagnostics.chunkCount = chunk_count;
diagnostics.chunkPoints = chunk_points;
diagnostics.chunkStartPoints = chunk_start_points;
diagnostics.chunkPointCounts = chunk_point_counts;
diagnostics.chunkProcessed = chunk_processed;
diagnostics.chunkTimingPhaseSymbols = chunk_phases;
diagnostics.chunkSyncErrorRates = chunk_sync_errors;
diagnostics.chunkFrameCount = chunk_frame_count;
diagnostics.chunkCrcGood = chunk_crc_good;
diagnostics.chunkHeaderGood = chunk_header_good;
diagnostics.chunkErrorId = chunk_error_id;
diagnostics.segmentedByteCount = numel(segmented_rx_bytes);

packing.byteCount = numel(rx_bytes);
packing.chunkLaneSymbolOffsets = chunk_lane_offsets;
packing.chunkLanePolarity = chunk_lane_polarity;
packing.chunkProcessed = chunk_processed;
end

function text = ternary_text(value)
if value
    text = 'accepted';
else
    text = 'rejected';
end
end

function row = first_valid_row(values, valid)
index = find(valid, 1, 'first');
if isempty(index)
    row = nan(1, size(values, 2));
else
    row = values(index, :);
end
end
