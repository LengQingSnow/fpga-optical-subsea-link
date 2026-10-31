function summary = offline_summarize_idle_frames(frames, cfg)
%OFFLINE_SUMMARIZE_IDLE_FRAMES Compare idle-frame PRBS31 filler exactly.
summary = struct('ber', NaN, 'bitErrors', 0, 'comparedBits', 0, ...
    'frameCount', frames.frameCount, 'crcGoodFrames', sum(frames.crcOk));
errors = 0;
for index = 1:frames.frameCount
    expected = zeros(cfg.frameBytes, 1, 'uint8');
    expected(1:8) = reshape(cfg.syncWord, 1, []);
    expected(9) = cfg.protocolVersion;
    expected(10) = uint8(6);
    expected(13:16) = write_be_u32(frames.sequence(index));
    expected(17:cfg.framePayloadEnd) = aggregate_prbs31_bytes( ...
        frames.sequence(index), cfg.framePayloadEnd - 16);
    expected(cfg.framePayloadEnd + 1:cfg.frameBytes) = write_be_u32( ...
        crc32_msb(expected(1:cfg.framePayloadEnd)));
    difference = bitxor(frames.bytes(:, index), expected);
    for bit = 1:8
        errors = errors + sum(bitget(difference, bit));
    end
end
summary.bitErrors = errors;
summary.comparedBits = frames.frameCount * cfg.frameBytes * 8;
summary.ber = errors / max(1, summary.comparedBits);
end

function bytes = write_be_u32(value)
value = uint32(value);
bytes = uint8([bitshift(value, -24), bitand(bitshift(value, -16), 255), ...
    bitand(bitshift(value, -8), 255), bitand(value, 255)]).';
end
