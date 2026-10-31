function metrics = compute_eye_metrics(capture, symbol_rate_hz)
%COMPUTE_EYE_METRICS Estimate binary eye height/width and timing phase.

if nargin < 2 || isempty(symbol_rate_hz)
    symbol_rate_hz = 4e9;
end
validateattributes(capture.channels, {'single', 'double'}, ...
    {'2d', 'nonempty', 'finite'}, mfilename, 'capture.channels');
samples_per_symbol = double(capture.sampleRateHz) / double(symbol_rate_hz);
if samples_per_symbol < 4
    error('compute_eye_metrics:SamplingRate', ...
        'At least four scope samples per symbol are required.');
end

phase_step = 0.01;
phase_grid = 0:phase_step:1 - phase_step;
lane_metrics = repmat(struct(), 1, 4);
normalized = zeros(size(capture.channels), 'single');
scope_scale = zeros(1, 4);
for lane = 1:4
    signal = double(capture.channels(:, lane));
    center = median(signal);
    scope_scale(lane) = median(abs(signal - center));
    if scope_scale(lane) <= eps
        error('compute_eye_metrics:FlatChannel', ...
            'Channel %d is flat.', lane);
    end
    normalized(:, lane) = single((signal - center) / scope_scale(lane));
end

for lane = 1:4
    signal = double(normalized(:, lane));
    opening = zeros(size(phase_grid));
    upper_level = zeros(size(phase_grid));
    lower_level = zeros(size(phase_grid));
    sample_count = floor((numel(signal) - 2 - phase_grid * ...
        samples_per_symbol) / samples_per_symbol);
    for phase_index = 1:numel(phase_grid)
        positions = 1 + phase_grid(phase_index) * samples_per_symbol + ...
            (0:sample_count(phase_index) - 1) * samples_per_symbol;
        values = interpolate(signal, positions);
        split = median(values);
        high = values(values >= split);
        low = values(values < split);
        if isempty(high) || isempty(low)
            continue;
        end
        upper_level(phase_index) = median(high);
        lower_level(phase_index) = median(low);
        opening(phase_index) = upper_level(phase_index) - ...
            lower_level(phase_index);
    end

    [max_opening, best_index] = max(opening);
    threshold = 0.8 * max_opening;
    eye_width_ui = sum(opening >= threshold) * phase_step;
    best_phase = phase_grid(best_index);
    best_positions = 1 + best_phase * samples_per_symbol + ...
        (0:sample_count(best_index) - 1) * samples_per_symbol;
    best_values = interpolate(signal, best_positions);
    rms_noise = sqrt(mean((best_values - ...
        sign(best_values) * max_opening / 2) .^ 2));

    lane_metrics(lane).channel = lane;
    lane_metrics(lane).samplesPerSymbol = samples_per_symbol;
    lane_metrics(lane).bestPhaseUi = best_phase;
    lane_metrics(lane).eyeHeightNormalized = max_opening;
    lane_metrics(lane).eyeHeightVolts = max_opening * scope_scale(lane);
    lane_metrics(lane).eyeWidthUi = eye_width_ui;
    lane_metrics(lane).upperLevelNormalized = upper_level(best_index);
    lane_metrics(lane).lowerLevelNormalized = lower_level(best_index);
    lane_metrics(lane).openingByPhaseUi = opening;
    lane_metrics(lane).phaseGridUi = phase_grid;
    lane_metrics(lane).rmsDecisionNoiseNormalized = rms_noise;
end

reference_phase = lane_metrics(1).bestPhaseUi;
for lane = 1:4
    relative = lane_metrics(lane).bestPhaseUi - reference_phase;
    relative = relative - round(relative);
    lane_metrics(lane).relativePhaseUi = relative;
    lane_metrics(lane).relativeDelayPs = relative * ...
        1e12 / double(symbol_rate_hz);
end

metrics.sampleRateHz = capture.sampleRateHz;
metrics.symbolRateHz = symbol_rate_hz;
metrics.samplesPerSymbol = samples_per_symbol;
metrics.channel = lane_metrics;
metrics.bestEyeHeightNormalized = [lane_metrics.eyeHeightNormalized];
metrics.bestEyeWidthUi = [lane_metrics.eyeWidthUi];
metrics.bestPhaseUi = [lane_metrics.bestPhaseUi];
metrics.relativePhaseUi = [lane_metrics.relativePhaseUi];
metrics.relativeDelayPs = [lane_metrics.relativeDelayPs];
end

function values = interpolate(signal, positions)
positions = positions(:);
lower = floor(positions);
fraction = positions - lower;
lower = max(1, min(numel(signal) - 1, lower));
values = signal(lower) .* (1 - fraction) + ...
    signal(lower + 1) .* fraction;
end
