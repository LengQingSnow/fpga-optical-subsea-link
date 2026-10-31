function [lane_bits, diagnostics] = equalize_dpqpsk_symbols(soft_symbols, rx_bytes, packing, cfg)
%EQUALIZE_DPQPSK_SYMBOLS Train a short per-lane MMSE FIR on sync words.

validateattributes(soft_symbols, {'single', 'double'}, ...
    {'2d', 'nonempty', 'finite'}, mfilename, 'soft_symbols', 1);
if size(soft_symbols, 2) ~= 4
    error('equalize_dpqpsk_symbols:LaneCount', 'Expected four soft-symbol lanes.');
end
rx_bytes = uint8(rx_bytes(:));
if ~isfield(packing, 'nibbleOffset') || ...
        ~isfield(packing, 'laneSymbolOffsets') || ...
        ~isfield(packing, 'lanePolarity')
    error('equalize_dpqpsk_symbols:Packing', ...
        'Packing diagnostics are missing sync-to-symbol alignment fields.');
end

sync_positions = strfind(double(rx_bytes(:).'), double(cfg.syncWord(:).'));
if numel(sync_positions) < cfg.postEqualizerMinimumSyncFrames
    error('equalize_dpqpsk_symbols:TooFewTrainingFrames', ...
        'Need at least %d exact sync words, found %d.', ...
        cfg.postEqualizerMinimumSyncFrames, numel(sync_positions));
end
max_frames = min(numel(sync_positions), cfg.postEqualizerMaximumSyncFrames);
selected_frames = unique(round(linspace(1, numel(sync_positions), max_frames)));
train_frames = selected_frames(1:2:end);
validation_frames = selected_frames(2:2:end);
if isempty(validation_frames)
    validation_frames = train_frames;
end

sync_nibbles = zeros(2 * numel(cfg.syncWord), 1, 'uint8');
sync_nibbles(1:2:end) = bitshift(uint8(cfg.syncWord(:)), -4);
sync_nibbles(2:2:end) = bitand(uint8(cfg.syncWord(:)), uint8(15));
expected_bits = false(numel(sync_nibbles), 4);
for lane = 1:4
    expected_bits(:, lane) = bitget(sync_nibbles, 5 - lane) ~= 0;
end

