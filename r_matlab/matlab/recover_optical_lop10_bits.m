function [lane_bits, bytes, recovery, packing] = ...
        recover_optical_lop10_bits(capture, cfg)
%RECOVER_OPTICAL_LOP10_BITS Page-6 10 dB DSP and good-frame recovery.
% The input is already passed through the 10 dB front end.  A fixed CMA
% configuration is used for the payload stream; mapping candidates are
% accepted only when they produce at least one CRC-correct aggregate frame.

lane_bits = false(0, 4);
bytes = uint8([]);
recovery = struct();
packing = struct();

if nargin < 2 || isempty(cfg)
    error('recover_optical_lop10_bits:Config', 'RF47 configuration is required.');
end

options = struct('symbolRateHz', cfg.symbolRateHz, 'taps', 41, ...
    'stepSize', 2.5e-2, 'refineStepSize', 3.125e-3, ...
    'phaseScanSymbols', 8000, 'phaseBlockSymbols', 8, ...
    'phaseCandidateCount', 32, 'decorrelateOutputs', true);
cma = cma_mimo_equalize(capture, options);
symbols = cma.equalizedSymbols;
if isempty(symbols) || size(symbols, 2) ~= 2
    error('recover_optical_lop10_bits:CmaOutput', ...
        'The 10 dB CMA did not return two polarization streams.');
end

best_score = -inf;
best_crc = 0;
best_bits = false(0, 4);
best_bytes = uint8([]);
best_packing = struct();
best_mapping = 0;
last_error = '';
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
            candidate_bits = [real(z1) >= 0, imag(z1) >= 0, ...
                real(z2) >= 0, imag(z2) >= 0];
            try
                [candidate_bytes, candidate_packing] = ...
                    optical_pack_dpqpsk_bytes(candidate_bits, cfg);
                [candidate_frames, ~] = parse_aggregate_frames_relocked( ...
                    uint8(candidate_bytes(:)), cfg);
                crc_count = sum(candidate_frames.crcOk & ...
                    candidate_frames.headerOk & ...
                    candidate_frames.segmentParseOk);
                score = 100 * crc_count + ...
                    sum(candidate_frames.headerOk) + ...
                    sum(candidate_frames.segmentParseOk);
                if score > best_score
                    best_score = score;
                    best_crc = crc_count;
                    best_bits = candidate_bits;
                    best_bytes = uint8(candidate_bytes(:));
                    best_packing = candidate_packing;
                    best_mapping = swap * 4 + first_iq * 2 + ...
                        second_iq + 1;
                end
            catch exception
                last_error = exception.message;
            end
        end
    end
end

if best_crc < 1
    if isempty(last_error)
        last_error = 'No CRC-correct aggregate frame found.';
    end
    error('recover_optical_lop10_bits:GoodFrame', ...
        '10 dB DSP did not find a CRC-correct frame (%s).', last_error);
end

lane_bits = best_bits;
bytes = best_bytes;
packing = best_packing;
recovery = cma;
recovery.opticalMappingIndex = best_mapping;
recovery.lop10ParseScore = best_score;
recovery.lop10CrcGoodFrames = best_crc;
recovery.lop10GoodFrameOnly = true;
end
