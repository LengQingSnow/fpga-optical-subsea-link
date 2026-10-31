%RUN_LITERATURE_TAPS_COMBO_STAGE_2M Search FSE taps with timing/BPS settings.
set(0, 'DefaultFigureVisible', 'off');
matlab_dir = smf_project_path('r_matlab','matlab');
data_dir = smf_project_path('r_matlab','data2');
addpath(matlab_dir);
reference = load(fullfile(data_dir, ...
    'rf47_reference_for_330km_capture.mat'));
reference = reference.reference;
dbp = load(fullfile(data_dir, 'literature_stage1_dbp_2m.mat'));
dbp = dbp.dbp;
stage1 = load(fullfile(data_dir, 'literature_stage1_2m_result.mat'));
probes = stage1.probes;
timing = load(fullfile(data_dir, ...
    'literature_timing_stage_2m_result.mat'));
[~, best_index] = min(timing.ber, [], 2);
offsets = timing.summary.offsets(best_index);
tap_counts = [5, 7, 9, 11, 15, 21];
block_points = 250000;
block_count = floor(dbp.pointCount / block_points);
ber = nan(block_count, numel(tap_counts));
lane = nan(block_count, numel(tap_counts), 4);
evm = nan(block_count, numel(tap_counts), 2);
file_id = fopen(fullfile(data_dir, 'literature_taps_combo_stage_2m.log'), 'w');
if file_id < 0
    error('run_literature_taps_combo_stage_2m:Log', 'Cannot open log.');
end
cleanup = onCleanup(@() fclose(file_id));
for block = 1:block_count
    first = (block - 1) * block_points + 1;
    last = block * block_points;
    local = dbp;
    local.channels = dbp.channels(first:last, :);
    local.pointCount = block_points;
    for index = 1:numel(tap_counts)
        fse = offline_reference_wl_fse(local, reference, probes{block}, ...
            struct('symbolRateHz', 4e9, 'tapCount', tap_counts(index), ...
            'trainSymbols', 1024, 'outputSymbols', 8, 'ridge', 1e-2, ...
            'causal', false, 'fractionalSampleOffset', offsets(block)));
        bps = offline_joint_qpsk_bps(fse, ...
            struct('blockSymbols', 64, 'phaseCount', 321, ...
            'jointPolarizations', true));
        ber(block, index) = bps.ber;
        lane(block, index, :) = bps.berByLane;
        evm(block, index, :) = bps.evmRms;
        fprintf(file_id, 'BLOCK=%d TAPS=%d BER=%g L=%s E=%s\n', ...
            block, tap_counts(index), bps.ber, mat2str(bps.berByLane), ...
            mat2str(bps.evmRms));
    end
end
[best_ber, best_index] = min(mean(ber, 1));
summary = struct();
summary.tapCounts = tap_counts;
summary.ber = mean(ber, 1);
summary.berByLane = squeeze(mean(lane, 1));
summary.evm = squeeze(mean(evm, 1));
summary.bestTapCount = tap_counts(best_index);
summary.bestBer = best_ber;
fprintf(file_id, 'SUMMARY BEST_TAPS=%d BEST_BER=%g\n', ...
    summary.bestTapCount, summary.bestBer);
save(fullfile(data_dir, 'literature_taps_combo_stage_2m_result.mat'), ...
    'summary', 'ber', 'lane', 'evm', '-v7');
clear cleanup;
exit;
