function compensated = offline_apply_dispersion(capture, dispersion_ps_nm, options)
%OFFLINE_APPLY_DISPERSION Apply a fixed total chromatic-dispersion inverse.

if nargin < 3 || isempty(options)
    options = struct();
end
symbol_rate = get_option(options, 'symbolRateHz', 4e9);
wavelength_nm = get_option(options, 'wavelengthNm', 1550);
sample_rate = double(capture.sampleRateHz);
decimation = max(1, round(sample_rate / (2 * symbol_rate)));
reduced_rate = sample_rate / decimation;
if abs(reduced_rate / symbol_rate - 2) > 0.05
    error('offline_apply_dispersion:SampleRate', ...
        'Input rate cannot be reduced to two samples per symbol.');
end

waveform = double(capture.channels);
waveform = bsxfun(@minus, waveform, mean(waveform, 1));
polarizations = [waveform(:, 1) + 1i * waveform(:, 2), ...
    waveform(:, 3) + 1i * waveform(:, 4)];
polarizations = bsxfun(@rdivide, polarizations, ...
    sqrt(mean(abs(polarizations) .^ 2, 1) + eps));
count = size(polarizations, 1);
frequency = ((0:count - 1).' - floor(count / 2)) * (sample_rate / count);
phase = dispersion_phase(frequency, dispersion_ps_nm, wavelength_nm);
spectrum = fftshift(fft(polarizations, [], 1), 1);

% Constrain the signal before the later 40-to-8 GSa/s reduction. Directly
% decimating the dispersed waveform aliases out-of-band energy into the
% coherent baseband and cannot be repaired by a subsequent CD filter.
passband_hz = get_option(options, 'passbandHz', 3.2e9);
stopband_hz = get_option(options, 'stopbandHz', 3.9e9);
absolute_frequency = abs(frequency);
lowpass = ones(size(frequency));
lowpass(absolute_frequency >= stopband_hz) = 0;
transition = absolute_frequency > passband_hz & ...
    absolute_frequency < stopband_hz;
lowpass(transition) = 0.5 * (1 + cos(pi * ...
    (absolute_frequency(transition) - passband_hz) / ...
    (stopband_hz - passband_hz)));
combined_response = phase .* lowpass;
corrected = ifft(ifftshift(bsxfun(@times, spectrum, ...
    combined_response), 1), [], 1);

compensated = capture;
compensated.channels = single([real(corrected(:, 1)), ...
    imag(corrected(:, 1)), real(corrected(:, 2)), imag(corrected(:, 2))]);
compensated.sampleRateHz = sample_rate;
compensated.pointCount = count;
compensated.dispersionPsNm = double(dispersion_ps_nm);
compensated.recommendedDecimation = decimation;
end

function phase = dispersion_phase(frequency, dispersion_ps_nm, wavelength_nm)
speed_of_light = 299792458;
wavelength_m = wavelength_nm * 1e-9;
dispersion_si = dispersion_ps_nm * 1e-12 / 1e-9;
beta2_length = -(wavelength_m ^ 2 / (2 * pi * speed_of_light)) * ...
    dispersion_si;
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
