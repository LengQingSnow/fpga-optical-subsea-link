function result = offline_joint_qpsk_bps(equalizer_result, options)
%OFFLINE_JOINT_QPSK_BPS Blind sliding carrier phase recovery for DP-QPSK.
%   The phase metric uses constellation distance only.  The known reference
%   is used solely after phase recovery to report held-out BER and EVM.

if nargin < 2 || isempty(options)
    options = struct();
end
if ~isstruct(equalizer_result) || ...
        ~isfield(equalizer_result, 'equalizedSymbols') || ...
        ~isfield(equalizer_result, 'desiredSymbols')
    error('offline_joint_qpsk_bps:Input', ...
        'An offline_reference_wl_fse result is required.');
end
input = double(equalizer_result.equalizedSymbols);
target = double(equalizer_result.desiredSymbols);
block_symbols = round(get_option(options, 'blockSymbols', 64));
phase_count = round(get_option(options, 'phaseCount', 81));
joint = logical(get_option(options, 'jointPolarizations', true));
if block_symbols < 8 || phase_count < 9
    error('offline_joint_qpsk_bps:Options', ...
        'blockSymbols and phaseCount are too small.');
end

test_phases = (-pi / 4) + (0:phase_count - 1) * ...
    ((pi / 2) / phase_count);
count = size(input, 1);
block_count = ceil(count / block_symbols);
phase_centers = zeros(block_count, 2);
center_indices = zeros(block_count, 1);
for block = 1:block_count
    first = (block - 1) * block_symbols + 1;
    last = min(count, block * block_symbols);
    values = input(first:last, :);
    center_indices(block) = 0.5 * (first + last);
    if joint
        metrics = zeros(phase_count, 1);
        for phase_index = 1:phase_count
            rotated = values * exp(-1i * test_phases(phase_index));
            decisions = qpsk_decision(rotated);
            metrics(phase_index) = mean(abs(rotated(:) - ...
                decisions(:)) .^ 2);
        end
        [~, best_index] = min(metrics);
        phase_centers(block, :) = test_phases(best_index);
    else
        for polarization = 1:2
            metrics = zeros(phase_count, 1);
            for phase_index = 1:phase_count
                rotated = values(:, polarization) * ...
                    exp(-1i * test_phases(phase_index));
                decisions = qpsk_decision(rotated);
                metrics(phase_index) = mean(abs(rotated - decisions) .^ 2);
            end
            [~, best_index] = min(metrics);
            phase_centers(block, polarization) = ...
                test_phases(best_index);
        end
    end
end

for polarization = 1:2
    phase_centers(:, polarization) = unwrap_qpsk_phase( ...
        phase_centers(:, polarization));
end
sample_indices = (1:count).';
phase_track = zeros(count, 2);
for polarization = 1:2
    if block_count == 1
        phase_track(:, polarization) = phase_centers(1, polarization);
    else
        phase_track(:, polarization) = interp1(center_indices, ...
            phase_centers(:, polarization), sample_indices, ...
            'linear', 'extrap');
    end
end
corrected = input .* exp(-1i * phase_track);
corrected_real = [real(corrected(:, 1)), imag(corrected(:, 1)), ...
    real(corrected(:, 2)), imag(corrected(:, 2))] * sqrt(2);
target_real = [real(target(:, 1)), imag(target(:, 1)), ...
    real(target(:, 2)), imag(target(:, 2))] * sqrt(2);
errors = (corrected_real >= 0) ~= (target_real >= 0);

result = equalizer_result;
result.preBpsBer = equalizer_result.ber;
result.preBpsBerByLane = equalizer_result.berByLane;
result.preBpsEvmRms = equalizer_result.evmRms;
result.ber = mean(errors(:));
result.berByLane = mean(errors, 1);
result.evmRms = sqrt(mean(abs(corrected - target) .^ 2, 1));
result.equalizedSymbols = corrected;
result.equalizedReal = corrected_real;
result.bpsBlockSymbols = block_symbols;
result.bpsPhaseCount = phase_count;
result.bpsJointPolarizations = joint;
result.bpsPhaseTrack = phase_track;
end

function decisions = qpsk_decision(values)
real_sign = ones(size(values));
imag_sign = ones(size(values));
real_sign(real(values) < 0) = -1;
imag_sign(imag(values) < 0) = -1;
decisions = (real_sign + 1i * imag_sign) / sqrt(2);
end

function output = unwrap_qpsk_phase(input)
output = input;
for index = 2:numel(input)
    candidates = input(index) + (-2:2) * (pi / 2);
    [~, best] = min(abs(candidates - output(index - 1)));
    output(index) = candidates(best);
end
end

function value = get_option(options, name, default_value)
if isfield(options, name) && ~isempty(options.(name))
    value = options.(name);
else
    value = default_value;
end
end
