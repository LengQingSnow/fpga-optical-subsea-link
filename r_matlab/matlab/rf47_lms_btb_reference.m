function reference = rf47_lms_btb_reference()
%RF47_LMS_BTB_REFERENCE Read the active RF47 replay, without changing it.
% Returns 128 uint32 dwords and 1024-by-4 logical laneBits in TX0/2/4/6 order.
% Reads live hardware on every call; neither loads nor writes reference files.
% MATLAB R2016a, Windows, Java, and Vitis 2021.2 XSCT are required.

if ~ispc || ~usejava('jvm')
    error('rf47_lms_btb_reference:Platform', ...
        'The read-only RF47 reader requires Windows MATLAB with Java.');
end
xsct = smf_tool_path('xsct');
tcl_file = fullfile(fileparts(mfilename('fullpath')), 'private', ...
    'rf47_lms_btb_reference.tcl');
if exist(xsct, 'file') ~= 2 || exist(tcl_file, 'file') ~= 2
    error('rf47_lms_btb_reference:MissingReader', ...
        'Missing XSCT or read-only reference script: %s / %s', xsct, tcl_file);
end
[status, output] = run_reader(xsct, tcl_file, 45);
if status ~= 0
    error('rf47_lms_btb_reference:HardwareRead', ...
        'Read-only RF47 snapshot failed (exit %d): %s', status, strtrim(output));
end
reference = parse_reference(output);
captured_at = now;
reference.capturedAt = datestr(captured_at, 30);
reference.capturedAtDatenum = captured_at;
reference.captureTime = reference.capturedAt;
reference.source = 'Live read-only RF47 DA-input replay, before NRZ mapper and pre-equalizer';
reference.readOnly = true;
reference.readerScript = tcl_file;
end

