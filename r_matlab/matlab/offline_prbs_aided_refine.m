function [refined_bytes, diagnostics] = offline_prbs_aided_refine( ...
        cma, packing, input_bytes, cfg, options)
%OFFLINE_PRBS_AIDED_REFINE Train a real FIR MIMO from known idle frames.
if nargin < 5 || isempty(options)
    options = struct();
end
taps = round(get_option(options, 'taps', 9));
ridge = get_option(options, 'ridge', 1e-2);
if mod(taps, 2) == 0 || taps < 1
    error('offline_prbs_aided_refine:Taps', 'taps must be a positive odd integer.');
end

symbols = apply_mapping(cma.equalizedSymbols, cma.opticalMappingIndex);
features = [real(symbols(:, 1)), imag(symbols(:, 1)), ...
    real(symbols(:, 2)), imag(symbols(:, 2))];
offsets = double(packing.laneSymbolOffsets(:).');
count = min(size(features, 1) - offsets);
aligned = zeros(count, 4);
for lane = 1:4
    aligned(:, lane) = features(offsets(lane) + (1:count), lane);
    if bitget(uint8(packing.polarityMask), lane)
        aligned(:, lane) = -aligned(:, lane);
    end
end
nibble_offset = double(packing.nibbleOffset);
aligned = aligned(nibble_offset + 1:end, :);

[frames, ~] = parse_aggregate_frames(input_bytes, cfg);
idle = frames.headerOk & frames.flags == uint8(6) & ...
    frames.segmentBytes == 0;
if ~any(idle)
    error('offline_prbs_aided_refine:Training', ...
        'No structurally valid idle frame is available for training.');
end
sequence_values = double(frames.sequence(idle));
training_sequence = mode(sequence_values);
training_frames = find(idle & double(frames.sequence) == training_sequence);

half = (taps - 1) / 2;
rows = zeros(0, 4 * taps + 1);
targets = zeros(0, 4);
for frame_index = reshape(training_frames, 1, [])
    expected = expected_idle_frame(uint32(training_sequence), cfg);
    desired = bytes_to_lane_levels(expected);
    positions = 2 * (double(frames.startByte(frame_index)) - 1) + ...
        (1:2 * double(cfg.frameBytes));
    usable = positions > half & positions <= size(aligned, 1) - half;
    positions = positions(usable);
    desired = desired(usable, :);
    block = make_design(aligned, positions, taps);
    rows = [rows; block]; %#ok<AGROW>
    targets = [targets; desired]; %#ok<AGROW>
end
if size(rows, 1) < 10 * size(rows, 2)
    error('offline_prbs_aided_refine:TrainingCount', ...
        'Too few known PRBS symbols for FIR training.');
end

regularizer = ridge * eye(size(rows, 2));
regularizer(end, end) = ridge * 1e-3;
weights = (rows' * rows + regularizer) \ (rows' * targets);
all_positions = (half + 1:size(aligned, 1) - half).';
prediction = make_design(aligned, all_positions, taps) * weights;
levels = zeros(size(aligned));
levels(all_positions, :) = prediction;
levels(1:half, :) = aligned(1:half, :);
levels(end - half + 1:end, :) = aligned(end - half + 1:end, :);
bits = levels >= 0;
nibbles = uint8(bits(:, 1)) * 8 + uint8(bits(:, 2)) * 4 + ...
    uint8(bits(:, 3)) * 2 + uint8(bits(:, 4));
usable_nibbles = floor(numel(nibbles) / 2) * 2;
nibbles = nibbles(1:usable_nibbles);
refined_bytes = bitshift(nibbles(1:2:end), 4) + nibbles(2:2:end);
refined_bytes = refined_bytes(:);

training_prediction = rows * weights;
training_errors = (training_prediction >= 0) ~= (targets >= 0);
diagnostics = struct('taps', taps, 'ridge', ridge, ...
    'trainingSequence', uint32(training_sequence), ...
    'trainingFrameCount', numel(training_frames), ...
    'trainingSymbolCount', size(rows, 1), ...
    'trainingBer', mean(training_errors(:)), 'weights', weights);
end

function design = make_design(features, positions, taps)
half = (taps - 1) / 2;
design = zeros(numel(positions), 4 * taps + 1);
column = 1;
for delay = -half:half
    design(:, column:column + 3) = features(positions + delay, :);
    column = column + 4;
end
design(:, end) = 1;
end

function symbols = apply_mapping(symbols, mapping_index)
index = double(mapping_index) - 1;
if floor(index / 4) ~= 0
    symbols = symbols(:, [2 1]);
end
if bitget(uint8(mod(index, 4)), 2)
    symbols(:, 1) = 1i * conj(symbols(:, 1));
end
if bitget(uint8(mod(index, 4)), 1)
    symbols(:, 2) = 1i * conj(symbols(:, 2));
end
end

function frame = expected_idle_frame(sequence, cfg)
frame = zeros(cfg.frameBytes, 1, 'uint8');
frame(1:8) = cfg.syncWord(:);
frame(9) = cfg.protocolVersion;
frame(10) = uint8(6);
frame(13:16) = write_be_u32(sequence);
frame(17:cfg.framePayloadEnd) = aggregate_prbs31_bytes( ...
    sequence, cfg.framePayloadEnd - 16);
frame(cfg.framePayloadEnd + 1:end) = write_be_u32( ...
    crc32_msb(frame(1:cfg.framePayloadEnd)));
end

function levels = bytes_to_lane_levels(bytes)
nibbles = zeros(2 * numel(bytes), 1, 'uint8');
nibbles(1:2:end) = bitshift(bytes, -4);
nibbles(2:2:end) = bitand(bytes, uint8(15));
bits = false(numel(nibbles), 4);
for lane = 1:4
    bits(:, lane) = logical(bitget(nibbles, 5 - lane));
end
levels = 2 * double(bits) - 1;
end

function bytes = write_be_u32(value)
value = uint32(value);
bytes = uint8([bitshift(value, -24); bitand(bitshift(value, -16), 255); ...
    bitand(bitshift(value, -8), 255); bitand(value, 255)]);
end

function value = get_option(options, name, default_value)
if isfield(options, name) && ~isempty(options.(name))
    value = options.(name);
else
    value = default_value;
end
end
