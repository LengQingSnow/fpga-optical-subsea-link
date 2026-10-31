function result = cma_mimo_equalize(capture, options)
%CMA_MIMO_EQUALIZE Blind 2x2 complex CMA equalizer for dual-polarization QPSK.
% Input channels are [XI XQ YI YQ] real waveforms. The function decimates
% to two samples/symbol, searches the fractional timing phase, then adapts
% a fractionally-spaced complex FIR 2x2 MIMO equalizer using CMA. A blind
% fourth-power carrier-frequency and phase recovery follows the equalizer.

if nargin < 2 || isempty(options)
    options = struct();
end
if ~isstruct(capture) || ~isfield(capture, 'channels') || ...
        ~isfield(capture, 'sampleRateHz')
    error('cma_mimo_equalize:Capture', ...
        'Capture must contain channels and sampleRateHz.');
end
waveform = double(capture.channels);
if size(waveform, 2) ~= 4
    error('cma_mimo_equalize:Channels', ...
        'Expected four channels ordered XI, XQ, YI, YQ.');
end
if any(~isfinite(waveform(:)))
    error('cma_mimo_equalize:Finite', 'Capture contains non-finite samples.');
end

sample_rate = double(capture.sampleRateHz);
symbol_rate = get_option(options, 'symbolRateHz', 4e9);
samples_per_symbol = sample_rate / symbol_rate;
if samples_per_symbol < 2
    error('cma_mimo_equalize:SampleRate', ...
        'Need at least two samples/symbol; measured %.4g.', samples_per_symbol);
end
fse_samples_per_symbol = 2;
input_decimation = max(1, round(samples_per_symbol / fse_samples_per_symbol));
actual_fse_rate = sample_rate / input_decimation;
actual_fse_sps = actual_fse_rate / symbol_rate;
if abs(actual_fse_sps - fse_samples_per_symbol) > 0.05
    error('cma_mimo_equalize:FractionalRate', ...
        ['Sample rate %.9g Hz cannot be reduced to two samples/symbol ' ...
        'with integer decimation.'], sample_rate);
end

% Remove per-channel DC and normalize the two complex polarizations.
waveform = bsxfun(@minus, waveform, mean(waveform, 1));
xi = waveform(:, 1) + 1i * waveform(:, 2);
yi = waveform(:, 3) + 1i * waveform(:, 4);
input = [xi yi];
input = bsxfun(@rdivide, input, sqrt(mean(abs(input).^2, 1) + eps));

% Estimate the common optical carrier offset before reducing to one output
% per symbol. At two samples/symbol the fourth-power estimator has twice
% the unambiguous CFO range of a symbol-rate estimator.
frequency_probe = input(1:input_decimation:end, :);
coarse_frequency_hz = estimate_qpsk_frequency_fft( ...
    frequency_probe, actual_fse_rate);
raw_sample_index = (0:size(input, 1) - 1).';
coarse_phasor = exp(-1i * 2 * pi * coarse_frequency_hz * ...
    raw_sample_index / sample_rate);
input = bsxfun(@times, input, coarse_phasor);

taps = round(get_option(options, 'taps', 31));
if taps < 3 || mod(taps, 2) == 0
    error('cma_mimo_equalize:Taps', 'taps must be an odd integer >= 3.');
end
mu = get_option(options, 'stepSize', 8e-3);
decorrelate_outputs = logical(get_option(options, ...
    'decorrelateOutputs', true));
