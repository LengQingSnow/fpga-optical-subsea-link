%RUN_LITERATURE_FRONTEND_STAGE_2M Test reference-aided lane skew calibration.
%   This script is intentionally separate from the GUI and existing stage
%   scripts. It evaluates only a 2M-point cached DBP capture.

set(0, 'DefaultFigureVisible', 'off');
matlab_dir = smf_project_path('r_matlab','matlab');
data_dir = smf_project_path('r_matlab','data2');
addpath(matlab_dir);

capture_file = fullfile(data_dir, 'capture_330km_ber_pair.mat');
reference_file = fullfile(data_dir, 'rf47_reference_for_330km_capture.mat');
dbp_file = fullfile(data_dir, 'literature_stage1_dbp_2m.mat');
stage1_file = fullfile(data_dir, 'literature_stage1_2m_result.mat');
log_file = fullfile(data_dir, 'literature_frontend_skew_only_2m.log');
result_file = fullfile(data_dir, 'literature_frontend_skew_only_2m_result.mat');

loaded_capture = load(capture_file);
loaded_reference = load(reference_file);
loaded_dbp = load(dbp_file);
loaded_stage1 = load(stage1_file);
capture = loaded_capture.pair.capture;
reference = loaded_reference.reference;
dbp = loaded_dbp.dbp;
probes = loaded_stage1.probes;

block_points = 250000;
block_count = floor(dbp.pointCount / block_points);
baseline_ber = nan(block_count, 1);
baseline_lane = nan(block_count, 4);
baseline_evm = nan(block_count, 2);
baseline_bps_ber = nan(block_count, 1);
baseline_bps_lane = nan(block_count, 4);
baseline_bps_evm = nan(block_count, 2);
cal_ber = nan(block_count, 1);
cal_lane = nan(block_count, 4);
cal_evm = nan(block_count, 2);
cal_bps_ber = nan(block_count, 1);
cal_bps_lane = nan(block_count, 4);
cal_bps_evm = nan(block_count, 2);
skews = nan(block_count, 4);
calibrations = cell(block_count, 1);

file_id = fopen(log_file, 'w');
if file_id < 0
    error('run_literature_frontend_stage_2m:Log', ...
        'Cannot open the stage log file.');
end
cleanup = onCleanup(@() fclose(file_id));

