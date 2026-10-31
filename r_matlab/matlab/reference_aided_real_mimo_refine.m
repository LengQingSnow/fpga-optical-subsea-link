function result = reference_aided_real_mimo_refine( ...
        input_symbols, reference, options)
%REFERENCE_AIDED_REAL_MIMO_REFINE Causal 4x4 RLS after blind CMA startup.
% The RF47 replay block supplies training symbols. Predictions are formed
% before each RLS update, so reported BER is not a fitted training error.

if nargin < 3 || isempty(options)
    options = struct();
end
validateattributes(input_symbols, {'numeric'}, {'2d', 'nonempty'}, ...
    mfilename, 'input_symbols');
if size(input_symbols, 2) ~= 2
    error('reference_aided_real_mimo_refine:Input', ...
        'Two complex input polarizations are required.');
end
if ~isstruct(reference) || ~isfield(reference, 'laneBits') || ...
        size(reference.laneBits, 2) ~= 4
    error('reference_aided_real_mimo_refine:Reference', ...
        'A four-lane RF47 replay reference is required.');
end

received = [real(input_symbols(:, 1)), imag(input_symbols(:, 1)), ...
    real(input_symbols(:, 2)), imag(input_symbols(:, 2))];
received = bsxfun(@minus, received, mean(received, 1));
received = bsxfun(@rdivide, received, std(received, 0, 1) + eps);
reference_real = 2 * double(logical(reference.laneBits)) - 1;
period = size(reference_real, 1);
count = size(received, 1);
if count < 6 * period
    error('reference_aided_real_mimo_refine:ShortCapture', ...
        'At least six replay periods are required for RLS refinement.');
end

search_periods = round(get_option(options, 'searchPeriods', 4));
search_count = min(count, max(period, search_periods * period));
design_search = [received(1:search_count, :), ones(search_count, 1)];
shift_error = inf(period, 1);
for shift = 0:period - 1
    desired = reference_real(mod((0:search_count - 1)' + shift, ...
        period) + 1, :);
    weights = design_search \ desired;
    residual = design_search * weights - desired;
    shift_error(shift + 1) = mean(residual(:) .^ 2);
end
[~, shift_index] = min(shift_error);
reference_shift = shift_index - 1;
desired = reference_real(mod((0:count - 1)' + reference_shift, ...
    period) + 1, :);

lambda = get_option(options, 'forgettingFactor', 0.98);
delta = get_option(options, 'initialCovariance', 100);
training_periods = round(get_option(options, 'trainingPeriods', 4));
training_count = min(count - period, max(period, training_periods * period));
dimension = 5;
weights = zeros(dimension, 4);
inverse_covariance = delta * eye(dimension);
predictions = zeros(count, 4);
for index = 1:count
    vector = [received(index, :).'; 1];
    prediction = weights' * vector;
    predictions(index, :) = prediction.';
    gain = inverse_covariance * vector / ...
        (lambda + vector' * inverse_covariance * vector);
    error_vector = desired(index, :).' - prediction;
    weights = weights + gain * error_vector';
    inverse_covariance = (inverse_covariance - ...
        gain * vector' * inverse_covariance) / lambda;
end

usable = (training_count + 1):count;
predictions = predictions(usable, :);
desired = desired(usable, :);
predictions = normalize_binary_components(predictions);
symbols = [predictions(:, 1) + 1i * predictions(:, 2), ...
    predictions(:, 3) + 1i * predictions(:, 4)] / sqrt(2);
desired_symbols = [desired(:, 1) + 1i * desired(:, 2), ...
    desired(:, 3) + 1i * desired(:, 4)] / sqrt(2);
errors = (predictions >= 0) ~= (desired >= 0);

result = struct();
result.equalizedSymbols = symbols;
result.desiredSymbols = desired_symbols;
result.referenceShift = reference_shift;
result.weights = weights;
result.forgettingFactor = lambda;
result.trainingSymbols = training_count;
result.berByLane = mean(errors, 1);
result.ber = mean(errors(:));
result.evmRms = sqrt(mean(abs(symbols - desired_symbols) .^ 2, 1));
result.validity(1) = cma_constellation_metrics(symbols(:, 1));
result.validity(2) = cma_constellation_metrics(symbols(:, 2));
end

function normalized = normalize_binary_components(values)
normalized = zeros(size(values));
for lane = 1:size(values, 2)
    lane_values = values(:, lane);
    negative = lane_values(lane_values < 0);
    positive = lane_values(lane_values >= 0);
    if isempty(negative) || isempty(positive)
        normalized(:, lane) = lane_values;
        continue;
    end
    center = 0.5 * (mean(positive) + mean(negative));
    half_range = 0.5 * (mean(positive) - mean(negative));
    normalized(:, lane) = (lane_values - center) / max(eps, half_range);
end
end

function value = get_option(options, name, default_value)
if isfield(options, name) && ~isempty(options.(name))
    value = options.(name);
else
    value = default_value;
end
end
