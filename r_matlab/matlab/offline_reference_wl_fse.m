function result = offline_reference_wl_fse(capture, reference, probe, options)
%OFFLINE_REFERENCE_WL_FSE Causal 2-Sa/s widely-linear 4-by-2 equalizer.
%   The four real oscilloscope lanes are used jointly.  A real 4-by-4 FIR
%   mapping is equivalent to a complex widely-linear MIMO filter because it
%   can independently combine each complex input and its conjugate.
%
%   Equalizer coefficients are fitted only with symbols preceding the
%   reported test symbols.  Consequently, the returned BER is a held-out
%   prediction result rather than an in-sample training error.

if nargin < 4 || isempty(options)
    options = struct();
end
validateattributes(capture.channels, {'numeric'}, {'2d', 'nonempty'}, ...
    mfilename, 'capture.channels');
if size(capture.channels, 2) ~= 4
    error('offline_reference_wl_fse:Channels', ...
        'Four real oscilloscope channels are required.');
end
if ~isstruct(reference) || ~isfield(reference, 'laneBits') || ...
        size(reference.laneBits, 2) ~= 4
    error('offline_reference_wl_fse:Reference', ...
        'reference.laneBits must contain four lanes.');
end

symbol_rate = get_option(options, 'symbolRateHz', 4e9);
output_sps = round(get_option(options, 'outputSamplesPerSymbol', 2));
tap_count = round(get_option(options, 'tapCount', 11));
train_symbols = round(get_option(options, 'trainSymbols', 4096));
output_symbols = round(get_option(options, 'outputSymbols', 256));
ridge = get_option(options, 'ridge', 1e-2);
causal = logical(get_option(options, 'causal', true));
fractional_sample_offset = get_option(options, ...
    'fractionalSampleOffset', 0);
channel_skew_samples = double(get_option(options, ...
    'channelSkewSamples', zeros(1, 4)));
if numel(channel_skew_samples) ~= 4 || any(~isfinite(channel_skew_samples))
    error('offline_reference_wl_fse:ChannelSkew', ...
        'channelSkewSamples must contain four finite values.');
end
channel_skew_samples = reshape(channel_skew_samples, 1, 4);
pre_affine = get_option(options, 'preAffine', []);
if ~isempty(pre_affine)
    pre_affine = double(pre_affine);
    if ~isequal(size(pre_affine), [5, 4]) || any(~isfinite(pre_affine(:)))
        error('offline_reference_wl_fse:PreAffine', ...
            'preAffine must be a finite 5-by-4 matrix.');
    end
end
if output_sps ~= 2
    error('offline_reference_wl_fse:SamplesPerSymbol', ...
        'This diagnostic implementation requires 2 samples/symbol.');
end
if tap_count < 1 || mod(tap_count, 2) == 0
    error('offline_reference_wl_fse:Taps', ...
        'tapCount must be a positive odd integer.');
end

sample_rate = double(capture.sampleRateHz);
raw_samples_per_symbol = sample_rate / symbol_rate;
if raw_samples_per_symbol < 2
    error('offline_reference_wl_fse:SampleRate', ...
        'The input sample rate must be at least 2 samples/symbol.');
end

waveform = double(capture.channels);
waveform = bsxfun(@minus, waveform, mean(waveform, 1));
complex_input = [waveform(:, 1) + 1i * waveform(:, 2), ...
    waveform(:, 3) + 1i * waveform(:, 4)];
complex_input = bsxfun(@rdivide, complex_input, ...
    sqrt(mean(abs(complex_input) .^ 2, 1) + eps));
sample_index = (0:size(complex_input, 1) - 1).';
cfo_rotation = exp(-1i * 2 * pi * double(probe.frequencyOffsetHz) * ...
    sample_index / sample_rate);
complex_input = bsxfun(@times, complex_input, cfo_rotation);
rotated_real = [real(complex_input(:, 1)), imag(complex_input(:, 1)), ...
    real(complex_input(:, 2)), imag(complex_input(:, 2))];

half_symbol_step = raw_samples_per_symbol / 2;
first_position = double(probe.phase) + fractional_sample_offset;
last_position = size(complex_input, 1);
two_sps_count = floor((last_position - first_position) / ...
    half_symbol_step) + 1;
if two_sps_count < 4 * tap_count
    error('offline_reference_wl_fse:ShortCapture', ...
        'The capture is too short for the requested FSE.');
end
positions = first_position + (0:two_sps_count - 1).' * ...
    half_symbol_step;
source_positions = (1:size(rotated_real, 1)).';
two_sps = zeros(two_sps_count, 4);
for lane = 1:4
    two_sps(:, lane) = interp1(source_positions, rotated_real(:, lane), ...
        positions + channel_skew_samples(lane), 'linear');
