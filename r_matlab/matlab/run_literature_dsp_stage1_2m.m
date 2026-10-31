%RUN_LITERATURE_DSP_STAGE1_2M Compare causal widely-linear FSE candidates.
set(0, 'DefaultFigureVisible', 'off');
matlab_dir = smf_project_path('r_matlab','matlab');
data_dir = smf_project_path('r_matlab','data2');
addpath(matlab_dir);
capture_file = fullfile(data_dir, 'capture_330km_ber_pair.mat');
reference_file = fullfile(data_dir, 'rf47_reference_for_330km_capture.mat');
dbp_file = fullfile(data_dir, 'literature_stage1_dbp_2m.mat');
log_file = fullfile(data_dir, 'literature_stage1_2m.log');
result_file = fullfile(data_dir, 'literature_stage1_2m_result.mat');

loaded_capture = load(capture_file);
loaded_reference = load(reference_file);
capture = loaded_capture.pair.capture;
reference = loaded_reference.reference;
capture.channels = capture.channels(1:2000000, :);
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
    error('run_literature_dsp_stage1_2m:Log', ...
        'Cannot open the stage log file.');
end
cleanup = onCleanup(@() fclose(file_id));

tap_candidates = [7, 11, 15, 21];
candidate_count = numel(tap_candidates);
block_points = 250000;
block_count = floor(dbp.pointCount / block_points);
baseline_ber = nan(block_count, 1);
baseline_lane = nan(block_count, 4);
baseline_evm = nan(block_count, 2);
fse_ber = nan(block_count, candidate_count);
fse_lane = nan(block_count, candidate_count, 4);
fse_evm = nan(block_count, candidate_count, 2);
bps_joint_ber = nan(block_count, candidate_count);
bps_joint_lane = nan(block_count, candidate_count, 4);
bps_joint_evm = nan(block_count, candidate_count, 2);
bps_separate_ber = nan(block_count, candidate_count);
bps_separate_lane = nan(block_count, candidate_count, 4);
bps_separate_evm = nan(block_count, candidate_count, 2);
probes = cell(block_count, 1);
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
    baseline_ber(block) = baseline.ber;
    baseline_lane(block, :) = baseline.berByLane;
    baseline_evm(block, :) = baseline.evmRms;
    fprintf(file_id, ...
        'BLOCK=%d CFO=%g PH=%g SH=%g BASE BER=%g L=%s EVM=%s\n', ...
        block, probe.frequencyOffsetHz, probe.phase, probe.shift, ...
        baseline.ber, mat2str(baseline.berByLane), ...
        mat2str(baseline.evmRms));
    fprintf('Stage1 block %d/%d, baseline BER %.6g\n', ...
        block, block_count, baseline.ber);

    for candidate = 1:candidate_count
        taps = tap_candidates(candidate);
        fse = offline_reference_wl_fse(local, reference, probe, ...
            struct('symbolRateHz', 4e9, 'tapCount', taps, ...
            'trainSymbols', 512, 'outputSymbols', 8, ...
            'ridge', 1e-2, 'causal', false));
        joint = offline_joint_qpsk_bps(fse, ...
            struct('blockSymbols', 64, 'phaseCount', 81, ...
            'jointPolarizations', true));
        separate = offline_joint_qpsk_bps(fse, ...
            struct('blockSymbols', 64, 'phaseCount', 81, ...
            'jointPolarizations', false));
        fse_ber(block, candidate) = fse.ber;
        fse_lane(block, candidate, :) = fse.berByLane;
        fse_evm(block, candidate, :) = fse.evmRms;
        bps_joint_ber(block, candidate) = joint.ber;
        bps_joint_lane(block, candidate, :) = joint.berByLane;
        bps_joint_evm(block, candidate, :) = joint.evmRms;
        bps_separate_ber(block, candidate) = separate.ber;
        bps_separate_lane(block, candidate, :) = separate.berByLane;
        bps_separate_evm(block, candidate, :) = separate.evmRms;
        fprintf(file_id, ...
            ['BLOCK=%d TAPS=%d FSE=%g JL=%g SL=%g FSE_L=%s ' ...
            'J_L=%s S_L=%s FSE_E=%s J_E=%s S_E=%s\n'], ...
            block, taps, fse.ber, joint.ber, separate.ber, ...
            mat2str(fse.berByLane), mat2str(joint.berByLane), ...
            mat2str(separate.berByLane), mat2str(fse.evmRms), ...
            mat2str(joint.evmRms), mat2str(separate.evmRms));
    end
end

summary = struct();
summary.tapCandidates = tap_candidates;
summary.baselineBer = mean(baseline_ber);
summary.baselineBerByLane = mean(baseline_lane, 1);
summary.baselineEvm = mean(baseline_evm, 1);
summary.fseBer = mean(fse_ber, 1);
summary.fseBerByLane = squeeze(mean(fse_lane, 1));
summary.fseEvm = squeeze(mean(fse_evm, 1));
summary.jointBpsBer = mean(bps_joint_ber, 1);
summary.jointBpsBerByLane = squeeze(mean(bps_joint_lane, 1));
summary.jointBpsEvm = squeeze(mean(bps_joint_evm, 1));
summary.separateBpsBer = mean(bps_separate_ber, 1);
summary.separateBpsBerByLane = squeeze(mean(bps_separate_lane, 1));
summary.separateBpsEvm = squeeze(mean(bps_separate_evm, 1));
fprintf(file_id, 'SUMMARY BASE BER=%g L=%s EVM=%s\n', ...
    summary.baselineBer, mat2str(summary.baselineBerByLane), ...
    mat2str(summary.baselineEvm));
for candidate = 1:candidate_count
    fprintf(file_id, ...
        ['SUMMARY TAPS=%d FSE=%g JOINT=%g SEPARATE=%g ' ...
        'FSE_L=%s J_L=%s S_L=%s FSE_E=%s J_E=%s S_E=%s\n'], ...
        tap_candidates(candidate), summary.fseBer(candidate), ...
        summary.jointBpsBer(candidate), ...
        summary.separateBpsBer(candidate), ...
        mat2str(summary.fseBerByLane(candidate, :)), ...
        mat2str(summary.jointBpsBerByLane(candidate, :)), ...
        mat2str(summary.separateBpsBerByLane(candidate, :)), ...
        mat2str(summary.fseEvm(candidate, :)), ...
        mat2str(summary.jointBpsEvm(candidate, :)), ...
        mat2str(summary.separateBpsEvm(candidate, :)));
end
save(result_file, 'summary', 'baseline_ber', 'baseline_lane', ...
    'baseline_evm', 'fse_ber', 'fse_lane', 'fse_evm', ...
    'bps_joint_ber', 'bps_joint_lane', 'bps_joint_evm', ...
    'bps_separate_ber', 'bps_separate_lane', ...
    'bps_separate_evm', 'probes', '-v7');
clear cleanup;
exit;
