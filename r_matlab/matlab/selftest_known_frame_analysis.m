function selftest_known_frame_analysis()
%SELFTEST_KNOWN_FRAME_ANALYSIS Verify exact bad-frame error localization.

script_dir = fileparts(mfilename('fullpath'));
cfg = rf47_default_config(script_dir);
cfg.knownFrameMaximumPayloadBer = 0.12;

references.images = repmat({zeros(0, 1, 'uint8')}, 45, 1);
references.imageRgb = cell(45, 1);
rng(47);
references.waveformBytes = uint8(randi([0, 255], 28800, 1));
references.waveformSamples = zeros(14400, 1, 'int16');
references.imageWidth = 320;
references.imageHeight = 240;
references.waveformSampleRateHz = 20;

catalog = build_known_axds_catalog(references);
packet0 = build_expected_axds_packet(catalog(2), uint32(0));
packet1 = build_expected_axds_packet(catalog(2), uint32(1));

frame_count = 12;
tx_frames = zeros(cfg.frameBytes, frame_count, 'uint8');
for frame_index = 1:frame_count
    tx_frames(:, frame_index) = build_idle_frame(frame_index - 1, cfg);
end
tx_frames(:, 2) = build_data_frame(1, packet0(1:488), 7, true, false, cfg);
tx_frames(:, 3) = build_data_frame(2, packet0(489:976), 7, false, false, cfg);
tx_frames(:, 4) = build_data_frame(3, packet0(977:end), 7, false, true, cfg);
tx_frames(:, 5) = build_data_frame(4, packet1(1:488), 8, true, false, cfg);
tx_frames(:, 6) = build_data_frame(5, packet1(489:976), 8, false, false, cfg);
tx_frames(:, 7) = build_data_frame(6, packet1(977:end), 8, false, true, cfg);

rx_frames = tx_frames;
rx_frames(1, 3) = bitxor(rx_frames(1, 3), uint8(1));
rx_frames(100, 3) = bitxor(rx_frames(100, 3), uint8(4));
rx_frames(200, 9) = bitxor(rx_frames(200, 9), uint8(32));

[frames, segments] = parse_aggregate_frames(rx_frames(:), cfg);
[summary, details] = analyze_known_frame_errors( ...
    frames, segments, references, '', cfg);
fprintf(['known-frame self-test diagnostics: bad=%d full=%d bits=%d ' ...
    'errors=%d frame3=%d frame9=%d packets=%d\n'], ...
    summary.crcBadFrames, summary.fullyReconstructedBadFrames, ...
    summary.comparedBits, summary.bitErrors, details.frameBitErrors(3), ...
    details.frameBitErrors(9), sum(details.packetResolved));

assert(summary.crcBadFrames == 2);
assert(summary.fullyReconstructedBadFrames == 2);
assert(summary.bitErrors == 3);
assert(summary.comparedBits == frame_count * cfg.frameBytes * 8);
assert(details.frameBitErrors(3) == 2);
assert(details.frameBitErrors(9) == 1);
assert(details.packetResolved(1));
assert(details.packetBitErrors(1) == 1);
assert(crc32_ieee(uint8('123456789')) == uint32(hex2dec('CBF43926')));
fprintf('selftest_known_frame_analysis: PASS (%d exact bit errors)\n', ...
    summary.bitErrors);
end

function frame = build_idle_frame(sequence, cfg)
frame = zeros(cfg.frameBytes, 1, 'uint8');
frame(1:8) = cfg.syncWord(:);
frame(9) = cfg.protocolVersion;
frame(10) = uint8(6);
frame(13:16) = write_be_u32(sequence);
frame(17:cfg.framePayloadEnd) = aggregate_prbs31_bytes( ...
    sequence, cfg.framePayloadEnd - 16);
frame(cfg.framePayloadEnd + 1:end) = write_be_u32( ...
    crc32_msb(frame(1:cfg.framePayloadEnd)));
end

function frame = build_data_frame(sequence, payload, packet_id, sop, eop, cfg)
payload = uint8(payload(:));
frame = zeros(cfg.frameBytes, 1, 'uint8');
frame(1:8) = cfg.syncWord(:);
frame(9) = cfg.protocolVersion;
frame(10) = uint8(7);
segment_bytes = 4 + numel(payload);
frame(11:12) = write_be_u16(segment_bytes);
frame(13:16) = write_be_u32(sequence);
frame(17:cfg.framePayloadEnd) = aggregate_prbs31_bytes( ...
    sequence, cfg.framePayloadEnd - 16);
frame(17) = uint8(1 + 4 * sop + 8 * eop);
frame(18) = uint8(packet_id);
frame(19:20) = write_be_u16(numel(payload));
frame(21:20 + numel(payload)) = payload;
frame(cfg.framePayloadEnd + 1:end) = write_be_u32( ...
    crc32_msb(frame(1:cfg.framePayloadEnd)));
end

function bytes = write_be_u16(value)
value = uint16(value);
bytes = uint8([bitshift(value, -8); bitand(value, uint16(255))]);
end

function bytes = write_be_u32(value)
value = uint32(value);
bytes = uint8([bitshift(value, -24); ...
    bitand(bitshift(value, -16), uint32(255)); ...
    bitand(bitshift(value, -8), uint32(255)); ...
    bitand(value, uint32(255))]);
end
