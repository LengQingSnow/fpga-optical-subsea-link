function window = rf47_page6_packet_ber(packets, frames, references, cfg)
%RF47_PAGE6_PACKET_BER XOR known payload bytes in this capture only.
% Conditional, CRC-good payload BER; NOT the complete physical-link BER.
% Do not use merged objects: they replace damaged data and retain old bytes.
% Repeated packets in a NEW acquisition are new received observations.
% Unmatched references and incomplete/bad-CRC packets are not zero errors.
window = struct('errorsByStream', [0 0], 'bitsByStream', [0 0], ...
    'frameCount', 0, 'badFrames', 0, 'packetCount', 0, ...
    'unmatchedPackets', 0);
if nargin == 0
    return;
end
window.frameCount = double(frames.frameCount);
window.badFrames = sum(~frames.crcOk);
if isempty(packets) || isempty(packets.bytes)
    return;
end
[axds, ~] = parse_axds_packets(packets, cfg);
for index = 1:numel(axds.payload)
    stream = double(axds.datasetType(index));
    if ~axds.transportCrcOk(index) || ~ismember(stream, [1 2])
        continue;
    end
    object_id = double(axds.objectId(index));
    expected = [];
    if isstruct(references)
        if stream == 1 && isfield(references, 'images') && ...
                object_id >= 1 && object_id <= numel(references.images)
            expected = references.images{object_id};
        elseif stream == 2 && object_id == 1 && ...
                isfield(references, 'waveformBytes')
            expected = references.waveformBytes;
        end
    end
    count = double(axds.validLength(index));
    first = double(axds.objectOffset(index)) + 1;
    last = first + count - 1;
    if isempty(expected) || numel(expected) ~= double(axds.objectLength(index)) || ...
            count < 1 || last > numel(expected) || ...
            numel(axds.payload{index}) ~= count
        window.unmatchedPackets = window.unmatchedPackets + 1;
        continue;
    end
    actual = uint8(axds.payload{index}(:));
    expected = uint8(expected(:));
    difference = bitxor(actual, expected(first:last));
    error_count = 0;
    for bit_index = 1:8
        error_count = error_count + sum(double(bitget(difference, bit_index)));
    end
    window.errorsByStream(stream) = window.errorsByStream(stream) + error_count;
    window.bitsByStream(stream) = window.bitsByStream(stream) + 8 * count;
    window.packetCount = window.packetCount + 1;
end
end
