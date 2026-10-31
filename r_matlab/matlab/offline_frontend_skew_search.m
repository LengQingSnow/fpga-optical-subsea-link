function result = offline_frontend_skew_search(capture, reference, probe, options)
%OFFLINE_FRONTEND_SKEW_SEARCH Search static lane skew and affine correction.
%   This reference-aided calibration is used only by the offline 330-km
%   DSP experiments. It does not modify the GUI, FPGA, or hardware state.

if nargin < 4 || isempty(options)
    options = struct();
end
validateattributes(capture.channels, {'numeric'}, {'2d', 'nonempty'}, ...
    mfilename, 'capture.channels');
if size(capture.channels, 2) ~= 4
    error('offline_frontend_skew_search:Channels', ...
        'Four real oscilloscope channels are required.');
end
if ~isstruct(reference) || ~isfield(reference, 'laneBits') || ...
        size(reference.laneBits, 2) ~= 4
    error('offline_frontend_skew_search:Reference', ...
        'reference.laneBits must contain four lanes.');
end

symbol_rate = get_option(options, 'symbolRateHz', 4e9);
skew_grid = double(get_option(options, 'skewGridSamples', ...
    -0.4:0.1:0.4));
skew_grid = reshape(skew_grid, 1, []);
if isempty(skew_grid) || any(~isfinite(skew_grid))
    error('offline_frontend_skew_search:SkewGrid', ...
        'skewGridSamples must contain finite values.');
end
passes = max(1, round(get_option(options, 'passes', 1)));
train_symbols = max(32, round(get_option(options, 'trainSymbols', 1024)));
test_symbols = max(32, round(get_option(options, 'testSymbols', 1024)));
regularizer = get_option(options, 'ridge', 1e-3);

sample_rate = double(capture.sampleRateHz);
raw_samples_per_symbol = sample_rate / symbol_rate;
if raw_samples_per_symbol < 1
    error('offline_frontend_skew_search:SampleRate', ...
        'The input sample rate must be at least one sample/symbol.');
end

waveform = double(capture.channels);
waveform = bsxfun(@minus, waveform, mean(waveform, 1));
source_positions = (1:size(waveform, 1)).';
maximum_skew = max(abs(skew_grid));
first_position = max(1, double(probe.phase));
last_position = size(waveform, 1) - maximum_skew;
sample_count = floor((last_position - first_position) / ...
    raw_samples_per_symbol) + 1;
if sample_count < train_symbols + test_symbols + 16
    error('offline_frontend_skew_search:ShortCapture', ...
        'The capture is too short for the calibration split.');
end
positions = first_position + (0:sample_count - 1).' * raw_samples_per_symbol;

reference_real = 2 * double(logical(reference.laneBits)) - 1;
period = size(reference_real, 1);
desired = reference_real(mod((0:sample_count - 1).' + ...
    double(probe.shift), period) + 1, :);
train_indices = (1:train_symbols).';
test_end = min(sample_count, train_symbols + test_symbols);
test_indices = (train_symbols + 1:test_end).';
if numel(test_indices) < 32
    error('offline_frontend_skew_search:ShortTest', ...
        'The held-out calibration test is too short.');
end

lane_samples = interpolate_lanes(waveform, source_positions, positions, ...
    zeros(1, 4));
initial_affine = fit_affine(lane_samples(train_indices, :), ...
    desired(train_indices, :), regularizer);
before = score_candidate(lane_samples, desired, test_indices, ...
    initial_affine);

selected_skew = zeros(1, 4);
current_score = before.total;
for pass_index = 1:passes %#ok<NASGU>
    for lane = 1:4
        best_lane_score = current_score;
        best_lane_samples = lane_samples(:, lane);
        best_lane_skew = selected_skew(lane);
        for grid_index = 1:numel(skew_grid)
            candidate_skew = selected_skew;
            candidate_skew(lane) = skew_grid(grid_index);
            candidate_lane = interpolate_one(waveform(:, lane), ...
                source_positions, positions + candidate_skew(lane));
            candidate_lane = normalize_one(candidate_lane);
            candidate_samples = lane_samples;
            candidate_samples(:, lane) = candidate_lane;
            candidate_affine = fit_affine( ...
                candidate_samples(train_indices, :), ...
                desired(train_indices, :), regularizer);
            candidate_score = score_candidate(candidate_samples, ...
                desired, test_indices, candidate_affine);
            if candidate_score.total < best_lane_score
                best_lane_score = candidate_score.total;
                best_lane_samples = candidate_lane;
                best_lane_skew = candidate_skew(lane);
            end
        end
        lane_samples(:, lane) = best_lane_samples;
        selected_skew(lane) = best_lane_skew;
        current_score = best_lane_score;
    end
end

current_affine = fit_affine(lane_samples(train_indices, :), ...
    desired(train_indices, :), regularizer);
after = score_candidate(lane_samples, desired, test_indices, ...
    current_affine);

result = struct();
result.channelSkewSamples = selected_skew;
result.preAffine = current_affine;
result.before = before;
result.after = after;
result.rawSamplesPerSymbol = raw_samples_per_symbol;
result.trainSymbols = numel(train_indices);
result.testSymbols = numel(test_indices);
result.skewGridSamples = skew_grid;
result.passes = passes;
end

function samples = interpolate_lanes(waveform, source_positions, ...
        positions, skew)
samples = zeros(numel(positions), 4);
for lane = 1:4
    samples(:, lane) = interpolate_one(waveform(:, lane), ...
        source_positions, positions + skew(lane));
end
samples = normalize_lanes(samples);
end

function values = interpolate_one(waveform, source_positions, positions)
values = interp1(source_positions, waveform, positions, 'linear');
if any(~isfinite(values))
    error('offline_frontend_skew_search:Interpolation', ...
        'Candidate skew produced samples outside the capture.');
end
values = values(:);
end

function values = normalize_one(values)
values = values - mean(values);
values = values / (std(values, 0, 1) + eps);
end

function samples = normalize_lanes(samples)
for lane = 1:size(samples, 2)
    samples(:, lane) = normalize_one(samples(:, lane));
end
end

function affine = fit_affine(samples, desired, regularizer)
design = [samples, ones(size(samples, 1), 1)];
identity = eye(size(design, 2));
identity(end, end) = 0;
affine = (design' * design + regularizer * identity) \ ...
    (design' * desired);
end

function score = score_candidate(samples, desired, indices, affine)
design = [samples(indices, :), ones(numel(indices), 1)];
predicted = design * affine;
target = desired(indices, :);
errors = (predicted >= 0) ~= (target >= 0);
score = struct();
score.ber = mean(errors(:));
score.berByLane = mean(errors, 1);
score.mse = mean((predicted - target) .^ 2, 1);
score.total = score.ber + 0.02 * min(mean(score.mse), 4);
score.predicted = predicted;
score.target = target;
end

function value = get_option(options, name, default_value)
if isfield(options, name) && ~isempty(options.(name))
    value = options.(name);
else
    value = default_value;
end
end
