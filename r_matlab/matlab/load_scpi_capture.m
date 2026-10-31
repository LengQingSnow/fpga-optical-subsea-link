function capture = load_scpi_capture(capture_dir)
%LOAD_SCPI_CAPTURE Load raw DS81304 SCPI BYTE export plus capture.json.

validateattributes(capture_dir, {'char'}, {'row'}, mfilename, 'capture_dir');
metadata_path = fullfile(capture_dir, 'capture.json');
if exist(metadata_path, 'file') ~= 2
    error('load_scpi_capture:Metadata', ...
        'capture.json is missing from %s.', capture_dir);
end
metadata = fileread(metadata_path);

x_increment = parse_first_number(metadata, ...
    '"xIncrement"\s*:\s*([-+0-9.Ee]+)');
if isempty(x_increment) || x_increment <= 0
    error('load_scpi_capture:SampleInterval', ...
        'No valid xIncrement was found in capture.json.');
end

channels = zeros(0, 4, 'single');
scaling = zeros(4, 3);
for channel = 1:4
    file_path = fullfile(capture_dir, sprintf('ch%d.bin', channel));
    file_id = fopen(file_path, 'r', 'ieee-le');
    if file_id < 0
        error('load_scpi_capture:ChannelFile', ...
            'Cannot open %s.', file_path);
    end
    cleanup = onCleanup(@() fclose(file_id));
    raw = fread(file_id, inf, '*uint8');
    clear cleanup;
    if channel == 1
        channels = zeros(numel(raw), 4, 'single');
    elseif numel(raw) ~= size(channels, 1)
        error('load_scpi_capture:PointCount', ...
            'Channel files do not have equal point counts.');
    end

    pattern = ['(?s)"channel"\s*:\s*' num2str(channel) '.*?' ...
        '"yIncrement"\s*:\s*([-+0-9.Ee]+).*?' ...
        '"yOrigin"\s*:\s*([-+0-9.Ee]+).*?' ...
        '"yReference"\s*:\s*([-+0-9.Ee]+)'];
    tokens = regexp(metadata, pattern, 'tokens', 'once');
    if isempty(tokens)
        error('load_scpi_capture:Scaling', ...
            'No scaling metadata was found for channel %d.', channel);
    end
    scaling(channel, :) = str2double(tokens);
    channels(:, channel) = single((double(raw) - scaling(channel, 2) - ...
        scaling(channel, 3)) * scaling(channel, 1));
end

capture.directory = capture_dir;
capture.sampleRateHz = 1 / x_increment;
capture.pointCount = size(channels, 1);
capture.xOriginSeconds = -0.5 * capture.pointCount / capture.sampleRateHz;
capture.channels = channels;
capture.sourceFormat = 'DS81304 SCPI BYTE';
capture.scaling = scaling;
end

function value = parse_first_number(text, pattern)
tokens = regexp(text, pattern, 'tokens', 'once');
if isempty(tokens)
    value = NaN;
else
    value = str2double(tokens{1});
end
end
