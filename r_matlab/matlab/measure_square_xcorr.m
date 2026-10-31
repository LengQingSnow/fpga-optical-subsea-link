function report = measure_square_xcorr(capture_dir)
%MEASURE_SQUARE_XCORR Estimate same-record channel skew by periodic correlation.
capture = load_scpi_capture(capture_dir);
x = double(capture.channels);
x = x - repmat(mean(x, 1), size(x, 1), 1);
% Remove scope noise while retaining the square-wave edge.
kernel = ones(5, 1)/5;
for lane = 1:4
    x(:, lane) = conv(x(:, lane), kernel, 'same');
end
reference = x(:, 1);
% Estimate the fundamental period so the periodic correlation cannot select
% a peak several cycles away from zero.  The hardware delay range is below
% half this diagnostic period.
n = size(x, 1);
fft_length = 2^nextpow2(n);
window = 0.5 - 0.5*cos(2*pi*(0:n-1)'/(n-1));
spectrum = abs(fft(x(:, 1).*window, fft_length));
freq = (0:fft_length-1)' * capture.sampleRateHz / fft_length;
band = find(freq >= 0.7e9 & freq <= 1.3e9);
[~, peak] = max(spectrum(band));
frequency_hz = freq(band(peak));
period_samples = capture.sampleRateHz / frequency_hz;
max_lag = max(2, round(0.5*period_samples));
lags = (-max_lag:max_lag)';
correlation = zeros(numel(lags), 3);
for lane = 2:4
    for k = 1:numel(lags)
        lag = lags(k);
        if lag >= 0
            a = reference(1:end-lag);
            b = x(1+lag:end, lane);
        else
            a = reference(1-lag:end);
            b = x(1:end+lag, lane);
        end
        correlation(k, lane-1) = (a'*b)/sqrt((a'*a)*(b'*b));
    end
end

best_lag = zeros(1, 3);
best_corr = zeros(1, 3);
for lane = 1:3
    [best_corr(lane), index] = max(correlation(:, lane));
    best_lag(lane) = lags(index);
end
report.sampleIntervalPs = 1e12/capture.sampleRateHz;
report.frequencyHz = frequency_hz;
report.periodSamples = period_samples;
report.lagSamples = best_lag;
report.lagPs = best_lag * report.sampleIntervalPs;
report.correlation = best_corr;
fprintf('Square xcorr: CH2 %+d samples (%+.3f ps), CH3 %+d (%+.3f ps), CH4 %+d (%+.3f ps), corr %.5f/%.5f/%.5f.\n', ...
    best_lag(1), report.lagPs(1), best_lag(2), report.lagPs(2), ...
    best_lag(3), report.lagPs(3), best_corr(1), best_corr(2), best_corr(3));
end
