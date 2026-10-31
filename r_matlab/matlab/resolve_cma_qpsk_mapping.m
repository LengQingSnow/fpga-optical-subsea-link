function [aligned_symbols, mapped_bits, mapping, diagnostics] = ...
        resolve_cma_qpsk_mapping(symbols, reference, previous_mapping)
%RESOLVE_CMA_QPSK_MAPPING Apply only physical DP-QPSK blind ambiguities.
% The legal transformations are a polarization swap, per-polarization
% conjugation, and multiples of 90 degrees. All four lanes share one
% replay-period phase; arbitrary cross-polarization bit permutations are
% deliberately excluded.

if nargin < 3
    previous_mapping = [];
end
validateattributes(symbols, {'numeric'}, {'2d', 'nonempty'}, ...
    mfilename, 'symbols');
if size(symbols, 2) ~= 2
    error('resolve_cma_qpsk_mapping:Polarizations', ...
        'CMA output must contain two complex polarizations.');
end
if ~isstruct(reference) || ~isfield(reference, 'laneBits') || ...
        size(reference.laneBits, 2) ~= 4
    error('resolve_cma_qpsk_mapping:Reference', ...
        'A four-lane RF47 reference is required.');
end

symbols = double(symbols);
reference_bits = logical(reference.laneBits);
sample_count = size(symbols, 1);
period = size(reference_bits, 1);
if period < 2
    error('resolve_cma_qpsk_mapping:ReferencePeriod', ...
        'The replay reference period is too short.');
end

input_metrics(1) = cma_constellation_metrics(symbols(:, 1));
input_metrics(2) = cma_constellation_metrics(symbols(:, 2));
input_valid = [input_metrics.valid];

raw_bits = false(sample_count, 4);
raw_bits(:, 1) = real(symbols(:, 1)) >= 0;
raw_bits(:, 2) = imag(symbols(:, 1)) >= 0;
raw_bits(:, 3) = real(symbols(:, 2)) >= 0;
raw_bits(:, 4) = imag(symbols(:, 2)) >= 0;
correlations = lane_phase_correlations(raw_bits, reference_bits);

candidate_count = 2 * 8 * 8;
candidates = repmat(empty_mapping(), candidate_count, 1);
candidate_index = 0;
orders = [1 2; 2 1];
for order_index = 1:2
    for first_transform = 0:7
        for second_transform = 0:7
            candidate_index = candidate_index + 1;
            candidate = empty_mapping();
            candidate.polarizationOrder = orders(order_index, :);
            candidate.conjugated = [first_transform >= 4, ...
                second_transform >= 4];
            candidate.quarterTurns = [mod(first_transform, 4), ...
                mod(second_transform, 4)];
            [candidate.componentSource, candidate.componentInverted] = ...
                transformation_components(candidate);
            polarization_scores = zeros(1, 2);
            candidate.polarizationPhase = zeros(1, 2);
            for polarization = 1:2
                phase_scores = zeros(period, 1);
                lanes = 2 * polarization - 1 + (0:1);
                for lane = lanes
                    contribution = squeeze(correlations( ...
                        candidate.componentSource(lane), lane, :));
                    if candidate.componentInverted(lane)
                        contribution = -contribution;
                    end
                    phase_scores = phase_scores + contribution;
                end
                [polarization_scores(polarization), best_phase_index] = ...
                    max(phase_scores);
                candidate.polarizationPhase(polarization) = ...
                    best_phase_index - 1;
            end
            best_score = sum(polarization_scores);
            candidate.commonPhase = candidate.polarizationPhase;
            candidate.bitErrors = round((4 * sample_count - best_score) / 2);
            candidate.comparedBits = 4 * sample_count;
            candidate.ber = candidate.bitErrors / max(1, candidate.comparedBits);
            candidates(candidate_index) = candidate;
        end
    end
end

[~, best_index] = min([candidates.bitErrors]);
selected = candidates(best_index);
mapping_held = false;
if is_mapping(previous_mapping)
    previous_index = find_matching_candidate(candidates, previous_mapping);
    if all(input_valid) && ...
            candidates(previous_index).ber <= selected.ber + 1e-3
        selected = candidates(previous_index);
        mapping_held = true;
    end
end

[aligned_symbols, mapped_bits] = apply_mapping(symbols, selected);
aligned_metrics(1) = cma_constellation_metrics(aligned_symbols(:, 1));
aligned_metrics(2) = cma_constellation_metrics(aligned_symbols(:, 2));
selected.valid = all([aligned_metrics.valid]);

mapping = selected;
diagnostics = struct();
diagnostics.valid = selected.valid;
diagnostics.validByPolarization = [aligned_metrics.valid];
diagnostics.inputMetrics = input_metrics;
diagnostics.alignedMetrics = aligned_metrics;
diagnostics.mappingHeld = mapping_held;
diagnostics.bestLegalBer = candidates(best_index).ber;
diagnostics.selectedLegalBer = selected.ber;
diagnostics.reason = validity_reason(aligned_metrics);
end

