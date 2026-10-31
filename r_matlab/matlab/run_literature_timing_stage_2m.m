%RUN_LITERATURE_TIMING_STAGE_2M Search the common fractional sample phase.
set(0, 'DefaultFigureVisible', 'off');
matlab_dir = smf_project_path('r_matlab','matlab');
data_dir = smf_project_path('r_matlab','data2');
addpath(matlab_dir);
loaded_capture = load(fullfile(data_dir, 'capture_330km_ber_pair.mat'));
loaded_reference = load(fullfile(data_dir, 'rf47_reference_for_330km_capture.mat'));
loaded_dbp = load(fullfile(data_dir, 'literature_stage1_dbp_2m.mat'));
loaded_stage1 = load(fullfile(data_dir, 'literature_stage1_2m_result.mat'));
reference = loaded_reference.reference;
dbp = loaded_dbp.dbp;
probes = loaded_stage1.probes;
offsets = -2:0.25:2;
block_points = 250000;
block_count = floor(dbp.pointCount / block_points);
ber = nan(block_count, numel(offsets));
ber_lane = nan(block_count, numel(offsets), 4);
evm = nan(block_count, numel(offsets), 2);
file_id = fopen(fullfile(data_dir, 'literature_timing_stage_2m.log'), 'w');
if file_id < 0
    error('run_literature_timing_stage_2m:Log', 'Cannot open log.');
end
cleanup = onCleanup(@() fclose(file_id));
for block = 1:block_count
    first = (block - 1) * block_points + 1;
    last = block * block_points;
    local = dbp;
    local.channels = dbp.channels(first:last, :);
    local.pointCount = block_points;
    probe = probes{block};
    for index = 1:numel(offsets)
        fse = offline_reference_wl_fse(local, reference, probe, ...
            struct('symbolRateHz', 4e9, 'tapCount', 7, ...
            'trainSymbols', 1024, 'outputSymbols', 8, 'ridge', 1e-2, ...
            'causal', false, 'fractionalSampleOffset', offsets(index)));
        bps = offline_joint_qpsk_bps(fse, ...
            struct('blockSymbols', 32, 'phaseCount', 81, ...
            'jointPolarizations', true));
        ber(block, index) = bps.ber;
        ber_lane(block, index, :) = bps.berByLane;
        evm(block, index, :) = bps.evmRms;
        fprintf(file_id, 'BLOCK=%d OFFSET=%g BER=%g L=%s E=%s\n', ...
            block, offsets(index), bps.ber, mat2str(bps.berByLane), ...
            mat2str(bps.evmRms));
    end
    fprintf('Timing stage block %d/%d done, best %.6g\n', block, ...
        block_count, min(ber(block, :)));
end
[best_ber, best_index] = min(mean(ber, 1));
summary = struct();
summary.offsets = offsets;
summary.ber = mean(ber, 1);
summary.berByLane = squeeze(mean(ber_lane, 1));
summary.evm = squeeze(mean(evm, 1));
summary.bestOffset = offsets(best_index);
summary.bestBer = best_ber;
fprintf(file_id, 'SUMMARY BEST_OFFSET=%g BEST_BER=%g\n', ...
    summary.bestOffset, summary.bestBer);
save(fullfile(data_dir, 'literature_timing_stage_2m_result.mat'), ...
    'summary', 'ber', 'ber_lane', 'evm', '-v7');
clear cleanup;
exit;
