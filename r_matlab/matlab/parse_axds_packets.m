function [axds, stats] = parse_axds_packets(packets, cfg)
%PARSE_AXDS_PACKETS Decode the 32-byte ax7101 dataset application header.

capacity = max(64, numel(packets.bytes));
axds.datasetType = zeros(capacity, 1, 'uint8');
axds.sourcePort = zeros(capacity, 1, 'uint8');
axds.aggregatePort = zeros(capacity, 1, 'uint8');
axds.flags = zeros(capacity, 1, 'uint8');
axds.datasetCycle = zeros(capacity, 1, 'uint32');
axds.objectId = zeros(capacity, 1, 'uint16');
axds.validLength = zeros(capacity, 1, 'uint16');
axds.packetSequence = zeros(capacity, 1, 'uint32');
axds.objectOffset = zeros(capacity, 1, 'uint32');
axds.objectLength = zeros(capacity, 1, 'uint32');
axds.objectCrc32 = zeros(capacity, 1, 'uint32');
axds.transportCrcOk = false(capacity, 1);
axds.payload = cell(capacity, 1);

valid_count = 0;
bad_magic = 0;
bad_header = 0;
magic = uint8([hex2dec('41'); hex2dec('58'); hex2dec('44'); hex2dec('53')]);

for packet_index = 1:numel(packets.bytes)
    bytes = uint8(packets.bytes{packet_index}(:));
    if numel(bytes) < cfg.minimumPacketBytes
        bad_header = bad_header + 1;
        continue;
    end
    if any(bytes(1:4) ~= magic)
        bad_magic = bad_magic + 1;
        continue;
    end
    valid_length = double(read_be_u16(bytes(15:16)));
    object_length = double(read_be_u32(bytes(25:28)));
    source_port = bytes(7);
    if bytes(5) ~= uint8(1) || valid_length > numel(bytes) - 32 || ...
            object_length < 1 || object_length > cfg.maximumObjectBytes || ...
            source_port < 1 || source_port > 4
        bad_header = bad_header + 1;
        continue;
    end

    valid_count = valid_count + 1;
    axds.datasetType(valid_count) = bytes(6);
    axds.sourcePort(valid_count) = source_port;
    axds.aggregatePort(valid_count) = packets.portId(packet_index);
    axds.flags(valid_count) = bytes(8);
    axds.datasetCycle(valid_count) = read_be_u32(bytes(9:12));
    axds.objectId(valid_count) = read_be_u16(bytes(13:14));
    axds.validLength(valid_count) = uint16(valid_length);
    axds.packetSequence(valid_count) = read_be_u32(bytes(17:20));
    axds.objectOffset(valid_count) = read_be_u32(bytes(21:24));
    axds.objectLength(valid_count) = uint32(object_length);
    axds.objectCrc32(valid_count) = read_be_u32(bytes(29:32));
    axds.transportCrcOk(valid_count) = packets.allFramesCrcOk(packet_index);
    axds.payload{valid_count} = bytes(33:32 + valid_length);
end

fields = fieldnames(axds);
for field_index = 1:numel(fields)
    name = fields{field_index};
    axds.(name) = axds.(name)(1:valid_count, :);
end

stats.inputPacketCount = numel(packets.bytes);
stats.validPacketCount = valid_count;
stats.badMagicCount = bad_magic;
stats.badHeaderCount = bad_header;
stats.validByType = [sum(axds.datasetType == 1), sum(axds.datasetType == 2)];
end

function value = read_be_u16(bytes)
bytes = uint16(bytes(:));
value = bitshift(bytes(1), 8) + bytes(2);
end

function value = read_be_u32(bytes)
bytes = uint32(bytes(:));
value = bitshift(bytes(1), 24) + bitshift(bytes(2), 16) + ...
    bitshift(bytes(3), 8) + bytes(4);
end
