%RUN_LITERATURE_DSP_STAGE2_4M Validate the selected DSP on 4M points.
set(0, 'DefaultFigureVisible', 'off');
matlab_dir = smf_project_path('r_matlab','matlab');
data_dir = smf_project_path('r_matlab','data2');
addpath(matlab_dir);
capture_file = fullfile(data_dir, 'capture_330km_ber_pair.mat');
reference_file = fullfile(data_dir, 'rf47_reference_for_330km_capture.mat');
dbp_file = fullfile(data_dir, 'literature_stage2_dbp_4m.mat');
log_file = fullfile(data_dir, 'literature_stage2_4m.log');
result_file = fullfile(data_dir, 'literature_stage2_4m_result.mat');

loaded_capture = load(capture_file);
loaded_reference = load(reference_file);
capture = loaded_capture.pair.capture;
reference = loaded_reference.reference;
capture.channels = capture.channels(1:4000000, :);
capture.pointCount = size(capture.channels, 1);
if exist(dbp_file, 'file') == 2
    loaded_dbp = load(dbp_file);
    dbp = loaded_dbp.dbp;
else
    dbp = offline_dbp_ssfm_trial(capture, -7250, 0.01, 8, ...
        struct('passbandHz', 2.6e9, 'stopbandHz', 3.4e9));
    save(dbp_file, 'dbp', '-v7.3');
end

file_id = fopen(log_file, 'w');
if file_id < 0
    error('run_literature_dsp_stage2_4m:Log', ...
        'Cannot open the stage log file.');
end
block_points = 250000;
block_count = floor(dbp.pointCount / block_points);
baseline_ber = nan(block_count, 1);
baseline_lane = nan(block_count, 4);
baseline_evm = nan(block_count, 2);
fse_ber = nan(block_count, 1);
fse_lane = nan(block_count, 4);
fse_evm = nan(block_count, 2);
bps_ber = nan(block_count, 1);
bps_lane = nan(block_count, 4);
bps_evm = nan(block_count, 2);
probes = cell(block_count, 1);
plot_equalized = zeros(0, 2);
plot_target = zeros(0, 2);
previous_cfo = -531e6;

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
    baseline = offline_reference_cfo_sliding_fir(local, reference, ...
        probe, struct('symbolRateHz', 4e9, 'outputSymbols', 8, ...
        'trainSymbols', 384, 'tapCount', 5, 'ridge', 1e-2));
    fse = offline_reference_wl_fse(local, reference, probe, ...
        struct('symbolRateHz', 4e9, 'tapCount', 7, ...
        'trainSymbols', 1024, 'outputSymbols', 8, ...
        'ridge', 1e-2, 'causal', false));
    bps = offline_joint_qpsk_bps(fse, ...
        struct('blockSymbols', 32, 'phaseCount', 81, ...
        'jointPolarizations', true));
    baseline_ber(block) = baseline.ber;
    baseline_lane(block, :) = baseline.berByLane;
    baseline_evm(block, :) = baseline.evmRms;
    fse_ber(block) = fse.ber;
    fse_lane(block, :) = fse.berByLane;
    fse_evm(block, :) = fse.evmRms;
    bps_ber(block) = bps.ber;
    bps_lane(block, :) = bps.berByLane;
    bps_evm(block, :) = bps.evmRms;
    take = min(20000, size(bps.equalizedSymbols, 1));
    plot_equalized = [plot_equalized; bps.equalizedSymbols(1:take, :)]; %#ok<AGROW>
    plot_target = [plot_target; bps.desiredSymbols(1:take, :)]; %#ok<AGROW>
    fprintf(file_id, ['BLOCK=%d CFO=%g PH=%g SH=%g BASE=%g FSE=%g BPS=%g ' ...
        'BL=%s FL=%s JL=%s BE=%s FE=%s JE=%s\n'], block, ...
        probe.frequencyOffsetHz, probe.phase, probe.shift, baseline.ber, ...
        fse.ber, bps.ber, mat2str(baseline.berByLane), ...
        mat2str(fse.berByLane), mat2str(bps.berByLane), ...
        mat2str(baseline.evmRms), mat2str(fse.evmRms), ...
        mat2str(bps.evmRms));
    fclose(file_id);
    file_id = fopen(log_file, 'a');
    fprintf('Stage2 block %d/%d, baseline %.6g, selected %.6g\n', ...
        block, block_count, baseline.ber, bps.ber);
end

summary = struct();
summary.pointCount = dbp.pointCount;
summary.baselineBer = mean(baseline_ber);
summary.baselineBerByLane = mean(baseline_lane, 1);
summary.baselineEvm = mean(baseline_evm, 1);
summary.fseBer = mean(fse_ber);
summary.fseBerByLane = mean(fse_lane, 1);
summary.fseEvm = mean(fse_evm, 1);
summary.bpsBer = mean(bps_ber);
summary.bpsBerByLane = mean(bps_lane, 1);
summary.bpsEvm = mean(bps_evm, 1);
fprintf(file_id, 'SUMMARY BASE=%g L=%s E=%s FSE=%g L=%s E=%s BPS=%g L=%s E=%s\n', ...
    summary.baselineBer, mat2str(summary.baselineBerByLane), ...
    mat2str(summary.baselineEvm), summary.fseBer, ...
    mat2str(summary.fseBerByLane), mat2str(summary.fseEvm), ...
    summary.bpsBer, mat2str(summary.bpsBerByLane), ...
    mat2str(summary.bpsEvm));
save(result_file, 'summary', 'baseline_ber', 'baseline_lane', ...
    'baseline_evm', 'fse_ber', 'fse_lane', 'fse_evm', ...
    'bps_ber', 'bps_lane', 'bps_evm', 'probes', ...
    'plot_equalized', 'plot_target', '-v7');
fclose(file_id);
exit;
