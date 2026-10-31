function [state, result] = accumulate_realtime_dac_ber( ...
    state, recovered_lane_bits, reference)
%ACCUMULATE_REALTIME_DAC_BER Align, XOR, and accumulate physical-layer BER.

validateattributes(recovered_lane_bits, {'logical', 'numeric'}, ...
    {'2d', 'nonempty'}, mfilename, 'recovered_lane_bits');
if size(recovered_lane_bits, 2) ~= 4
    error('accumulate_realtime_dac_ber:ChannelCount', ...
        'Recovered bits must contain four columns.');
end
if ~isstruct(reference) || ~isfield(reference, 'laneBits') || ...
        size(reference.laneBits, 2) ~= 4
    error('accumulate_realtime_dac_ber:Reference', ...
        'A four-lane RF47 DA reference is required.');
end
if nargin < 1 || isempty(state)
    state = initial_state();
end

actual = logical(recovered_lane_bits);
reference_bits = logical(reference.laneBits);
period = size(reference_bits, 1);
sample_count = size(actual, 1);
last_xor = false(sample_count, 4);
last_errors = zeros(1, 4);
phase = zeros(1, 4);
inverted = false(1, 4);

residue = mod((0:sample_count - 1)', period) + 1;
position_counts = accumarray(residue, 1, [period 1]);
for lane = 1:4
    ones_by_position = accumarray(residue, double(actual(:, lane)), ...
        [period 1]);
    best_errors = inf;
    best_phase = 0;
    best_inverted = false;
    for candidate = 0:period - 1
        expected_period = reference_bits( ...
            mod((0:period - 1)' + candidate, period) + 1, lane);
        direct_errors = sum(ones_by_position(~expected_period)) + ...
            sum(position_counts(expected_period) - ...
            ones_by_position(expected_period));
        inverse_errors = sample_count - direct_errors;
        if direct_errors < best_errors
            best_errors = direct_errors;
            best_phase = candidate;
            best_inverted = false;
        end
        if inverse_errors < best_errors
            best_errors = inverse_errors;
            best_phase = candidate;
            best_inverted = true;
        end
    end

    expected = reference_bits( ...
        mod((0:sample_count - 1)' + best_phase, period) + 1, lane);
    if best_inverted
        expected = ~expected;
    end
    last_xor(:, lane) = xor(actual(:, lane), expected);
    last_errors(lane) = sum(last_xor(:, lane));
    phase(lane) = best_phase;
    inverted(lane) = best_inverted;
end

last_bits = sample_count * ones(1, 4);
state.captureCount = state.captureCount + 1;
state.totalErrorsByLane = state.totalErrorsByLane + last_errors;
state.totalBitsByLane = state.totalBitsByLane + last_bits;
state.lastErrorsByLane = last_errors;
state.lastBitsByLane = last_bits;
state.lastPhase = phase;
state.lastInverted = inverted;
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
