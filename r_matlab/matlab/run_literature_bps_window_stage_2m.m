%RUN_LITERATURE_BPS_WINDOW_STAGE_2M Search blind phase-tracking window.
set(0, 'DefaultFigureVisible', 'off');
matlab_dir = smf_project_path('r_matlab','matlab');
data_dir = smf_project_path('r_matlab','data2');
addpath(matlab_dir);
loaded_reference = load(fullfile(data_dir, 'rf47_reference_for_330km_capture.mat'));
loaded_dbp = load(fullfile(data_dir, 'literature_stage1_dbp_2m.mat'));
loaded_stage1 = load(fullfile(data_dir, 'literature_stage1_2m_result.mat'));
reference = loaded_reference.reference;
dbp = loaded_dbp.dbp;
probes = loaded_stage1.probes;
block_windows = [8, 16, 32, 64, 128];
block_points = 250000;
block_count = floor(dbp.pointCount / block_points);
ber = nan(block_count, numel(block_windows));
lane = nan(block_count, numel(block_windows), 4);
evm = nan(block_count, numel(block_windows), 2);
file_id = fopen(fullfile(data_dir, 'literature_bps_window_stage_2m.log'), 'w');
if file_id < 0
    error('run_literature_bps_window_stage_2m:Log', 'Cannot open log.');
end
cleanup = onCleanup(@() fclose(file_id));
for block = 1:block_count
    first = (block - 1) * block_points + 1;
    last = block * block_points;
    local = dbp;
    local.channels = dbp.channels(first:last, :);
    local.pointCount = block_points;
    fse = offline_reference_wl_fse(local, reference, probes{block}, ...
        struct('symbolRateHz', 4e9, 'tapCount', 7, ...
        'trainSymbols', 1024, 'outputSymbols', 8, 'ridge', 1e-2, ...
        'causal', false));
    for index = 1:numel(block_windows)
        bps = offline_joint_qpsk_bps(fse, ...
            struct('blockSymbols', block_windows(index), ...
            'phaseCount', 81, 'jointPolarizations', true));
        ber(block, index) = bps.ber;
        lane(block, index, :) = bps.berByLane;
        evm(block, index, :) = bps.evmRms;
        fprintf(file_id, 'BLOCK=%d WINDOW=%d BER=%g L=%s E=%s\n', ...
            block, block_windows(index), bps.ber, mat2str(bps.berByLane), ...
            mat2str(bps.evmRms));
    end
    fprintf('BPS window block %d/%d done, best %.6g\n', block, ...
        block_count, min(ber(block, :)));
end
[best_ber, best_index] = min(mean(ber, 1));
summary = struct();
summary.blockWindows = block_windows;
summary.ber = mean(ber, 1);
summary.berByLane = squeeze(mean(lane, 1));
summary.evm = squeeze(mean(evm, 1));
summary.bestWindow = block_windows(best_index);
summary.bestBer = best_ber;
fprintf(file_id, 'SUMMARY BEST_WINDOW=%d BEST_BER=%g\n', ...
    summary.bestWindow, summary.bestBer);
save(fullfile(data_dir, 'literature_bps_window_stage_2m_result.mat'), ...
    'summary', 'ber', 'lane', 'evm', '-v7');
clear cleanup;
exit;
