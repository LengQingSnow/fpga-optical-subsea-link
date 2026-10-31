function [lane_bits, diagnostics] = recover_dpqpsk_symbols(capture, cfg)
%RECOVER_DPQPSK_SYMBOLS Recover XI/XQ/YI/YQ bits from the four RF47 lanes.

validateattributes(capture.channels, {'single', 'double'}, ...
    {'2d', 'nonempty', 'finite'}, mfilename, 'capture.channels');
if size(capture.channels, 2) ~= 4
    error('recover_dpqpsk_symbols:ChannelCount', ...
        'Expected four columns ordered as TX0, TX2, TX4 and TX6.');
end

sample_rate = double(capture.sampleRateHz);
symbol_rate = double(cfg.symbolRateHz);
samples_per_symbol = sample_rate / symbol_rate;
if samples_per_symbol <= 1
    error('recover_dpqpsk_symbols:SamplingRate', ...
        'Scope sampling rate must exceed the 4 GHz symbol rate.');
end

normalized = zeros(size(capture.channels), 'single');
channel_center = zeros(1, 4);
channel_scale = zeros(1, 4);
for lane = 1:4
    signal = double(capture.channels(:, lane));
    center = median(signal);
    centered = signal - center;
    scale = median(abs(centered));
    if scale <= eps
        error('recover_dpqpsk_symbols:FlatChannel', ...
            'Channel %d has no measurable waveform.', lane);
    end
    normalized(:, lane) = single(centered / scale);
    channel_center(lane) = center;
    channel_scale(lane) = scale;
end

[pulse_coefficients, filter_delay] = rf47_pulse_shape_config(cfg);
[best_phases, phase_scores, phase_sync_hits, lane_phase_scores, ...
    lane_sync_error_rates, lane_sync_residues, lane_sync_inverted] = ...
    find_timing_phase(normalized, sample_rate, symbol_rate, cfg);

two_sps_step = sample_rate / (2 * symbol_rate);
start_positions = 1 + best_phases * samples_per_symbol;
last_position = size(normalized, 1) - 1;
resampled_counts = floor((last_position - start_positions) / two_sps_step) + 1;
symbol_counts = floor((resampled_counts - filter_delay + 1) / 2);
symbol_count = min(symbol_counts);
if symbol_count < 4096
    error('recover_dpqpsk_symbols:ShortCapture', ...
        'Fewer than 4096 symbols remain after timing recovery.');
end

lane_bits = false(symbol_count, 4);
decision_mean = zeros(1, 4);
decision_std = zeros(1, 4);
for lane = 1:4
    symbols = resample_match_and_decimate(normalized(:, lane), ...
        start_positions(lane), two_sps_step, resampled_counts(lane), ...
        pulse_coefficients, cfg.resampleChunkPoints);
    symbols = symbols(1:symbol_count);
    lane_bits(:, lane) = symbols >= 0;
    decision_mean(lane) = mean(abs(double(symbols)));
    decision_std(lane) = std(abs(double(symbols)));
end

diagnostics.sampleRateHz = sample_rate;
diagnostics.samplesPerSymbol = samples_per_symbol;
diagnostics.timingPhaseSymbols = best_phases;
diagnostics.phaseScores = phase_scores;
diagnostics.phaseSyncHits = phase_sync_hits;
diagnostics.lanePhaseScores = lane_phase_scores;
diagnostics.laneSyncErrorRates = lane_sync_error_rates;
diagnostics.laneSyncResidues = lane_sync_residues;
diagnostics.laneSyncInverted = lane_sync_inverted;
diagnostics.channelCenter = channel_center;
diagnostics.channelScale = channel_scale;
diagnostics.decisionAbsMean = decision_mean;
diagnostics.decisionAbsStd = decision_std;
diagnostics.symbolCount = symbol_count;
if isfield(cfg, 'pulseShape')
    diagnostics.pulseShape = cfg.pulseShape;
else
    diagnostics.pulseShape = 'rrc';
end
end

function [best_phases, phase_scores, sync_hits, lane_phase_scores, ...
    lane_sync_error_rates, lane_sync_residues, lane_sync_inverted] = ...
    find_timing_phase(channels, sample_rate, symbol_rate, cfg)
phase_count = cfg.timingPhaseCount;
phase_scores = zeros(phase_count, 1);
sync_hits = zeros(phase_count, 1);
lane_phase_scores = zeros(phase_count, 4);
lane_sync_error_rates = inf(phase_count, 4);
lane_sync_residues = zeros(phase_count, 4);
lane_sync_inverted = false(phase_count, 4);
samples_per_symbol = sample_rate / symbol_rate;
[pulse_coefficients, filter_delay] = rf47_pulse_shape_config(cfg);
two_sps_step = samples_per_symbol / 2;
max_symbols = min(cfg.timingScanSymbols, ...
    floor((size(channels, 1) - 2) / samples_per_symbol) - filter_delay);
if max_symbols < 4096
    error('recover_dpqpsk_symbols:TimingWindow', ...
        'Capture is too short for timing phase search.');
end

