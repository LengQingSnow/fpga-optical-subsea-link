function [state, result] = accumulate_cma_window_ber(state, errors_by_lane, bits_by_lane)
%ACCUMULATE_CMA_WINDOW_BER Accumulate a directly reference-tested window.

validateattributes(errors_by_lane, {'numeric'}, {'vector', 'numel', 4, 'nonnegative'});
validateattributes(bits_by_lane, {'numeric'}, {'vector', 'numel', 4, 'positive'});
if nargin < 1 || isempty(state)
    state = struct('captureCount', 0, 'totalErrorsByLane', zeros(1, 4), ...
        'totalBitsByLane', zeros(1, 4));
end
errors_by_lane = double(errors_by_lane(:).');
bits_by_lane = double(bits_by_lane(:).');
state.captureCount = state.captureCount + 1;
state.totalErrorsByLane = state.totalErrorsByLane + errors_by_lane;
state.totalBitsByLane = state.totalBitsByLane + bits_by_lane;
result = struct();
result.captureCount = state.captureCount;
result.lastErrorsByLane = errors_by_lane;
result.lastBitsByLane = bits_by_lane;
result.totalErrorsByLane = state.totalErrorsByLane;
result.totalBitsByLane = state.totalBitsByLane;
result.lastBerByLane = errors_by_lane ./ bits_by_lane;
result.totalBerByLane = state.totalErrorsByLane ./ state.totalBitsByLane;
result.lastErrors = sum(errors_by_lane);
result.lastBits = sum(bits_by_lane);
result.totalErrors = sum(state.totalErrorsByLane);
result.totalBits = sum(state.totalBitsByLane);
result.lastBer = result.lastErrors / result.lastBits;
result.totalBer = result.totalErrors / result.totalBits;
result.resolution = 1 / result.totalBits;
result.targetReached = result.totalBits >= 1e6;
result.zeroErrorUpper95 = -log(0.05) / result.totalBits;
result.phase = zeros(1, 4);
result.inverted = false(1, 4);
result.lastXor = false(0, 4);
result.lastUpdate = now;
end
