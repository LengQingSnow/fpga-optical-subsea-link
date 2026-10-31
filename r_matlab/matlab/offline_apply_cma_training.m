function [bytes, diagnostics, packing] = offline_apply_cma_training( ...
        capture, training, cfg)
%OFFLINE_APPLY_CMA_TRAINING Apply converged optical taps to another block.
bytes = uint8([]);
packing = struct();
waveform = double(capture.channels);
waveform = bsxfun(@minus, waveform, mean(waveform, 1));
input = [waveform(:, 1) + 1i * waveform(:, 2), ...
    waveform(:, 3) + 1i * waveform(:, 4)];
input = bsxfun(@rdivide, input, sqrt(mean(abs(input) .^ 2, 1) + eps));
sample_rate = double(capture.sampleRateHz);
sample_index = (0:size(input, 1) - 1).';
input = bsxfun(@times, input, exp(-1i * 2 * pi * ...
    double(training.coarseFrequencyOffsetHz) * sample_index / sample_rate));
decimation = round(training.decimation);
phase = round(training.sampleOffset);
fse = input(phase:decimation:end, :);
weights = training.weights;
taps = size(weights, 1) / 2;
count = floor((size(fse, 1) - taps) / 2) + 1;
equalized = zeros(count, 2);
row = 0;
for index = taps:2:size(fse, 1)
    vector = [flipud(fse(index - taps + 1:index, 1)); ...
        flipud(fse(index - taps + 1:index, 2))];
    row = row + 1;
    equalized(row, :) = (weights' * vector).';
end
symbols = block_phase_recovery(equalized, 8, 32);
if isfield(training, 'iqCorrection') && ...
        isequal(size(training.iqCorrection), [3 2])
    for polarization = 1:2
        value = symbols(:, polarization);
        symbols(:, polarization) = [value conj(value) ones(size(value))] * ...
            training.iqCorrection(:, polarization);
    end
end
symbols = bsxfun(@rdivide, symbols, ...
    sqrt(mean(abs(symbols) .^ 2, 1) + eps));
[bytes, packing, mapping] = pack_symbol_mappings(symbols, cfg);
diagnostics = training;
diagnostics.equalizedSymbols = symbols;
diagnostics.opticalMappingIndex = mapping;
end

function output = block_phase_recovery(input, block_symbols, candidates)
output = zeros(size(input));
phases = (0:candidates - 1) * (pi / 2) / candidates;
for polarization = 1:2
    previous_phase = 0;
    for first = 1:block_symbols:size(input, 1)
        last = min(size(input, 1), first + block_symbols - 1);
        block = input(first:last, polarization);
        costs = zeros(1, candidates);
        for candidate = 1:candidates
            rotated = block * exp(-1i * phases(candidate));
            decision = (sign(real(rotated)) + ...
                1i * sign(imag(rotated))) / sqrt(2);
            costs(candidate) = sum(abs(rotated - decision) .^ 2);
        end
        [~, selected] = min(costs);
        phase = phases(selected);
        phase = phase + round((previous_phase - phase) / (pi / 2)) * (pi / 2);
        output(first:last, polarization) = block * exp(-1i * phase);
        previous_phase = phase;
    end
end
end

function [bytes, packing, mapping] = pack_symbol_mappings(symbols, cfg)
bytes = uint8([]);
packing = struct();
mapping = 0;
best_crc = -1;
for swap = 0:1
    source = symbols;
    if swap
        source = source(:, [2 1]);
    end
    for first_iq = 0:1
        for second_iq = 0:1
            z1 = source(:, 1);
            z2 = source(:, 2);
            if first_iq
                z1 = 1i * conj(z1);
            end
            if second_iq
                z2 = 1i * conj(z2);
            end
            bits = [real(z1) >= 0, imag(z1) >= 0, ...
                real(z2) >= 0, imag(z2) >= 0];
            try
                [candidate, candidate_packing] = ...
                    optical_pack_dpqpsk_bytes(bits, cfg);
                [frames, ~] = parse_aggregate_frames_relocked(candidate, cfg);
                crc_count = sum(frames.crcOk);
                if crc_count > best_crc
                    best_crc = crc_count;
                    bytes = uint8(candidate(:));
                    packing = candidate_packing;
                    mapping = swap * 4 + first_iq * 2 + second_iq + 1;
                end
            catch
            end
        end
    end
end
end
