function capture = rf47_lms_btb_scope_read(host_name, tcp_port, point_count, timeout_seconds)
%RF47_LMS_BTB_SCOPE_READ Acquire a short four-channel BYTE record from DS81304.
% Page-specific transport; waits for a completed single acquisition before reading.
% Uses Java sockets so MATLAB 2016a does not require Instrument Control Toolbox.

if nargin < 1 || isempty(host_name)
    host_name = '192.168.1.12';
end
if nargin < 2 || isempty(tcp_port)
    tcp_port = 5555;
end
if nargin < 3 || isempty(point_count)
    point_count = 1000000;
end
if nargin < 4 || isempty(timeout_seconds)
    timeout_seconds = 30;
end
validateattributes(host_name, {'char'}, {'row'}, mfilename, 'host_name');
validateattributes(tcp_port, {'numeric'}, {'scalar', 'integer', 'positive'}, mfilename, 'tcp_port');
validateattributes(point_count, {'numeric'}, {'scalar', 'integer', 'positive'}, mfilename, 'point_count');

socket = java.net.Socket();
cleanup_socket = onCleanup(@() stop_and_close_socket(socket));
endpoint = java.net.InetSocketAddress(host_name, tcp_port);
socket.connect(endpoint, 5000);
socket.setTcpNoDelay(true);
socket.setSoTimeout(max(1000, round(timeout_seconds * 1000)));
input_stream = socket.getInputStream();
output_stream = socket.getOutputStream();
read_channel = java.nio.channels.Channels.newChannel(input_stream);

started_at = now;
% A short memory depth can leave only a few interleaved frames per port,
% which is insufficient to close a UDP/AXDS packet. Keep at least 1 Mpoint
% available whenever the caller requests a live content capture.
memory_depth = max(point_count, 1000000);
write_scpi(output_stream, sprintf(':ACQ:MDEP %d', memory_depth));
pause(0.10);
write_scpi(output_stream, ':SING');
wait_for_single_acquisition(output_stream, input_stream, timeout_seconds);
acquired_at = now;
pause(0.05);

capture = struct();
capture.host = host_name;
capture.port = tcp_port;
capture.capturedAt = datestr(acquired_at, 30);
capture.capturedAtDatenum = acquired_at;
capture.startedAtDatenum = started_at;
capture.acquiredAtDatenum = acquired_at;
capture.channels = [];
capture.preamble = cell(1, 4);
capture.sampleRateHz = NaN;
capture.pointCount = point_count;
capture.requestedPointCount = point_count;
capture.reportedPointCountByChannel = zeros(1, 4);

for channel = 1:4
    write_scpi(output_stream, sprintf(':WAV:SOUR CHAN%d', channel));
    write_scpi(output_stream, ':WAV:MODE RAW');
    write_scpi(output_stream, ':WAV:FORM BYTE');
    % The scope retains the final waveform window from the preceding read.
    % Reset it before PRE? so the reported length covers the full record.
    write_scpi(output_stream, ':WAV:STAR 1');
    write_scpi(output_stream, sprintf(':WAV:STOP %d', point_count));
    preamble_text = query_scpi(output_stream, input_stream, ':WAV:PRE?');
    fields = str2double(strsplit(preamble_text, ','));
    if numel(fields) < 10
        error('rf47_lms_btb_scope_read:Preamble', ...
            'Unexpected CH%d preamble: %s', channel, preamble_text);
    end
    reported_point_count = round(fields(3));
    if ~isfinite(reported_point_count) || reported_point_count < 1000
        error('rf47_lms_btb_scope_read:ReportedPointCount', ...
            'CH%d reports an invalid waveform length of %.12g points.', ...
            channel, fields(3));
    end
    capture.reportedPointCountByChannel(channel) = reported_point_count;
    if channel == 1
        capture.pointCount = min(point_count, reported_point_count);
        capture.channels = zeros(capture.pointCount, 4, 'single');
    elseif reported_point_count < capture.pointCount
        error('rf47_lms_btb_scope_read:ChannelPointCount', ...
            'CH%d reports %d points, fewer than CH1 capture length %d.', ...
            channel, reported_point_count, capture.pointCount);
    end
    x_increment = fields(5);
    y_increment = fields(8);
    y_origin = fields(9);
    y_reference = fields(10);
    maximum_block_points = 1000000;
    for first_point = 1:maximum_block_points:capture.pointCount
        last_point = min(capture.pointCount, ...
            first_point + maximum_block_points - 1);
        write_scpi(output_stream, sprintf(':WAV:STAR %d', first_point));
        write_scpi(output_stream, sprintf(':WAV:STOP %d', last_point));
        write_scpi(output_stream, ':WAV:DATA?');
        raw = read_scpi_block(read_channel, input_stream);
        expected_count = last_point - first_point + 1;
        if numel(raw) ~= expected_count
            error('rf47_lms_btb_scope_read:PointCount', ...
                'CH%d returned %d points for %d-%d, expected %d.', ...
                channel, numel(raw), first_point, last_point, ...
                expected_count);
        end
        capture.channels(first_point:last_point, channel) = single( ...
            (double(raw(:)) - y_reference - y_origin) * y_increment);
    end
    capture.preamble{channel} = preamble_text;
    if channel == 1
        capture.sampleRateHz = 1 / x_increment;
    elseif abs(1 / x_increment - capture.sampleRateHz) > 1
        error('rf47_lms_btb_scope_read:SampleRate', 'Channel sample rates are inconsistent.');
    end
