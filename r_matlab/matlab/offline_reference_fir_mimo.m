function result = offline_reference_fir_mimo(capture, reference, options)
%OFFLINE_REFERENCE_FIR_MIMO Offline supervised FIR MIMO for one capture.
if nargin < 3 || isempty(options)
    options = struct();
end
symbol_rate = get_option(options, 'symbolRateHz', 4e9);
block_symbols = round(get_option(options, 'blockSymbols', 384));
tap_count = round(get_option(options, 'tapCount', 5));
ridge = get_option(options, 'ridge', 1e-2);
if mod(tap_count, 2) == 0 || tap_count < 1
    error('offline_reference_fir_mimo:Taps', ...
        'tapCount must be a positive odd integer.');
end

% Use the existing reference-aided search only for CFO, timing phase and
% cyclic reference shift; the FIR is then trained independently below.
probe = reference_aided_capture_mimo(capture, reference, ...
    struct('symbolRateHz', symbol_rate, 'blockSymbols', block_symbols, ...
    'searchPeriods', get_option(options, 'searchPeriods', 8)));
sample_rate = double(capture.sampleRateHz);
samples_per_symbol = round(sample_rate / symbol_rate);
waveform = double(capture.channels);
waveform = bsxfun(@minus, waveform, mean(waveform, 1));
input = [waveform(:, 1) + 1i * waveform(:, 2), ...
    waveform(:, 3) + 1i * waveform(:, 4)];
input = bsxfun(@rdivide, input, sqrt(mean(abs(input) .^ 2, 1) + eps));
sample_index = (0:size(input, 1) - 1).';
input = bsxfun(@times, input, exp(-1i * 2 * pi * ...
    probe.frequencyOffsetHz * sample_index / sample_rate));
received = input(probe.sampleOffset:samples_per_symbol:end, :);
features = [real(received(:, 1)), imag(received(:, 1)), ...
    real(received(:, 2)), imag(received(:, 2))];
features = bsxfun(@minus, features, mean(features, 1));
features = bsxfun(@rdivide, features, std(features, 0, 1) + eps);
reference_real = 2 * double(logical(reference.laneBits)) - 1;
count = min(size(features, 1), numel(reference_real(:, 1)) * 64);
desired = reference_real(mod((0:count - 1).' + probe.referenceShift, ...
    size(reference_real, 1)) + 1, :);
features = features(1:count, :);

half = (tap_count - 1) / 2;
predictions = zeros(0, 4);
targets = zeros(0, 4);
training_rows = 0;
for first = 1:block_symbols:count - block_symbols + 1
    block = first:first + block_symbols - 1;
    train_count = floor(numel(block) / 2);
    train = block(half + 1:train_count - half);
    test = block(train_count + 1 + half:numel(block) - half);
    if numel(train) < 16 || isempty(test)
        continue;
    end
    design_train = make_design(features, train, tap_count);
    design_test = make_design(features, test, tap_count);
    weights = (design_train' * design_train + ridge * eye(size(design_train, 2))) \ ...
        (design_train' * desired(train, :));
    predictions = [predictions; design_test * weights]; %#ok<AGROW>
    targets = [targets; desired(test, :)]; %#ok<AGROW>
    training_rows = training_rows + numel(train);
end
if isempty(predictions)
    error('offline_reference_fir_mimo:ShortCapture', ...
        'No FIR test blocks were available.');
end
errors = (predictions >= 0) ~= (targets >= 0);
normalized = normalize_levels(predictions);
result = struct();
result.equalizedSymbols = [normalized(:, 1) + 1i * normalized(:, 2), ...
    normalized(:, 3) + 1i * normalized(:, 4)] / sqrt(2);
result.desiredSymbols = [targets(:, 1) + 1i * targets(:, 2), ...
    targets(:, 3) + 1i * targets(:, 4)] / sqrt(2);
result.berByLane = mean(errors, 1);
result.ber = mean(errors(:));
result.evmRms = sqrt(mean(abs(result.equalizedSymbols - ...
    result.desiredSymbols) .^ 2, 1));
result.tapCount = tap_count;
result.blockSymbols = block_symbols;
result.ridge = ridge;
result.trainingSymbols = training_rows;
result.sampleOffset = probe.sampleOffset;
result.referenceShift = probe.referenceShift;
result.frequencyOffsetHz = probe.frequencyOffsetHz;
end

function design = make_design(values, positions, tap_count)
half = (tap_count - 1) / 2;
design = zeros(numel(positions), 4 * tap_count + 1);
column = 1;
for delay = -half:half
    design(:, column:column + 3) = values(positions + delay, :);
    column = column + 4;
end
design(:, end) = 1;
end

function values = normalize_levels(values)
values = values;
for lane = 1:size(values, 2)
    negative = values(values(:, lane) < 0, lane);
    positive = values(values(:, lane) >= 0, lane);
    if ~isempty(negative) && ~isempty(positive)
        center = 0.5 * (mean(positive) + mean(negative));
        half_range = 0.5 * (mean(positive) - mean(negative));
        values(:, lane) = (values(:, lane) - center) / ...
            max(eps, half_range);
    end
end
end

function value = get_option(options, name, default_value)
if isfield(options, name) && ~isempty(options.(name))
    value = options.(name);
else
    value = default_value;
end
end
