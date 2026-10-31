function summary = compare_and_save_results(objects, references, frames, ...
    recovery, packing, pipeline_stats, result_dir, cfg)
%COMPARE_AND_SAVE_RESULTS Compare known bytes and write recovered artifacts.

if exist(result_dir, 'dir') ~= 7
    mkdir(result_dir);
end

row_template = struct('datasetType', 0, 'datasetCycle', 0, 'objectId', 0, ...
    'receivedBytes', 0, 'totalBytes', 0, 'coverage', 0, ...
    'bitErrors', 0, 'comparedBits', 0, 'ber', NaN, ...
    'conflictBytes', 0, 'transportCrcOk', false, 'objectCrcOk', false);
rows = repmat(row_template, numel(objects), 1);

image_candidates = [];
waveform_candidates = [];
for object_index = 1:numel(objects)
    reference = reference_bytes(objects(object_index), references);
    mask = objects(object_index).validMask;
    compared = min(numel(reference), numel(mask));
    mask = mask(1:compared);
    actual = objects(object_index).data(1:compared);
    expected = reference(1:compared);
    difference = bitxor(actual(mask), expected(mask));
    bit_errors = population_count(difference);
    compared_bits = 8 * sum(mask);

    rows(object_index).datasetType = double(objects(object_index).datasetType);
    rows(object_index).datasetCycle = double(objects(object_index).datasetCycle);
    rows(object_index).objectId = double(objects(object_index).objectId);
    rows(object_index).receivedBytes = sum(mask);
    rows(object_index).totalBytes = numel(reference);
    rows(object_index).coverage = sum(mask) / max(1, numel(reference));
    rows(object_index).bitErrors = bit_errors;
    rows(object_index).comparedBits = compared_bits;
    if compared_bits > 0
        rows(object_index).ber = bit_errors / compared_bits;
    end
    rows(object_index).conflictBytes = objects(object_index).conflictBytes;
    rows(object_index).transportCrcOk = objects(object_index).allTransportCrcOk;
    if all(mask) && numel(reference) == numel(objects(object_index).data)
        rows(object_index).objectCrcOk = ...
            crc32_reflected(objects(object_index).data) == ...
            objects(object_index).objectCrc32;
    end

    if rows(object_index).datasetType == 1 && rows(object_index).receivedBytes > 0
        image_candidates(end + 1) = object_index; %#ok<AGROW>
    elseif rows(object_index).datasetType == 2 && rows(object_index).receivedBytes > 0
        waveform_candidates(end + 1) = object_index; %#ok<AGROW>
    end
end

write_summary_csv(fullfile(result_dir, 'ber_summary.csv'), rows);
write_image_results(objects, rows, image_candidates, references, result_dir, cfg);
write_waveform_result(objects, rows, waveform_candidates, references, result_dir);
write_diagnostics(fullfile(result_dir, 'diagnostics.txt'), frames, recovery, ...
    packing, pipeline_stats, rows);

summary.rows = rows;
summary.image = aggregate_type(rows, 1);
summary.waveform = aggregate_type(rows, 2);
summary.resultDirectory = result_dir;
end

function reference = reference_bytes(object, references)
if object.datasetType == 1 && object.objectId >= 1 && object.objectId <= 45
    reference = references.images{double(object.objectId)};
elseif object.datasetType == 2 && object.objectId == 1
    reference = references.waveformBytes;
else
    reference = zeros(double(object.objectLength), 1, 'uint8');
end
reference = uint8(reference(:));
end

function count = population_count(bytes)
count = 0;
for bit_index = 1:8
    count = count + sum(bitget(uint8(bytes), bit_index));
end
end

function result = aggregate_type(rows, dataset_type)
selected = find([rows.datasetType] == dataset_type);
result.objectCount = numel(selected);
result.receivedBytes = sum([rows(selected).receivedBytes]);
result.totalBytes = sum([rows(selected).totalBytes]);
result.bitErrors = sum([rows(selected).bitErrors]);
result.comparedBits = sum([rows(selected).comparedBits]);
if result.comparedBits > 0
    result.ber = result.bitErrors / result.comparedBits;
    if result.bitErrors == 0
        result.berUpper95 = 3 / result.comparedBits;
    else
        result.berUpper95 = NaN;
    end
