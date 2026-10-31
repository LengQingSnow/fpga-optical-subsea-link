function [symbols, diagnostics] = optical_apply_third_page_training( ...
        capture, cache_file, symbol_rate)
%OPTICAL_APPLY_THIRD_PAGE_TRAINING Reuse valid page-3 reference training.
% This helper is used only by the fourth optical-decode page.

symbols = zeros(0, 2);
diagnostics = struct('used', false, 'reason', 'cache unavailable');
if nargin < 3 || isempty(symbol_rate)
    symbol_rate = 4e9;
end
if ~exist(cache_file, 'file')
    return;
end
loaded = load(cache_file, 'training');
if ~isfield(loaded, 'training')
    diagnostics.reason = 'cache has no training structure';
    return;
end
training = loaded.training;
required = {'weights', 'sampleOffset', 'frequencyOffsetHz', ...
    'sampleRateHz', 'symbolRateHz', 'ber'};
for index = 1:numel(required)
    if ~isfield(training, required{index})
        diagnostics.reason = ['cache missing ' required{index}];
        return;
    end
end
if ~isequal(size(training.weights), [5 4]) || ...
        ~isfinite(training.ber) || training.ber > 0.05
    diagnostics.reason = 'cached page-3 training is not valid';
    return;
end
sample_rate = double(capture.sampleRateHz);
samples_per_symbol = round(sample_rate / symbol_rate);
if abs(sample_rate / symbol_rate - samples_per_symbol) > 0.05 || ...
        abs(double(training.symbolRateHz) - symbol_rate) > 1
    diagnostics.reason = 'cached rate is incompatible';
    return;
end
waveform = double(capture.channels);
waveform = bsxfun(@minus, waveform, mean(waveform, 1));
input = [waveform(:, 1) + 1i * waveform(:, 2), ...
    waveform(:, 3) + 1i * waveform(:, 4)];
input = bsxfun(@rdivide, input, sqrt(mean(abs(input) .^ 2, 1) + eps));
sample_index = (0:size(input, 1) - 1).';
input = bsxfun(@times, input, exp(-1i * 2 * pi * ...
    double(training.frequencyOffsetHz) * sample_index / sample_rate));
phase = max(1, min(samples_per_symbol, round(training.sampleOffset)));
received = input(phase:samples_per_symbol:end, :);
real_input = [real(received(:, 1)), imag(received(:, 1)), ...
    real(received(:, 2)), imag(received(:, 2))];
real_input = bsxfun(@minus, real_input, mean(real_input, 1));
real_input = bsxfun(@rdivide, real_input, std(real_input, 0, 1) + eps);
predictions = [real_input ones(size(real_input, 1), 1)] * training.weights;
symbols = [predictions(:, 1) + 1i * predictions(:, 2), ...
    predictions(:, 3) + 1i * predictions(:, 4)] / sqrt(2);
diagnostics.used = true;
diagnostics.reason = '';
diagnostics.trainingBer = training.ber;
diagnostics.sampleOffset = phase;
diagnostics.frequencyOffsetHz = training.frequencyOffsetHz;
end
