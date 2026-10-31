function [compensated, diagnostics, probe] = ...
        auto_reference_cd_compensate_capture(capture, reference, options)
%AUTO_REFERENCE_CD_COMPENSATE_CAPTURE Reference-aided automatic CD search.
%   This page-5-only CD estimator selects the 330 km dispersion from the
%   captured waveform by minimizing a short reference-aided residual.  It
%   does not fix the result to the previous -7250 ps/nm value.

if nargin < 3 || isempty(options)
    options = struct();
end
if ~isstruct(capture) || ~isfield(capture, 'channels') || ...
        ~isfield(capture, 'sampleRateHz')
    error('auto_reference_cd_compensate_capture:Capture', ...
        'Capture must contain channels and sampleRateHz.');
end
if size(capture.channels, 2) ~= 4
    error('auto_reference_cd_compensate_capture:Channels', ...
        'Expected four channels ordered XI, XQ, YI, YQ.');
end
if ~isstruct(reference) || ~isfield(reference, 'laneBits') || ...
        size(reference.laneBits, 2) ~= 4
    error('auto_reference_cd_compensate_capture:Reference', ...
        'A four-lane RF47 reference is required.');
end

symbol_rate = get_option(options, 'symbolRateHz', 4e9);
sample_rate = double(capture.sampleRateHz);
decimation = max(1, round(sample_rate / (2 * symbol_rate)));
reduced_rate = sample_rate / decimation;
if abs(reduced_rate / symbol_rate - 2) > 0.05
    error('auto_reference_cd_compensate_capture:Rate', ...
        'Sample rate cannot be reduced to two samples/symbol.');
end

waveform = double(capture.channels);
if any(~isfinite(waveform(:)))
    error('auto_reference_cd_compensate_capture:Finite', ...
        'Capture contains non-finite samples.');
end
waveform = bsxfun(@minus, waveform, mean(waveform, 1));
input = [waveform(:, 1) + 1i * waveform(:, 2), ...
    waveform(:, 3) + 1i * waveform(:, 4)];
input = bsxfun(@rdivide, input, sqrt(mean(abs(input) .^ 2, 1) + eps));
% Perform the CD scan at the original ADC rate.  Scanning after decimation
% can alias the quadratic CD phase and makes the 330 km estimate unstable.
% The probe is still evaluated at two samples/symbol after each candidate.
scan_symbols = round(get_option(options, 'scanPointCount', 32768));
scan_count = min(size(input, 1), max(4096, scan_symbols * decimation));
fft_count = 2 ^ floor(log2(max(4096, scan_count)));
fft_count = min(fft_count, size(input, 1));
if fft_count < 4096
    error('auto_reference_cd_compensate_capture:ShortCapture', ...
        'Too few samples for automatic CD identification.');
end
segment = input(1:fft_count, :);
segment_spectrum = fftshift(fft(segment, [], 1), 1);
frequency = ((0:fft_count - 1).' - floor(fft_count / 2)) * ...
    (sample_rate / fft_count);
segment_spectrum = bsxfun(@times, segment_spectrum, spectral_window( ...
    frequency, options));

coarse_grid = double(get_option(options, 'coarseGridPsNm', ...
    -9500:500:-5500));
refine_step = double(get_option(options, 'refineStepPsNm', 100));
refine_half_range = double(get_option(options, ...
    'refineHalfRangePsNm', 500));
[coarse_best, coarse_scores, coarse_probes] = evaluate_grid( ...
    coarse_grid, segment_spectrum, frequency, segment, reduced_rate, ...
    symbol_rate, reference, options, decimation);
refine_grid = coarse_best + (-refine_half_range:refine_step: ...
    refine_half_range);
[best_dispersion, refine_scores, refine_probes] = evaluate_grid( ...
    refine_grid, segment_spectrum, frequency, segment, reduced_rate, ...
    symbol_rate, reference, options, decimation);
[~, selected] = min(refine_scores);
probe = refine_probes{selected};

full_spectrum = fftshift(fft(input, [], 1), 1);
full_frequency = ((0:size(input, 1) - 1).' - ...
    floor(size(input, 1) / 2)) * ...
    (sample_rate / size(input, 1));
phase = dispersion_phase(full_frequency, best_dispersion, options);
phase = phase .* spectral_window(full_frequency, options);
corrected_full = ifft(ifftshift(bsxfun(@times, full_spectrum, phase), 1), [], 1);
corrected = corrected_full(1:decimation:end, :);

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
diagnostics.referenceProbeError = probe.error;
diagnostics.decimation = decimation;
diagnostics.inputSampleRateHz = sample_rate;
diagnostics.outputSampleRateHz = reduced_rate;
diagnostics.scanPointCount = fft_count;
diagnostics.fiberLengthKm = 330;
diagnostics.wavelengthNm = get_option(options, 'wavelengthNm', 1550);
diagnostics.searchSucceeded = isfinite(best_dispersion) && isfinite(probe.error);
end

function [best_value, scores, probes] = evaluate_grid(grid, spectrum, ...
        frequency, segment, reduced_rate, symbol_rate, reference, options, decimation)
scores = inf(size(grid));
probes = cell(size(grid));
for index = 1:numel(grid)
    phase = dispersion_phase(frequency, grid(index), options);
    phase = phase .* spectral_window(frequency, options);
    candidate_full = ifft(ifftshift(bsxfun(@times, spectrum, phase), 1), [], 1);
    candidate = candidate_full(1:decimation:end, :);
    candidate_capture = struct();
    candidate_capture.channels = single([real(candidate(:, 1)), ...
        imag(candidate(:, 1)), real(candidate(:, 2)), imag(candidate(:, 2))]);
    candidate_capture.sampleRateHz = reduced_rate;
    candidate_capture.pointCount = size(candidate_capture.channels, 1);
    candidate_probe = offline_fast_reference_probe(candidate_capture, ...
        reference, struct('symbolRateHz', symbol_rate, 'searchPeriods', 2));
    probes{index} = candidate_probe;
    scores(index) = candidate_probe.error;
end
[~, selected] = min(scores);
best_value = grid(selected);
end

function phase = dispersion_phase(frequency, dispersion_ps_nm, options)
wavelength = get_option(options, 'wavelengthNm', 1550) * 1e-9;
speed_of_light = 299792458;
beta2_length = -(dispersion_ps_nm * 1e-3) * wavelength ^ 2 / ...
    (2 * pi * speed_of_light);
angular_frequency = 2 * pi * frequency;
phase = exp(1i * 0.5 * beta2_length * angular_frequency .^ 2);
end

function window = spectral_window(frequency, options)
passband = get_option(options, 'passbandHz', 2.6e9);
stopband = get_option(options, 'stopbandHz', 3.4e9);
af = abs(frequency);
window = ones(size(af));
window(af >= stopband) = 0;
transition = af > passband & af < stopband;
window(transition) = 0.5 * (1 + cos(pi * ...
    (af(transition) - passband) / (stopband - passband)));
end

function value = get_option(options, name, default_value)
if isfield(options, name) && ~isempty(options.(name))
    value = options.(name);
else
    value = default_value;
end
end