else
    result.ber = NaN;
    result.berUpper95 = NaN;
end
end

function write_summary_csv(file_path, rows)
file_id = fopen(file_path, 'w');
if file_id < 0
    error('compare_and_save_results:SummaryOpen', ...
        'Cannot create %s.', file_path);
end
cleanup = onCleanup(@() fclose(file_id));
fprintf(file_id, ['dataset_type,dataset_cycle,object_id,received_bytes,' ...
    'total_bytes,coverage,bit_errors,compared_bits,ber,conflict_bytes,' ...
    'transport_crc_ok,object_crc_ok\n']);
for index = 1:numel(rows)
    fprintf(file_id, '%d,%u,%d,%d,%d,%.12g,%d,%d,%.12g,%d,%d,%d\n', ...
        rows(index).datasetType, rows(index).datasetCycle, ...
        rows(index).objectId, rows(index).receivedBytes, ...
        rows(index).totalBytes, rows(index).coverage, ...
        rows(index).bitErrors, rows(index).comparedBits, rows(index).ber, ...
        rows(index).conflictBytes, rows(index).transportCrcOk, ...
        rows(index).objectCrcOk);
end
clear cleanup;
end

function write_image_results(objects, rows, candidates, references, result_dir, cfg)
if isempty(candidates)
    return;
end
[~, order] = sort([rows(candidates).coverage], 'descend');
candidates = candidates(order);
count = min(numel(candidates), cfg.maximumImagesToWrite);
for rank = 1:count
    index = candidates(rank);
    object_id = double(objects(index).objectId);
    bytes = objects(index).data;
    mask = objects(index).validMask;
    expected_bytes = references.imageWidth * references.imageHeight * 3;
    if object_id < 1 || object_id > numel(references.images) || ...
            numel(bytes) ~= expected_bytes || numel(mask) ~= expected_bytes
        continue;
    end
    bytes(~mask) = 0;
    rgb_rows = reshape(bytes, 3, []).';
    valid_rows = reshape(mask, 3, []).';
    valid_pixels = all(valid_rows, 2);
    image = zeros(references.imageHeight, references.imageWidth, 3, 'uint8');
    for component = 1:3
        image(:, :, component) = reshape(rgb_rows(:, component), ...
            [references.imageWidth, references.imageHeight]).';
    end
    mask_image = reshape(uint8(valid_pixels) * 255, ...
        [references.imageWidth, references.imageHeight]).';
    base_name = sprintf('recovered_image_%02d_cycle_%u', object_id, ...
        uint32(objects(index).datasetCycle));
    imwrite(image, fullfile(result_dir, [base_name '_partial.png']));
    imwrite(mask_image, fullfile(result_dir, [base_name '_mask.png']));
end
end

function write_waveform_result(objects, rows, candidates, references, result_dir)
if isempty(candidates)
    return;
end
[~, local_best] = max([rows(candidates).coverage]);
index = candidates(local_best);
bytes = objects(index).data;
mask_bytes = objects(index).validMask;
sample_count = floor(numel(bytes) / 2);
high = uint16(bytes(1:2:2 * sample_count));
low = uint16(bytes(2:2:2 * sample_count));
unsigned = bitshift(high, 8) + low;
recovered = double(unsigned);
negative = recovered >= 32768;
recovered(negative) = recovered(negative) - 65536;
valid = mask_bytes(1:2:2 * sample_count) & mask_bytes(2:2:2 * sample_count);
reference = double(references.waveformSamples(1:sample_count));

csv_path = fullfile(result_dir, 'recovered_waveform.csv');
file_id = fopen(csv_path, 'w');
if file_id < 0
    error('compare_and_save_results:WaveformOpen', ...
        'Cannot create %s.', csv_path);
end
cleanup = onCleanup(@() fclose(file_id));
fprintf(file_id, 'sample_index,time_s,recovered,reference,valid\n');
for sample_index = 1:sample_count
    fprintf(file_id, '%d,%.9f,%d,%d,%d\n', sample_index - 1, ...
        (sample_index - 1) / references.waveformSampleRateHz, ...
        recovered(sample_index), reference(sample_index), valid(sample_index));
