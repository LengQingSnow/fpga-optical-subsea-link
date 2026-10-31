function capture = load_rigol_rg03_set(data_dir, base_name)
%LOAD_RIGOL_RG03_SET Load one explicitly named four-channel RG03 set.

% This loader deliberately ignores capture.json and legacy ch*.bin files.

if nargin < 2 || isempty(base_name)
    base_name = 'RigolDS';
end
channels = [];
metadata = cell(1, 4);
files = cell(1, 4);
for channel_index = 1:4
    files{channel_index} = fullfile(data_dir, sprintf('%s_ch%d.bin', ...
        base_name, channel_index));
    [samples, metadata{channel_index}] = read_rg03(files{channel_index});
    if channel_index == 1
        channels = zeros(metadata{1}.pointCount, 4, 'single');
    else
        if metadata{channel_index}.pointCount ~= metadata{1}.pointCount
            error('load_rigol_rg03_set:PointCount', ...
                'The four RG03 files have different point counts.');
        end
        tolerance = max(eps, abs(metadata{1}.xIncrementSeconds) * 1e-9);
        if abs(metadata{channel_index}.xIncrementSeconds - ...
                metadata{1}.xIncrementSeconds) > tolerance
            error('load_rigol_rg03_set:SampleRate', ...
                'The four RG03 files have different sample intervals.');
        end
    end
    channels(:, channel_index) = samples;
end

capture = struct();
capture.directory = data_dir;
capture.sampleRateHz = 1 / metadata{1}.xIncrementSeconds;
capture.pointCount = metadata{1}.pointCount;
capture.xOriginSeconds = metadata{1}.xOriginSeconds;
capture.channels = channels;
capture.sourceFormat = 'RIGOL DS80000 RG03 BIN (explicit set)';
capture.channelFiles = files;
capture.channelMetadata = metadata;
end

function [samples, metadata] = read_rg03(file_path)
file_id = fopen(file_path, 'r', 'ieee-le');
if file_id < 0
    error('load_rigol_rg03_set:Open', 'Cannot open %s.', file_path);
end
cleanup = onCleanup(@() fclose(file_id));
magic = char(fread(file_id, 4, '*uint8').');
if ~strcmp(magic, 'RG03')
    error('load_rigol_rg03_set:Magic', '%s is not an RG03 file.', file_path);
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
fseek(file_id, 164, 'bof');
data_bytes = double(fread(file_id, 1, '*uint32'));
data_offset = 32 + variable_header_bytes;
file_info = dir(file_path);
if isempty(file_info) || total_bytes ~= file_info.bytes || ...
        data_bytes ~= point_count * 4 || data_offset + data_bytes ~= total_bytes
    error('load_rigol_rg03_set:Layout', ...
        'Unsupported or inconsistent RG03 layout in %s.', file_path);
end
if ~isfinite(x_increment) || x_increment <= 0
    error('load_rigol_rg03_set:XIncrement', ...
        'Invalid sample interval in %s.', file_path);
end
fseek(file_id, data_offset, 'bof');
samples = fread(file_id, point_count, '*single');
if numel(samples) ~= point_count
    error('load_rigol_rg03_set:DataLength', ...
        'Short sample data in %s.', file_path);
end
metadata = struct('pointCount', point_count, ...
    'xOriginSeconds', x_origin, 'xIncrementSeconds', x_increment, ...
    'totalBytes', total_bytes, 'headerBytes', data_offset);
clear cleanup;
end
