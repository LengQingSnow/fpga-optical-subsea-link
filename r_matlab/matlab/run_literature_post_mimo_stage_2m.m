%RUN_LITERATURE_POST_MIMO_STAGE_2M Test decision-directed MIMO cleanup.
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
train_lengths = [32, 64, 128, 256, 512, 1024];
block_points = 250000;
block_count = floor(dbp.pointCount / block_points);
ber = nan(block_count, numel(train_lengths));
lane = nan(block_count, numel(train_lengths), 4);
evm = nan(block_count, numel(train_lengths), 2);
file_id = fopen(fullfile(data_dir, 'literature_post_mimo_stage_2m.log'), 'w');
if file_id < 0
    error('run_literature_post_mimo_stage_2m:Log', 'Cannot open log.');
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
        'trainSymbols', 1024, 'outputSymbols', 8, 'ridge', 0.1, ...
        'causal', false, 'fractionalSampleOffset', offsets(block)));
    bps = offline_joint_qpsk_bps(fse, ...
        struct('blockSymbols', 64, 'phaseCount', 321, ...
        'jointPolarizations', true));
    for index = 1:numel(train_lengths)
        mimo = offline_bps_reference_mimo(bps, ...
            struct('blockSymbols', 64, 'trainSymbols', train_lengths(index), ...
            'ridge', 1e-2));
        ber(block, index) = mimo.ber;
        lane(block, index, :) = mimo.berByLane;
        evm(block, index, :) = mimo.evmRms;
        fprintf(file_id, 'BLOCK=%d TRAIN=%d BER=%g L=%s E=%s\n', ...
            block, train_lengths(index), mimo.ber, mat2str(mimo.berByLane), ...
            mat2str(mimo.evmRms));
    end
end
[best_ber, best_index] = min(mean(ber, 1));
summary = struct();
summary.trainLengths = train_lengths;
summary.ber = mean(ber, 1);
summary.berByLane = squeeze(mean(lane, 1));
summary.evm = squeeze(mean(evm, 1));
summary.bestTrainLength = train_lengths(best_index);
summary.bestBer = best_ber;
fprintf(file_id, 'SUMMARY BEST_TRAIN=%d BEST_BER=%g\n', ...
    summary.bestTrainLength, summary.bestBer);
save(fullfile(data_dir, 'literature_post_mimo_stage_2m_result.mat'), ...
    'summary', 'ber', 'lane', 'evm', '-v7');
clear cleanup;
exit;