end
clear cleanup;

try
    figure_handle = figure('Visible', 'off');
    time = (0:sample_count - 1) / references.waveformSampleRateHz;
    plot(time, reference, 'k-');
    hold on;
    recovered_plot = recovered;
    recovered_plot(~valid) = NaN;
    plot(time, recovered_plot, 'r-');
    xlabel('Time (s)');
    ylabel('Amplitude (int16)');
    legend('Reference', 'Recovered');
    grid on;
    print(figure_handle, fullfile(result_dir, 'recovered_waveform.png'), ...
        '-dpng', '-r150');
    close(figure_handle);
catch plot_error
    warning('compare_and_save_results:PlotFailed', ...
        'Waveform CSV was written, but plotting failed: %s', plot_error.message);
end
end

function write_diagnostics(file_path, frames, recovery, packing, pipeline_stats, rows)
file_id = fopen(file_path, 'w');
if file_id < 0
    error('compare_and_save_results:DiagnosticsOpen', ...
        'Cannot create %s.', file_path);
end
cleanup = onCleanup(@() fclose(file_id));
fprintf(file_id, 'RF47 offline receiver diagnostics\n');
fprintf(file_id, 'sample_rate_hz=%.12g\n', recovery.sampleRateHz);
fprintf(file_id, 'samples_per_symbol=%.9f\n', recovery.samplesPerSymbol);
if isfield(recovery, 'chunkTimingPhaseSymbols')
    if isfield(recovery, 'timingTracking')
        fprintf(file_id, 'timing_tracking=%s\n', recovery.timingTracking);
    else
        fprintf(file_id, 'timing_tracking=segmented\n');
    end
    if isfield(recovery, 'clockOffsetPpm')
        fprintf(file_id, 'clock_offset_ppm=%.12g\n', ...
            recovery.clockOffsetPpm);
        fprintf(file_id, 'estimated_symbol_rate_hz=%.12g\n', ...
            recovery.estimatedSymbolRateHz);
        fprintf(file_id, 'effective_samples_per_symbol=%.12g\n', ...
            recovery.effectiveSamplesPerSymbol);
        fprintf(file_id, 'cdr_anchor_residual_rms_ui=%.12g\n', ...
            recovery.cdrAnchorResidualRmsUi);
        fprintf(file_id, 'cdr_tracked_residual_rms_ui=%.12g\n', ...
            recovery.cdrTrackedResidualRmsUi);
    end
    if isfield(recovery, 'equalizer')
        equalizer = recovery.equalizer;
        fprintf(file_id, 'post_equalizer_enabled=%d\n', ...
            isfield(equalizer, 'enabled') && equalizer.enabled);
        fprintf(file_id, 'post_equalizer_accepted=%d\n', ...
            isfield(equalizer, 'accepted') && equalizer.accepted);
        if isfield(equalizer, 'preCrcGood')
            fprintf(file_id, 'post_equalizer_crc_good=%d,%d\n', ...
                equalizer.preCrcGood, equalizer.postCrcGood);
            fprintf(file_id, 'post_equalizer_frame_count=%d,%d\n', ...
                equalizer.preFrameCount, equalizer.postFrameCount);
        end
        if isfield(equalizer, 'selectedTapLength')
            fprintf(file_id, 'post_equalizer_tap_lengths=%d,%d,%d,%d\n', ...
                equalizer.selectedTapLength);
            fprintf(file_id, 'post_equalizer_mse_improvement=%.9g,%.9g,%.9g,%.9g\n', ...
                equalizer.validationMseImprovement);
            for lane = 1:4
                fprintf(file_id, 'post_equalizer_taps_%d=', lane);
                fprintf(file_id, '%.12g,', equalizer.taps(1:end - 1, lane));
                fprintf(file_id, '%.12g\n', equalizer.taps(end, lane));
            end
        end
    end
    fprintf(file_id, 'timing_chunks=%d\n', recovery.chunkCount);
    fprintf(file_id, 'timing_chunks_processed=%d\n', ...
        sum(recovery.chunkProcessed));
    fprintf(file_id, 'chunk_frames=%d\n', ...
        sum(recovery.chunkFrameCount));
    fprintf(file_id, 'chunk_crc_good=%d\n', ...
        sum(recovery.chunkCrcGood));
    fprintf(file_id, 'chunk_crc_rate=%.12g\n', ...
        sum(recovery.chunkCrcGood) / max(1, ...
        sum(recovery.chunkFrameCount)));
    for chunk_index = 1:recovery.chunkCount
        if ~recovery.chunkProcessed(chunk_index)
            fprintf(file_id, 'chunk_%02d=skipped,%s\n', chunk_index, ...
                recovery.chunkErrorId{chunk_index});
            continue;
        end
        time_seconds = (recovery.chunkStartPoints(chunk_index) - 1) / ...
            recovery.sampleRateHz;
        fprintf(file_id, ...
            ['chunk_%02d=time_s=%.9g,phases=%.6f,%.6f,%.6f,%.6f,' ...
            'sync_errors=%.6g,%.6g,%.6g,%.6g,frames=%d,' ...
            'crc_good=%d,lane_offsets=%d,%d,%d,%d\n'], ...
            chunk_index, time_seconds, ...
            recovery.chunkTimingPhaseSymbols(chunk_index, :), ...
            recovery.chunkSyncErrorRates(chunk_index, :), ...
            recovery.chunkFrameCount(chunk_index), ...
            recovery.chunkCrcGood(chunk_index), ...
            packing.chunkLaneSymbolOffsets(chunk_index, :));
    end
