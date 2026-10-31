function report = offline_analyze_330km_data2()
%OFFLINE_ANALYZE_330KM_DATA2 Analyze explicit RigolDS RG03 files offline.
script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);
project_dir = fileparts(script_dir);
data_dir = fullfile(project_dir, 'data2');
dataset_dir = fullfile(project_dir, 'dataset2');
result_dir = fullfile(data_dir, 'offline_330km_result');
if exist(result_dir, 'dir') ~= 7
    mkdir(result_dir);
end
cfg = rf47_default_config(script_dir);
cfg.dataDir = data_dir;
cfg.datasetDir = dataset_dir;
references = load_reference_dataset(dataset_dir);
capture = load_rigol_rg03_set(data_dir, 'RigolDS');
dispersion = -6000;
passband = 2.8e9;
stopband = 3.5e9;
chunk_points = 1000000;
chunk_count = ceil(capture.pointCount / chunk_points);
frame_stream = uint8([]);
chunk_reports = repmat(struct('frames', 0, 'crcGood', 0, ...
    'crcBad', 0, 'bytes', 0, 'evm', [NaN NaN]), 1, chunk_count);
for index = 1:chunk_count
    first = (index - 1) * chunk_points + 1;
    last = min(capture.pointCount, index * chunk_points);
    block = capture;
    block.channels = capture.channels(first:last, :);
    block.pointCount = size(block.channels, 1);
    block = offline_apply_dispersion(block, dispersion, ...
        struct('passbandHz', passband, 'stopbandHz', stopband));
    [bytes, cma, ~] = offline_try_capture_local_cma(block, cfg, true);
    chunk_reports(index).bytes = numel(bytes);
    if isempty(bytes)
        fprintf('Chunk %d/%d: no bytes\n', index, chunk_count);
        continue;
    end
    try
        [frames, ~] = parse_aggregate_frames_relocked(bytes, cfg);
        frame_stream = [frame_stream; frames.bytes(:)]; %#ok<AGROW>
        chunk_reports(index).frames = frames.frameCount;
        chunk_reports(index).crcGood = sum(frames.crcOk);
        chunk_reports(index).crcBad = sum(~frames.crcOk);
        if isfield(cma, 'evmRms')
            chunk_reports(index).evm = cma.evmRms;
        end
        fprintf('Chunk %d/%d: frames=%d good=%d bad=%d EVM=%.4f/%.4f\n', ...
            index, chunk_count, frames.frameCount, sum(frames.crcOk), ...
            sum(~frames.crcOk), chunk_reports(index).evm(1), ...
            chunk_reports(index).evm(2));
    catch exception
        fprintf('Chunk %d/%d parse failed: %s\n', index, chunk_count, ...
            exception.message);
    end
end
parser_cfg = cfg;
parser_cfg.useBadCrcSegments = true;
[frames, segments] = parse_aggregate_frames_relocked(frame_stream, parser_cfg);
[packets, udp_stats] = reassemble_udp_packets(segments, frames, parser_cfg);
[axds, axds_stats] = parse_axds_packets(packets, parser_cfg);
[objects, object_stats] = reassemble_axds_objects(axds);
state = struct('frames', frames, 'segments', segments, 'packets', packets, ...
    'objects', objects, 'lastDecodedBytes', numel(frame_stream), ...
    'udpStats', udp_stats, 'axdsStats', axds_stats, ...
    'objectStats', object_stats);
decoded = offline_make_decode_result(state, references);
idle = offline_summarize_idle_frames(frames, cfg);
report = struct('capture', capture, 'dispersionPsNm', dispersion, ...
    'passbandHz', passband, 'stopbandHz', stopband, ...
    'chunkReports', chunk_reports, 'state', state, ...
    'decoded', decoded, 'idleFrame', idle);
save(fullfile(result_dir, 'offline_330km_report.mat'), 'report', '-v7.3');
file_id = fopen(fullfile(result_dir, 'summary.txt'), 'w');
if file_id >= 0
    fprintf(file_id, 'D=%.0f ps/nm, BW=%.3f/%.3f GHz\n', dispersion, ...
        passband / 1e9, stopband / 1e9);
    fprintf(file_id, 'Frames=%d CRCgood=%d CRCbad=%d Objects=%d\n', ...
        decoded.frameCount, decoded.crcGoodFrames, decoded.crcBadFrames, ...
        decoded.objectCount);
    fprintf(file_id, 'PRBS31 BER=%.12e (%d/%d bits)\n', idle.ber, ...
        idle.bitErrors, idle.comparedBits);
    fclose(file_id);
end
fprintf('Final frames=%d good=%d bad=%d objects=%d\n', decoded.frameCount, ...
    decoded.crcGoodFrames, decoded.crcBadFrames, decoded.objectCount);
fprintf('Image coverage=%.6f BER=%.12e\n', decoded.image.coverage, ...
    decoded.image.ber);
fprintf('Wave coverage=%.6f BER=%.12e\n', decoded.waveform.coverage, ...
    decoded.waveform.ber);
fprintf('PRBS31 BER=%.12e (%d/%d bits)\n', idle.ber, idle.bitErrors, ...
    idle.comparedBits);
end
