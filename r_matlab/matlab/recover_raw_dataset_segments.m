function [summary, details] = recover_raw_dataset_segments( ...
    segments, references, result_dir, cfg)
%RECOVER_RAW_DATASET_SEGMENTS Match headerless payload fragments to references.

if exist(result_dir, 'dir') ~= 7
    mkdir(result_dir);
end
reference_sets = {vertcat(references.images{:}), references.waveformBytes(:)};
matched = zeros(1, 2);
matched_crc_good = zeros(1, 2);
matched_crc_bad = zeros(1, 2);
compared_bits = zeros(1, 2);
bit_errors = zeros(1, 2);
conflict_bytes = zeros(1, 2);
coverage_masks = {false(numel(reference_sets{1}), 1), ...
    false(numel(reference_sets{2}), 1)};
recovered_data = {zeros(numel(reference_sets{1}), 1, 'uint8'), ...
    zeros(numel(reference_sets{2}), 1, 'uint8')};

segment_order = [find(segments.frameCrcOk); find(~segments.frameCrcOk)];
for order_index = 1:numel(segment_order)
    segment_index = segment_order(order_index);
    if ~segments.frameCrcOk(segment_index) && ~cfg.useBadCrcSegments
        continue;
    end
    port = double(segments.portId(segment_index));
    if port < 1 || port > 2
        continue;
    end
    payload = uint8(segments.payload{segment_index}(:));
    if numel(payload) < 16 || ...
            all(payload(1:4) == uint8('AXDS').')
        continue;
    end

    reference = reference_sets{port};
    positions = strfind(reference(:).', payload(1:16).');
    if isempty(positions)
        continue;
    end
    [start_position, errors] = best_reference_match( ...
        payload, reference, positions);

    matched(port) = matched(port) + 1;
    if segments.frameCrcOk(segment_index)
        matched_crc_good(port) = matched_crc_good(port) + 1;
    else
        matched_crc_bad(port) = matched_crc_bad(port) + 1;
    end
    compared_bits(port) = compared_bits(port) + 8 * numel(payload);
    bit_errors(port) = bit_errors(port) + errors;

    target = mod((start_position - 1) + (0:numel(payload) - 1), ...
        numel(reference)) + 1;
    target = target(:);
    already_valid = coverage_masks{port}(target);
    if any(already_valid)
        old_data = recovered_data{port}(target(already_valid));
        new_data = payload(already_valid);
        conflict_bytes(port) = conflict_bytes(port) + ...
            sum(old_data ~= new_data);
    end
    write_new = ~already_valid;
    recovered_data{port}(target(write_new)) = payload(write_new);
    coverage_masks{port}(target) = true;
end

summary.image = make_summary(matched(1), matched_crc_good(1), ...
    matched_crc_bad(1), compared_bits(1), bit_errors(1), ...
    coverage_masks{1}, conflict_bytes(1), 45);
summary.waveform = make_summary(matched(2), matched_crc_good(2), ...
    matched_crc_bad(2), compared_bits(2), bit_errors(2), ...
    coverage_masks{2}, conflict_bytes(2), 1);
details.coverageMasks = coverage_masks;
details.recoveredData = recovered_data;

write_summary(fullfile(result_dir, 'raw_segment_ber_summary.csv'), summary);
write_partial_images(recovered_data{1}, coverage_masks{1}, references, ...
    result_dir, cfg);
write_partial_waveform(recovered_data{2}, coverage_masks{2}, references, ...
    result_dir);
save(fullfile(result_dir, 'raw_segment_recovery.mat'), ...
    'summary', 'details', '-v7.3');
end

function [best_position, best_errors] = best_reference_match( ...
    payload, reference, positions)
best_position = 0;
best_errors = inf;
for position_index = 1:numel(positions)
    start_position = positions(position_index);
    indices = mod((start_position - 1) + (0:numel(payload) - 1), ...
        numel(reference)) + 1;
    expected = reference(indices);
    difference = bitxor(payload, expected(:));
    errors = population_count(difference);
    if errors < best_errors
        best_errors = errors;
        best_position = start_position;
    end
end
end

function count = population_count(bytes)
count = 0;
for bit_index = 1:8
    count = count + sum(bitget(uint8(bytes), bit_index));
end
end

function result = make_summary(matched, crc_good, crc_bad, compared_bits, ...
    bit_errors, coverage_mask, conflict_bytes, object_count)
result.objectCount = object_count;
result.matchedSegments = matched;
result.crcGoodSegments = crc_good;
result.crcBadSegments = crc_bad;
result.receivedBytes = sum(coverage_mask);
result.totalBytes = numel(coverage_mask);
result.coverage = result.receivedBytes / max(1, result.totalBytes);
result.bitErrors = bit_errors;
result.comparedBits = compared_bits;
result.conflictBytes = conflict_bytes;
if compared_bits > 0
    result.ber = bit_errors / compared_bits;
else
    result.ber = NaN;
end
if compared_bits > 0 && bit_errors == 0
    result.berUpper95 = 3 / compared_bits;
else
    result.berUpper95 = NaN;
end
end

function write_summary(file_path, summary)
file_id = fopen(file_path, 'w');
if file_id < 0
    error('recover_raw_dataset_segments:SummaryOpen', ...
        'Cannot create %s.', file_path);
end
cleanup = onCleanup(@() fclose(file_id));
fprintf(file_id, ['dataset,matched_segments,crc_good_segments,' ...
    'crc_bad_segments,unique_bytes,total_bytes,coverage,bit_errors,' ...
    'compared_bits,ber,conflict_bytes\n']);
write_summary_row(file_id, 'image', summary.image);
write_summary_row(file_id, 'waveform', summary.waveform);
clear cleanup;
end

function write_summary_row(file_id, name, result)
fprintf(file_id, '%s,%d,%d,%d,%d,%d,%.12g,%d,%d,%.12g,%d\n', ...
    name, result.matchedSegments, result.crcGoodSegments, ...
    result.crcBadSegments, result.receivedBytes, result.totalBytes, ...
    result.coverage, result.bitErrors, result.comparedBits, result.ber, ...
    result.conflictBytes);
end

function write_partial_images(data, mask, references, result_dir, cfg)
image_bytes = references.imageWidth * references.imageHeight * 3;
coverage = zeros(45, 1);
for image_id = 1:45
    range = (image_id - 1) * image_bytes + (1:image_bytes);
    coverage(image_id) = sum(mask(range)) / image_bytes;
end
[~, order] = sort(coverage, 'descend');
count = min(cfg.maximumImagesToWrite, sum(coverage > 0));
for rank = 1:count
    image_id = order(rank);
    range = (image_id - 1) * image_bytes + (1:image_bytes);
    bytes = data(range);
    valid_bytes = mask(range);
    bytes(~valid_bytes) = 0;
    rgb_rows = reshape(bytes, 3, []).';
    image = zeros(references.imageHeight, references.imageWidth, 3, 'uint8');
    valid_rows = reshape(valid_bytes, 3, []).';
    valid_pixels = all(valid_rows, 2);
    for component = 1:3
        image(:, :, component) = reshape(rgb_rows(:, component), ...
            [references.imageWidth, references.imageHeight]).';
    end
    mask_image = reshape(uint8(valid_pixels) * 255, ...
        [references.imageWidth, references.imageHeight]).';
    imwrite(image, fullfile(result_dir, sprintf( ...
        'raw_recovered_image_%02d_partial.png', image_id)));
    imwrite(mask_image, fullfile(result_dir, sprintf( ...
        'raw_recovered_image_%02d_mask.png', image_id)));
end
end

function write_partial_waveform(data, mask, references, result_dir)
sample_count = floor(numel(data) / 2);
high = uint16(data(1:2:2 * sample_count));
low = uint16(data(2:2:2 * sample_count));
recovered = double(bitshift(high, 8) + low);
negative = recovered >= 32768;
recovered(negative) = recovered(negative) - 65536;
valid = mask(1:2:2 * sample_count) & mask(2:2:2 * sample_count);
reference = double(references.waveformSamples(1:sample_count));

file_path = fullfile(result_dir, 'raw_recovered_waveform.csv');
file_id = fopen(file_path, 'w');
if file_id < 0
    error('recover_raw_dataset_segments:WaveformOpen', ...
        'Cannot create %s.', file_path);
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
    plot(time, reference, 'Color', [0.65, 0.65, 0.65]);
    hold on;
    recovered_plot = recovered;
    recovered_plot(~valid) = NaN;
    plot(time, recovered_plot, 'r-');
    xlabel('Time (s)');
    ylabel('Amplitude (int16)');
    legend('Reference', 'Recovered');
    grid on;
    print(figure_handle, fullfile(result_dir, ...
        'raw_recovered_waveform.png'), '-dpng', '-r150');
    close(figure_handle);
catch plot_error
    warning('recover_raw_dataset_segments:PlotFailed', ...
        'Waveform CSV was written, but plotting failed: %s', ...
        plot_error.message);
end
end
