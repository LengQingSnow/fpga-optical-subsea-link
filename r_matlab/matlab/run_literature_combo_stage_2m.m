%RUN_LITERATURE_COMBO_STAGE_2M Evaluate per-block timing with BPS window 64.
set(0, 'DefaultFigureVisible', 'off');
matlab_dir = smf_project_path('r_matlab','matlab');
data_dir = smf_project_path('r_matlab','data2');
addpath(matlab_dir);
reference = load(fullfile(data_dir, ...
    'rf47_reference_for_330km_capture.mat'));
reference = reference.reference;
loaded_dbp = load(fullfile(data_dir, 'literature_stage1_dbp_2m.mat'));
dbp = loaded_dbp.dbp;
loaded_stage1 = load(fullfile(data_dir, 'literature_stage1_2m_result.mat'));
probes = loaded_stage1.probes;
timing = load(fullfile(data_dir, ...
    'literature_timing_stage_2m_result.mat'));
[~, best_index] = min(timing.ber, [], 2);
offsets = timing.summary.offsets(best_index);
block_points = 250000;
block_count = floor(dbp.pointCount / block_points);
base_ber = nan(block_count, 1);
cal_ber = nan(block_count, 1);
base_lane = nan(block_count, 4);
cal_lane = nan(block_count, 4);
base_evm = nan(block_count, 2);
cal_evm = nan(block_count, 2);
file_id = fopen(fullfile(data_dir, 'literature_combo_stage_2m.log'), 'w');
if file_id < 0
    error('run_literature_combo_stage_2m:Log', 'Cannot open log.');
end
cleanup = onCleanup(@() fclose(file_id));
for block = 1:block_count
    first = (block - 1) * block_points + 1;
    last = block * block_points;
    local = dbp;
    local.channels = dbp.channels(first:last, :);
    local.pointCount = block_points;
    base_fse = offline_reference_wl_fse(local, reference, probes{block}, ...
        struct('symbolRateHz', 4e9, 'tapCount', 7, ...
        'trainSymbols', 1024, 'outputSymbols', 8, 'ridge', 1e-2, ...
        'causal', false));
    base_bps = offline_joint_qpsk_bps(base_fse, ...
        struct('blockSymbols', 64, 'phaseCount', 81, ...
        'jointPolarizations', true));
    cal_fse = offline_reference_wl_fse(local, reference, probes{block}, ...
        struct('symbolRateHz', 4e9, 'tapCount', 7, ...
        'trainSymbols', 1024, 'outputSymbols', 8, 'ridge', 1e-2, ...
        'causal', false, 'fractionalSampleOffset', offsets(block)));
    cal_bps = offline_joint_qpsk_bps(cal_fse, ...
        struct('blockSymbols', 64, 'phaseCount', 81, ...
        'jointPolarizations', true));
    base_ber(block) = base_bps.ber;
    base_lane(block, :) = base_bps.berByLane;
    base_evm(block, :) = base_bps.evmRms;
    cal_ber(block) = cal_bps.ber;
    cal_lane(block, :) = cal_bps.berByLane;
    cal_evm(block, :) = cal_bps.evmRms;
    fprintf(file_id, 'BLOCK=%d OFFSET=%g BASE=%g CAL=%g BL=%s CL=%s BE=%s CE=%s\n', ...
        block, offsets(block), base_bps.ber, cal_bps.ber, ...
        mat2str(base_bps.berByLane), mat2str(cal_bps.berByLane), ...
        mat2str(base_bps.evmRms), mat2str(cal_bps.evmRms));
end
summary = struct();
summary.baseBer = mean(base_ber);
summary.baseBerByLane = mean(base_lane, 1);
summary.baseEvm = mean(base_evm, 1);
summary.calibratedBer = mean(cal_ber);
summary.calibratedBerByLane = mean(cal_lane, 1);
summary.calibratedEvm = mean(cal_evm, 1);
summary.offsets = offsets;
fprintf(file_id, 'SUMMARY BASE=%g CAL=%g OFFSETS=%s\n', ...
    summary.baseBer, summary.calibratedBer, mat2str(offsets));
save(fullfile(data_dir, 'literature_combo_stage_2m_result.mat'), ...
    'summary', 'base_ber', 'base_lane', 'base_evm', 'cal_ber', ...
    'cal_lane', 'cal_evm', '-v7');
clear cleanup;
exit;
