function references = load_reference_dataset(dataset_dir)
%LOAD_REFERENCE_DATASET Load the transmitted underwater images and waveform.

prepared_dir = fullfile(dataset_dir, 'prepared_ax7101_trim160s');
manifest_path = fullfile(prepared_dir, 'manifest.json');
if exist(manifest_path, 'file') == 2
    image_dir = fullfile(prepared_dir, 'images_mem_rgb888');
    waveform_path = fullfile(prepared_dir, 'waveform_bhz_int16.mem');
    manifest_text = fileread(manifest_path);
    image_count = manifest_integer(manifest_text, 'image_count');
    image_width = manifest_integer(manifest_text, 'image_width');
    image_height = manifest_integer(manifest_text, 'image_height');
else
    channeltest_dir = fullfile(dataset_dir, 'channeltest');
    image_dir = fullfile(channeltest_dir, 'ch1_underwater_image', 'mem_rgb888');
    waveform_path = fullfile(channeltest_dir, 'ch3_earthquake', ...
        'waveform_bhz_int16.mem');
    image_count = 45;
    image_width = 320;
    image_height = 240;
end
if exist(image_dir, 'dir') ~= 7
    error('load_reference_dataset:ImageDirectory', ...
        'Image MEM directory does not exist: %s', image_dir);
end
if exist(waveform_path, 'file') ~= 2
    error('load_reference_dataset:WaveformFile', ...
        'Waveform MEM file does not exist: %s', waveform_path);
end

references.images = cell(image_count, 1);
references.imageRgb = cell(image_count, 1);
for image_id = 1:image_count
    file_path = fullfile(image_dir, sprintf('%d_raw.mem', image_id));
    words = read_hex_words(file_path, 6);
    expected_pixels = image_width * image_height;
    if numel(words) ~= expected_pixels
        error('load_reference_dataset:ImageLength', ...
            '%s contains %d pixels, expected %d.', ...
            file_path, numel(words), expected_pixels);
    end
    red = uint8(bitand(bitshift(words, -16), uint32(255)));
    green = uint8(bitand(bitshift(words, -8), uint32(255)));
    blue = uint8(bitand(words, uint32(255)));
    rgb_rows = [red(:), green(:), blue(:)];
    references.images{image_id} = reshape(rgb_rows.', [], 1);
    image = zeros(image_height, image_width, 3, 'uint8');
    image(:, :, 1) = reshape(red, [image_width, image_height]).';
    image(:, :, 2) = reshape(green, [image_width, image_height]).';
    image(:, :, 3) = reshape(blue, [image_width, image_height]).';
    references.imageRgb{image_id} = image;
end

waveform_words = read_hex_words(waveform_path, 4);
if numel(waveform_words) ~= 11200
    error('load_reference_dataset:WaveformLength', ...
        'Waveform contains %d samples, expected 11200.', numel(waveform_words));
end
waveform_u16 = uint16(waveform_words);
waveform_signed = double(waveform_u16);
negative = waveform_signed >= 32768;
waveform_signed(negative) = waveform_signed(negative) - 65536;
references.waveformSamples = int16(waveform_signed);
references.waveformBytes = zeros(numel(waveform_u16) * 2, 1, 'uint8');
references.waveformBytes(1:2:end) = uint8(bitshift(waveform_u16, -8));
references.waveformBytes(2:2:end) = uint8(bitand(waveform_u16, 255));
references.imageWidth = image_width;
references.imageHeight = image_height;
references.waveformSampleRateHz = 20;
end

function value = manifest_integer(manifest_text, field_name)
pattern = ['"' field_name '"\s*:\s*(\d+)'];
token = regexp(manifest_text, pattern, 'tokens', 'once');
if isempty(token)
    error('load_reference_dataset:ManifestField', ...
        'Manifest field %s was not found.', field_name);
end
value = str2double(token{1});
if ~isfinite(value) || value < 1 || value ~= floor(value)
    error('load_reference_dataset:ManifestValue', ...
        'Manifest field %s is invalid.', field_name);
end
end

function words = read_hex_words(file_path, expected_digits)
file_id = fopen(file_path, 'r');
if file_id < 0
    error('load_reference_dataset:OpenFailed', 'Cannot open %s.', file_path);
end
cleanup = onCleanup(@() fclose(file_id));
tokens = textscan(file_id, '%s');
tokens = tokens{1};
words = zeros(numel(tokens), 1, 'uint32');
for index = 1:numel(tokens)
    token = strtrim(tokens{index});
    if numel(token) ~= expected_digits
        error('load_reference_dataset:HexWidth', ...
            '%s line %d has unexpected width.', file_path, index);
    end
    value = hex2dec(token);
    if ~isfinite(value)
        error('load_reference_dataset:HexValue', ...
            '%s line %d is not hexadecimal.', file_path, index);
    end
    words(index) = uint32(value);
end
clear cleanup;
end