scan_symbols = round(get_option(options, 'phaseScanSymbols', 20000));
phase_list = get_option(options, 'sampleOffsets', 1:input_decimation);
phase_list = unique(max(1, min(input_decimation, round(phase_list(:).'))));
phase_block_symbols = round(get_option(options, 'phaseBlockSymbols', 64));
phase_candidate_count = round(get_option(options, 'phaseCandidateCount', 64));
if phase_block_symbols < 4 || phase_candidate_count < 8
    error('cma_mimo_equalize:PhaseSearch', ...
        'Phase block and candidate counts are too small.');
end

% A short CMA/BPS pass selects the sampling phase using only blind QPSK
% decision error, rather than relying on CMA cost alone.
phase_cost = inf(1, numel(phase_list));
phase_quality = inf(1, numel(phase_list));
for phase_index = 1:numel(phase_list)
    decimated = input(phase_list(phase_index):input_decimation:end, :);
    decimated = decimated(1:min(2 * scan_symbols, size(decimated, 1)), :);
    if size(decimated, 1) <= taps + 4
        continue;
    end
    probe = cma_core(decimated, taps, mu * 0.5, true, 2, eye(2), ...
        decorrelate_outputs);
    phase_cost(phase_index) = probe.finalCost;
    [probe_recovered, ~, ~] = carrier_recover_qpsk(probe.output, ...
        symbol_rate, phase_block_symbols, phase_candidate_count);
    probe_recovered = bsxfun(@rdivide, probe_recovered, ...
        sqrt(mean(abs(probe_recovered) .^ 2, 1) + eps));
    probe_reference = (sign(real(probe_recovered)) + ...
        1i * sign(imag(probe_recovered))) / sqrt(2);
    phase_quality(phase_index) = sum(mean( ...
        abs(probe_recovered - probe_reference) .^ 2, 1)) + ...
        10 * qpsk_pair_penalty(probe_recovered);
end
[~, selected_index] = min(phase_quality);
if ~isfinite(phase_cost(selected_index))
    error('cma_mimo_equalize:Timing', 'No valid symbol sampling phase was found.');
end
selected_phase = phase_list(selected_index);
fse_input = input(selected_phase:input_decimation:end, :);

initial_matrices = {eye(2), ...
    [1 1; -1 1] / sqrt(2), ...
    [1 1i; 1i 1] / sqrt(2)};
best_core = [];
best_recovered = [];
best_residual_frequency_hz = [];
best_phase_trace = [];
best_quality = inf;
for trial = 1:numel(initial_matrices)
    trial_core = cma_core(fse_input, taps, mu, true, 2, ...
        initial_matrices{trial}, decorrelate_outputs);
    [trial_recovered, trial_frequency_hz, trial_phase_trace] = ...
        carrier_recover_qpsk(trial_core.output, symbol_rate, ...
        phase_block_symbols, phase_candidate_count);
    trial_recovered = bsxfun(@rdivide, trial_recovered, ...
        sqrt(mean(abs(trial_recovered) .^ 2, 1) + eps));
    trial_reference = (sign(real(trial_recovered)) + ...
        1i * sign(imag(trial_recovered))) / sqrt(2);
    trial_constellation_quality = sum(mean( ...
        abs(trial_recovered - trial_reference) .^ 2, 1));
    trial_independence = output_dependence(trial_core.output);
    trial_quality = trial_constellation_quality + ...
        2 * trial_independence + 10 * qpsk_pair_penalty(trial_recovered);
    if isempty(best_core) || trial_quality < best_quality
        best_core = trial_core;
        best_recovered = trial_recovered;
        best_residual_frequency_hz = trial_frequency_hz;
        best_phase_trace = trial_phase_trace;
        best_quality = trial_quality;
    end
end
core = best_core;
equalized = core.output;
refine_mu = get_option(options, 'refineStepSize', mu / 8);
refined_core = cma_core(fse_input, taps, refine_mu, true, 2, ...
    core.weights, decorrelate_outputs);
[refined_recovered, refined_frequency_hz, refined_phase_trace] = ...
    carrier_recover_qpsk(refined_core.output, symbol_rate, ...
    phase_block_symbols, phase_candidate_count);
refined_recovered = bsxfun(@rdivide, refined_recovered, ...
    sqrt(mean(abs(refined_recovered) .^ 2, 1) + eps));
refined_reference = (sign(real(refined_recovered)) + ...
    1i * sign(imag(refined_recovered))) / sqrt(2);
refined_constellation_quality = sum(mean( ...
    abs(refined_recovered - refined_reference) .^ 2, 1));
refined_independence = output_dependence(refined_core.output);
refined_quality = refined_constellation_quality + ...
    2 * refined_independence + 10 * qpsk_pair_penalty(refined_recovered);
refinement_used = refined_quality < best_quality;
if refinement_used
    core = refined_core;
    equalized = core.output;
    best_recovered = refined_recovered;
    best_residual_frequency_hz = refined_frequency_hz;
    best_phase_trace = refined_phase_trace;
    best_quality = refined_quality;
end

% CMA is phase blind; best_recovered is the blind BPS result selected above.
recovered = best_recovered;
residual_frequency_hz = best_residual_frequency_hz;
phase_trace = best_phase_trace;
[recovered, iq_correction, iq_correction_applied, ...
    pre_iq_metrics, post_iq_metrics] = qpsk_iq_correction(recovered);

blind_recovered = recovered;
reference_refinement = [];

% Report a QPSK-only EVM as a useful convergence indicator. The output
% ordering and polarization unitary rotation remain intentionally blind.
qpsk_reference = (sign(real(recovered)) + 1i * sign(imag(recovered))) / sqrt(2);
evm = sqrt(mean(abs(recovered - qpsk_reference) .^ 2, 1));
modulus_error = mean((abs(equalized) .^ 2 - core.modulusRadius) .^ 2, 1);

result = struct();
result.inputSymbols = fse_input(1:2:end, :);
result.fractionalInput = fse_input;
result.cmaOutputSymbols = equalized;
result.blindEqualizedSymbols = blind_recovered;
result.equalizedSymbols = recovered;
result.weights = core.weights;
result.costHistory = core.costHistory;
result.sampleRateHz = sample_rate;
result.symbolRateHz = symbol_rate;
result.samplesPerSymbol = samples_per_symbol;
result.decimation = input_decimation;
result.fractionalSamplesPerSymbol = actual_fse_sps;
result.sampleOffset = selected_phase;
result.phaseCandidates = phase_list;
result.phaseCosts = phase_cost;
result.phaseQuality = phase_quality;
result.coarseFrequencyOffsetHz = coarse_frequency_hz;
result.residualFrequencyOffsetHz = residual_frequency_hz;
result.frequencyOffsetHz = coarse_frequency_hz + residual_frequency_hz;
result.carrierPhaseTrace = phase_trace;
result.iqCorrection = iq_correction;
result.iqCorrectionApplied = iq_correction_applied;
result.preIqMetrics = pre_iq_metrics;
result.postIqMetrics = post_iq_metrics;
result.modulusRadius = core.modulusRadius;
result.modulusError = modulus_error;
result.evmRms = evm;
result.finalCost = core.finalCost;
result.refineStepSize = refine_mu;
result.refinementUsed = refinement_used;
result.outputDependence = output_dependence(equalized);
result.weightCorrelation = abs(core.weights(:, 1)' * core.weights(:, 2)) / ...
    max(eps, norm(core.weights(:, 1)) * norm(core.weights(:, 2)));
result.decorrelateOutputs = decorrelate_outputs;
result.referenceRefinement = reference_refinement;
result.converged = core.finalCost < 0.15 * max(core.initialCost, eps);
end

function dependence = output_dependence(output)
energy = sqrt(mean(abs(output(:, 1)) .^ 2) * ...
    mean(abs(output(:, 2)) .^ 2)) + eps;
direct = abs(mean(output(:, 1) .* conj(output(:, 2)))) / energy;
pseudo = abs(mean(output(:, 1) .* output(:, 2))) / energy;
dependence = direct ^ 2 + pseudo ^ 2;
end

function penalty = qpsk_pair_penalty(symbols)
penalty = 0;
for polarization = 1:2
    metrics = cma_constellation_metrics(symbols(:, polarization));
    penalty = penalty + metrics.penalty;
end
end

function [corrected, coefficients, applied, pre_metrics, post_metrics] = ...
        qpsk_iq_correction(input)
% Fit a static widely-linear affine correction for residual I/Q ellipse.
corrected = zeros(size(input));
coefficients = zeros(3, 2);
applied = false(1, 2);
pre_metrics = repmat(cma_constellation_metrics(input(:, 1)), 1, 2);
post_metrics = pre_metrics;
for polarization = 1:2
    values = input(:, polarization);
    pre_metrics(polarization) = cma_constellation_metrics(values);
    reference = (sign(real(values)) + 1i * sign(imag(values))) / sqrt(2);
    design = [values, conj(values), ones(size(values))];
    candidate_coefficients = design \ reference;
    candidate = design * candidate_coefficients;
    candidate_metrics = cma_constellation_metrics(candidate);
    preserves_dimensions = candidate_metrics.valid || ...
        (~pre_metrics(polarization).valid && ...
        candidate_metrics.penalty < pre_metrics(polarization).penalty);
    if preserves_dimensions
        coefficients(:, polarization) = candidate_coefficients;
        corrected(:, polarization) = candidate;
        post_metrics(polarization) = candidate_metrics;
        applied(polarization) = true;
    else
        coefficients(:, polarization) = [1; 0; 0];
        corrected(:, polarization) = values;
        post_metrics(polarization) = pre_metrics(polarization);
    end
end
end

function frequency_hz = estimate_qpsk_frequency_fft(input, sample_rate)
count = size(input, 1);
fft_count = 2 ^ nextpow2(min(count, 262144));
values = input(1:min(count, fft_count), :);
window = 0.5 - 0.5 * cos(2 * pi * (0:size(values, 1) - 1).' / ...
    max(1, size(values, 1) - 1));
spectrum = zeros(fft_count, 1);
for polarization = 1:2
    fourth_power = values(:, polarization) .^ 4;
    spectrum = spectrum + abs(fftshift(fft( ...
        fourth_power .* window, fft_count))) .^ 2;
end
frequency_axis = ((0:fft_count - 1).' - floor(fft_count / 2)) * ...
    (sample_rate / fft_count);
% DC terms can be produced by polarization mixing and must not mask the
% fourth-power carrier tone. One MHz is negligible at 4 Gbaud.
spectrum(abs(frequency_axis) < 4e6) = 0;
[~, peak_index] = max(spectrum);
frequency_hz = frequency_axis(peak_index) / 4;
end

function core = cma_core(symbols, taps, step_size, keep_output, ...
        output_stride, initial_matrix, decorrelate_outputs)
count = size(symbols, 1);
if count <= taps + 2
    error('cma_mimo_equalize:ShortCapture', 'Too few symbols for the CMA FIR.');
end
modulus_radius = 1;
if isequal(size(initial_matrix), [2 2])
    weights = zeros(2 * taps, 2);
    center = (taps + 1) / 2;
    weights([center, taps + center], :) = initial_matrix;
elseif isequal(size(initial_matrix), [2 * taps 2])
    weights = initial_matrix;
else
    error('cma_mimo_equalize:InitialWeights', ...
        'Initial CMA weights have incompatible dimensions.');
end
output_count = floor((count - taps) / output_stride) + 1;
output = zeros(output_count, 2);
cost_history = zeros(output_count, 1);

row = 0;
for index = taps:output_stride:count
    vector = [flipud(symbols(index - taps + 1:index, 1)); ...
        flipud(symbols(index - taps + 1:index, 2))];
    value = weights' * vector;
    error_vector = (modulus_radius - abs(value) .^ 2) .* value;
    normalization = real(vector' * vector) + 1e-9;
    weights = weights + (step_size / normalization) * vector * conj(error_vector).';
    if decorrelate_outputs
        weights = orthogonalize_output_weights(weights);
    end
    row = row + 1;
    cost_history(row) = mean(abs(error_vector) .^ 2);
    if keep_output
        output(row, :) = value.';
    end
end
if ~keep_output
    output = zeros(0, 2);
else
    % Re-filter with the converged taps. The adaptation-path samples above
    % include the initial transient and are not the final equalizer output.
    row = 0;
    for index = taps:output_stride:count
        vector = [flipud(symbols(index - taps + 1:index, 1)); ...
            flipud(symbols(index - taps + 1:index, 2))];
        row = row + 1;
        output(row, :) = (weights' * vector).';
    end
end

tail = max(1, floor(0.1 * numel(cost_history)));
core = struct();
core.weights = weights;
core.output = output;
core.costHistory = cost_history;
core.modulusRadius = modulus_radius;
core.initialCost = mean(cost_history(1:min(100, numel(cost_history))));
core.finalCost = mean(cost_history(end - tail + 1:end));
end

function weights = orthogonalize_output_weights(weights)
first = weights(:, 1);
second = weights(:, 2);
second_norm = norm(second);
projection = (first' * second) / (real(first' * first) + eps);
second = second - first * projection;
new_norm = norm(second);
if new_norm > 1e-9 && second_norm > 1e-9
    second = second * (second_norm / new_norm);
end
weights(:, 2) = second;
end

function [output, frequency_hz, phase_trace] = ...
        carrier_recover_qpsk(input, symbol_rate, phase_block_symbols, ...
        phase_candidate_count)
count = size(input, 1);
output = zeros(size(input));
frequency_hz = zeros(1, 2);
phase_trace = zeros(size(input));
sample_index = (0:count - 1).';
phase_grid = (0:phase_candidate_count - 1) * pi / ...
    (2 * phase_candidate_count);

for polarization = 1:2
    values = input(:, polarization);
    % The common CFO was already removed before CMA. A separate one-lag
    % estimate per polarization is unreliable when one branch is mixed;
    % let the short-block QPSK search handle only the residual phase.
    frequency_phase_per_symbol = 0;
    frequency_hz(polarization) = 0;
    coarse = values .* exp(-1i * frequency_phase_per_symbol * sample_index);
    tracked_phase = zeros(size(coarse));
    for block_start = 1:phase_block_symbols:count
        block_end = min(count, block_start + phase_block_symbols - 1);
        block = coarse(block_start:block_end);
        candidate_cost = zeros(1, phase_candidate_count);
        for candidate_index = 1:phase_candidate_count
            rotated = block * exp(-1i * phase_grid(candidate_index));
            reference = (sign(real(rotated)) + ...
                1i * sign(imag(rotated))) / sqrt(2);
            candidate_cost(candidate_index) = ...
                sum(abs(rotated - reference) .^ 2);
        end
        [~, best_index] = min(candidate_cost);
        best_phase = phase_grid(best_index);
        tracked_phase(block_start:block_end) = best_phase;
    end
    tracked_phase = unwrap(4 * tracked_phase) / 4;
    recovered = coarse .* exp(-1i * tracked_phase);
    phase_trace(:, polarization) = tracked_phase;
    output(:, polarization) = recovered;
end
end

function value = get_option(options, name, default_value)
if isfield(options, name) && ~isempty(options.(name))
    value = options.(name);
else
    value = default_value;
end
end
