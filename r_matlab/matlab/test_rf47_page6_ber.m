function test_rf47_page6_ber()
%TEST_RF47_PAGE6_BER Offline counters/UI regression. Never connects hardware.
root = fileparts(mfilename('fullpath'));
test_dir = fullfile(fileparts(root), 'backup', ...
    'page6_ber_before_20260913', 'tests');
cfg = rf47_default_config(root);
references = struct('images', {{uint8([0; 3; 255; 7])}}, ...
    'waveformBytes', uint8([128; 0; 32; 255]));
p1 = make_packet(1, 1, 0, 4, uint8([0; 3]));
p2 = make_packet(2, 1, 0, 4, uint8([128; 0; 32; 255]));
packets = struct('bytes', {{p1; p2}}, 'portId', uint8([1; 2]), ...
    'allFramesCrcOk', true(2, 1));
frames = struct('frameCount', 3, 'crcOk', [true; true; false]);
w = rf47_page6_packet_ber(packets, frames, references, cfg);
assert(isequal(w.bitsByStream, [16 32]));
assert(isequal(w.errorsByStream, [0 0]));
assert(w.badFrames == 1 && w.frameCount == 3);

% A known injected payload difference is counted by XOR, NOT forced to 0
% merely because transport CRC is good (e.g. a changed reference dataset).
packets.bytes{1}(33) = uint8(1);
w2 = rf47_page6_packet_ber(packets, frames, references, cfg);
assert(isequal(w2.errorsByStream, [1 0]));
assert(sum(w2.errorsByStream) / sum(w2.bitsByStream) == 1 / 48);
packets.allFramesCrcOk(1) = false;
w3 = rf47_page6_packet_ber(packets, frames, references, cfg);
assert(isequal(w3.bitsByStream, [0 32]));
assert(isequal(w3.errorsByStream, [0 0]));

% Offset, unknown object, incompatible reference length, out-of-bounds.
packets.allFramesCrcOk(1) = true;
packets.bytes{1} = make_packet(1, 1, 2, 4, uint8([255; 7]));
offset = rf47_page6_packet_ber(packets, frames, references, cfg);
assert(isequal(offset.errorsByStream, [0 0]));
for kind = 1:3
    if kind == 1
        packets.bytes{1} = make_packet(1, 9, 0, 4, uint8([1; 2]));
    elseif kind == 2
        packets.bytes{1} = make_packet(1, 1, 0, 8, uint8([1; 2]));
    else
        packets.bytes{1} = make_packet(1, 1, 4, 4, uint8([1; 2]));
    end
    unmatched = rf47_page6_packet_ber(packets, frames, references, cfg);
    assert(unmatched.bitsByStream(1) == 0 && unmatched.unmatchedPackets == 1);
end

stamp = datenum(2026, 9, 13, 12, 0, 0);
h = rf47_page6_ber_history([], w2, stamp, 3);
assert(h.ber(1, 1) == 1 / 48); % weighted, not mean([1/16 0])
h = rf47_page6_ber_history(h, rf47_page6_packet_ber(), stamp + 1/86400, 3);
assert(all(isnan(h.ber(end, :))));
assert(sum(h.totalBits) == 48);
h = rf47_page6_ber_history(h, w, stamp + 2/86400, 3);
assert(all(h.ber(end, :) == 0));
h = rf47_page6_ber_history(h, w, stamp + 3/86400, 3);
assert(numel(h.time) == 3 && sum(h.totalBits) == 144);
assert(h.captureCount == 4 && h.totalErrors(1) == 1);
h_one = rf47_page6_ber_history([], w3, stamp, 3);
assert(isnan(h_one.ber(2)) && h_one.ber(1) == 0);
bad = w;
bad.errorsByStream(1) = bad.bitsByStream(1) + 1;
caught = false;
try
    rf47_page6_ber_history([], bad, stamp, 3);
catch exception
    caught = strcmp(exception.identifier, 'rf47_page6_ber_history:Counts');
end
assert(caught);
fprintf('PASS packet XOR, CRC filtering, reference bounds, window/total counts, NaN gaps.\n');

% Same synthetic aggregate bytes, old two-output vs new three-output API.
stub_dir = fullfile(test_dir, 'stubs');
addpath(stub_dir, '-begin');
path_cleanup = onCleanup(@() rmpath(stub_dir));
cfg.opticalCma = true;
cfg.opticalLop10 = true;
capture = struct('channels', zeros(64, 4), 'sampleRateHz', 40e9, ...
    'testBytes', [make_frame(p1, 1, 1, cfg); make_frame(p2, 2, 2, cfg)]);
