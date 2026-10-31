function result = optical_cma_mimo_equalize(capture, options)
%OPTICAL_CMA_MIMO_EQUALIZE CMA branch dedicated to optical content decode.
% This entry isolates page 4 from the stable page-3 CMA configuration.
% Optical packet-aided phase and mapping changes belong here; the existing
% cma_mimo_equalize implementation used by page 3 remains untouched.

if nargin < 2 || isempty(options)
    options = struct();
end

result = cma_mimo_equalize(capture, options);
use_cached_training = logical(get_optical_option(options, ...
    'useCachedTraining', true));
if use_cached_training
    [cached_symbols, cache_diagnostics] = optical_apply_third_page_training( ...
        capture, fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
        'data', 'third_page_mimo_training_latest.mat'), ...
        get_optical_option(options, 'symbolRateHz', 4e9));
else
    cached_symbols = zeros(0, 2);
    cache_diagnostics = struct('used', false, ...
        'reason', 'disabled for capture-local training');
end
if cache_diagnostics.used
    [continuous_symbols, pll_diagnostics] = ...
        continuous_qpsk_pll(cached_symbols);
    sync_diagnostics = struct('score', NaN, 'residue', NaN, ...
        'polarizationSwap', false, 'conjugated', false(1, 2), ...
        'pll', pll_diagnostics, 'thirdPageTraining', cache_diagnostics);
elseif isfield(options, 'syncWord') && isfield(options, 'frameBytes')
    raw_symbols = result.cmaOutputSymbols;
    [continuous_symbols, sync_diagnostics] = sync_trained_mimo_recovery( ...
        raw_symbols, options.syncWord, options.frameBytes);
else
    raw_symbols = result.cmaOutputSymbols;
    [continuous_symbols, pll_diagnostics] = continuous_qpsk_pll(raw_symbols);
    sync_diagnostics = struct('score', NaN, 'residue', NaN, ...
        'polarizationSwap', false, 'conjugated', false(1, 2), ...
        'pll', pll_diagnostics);
end
continuous_symbols = correct_optical_iq(continuous_symbols);
continuous_symbols = bsxfun(@rdivide, continuous_symbols, ...
    sqrt(mean(abs(continuous_symbols) .^ 2, 1) + eps));
result.equalizedSymbols = continuous_symbols;
result.blindEqualizedSymbols = continuous_symbols;
reference = (sign(real(continuous_symbols)) + ...
    1i * sign(imag(continuous_symbols))) / sqrt(2);
result.evmRms = sqrt(mean(abs(continuous_symbols - reference) .^ 2, 1));
result.opticalSyncDiagnostics = sync_diagnostics;
result.opticalDecodeBranch = true;
end

function value = get_optical_option(options, name, default_value)
if isfield(options, name) && ~isempty(options.(name))
    value = options.(name);
else
    value = default_value;
end
end

function [output, diagnostics] = sync_trained_mimo_recovery( ...
        symbols, sync_word, frame_bytes)
frame_symbols = 2 * double(frame_bytes);
reference = sync_reference_symbols([uint8(sync_word(:)); uint8(1)]);
sync_symbols = size(reference, 1);
count = size(symbols, 1);
best_score = inf;
best_residue = 0;
best_coefficients = [];
for residue = 0:frame_symbols - 1
    starts = residue + 1:frame_symbols:count - sync_symbols + 1;
    starts = starts(1:min(numel(starts), 32));
    if numel(starts) < 3
        continue;
    end
    rows = zeros(numel(starts) * sync_symbols, 2);
    targets = repmat(reference, numel(starts), 1);
    for frame_index = 1:numel(starts)
        destination = (frame_index - 1) * sync_symbols + (1:sync_symbols);
        source = starts(frame_index) + (0:sync_symbols - 1);
        rows(destination, :) = symbols(source, :);
    end
    design = [rows conj(rows) ones(size(rows, 1), 1)];
    coefficients = design \ targets;
    candidate = design * coefficients;
    hard_error = (sum(sign(real(candidate(:))) ~= ...
        sign(real(targets(:)))) + sum(sign(imag(candidate(:))) ~= ...
        sign(imag(targets(:))))) / (2 * numel(targets));
    mse = mean(abs(candidate(:) - targets(:)) .^ 2);
    score = hard_error + 0.05 * mse;
    if score < best_score
        best_score = score;
        best_residue = residue;
        best_coefficients = coefficients;
    end
