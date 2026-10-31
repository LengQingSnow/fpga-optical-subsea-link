%RUN_LITERATURE_BEST_10M Validate the best offline DSP candidate on 10M.
set(0, 'DefaultFigureVisible', 'off');
matlab_dir = smf_project_path('r_matlab','matlab');
data_dir = smf_project_path('r_matlab','data2');
addpath(matlab_dir);
reference = load(fullfile(data_dir, ...
    'rf47_reference_for_330km_capture.mat'));
reference = reference.reference;
dbp = load(fullfile(data_dir, 'literature_stage3_dbp_10m.mat'));
dbp = dbp.dbp;
block_points = 250000;
block_count = floor(dbp.pointCount / block_points);
baseline_ber = nan(block_count, 1);
baseline_lane = nan(block_count, 4);
baseline_evm = nan(block_count, 2);
best_ber = nan(block_count, 1);
best_lane = nan(block_count, 4);
best_evm = nan(block_count, 2);
probes = cell(block_count, 1);
plot_equalized = zeros(0, 2);
plot_target = zeros(0, 2);
previous_cfo = -531e6;
fractional_offset = -1.75;
file_id = fopen(fullfile(data_dir, 'literature_best_10m.log'), 'w');
if file_id < 0
    error('run_literature_best_10m:Log', 'Cannot open log.');
end
cleanup = onCleanup(@() fclose(file_id));

for block = 1:block_count
    first = (block - 1) * block_points + 1;
    last = block * block_points;
    local = dbp;
    local.channels = dbp.channels(first:last, :);
    local.pointCount = block_points;
    if block == 1
        cfo_grid = (-538:0.5:-524) * 1e6;
    else
        predicted_cfo = previous_cfo - 0.5e6;
        cfo_grid = predicted_cfo + (-3:0.25:3) * 1e6;
    end
    probe = offline_reference_cfo_scan(local, reference, ...
        struct('symbolRateHz', 4e9, 'cfoGridHz', cfo_grid, ...
        'searchPeriods', 2, 'probeSymbols', 2048));
    probes{block} = probe;
    previous_cfo = probe.frequencyOffsetHz;
    baseline = offline_reference_wl_fse(local, reference, probe, ...
        struct('symbolRateHz', 4e9, 'tapCount', 7, ...
        'trainSymbols', 1024, 'outputSymbols', 8, 'ridge', 1e-2, ...
        'causal', false));
    baseline_bps = offline_joint_qpsk_bps(baseline, ...
        struct('blockSymbols', 64, 'phaseCount', 321, ...
        'jointPolarizations', true));
    best = offline_reference_wl_fse(local, reference, probe, ...
        struct('symbolRateHz', 4e9, 'tapCount', 7, ...
        'trainSymbols', 1024, 'outputSymbols', 8, 'ridge', 0.1, ...
        'causal', false, 'fractionalSampleOffset', fractional_offset));
    best_bps = offline_joint_qpsk_bps(best, ...
        struct('blockSymbols', 64, 'phaseCount', 321, ...
        'jointPolarizations', true));
    baseline_ber(block) = baseline_bps.ber;
    baseline_lane(block, :) = baseline_bps.berByLane;
    baseline_evm(block, :) = baseline_bps.evmRms;
    best_ber(block) = best_bps.ber;
    best_lane(block, :) = best_bps.berByLane;
    best_evm(block, :) = best_bps.evmRms;
    take = min(5000, size(best_bps.equalizedSymbols, 1));
    plot_equalized = [plot_equalized; best_bps.equalizedSymbols(1:take, :)]; %#ok<AGROW>
    plot_target = [plot_target; best_bps.desiredSymbols(1:take, :)]; %#ok<AGROW>
    fprintf(file_id, ['BLOCK=%d CFO=%g PH=%g SH=%g BASE=%g BEST=%g ' ...
        'BL=%s JL=%s BE=%s JE=%s\n'], block, probe.frequencyOffsetHz, ...
        probe.phase, probe.shift, baseline_bps.ber, best_bps.ber, ...
        mat2str(baseline_bps.berByLane), mat2str(best_bps.berByLane), ...
        mat2str(baseline_bps.evmRms), mat2str(best_bps.evmRms));
    fprintf('Best 10M block %d/%d, baseline %.6g, selected %.6g\n', ...
        block, block_count, baseline_bps.ber, best_bps.ber);
end

summary = struct();
summary.pointCount = dbp.pointCount;
summary.fractionalSampleOffset = fractional_offset;
summary.baselineBer = mean(baseline_ber);
summary.baselineBerByLane = mean(baseline_lane, 1);
summary.baselineEvm = mean(baseline_evm, 1);
summary.bestBer = mean(best_ber);
summary.bestBerByLane = mean(best_lane, 1);
summary.bestEvm = mean(best_evm, 1);
fprintf(file_id, 'SUMMARY BASE=%g BEST=%g OFF=%g BL=%s JL=%s BE=%s JE=%s\n', ...
    summary.baselineBer, summary.bestBer, fractional_offset, ...
    mat2str(summary.baselineBerByLane), mat2str(summary.bestBerByLane), ...
    mat2str(summary.baselineEvm), mat2str(summary.bestEvm));
save(fullfile(data_dir, 'literature_best_10m_result.mat'), ...
    'summary', 'baseline_ber', 'baseline_lane', 'baseline_evm', ...
    'best_ber', 'best_lane', 'best_evm', 'probes', ...
    'plot_equalized', 'plot_target', '-v7');
clear cleanup;
exit;
