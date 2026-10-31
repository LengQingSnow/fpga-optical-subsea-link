function result = offline_bps_reference_mimo(bps_result, options)
%OFFLINE_BPS_REFERENCE_MIMO Reference-aided decision-directed MIMO cleanup.
%   A complex 2-by-2 affine matrix is fitted only from preceding corrected
%   symbols, then applied to the current block. This is an offline test of
%   slow polarization/gain drift; it does not alter the GUI or FPGA.

if nargin < 2 || isempty(options)
    options = struct();
end
if ~isstruct(bps_result) || ~isfield(bps_result, 'equalizedSymbols') || ...
        ~isfield(bps_result, 'desiredSymbols')
    error('offline_bps_reference_mimo:Input', ...
        'A BPS result with equalized and desired symbols is required.');
end
input = double(bps_result.equalizedSymbols);
target = double(bps_result.desiredSymbols);
if size(input, 2) ~= 2 || ~isequal(size(input), size(target))
    error('offline_bps_reference_mimo:Dimensions', ...
        'The two polarization matrices must have equal two-column size.');
end
block_symbols = max(8, round(get_option(options, 'blockSymbols', 64)));
train_symbols = max(16, round(get_option(options, 'trainSymbols', 256)));
ridge = get_option(options, 'ridge', 1e-2);
count = size(input, 1);
corrected = zeros(size(input));
coefficients = zeros(3, 2, ceil(count / block_symbols));
for block = 1:ceil(count / block_symbols)
    first = (block - 1) * block_symbols + 1;
    last = min(count, first + block_symbols - 1);
    if first <= 1
        corrected(first:last, :) = input(first:last, :);
        coefficients(:, :, block) = [eye(2); zeros(1, 2)];
        continue;
    end
    train_first = max(1, first - train_symbols);
    train_indices = (train_first:first - 1).';
    design = [input(train_indices, :), ones(numel(train_indices), 1)];
    identity = eye(3);
    identity(end, end) = 0;
    coefficient = (design' * design + ridge * identity) \ ...
        (design' * target(train_indices, :));
    corrected(first:last, :) = [input(first:last, :), ...
        ones(last - first + 1, 1)] * coefficient;
    coefficients(:, :, block) = coefficient;
end
corrected_real = [real(corrected(:, 1)), imag(corrected(:, 1)), ...
    real(corrected(:, 2)), imag(corrected(:, 2))] * sqrt(2);
target_real = [real(target(:, 1)), imag(target(:, 1)), ...
    real(target(:, 2)), imag(target(:, 2))] * sqrt(2);
errors = (corrected_real >= 0) ~= (target_real >= 0);
result = bps_result;
result.preMimoBer = bps_result.ber;
result.preMimoBerByLane = bps_result.berByLane;
result.preMimoEvmRms = bps_result.evmRms;
result.ber = mean(errors(:));
result.berByLane = mean(errors, 1);
result.evmRms = sqrt(mean(abs(corrected - target) .^ 2, 1));
result.equalizedSymbols = corrected;
result.equalizedReal = corrected_real;
result.referenceMimoBlockSymbols = block_symbols;
result.referenceMimoTrainSymbols = train_symbols;
result.referenceMimoCoefficients = coefficients;
end

function value = get_option(options, name, default_value)
if isfield(options, name) && ~isempty(options.(name))
    value = options.(name);
else
    value = default_value;
end
end
