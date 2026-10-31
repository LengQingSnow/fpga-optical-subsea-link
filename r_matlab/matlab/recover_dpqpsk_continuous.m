function [lane_bits, diagnostics] = recover_dpqpsk_continuous( ...
    capture, cfg, timing_model)
%RECOVER_DPQPSK_CONTINUOUS Recover all symbols with a continuous CDR NCO.

validateattributes(capture.channels, {'single', 'double'}, ...
    {'2d', 'nonempty', 'finite'}, mfilename, 'capture.channels');
if size(capture.channels, 2) ~= 4
    error('recover_dpqpsk_continuous:ChannelCount', ...
        'Expected four columns ordered as TX0, TX2, TX4 and TX6.');
end

sample_rate = double(capture.sampleRateHz);
samples_per_symbol = sample_rate / double(cfg.symbolRateHz);
[pulse_coefficients, filter_delay] = rf47_pulse_shape_config(cfg);
if samples_per_symbol <= 1
    error('recover_dpqpsk_continuous:SamplingRate', ...
        'Scope sampling rate must exceed the symbol rate.');
end

estimate_count = min(size(capture.channels, 1), ...
    double(cfg.cdrScaleEstimatePoints));
estimate_indices = unique(round(linspace(1, ...
    size(capture.channels, 1), estimate_count)));
channel_center = zeros(1, 4);
channel_scale = zeros(1, 4);
point_counts = zeros(1, 4);
symbol_counts = zeros(1, 4);
for lane = 1:4
    estimate = double(capture.channels(estimate_indices, lane));
    channel_center(lane) = median(estimate);
    channel_scale(lane) = median(abs(estimate - channel_center(lane)));
    if channel_scale(lane) <= eps
        error('recover_dpqpsk_continuous:FlatChannel', ...
            'Channel %d has no measurable waveform.', lane);
    end
    point_counts(lane) = continuous_point_count( ...
        size(capture.channels, 1), samples_per_symbol, ...
        timing_model, lane);
    symbol_counts(lane) = floor((point_counts(lane) - ...
        filter_delay + 1) / 2);
end

symbol_count = min(symbol_counts);
if symbol_count < 4096
    error('recover_dpqpsk_continuous:ShortCapture', ...
        'Fewer than 4096 symbols remain after continuous timing recovery.');
end

lane_bits = false(symbol_count, 4);
decision_symbols = zeros(symbol_count, 4, 'single');
decision_mean = zeros(1, 4);
decision_std = zeros(1, 4);
for lane = 1:4
    symbols = resample_continuous_lane(capture.channels(:, lane), ...
        channel_center(lane), channel_scale(lane), samples_per_symbol, ...
        timing_model, lane, point_counts(lane), pulse_coefficients, ...
        cfg.cdrResampleChunkPoints);
    symbols = symbols(1:symbol_count);
    decision_symbols(:, lane) = symbols;
    lane_bits(:, lane) = symbols >= 0;
    decision_mean(lane) = mean(abs(double(symbols)));
    decision_std(lane) = std(abs(double(symbols)));
    fprintf('Continuous CDR lane %d/4: %d symbols recovered.\n', ...
        lane, symbol_count);
    clear symbols;
end

diagnostics.sampleRateHz = sample_rate;
diagnostics.samplesPerSymbol = samples_per_symbol;
diagnostics.timingPhaseSymbols = timing_model.phaseAtStart;
diagnostics.channelCenter = channel_center;
diagnostics.channelScale = channel_scale;
diagnostics.decisionAbsMean = decision_mean;
diagnostics.decisionAbsStd = decision_std;
diagnostics.symbolCount = symbol_count;
diagnostics.clockOffsetPpm = timing_model.clockOffsetPpm;
diagnostics.estimatedSymbolRateHz = timing_model.estimatedSymbolRateHz;
diagnostics.effectiveSamplesPerSymbol = ...
    timing_model.effectiveSamplesPerSymbol;
diagnostics.softSymbols = decision_symbols;
if isfield(cfg, 'pulseShape')
    diagnostics.pulseShape = cfg.pulseShape;
else
    diagnostics.pulseShape = 'rrc';
end
end

function point_count = continuous_point_count(input_count, ...
    samples_per_symbol, timing_model, lane)
usable_symbol_position = (double(input_count) - 2) / samples_per_symbol;
phase_start = timing_model.phaseAtStart(lane);
slope = timing_model.phaseSlopeUiPerSymbol;
maximum_u = (usable_symbol_position - phase_start) / (1 + slope);
point_count = max(0, floor(2 * maximum_u) + 1);

while point_count > 0 && sample_position(point_count, ...
        samples_per_symbol, timing_model, lane) > input_count - 1
    point_count = point_count - 1;
end
while sample_position(point_count + 1, samples_per_symbol, ...
        timing_model, lane) <= input_count - 1
    point_count = point_count + 1;
end
end

function position = sample_position(point_index, samples_per_symbol, ...
    timing_model, lane)
symbol_position = (double(point_index) - 1) / 2;
phase = interp1(timing_model.anchorSymbols, ...
    timing_model.anchorPhaseSymbols(:, lane), symbol_position, ...
    'linear', 'extrap');
position = 1 + (symbol_position + phase) * samples_per_symbol;
end

function symbols = resample_continuous_lane(signal, center, scale, ...
    samples_per_symbol, timing_model, lane, point_count, coefficients, ...
    chunk_size)
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
    symbol_positions = (double(global_indices) - 1) / 2;
    phase = interp1(timing_model.anchorSymbols, ...
        timing_model.anchorPhaseSymbols(:, lane), symbol_positions, ...
        'linear', 'extrap');
    positions = 1 + (symbol_positions + phase) * samples_per_symbol;
    interpolated = interpolate_normalized(signal, positions, center, scale);
    if isempty(coefficients)
        filtered = interpolated;
    else
        [filtered, filter_state] = filter(coefficients, 1, ...
            interpolated, filter_state);
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

function values = interpolate_normalized(signal, positions, center, scale)
lower_index = floor(positions);
fraction = positions - lower_index;
lower_index = max(1, min(numel(signal) - 1, lower_index));
lower = double(signal(lower_index));
upper = double(signal(lower_index + 1));
values = ((lower .* (1 - fraction) + upper .* fraction) - center) / scale;
end
