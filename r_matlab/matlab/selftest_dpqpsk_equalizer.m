function selftest_dpqpsk_equalizer()
%SELFTEST_DPQPSK_EQUALIZER Verify supervised MMSE recovery on synthetic ISI.

cfg.syncWord = uint8([hex2dec('D5'), hex2dec('C0'), hex2dec('1A'), ...
    hex2dec('CF'), hex2dec('FC'), hex2dec('1D'), hex2dec('5A'), ...
    hex2dec('A5')]);
cfg.postEqualizerMinimumSyncFrames = 8;
cfg.postEqualizerMaximumSyncFrames = 64;
cfg.postEqualizerMinimumTrainingSymbols = 64;
cfg.postEqualizerMinimumValidationSymbols = 64;
cfg.postEqualizerTapCandidates = [1 3 5 7 9];
cfg.postEqualizerLambdaCandidates = [1e-4 1e-3 1e-2];

frame_count = 32;
frame_bytes = repmat(uint8(0), 512, frame_count);
for frame = 1:frame_count
    frame_bytes(:, frame) = uint8(mod((0:511)' * 37 + frame * 11, 256));
    frame_bytes(1:8, frame) = cfg.syncWord(:);
end
rx_bytes = frame_bytes(:);
nibbles = zeros(2 * numel(rx_bytes), 1, 'uint8');
nibbles(1:2:end) = bitshift(rx_bytes, -4);
nibbles(2:2:end) = bitand(rx_bytes, uint8(15));
clean = false(numel(nibbles), 4);
for lane = 1:4
    clean(:, lane) = bitget(nibbles, 5 - lane) ~= 0;
end
clean = 2 * double(clean) - 1;

% A deliberately asymmetric three-symbol channel creates precursor and
% postcursor ISI while preserving the known sync-word training targets.
channel = [0.24 1.00 0.32];
soft = zeros(size(clean));
rng(47);
for lane = 1:4
    soft(:, lane) = conv(clean(:, lane), channel, 'same') + ...
        0.02 * randn(size(clean, 1), 1);
end

packing.nibbleOffset = 0;
packing.laneSymbolOffsets = [0 0 0 0];
packing.lanePolarity = [1 1 1 1];
[lane_bits, diagnostics] = equalize_dpqpsk_symbols( ...
    single(soft), rx_bytes, packing, cfg);
expected = logical(clean >= 0);
comparison = lane_bits(8 * 2 + 1:end - 8 * 2, :) ~= ...
    expected(8 * 2 + 1:end - 8 * 2, :);
error_rate = mean(comparison(:));
assert(error_rate < 1e-3);
assert(all(diagnostics.validationMseImprovement > 0.05));
fprintf('selftest_dpqpsk_equalizer: PASS (BER %.3e, taps %d/%d/%d/%d)\n', ...
    error_rate, diagnostics.selectedTapLength);
end
