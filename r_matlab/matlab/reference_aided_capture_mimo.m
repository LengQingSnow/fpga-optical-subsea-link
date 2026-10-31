function result = reference_aided_capture_mimo(capture, reference, options)
%REFERENCE_AIDED_CAPTURE_MIMO Recover four real dimensions with causal RLS.

if nargin < 3 || isempty(options)
    options = struct();
end
if ~isstruct(capture) || ~isfield(capture, 'channels') || ...
        ~isfield(capture, 'sampleRateHz') || size(capture.channels, 2) ~= 4
    error('reference_aided_capture_mimo:Capture', ...
        'A four-channel scope capture is required.');
end
if ~isstruct(reference) || ~isfield(reference, 'laneBits') || ...
        size(reference.laneBits, 2) ~= 4
    error('reference_aided_capture_mimo:Reference', ...
        'A four-lane RF47 replay reference is required.');
end

symbol_rate = get_option(options, 'symbolRateHz', 4e9);
sample_rate = double(capture.sampleRateHz);
samples_per_symbol = round(sample_rate / symbol_rate);
if abs(sample_rate / symbol_rate - samples_per_symbol) > 0.05
    error('reference_aided_capture_mimo:SampleRate', ...
        'The scope sample rate is not an integer number of samples/symbol.');
end
waveform = double(capture.channels);
waveform = bsxfun(@minus, waveform, mean(waveform, 1));
complex_input = [waveform(:, 1) + 1i * waveform(:, 2), ...
    waveform(:, 3) + 1i * waveform(:, 4)];
complex_input = bsxfun(@rdivide, complex_input, ...
    sqrt(mean(abs(complex_input) .^ 2, 1) + eps));

probe_stride = max(1, floor(samples_per_symbol / 2));
coarse_frequency = estimate_qpsk_frequency_fft( ...
    complex_input(1:probe_stride:end, :), sample_rate / probe_stride);
period = size(reference.laneBits, 1);
[frequency, residual_frequency] = refine_frequency_from_period( ...
    complex_input(1:samples_per_symbol:end, :), period, ...
    symbol_rate, coarse_frequency);
sample_index = (0:size(complex_input, 1) - 1).';
complex_input = bsxfun(@times, complex_input, exp(-1i * 2 * pi * ...
    frequency * sample_index / sample_rate));

reference_real = 2 * double(logical(reference.laneBits)) - 1;
search_periods = round(get_option(options, 'searchPeriods', 4));
best_error = inf;
best_phase = 1;
best_shift = 0;
for phase = 1:samples_per_symbol
    received = complex_input(phase:samples_per_symbol:end, :);
    received = received(1:min(search_periods * period, ...
        size(received, 1)), :);
    received_real = complex_to_real(received);
    design = [received_real, ones(size(received_real, 1), 1)];
    for shift = 0:period - 1
        desired = reference_real(mod((0:size(received_real, 1) - 1)' + ...
            shift, period) + 1, :);
        weights = design \ desired;
        residual = design * weights - desired;
        error_value = mean(residual(:) .^ 2);
        if error_value < best_error
            best_error = error_value;
            best_phase = phase;
            best_shift = shift;
        end
    end
end

received = complex_input(best_phase:samples_per_symbol:end, :);
received_real = complex_to_real(received);
received_real = bsxfun(@minus, received_real, mean(received_real, 1));
received_real = bsxfun(@rdivide, received_real, ...
    std(received_real, 0, 1) + eps);
count = size(received_real, 1);
desired = reference_real(mod((0:count - 1)' + best_shift, ...
    period) + 1, :);

block_symbols = round(get_option(options, 'blockSymbols', 128));
block_symbols = max(16, block_symbols);
predictions = zeros(0, 4);
desired_test = zeros(0, 4);
weights = zeros(5, 4);
block_count = 0;
for first = 1:block_symbols:count
    last = min(count, first + block_symbols - 1);
    local = first:last;
    training_count = floor(numel(local) / 2);
    if training_count < 8 || numel(local) - training_count < 1
        continue;
    end
    training = local(1:training_count);
    testing = local(training_count + 1:end);
    design_training = [received_real(training, :), ...
        ones(numel(training), 1)];
    weights = design_training \ desired(training, :);
    design_testing = [received_real(testing, :), ...
        ones(numel(testing), 1)];
    predictions = [predictions; design_testing * weights]; %#ok<AGROW>
    desired_test = [desired_test; desired(testing, :)]; %#ok<AGROW>
    block_count = block_count + 1;