function correlations = lane_phase_correlations(actual_bits, reference_bits)
sample_count = size(actual_bits, 1);
period = size(reference_bits, 1);
residue = mod((0:sample_count - 1)', period) + 1;
folded = zeros(period, 4);
for lane = 1:4
    folded(:, lane) = accumarray(residue, ...
        2 * double(actual_bits(:, lane)) - 1, [period 1]);
end
reference_sign = 2 * double(reference_bits) - 1;
correlations = zeros(4, 4, period);
positions = (0:period - 1)';
for actual_lane = 1:4
    for reference_lane = 1:4
        for phase = 0:period - 1
            expected = reference_sign(mod(positions + phase, period) + 1, ...
                reference_lane);
            correlations(actual_lane, reference_lane, phase + 1) = ...
                folded(:, actual_lane)' * expected;
        end
    end
end
end

function [source, inverted] = transformation_components(mapping)
source = zeros(1, 4);
inverted = false(1, 4);
for target_polarization = 1:2
    source_polarization = mapping.polarizationOrder(target_polarization);
    source_pair = 2 * source_polarization - 1 + (0:1);
    transform = mapping.quarterTurns(target_polarization) + ...
        4 * mapping.conjugated(target_polarization);
    [pair_source, pair_inverted] = component_rule(transform);
    target_pair = 2 * target_polarization - 1 + (0:1);
    source(target_pair) = source_pair(pair_source);
    inverted(target_pair) = pair_inverted;
end
end

function [source, inverted] = component_rule(transform)
bits = logical([0 0; 0 1; 1 0; 1 1]);
values = (2 * double(bits(:, 1)) - 1) + ...
    1i * (2 * double(bits(:, 2)) - 1);
conjugated = transform >= 4;
quarter_turn = mod(transform, 4);
if conjugated
    values = conj(values);
end
values = values .* exp(-1i * quarter_turn * pi / 2);
output_bits = [real(values) >= 0, imag(values) >= 0];
source = zeros(1, 2);
inverted = false(1, 2);
for output_component = 1:2
    for input_component = 1:2
        if isequal(output_bits(:, output_component), bits(:, input_component))
            source(output_component) = input_component;
            break;
        end
        if isequal(output_bits(:, output_component), ~bits(:, input_component))
            source(output_component) = input_component;
            inverted(output_component) = true;
            break;
        end
    end
end
if any(source == 0)
    error('resolve_cma_qpsk_mapping:Transform', ...
        'Unable to resolve a legal QPSK transformation.');
end
end

function [aligned, bits] = apply_mapping(symbols, mapping)
aligned = zeros(size(symbols));
for target_polarization = 1:2
    values = symbols(:, mapping.polarizationOrder(target_polarization));
    if mapping.conjugated(target_polarization)
        values = conj(values);
    end
    aligned(:, target_polarization) = values .* exp( ...
        -1i * mapping.quarterTurns(target_polarization) * pi / 2);
end
bits = false(size(symbols, 1), 4);
bits(:, 1) = real(aligned(:, 1)) >= 0;
bits(:, 2) = imag(aligned(:, 1)) >= 0;
bits(:, 3) = real(aligned(:, 2)) >= 0;
bits(:, 4) = imag(aligned(:, 2)) >= 0;
end

function index = find_matching_candidate(candidates, mapping)
matches = false(numel(candidates), 1);
for candidate_index = 1:numel(candidates)
    candidate = candidates(candidate_index);
    matches(candidate_index) = ...
        isequal(candidate.polarizationOrder, mapping.polarizationOrder) && ...
        isequal(candidate.conjugated, mapping.conjugated) && ...
        isequal(candidate.quarterTurns, mapping.quarterTurns);
end
index = find(matches, 1, 'first');
if isempty(index)
    index = 1;
end
end

function valid = is_mapping(mapping)
valid = isstruct(mapping) && isfield(mapping, 'polarizationOrder') && ...
    isfield(mapping, 'conjugated') && isfield(mapping, 'quarterTurns') && ...
    numel(mapping.polarizationOrder) == 2 && ...
    numel(mapping.conjugated) == 2 && numel(mapping.quarterTurns) == 2;
end

function mapping = empty_mapping()
mapping = struct('polarizationOrder', [1 2], ...
    'conjugated', false(1, 2), 'quarterTurns', zeros(1, 2), ...
    'componentSource', 1:4, 'componentInverted', false(1, 4), ...
    'polarizationPhase', zeros(1, 2), 'commonPhase', zeros(1, 2), ...
    'bitErrors', inf, 'comparedBits', 0, ...
    'ber', inf, 'valid', false);
end

function reason = validity_reason(metrics)
invalid = find(~[metrics.valid]);
if isempty(invalid)
    reason = 'valid four-quadrant DP-QPSK';
    return;
end
parts = cell(1, numel(invalid));
for index = 1:numel(invalid)
    polarization = invalid(index);
    item = metrics(polarization);
    parts{index} = sprintf( ...
        'P%d collapsed: minQ=%.3f axis=%.3f circ=%.3f', ...
        polarization, item.minimumQuadrantFraction, ...
        item.axisPowerRatio, item.circularity);
end
reason = parts{1};
for index = 2:numel(parts)
    reason = [reason ' | ' parts{index}]; %#ok<AGROW>
end
end