[state_old, decoded_old] = update_realtime_decode([], capture, cfg, references);
[state_new, decoded_new, measured] = update_realtime_decode([], capture, cfg, references);
assert(isempty(decoded_new.error), decoded_new.error);
assert(isequaln(state_old, state_new) && isequaln(decoded_old, decoded_new));
assert(isequal(measured.bitsByStream, [16 32]));
[~, decoded_next, measured_next] = update_realtime_decode(state_new, capture, cfg, references);
assert(decoded_next.image.comparedBits == 16); % merged object unchanged
assert(isequal(measured_next.bitsByStream, [16 32])); % new physical observation
capture.testBytes = uint8(zeros(64, 1));
[~, failed, measured_failed] = update_realtime_decode(state_new, capture, cfg, references);
assert(~isempty(failed.error) && all(measured_failed.bitsByStream == 0));
clear path_cleanup;
fprintf('PASS decoder two-output regression, current-window measurement, failed-sync isolation.\n');

% Construct the actual six-tab GUI without the startup script, JTAG, or timer.
previous_visible = get(0, 'DefaultFigureVisible');
set(0, 'DefaultFigureVisible', 'off');
visible_cleanup = onCleanup(@() set(0, 'DefaultFigureVisible', previous_visible));
app = main_realtime_eye(struct('autoStart', false));
figure_cleanup = onCleanup(@() close(app.figure));
assert(strcmp(app.timer.Running, 'off'));
assert(numel(get(app.tabs, 'Children')) == 6);
set(app.tabs, 'SelectedTab', app.dispersion_optical_tab);
panels = findall(app.dispersion_optical_tab, 'Type', 'uipanel');
assert(numel(panels) == 3);
for index = 1:3
    position = get(panels(index), 'Position');
    assert(abs(position(3) - 0.32) < 1e-12);
end
rf47_page6_render_ber(app.dispersion_optical_ber_view, h);
assert(strcmp(get(app.dispersion_optical_ber_view.axes, 'YScale'), 'linear'));
assert(~isempty(strfind(get(app.dispersion_optical_ber_view.last, 'String'), '0.000e+00')));
rf47_page6_render_ber(app.dispersion_optical_ber_view, h_one);
empty_h = rf47_page6_ber_history([], rf47_page6_packet_ber(), stamp, 3);
rf47_page6_render_ber(app.dispersion_optical_ber_view, empty_h);
assert(~isempty(strfind(get(app.dispersion_optical_ber_view.last, 'String'), '--')));

% UI preview uses generated test graphics, NOT experimental measurements.
rf47_page6_render_ber(app.dispersion_optical_ber_view, h);
image('Parent', app.dispersion_optical_image_axes, ...
    'CData', repmat(uint8(linspace(0,255,160)), [120 1 3]));
axis(app.dispersion_optical_image_axes, 'image');
axis(app.dispersion_optical_image_axes, 'off');
title(app.dispersion_optical_image_axes, 'LAYOUT TEST - not received image');
t = linspace(0, 10, 1000);
plot(app.dispersion_optical_wave_axes, t, sin(2*pi*t).*exp(-t/5));
title(app.dispersion_optical_wave_axes, 'LAYOUT TEST - not received waveform');
set(app.figure, 'PaperPositionMode', 'auto', 'InvertHardcopy', 'off');
drawnow;
print(app.figure, fullfile(test_dir, 'page6_layout_test.png'), '-dpng', '-r100');
callback = get(app.clear_button, 'Callback');
callback(app.clear_button, []);
cleared = guidata(app.figure);
assert(isempty(cleared.dispersionOpticalBerHistory));
assert(~isempty(strfind(get(cleared.dispersion_optical_ber_view.last, 'String'), '--')));
assert(strcmp(app.timer.Running, 'off'));
clear figure_cleanup visible_cleanup;
fprintf('PASS actual six-tab layout, zero/empty rendering, clear/reset, timer remains stopped.\n');
fprintf('ALL PAGE-6 TESTS PASS. No hardware used.\n');
end

function packet = make_packet(kind, id, offset, length_bytes, payload)
packet = zeros(32 + numel(payload), 1, 'uint8');
packet(1:4) = uint8('AXDS');
packet(5:7) = uint8([1 kind kind]);
packet(13:14) = be(id, 2);
packet(15:16) = be(numel(payload), 2);
packet(21:24) = be(offset, 4);
packet(25:28) = be(length_bytes, 4);
packet(33:end) = payload;
end

function frame = make_frame(packet, port, sequence, cfg)
frame = zeros(512, 1, 'uint8');
frame(1:8) = cfg.syncWord;
frame(9:10) = uint8([1 7]);
frame(11:12) = be(4 + numel(packet), 2);
frame(13:16) = be(sequence, 4);
frame(17) = uint8(12 + port - 1); % SOP+EOP+zero-based port
frame(18) = uint8(sequence);
frame(19:20) = be(numel(packet), 2);
frame(21:20 + numel(packet)) = packet;
frame(509:512) = be(crc32_msb(frame(1:508)), 4);
end

function bytes = be(value, count)
bytes = zeros(count, 1, 'uint8');
for index = 1:count
    bytes(index) = uint8(bitand(bitshift(uint32(value), -8*(count-index)), 255));
end
end
