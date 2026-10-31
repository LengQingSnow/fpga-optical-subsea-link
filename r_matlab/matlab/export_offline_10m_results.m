function summary = export_offline_10m_results()
%EXPORT_OFFLINE_10M_RESULTS Export recovered objects and PRBS31 BER.
script_dir = fileparts(mfilename('fullpath'));
data_dir = fullfile(fileparts(script_dir), 'data2');
result_dir = fullfile(data_dir, 'offline_optical_result_10m_20260820');
workspace_file = fullfile(data_dir, 'offline_10m_workspace.mat');
loaded = load(workspace_file, 'report');
report = loaded.report;
cfg = rf47_default_config(script_dir);

idle_mask = report.state.frames.flags == 6;
idle_frames = subset_frames(report.state.frames, idle_mask);
prbs = offline_summarize_idle_frames(idle_frames, cfg);

image_file = fullfile(result_dir, 'underwater_image_partial.png');
image_mask_file = fullfile(result_dir, 'underwater_image_coverage.png');
waveform_file = fullfile(result_dir, 'earthquake_waveform_partial.png');
waveform_data_file = fullfile(result_dir, 'earthquake_waveform_partial.csv');

if report.decoded.image.available
    write_partial_image(report.decoded.image, image_file, image_mask_file);
end
if report.decoded.waveform.available
    write_partial_waveform(report.decoded.waveform, waveform_file, ...
        waveform_data_file);
end

summary = struct();
summary.frameCount = report.decoded.frameCount;
summary.crcGoodFrames = report.decoded.crcGoodFrames;
summary.crcBadFrames = report.decoded.crcBadFrames;
summary.prbs = prbs;
summary.image = report.decoded.image;
summary.waveform = report.decoded.waveform;
save(fullfile(result_dir, 'offline_10m_summary.mat'), 'summary');

summary_file = fullfile(result_dir, 'offline_10m_summary.txt');
file_id = fopen(summary_file, 'w');
if file_id < 0
    error('export_offline_10m_results:SummaryOpen', ...
        'Cannot open summary output file.');
end
cleanup = onCleanup(@() fclose(file_id));
fprintf(file_id, 'Frames: %d\n', summary.frameCount);
fprintf(file_id, 'CRC good: %d\n', summary.crcGoodFrames);
fprintf(file_id, 'CRC bad: %d\n', summary.crcBadFrames);
fprintf(file_id, 'PRBS31 idle frames: %d\n', prbs.frameCount);
fprintf(file_id, 'PRBS31 BER: %.12e (%d/%d bits)\n', ...
    prbs.ber, prbs.bitErrors, prbs.comparedBits);
fprintf(file_id, 'Image coverage: %.9f\n', summary.image.coverage);
fprintf(file_id, 'Image BER: %.12e (%d/%d bits)\n', ...
    summary.image.ber, summary.image.bitErrors, summary.image.comparedBits);
fprintf(file_id, 'Waveform coverage: %.9f\n', summary.waveform.coverage);
fprintf(file_id, 'Waveform BER: %.12e (%d/%d bits)\n', ...
    summary.waveform.ber, summary.waveform.bitErrors, ...
    summary.waveform.comparedBits);
clear cleanup;
end

function output = subset_frames(input, mask)
output = input;
count = input.frameCount;
names = fieldnames(input);
for index = 1:numel(names)
    name = names{index};
    value = input.(name);
    if strcmp(name, 'bytes') && size(value, 2) == count
        output.(name) = value(:, mask);
    elseif isvector(value) && numel(value) == count
        output.(name) = value(mask);
    end
end
output.frameCount = sum(mask);
end

function write_partial_image(result, image_file, mask_file)
width = 160;
height = 120;
byte_count = width * height * 3;
data = zeros(byte_count, 1, 'uint8');
mask = false(byte_count, 1);
count = min(byte_count, numel(result.data));
data(1:count) = result.data(1:count);
mask(1:count) = result.validMask(1:count);
pixels = permute(reshape(data, [3, width, height]), [3, 2, 1]);
pixel_mask = permute(reshape(mask, [3, width, height]), [3, 2, 1]);
valid_pixel = all(pixel_mask, 3);
pixels(repmat(~valid_pixel, [1, 1, 3])) = 0;
imwrite(pixels, image_file);
imwrite(uint8(valid_pixel) * 255, mask_file);
end

function write_partial_waveform(result, plot_file, data_file)
byte_count = floor(numel(result.data) / 2) * 2;
bytes = result.data(1:byte_count);
mask = result.validMask(1:byte_count);
high = uint16(bytes(1:2:end));
low = uint16(bytes(2:2:end));
unsigned = bitor(bitshift(high, 8), low);
signed = double(unsigned);
signed(signed >= 32768) = signed(signed >= 32768) - 65536;
values = signed(:);
sample_mask = all(reshape(mask, 2, []).', 2);
values(~sample_mask) = NaN;
csvwrite(data_file, [(0:numel(values) - 1).', values, double(sample_mask)]);
figure_handle = figure('Visible', 'off', 'Color', 'white');
plot(values, 'b-');
xlabel('Sample index');
ylabel('Amplitude (int16)');
title(sprintf('Recovered earthquake waveform, coverage %.2f%%', ...
    100 * result.coverage));
grid on;
print(figure_handle, plot_file, '-dpng', '-r150');
close(figure_handle);
end
