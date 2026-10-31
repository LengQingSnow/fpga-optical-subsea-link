function selftest_eye_metrics()
capture.sampleRateHz = 40e9;
capture.pointCount = 100000;
bits = logical(mod((0:capture.pointCount / 10 - 1)', 3) == 0);
symbol = 2 * double(bits) - 1;
waveform = kron(symbol, ones(10, 1));
rng(19);
capture.channels = single(repmat(waveform, 1, 4) + ...
    0.01 * randn(numel(waveform), 4));
metrics = compute_eye_metrics(capture, 4e9);
assert(all(metrics.bestEyeHeightNormalized > 1.5));
assert(all(metrics.bestEyeWidthUi >= 0.4));
fprintf('selftest_eye_metrics: PASS.\n');
end