for phase_index = 1:phase_count
    phase = (phase_index - 1) / phase_count;
    start_position = 1 + phase * samples_per_symbol;
    available_points = floor((size(channels, 1) - 1 - start_position) / ...
        two_sps_step) + 1;
    resampled_count = min(available_points, 2 * max_symbols + filter_delay);
    sampled = false(max_symbols, 4);
    decisions = zeros(max_symbols, 4, 'single');
    for lane = 1:4
        symbols = resample_match_and_decimate(channels(:, lane), ...
            start_position, two_sps_step, resampled_count, ...
            pulse_coefficients, cfg.resampleChunkPoints);
        count = min(max_symbols, numel(symbols));
        decisions(1:count, lane) = symbols(1:count);
        sampled(1:count, lane) = symbols(1:count) >= 0;
    end
    spread = std(abs(double(decisions)), 0, 1);
    opening = mean(abs(double(decisions)), 1) ./ (spread + eps);
    lane_phase_scores(phase_index, :) = opening;
    phase_scores(phase_index) = sum(opening);
    sync_hits(phase_index) = maximum_sync_hits(sampled, cfg.syncWord);
    for lane = 1:4
        [lane_sync_error_rates(phase_index, lane), ...
            lane_sync_residues(phase_index, lane), ...
            lane_sync_inverted(phase_index, lane)] = ...
            minimum_periodic_lane_sync_error(sampled(:, lane), ...
            cfg.syncWord, lane, 2 * cfg.frameBytes);
    end
end

best_phases = zeros(1, 4);
for lane = 1:4
    best_error_rate = min(lane_sync_error_rates(:, lane));
    candidates = find(abs(lane_sync_error_rates(:, lane) - ...
        best_error_rate) <= 1e-12);
    [~, local_best] = max(lane_phase_scores(candidates, lane));
    best_index = candidates(local_best);
    best_phases(lane) = (best_index - 1) / phase_count;
end
end

function hits = maximum_sync_hits(bits, sync_word)
hits = 0;
for polarity_mask = 0:15
    trial = bits;
    for lane = 1:4
        if bitget(polarity_mask, lane)
            trial(:, lane) = ~trial(:, lane);
        end
    end
    nibbles = uint8(trial(:, 1)) * 8 + uint8(trial(:, 2)) * 4 + ...
        uint8(trial(:, 3)) * 2 + uint8(trial(:, 4));
    for offset = 0:1
        usable = floor((numel(nibbles) - offset) / 2) * 2;
        if usable < 16
            continue;
        end
        selected = nibbles(offset + 1:offset + usable);
        bytes = bitshift(selected(1:2:end), 4) + selected(2:2:end);
        count = numel(strfind(double(bytes(:).'), double(sync_word(:).')));
        if count > hits
            hits = count;
        end
    end
end
end

function [error_rate, best_residue, inverted] = ...
    minimum_periodic_lane_sync_error(bits, sync_word, lane, frame_symbols)
sync_word = uint8(sync_word(:));
sync_nibbles = zeros(2 * numel(sync_word), 1, 'uint8');
sync_nibbles(1:2:end) = bitshift(sync_word, -4);
sync_nibbles(2:2:end) = bitand(sync_word, uint8(15));
expected = double(bitget(sync_nibbles, 5 - lane));
window_length = numel(expected);

actual = double(logical(bits(:)));
position_count = numel(actual) - window_length + 1;
if position_count < frame_symbols
    error_rate = inf;
    best_residue = 0;
    inverted = false;
    return;
end
window_ones = conv(actual, ones(window_length, 1), 'valid');
correlation = conv(actual, flipud(expected), 'valid');
mismatch = window_ones + sum(expected) - 2 * correlation;
residues = mod((0:position_count - 1)', frame_symbols) + 1;
position_counts = accumarray(residues, 1, [frame_symbols, 1]);
direct_errors = accumarray(residues, mismatch, [frame_symbols, 1]);
inverted_errors = position_counts * window_length - direct_errors;
minimum_errors = min(direct_errors, inverted_errors);
rates = minimum_errors ./ (position_counts * window_length);
[error_rate, residue_index] = min(rates);
best_residue = residue_index - 1;
inverted = inverted_errors(residue_index) < direct_errors(residue_index);
end

function symbols = resample_match_and_decimate(signal, start_position, ...
    step, point_count, coefficients, chunk_size)
coefficients = double(coefficients(:));
if isempty(coefficients)
    filter_delay = 0;
else
    filter_delay = (numel(coefficients) - 1) / 2;
end
symbol_count = floor((point_count - filter_delay + 1) / 2);
symbols = zeros(symbol_count, 1, 'single');
filter_state = zeros(max(0, numel(coefficients) - 1), 1);
write_index = 1;

for chunk_start = 1:chunk_size:point_count
    chunk_end = min(point_count, chunk_start + chunk_size - 1);
    global_indices = (chunk_start:chunk_end)';
    positions = start_position + (double(global_indices) - 1) * step;
    interpolated = double(interpolate_uniform(signal, positions));
    if isempty(coefficients)
        filtered = interpolated;
    else
        [filtered, filter_state] = filter( ...
            coefficients, 1, interpolated, filter_state);
    end

    first_valid = max(chunk_start, filter_delay + 1);
    if mod(first_valid - (filter_delay + 1), 2) ~= 0
        first_valid = first_valid + 1;
    end
    selected_global = first_valid:2:chunk_end;
    if isempty(selected_global)
        continue;
    end
    selected_local = selected_global - chunk_start + 1;
    count = numel(selected_local);
    symbols(write_index:write_index + count - 1) = ...
        single(filtered(selected_local));
    write_index = write_index + count;
end
symbols = symbols(1:write_index - 1);
end

function values = interpolate_uniform(signal, positions)
lower_index = floor(positions);
fraction = single(positions - lower_index);
lower_index = max(1, min(numel(signal) - 1, lower_index));
values = signal(lower_index) .* (1 - fraction) + ...
    signal(lower_index + 1) .* fraction;
end