for block = 1:block_count
    first = (block - 1) * block_points + 1;
    last = block * block_points;
    local = dbp;
    local.channels = dbp.channels(first:last, :);
    local.pointCount = block_points;
    probe = probes{block};

    base_fse = offline_reference_wl_fse(local, reference, probe, ...
        struct('symbolRateHz', 4e9, 'tapCount', 7, ...
        'trainSymbols', 1024, 'outputSymbols', 8, 'ridge', 1e-2, ...
        'causal', false));
    base_bps = offline_joint_qpsk_bps(base_fse, ...
        struct('blockSymbols', 32, 'phaseCount', 81, ...
        'jointPolarizations', true));

    calibration = offline_frontend_skew_search(local, reference, probe, ...
        struct('symbolRateHz', 4e9, 'skewGridSamples', -0.4:0.1:0.4, ...
        'passes', 1, 'trainSymbols', 1024, 'testSymbols', 1024, ...
        'ridge', 1e-3));
    calibrated_fse = offline_reference_wl_fse(local, reference, probe, ...
        struct('symbolRateHz', 4e9, 'tapCount', 7, ...
        'trainSymbols', 1024, 'outputSymbols', 8, 'ridge', 1e-2, ...
        'causal', false, 'channelSkewSamples', ...
        calibration.channelSkewSamples));
    calibrated_bps = offline_joint_qpsk_bps(calibrated_fse, ...
        struct('blockSymbols', 32, 'phaseCount', 81, ...
        'jointPolarizations', true));

    baseline_ber(block) = base_fse.ber;
    baseline_lane(block, :) = base_fse.berByLane;
    baseline_evm(block, :) = base_fse.evmRms;
    baseline_bps_ber(block) = base_bps.ber;
    baseline_bps_lane(block, :) = base_bps.berByLane;
    baseline_bps_evm(block, :) = base_bps.evmRms;
    cal_ber(block) = calibrated_fse.ber;
    cal_lane(block, :) = calibrated_fse.berByLane;
    cal_evm(block, :) = calibrated_fse.evmRms;
    cal_bps_ber(block) = calibrated_bps.ber;
    cal_bps_lane(block, :) = calibrated_bps.berByLane;
    cal_bps_evm(block, :) = calibrated_bps.evmRms;
    skews(block, :) = calibration.channelSkewSamples;
    calibrations{block} = calibration;
    fprintf(file_id, ['BLOCK=%d CFO=%g PH=%g SH=%g BASE=%g BBASE=%g ' ...
        'CAL=%g BCAL=%g SKEW=%s BL=%s BBL=%s CL=%s BCL=%s ' ...
        'BE=%s BBE=%s CE=%s BCE=%s\n'], block, ...
        probe.frequencyOffsetHz, probe.phase, probe.shift, base_fse.ber, ...
        base_bps.ber, calibrated_fse.ber, calibrated_bps.ber, ...
        mat2str(calibration.channelSkewSamples), ...
        mat2str(base_fse.berByLane), mat2str(base_bps.berByLane), ...
        mat2str(calibrated_fse.berByLane), ...
        mat2str(calibrated_bps.berByLane), mat2str(base_fse.evmRms), ...
        mat2str(base_bps.evmRms), mat2str(calibrated_fse.evmRms), ...
        mat2str(calibrated_bps.evmRms));
    fprintf('Frontend stage block %d/%d, baseline %.6g, calibrated %.6g\n', ...
        block, block_count, base_bps.ber, calibrated_bps.ber);
end

summary = struct();
summary.blockCount = block_count;
summary.baselineBer = mean(baseline_ber);
summary.baselineBerByLane = mean(baseline_lane, 1);
summary.baselineEvm = mean(baseline_evm, 1);
summary.baselineBpsBer = mean(baseline_bps_ber);
summary.baselineBpsBerByLane = mean(baseline_bps_lane, 1);
summary.baselineBpsEvm = mean(baseline_bps_evm, 1);
summary.calibratedBer = mean(cal_ber);
summary.calibratedBerByLane = mean(cal_lane, 1);
summary.calibratedEvm = mean(cal_evm, 1);
summary.calibratedBpsBer = mean(cal_bps_ber);
summary.calibratedBpsBerByLane = mean(cal_bps_lane, 1);
summary.calibratedBpsEvm = mean(cal_bps_evm, 1);
summary.skewSamples = mean(skews, 1);
fprintf(file_id, ['SUMMARY BASE=%g BBASE=%g CAL=%g BCAL=%g ' ...
    'SKEW=%s BL=%s BBL=%s CL=%s BCL=%s BE=%s BBE=%s CE=%s BCE=%s\n'], ...
    summary.baselineBer, summary.baselineBpsBer, summary.calibratedBer, ...
    summary.calibratedBpsBer, mat2str(summary.skewSamples), ...
    mat2str(summary.baselineBerByLane), ...
    mat2str(summary.baselineBpsBerByLane), ...
    mat2str(summary.calibratedBerByLane), ...
    mat2str(summary.calibratedBpsBerByLane), ...
    mat2str(summary.baselineEvm), mat2str(summary.baselineBpsEvm), ...
    mat2str(summary.calibratedEvm), mat2str(summary.calibratedBpsEvm));
save(result_file, 'summary', 'baseline_ber', 'baseline_lane', ...
    'baseline_evm', 'baseline_bps_ber', 'baseline_bps_lane', ...
    'baseline_bps_evm', 'cal_ber', 'cal_lane', 'cal_evm', ...
    'cal_bps_ber', 'cal_bps_lane', 'cal_bps_evm', 'skews', ...
    'calibrations', '-v7');
clear cleanup;
exit;