end
if isempty(predictions)
    error('reference_aided_capture_mimo:Training', ...
        'The capture is too short for frozen-block evaluation.');
end
predictions = normalize_binary_components(predictions);
desired = desired_test;
symbols = [predictions(:, 1) + 1i * predictions(:, 2), ...
    predictions(:, 3) + 1i * predictions(:, 4)] / sqrt(2);
desired_symbols = [desired(:, 1) + 1i * desired(:, 2), ...
    desired(:, 3) + 1i * desired(:, 4)] / sqrt(2);
errors = (predictions >= 0) ~= (desired >= 0);

result = struct();
result.equalizedSymbols = symbols;
result.desiredSymbols = desired_symbols;
result.sampleOffset = best_phase;
result.referenceShift = best_shift;
result.frequencyOffsetHz = frequency;
result.coarseFrequencyOffsetHz = coarse_frequency;
result.residualFrequencyOffsetHz = residual_frequency;
result.weights = weights;
result.trainingSymbols = floor(block_symbols / 2);
result.blockSymbols = block_symbols;
result.blockCount = block_count;
result.berByLane = mean(errors, 1);
result.ber = mean(errors(:));
result.evmRms = sqrt(mean(abs(symbols - desired_symbols) .^ 2, 1));
result.validity(1) = cma_constellation_metrics(symbols(:, 1));
result.validity(2) = cma_constellation_metrics(symbols(:, 2));
end

function real_values = complex_to_real(values)
real_values = [real(values(:, 1)), imag(values(:, 1)), ...
    real(values(:, 2)), imag(values(:, 2))];
end

function normalized = normalize_binary_components(values)
normalized = zeros(size(values));
for lane = 1:size(values, 2)
    lane_values = values(:, lane);
    negative = lane_values(lane_values < 0);
    positive = lane_values(lane_values >= 0);
    if isempty(negative) || isempty(positive)
        normalized(:, lane) = lane_values;
    else
        center = 0.5 * (mean(positive) + mean(negative));
        half_range = 0.5 * (mean(positive) - mean(negative));
        normalized(:, lane) = (lane_values - center) / max(eps, half_range);
    end
end
end

function [frequency_hz, residue_hz] = refine_frequency_from_period( ...
        samples, period, symbol_rate, coarse_frequency_hz)
first = samples(1:end - period, :);
second = samples(1 + period:end, :);
products = conj(first) .* second;
residue_hz = angle(sum(products(:))) * symbol_rate / (2 * pi * period);
ambiguity_hz = symbol_rate / period;
frequency_hz = residue_hz + round((coarse_frequency_hz - residue_hz) / ...
    ambiguity_hz) * ambiguity_hz;
end

function frequency_hz = estimate_qpsk_frequency_fft(input, sample_rate)
count = size(input, 1);
fft_count = 2 ^ nextpow2(min(count, 262144));
values = input(1:min(count, fft_count), :);
window = 0.5 - 0.5 * cos(2 * pi * (0:size(values, 1) - 1).' / ...
    max(1, size(values, 1) - 1));
spectrum = zeros(fft_count, 1);
for polarization = 1:2
    spectrum = spectrum + abs(fftshift(fft( ...
        values(:, polarization) .^ 4 .* window, fft_count))) .^ 2;
end
frequency_axis = ((0:fft_count - 1).' - floor(fft_count / 2)) * ...
    (sample_rate / fft_count);
spectrum(abs(frequency_axis) < 4e6) = 0;
[~, peak_index] = max(spectrum);
frequency_hz = frequency_axis(peak_index) / 4;
end

function value = get_option(options, name, default_value)
if isfield(options, name) && ~isempty(options.(name))
    value = options.(name);
else
    value = default_value;
end
end