end
if isempty(best_coefficients)
    error('optical_cma_mimo_equalize:SyncTraining', ...
        'No periodic aggregate-sync training phase was found.');
end
all_design = [symbols conj(symbols) ones(count, 1)];
output = all_design * best_coefficients;
starts = best_residue + 1:frame_symbols:count - sync_symbols + 1;
for frame_index = 1:numel(starts)
    first = starts(frame_index);
    last = min(count, first + frame_symbols - 1);
    sync_indices = first + (0:sync_symbols - 1);
    training = symbols(sync_indices, :);
    design = [training conj(training) ones(sync_symbols, 1)];
    coefficients = design \ reference;
    block = symbols(first:last, :);
    output(first:last, :) = decision_directed_mimo_track( ...
        block, coefficients, reference);
end
diagnostics = struct('score', best_score, 'residue', best_residue, ...
    'polarizationSwap', false, 'conjugated', false(1, 2), ...
    'anchorCount', numel(starts), 'syncTrainedMimo', true);
end

function output = decision_directed_mimo_track(block, coefficients, reference)
% Continue the sync-trained mapping through one frame without phase slips.
mu = 1.5e-3;
count = size(block, 1);
training_count = size(reference, 1);
output = zeros(count, 2);
for index = 1:count
    row = [block(index, :) conj(block(index, :)) 1];
    value = row * coefficients;
    if index <= training_count
        desired = reference(index, :);
    else
        desired = (sign(real(value)) + 1i * sign(imag(value))) / sqrt(2);
    end
    error = desired - value;
    normalization = real(row * row') + eps;
    coefficients = coefficients + mu * (row' * error) / normalization;
    output(index, :) = value;
end
end

function [output, diagnostics] = continuous_qpsk_pll(input)
% Preserve temporal QPSK decisions while tracking residual carrier phase.
% The detector is invariant to one fixed pi/2 ambiguity, but unlike the
% block BPS used for constellation display it cannot introduce quadrant
% changes between adjacent blocks.
alpha = 0.025;
beta = 2.5e-5;
count = size(input, 1);
output = zeros(size(input));
diagnostics.finalPhase = zeros(1, 2);
diagnostics.finalFrequency = zeros(1, 2);
diagnostics.meanAbsError = zeros(1, 2);
for polarization = 1:2
    phase = 0;
    frequency = 0;
    error_sum = 0;
    for index = 1:count
        value = input(index, polarization) * exp(-1i * phase);
        decision = (sign(real(value)) + 1i * sign(imag(value))) / sqrt(2);
        error = angle(value * conj(decision));
        frequency = frequency + beta * error;
        phase = phase + frequency + alpha * error;
        output(index, polarization) = value;
        error_sum = error_sum + abs(error);
    end
    diagnostics.finalPhase(polarization) = phase;
    diagnostics.finalFrequency(polarization) = frequency;
    diagnostics.meanAbsError(polarization) = error_sum / count;
end
end

function reference = sync_reference_symbols(sync_word)
bytes = uint8(sync_word(:));
nibbles = zeros(2 * numel(bytes), 1, 'uint8');
nibbles(1:2:end) = bitshift(bytes, -4);
nibbles(2:2:end) = bitand(bytes, uint8(15));
bits = false(numel(nibbles), 4);
for lane = 1:4
    bits(:, lane) = logical(bitget(nibbles, 5 - lane));
end
levels = 2 * double(bits) - 1;
reference = [levels(:, 1) + 1i * levels(:, 2), ...
    levels(:, 3) + 1i * levels(:, 4)] / sqrt(2);
end

function corrected = correct_optical_iq(input)
corrected = zeros(size(input));
for polarization = 1:2
    values = input(:, polarization);
    reference = (sign(real(values)) + ...
        1i * sign(imag(values))) / sqrt(2);
    design = [values, conj(values), ones(size(values))];
    coefficients = design \ reference;
    candidate = design * coefficients;
    if all(isfinite(candidate)) && ...
            mean(abs(candidate - reference) .^ 2) <= ...
            mean(abs(values - reference) .^ 2)
        corrected(:, polarization) = candidate;
    else
        corrected(:, polarization) = values;
    end
end
end
