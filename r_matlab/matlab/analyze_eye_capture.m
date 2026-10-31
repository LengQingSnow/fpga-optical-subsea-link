function metrics = analyze_eye_capture(capture_dir, output_dir)
%ANALYZE_EYE_CAPTURE Analyze DS81304 raw capture and write CSV/MAT report.

capture = load_scpi_capture(capture_dir);
metrics = compute_eye_metrics(capture, 4e9);
if nargin < 2 || isempty(output_dir)
    output_dir = capture_dir;
end
if exist(output_dir, 'dir') ~= 7
    mkdir(output_dir);
end

file_id = fopen(fullfile(output_dir, 'eye_metrics.csv'), 'w');
cleanup = onCleanup(@() fclose(file_id));
fprintf(file_id, ['channel,best_phase_ui,relative_phase_ui,relative_delay_ps,' ...
    'eye_height_normalized,eye_height_volts,eye_width_ui,' ...
    'rms_decision_noise_normalized\n']);
for lane = 1:4
    item = metrics.channel(lane);
    fprintf(file_id, '%d,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g\n', ...
        lane, item.bestPhaseUi, item.relativePhaseUi, ...
        item.relativeDelayPs, item.eyeHeightNormalized, ...
        item.eyeHeightVolts, item.eyeWidthUi, ...
        item.rmsDecisionNoiseNormalized);
end
clear cleanup;
save(fullfile(output_dir, 'eye_metrics.mat'), 'metrics', '-v7');
fprintf(['Eye capture %.6g GSa/s, %.6g samples/UI.\n' ...
    'CH1 %.4f UI / CH2 %.4f UI / CH3 %.4f UI / CH4 %.4f UI height.\n'], ...
    metrics.sampleRateHz / 1e9, metrics.samplesPerSymbol, ...
    metrics.bestEyeHeightNormalized);
end
