function capture = load_scope_capture(data_dir, capture_name)
%LOAD_SCOPE_CAPTURE Load a four-channel RIGOL capture from binary or CSV.
%
% Preferred binary layout:
%   capture_manifest.txt
%   ch1.bin ... ch4.bin
%
% The manifest uses key=value lines. Required keys are sample_rate_hz,
% point_count, sample_type and ch1_file through ch4_file. Optional RIGOL
% scaling keys are chN_y_increment, chN_y_origin and chN_y_reference.

if nargin < 2
    capture_name = '';
end
validateattributes(data_dir, {'char'}, {'row'}, mfilename, 'data_dir', 1);

capture_dir = select_capture_directory(data_dir, capture_name);
manifest_path = fullfile(capture_dir, 'capture_manifest.txt');
scpi_metadata_path = fullfile(capture_dir, 'capture.json');

if exist(manifest_path, 'file') == 2
    capture = load_binary_capture(capture_dir, manifest_path);
elseif exist(scpi_metadata_path, 'file') == 2
    capture = load_scpi_capture(capture_dir);
elseif has_rigol_bin_set(capture_dir)
    capture = load_rigol_bin_capture(capture_dir);
else
    capture = load_csv_capture(capture_dir);
end

if size(capture.channels, 2) ~= 4
    error('load_scope_capture:ChannelCount', ...
        'The capture must contain exactly four channels.');
end
if size(capture.channels, 1) < 4096
    error('load_scope_capture:TooShort', ...
        'The capture is too short for reliable frame synchronization.');
end
if ~isfinite(capture.sampleRateHz) || capture.sampleRateHz <= 4e9
    error('load_scope_capture:SampleRate', ...
        'The sample rate must be greater than the 4 GHz symbol rate.');
end
end

function capture_dir = select_capture_directory(data_dir, capture_name)
if exist(data_dir, 'dir') ~= 7
    error('load_scope_capture:MissingDataDirectory', ...
        'Data directory does not exist: %s', data_dir);
end

if ~isempty(capture_name)
    capture_dir = fullfile(data_dir, capture_name);
    if exist(capture_dir, 'dir') ~= 7
        error('load_scope_capture:MissingCapture', ...
            'Capture directory does not exist: %s', capture_dir);
    end
    return;
end

if exist(fullfile(data_dir, 'capture_manifest.txt'), 'file') == 2 || ...
        exist(fullfile(data_dir, 'capture.json'), 'file') == 2 || ...
        has_rigol_bin_set(data_dir)
    capture_dir = data_dir;
    return;
end

entries = dir(data_dir);
best_time = -inf;
capture_dir = '';
for k = 1:numel(entries)
    if entries(k).isdir && entries(k).name(1) ~= '.'
        candidate = fullfile(data_dir, entries(k).name);
        has_manifest = exist(fullfile(candidate, 'capture_manifest.txt'), 'file') == 2;
        has_scpi = exist(fullfile(candidate, 'capture.json'), 'file') == 2;
        has_csv = ~isempty(dir(fullfile(candidate, '*.csv')));
        has_rigol = has_rigol_bin_set(candidate);
        if (has_manifest || has_scpi || has_csv || has_rigol) && ...
                entries(k).datenum > best_time
            best_time = entries(k).datenum;
            capture_dir = candidate;
        end
    end
end

if isempty(capture_dir)
    if ~isempty(dir(fullfile(data_dir, '*.csv'))) || ...
            exist(fullfile(data_dir, 'capture.json'), 'file') == 2 || ...
            has_rigol_bin_set(data_dir)
        capture_dir = data_dir;
    else
        error('load_scope_capture:NoCapture', ...
            ['No capture_manifest.txt, capture.json, DS80000 channel BIN ' ...
             'set, or CSV capture was found in %s.'], data_dir);
    end
end
end

function capture = load_rigol_bin_capture(capture_dir)
file_paths = find_rigol_bin_files(capture_dir);
first_meta = struct();
channels = [];

for channel_index = 1:4
    [samples, meta] = read_rigol_ds80000_bin(file_paths{channel_index});
    if channel_index == 1
        first_meta = meta;
        channels = zeros(meta.pointCount, 4, 'single');
    else
        if meta.pointCount ~= first_meta.pointCount
            error('load_scope_capture:RigolPointCount', ...
                'DS80000 channel files have different point counts.');
        end
        tolerance = max(abs(first_meta.xIncrementSeconds) * 1e-9, eps);
        if abs(meta.xIncrementSeconds - first_meta.xIncrementSeconds) > tolerance
            error('load_scope_capture:RigolSampleRate', ...
                'DS80000 channel files have different sample intervals.');
        end
    end
    channels(:, channel_index) = samples;
