function selftest_realtime_dac_ber()
%SELFTEST_REALTIME_DAC_BER Verify periodic alignment, polarity, and counting.

rng(47);
reference = struct();
reference.laneBits = logical(randi([0 1], 1024, 4));
sample_count = 20000;
phase = [7 211 511 900];
inverted = [false true false true];
actual = false(sample_count, 4);
for lane = 1:4
    actual(:, lane) = reference.laneBits( ...
        mod((0:sample_count - 1)' + phase(lane), 1024) + 1, lane);
    if inverted(lane)
        actual(:, lane) = ~actual(:, lane);
    end
end
error_indices = {11, [21 1201], [31 3001 9001], [41 4001 8001 12001]};
for lane = 1:4
    actual(error_indices{lane}, lane) = ~actual(error_indices{lane}, lane);
end

[state, result] = accumulate_realtime_dac_ber([], actual, reference);
assert(result.totalErrors == 10);
assert(result.totalBits == 4 * sample_count);
assert(all(result.phase == phase));
assert(all(result.inverted == inverted));
assert(sum(result.lastXor(:)) == 10);
[~, result] = accumulate_realtime_dac_ber(state, actual, reference);
assert(result.totalErrors == 20);
assert(result.totalBits == 8 * sample_count);
fprintf('PASS: physical BER alignment, XOR, polarity, and accumulation\n');
end
