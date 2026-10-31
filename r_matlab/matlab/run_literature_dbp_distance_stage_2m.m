%RUN_LITERATURE_DBP_DISTANCE_STAGE_2M Probe DBP distance on one 250k block.
set(0, 'DefaultFigureVisible', 'off');
matlab_dir = smf_project_path('r_matlab','matlab');
data_dir = smf_project_path('r_matlab','data2');
addpath(matlab_dir);
raw = load(fullfile(data_dir, 'capture_330km_ber_pair.mat'));
raw = raw.pair.capture;
reference = load(fullfile(data_dir, ...
    'rf47_reference_for_330km_capture.mat'));
reference = reference.reference;
raw.channels = raw.channels(1:2000000, :);
raw.pointCount = size(raw.channels, 1);
distances = [-6000, -6500, -7000, -7250, -7500, -8000, -8500];
block_points = 250000;
ber = nan(numel(distances), 1);
lane = nan(numel(distances), 4);
evm = nan(numel(distances), 2);
file_id = fopen(fullfile(data_dir, 'literature_dbp_distance_stage_2m.log'), 'w');
if file_id < 0
    error('run_literature_dbp_distance_stage_2m:Log', 'Cannot open log.');
end
cleanup = onCleanup(@() fclose(file_id));
for index = 1:numel(distances)
    dbp = offline_dbp_ssfm_trial(raw, distances(index), 0.01, 8, ...
        struct('passbandHz', 2.6e9, 'stopbandHz', 3.4e9));
    local = dbp;
    local.channels = dbp.channels(1:block_points, :);
    local.pointCount = block_points;
    probe = offline_reference_cfo_scan(local, reference, ...
        struct('symbolRateHz', 4e9, ...
        'cfoGridHz', (-538:0.5:-524) * 1e6, ...
        'searchPeriods', 2, 'probeSymbols', 2048));
    fse = offline_reference_wl_fse(local, reference, probe, ...
        struct('symbolRateHz', 4e9, 'tapCount', 7, ...
        'trainSymbols', 1024, 'outputSymbols', 8, 'ridge', 0.1, ...
        'causal', false, 'fractionalSampleOffset', -1.75));
    bps = offline_joint_qpsk_bps(fse, ...
        struct('blockSymbols', 64, 'phaseCount', 321, ...
        'jointPolarizations', true));
    ber(index) = bps.ber;
    lane(index, :) = bps.berByLane;
    evm(index, :) = bps.evmRms;
    fprintf(file_id, 'D=%g BER=%g L=%s E=%s CFO=%g PH=%g SH=%g\n', ...
        distances(index), bps.ber, mat2str(bps.berByLane), ...
        mat2str(bps.evmRms), probe.frequencyOffsetHz, probe.phase, ...
        probe.shift);
    fprintf('DBP distance %g, BER %.6g\n', distances(index), bps.ber);
end
[best_ber, best_index] = min(ber);
summary = struct();
summary.distances = distances;
summary.ber = ber;
summary.berByLane = lane;
summary.evm = evm;
summary.bestDistance = distances(best_index);
summary.bestBer = best_ber;
fprintf(file_id, 'SUMMARY BEST_DISTANCE=%g BEST_BER=%g\n', ...
    summary.bestDistance, summary.bestBer);
save(fullfile(data_dir, 'literature_dbp_distance_stage_2m_result.mat'), ...
    'summary', 'ber', 'lane', 'evm', '-v7');
clear cleanup;
exit;
