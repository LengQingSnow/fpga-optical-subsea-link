function reference = rf47_cma_btb_reference()
%RF47_LMS_BTB_REFERENCE Read the active RF47 replay, without changing it.
% Reconstructs the validated 262144-symbol PRBS and verifies its live prefix.
% Reads live hardware on every call; neither loads nor writes reference files.
% MATLAB R2016a, Windows, Java, and Vitis 2021.2 XSCT are required.

if ~ispc || ~usejava('jvm')
    error('rf47_cma_btb_reference:Platform', ...
        'The read-only RF47 reader requires Windows MATLAB with Java.');
end
xsct = smf_tool_path('xsct');
tcl_file = fullfile(fileparts(mfilename('fullpath')), 'private', ...
    'rf47_cma_btb_reference.tcl');
if exist(xsct, 'file') ~= 2 || exist(tcl_file, 'file') ~= 2
    error('rf47_cma_btb_reference:MissingReader', ...
        'Missing XSCT or read-only reference script: %s / %s', xsct, tcl_file);
end
[status, output] = run_reader(xsct, tcl_file, 45);
if status ~= 0
    error('rf47_cma_btb_reference:HardwareRead', ...
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
                error('rf47_cma_btb_reference:OutputLimit', ...
                    'The read-only RF47 process exceeded its output limit.');
            end
        end
    end
    [finished, status] = process_status(process);
    if finished && input_stream.available() == 0
        break;
    end
    if toc(started) >= timeout_seconds
        error('rf47_cma_btb_reference:Timeout', ...
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
rows = regexp(output, '(?m)^LONG_REG ([0-9]+) ([0-9A-Fa-f]{8})\r?$', 'tokens');
registers = zeros(204,1,'uint32'); seen = false(204,1);
for k=1:numel(rows)
    ix=str2double(rows{k}{1})+1;
    assert(ix>=1 && ix<=204 && ~seen(ix),'Invalid or duplicate register');
    registers(ix)=uint32(hex2dec(rows{k}{2})); seen(ix)=true;
end
required=[6 65 66 67 196:203]+1;
assert(all(seen(required)), 'Incomplete long-PRBS register snapshot');
assert(registers(197)==hex2dec('5052424C') && registers(198)==262144, 'Not the validated long PRBS build');
assert(registers(7)==0 && registers(66)==3 && registers(67)==3 && registers(68)==64, 'RF47 long BER replay is not active in QSFP mode');
assert(registers(203)==hex2dec('10000009'), 'Unsupported PRBS polynomial');
rows=regexp(output,'(?m)^BER_REF_DWORD ([0-9]+) 0x([0-9A-Fa-f]{8})\r?$','tokens');
assert(numel(rows)==128,'Expected 128 live prefix dwords');
dwords=zeros(128,1,'uint32');
for k=1:128
    assert(str2double(rows{k}{1})==k-1,'Unordered reference dwords');
    dwords(k)=uint32(hex2dec(rows{k}{2}));
end
seeds=registers(199:202); period=double(registers(198));
persistent cachedSeeds cachedBits
if isempty(cachedSeeds) || ~isequal(cachedSeeds,seeds)
    bits=false(period+31,4);
    for lane=1:4, bits(1:31,lane)=bitget(seeds(lane),31:-1:1)>0; end
    for k=1:period, bits(k+31,:)=xor(bits(k,:),bits(k+3,:)); end
    cachedBits=bits(1:period,:); cachedSeeds=seeds;
end
prefix=false(1024,4);
for word=0:63
    for symbol=0:15
        for lane=0:3
            pos=63-4*symbol-lane;
            if pos>=32, v=bitget(dwords(2*word+2),pos-31);
            else, v=bitget(dwords(2*word+1),pos+1); end
            prefix(16*word+symbol+1,lane+1)=logical(v);
        end
    end
end
assert(isequal(prefix,cachedBits(1:1024,:)), 'Live DA prefix disagrees with long PRBS seeds; BER is unavailable');
stable=[6 7 9 10:17 47 65:67 196:203]+1;
reference=struct('laneBits',cachedBits,'dwords',dwords,'seeds',seeds, ...
    'symbolsPerLane',period,'registers',registers,'signature',registers(stable), ...
    'laneOrder',{{'TX0','TX2','TX4','TX6'}});
end
