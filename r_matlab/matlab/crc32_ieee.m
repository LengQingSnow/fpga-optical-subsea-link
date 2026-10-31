function value = crc32_ieee(bytes)
%CRC32_IEEE Standard reflected CRC-32 used in the AXDS object metadata.

persistent lookup_table;
if isempty(lookup_table)
    polynomial = uint32(hex2dec('EDB88320'));
    lookup_table = zeros(256, 1, 'uint32');
    for table_index = 0:255
        crc = uint32(table_index);
        for bit_index = 1:8
            if bitget(crc, 1)
                crc = bitxor(bitshift(crc, -1), polynomial);
            else
                crc = bitshift(crc, -1);
            end
        end
        lookup_table(table_index + 1) = crc;
    end
end

crc = uint32(hex2dec('FFFFFFFF'));
bytes = uint8(bytes(:));
for byte_index = 1:numel(bytes)
    table_index = bitxor(bitand(crc, uint32(255)), ...
        uint32(bytes(byte_index)));
    crc = bitxor(bitshift(crc, -8), ...
        lookup_table(double(table_index) + 1));
end
value = bitcmp(crc);
end
