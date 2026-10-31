function [state, result] = accumulate_cma_mapped_ber( ...
        state, mapped_lane_bits, reference, mapping)
%ACCUMULATE_CMA_MAPPED_BER Accumulate BER with one DP-QPSK period phase.
% Mapping has already resolved polarization order, QPSK rotation, and
% conjugation. The four bit lanes must therefore use one common period
% phase and no independent inversion.

validateattributes(mapped_lane_bits, {'logical', 'numeric'}, ...
    {'2d', 'nonempty'}, mfilename, 'mapped_lane_bits');
if size(mapped_lane_bits, 2) ~= 4
    error('accumulate_cma_mapped_ber:ChannelCount', ...
        'Mapped CMA bits must contain four columns.');
end
if ~isstruct(reference) || ~isfield(reference, 'laneBits') || ...
        size(reference.laneBits, 2) ~= 4
    error('accumulate_cma_mapped_ber:Reference', ...
        'A four-lane RF47 reference is required.');
end
if ~isstruct(mapping) || ~isfield(mapping, 'commonPhase') || ...
        numel(mapping.commonPhase) ~= 2 || ...
        any(~isfinite(mapping.commonPhase))
    error('accumulate_cma_mapped_ber:Mapping', ...
        'A CMA mapping with one replay phase per polarization is required.');
end
if nargin < 1 || isempty(state)
    state = initial_state();
end

actual = logical(mapped_lane_bits);
reference_bits = logical(reference.laneBits);
period = size(reference_bits, 1);
sample_count = size(actual, 1);
polarization_phase = mod(round(double(mapping.commonPhase(:).')), period);
expected = false(sample_count, 4);
for polarization = 1:2
    lanes = 2 * polarization - 1 + (0:1);
    expected_indices = mod((0:sample_count - 1)' + ...
        polarization_phase(polarization), period) + 1;
    expected(:, lanes) = reference_bits(expected_indices, lanes);
end
last_xor = xor(actual, expected);
last_errors = sum(last_xor, 1);
last_bits = sample_count * ones(1, 4);

state.captureCount = state.captureCount + 1;
state.totalErrorsByLane = state.totalErrorsByLane + last_errors;
state.totalBitsByLane = state.totalBitsByLane + last_bits;
state.lastErrorsByLane = last_errors;
state.lastBitsByLane = last_bits;
state.lastPhase = [polarization_phase(1) polarization_phase(1) ...
    polarization_phase(2) polarization_phase(2)];
state.lastInverted = false(1, 4);
state.lastXor = last_xor;
state.lastUpdate = now;

result = result_from_state(state);
end

function state = initial_state()
state = struct();
state.captureCount = 0;
state.totalErrorsByLane = zeros(1, 4);
state.totalBitsByLane = zeros(1, 4);
state.lastErrorsByLane = zeros(1, 4);
state.lastBitsByLane = zeros(1, 4);
state.lastPhase = zeros(1, 4);
state.lastInverted = false(1, 4);
state.lastXor = false(0, 4);
state.lastUpdate = NaN;
end

function result = result_from_state(state)
result = struct();
result.captureCount = state.captureCount;
result.lastErrorsByLane = state.lastErrorsByLane;
result.lastBitsByLane = state.lastBitsByLane;
result.totalErrorsByLane = state.totalErrorsByLane;
result.totalBitsByLane = state.totalBitsByLane;
result.lastBerByLane = state.lastErrorsByLane ./ max(1, state.lastBitsByLane);
result.totalBerByLane = state.totalErrorsByLane ./ max(1, state.totalBitsByLane);
result.lastErrors = sum(state.lastErrorsByLane);
result.lastBits = sum(state.lastBitsByLane);
result.totalErrors = sum(state.totalErrorsByLane);
result.totalBits = sum(state.totalBitsByLane);
result.lastBer = result.lastErrors / max(1, result.lastBits);
result.totalBer = result.totalErrors / max(1, result.totalBits);
result.resolution = 1 / max(1, result.totalBits);
result.targetReached = result.totalBits >= 1e6;
result.zeroErrorUpper95 = -log(0.05) / max(1, result.totalBits);
result.phase = state.lastPhase;
result.inverted = state.lastInverted;
result.lastXor = state.lastXor;
result.lastUpdate = state.lastUpdate;
end
