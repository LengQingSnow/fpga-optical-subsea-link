function value = crc32_msb(bytes)
%CRC32_MSB CRC-32/MPEG-style byte update used by the KU115 aggregate frame.

persistent lookup_table;
if isempty(lookup_table)
    polynomial = uint32(hex2dec('04C11DB7'));
    lookup_table = zeros(256, 1, 'uint32');
    for table_index = 0:255
        crc = bitshift(uint32(table_index), 24);
        for bit_index = 1:8
            if bitget(crc, 32)
                crc = bitxor(bitshift(crc, 1), polynomial);
            else
                crc = bitshift(crc, 1);
            end
        end
        lookup_table(table_index + 1) = crc;
    end
end

crc = uint32(hex2dec('FFFFFFFF'));
bytes = uint8(bytes(:));
for byte_index = 1:numel(bytes)
    table_index = bitxor(bitshift(crc, -24), uint32(bytes(byte_index)));
    crc = bitxor(bitshift(crc, 8), lookup_table(double(table_index) + 1));
end
value = bitcmp(crc);
end
