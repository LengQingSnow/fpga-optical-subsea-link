function bytes = aggregate_prbs31_bytes(frame_sequence, byte_count)
%AGGREGATE_PRBS31_BYTES Recreate KU115 frame filler bytes.

state = bitxor(uint32(hex2dec('7FFFFFFF')), ...
    bitand(uint32(frame_sequence), uint32(hex2dec('7FFFFFFF'))));
state = bitor(state, uint32(1));
bytes = zeros(byte_count, 1, 'uint8');
for byte_index = 1:byte_count
    value = uint8(0);
    for bit_index = 1:8
        value = bitset(value, 9 - bit_index, bitget(state, 31));
        feedback = xor(bitget(state, 31), bitget(state, 28));
        state = bitand(bitshift(state, 1), uint32(hex2dec('7FFFFFFF')));
        if feedback
            state = bitor(state, uint32(1));
        end
    end
    bytes(byte_index) = value;
end
end