end

capture.systemError = query_scpi(output_stream, input_stream, ':SYST:ERR?');
clear cleanup_socket;
end

function write_scpi(output_stream, command)
bytes = uint8([double(command), 10]);
output_stream.write(bytes, 0, numel(bytes));
output_stream.flush();
end

function response = query_scpi(output_stream, input_stream, command)
write_scpi(output_stream, command);
characters = zeros(1, 256, 'uint8');
count = 0;
while true
    value = input_stream.read();
    if value < 0
        error('rf47_lms_btb_scope_read:Connection', 'Connection closed while reading SCPI response.');
    end
    if value == 10
        break;
    end
    if value ~= 13
        count = count + 1;
        if count > numel(characters)
            characters(end + 1:end + 256) = 0;
        end
        characters(count) = uint8(value);
    end
end
response = strtrim(char(characters(1:count)));
end

function wait_for_single_acquisition(output_stream, input_stream, timeout_seconds)
% Match the independently validated capture: let the single engine settle,
% then require its natural STOP before retrieving the stopped memory.
started = tic;
pause(0.50);
last_state = '';
while toc(started) < timeout_seconds
    last_state = query_scpi(output_stream, input_stream, ':TRIG:STAT?');
    if strcmpi(last_state, 'STOP')
        write_scpi(output_stream, ':STOP');
        pause(0.10);
        return;
    end
    pause(0.25);
end
error('rf47_lms_btb_scope_read:AcquisitionTimeout', ...
    'Single acquisition did not complete in %.0f seconds (state %s).', ...
    timeout_seconds, last_state);
end

function payload = read_scpi_block(read_channel, input_stream)
marker = input_stream.read();
while marker ~= double('#')
    if marker < 0
        error('rf47_lms_btb_scope_read:Connection', 'Connection closed before binary block.');
    end
    marker = input_stream.read();
end
digit_count = input_stream.read() - double('0');
if digit_count < 1 || digit_count > 9
    error('rf47_lms_btb_scope_read:BlockHeader', 'Invalid SCPI binary block header.');
end
length_bytes = read_exact(read_channel, digit_count);
payload_count = str2double(char(length_bytes));
if ~isfinite(payload_count) || payload_count < 1
    error('rf47_lms_btb_scope_read:BlockLength', 'Invalid SCPI binary block length.');
end
payload = read_exact(read_channel, payload_count);
terminator = input_stream.read();
if terminator == 13
    terminator = input_stream.read();
end
if terminator ~= 10
    error('rf47_lms_btb_scope_read:BlockTerminator', 'Invalid SCPI binary block terminator.');
end
end

function data = read_exact(read_channel, expected_count)
byte_buffer = java.nio.ByteBuffer.allocate(expected_count);
while byte_buffer.hasRemaining()
    count = read_channel.read(byte_buffer);
    if count <= 0
        error('rf47_lms_btb_scope_read:Connection', 'Connection closed during binary transfer.');
    end
end
data = typecast(byte_buffer.array(), 'uint8');
data = reshape(data, 1, []);
end

function close_socket(socket)
try
    socket.close();
catch
end
end


function stop_and_close_socket(socket)
try
    output_stream = socket.getOutputStream();
    write_scpi(output_stream, ':STOP');
catch
end
close_socket(socket);
end
