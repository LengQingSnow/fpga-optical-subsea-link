function [rx_bytes, diagnostics] = pack_dpqpsk_bytes(lane_bits, cfg)
%PACK_DPQPSK_BYTES Resolve lane polarity and nibble phase, then pack bytes.

validateattributes(lane_bits, {'logical', 'numeric'}, ...
    {'2d', 'nonempty'}, mfilename, 'lane_bits', 1);
if size(lane_bits, 2) ~= 4
    error('pack_dpqpsk_bytes:LaneCount', 'Expected four bit lanes.');
end
lane_bits = logical(lane_bits);

[lane_offsets, pre_polarity_mask, lane_sync_error_rates] = ...
    resolve_lane_alignment(lane_bits, cfg);
aligned_count = min(size(lane_bits, 1) - lane_offsets);
aligned_bits = false(aligned_count, 4);
for lane = 1:4
    start_index = lane_offsets(lane) + 1;
    aligned_bits(:, lane) = lane_bits(start_index: ...
        start_index + aligned_count - 1, lane);
end
aligned_bits = apply_polarity(aligned_bits, pre_polarity_mask);

scan_count = min(size(aligned_bits, 1), cfg.packingScanSymbols);
scan_bits = aligned_bits(1:scan_count, :);
best_hits = -1;
best_mask = 0;
best_offset = 0;

for polarity_mask = 0:15
    trial = apply_polarity(scan_bits, polarity_mask);
    nibbles = bits_to_nibbles(trial);
    for offset = 0:1
        bytes = nibbles_to_bytes(nibbles, offset);
        hit_count = numel(strfind(double(bytes(:).'), ...
            double(cfg.syncWord(:).')));
        if hit_count > best_hits
            best_hits = hit_count;
            best_mask = polarity_mask;
            best_offset = offset;
        end
    end
end

if best_hits <= 0
    error('pack_dpqpsk_bytes:NoSync', ...
        ['No exact aggregate sync word was found. Check channel order, ' ...
         'scope sample rate, clipping and timing recovery.']);
end

resolved_bits = apply_polarity(aligned_bits, best_mask);
rx_bytes = nibbles_to_bytes(bits_to_nibbles(resolved_bits), best_offset);
rx_bytes = rx_bytes(:);

total_mask = double(bitxor(uint8(pre_polarity_mask), uint8(best_mask)));
diagnostics.polarityMask = total_mask;
diagnostics.prePolarityMask = pre_polarity_mask;
diagnostics.nibbleOffset = best_offset;
diagnostics.scanSyncHits = best_hits;
diagnostics.laneSymbolOffsets = lane_offsets;
diagnostics.laneSyncErrorRates = lane_sync_error_rates;
diagnostics.lanePolarity = ones(1, 4);
for lane = 1:4
    if bitget(total_mask, lane)
        diagnostics.lanePolarity(lane) = -1;
    end
end
diagnostics.byteCount = numel(rx_bytes);
end

function [lane_offsets, polarity_mask, error_rates] = ...
    resolve_lane_alignment(lane_bits, cfg)
scan_count = min(size(lane_bits, 1), cfg.packingScanSymbols);
scan_bits = lane_bits(1:scan_count, :);
sync_word = uint8(cfg.syncWord(:));
sync_nibbles = zeros(2 * numel(sync_word), 1, 'uint8');
sync_nibbles(1:2:end) = bitshift(sync_word, -4);
sync_nibbles(2:2:end) = bitand(sync_word, uint8(15));
window_length = numel(sync_nibbles);
frame_symbols = 2 * cfg.frameBytes;
position_count = scan_count - window_length + 1;
residues = mod((0:position_count - 1)', frame_symbols) + 1;
position_counts = accumarray(residues, 1, [frame_symbols, 1]);

lane_offsets = zeros(1, 4);
error_rates = inf(1, 4);
polarity_mask = 0;
for lane = 1:4
    actual = double(scan_bits(:, lane));
    expected = double(bitget(sync_nibbles, 5 - lane));
    window_ones = conv(actual, ones(window_length, 1), 'valid');
    correlation = conv(actual, flipud(expected), 'valid');
    mismatch = window_ones + sum(expected) - 2 * correlation;
    direct_errors = accumarray(residues, mismatch, [frame_symbols, 1]);
    inverted_errors = position_counts * window_length - direct_errors;
    minimum_errors = min(direct_errors, inverted_errors);
    rates = minimum_errors ./ (position_counts * window_length);
    [error_rates(lane), residue_index] = min(rates);
    lane_offsets(lane) = residue_index - 1;
    if inverted_errors(residue_index) < direct_errors(residue_index)
        polarity_mask = bitset(polarity_mask, lane);
    end
end

if any(error_rates > cfg.maxLaneSyncErrorRate)
    error('pack_dpqpsk_bytes:LaneSync', ...
        ['At least one lane has no reliable 512-byte frame-period sync. ' ...
         'Check timing recovery, channel order and capture quality.']);
end
end

function bits = apply_polarity(bits, polarity_mask)
for lane = 1:4
    if bitget(polarity_mask, lane)
        bits(:, lane) = ~bits(:, lane);
    end
end
end

function nibbles = bits_to_nibbles(bits)
nibbles = uint8(bits(:, 1)) * 8 + uint8(bits(:, 2)) * 4 + ...
    uint8(bits(:, 3)) * 2 + uint8(bits(:, 4));
end

function bytes = nibbles_to_bytes(nibbles, offset)
usable = floor((numel(nibbles) - offset) / 2) * 2;
if usable <= 0
    bytes = zeros(0, 1, 'uint8');
    return;
end
selected = nibbles(offset + 1:offset + usable);
bytes = bitshift(selected(1:2:end), 4) + selected(2:2:end);
end
