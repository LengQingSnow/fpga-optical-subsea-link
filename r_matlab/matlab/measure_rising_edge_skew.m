function report = measure_rising_edge_skew(capture)
%MEASURE_RISING_EDGE_SKEW Estimate four-channel skew from interpolated edges.

validateattributes(capture.channels, {'numeric'}, {'2d', 'ncols', 4});
validateattributes(capture.sampleRateHz, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});

signals = double(capture.channels);
sample_period_ps = 1e12 / double(capture.sampleRateHz);
edge_samples = cell(1, 4);
thresholds = zeros(1, 4);

for channel = 1:4
    signal = signals(:, channel);
    signal = conv(signal, [0.25; 0.5; 0.25], 'same');
    sorted = sort(signal);
    count = numel(sorted);
    low_level = median(sorted(1:max(1, floor(0.35 * count))));
    high_level = median(sorted(max(1, ceil(0.65 * count)):end));
    thresholds(channel) = 0.5 * (low_level + high_level);

    before = signal(1:end - 1);
    after = signal(2:end);
    indices = find(before <= thresholds(channel) & after > thresholds(channel));
    slopes = after(indices) - before(indices);
    valid = slopes > 0.05 * max(eps, high_level - low_level);
    indices = indices(valid);
    slopes = slopes(valid);
    fractions = (thresholds(channel) - before(indices)) ./ slopes;
    edge_samples{channel} = double(indices - 1) + fractions;
end

reference_edges = edge_samples{1};
if numel(reference_edges) < 10
    error('measure_rising_edge_skew:TooFewEdges', ...
        'CH1 has only %d usable rising edges.', numel(reference_edges));
end
period_samples = median(diff(reference_edges));
if ~isfinite(period_samples) || period_samples <= 2
    error('measure_rising_edge_skew:InvalidPeriod', ...
        'Unable to estimate the square-wave period.');
end

relative_delay_ps = zeros(1, 4);
jitter_ps = zeros(1, 4);
matched_edges = zeros(1, 4);
matched_edges(1) = numel(reference_edges);

for channel = 2:4
    candidates = edge_samples{channel};
    offsets = zeros(numel(reference_edges), 1);
    used = false(numel(reference_edges), 1);
    for edge_index = 1:numel(reference_edges)
        [distance, candidate_index] = min(abs(candidates - reference_edges(edge_index)));
        if ~isempty(distance) && distance < 0.4 * period_samples
            offsets(edge_index) = candidates(candidate_index) - reference_edges(edge_index);
            used(edge_index) = true;
        end
    end
    offsets = offsets(used);
    if numel(offsets) < 10
        error('measure_rising_edge_skew:TooFewMatches', ...
            'CH%d has only %d matched rising edges.', channel, numel(offsets));
    end
    center = median(offsets);
    deviation = abs(offsets - center);
    mad_value = median(deviation);
    if mad_value > 0
        offsets = offsets(deviation <= 6 * mad_value);
    end
    relative_delay_ps(channel) = median(offsets) * sample_period_ps;
    jitter_ps(channel) = 1.4826 * median(abs(offsets - median(offsets))) * ...
        sample_period_ps;
    matched_edges(channel) = numel(offsets);
end

report = struct('sampleRateHz', double(capture.sampleRateHz), ...
    'samplePeriodPs', sample_period_ps, ...
    'periodSamples', period_samples, ...
    'frequencyHz', double(capture.sampleRateHz) / period_samples, ...
    'thresholdVolts', thresholds, ...
    'relativeDelayPs', relative_delay_ps, ...
    'robustJitterPs', jitter_ps, ...
    'matchedEdges', matched_edges);

fprintf('Rising-edge frequency %.9g Hz, sample interval %.3f ps.\n', ...
    report.frequencyHz, report.samplePeriodPs);
for channel = 1:4
    fprintf('CH%d: delay %+0.3f ps, robust jitter %.3f ps, edges %d.\n', ...
        channel, report.relativeDelayPs(channel), ...
        report.robustJitterPs(channel), report.matchedEdges(channel));
end
end
