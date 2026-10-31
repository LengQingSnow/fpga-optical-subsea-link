function selftest_rf47_pipeline()
%SELFTEST_RF47_PIPELINE Exercise waveform recovery and protocol parsing.

script_dir = fileparts(mfilename('fullpath'));
cfg = rf47_default_config(script_dir);
cfg.pulseShape = 'rrc';
cfg.timingScanSymbols = 65536;
cfg.packingScanSymbols = 65536;
cfg.resampleChunkPoints = 65536;

frame_count = 48;
frames_tx = zeros(cfg.frameBytes, frame_count, 'uint8');
payload = uint8(mod((0:63)' * 17 + 3, 256));
axds_packet = build_axds_packet(payload);
for frame_index = 1:frame_count
    if frame_index == 20
        segment = [uint8(13); uint8(7); ...
            uint8(bitshift(uint16(numel(axds_packet)), -8)); ...
            uint8(bitand(uint16(numel(axds_packet)), 255)); axds_packet];
        frames_tx(:, frame_index) = build_frame(frame_index - 1, segment, cfg);
    else
        frames_tx(:, frame_index) = build_frame(frame_index - 1, ...
            zeros(0, 1, 'uint8'), cfg);
    end
end

tx_bytes = frames_tx(:);
nibbles = zeros(numel(tx_bytes) * 2, 1, 'uint8');
nibbles(1:2:end) = bitshift(tx_bytes, -4);
nibbles(2:2:end) = bitand(tx_bytes, uint8(15));
bits = false(numel(nibbles), 4);
bits(:, 1) = bitget(nibbles, 4) ~= 0;
bits(:, 2) = bitget(nibbles, 3) ~= 0;
bits(:, 3) = bitget(nibbles, 2) ~= 0;
bits(:, 4) = bitget(nibbles, 1) ~= 0;

h = double(cfg.rrcCoefficients(:));
waveform_8g = zeros(2 * size(bits, 1) + numel(h) - 1, 4);
for lane = 1:4
    impulses = zeros(2 * size(bits, 1), 1);
    impulses(1:2:end) = 2 * double(bits(:, lane)) - 1;
    waveform_8g(:, lane) = conv(impulses, h);
end

scope_rate = 10e9;
tx_rate = 2 * cfg.symbolRateHz;
scope_points = floor((size(waveform_8g, 1) - 2) * scope_rate / tx_rate);
scope_time = (0:scope_points - 1)' / scope_rate;
tx_time = (0:size(waveform_8g, 1) - 1)' / tx_rate;
scope_waveform = zeros(scope_points, 4, 'single');
rng(47);
for lane = 1:4
    clean = interp1(tx_time, waveform_8g(:, lane), scope_time, 'linear');
    scope_waveform(:, lane) = single(clean + 0.01 * std(clean) * ...
        randn(size(clean)));
end

capture.channels = scope_waveform;
capture.sampleRateHz = scope_rate;
capture.pointCount = scope_points;
capture.xOriginSeconds = 0;
capture.directory = '<synthetic>';
capture.sourceFormat = 'self-test';

[lane_bits_fixed, ~] = recover_dpqpsk_symbols(capture, cfg);
timing_model.anchorSymbols = [0; size(bits, 1) - 1];
timing_model.anchorPhaseSymbols = zeros(2, 4);
timing_model.phaseAtStart = zeros(1, 4);
timing_model.phaseSlopeUiPerSymbol = 0;
timing_model.clockOffsetPpm = 0;
timing_model.estimatedSymbolRateHz = cfg.symbolRateHz;
timing_model.effectiveSamplesPerSymbol = ...
    capture.sampleRateHz / cfg.symbolRateHz;
[lane_bits_continuous, ~] = recover_dpqpsk_continuous( ...
    capture, cfg, timing_model);
comparison_count = min(size(lane_bits_fixed, 1), ...
    size(lane_bits_continuous, 1));
assert(isequal(lane_bits_fixed(1:comparison_count, :), ...
    lane_bits_continuous(1:comparison_count, :)));
fprintf(['Continuous resampler equivalence: PASS (%d symbols, ' ...
    '0 differing decisions)\n'], comparison_count);

[lane_bits, recovery] = recover_dpqpsk_symbols(capture, cfg);
fprintf(['Self-test timing phases %.6f, %.6f, %.6f, %.6f, ' ...
    'phase sync hits %d\n'], recovery.timingPhaseSymbols, ...
    max(recovery.phaseSyncHits));
for lane = 1:4
    [lane_ber, lane_shift, lane_invert] = best_known_alignment( ...
        lane_bits(:, lane), bits(:, lane), 64);
    fprintf('Lane %d pre-pack BER %.3e, shift %d, invert %d\n', ...
        lane, lane_ber, lane_shift, lane_invert);
end
[rx_bytes, packing] = pack_dpqpsk_bytes(lane_bits, cfg);
[frames_rx, segments] = parse_aggregate_frames(rx_bytes, cfg);
[packets, udp_stats] = reassemble_udp_packets(segments, frames_rx, cfg);
[axds, axds_stats] = parse_axds_packets(packets, cfg);

assert(recovery.symbolCount > 4096);
assert(packing.scanSyncHits > 1);
assert(sum(frames_rx.crcOk) > 10);
assert(udp_stats.packetCount == 1);
assert(axds_stats.validPacketCount == 1);
assert(isequal(axds.payload{1}, payload));
fprintf('selftest_rf47_pipeline: PASS (%d CRC-good frames, %d bytes)\n', ...
    sum(frames_rx.crcOk), numel(rx_bytes));
selftest_known_frame_analysis();
end

function [best_ber, best_shift, best_invert] = best_known_alignment( ...
    recovered, expected, maximum_shift)
best_ber = inf;
best_shift = 0;
best_invert = 0;
for shift = -maximum_shift:maximum_shift
    recovered_start = max(1, 1 + shift);
    expected_start = max(1, 1 - shift);
    count = min(numel(recovered) - recovered_start + 1, ...
        numel(expected) - expected_start + 1);
    if count < 1000
        continue;
    end
    actual = recovered(recovered_start:recovered_start + count - 1);
    reference = expected(expected_start:expected_start + count - 1);
    ber = mean(actual ~= reference);
    if ber < best_ber
        best_ber = ber;
        best_shift = shift;
        best_invert = 0;
    end
    if 1 - ber < best_ber
        best_ber = 1 - ber;
        best_shift = shift;
        best_invert = 1;
    end
end
end

function packet = build_axds_packet(payload)
packet = zeros(32 + numel(payload), 1, 'uint8');
packet(1:4) = uint8([hex2dec('41'); hex2dec('58'); ...
    hex2dec('44'); hex2dec('53')]);
packet(5) = 1;
packet(6) = 2;
packet(7) = 2;
packet(8) = 3;
packet(13:14) = uint8([0; 1]);
packet(15:16) = write_be_u16(numel(payload));
packet(25:28) = write_be_u32(numel(payload));
packet(33:end) = payload;
end

function frame = build_frame(sequence, segment, cfg)
frame = zeros(cfg.frameBytes, 1, 'uint8');
frame(1:8) = cfg.syncWord(:);
frame(9) = cfg.protocolVersion;
filler_index = (0:491)';
frame(17:508) = uint8(mod(filler_index * 73 + double(sequence) * 17 + 11, 256));
if isempty(segment)
    frame(10) = 6;
else
    frame(10) = 7;
    frame(11:12) = write_be_u16(numel(segment));
    frame(17:16 + numel(segment)) = segment;
end
frame(13:16) = write_be_u32(sequence);
crc = crc32_msb(frame(1:508));
frame(509:512) = write_be_u32(double(crc));
end

function bytes = write_be_u16(value)
value = uint16(value);
bytes = uint8([bitshift(value, -8); bitand(value, uint16(255))]);
end

function bytes = write_be_u32(value)
value = uint32(value);
bytes = uint8([bitshift(value, -24); bitand(bitshift(value, -16), 255); ...
    bitand(bitshift(value, -8), 255); bitand(value, 255)]);
end
