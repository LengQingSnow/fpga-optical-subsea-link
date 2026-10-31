function [rx_bytes, diagnostics] = optical_pack_dpqpsk_bytes(lane_bits, cfg)
%OPTICAL_PACK_DPQPSK_BYTES Tolerant packet packing for optical CMA output.
% This page-4-only path scores the aggregate sync by Hamming distance.  It
% does not change the strict electrical/replay packer used by pages 1-3.

validateattributes(lane_bits, {'logical', 'numeric'}, ...
    {'2d', 'nonempty'}, mfilename, 'lane_bits', 1);
if size(lane_bits, 2) ~= 4
    error('optical_pack_dpqpsk_bytes:LaneCount', ...
        'Expected four bit lanes.');
end
lane_bits = logical(lane_bits);

[lane_offsets, pre_mask, lane_error_rates] = ...
    resolve_optical_lane_alignment(lane_bits, cfg);
aligned_count = min(size(lane_bits, 1) - lane_offsets);
aligned = false(aligned_count, 4);
for lane = 1:4
    first = lane_offsets(lane) + 1;
    aligned(:, lane) = lane_bits(first:first + aligned_count - 1, lane);
end
aligned = apply_mask(aligned, pre_mask);

[crc_bytes, crc_diagnostics] = pack_crc_resolved_frames(aligned, cfg);
if ~isempty(crc_bytes)
    rx_bytes = crc_bytes;
    diagnostics = crc_diagnostics;
    diagnostics.prePolarityMask = pre_mask;
    diagnostics.polarityMask = pre_mask;
    diagnostics.laneSymbolOffsets = lane_offsets;
    diagnostics.laneSyncErrorRates = lane_error_rates;
    diagnostics.byteCount = numel(rx_bytes);
    return;
end

scan_count = min(size(aligned, 1), cfg.packingScanSymbols);
best = struct('distance', inf, 'hits', 0, 'mask', 0, 'offset', 0);
for mask = 0:15
    trial = apply_mask(aligned(1:scan_count, :), mask);
    nibbles = bits_to_nibbles(trial);
    for offset = 0:1
        bytes = nibbles_to_bytes(nibbles, offset);
        [distance, hits] = minimum_sync_distance(bytes, cfg.syncWord, ...
            cfg.maxSyncBitErrors);
        if distance < best.distance || ...
                (distance == best.distance && hits > best.hits)
            best.distance = distance;
            best.hits = hits;
            best.mask = mask;
            best.offset = offset;
        end
    end
end

if best.distance > cfg.maxSyncBitErrors
    error('optical_pack_dpqpsk_bytes:NoSync', ...
        ['Optical aggregate sync not found: minimum sync distance=%d ' ...
         'bits, permitted=%d; lane periodic errors=[%s].'], ...
        best.distance, cfg.maxSyncBitErrors, sprintf('%.3f ', lane_error_rates));
end

resolved = apply_mask(aligned, best.mask);
rx_bytes = nibbles_to_bytes(bits_to_nibbles(resolved), best.offset);
rx_bytes = rx_bytes(:);
[~, ~, sync_positions] = minimum_sync_distance(rx_bytes, ...
    cfg.syncWord, cfg.maxSyncBitErrors);
corrected_sync_count = 0;
for index = 1:numel(sync_positions)
    first = sync_positions(index);
    last = first + numel(cfg.syncWord) - 1;
    if last <= numel(rx_bytes)
        rx_bytes(first:last) = cfg.syncWord(:);
        corrected_sync_count = corrected_sync_count + 1;
    end
end
diagnostics.polarityMask = double(bitxor(uint8(pre_mask), uint8(best.mask)));
diagnostics.prePolarityMask = pre_mask;
diagnostics.nibbleOffset = best.offset;
diagnostics.scanSyncHits = best.hits;
diagnostics.minimumSyncBitErrors = best.distance;
diagnostics.correctedSyncCount = corrected_sync_count;
diagnostics.laneSymbolOffsets = lane_offsets;
diagnostics.laneSyncErrorRates = lane_error_rates;
diagnostics.byteCount = numel(rx_bytes);
end

