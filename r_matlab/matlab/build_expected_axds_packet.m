function packet = build_expected_axds_packet(catalog_entry, packet_sequence)
%BUILD_EXPECTED_AXDS_PACKET Recreate one deterministic ax7101 UDP payload.

sequence_double = double(uint32(packet_sequence));
position = mod(sequence_double, catalog_entry.packetsPerCycle);
dataset_cycle = floor(sequence_double / catalog_entry.packetsPerCycle);

object_index = 1;
while position >= catalog_entry.packetsPerObject(object_index)
    position = position - catalog_entry.packetsPerObject(object_index);
    object_index = object_index + 1;
end

object_bytes = uint8(catalog_entry.objectBytes{object_index}(:));
object_length = double(catalog_entry.objectLengths(object_index));
object_offset = position * catalog_entry.maximumDataBytes;
valid_length = min(catalog_entry.maximumDataBytes, ...
    object_length - object_offset);
flags = uint8(0);
if object_offset == 0
    flags = bitset(flags, 1);
end
if object_offset + valid_length == object_length
    flags = bitset(flags, 2);
end

packet = zeros(32 + valid_length, 1, 'uint8');
packet(1:4) = uint8([hex2dec('41'); hex2dec('58'); ...
    hex2dec('44'); hex2dec('53')]);
packet(5) = uint8(1);
packet(6) = catalog_entry.datasetType;
packet(7) = catalog_entry.portId;
packet(8) = flags;
packet(9:12) = write_be_u32(dataset_cycle);
packet(13:14) = write_be_u16(object_index);
packet(15:16) = write_be_u16(valid_length);
packet(17:20) = write_be_u32(packet_sequence);
packet(21:24) = write_be_u32(object_offset);
packet(25:28) = write_be_u32(object_length);
packet(29:32) = write_be_u32(catalog_entry.objectCrc32(object_index));
packet(33:end) = object_bytes(object_offset + 1: ...
    object_offset + valid_length);
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
