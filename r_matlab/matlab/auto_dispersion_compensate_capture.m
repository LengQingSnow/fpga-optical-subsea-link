function [compensated, diagnostics] = auto_dispersion_compensate_capture( ...
        capture, options)
%AUTO_DISPERSION_COMPENSATE_CAPTURE Blind chromatic-dispersion search.
% The input is [XI XQ YI YQ] at a rate compatible with an integer reduction
% to two samples/symbol.  The returned capture is reduced to two samples per
% symbol and contains the frequency-domain inverse-dispersion result.

if nargin < 2 || isempty(options)
    options = struct();
end
if ~isstruct(capture) || ~isfield(capture, 'channels') || ...
        ~isfield(capture, 'sampleRateHz')
    error('auto_dispersion_compensate_capture:Capture', ...
        'Capture must contain channels and sampleRateHz.');
end
if size(capture.channels, 2) ~= 4
    error('auto_dispersion_compensate_capture:Channels', ...
        'Expected four channels ordered XI, XQ, YI, YQ.');
end

symbol_rate = get_option(options, 'symbolRateHz', 4e9);
sample_rate = double(capture.sampleRateHz);
decimation = max(1, round(sample_rate / (2 * symbol_rate)));
reduced_rate = sample_rate / decimation;
if abs(reduced_rate / symbol_rate - 2) > 0.05
    error('auto_dispersion_compensate_capture:Rate', ...
        'Sample rate %.12g cannot be reduced to two samples/symbol.', ...
        sample_rate);
end

waveform = double(capture.channels);
if any(~isfinite(waveform(:)))
    error('auto_dispersion_compensate_capture:Finite', ...
        'Capture contains non-finite samples.');
end
waveform = bsxfun(@minus, waveform, mean(waveform, 1));
input = [waveform(:, 1) + 1i * waveform(:, 2), ...
    waveform(:, 3) + 1i * waveform(:, 4)];
input = bsxfun(@rdivide, input, sqrt(mean(abs(input) .^ 2, 1) + eps));

% A fixed phase is sufficient here because the downstream CMA still searches
% the two-samples/symbol timing phase.  This keeps the 10M-point path small.
reduced = input(1:decimation:end, :);
scan_count = min(size(reduced, 1), round(get_option(options, ...
    'scanPointCount', 65536)));
fft_count = 2 ^ floor(log2(max(4096, scan_count)));
fft_count = min(fft_count, size(reduced, 1));
if fft_count < 4096
    error('auto_dispersion_compensate_capture:ShortCapture', ...
        'Too few samples for automatic dispersion identification.');
end

coarse_grid = get_option(options, 'coarseGridPsNm', -9000:3000:9000);
coarse_grid = unique(double(coarse_grid(:).'));
segment = reduced(1:fft_count, :);
segment_spectrum = fftshift(fft(segment, [], 1), 1);
frequency = ((0:fft_count - 1).' - floor(fft_count / 2)) * ...
    (reduced_rate / fft_count);

[coarse_best, coarse_scores] = scan_grid(segment_spectrum, frequency, ...
    coarse_grid, options);
refine_step = get_option(options, 'refineStepPsNm', 500);
refine_half_range = get_option(options, 'refineHalfRangePsNm', 1500);
refine_grid = coarse_best + (-refine_half_range:refine_step:refine_half_range);
refine_grid = unique(refine_grid);
[best_dispersion, refine_scores] = scan_grid(segment_spectrum, frequency, ...
    refine_grid, options);

full_spectrum = fftshift(fft(reduced, [], 1), 1);
full_frequency = ((0:size(reduced, 1) - 1).' - ...
    floor(size(reduced, 1) / 2)) * (reduced_rate / size(reduced, 1));
phase = dispersion_phase(full_frequency, best_dispersion, options);
corrected = ifft(ifftshift(bsxfun(@times, full_spectrum, phase), 1), [], 1);

compensated = capture;
compensated.channels = single([real(corrected(:, 1)), imag(corrected(:, 1)), ...
    real(corrected(:, 2)), imag(corrected(:, 2))]);
compensated.sampleRateHz = reduced_rate;
compensated.pointCount = size(compensated.channels, 1);
compensated.requestedPointCount = compensated.pointCount;
compensated.reportedPointCountByChannel = ...
    compensated.pointCount * ones(1, 4);

diagnostics = struct();
diagnostics.dispersionPsNm = best_dispersion;
diagnostics.coarseGridPsNm = coarse_grid;
diagnostics.coarseScores = coarse_scores;
diagnostics.refineGridPsNm = refine_grid;
diagnostics.refineScores = refine_scores;
diagnostics.decimation = decimation;
diagnostics.inputSampleRateHz = sample_rate;
diagnostics.outputSampleRateHz = reduced_rate;
diagnostics.scanPointCount = fft_count;
diagnostics.fiberLengthKm = get_option(options, 'fiberLengthKm', 330);
diagnostics.wavelengthNm = get_option(options, 'wavelengthNm', 1550);
diagnostics.searchSucceeded = isfinite(best_dispersion);
end

function [best_value, scores] = scan_grid(spectrum, frequency, ...
        grid, options)
scores = inf(size(grid));
for index = 1:numel(grid)
    phase = dispersion_phase(frequency, grid(index), options);
    candidate = ifft(ifftshift(bsxfun(@times, spectrum, phase), 1), [], 1);
    scores(index) = dispersion_quality(candidate);
end
[~, selected] = min(scores);
best_value = grid(selected);
end

function score = dispersion_quality(candidate)
candidate = bsxfun(@rdivide, candidate, ...
    sqrt(mean(abs(candidate) .^ 2, 1) + eps));
modulus_error = mean((abs(candidate) .^ 2 - 1) .^ 2, 1);
fourth_order = abs(mean(candidate .^ 4, 1)) ./ ...
    (mean(abs(candidate) .^ 4, 1) + eps);
score = mean(modulus_error) + 0.10 * mean(1 - fourth_order);
end

function phase = dispersion_phase(frequency, dispersion_ps_nm, options)
wavelength = get_option(options, 'wavelengthNm', 1550) * 1e-9;
speed_of_light = 299792458;
% beta2*L expressed directly from total dispersion in ps/nm.
beta2_length = -(dispersion_ps_nm * 1e-3) * wavelength ^ 2 / ...
    (2 * pi * speed_of_light);
angular_frequency = 2 * pi * frequency;
phase = exp(1i * 0.5 * beta2_length * angular_frequency .^ 2);
end

function value = get_option(options, name, default_value)
if isfield(options, name) && ~isempty(options.(name))
    value = options.(name);
else
    value = default_value;
end
end