function [bytes, diagnostics] = pack_crc_resolved_frames(bits, cfg)
% Resolve the blind-QPSK quadrant independently for every aggregate frame.
% CMA/BPS may slip by pi/2 between blocks while the constellation remains
% visually correct.  Aggregate CRC provides an unambiguous page-4-only
% decision without using payload content as a training sequence.
frame_symbols = 2 * double(cfg.frameBytes);
frame_count = floor((size(bits, 1) - 1) / frame_symbols);
accepted = zeros(double(cfg.frameBytes), frame_count, 'uint8');
accepted_count = 0;
tested_count = 0;
for frame_index = 1:frame_count
    nominal = 1 + (frame_index - 1) * frame_symbols;
    found = false;
    for nibble_offset = 0:1
        first = nominal + nibble_offset;
        last = first + frame_symbols - 1;
        if last > size(bits, 1)
            continue;
        end
        block = bits(first:last, :);
        for polarization_swap = 0:1
            if polarization_swap
                ordered = block(:, [3 4 1 2]);
            else
                ordered = block;
            end
            for swap_x = 0:1
                for swap_y = 0:1
                    mapped = ordered;
                    if swap_x
                        mapped(:, [1 2]) = mapped(:, [2 1]);
                    end
                    if swap_y
                        mapped(:, [3 4]) = mapped(:, [4 3]);
                    end
                    for mask = 0:15
                        tested_count = tested_count + 1;
                        trial = apply_mask(mapped, mask);
                        frame = nibbles_to_bytes(bits_to_nibbles(trial), 0);
                        if numel(frame) ~= double(cfg.frameBytes) || ...
                                frame(9) ~= cfg.protocolVersion || ...
                                ~(frame(10) == uint8(6) || frame(10) == uint8(7))
                            continue;
                        end
                        sync_errors = bit_error_count(frame(1:8), cfg.syncWord);
                        segment_bytes = double(frame(11)) * 256 + double(frame(12));
                        if sync_errors > cfg.maxSyncBitErrors || segment_bytes > 492
                            continue;
                        end
                        received_crc = read_be_u32(frame(cfg.framePayloadEnd + 1:end));
                        if crc32_msb(frame(1:cfg.framePayloadEnd)) ~= received_crc
                            continue;
                        end
                        frame(1:8) = cfg.syncWord(:);
                        accepted_count = accepted_count + 1;
                        accepted(:, accepted_count) = frame(:);
                        found = true;
                        break;
                    end
                    if found, break; end
                end
                if found, break; end
            end
            if found, break; end
        end
        if found, break; end
    end
end
accepted = accepted(:, 1:accepted_count);
bytes = accepted(:);
diagnostics = struct('framewiseCrcResolved', true, ...
    'crcResolvedFrames', accepted_count, ...
    'candidateFrames', frame_count, ...
    'mappingCandidatesTested', tested_count, ...
    'nibbleOffset', 0, 'scanSyncHits', accepted_count, ...
    'minimumSyncBitErrors', 0, 'correctedSyncCount', accepted_count);
end

function count = bit_error_count(actual, expected)
difference = bitxor(uint8(actual(:)), uint8(expected(:)));
count = 0;
for bit = 1:8
    count = count + sum(bitget(difference, bit));
end
end

function value = read_be_u32(bytes)
bytes = uint32(bytes(:));
value = bitor(bitshift(bytes(1), 24), bitor(bitshift(bytes(2), 16), ...
    bitor(bitshift(bytes(3), 8), bytes(4))));
end

function [offsets, polarity_mask, error_rates] = ...
        resolve_optical_lane_alignment(bits, cfg)
scan_count = min(size(bits, 1), cfg.packingScanSymbols);
scan_bits = bits(1:scan_count, :);
sync_word = uint8(cfg.syncWord(:));
sync_nibbles = zeros(2 * numel(sync_word), 1, 'uint8');
sync_nibbles(1:2:end) = bitshift(sync_word, -4);
sync_nibbles(2:2:end) = bitand(sync_word, uint8(15));
window_length = numel(sync_nibbles);
frame_symbols = 2 * cfg.frameBytes;
position_count = scan_count - window_length + 1;
if position_count < frame_symbols
    error('optical_pack_dpqpsk_bytes:ShortCapture', ...
        'Too few CMA symbols for periodic lane alignment.');
end
residues = mod((0:position_count - 1)', frame_symbols) + 1;
position_counts = accumarray(residues, 1, [frame_symbols, 1]);
offsets = zeros(1, 4);
error_rates = inf(1, 4);
polarity_mask = 0;
for lane = 1:4
    actual = double(scan_bits(:, lane));
    expected = double(bitget(sync_nibbles, 5 - lane));
    window_ones = conv(actual, ones(window_length, 1), 'valid');
    correlation = conv(actual, flipud(expected), 'valid');
    mismatch = window_ones + sum(expected) - 2 * correlation;
    direct = accumarray(residues, mismatch, [frame_symbols, 1]);
    inverted = position_counts * window_length - direct;
    minimum = min(direct, inverted);
    rates = minimum ./ (position_counts * window_length);
    [error_rates(lane), residue] = min(rates);
    offsets(lane) = residue - 1;
    if inverted(residue) < direct(residue)
        polarity_mask = bitset(polarity_mask, lane);
    end
end
end

function [minimum_distance, hit_count, hit_positions] = ...
        minimum_sync_distance(bytes, sync_word, maximum_errors)
bytes = uint8(bytes(:));
sync_word = uint8(sync_word(:));
window_count = numel(bytes) - numel(sync_word) + 1;
minimum_distance = inf;
hit_count = 0;
hit_positions = zeros(0, 1);
if window_count < 1
    return;
end
total_errors = zeros(window_count, 1);
for byte_index = 1:numel(sync_word)
    differences = bitxor(bytes(byte_index:byte_index + window_count - 1), ...
        sync_word(byte_index));
    for bit = 1:8
        total_errors = total_errors + double(bitget(differences, bit));
    end
end
minimum_distance = min(total_errors);
hit_positions = find(total_errors <= maximum_errors);
hit_count = numel(hit_positions);
end

function bits = apply_mask(bits, mask)
for lane = 1:4
    if bitget(mask, lane)
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