else
    fprintf(file_id, 'timing_tracking=fixed\n');
    fprintf(file_id, 'timing_phase_symbols=%.9f,%.9f,%.9f,%.9f\n', ...
        recovery.timingPhaseSymbols);
end
fprintf(file_id, 'recovered_symbols=%d\n', recovery.symbolCount);
fprintf(file_id, 'lane_polarity=%d,%d,%d,%d\n', packing.lanePolarity);
if isfield(packing, 'laneSymbolOffsets')
    fprintf(file_id, 'lane_symbol_offsets=%d,%d,%d,%d\n', ...
        packing.laneSymbolOffsets);
end
if isfield(packing, 'laneSyncErrorRates')
    fprintf(file_id, 'lane_sync_error_rates=%.9g,%.9g,%.9g,%.9g\n', ...
        packing.laneSyncErrorRates);
end
fprintf(file_id, 'nibble_offset=%d\n', packing.nibbleOffset);
fprintf(file_id, 'aggregate_frames=%d\n', frames.frameCount);
fprintf(file_id, 'aggregate_crc_good=%d\n', sum(frames.crcOk));
fprintf(file_id, 'aggregate_crc_bad=%d\n', sum(~frames.crcOk));
fprintf(file_id, 'aggregate_header_good=%d\n', sum(frames.headerOk));
fprintf(file_id, 'udp_packets=%d\n', pipeline_stats.udp.packetCount);
fprintf(file_id, 'axds_packets=%d\n', pipeline_stats.axds.validPacketCount);
fprintf(file_id, 'objects=%d\n', numel(rows));
clear cleanup;
end

function value = crc32_reflected(bytes)
persistent table;
if isempty(table)
    polynomial = uint32(hex2dec('EDB88320'));
    table = zeros(256, 1, 'uint32');
    for table_index = 0:255
        crc = uint32(table_index);
        for bit_index = 1:8
            if bitand(crc, uint32(1))
                crc = bitxor(bitshift(crc, -1), polynomial);
            else
                crc = bitshift(crc, -1);
            end
        end
        table(table_index + 1) = crc;
    end
end
crc = uint32(hex2dec('FFFFFFFF'));
for index = 1:numel(bytes)
    table_index = bitand(bitxor(crc, uint32(bytes(index))), uint32(255));
    crc = bitxor(bitshift(crc, -8), table(double(table_index) + 1));
end
value = bitcmp(crc);
end
