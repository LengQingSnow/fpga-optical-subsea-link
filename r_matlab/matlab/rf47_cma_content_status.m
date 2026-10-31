function reference = rf47_cma_content_status()
%RF47_CMA_CONTENT_STATUS Read RF47 information-mode guards without writes.
% Verify live QSFP information mode with replay disabled.
% Reads live hardware on every call; neither loads nor writes reference files.
% MATLAB R2016a, Windows, Java, and Vitis 2021.2 XSCT are required.

if ~ispc || ~usejava('jvm')
    error('rf47_cma_content_status:Platform', ...
        'The read-only RF47 reader requires Windows MATLAB with Java.');
end
xsct = smf_tool_path('xsct');
tcl_file = fullfile(fileparts(mfilename('fullpath')), 'private', ...
    'rf47_cma_content_status.tcl');
if exist(xsct, 'file') ~= 2 || exist(tcl_file, 'file') ~= 2
    error('rf47_cma_content_status:MissingReader', ...
        'Missing XSCT or read-only reference script: %s / %s', xsct, tcl_file);
end
[status, output] = run_reader(xsct, tcl_file, 45);
if status ~= 0
    error('rf47_cma_content_status:HardwareRead', ...
        'Read-only RF47 snapshot failed (exit %d): %s', status, strtrim(output));
end
reference = parse_reference(output);
captured_at = now;
reference.capturedAt = datestr(captured_at, 30);
reference.capturedAtDatenum = captured_at;
reference.captureTime = reference.capturedAt;
reference.source = 'Live read-only RF47 QSFP and replay-control status';
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
                error('rf47_cma_content_status:OutputLimit', ...
                    'The read-only RF47 process exceeded its output limit.');
            end
        end
    end
    [finished, status] = process_status(process);
    if finished && input_stream.available() == 0
        break;
    end
    if toc(started) >= timeout_seconds
        error('rf47_cma_content_status:Timeout', ...
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

function state=parse_reference(output)
rows=regexp(output,'(?m)^CMA_INFO_REG ([0-9]+) ([0-9A-Fa-f]{8})\r?$','tokens');
ix=[3 6 7 65 66]; values=nan(1,5);
for k=1:numel(rows)
    at=find(ix==str2double(rows{k}{1}));
    assert(numel(at)==1 && isnan(values(at)),'Malformed information-mode snapshot');
    values(at)=hex2dec(rows{k}{2});
end
assert(all(isfinite(values)),'Incomplete RF47 information-mode snapshot');
assert(values(1)==1 && values(2)==0 && values(3)==1 && ...
    bitand(uint32(values(4)),uint32(2))==0 && bitand(uint32(values(5)),uint32(2))==0, ...
    'RF47 must be clock-locked, initialized, QSFP mode, BER replay OFF');
state=struct('clockLocked',values(1),'mode',values(2),'configDone',values(3), ...
    'berControl',values(4),'berStatus',values(5));
end