function [status, output] = run_reader(xsct, tcl_file, timeout_seconds)
% A private shell emits its own PID before starting XSCT. Timeout cleanup
% targets only that PID and its descendants, never any existing hardware server.
script = sprintf(['$ErrorActionPreference=''Stop''; ' ...
    '[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false); ' ...
    '[Console]::WriteLine(''RF47_READER_PID '' + $PID); ' ...
    '& ''%s'' ''%s''; exit $LASTEXITCODE'], ...
    strrep(xsct, '''', ''''''), strrep(tcl_file, '''', ''''''));
encoded = char(javax.xml.bind.DatatypeConverter.printBase64Binary( ...
    typecast(uint16(script), 'int8')));
arguments = java.util.ArrayList();
tokens = {'powershell.exe', '-NoLogo', '-NoProfile', '-NonInteractive', ...
    '-ExecutionPolicy', 'Bypass', '-EncodedCommand', encoded};
for k = 1:numel(tokens)
    arguments.add(java.lang.String(tokens{k}));
end
builder = java.lang.ProcessBuilder(arguments);
builder.redirectErrorStream(true);
started = tic;
process = builder.start();
reader_pid = java.util.concurrent.atomic.AtomicLong(0);
input_stream = process.getInputStream();
read_channel = java.nio.channels.Channels.newChannel(input_stream);
cleanup = onCleanup(@() cleanup_reader(process, input_stream, reader_pid));
output = '';
while true
    count = double(input_stream.available());
    if count > 0
        buffer = java.nio.ByteBuffer.allocate(min(count, 65536));
        received = read_channel.read(buffer);
        if received > 0
            bytes = typecast(buffer.array(), 'uint8');
            output = [output, char(reshape(bytes(1:received), 1, []))]; %#ok<AGROW>
            if reader_pid.get() == 0
                token = regexp(output, '(?m)^RF47_READER_PID ([0-9]+)\r?$', ...
                    'tokens', 'once');
                if ~isempty(token)
                    reader_pid.set(int64(str2double(token{1})));
                end
            end
            if numel(output) > 1000000
                error('rf47_lms_btb_reference:OutputLimit', ...
                    'The read-only RF47 process exceeded its output limit.');
            end
        end
    end
    [finished, status] = process_status(process);
    if finished && input_stream.available() == 0
        break;
    end
    if toc(started) >= timeout_seconds
        error('rf47_lms_btb_reference:Timeout', ...
            'Read-only RF47 snapshot exceeded %.0f seconds. %s', ...
            timeout_seconds, strtrim(output));
    end
    pause(0.02);
end
clear cleanup;
end

function cleanup_reader(process, input_stream, reader_pid)
[finished, ~] = process_status(process);
if ~finished
    pid = double(reader_pid.get());
    if isfinite(pid) && pid > 0 && pid == fix(pid)
        terminate_own_tree(pid);
    end
    try
        process.destroy();
    catch
    end
end
try
    input_stream.close();
    output_stream = process.getOutputStream();
    error_stream = process.getErrorStream();
    output_stream.close();
    error_stream.close();
catch
end
end

function [finished, status] = process_status(process)
try
    status = double(process.exitValue());
    finished = true;
catch
    status = NaN;
    finished = false;
end
end

function terminate_own_tree(pid)
try
    arguments = java.util.ArrayList();
    tokens = {'taskkill.exe', '/PID', sprintf('%.0f', pid), '/T', '/F'};
    for k = 1:numel(tokens)
        arguments.add(java.lang.String(tokens{k}));
    end
    builder = java.lang.ProcessBuilder(arguments);
    builder.redirectErrorStream(true);
    killer = builder.start();
    started = tic;
    while toc(started) < 2
        [finished, ~] = process_status(killer);
        if finished
            break;
        end
        pause(0.02);
    end
    killer.destroy();
    input_stream = killer.getInputStream();
    output_stream = killer.getOutputStream();
    input_stream.close();
    output_stream.close();
catch
end
end

function reference = parse_reference(output)
lines = regexp(output, '[\r\n]+', 'split');
first = find(strcmp(lines, 'RF47_REFERENCE_BEGIN 1'));
last = find(strcmp(lines, 'RF47_REFERENCE_END 1'));
if numel(first) ~= 1 || numel(last) ~= 1 || last - first ~= 133
    error('rf47_lms_btb_reference:Frame', ...
        'Missing, duplicate, or incomplete read-only RF47 snapshot.');
end
labels = {'RF_MODE', 'BER_CONTROL', 'BER_STATUS', 'BER_COUNT'};
registers = struct();
for k = 1:4
    token = regexp(lines{first + k}, ...
        ['^', labels{k}, ' 0x([0-9A-Fa-f]{8})$'], 'tokens', 'once');
    if isempty(token)
        error('rf47_lms_btb_reference:Register', ...
            'Malformed or unordered RF47 register header: %s.', labels{k});
    end
    registers.(labels{k}) = uint32(hex2dec(token{1}));
end
if registers.RF_MODE ~= 0 || bitand(registers.BER_CONTROL, uint32(2)) ~= 2 || ...
        bitand(registers.BER_STATUS, uint32(3)) ~= 3 || registers.BER_COUNT ~= 64
    error('rf47_lms_btb_reference:ReplayState', ...
        'RF47 must use RF_MODE=0 with replay enabled, active, ready, and COUNT=64.');
end
dwords = zeros(128, 1, 'uint32');
for k = 0:127
    token = regexp(lines{first + 5 + k}, ...
        '^BER_REF_DWORD ([0-9]+) 0x([0-9A-Fa-f]{8})$', 'tokens', 'once');
    if isempty(token) || str2double(token{1}) ~= k
        error('rf47_lms_btb_reference:Index', ...
            'Expected ordered RF47 reference dword index %d.', k);
    end
    dwords(k + 1) = uint32(hex2dec(token{2}));
end
lane_bits = false(1024, 4);
for word = 0:63
    low = dwords(2 * word + 1);
    high = dwords(2 * word + 2);
    for symbol = 0:15
        for lane = 0:3
            position = 63 - 4 * symbol - lane;
            if position >= 32
                value = bitget(high, position - 31);
            else
                value = bitget(low, position + 1);
            end
            lane_bits(16 * word + symbol + 1, lane + 1) = logical(value);
        end
    end
end
reference = struct('dwords', dwords, 'laneBits', lane_bits, ...
    'registers', registers, 'wordCount', 64, 'symbolsPerLane', 1024, ...
    'laneOrder', {{'TX0', 'TX2', 'TX4', 'TX6'}});
end
