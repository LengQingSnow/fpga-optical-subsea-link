function report = analyze_square_alignment(capture_dir)
%ANALYZE_SQUARE_ALIGNMENT Measure common-source square-wave timing skew.

capture = load_scpi_capture(capture_dir);
signals = double(capture.channels);
fs = double(capture.sampleRateHz);
n = size(signals, 1);
signals = signals - repmat(mean(signals, 1), n, 1);

% Estimate the dominant square-wave fundamental from CH1.  The RF47
% diagnostic source is close to 1 GHz; limiting the search avoids picking
% harmonics or scope noise.
fft_length = 2^nextpow2(n);
window = 0.5 - 0.5*cos(2*pi*(0:n-1)'/(n-1));
spectrum = abs(fft(signals(:, 1).*window, fft_length));
freq = (0:fft_length-1)' * fs / fft_length;
band = find(freq >= 0.7e9 & freq <= 1.3e9);
[~, index] = max(spectrum(band));
frequency_hz = freq(band(index));

t = (0:n-1)'/fs;
phasor = zeros(1, 4);
amplitude = zeros(1, 4);
for lane = 1:4
    coefficient = 2/n * sum(signals(:, lane) .* exp(-1j*2*pi*frequency_hz*t));
    phasor(lane) = coefficient;
    amplitude(lane) = abs(coefficient);
end
relative_phase_rad = angle(phasor ./ phasor(1));
period_ps = 1e12 / frequency_hz;
relative_delay_ps = -relative_phase_rad/(2*pi*frequency_hz)*1e12;
relative_delay_ps = relative_delay_ps - round(relative_delay_ps/period_ps)*period_ps;

report.frequencyHz = frequency_hz;
report.periodPs = period_ps;
report.relativePhaseRad = relative_phase_rad;
report.relativeDelayPs = relative_delay_ps;
report.fundamentalAmplitude = amplitude;

fprintf('Square fundamental %.9g Hz (period %.3f ps)\n', frequency_hz, period_ps);
for lane = 1:4
    fprintf('CH%d: phase %+0.6f rad, delay %+0.3f ps, amplitude %.6g\n', ...
        lane, relative_phase_rad(lane), relative_delay_ps(lane), amplitude(lane));
end
end
