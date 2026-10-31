function selftest_dynamic_frame_relock()
%SELFTEST_DYNAMIC_FRAME_RELOCK Verify frame parsing across a byte slip.

script_dir = fileparts(mfilename('fullpath'));
cfg = rf47_default_config(script_dir);
frame_count = 20;
frame_bytes = zeros(cfg.frameBytes, frame_count, 'uint8');
for index = 1:frame_count
    frame = zeros(cfg.frameBytes, 1, 'uint8');
    frame(1:8) = cfg.syncWord(:);
    frame(9) = cfg.protocolVersion;
    frame(10) = uint8(6);
    frame(13:16) = write_u32(index - 1);
    frame(17:cfg.framePayloadEnd) = uint8(mod((0:491)' * 73 + ...
        index * 17 + 11, 256));
    frame(cfg.framePayloadEnd + 1:end) = ...
        write_u32(double(crc32_msb(frame(1:cfg.framePayloadEnd))));
    frame_bytes(:, index) = frame;
end

stream = [reshape(frame_bytes(:, 1:10), [], 1); ...
    zeros(32, 1, 'uint8'); reshape(frame_bytes(:, 11:20), [], 1)];
[fixed_frames, ~] = parse_aggregate_frames(stream, cfg);
[relocked_frames, ~] = parse_aggregate_frames_relocked(stream, cfg);
assert(sum(fixed_frames.crcOk) < frame_count);
assert(relocked_frames.frameCount == frame_count);
assert(all(relocked_frames.crcOk));
assert(isequal(relocked_frames.sequence, uint32((0:frame_count - 1)')));
fprintf(['selftest_dynamic_frame_relock: PASS (%d/%d CRC-good ' ...
    'across a 32-byte slip).\n'], sum(relocked_frames.crcOk), frame_count);
end

function bytes = write_u32(value)
value = uint32(value);
bytes = uint8([bitshift(value, -24); bitand(bitshift(value, -16), 255); ...
    bitand(bitshift(value, -8), 255); bitand(value, 255)]);
end
