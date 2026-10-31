function reference = prepare_rf47_ber_reference(force_refresh)
%PREPARE_RF47_BER_REFERENCE Load the persisted RF47 DA-input reference.
%   With FORCE_REFRESH true, arm a fresh RF47 BER replay block through JTAG,
%   read the current 128 reference dwords, and overwrite the persisted file.
%   With the default false value, load the existing persisted reference.

if nargin < 1 || isempty(force_refresh)
    force_refresh = false;
end
if ~isscalar(force_refresh)
    error('prepare_rf47_ber_reference:ForceRefresh', ...
        'force_refresh must be a scalar logical value.');
end
force_refresh = logical(force_refresh);

script_dir = fileparts(mfilename('fullpath'));
project_dir = fileparts(script_dir);
workspace_dir = fileparts(project_dir);
reference_dir = fullfile(project_dir, 'ref');
reference_file = fullfile(reference_dir, 'rf47_ber_reference.mat');
if ~force_refresh && exist(reference_file, 'file') == 2
    loaded = load(reference_file);
    if isfield(loaded, 'reference')
        reference = loaded.reference;
    else
        reference = loaded;
    end
    validate_reference(reference, reference_file);
    return;
end

capture_script = fullfile(workspace_dir, 'code', 'da_project', 'porject', ...
    'vitis', 'capture_ber_reference.ps1');
if exist(capture_script, 'file') ~= 2
    error('prepare_rf47_ber_reference:MissingScript', ...
        'RF47 BER reference script was not found: %s', capture_script);
end

command = sprintf('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%s"', ...
    capture_script);
[status, output] = system(command);
if status ~= 0
    error('prepare_rf47_ber_reference:HardwareRead', ...
        'RF47 BER reference capture failed: %s', strtrim(output));
end

tokens = regexp(output, ...
    'BER_REF_DWORD\s+(\d+)\s+0x([0-9A-Fa-f]{8})', 'tokens');
if numel(tokens) ~= 128
    error('prepare_rf47_ber_reference:WordCount', ...
        'Expected 128 reference dwords, received %d.', numel(tokens));
end

dwords = zeros(128, 1, 'uint32');
present = false(128, 1);
for token_index = 1:numel(tokens)
    index = str2double(tokens{token_index}{1}) + 1;
    if index < 1 || index > 128 || present(index)
        error('prepare_rf47_ber_reference:Index', ...
            'Invalid or duplicate BER reference dword index.');
    end
    dwords(index) = uint32(hex2dec(tokens{token_index}{2}));
    present(index) = true;
end
if ~all(present)
    error('prepare_rf47_ber_reference:Incomplete', ...
        'The RF47 BER reference readback is incomplete.');
end

lane_bits = false(64 * 16, 4);
for word_index = 0:63
    low_word = dwords(2 * word_index + 1);
    high_word = dwords(2 * word_index + 2);
    for symbol_index = 0:15
        for lane = 1:4
            bit_position = 63 - 4 * symbol_index - (lane - 1);
            if bit_position >= 32
                value = bitget(high_word, bit_position - 32 + 1);
            else
                value = bitget(low_word, bit_position + 1);
            end
            lane_bits(word_index * 16 + symbol_index + 1, lane) = logical(value);
        end
    end
end

reference = struct();
reference.laneBits = lane_bits;
reference.dwords = dwords;
reference.wordCount = 64;
reference.symbolsPerLane = size(lane_bits, 1);
reference.captureTime = datestr(now, 30);
reference.source = 'RF47 DA input before NRZ mapper and pre-equalizer';
reference.rawOutput = output;
if exist(reference_dir, 'dir') ~= 7
    mkdir(reference_dir);
end
save(reference_file, 'reference', '-v7');
end

function validate_reference(reference, reference_file)
if ~isstruct(reference) || ~isfield(reference, 'laneBits') || ...
        size(reference.laneBits, 2) ~= 4 || ...
        size(reference.laneBits, 1) < 2
    error('prepare_rf47_ber_reference:InvalidFile', ...
        'Invalid four-lane BER reference file: %s', reference_file);
end
end