end

features = two_sps;
features = bsxfun(@minus, features, mean(features, 1));
features = bsxfun(@rdivide, features, std(features, 0, 1) + eps);
if ~isempty(pre_affine)
    features = [features, ones(size(features, 1), 1)] * pre_affine;
end

half_taps = (tap_count - 1) / 2;
symbol_count = floor((two_sps_count - 1) / 2) + 1;
symbol_centers = 1 + 2 * (0:symbol_count - 1).';
valid_symbols = find(symbol_centers - half_taps >= 1 & ...
    symbol_centers + half_taps <= two_sps_count);
if numel(valid_symbols) <= train_symbols + output_symbols
    error('offline_reference_wl_fse:TrainingLength', ...
        'The capture does not contain enough training and test symbols.');
end

reference_real = 2 * double(logical(reference.laneBits)) - 1;
period = size(reference_real, 1);
desired = reference_real(mod((0:symbol_count - 1).' + ...
    double(probe.shift), period) + 1, :);

first_valid = valid_symbols(1);
last_valid = valid_symbols(end);
first_test = first_valid + train_symbols;
prediction_cells = cell(ceil((last_valid - first_test + 1) / ...
    output_symbols), 1);
target_cells = cell(size(prediction_cells));
index_cells = cell(size(prediction_cells));
cell_index = 0;
for test_start = first_test:output_symbols:last_valid
    test_indices = test_start:min(last_valid, ...
        test_start + output_symbols - 1);
    if causal
        train_start = max(first_valid, test_start - train_symbols);
        train_indices = train_start:test_start - 1;
    else
        test_center = round(mean(test_indices));
        train_start = max(first_valid, ...
            test_center - floor(train_symbols / 2));
        train_end = min(last_valid, ...
            train_start + train_symbols - 1);
        train_indices = train_start:train_end;
        train_indices = train_indices(~ismember(train_indices, test_indices));
    end
    if numel(train_indices) < 4 * tap_count + 8 || ...
            isempty(test_indices)
        continue;
    end
    design_train = make_design(features, symbol_centers, ...
        train_indices, tap_count);
    design_test = make_design(features, symbol_centers, ...
        test_indices, tap_count);
    identity = eye(size(design_train, 2));
    identity(end, end) = 0;
    coefficients = (design_train' * design_train + ridge * identity) \ ...
        (design_train' * desired(train_indices, :));
    cell_index = cell_index + 1;
    prediction_cells{cell_index} = design_test * coefficients;
    target_cells{cell_index} = desired(test_indices, :);
    index_cells{cell_index} = test_indices(:);
end
if cell_index == 0
    error('offline_reference_wl_fse:NoTestSymbols', ...
        'No held-out test symbols were produced.');
end
predictions = vertcat(prediction_cells{1:cell_index});
targets = vertcat(target_cells{1:cell_index});
symbol_indices = vertcat(index_cells{1:cell_index});

errors = (predictions >= 0) ~= (targets >= 0);
equalized = [predictions(:, 1) + 1i * predictions(:, 2), ...
    predictions(:, 3) + 1i * predictions(:, 4)] / sqrt(2);
target_symbols = [targets(:, 1) + 1i * targets(:, 2), ...
    targets(:, 3) + 1i * targets(:, 4)] / sqrt(2);

result = struct();
result.ber = mean(errors(:));
result.berByLane = mean(errors, 1);
result.evmRms = sqrt(mean(abs(equalized - target_symbols) .^ 2, 1));
result.equalizedSymbols = equalized;
result.desiredSymbols = target_symbols;
result.equalizedReal = predictions;
result.targetReal = targets;
result.symbolIndices = symbol_indices;
result.tapCount = tap_count;
result.trainSymbols = train_symbols;
result.outputSymbols = output_symbols;
result.ridge = ridge;
result.fractionalSampleOffset = fractional_sample_offset;
result.comparedSymbols = size(predictions, 1);
result.frequencyOffsetHz = double(probe.frequencyOffsetHz);
result.sampleOffset = double(probe.phase);
result.referenceShift = double(probe.shift);
result.channelSkewSamples = channel_skew_samples;
result.preAffine = pre_affine;
end

function design = make_design(features, symbol_centers, indices, tap_count)
half_taps = (tap_count - 1) / 2;
indices = indices(:);
design = zeros(numel(indices), 4 * tap_count + 1);
column = 1;
for delay = -half_taps:half_taps
    rows = symbol_centers(indices) + delay;
    design(:, column:column + 3) = features(rows, :);
    column = column + 4;
end
design(:, end) = 1;
end

function value = get_option(options, name, default_value)
if isfield(options, name) && ~isempty(options.(name))
    value = options.(name);
else
    value = default_value;
end
end
