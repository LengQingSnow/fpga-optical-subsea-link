function eye = compute_realtime_eye(samples, sample_rate_hz, symbol_rate_hz, clock_offset_ppm, phase_bins, amplitude_bins)
%COMPUTE_REALTIME_EYE Build two polarization constellations at maximum eye height.

if nargin < 3 || isempty(symbol_rate_hz)
    symbol_rate_hz = 4e9;
end
if nargin < 4 || isempty(clock_offset_ppm)
    clock_offset_ppm = -0.18310546875;
end
if nargin < 5 || isempty(phase_bins)
    phase_bins = 160;
end
if nargin < 6 || isempty(amplitude_bins)
    amplitude_bins = 120;
end
validateattributes(samples, {'single', 'double'}, ...
    {'2d', 'nonempty', 'finite'}, mfilename, 'samples');
if size(samples, 2) ~= 4
    error('compute_realtime_eye:ChannelCount', 'Expected four channels.');
end
validateattributes(phase_bins, {'numeric'}, ...
    {'scalar', 'integer', '>=', 33}, mfilename, 'phase_bins');
validateattributes(amplitude_bins, {'numeric'}, ...
    {'scalar', 'integer', 'positive'}, mfilename, 'amplitude_bins');

samples_per_symbol = double(sample_rate_hz) / ...
    (double(symbol_rate_hz) * (1 + double(clock_offset_ppm) * 1e-6));
if samples_per_symbol < 2
    error('compute_realtime_eye:SamplingRate', ...
        'The sample rate is too low for the selected symbol rate.');
end

sample_count = size(samples, 1);
normalized = zeros(sample_count, 4);
for channel = 1:4
    signal = double(samples(:, channel));
    signal = signal - median(signal);
    scale = max(abs(signal));
    if scale <= eps
        scale = 1;
    end
    normalized(:, channel) = signal / scale;
end

segment_count = floor((sample_count - 2 * samples_per_symbol) / ...
    samples_per_symbol);
if segment_count < 1
    error('compute_realtime_eye:RecordLength', ...
        'The record is too short for constellation sampling.');
end

phase_axis = linspace(0, 1, round(double(phase_bins)));
scan_count = min(4000, segment_count);
scan_indices = round(linspace(1, segment_count, scan_count));
scan_starts = 1 + (scan_indices(:) - 1) * samples_per_symbol;
eye_height = NaN(numel(phase_axis), 4);
q_factor = NaN(numel(phase_axis), 4);
for phase_index = 1:numel(phase_axis)
    positions = scan_starts + phase_axis(phase_index) * samples_per_symbol;
    for channel = 1:4
        values = interp1(1:sample_count, normalized(:, channel), ...
            positions, 'linear');
        [eye_height(phase_index, channel), ...
            q_factor(phase_index, channel)] = binary_eye_metrics(values);
    end
end

lane = repmat(struct('metrics', struct(), 'eyeHeightByPhase', [], ...
    'qFactorByPhase', []), 1, 4);
for channel = 1:4
    lane(channel).eyeHeightByPhase = eye_height(:, channel);
    lane(channel).qFactorByPhase = q_factor(:, channel);
end

polarization = repmat(struct('iSamples', [], 'qSamples', [], ...
    'samplePhaseUi', NaN, 'jointEyeHeight', NaN, 'sampleCount', 0, ...
    'channels', []), 1, 2);
channel_pairs = [1 2; 3 4];
constellation_count = min(6000, segment_count);
constellation_indices = round(linspace(1, segment_count, ...
    constellation_count));
constellation_starts = 1 + ...
    (constellation_indices(:) - 1) * samples_per_symbol;

for polarization_index = 1:2
    channels = channel_pairs(polarization_index, :);
    joint_height = min(eye_height(:, channels), [], 2);
    joint_height(~isfinite(joint_height)) = -Inf;
    [best_height, best_phase_index] = max(joint_height);
    if ~isfinite(best_height)
        best_phase_index = ceil(numel(phase_axis) / 2);
        best_height = NaN;
    end
    sample_phase = phase_axis(best_phase_index);
    positions = constellation_starts + sample_phase * samples_per_symbol;
    i_samples = interp1(1:sample_count, normalized(:, channels(1)), ...
        positions, 'linear');
    q_samples = interp1(1:sample_count, normalized(:, channels(2)), ...
        positions, 'linear');

    polarization(polarization_index).iSamples = i_samples(:);
    polarization(polarization_index).qSamples = q_samples(:);
    polarization(polarization_index).samplePhaseUi = sample_phase;
    polarization(polarization_index).jointEyeHeight = best_height;
    polarization(polarization_index).sampleCount = numel(i_samples);
    polarization(polarization_index).channels = channels;

    for component = 1:2
        channel = channels(component);
        if component == 1
            values = i_samples;
        else
            values = q_samples;
        end
        [height_value, q_value] = binary_eye_metrics(values);
        lane(channel).metrics = struct('channel', channel, ...
            'eyeHeightNormalized', height_value, 'qFactor', q_value, ...
            'samplesPerSymbol', samples_per_symbol, ...
            'sampleCount', sample_count, 'samplePhaseUi', sample_phase);
    end
end

eye = struct('sampleRateHz', sample_rate_hz, ...
    'symbolRateHz', symbol_rate_hz, 'clockOffsetPpm', clock_offset_ppm, ...
    'samplesPerSymbol', samples_per_symbol, 'phaseAxisUi', phase_axis, ...
    'lane', lane, 'polarization', polarization);
end

function [eye_height, q_factor] = binary_eye_metrics(values)
values = double(values(:));
values = values(isfinite(values));
if numel(values) < 4
    eye_height = NaN;
    q_factor = NaN;
    return;
end

split = median(values);
high = values(values >= split);
low = values(values < split);
if isempty(high) || isempty(low)
    eye_height = NaN;
    q_factor = NaN;
    return;
end

upper = median(high);
lower = median(low);
eye_height = max(0, upper - lower);
q_factor = eye_height / max(eps, std(high) + std(low));
end
