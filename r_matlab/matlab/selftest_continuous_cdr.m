function selftest_continuous_cdr()
%SELFTEST_CONTINUOUS_CDR Verify ppm estimation and outlier rejection.

script_dir = fileparts(mfilename('fullpath'));
cfg = rf47_default_config(script_dir);
sample_rate = 10e9;
samples_per_symbol = sample_rate / cfg.symbolRateHz;
chunk_symbols = 2 * cfg.frameBytes * cfg.timingChunkFrames;
chunk_start_points = (0:39)' * chunk_symbols * samples_per_symbol + 1;
anchor_symbols = (chunk_start_points - 1) / samples_per_symbol;
true_ppm = -0.18310546875;
true_slope = true_ppm * 1e-6;
lane_phase = [0.96875, 0.8125, 0.53125, 0.9375];
ideal = bsxfun(@plus, true_slope * anchor_symbols, lane_phase);
measured = mod(round(ideal * cfg.timingPhaseCount) / ...
    cfg.timingPhaseCount, 1);
measured(30, 2) = 0.03125;

model = estimate_continuous_cdr(chunk_start_points, measured, ...
    true(size(chunk_start_points)), sample_rate, cfg);
assert(abs(model.clockOffsetPpm - true_ppm) < 0.01);
assert(~model.inlierMask(30, 2));
expected_phase = bsxfun(@plus, true_slope * anchor_symbols, lane_phase);
phase_error = model.anchorPhaseSymbols - expected_phase;
phase_error = phase_error - round(phase_error);
assert(max(abs(phase_error(:))) < 0.04);
fprintf(['selftest_continuous_cdr: PASS (estimated %.9f ppm, ' ...
    'outlier rejected).\n'], model.clockOffsetPpm);
end
