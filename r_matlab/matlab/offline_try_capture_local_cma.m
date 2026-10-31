function [bytes, cma, packing] = offline_try_capture_local_cma( ...
        capture, cfg, fixed)
%OFFLINE_TRY_CAPTURE_LOCAL_CMA Recover one independent optical block.
bytes = uint8([]);
packing = struct();
if nargin < 3
    fixed = false;
end
best_score = -inf;
best_cma = struct();
if fixed
    tap_candidates = 41;
    step_candidates = 2.5e-2;
else
    tap_candidates = [21 31 41];
    step_candidates = [2.5e-2 5e-2];
end
for tap_index = 1:numel(tap_candidates)
    for step_index = 1:numel(step_candidates)
        options = struct('symbolRateHz', cfg.symbolRateHz, ...
            'taps', tap_candidates(tap_index), ...
            'stepSize', step_candidates(step_index), ...
            'refineStepSize', step_candidates(step_index) / 8, ...
            'phaseScanSymbols', 8000, 'phaseBlockSymbols', 8, ...
            'phaseCandidateCount', 32);
        try
            candidate_cma = cma_mimo_equalize(capture, options);
            symbols = candidate_cma.equalizedSymbols;
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
                            [trial_frames, ~] = ...
                                parse_aggregate_frames_relocked( ...
                                uint8(candidate(:)), cfg);
                            score = sum(trial_frames.headerOk) + ...
                                sum(trial_frames.segmentParseOk) + ...
                                100 * sum(trial_frames.crcOk);
                            if score > best_score
                                best_score = score;
                                bytes = uint8(candidate(:));
                                packing = candidate_packing;
                                best_cma = candidate_cma;
                                best_cma.opticalMappingIndex = swap * 4 + ...
                                    first_iq * 2 + second_iq + 1;
                            end
                        catch
                        end
                    end
                end
            end
        catch exception
            fprintf('CMA candidate failed: %s\n', exception.message);
        end
    end
end
if isinf(best_score)
    cma = struct('error', 'No CMA candidate reached aggregate sync.');
else
    cma = best_cma;
    fprintf('Best capture-local CMA parse score: %.0f\n', best_score);
end
end
