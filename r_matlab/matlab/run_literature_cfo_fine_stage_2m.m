%RUN_LITERATURE_CFO_FINE_STAGE_2M Refine CFO around cached probe values.
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
block_points = 250000;
block_count = floor(dbp.pointCount / block_points);
ber = nan(block_count, 1);
lane = nan(block_count, 4);
evm = nan(block_count, 2);
cfo = nan(block_count, 1);
file_id = fopen(fullfile(data_dir, 'literature_cfo_fine_stage_2m.log'), 'w');
if file_id < 0
    error('run_literature_cfo_fine_stage_2m:Log', 'Cannot open log.');
end
cleanup = onCleanup(@() fclose(file_id));
for block = 1:block_count
    first = (block - 1) * block_points + 1;
    last = block * block_points;
    local = dbp;
    local.channels = dbp.channels(first:last, :);
    local.pointCount = block_points;
    base_probe = probes{block};
    grid = base_probe.frequencyOffsetHz + (-1:0.1:1) * 1e6;
    probe = offline_reference_cfo_scan(local, reference, ...
        struct('symbolRateHz', 4e9, 'cfoGridHz', grid, ...
        'searchPeriods', 2, 'probeSymbols', 2048));
    fse = offline_reference_wl_fse(local, reference, probe, ...
        struct('symbolRateHz', 4e9, 'tapCount', 7, ...
        'trainSymbols', 1024, 'outputSymbols', 8, 'ridge', 0.1, ...
        'causal', false, 'fractionalSampleOffset', offsets(block)));
    bps = offline_joint_qpsk_bps(fse, ...
        struct('blockSymbols', 64, 'phaseCount', 321, ...
        'jointPolarizations', true));
    ber(block) = bps.ber;
    lane(block, :) = bps.berByLane;
    evm(block, :) = bps.evmRms;
    cfo(block) = probe.frequencyOffsetHz;
    fprintf(file_id, 'BLOCK=%d CFO=%g BER=%g L=%s E=%s\n', block, ...
        cfo(block), bps.ber, mat2str(bps.berByLane), mat2str(bps.evmRms));
end
summary = struct();
summary.ber = mean(ber);
summary.berByLane = mean(lane, 1);
summary.evm = mean(evm, 1);
summary.cfo = cfo;
summary.offsets = offsets;
fprintf(file_id, 'SUMMARY BER=%g L=%s E=%s\n', summary.ber, ...
    mat2str(summary.berByLane), mat2str(summary.evm));
save(fullfile(data_dir, 'literature_cfo_fine_stage_2m_result.mat'), ...
    'summary', 'ber', 'lane', 'evm', 'cfo', '-v7');
clear cleanup;
exit;
