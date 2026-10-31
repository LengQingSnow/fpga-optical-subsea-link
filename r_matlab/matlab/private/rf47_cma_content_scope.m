function capture = rf47_cma_content_scope(host_name, tcp_port, point_count)
%RF47_CMA_CONTENT_SCOPE Page-4-only longer single record; STOP after transfer.
% Same validated transport as LMS-BTB, but real payload needs no replay reference.

if nargin < 1 || isempty(host_name)
    host_name = '192.168.1.12';
end
if nargin < 2 || isempty(tcp_port)
    tcp_port = 5555;
end
if nargin<3, point_count=10000000; end
assert(any(point_count==[1000000 10000000]),'Use 1M or 10M discrete memory depth');
validateattributes(host_name, {'char'}, {'row', 'nonempty'}, mfilename, 'host_name');
validateattributes(tcp_port, {'numeric'}, ...
    {'scalar', 'integer', '>=', 1, '<=', 65535}, mfilename, 'tcp_port');


stop_required = java.util.concurrent.atomic.AtomicBoolean(true);
cleanup = onCleanup(@() stop_on_exit(host_name, tcp_port, stop_required));
configure_scope(host_name, tcp_port);
capture = rf47_lms_btb_scope_read(host_name, tcp_port, point_count, 30);
% Close the acquisition connection before sending the final STOP.
stop_scope(host_name, tcp_port);
stop_required.set(false);
validate_capture(capture,point_count);
capture.scopeStoppedVerified = true;
capture.adcRailCountByChannel = zeros(1, 4);
clear cleanup;
end

function stop_on_exit(host_name, tcp_port, stop_required)
if stop_required.get()
    try
        stop_scope(host_name, tcp_port);
    catch stop_error
        warning('rf47_lms_content_capture:StopCleanup', ...
            'Could not verify STOP during capture cleanup: %s', stop_error.message);
    end
end
end

function configure_scope(host_name, tcp_port)
socket = open_scope(host_name, tcp_port);
cleanup = onCleanup(@() close_scope(socket));
output = socket.getOutputStream();
input = socket.getInputStream();
write_scpi(output, ':STOP');
write_scpi(output, ':TIM:SCAL 1e-6');
for channel = 1:4
    enabled = query_scpi(output, input, sprintf(':CHAN%d:DISP?', channel));
    if ~strcmp(enabled, '1') && ~strcmpi(enabled, 'ON')
        error('rf47_lms_content_capture:ChannelDisabled', ...
            'CH%d is disabled. Enable all four scope channels before BTB capture.', channel);
    end
end
scale = str2double(query_scpi(output, input, ':TIM:SCAL?'));
if ~isfinite(scale) || abs(scale - 1e-6) > 1e-12
    error('rf47_lms_content_capture:TimeScale', ...
        'The scope did not accept the required 1 us/div time scale.');
end
clear cleanup;
end

function stop_scope(host_name, tcp_port)
socket = open_scope(host_name, tcp_port);
cleanup = onCleanup(@() close_scope(socket));
output = socket.getOutputStream();
input = socket.getInputStream();
write_scpi(output, ':STOP');
pause(0.05);
state = query_scpi(output, input, ':TRIG:STAT?');
if ~strcmpi(state, 'STOP')
    error('rf47_lms_content_capture:ScopeNotStopped', ...
        'The scope did not confirm STOP (reported %s).', state);
end
clear cleanup;
end

function socket = open_scope(host_name, tcp_port)
socket = java.net.Socket();
try
    endpoint = java.net.InetSocketAddress(host_name, tcp_port);
    socket.connect(endpoint, 5000);
    socket.setTcpNoDelay(true);
    socket.setSoTimeout(5000);
catch connection_error
    close_scope(socket);
    rethrow(connection_error);
end
end

function close_scope(socket)
try
    socket.close();
catch
end
end

function write_scpi(output, command)
bytes = uint8([double(command), 10]);
output.write(bytes, 0, numel(bytes));
output.flush();
end

function response = query_scpi(output, input, command)
write_scpi(output, command);
bytes = zeros(1, 8192, 'uint8');
count = 0;
started = tic;
while true
    value = input.read();
    if value < 0
        error('rf47_lms_content_capture:Connection', ...
            'Scope connection closed while reading %s.', command);
    end
    if value == 10
        break;
    end
    if toc(started) > 5 || count == numel(bytes)
        error('rf47_lms_content_capture:Response', ...
            'Scope response to %s exceeded the size or time limit.', command);
    end
    if value ~= 13
        count = count + 1;
        bytes(count) = uint8(value);
    end
end
response = strtrim(char(bytes(1:count)));
end

function validate_capture(capture,point_count)
if ~isequal(size(capture.channels), [point_count, 4]) || ...
        capture.pointCount ~= point_count || any(~isfinite(capture.channels(:)))
    error('rf47_lms_content_capture:CaptureShape', ...
        'Capture requires the requested finite samples on each of four channels.');
end
if ~isfinite(capture.sampleRateHz) || abs(capture.sampleRateHz - 40e9) > 1
    error('rf47_lms_content_capture:SampleRate', ...
        'BTB capture requires 40 GSa/s; received %.9g Sa/s.', capture.sampleRateHz);
end
if isempty(regexp(capture.systemError, '^\s*\+?0\s*(,|$)', 'once'))
    error('rf47_lms_content_capture:ScopeError', ...
        'Scope reported an acquisition error: %s', capture.systemError);
end
for channel = 1:4
    fields = str2double(strsplit(capture.preamble{channel}, ','));
    if numel(fields) < 10 || any(~isfinite(fields(1:10))) || ...
            fields(1) ~= 0 || fields(3) < point_count || fields(8) <= 0
        error('rf47_lms_content_capture:Preamble', ...
            'Invalid BYTE preamble on CH%d.', channel);
    end
    % Undo the existing helper's voltage conversion; single precision is
    % ample to recover the original integer BYTE codes by rounding.
    codes = round(double(capture.channels(:, channel)) / fields(8) + ...
        fields(10) + fields(9));
    rails = nnz(codes <= 0 | codes >= 255);
    if rails > 0
        error('rf47_lms_content_capture:AdcClipping', ...
            'CH%d contains %d samples at the ADC rails; reduce clipping before capture.', ...
            channel, rails);
    end
end
end