tap_candidates = double(cfg.postEqualizerTapCandidates(:).');
lambda_candidates = double(cfg.postEqualizerLambdaCandidates(:).');
max_taps = max(tap_candidates);
if mod(max_taps, 2) ~= 1 || max_taps < 1
    error('equalize_dpqpsk_symbols:TapConfiguration', ...
        'Tap candidates must be positive odd lengths.');
end
half_max = (max_taps - 1) / 2;
oriented = zeros(size(soft_symbols), 'single');
for lane = 1:4
    oriented(:, lane) = single(double(soft_symbols(:, lane)) * ...
        double(packing.lanePolarity(lane)));
end

training = build_training_indices(sync_positions, train_frames, ...
    expected_bits, packing, size(oriented, 1), half_max);
validation = build_training_indices(sync_positions, validation_frames, ...
    expected_bits, packing, size(oriented, 1), half_max);
if training.count < cfg.postEqualizerMinimumTrainingSymbols || ...
        validation.count < cfg.postEqualizerMinimumValidationSymbols
    error('equalize_dpqpsk_symbols:TooFewTrainingSymbols', ...
        'Insufficient valid sync symbols for supervised equalization.');
end

equalized = zeros(size(oriented), 'single');
taps = zeros(max_taps, 4);
training_mse = zeros(1, 4);
validation_mse = zeros(1, 4);
baseline_validation_mse = zeros(1, 4);
selected_taps = zeros(1, 4);
selected_lambda = zeros(1, 4);
for lane = 1:4
    signal = double(oriented(:, lane));
    [normal_matrix, cross_vector, scale] = accumulate_normal_equations( ...
        signal, training.indices(:, lane), training.targets(:, lane), half_max);
    center = half_max + 1;
    baseline = validation_signal(signal, validation.indices(:, lane));
    baseline_validation_mse(lane) = mean((baseline - ...
        validation.targets(:, lane)) .^ 2);
    best_mse = inf;
    best_h = zeros(max_taps, 1);
    best_length = 1;
    best_lambda = lambda_candidates(1);
    for tap_length = tap_candidates
        half = (tap_length - 1) / 2;
        tap_indices = center - half:center + half;
        for lambda = lambda_candidates
            matrix = normal_matrix(tap_indices, tap_indices) + ...
                lambda * scale * eye(tap_length);
            candidate = matrix \ cross_vector(tap_indices);
            candidate_signal = validation_signal(signal, ...
                validation.indices(:, lane), half_max, tap_indices, candidate);
            mse = mean((candidate_signal - ...
                validation.targets(:, lane)) .^ 2);
            if mse < best_mse
                best_mse = mse;
                best_h = zeros(max_taps, 1);
                best_h(tap_indices) = candidate;
                best_length = tap_length;
                best_lambda = lambda;
            end
        end
    end
    train_prediction = training_signal(signal, training.indices(:, lane), ...
        half_max, best_h);
    training_mse(lane) = mean((train_prediction - ...
        training.targets(:, lane)) .^ 2);
    validation_mse(lane) = best_mse;
    taps(:, lane) = best_h;
    selected_taps(lane) = best_length;
    selected_lambda(lane) = best_lambda;
    equalized(:, lane) = apply_centered_fir(signal, best_h, half_max);
end

lane_bits = equalized >= 0;
diagnostics.enabled = true;
diagnostics.syncFrameCount = numel(sync_positions);
diagnostics.trainingFrameCount = numel(train_frames);
diagnostics.validationFrameCount = numel(validation_frames);
diagnostics.trainingSymbolCount = training.count;
diagnostics.validationSymbolCount = validation.count;
diagnostics.tapCandidates = tap_candidates;
diagnostics.lambdaCandidates = lambda_candidates;
diagnostics.selectedTapLength = selected_taps;
diagnostics.selectedLambda = selected_lambda;
diagnostics.taps = taps;
diagnostics.baselineValidationMse = baseline_validation_mse;
diagnostics.trainingMse = training_mse;
diagnostics.validationMse = validation_mse;
diagnostics.validationMseImprovement = ...
    1 - validation_mse ./ max(baseline_validation_mse, eps);
end

function result = build_training_indices(sync_positions, frame_indices, ...
    expected_bits, packing, point_count, half_max)
row_count = size(expected_bits, 1);
positions = zeros(numel(frame_indices) * row_count, 4);
targets = false(size(positions, 1), 4);
write_index = 0;
for index = 1:numel(frame_indices)
    byte_position = sync_positions(frame_indices(index));
    row_start = double(packing.nibbleOffset) + ...
        2 * (double(byte_position) - 1) + 1;
    rows = row_start + (0:row_count - 1)';
    valid = true(row_count, 1);
    for lane = 1:4
        raw_positions = double(packing.laneSymbolOffsets(lane)) + rows;
        valid = valid & raw_positions > half_max & ...
            raw_positions <= point_count - half_max;
        positions(write_index + (1:row_count), lane) = raw_positions;
    end
    if all(valid)
        targets(write_index + (1:row_count), :) = expected_bits;
    else
        positions(write_index + (1:row_count), :) = 0;
    end
    write_index = write_index + row_count;
end
valid = all(positions > 0, 2);
result.indices = positions(valid, :);
result.targets = targets(valid, :);
result.count = size(result.indices, 1);
end

function [normal_matrix, cross_vector, scale] = accumulate_normal_equations( ...
    signal, indices, targets, half_max)
tap_count = 2 * half_max + 1;
normal_matrix = zeros(tap_count, tap_count);
cross_vector = zeros(tap_count, 1);
chunk_size = 20000;
for first = 1:chunk_size:numel(indices)
    last = min(numel(indices), first + chunk_size - 1);
    row_indices = bsxfun(@plus, double(indices(first:last)), ...
        -half_max:half_max);
    design = signal(row_indices);
    desired = 2 * double(targets(first:last)) - 1;
    normal_matrix = normal_matrix + design' * design;
    cross_vector = cross_vector + design' * desired;
end
scale = trace(normal_matrix) / max(1, tap_count);
if scale <= eps
    scale = 1;
end
end

function values = validation_signal(signal, indices, half_max, tap_indices, taps)
if nargin < 4
    values = signal(indices);
    return;
end
row_indices = bsxfun(@plus, double(indices), ...
    tap_indices - (half_max + 1));
values = signal(row_indices) * taps;
end

function values = training_signal(signal, indices, half_max, taps)
tap_indices = find(abs(taps) > eps).';
if isempty(tap_indices)
    values = signal(indices);
    return;
end
row_indices = bsxfun(@plus, double(indices), ...
    tap_indices - (half_max + 1));
values = signal(row_indices) * taps(tap_indices);
end

function output = apply_centered_fir(signal, taps, half_max)
output = signal;
if nnz(abs(taps) > eps) <= 1 && abs(taps(half_max + 1) - 1) <= 1e-12
    return;
end
filtered = filter(flipud(taps(:)), 1, signal);
valid_count = numel(signal) - half_max;
if valid_count > 0
    output(1:valid_count) = filtered(half_max + 1:end);
end
if half_max > 0
    output(valid_count + 1:end) = signal(valid_count + 1:end);
end
end