end

capture.directory = capture_dir;
capture.sampleRateHz = 1 / first_meta.xIncrementSeconds;
capture.pointCount = first_meta.pointCount;
capture.xOriginSeconds = first_meta.xOriginSeconds;
capture.channels = channels;
capture.sourceFormat = 'RIGOL DS80000 RG03 BIN';
capture.manifest = first_meta;
capture.channelFiles = file_paths;
end

function [samples, meta] = read_rigol_ds80000_bin(file_path)
file_id = fopen(file_path, 'r', 'ieee-le');
if file_id < 0
    error('load_scope_capture:RigolOpen', ...
        'Cannot open DS80000 BIN file: %s', file_path);
end
cleanup = onCleanup(@() fclose(file_id));

magic = char(fread(file_id, 4, '*uint8').');
if ~strcmp(magic, 'RG03')
    error('load_scope_capture:RigolMagic', ...
        '%s does not have an RG03 DS80000 header.', file_path);
end

fseek(file_id, 4, 'bof');
total_bytes = double(fread(file_id, 1, '*uint32'));
fseek(file_id, 16, 'bof');
variable_header_bytes = double(fread(file_id, 1, '*uint32'));
fseek(file_id, 28, 'bof');
point_count = double(fread(file_id, 1, '*uint32'));
fseek(file_id, 40, 'bof');
x_origin = fread(file_id, 1, '*double');
x_increment = fread(file_id, 1, '*double');
fseek(file_id, 128, 'bof');
label_bytes = fread(file_id, 24, '*uint8').';
label = char(label_bytes(label_bytes ~= 0));
fseek(file_id, 164, 'bof');
data_bytes = double(fread(file_id, 1, '*uint32'));

data_offset = 32 + variable_header_bytes;
file_info = dir(file_path);
if isempty(file_info) || total_bytes ~= file_info.bytes
    error('load_scope_capture:RigolFileSize', ...
        'DS80000 BIN size field does not match %s.', file_path);
end
if point_count < 1 || data_bytes ~= point_count * 4 || ...
        data_offset + data_bytes ~= total_bytes
    error('load_scope_capture:RigolLayout', ...
        'Unsupported DS80000 BIN layout in %s.', file_path);
end
if ~isfinite(x_increment) || x_increment <= 0
    error('load_scope_capture:RigolXIncrement', ...
        'Invalid sample interval in %s.', file_path);
end

fseek(file_id, data_offset, 'bof');
samples = fread(file_id, point_count, '*single');
if numel(samples) ~= point_count
    error('load_scope_capture:RigolDataLength', ...
        '%s contains fewer samples than its header declares.', file_path);
end

meta.magic = magic;
meta.totalBytes = total_bytes;
meta.headerBytes = data_offset;
meta.pointCount = point_count;
meta.xOriginSeconds = x_origin;
meta.xIncrementSeconds = x_increment;
meta.channelLabel = label;
clear cleanup;
end

function present = has_rigol_bin_set(capture_dir)
present = false;
if exist(capture_dir, 'dir') ~= 7
    return;
end
try
    find_rigol_bin_files(capture_dir);
    present = true;
catch error_info
    if ~strcmp(error_info.identifier, 'load_scope_capture:NoRigolBinSet')
        rethrow(error_info);
    end
end
end

function file_paths = find_rigol_bin_files(capture_dir)
channel_one_files = dir(fullfile(capture_dir, '*_ch1.bin'));
valid_paths = {};
valid_times = [];
for file_index = 1:numel(channel_one_files)
    name = channel_one_files(file_index).name;
    base_name = name(1:end - numel('_ch1.bin'));
    candidate_paths = cell(1, 4);
    complete = true;
    for channel_index = 1:4
        candidate_paths{channel_index} = fullfile(capture_dir, ...
            sprintf('%s_ch%d.bin', base_name, channel_index));
        if exist(candidate_paths{channel_index}, 'file') ~= 2
            complete = false;
        end
    end
    if complete
        valid_paths{end + 1} = candidate_paths; %#ok<AGROW>
        valid_times(end + 1) = channel_one_files(file_index).datenum; %#ok<AGROW>
    end
end

if isempty(valid_paths)
    error('load_scope_capture:NoRigolBinSet', ...
        'No complete *_ch1.bin through *_ch4.bin set exists in %s.', ...
        capture_dir);
end
[~, newest_index] = max(valid_times);
file_paths = valid_paths{newest_index};
end

function capture = load_binary_capture(capture_dir, manifest_path)
manifest = read_key_value_file(manifest_path);
sample_rate = required_number(manifest, 'sample_rate_hz');
point_count = round(required_number(manifest, 'point_count'));
sample_type = required_text(manifest, 'sample_type');
byte_order = optional_text(manifest, 'byte_order', 'little');

switch lower(byte_order)
    case 'little'
        machine_format = 'ieee-le';
    case 'big'
        machine_format = 'ieee-be';
    otherwise
        error('load_scope_capture:ByteOrder', ...
            'Unsupported byte_order: %s', byte_order);
end

channels = zeros(point_count, 4, 'single');
for channel_index = 1:4
    prefix = sprintf('ch%d_', channel_index);
    file_name = required_text(manifest, [prefix 'file']);
    file_path = fullfile(capture_dir, file_name);
    file_id = fopen(file_path, 'r', machine_format);
    if file_id < 0
        error('load_scope_capture:OpenFailed', ...
            'Cannot open channel file: %s', file_path);
    end
    cleanup = onCleanup(@() fclose(file_id));
    raw = fread(file_id, point_count, ['*' sample_type]);
    clear cleanup;
    if numel(raw) ~= point_count
        error('load_scope_capture:PointCount', ...
            '%s contains %d points, expected %d.', ...
            file_name, numel(raw), point_count);
    end

    y_increment = optional_number(manifest, [prefix 'y_increment'], 1);
    y_origin = optional_number(manifest, [prefix 'y_origin'], 0);
    y_reference = optional_number(manifest, [prefix 'y_reference'], 0);
    channels(:, channel_index) = single((double(raw) - y_origin - ...
        y_reference) * y_increment);
end

capture.directory = capture_dir;
capture.sampleRateHz = sample_rate;
capture.pointCount = point_count;
capture.xOriginSeconds = optional_number(manifest, 'x_origin_s', 0);
capture.channels = channels;
capture.sourceFormat = 'RIGOL binary';
capture.manifest = manifest;
end

function capture = load_csv_capture(capture_dir)
files = dir(fullfile(capture_dir, '*.csv'));
if isempty(files)
    error('load_scope_capture:NoCsv', ...
        'No capture_manifest.txt or CSV file exists in %s.', capture_dir);
end

[~, newest] = max([files.datenum]);
csv_path = fullfile(capture_dir, files(newest).name);
imported = importdata(csv_path, ',');
if isstruct(imported)
    numeric_data = imported.data;
else
    numeric_data = imported;
end
if size(numeric_data, 2) < 5
    error('load_scope_capture:CsvColumns', ...
        'CSV must contain time plus CH1, CH2, CH3 and CH4 columns.');
end

time = double(numeric_data(:, 1));
channels = single(numeric_data(:, 2:5));
valid = isfinite(time) & all(isfinite(double(channels)), 2);
time = time(valid);
channels = channels(valid, :);
time_step = median(diff(time));
if ~isfinite(time_step) || time_step <= 0
    error('load_scope_capture:CsvTime', 'CSV time column is not increasing.');
end

capture.directory = capture_dir;
capture.sampleRateHz = 1 / time_step;
capture.pointCount = size(channels, 1);
capture.xOriginSeconds = time(1);
capture.channels = channels;
capture.sourceFormat = 'CSV';
capture.manifest = struct();
end

function values = read_key_value_file(file_path)
file_id = fopen(file_path, 'r');
if file_id < 0
    error('load_scope_capture:ManifestOpen', ...
        'Cannot open manifest: %s', file_path);
end
cleanup = onCleanup(@() fclose(file_id));
lines = textscan(file_id, '%s', 'Delimiter', '\n', 'Whitespace', '');
lines = lines{1};
values = struct();
for k = 1:numel(lines)
    line = strtrim(lines{k});
    if isempty(line) || line(1) == '#'
        continue;
    end
    split_at = find(line == '=', 1, 'first');
    if isempty(split_at)
        continue;
    end
    key = strtrim(line(1:split_at - 1));
    value = strtrim(line(split_at + 1:end));
    values.(key) = value;
end
clear cleanup;
end

function value = required_text(values, key)
if ~isfield(values, key)
    error('load_scope_capture:ManifestKey', ...
        'Manifest is missing required key: %s', key);
end
value = values.(key);
end

function value = optional_text(values, key, default_value)
if isfield(values, key)
    value = values.(key);
else
    value = default_value;
end
end

function value = required_number(values, key)
value = str2double(required_text(values, key));
if ~isfinite(value)
    error('load_scope_capture:ManifestNumber', ...
        'Manifest key %s is not numeric.', key);
end
end

function value = optional_number(values, key, default_value)
if isfield(values, key)
    value = str2double(values.(key));
    if ~isfinite(value)
        error('load_scope_capture:ManifestNumber', ...
            'Manifest key %s is not numeric.', key);
    end
else
    value = default_value;
end
end
