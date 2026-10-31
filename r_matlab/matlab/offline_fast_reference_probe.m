function probe = offline_fast_reference_probe(capture, reference, options)
%OFFLINE_FAST_REFERENCE_PROBE Fast CFO/phase/period probe for page 5.
%   This reference-aided estimator avoids thousands of repeated MATLAB
%   backslash calls.  It is used only by the page-5 literature DSP helper;
%   the established page-3/page-4 estimators are unchanged.

if nargin < 3 || isempty(options)
    options = struct();
end
symbol_rate = get_option(options, 'symbolRateHz', 4e9);
sample_rate = double(capture.sampleRateHz);
sps = round(sample_rate / symbol_rate);
if sps < 1 || abs(sample_rate / symbol_rate - sps) > 0.05
    error('offline_fast_reference_probe:SampleRate', ...
        'The capture must have an integer samples-per-symbol ratio.');
end
if size(capture.channels, 2) ~= 4
    error('offline_fast_reference_probe:Channels', ...
        'Four real channels are required.');
end
if ~isstruct(reference) || ~isfield(reference, 'laneBits') || ...
        size(reference.laneBits, 2) ~= 4
    error('offline_fast_reference_probe:Reference', ...
        'A four-lane reference is required.');
end

wave = double(capture.channels);
wave = bsxfun(@minus, wave, mean(wave, 1));
input = [wave(:, 1) + 1i * wave(:, 2), ...
    wave(:, 3) + 1i * wave(:, 4)];
input = bsxfun(@rdivide, input, sqrt(mean(abs(input) .^ 2, 1) + eps));

fft_count = 2 ^ floor(log2(min(size(input, 1), 262144)));
fft_count = max(4096, fft_count);
fft_count = min(fft_count, size(input, 1));
values = input(1:fft_count, :);
window = 0.5 - 0.5 * cos(2 * pi * (0:fft_count - 1).' / ...
    max(1, fft_count - 1));
spectrum = zeros(fft_count, 1);
for polarization = 1:2
    spectrum = spectrum + abs(fftshift(fft(values(:, polarization) .^ 4 .* ...
        window, fft_count))) .^ 2;
end
frequency_axis = ((0:fft_count - 1).' - floor(fft_count / 2)) * ...
    (sample_rate / fft_count);
spectrum(abs(frequency_axis) < 4e6) = 0;
[~, peak] = max(spectrum);
coarse_frequency = frequency_axis(peak) / 4;

period = size(reference.laneBits, 1);
sampled = input(1:sps:end, :);
if size(sampled, 1) <= period + 2
    error('offline_fast_reference_probe:ShortCapture', ...
        'The capture is too short for a reference period.');
end
first = sampled(1:end - period, :);
second = sampled(1 + period:end, :);
products = conj(first) .* second;
residue = angle(sum(products(:))) * symbol_rate / ...
    (2 * pi * period);
ambiguity = symbol_rate / period;
frequency = residue + round((coarse_frequency - residue) / ambiguity) * ambiguity;

sample_index = (0:size(input, 1) - 1).';
rotated = bsxfun(@times, input, exp(-1i * 2 * pi * frequency * ...
    sample_index / sample_rate));
reference_real = 2 * double(logical(reference.laneBits)) - 1;
search_periods = round(get_option(options, 'searchPeriods', 2));
best_error = inf;
best_phase = 1;
best_shift = 0;
for phase = 1:sps
    received = rotated(phase:sps:end, :);
    count = min(size(received, 1), search_periods * period);
    received = received(1:count, :);
    received_real = [real(received(:, 1)), imag(received(:, 1)), ...
        real(received(:, 2)), imag(received(:, 2))];
    design = [received_real, ones(count, 1)];
    gram = design' * design + 1e-6 * eye(5);
    projector = gram \ design';
    for shift = 0:period - 1
        desired = reference_real(mod((0:count - 1).' + shift, ...
            period) + 1, :);
        coefficients = projector * desired;
        residual = design * coefficients - desired;
        error_value = mean(residual(:) .^ 2);
        if error_value < best_error
            best_error = error_value;
            best_phase = phase;
            best_shift = shift;
        end
    end
end

probe = struct();
probe.error = best_error;
probe.phase = best_phase;
probe.shift = best_shift;
probe.frequencyOffsetHz = frequency;
probe.coarseFrequencyOffsetHz = coarse_frequency;
probe.residualFrequencyOffsetHz = residue;
end

function value = get_option(options, name, default_value)
if isfield(options, name) && ~isempty(options.(name))
    value = options.(name);
else
    value = default_value;
end
end
