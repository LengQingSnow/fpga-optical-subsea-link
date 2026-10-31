function model = estimate_continuous_cdr(chunk_start_points, ...
    chunk_phases, chunk_processed, sample_rate, cfg)
%ESTIMATE_CONTINUOUS_CDR Fit a common clock and smooth timing trajectory.

valid = logical(chunk_processed(:)) & ...
    all(isfinite(chunk_phases), 2) & isfinite(chunk_start_points(:));
if sum(valid) < cfg.cdrMinimumAnchors
    error('estimate_continuous_cdr:TooFewAnchors', ...
        'Continuous CDR requires at least %d valid timing anchors.', ...
        cfg.cdrMinimumAnchors);
end

samples_per_symbol = double(sample_rate) / double(cfg.symbolRateHz);
anchor_symbols = (double(chunk_start_points(valid)) - 1) / ...
    samples_per_symbol;
measured = double(chunk_phases(valid, :));
anchor_count = numel(anchor_symbols);
lane_count = size(measured, 2);
prior_slope = double(cfg.cdrClockOffsetPpmPrior) * 1e-6;

% Unwrap each modulo-UI observation around the expected low-ppm clock line.
unwrapped = zeros(size(measured));
for lane = 1:lane_count
    prediction = measured(1, lane) + prior_slope * ...
        (anchor_symbols - anchor_symbols(1));
    unwrapped(:, lane) = measured(:, lane) + ...
        round(prediction - measured(:, lane));
end

% A median of all within-lane pair slopes is insensitive to an occasional
% phase-search outlier and preserves the measured -0.183 ppm-scale drift.
pair_count = anchor_count * (anchor_count - 1) / 2;
slopes = zeros(pair_count * lane_count, 1);
write_index = 1;
for lane = 1:lane_count
    for first = 1:anchor_count - 1
        count = anchor_count - first;
        indices = first + 1:anchor_count;
        slopes(write_index:write_index + count - 1) = ...
            (unwrapped(indices, lane) - unwrapped(first, lane)) ./ ...
            (anchor_symbols(indices) - anchor_symbols(first));
        write_index = write_index + count;
    end
end
slope = median(slopes(1:write_index - 1));

reference_symbol = median(anchor_symbols);
centered_symbols = anchor_symbols - reference_symbol;
lane_intercepts = zeros(1, lane_count);
for lane = 1:lane_count
    lane_intercepts(lane) = median(unwrapped(:, lane) - ...
        slope * centered_symbols);
end

predicted = bsxfun(@plus, slope * centered_symbols, lane_intercepts);
residual = unwrapped - predicted;
inlier = abs(residual) <= double(cfg.cdrAnchorOutlierUi);

% Refit a common slope with lane-specific intercepts after rejecting bad
% anchors. This is the frequency term of the second-order timing loop.
numerator = 0;
denominator = 0;
for lane = 1:lane_count
    lane_valid = inlier(:, lane);
    if sum(lane_valid) < 2
        continue;
    end
    x = centered_symbols(lane_valid);
    y = unwrapped(lane_valid, lane);
    x_center = x - mean(x);
    y_center = y - mean(y);
    numerator = numerator + sum(x_center .* y_center);
    denominator = denominator + sum(x_center .^ 2);
end
if denominator > 0
    slope = numerator / denominator;
end
for lane = 1:lane_count
    lane_valid = inlier(:, lane);
    lane_intercepts(lane) = median(unwrapped(lane_valid, lane) - ...
        slope * centered_symbols(lane_valid));
end

predicted = bsxfun(@plus, slope * centered_symbols, lane_intercepts);
residual = unwrapped - predicted;
inlier = abs(residual) <= double(cfg.cdrAnchorOutlierUi);
common_residual = zeros(anchor_count, 1);
for anchor = 1:anchor_count
    values = residual(anchor, inlier(anchor, :));
    if anchor == 1 && isempty(values)
        common_residual(anchor) = 0;
    elseif isempty(values)
        common_residual(anchor) = common_residual(anchor - 1);
    else
        common_residual(anchor) = median(values);
    end
end

% Forward/backward one-pole smoothing is a low-bandwidth phase loop. The
% frequency slope remains continuous, while common residual wander is
% followed without injecting the 1/32-UI phase-search quantization.
alpha = double(cfg.cdrResidualSmoothing);
forward = zeros(anchor_count, 1);
backward = zeros(anchor_count, 1);
forward(1) = common_residual(1);
for index = 2:anchor_count
    forward(index) = forward(index - 1) + ...
        alpha * (common_residual(index) - forward(index - 1));
end
backward(end) = common_residual(end);
for index = anchor_count - 1:-1:1
    backward(index) = backward(index + 1) + ...
        alpha * (common_residual(index) - backward(index + 1));
end
smoothed_residual = (forward + backward) / 2;
anchor_phase = bsxfun(@plus, ...
    slope * centered_symbols + smoothed_residual, lane_intercepts);

model.anchorSymbols = anchor_symbols;
model.anchorPhaseSymbols = anchor_phase;
model.measuredPhaseSymbols = measured;
model.unwrappedPhaseSymbols = unwrapped;
model.inlierMask = inlier;
model.referenceSymbol = reference_symbol;
model.phaseSlopeUiPerSymbol = slope;
model.clockOffsetPpm = slope * 1e6;
model.estimatedSymbolRateHz = double(cfg.symbolRateHz) / (1 + slope);
model.effectiveSamplesPerSymbol = samples_per_symbol * (1 + slope);
model.phaseAtStart = evaluate_phase(model, 0);
model.anchorResidualRmsUi = sqrt(mean(common_residual .^ 2));
model.trackedResidualRmsUi = sqrt(mean((common_residual - ...
    smoothed_residual) .^ 2));
end

function phase = evaluate_phase(model, symbol_position)
phase = zeros(1, size(model.anchorPhaseSymbols, 2));
for lane = 1:numel(phase)
    phase(lane) = interp1(model.anchorSymbols, ...
        model.anchorPhaseSymbols(:, lane), symbol_position, ...
        'linear', 'extrap');
end
end
