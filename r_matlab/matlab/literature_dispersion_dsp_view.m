function [view, diagnostics, state] = literature_dispersion_dsp_view( ...
        capture, reference, options, state)
%LITERATURE_DISPERSION_DSP_VIEW Page-5-only offline DSP chain for live data.
%   The chain is the validated diagnostic sequence:
%   automatic CD compensation -> reference-aided CFO search -> 2-SPS
%   widely-linear FSE -> joint block BPS.  This helper is intentionally
%   separate from the existing page-3/page-4 code paths.
%
%   MATLAB 2016a compatible; no toolbox-specific functions are required.

if nargin < 3 || isempty(options)
    options = struct();
end
if nargin < 4 || isempty(state)
    state = struct();
end
if ~isstruct(capture) || ~isfield(capture, 'channels') || ...
        ~isfield(capture, 'sampleRateHz')
    error('literature_dispersion_dsp_view:Capture', ...
        'Capture must contain channels and sampleRateHz.');
end
if size(capture.channels, 2) ~= 4
    error('literature_dispersion_dsp_view:Channels', ...
        'Four channels ordered XI, XQ, YI, YQ are required.');
end
if ~isstruct(reference) || ~isfield(reference, 'laneBits') || ...
        size(reference.laneBits, 2) ~= 4
    error('literature_dispersion_dsp_view:Reference', ...
        'A four-lane RF47 reference is required.');
end

symbol_rate = get_option(options, 'symbolRateHz', 4e9);
use_dbp = logical(get_option(options, 'useDbp', false));
if use_dbp
    % These are the parameters selected by the offline 2M/10M scans.  At
    % one million input points the operation remains suitable for the
    % fifth-page refresh period and avoids the boundary solution observed
    % in the blind linear CD score on this capture.
    dispersion_ps_nm = get_option(options, 'dbpDispersionPsNm', -7250);
    nonlinear_phase = get_option(options, 'dbpNonlinearPhase', 0.01);
    dbp_steps = round(get_option(options, 'dbpSteps', 8));
    compensated = offline_dbp_ssfm_trial(capture, dispersion_ps_nm, ...
        nonlinear_phase, dbp_steps, struct('passbandHz', 2.6e9, ...
        'stopbandHz', 3.4e9));
    diagnostics = struct();
    diagnostics.dispersionPsNm = dispersion_ps_nm;
    diagnostics.nonlinearPhase = nonlinear_phase;
    diagnostics.dbpSteps = dbp_steps;
    diagnostics.decimation = 1;
    diagnostics.inputSampleRateHz = capture.sampleRateHz;
    diagnostics.outputSampleRateHz = compensated.sampleRateHz;
    diagnostics.scanPointCount = 0;
    diagnostics.fiberLengthKm = 330;
    diagnostics.wavelengthNm = 1550;
    diagnostics.searchSucceeded = true;
else
    % Automatic 330 km CD search.  The selected value is determined from
    % the captured waveform plus the persisted reference sequence; it is
    % not fixed to the previous -7250 ps/nm value.
    [compensated, diagnostics, fast_probe] = ...
        auto_reference_cd_compensate_capture(capture, reference, ...
        struct('symbolRateHz', symbol_rate, ...
        'scanPointCount', get_option(options, 'dispersionScanPointCount', 32768), ...
        'coarseGridPsNm', get_option(options, 'coarseGridPsNm', ...
        -9500:500:-5500), ...
        'refineStepPsNm', get_option(options, 'refineStepPsNm', 100), ...
        'refineHalfRangePsNm', get_option(options, ...
        'refineHalfRangePsNm', 500)));
end

% The real-time page uses a fast FFT + period estimator for CFO and timing.
% The heavier reference CFO grid scan remains an offline diagnostic; using
% it on every GUI refresh would make the page unresponsive.
if use_dbp
    fast_probe = offline_fast_reference_probe(compensated, reference, ...
        struct('symbolRateHz', symbol_rate, 'searchPeriods', 2));
end
probe = struct('frequencyOffsetHz', fast_probe.frequencyOffsetHz, ...
    'phase', fast_probe.phase, 'shift', fast_probe.shift);

% The validated -1.75 offset was measured at the original 40 GSa/s rate.
% Convert it to the two-SPS rate used after CD compensation.  If the phase
% is the first sample, use the second sample as the safe interpolation
% origin so the FSE never consumes an out-of-range extrapolated value.
fractional_offset = -1.75 / max(1, diagnostics.decimation);
if probe.phase < 2 && probe.phase + fractional_offset < 1
    probe.phase = 2;
end

fse = offline_reference_wl_fse(compensated, reference, probe, struct( ...
    'symbolRateHz', symbol_rate, 'tapCount', 7, ...
    'trainSymbols', 1024, 'outputSymbols', 16, 'ridge', 0.1, ...
    'causal', false, 'fractionalSampleOffset', fractional_offset, ...
    'timingSlope', -1.5e-6 / max(1, diagnostics.decimation)));
bps = offline_joint_qpsk_bps(fse, struct( ...
    'blockSymbols', 64, 'phaseCount', 321, ...
    'jointPolarizations', true));

% Keep the result shape expected by the fifth-page renderer and BER block.
display_count = min(30000, size(bps.equalizedSymbols, 1));
first = size(bps.equalizedSymbols, 1) - display_count + 1;
view = struct();
view.equalizedSymbols = bps.equalizedSymbols(first:end, :);
view.evmRms = bps.evmRms;
view.frequencyOffsetHz = probe.frequencyOffsetHz;
view.sampleOffset = probe.phase;
view.finalCost = bps.ber;
view.converged = isfinite(bps.ber);
view.pointCount = capture.pointCount;
view.compensatedPointCount = compensated.pointCount;
view.iqCorrectionApplied = false(1, 2);
% The BPS result is reference-tested and supplies berByLane.  The GUI uses
% this field to accumulate the fifth-page physical BER without changing the
% page-3/page-4 accounting paths.
view.referenceRefinement = bps;
view.preBpsBer = bps.preBpsBer;
view.preBpsEvmRms = bps.preBpsEvmRms;
view.fractionalSampleOffset = fractional_offset;
view.timingSlope = -1.5e-6 / max(1, diagnostics.decimation);
view.dispersionDiagnostics = diagnostics;
view.dspName = 'AUTO-CD+CFO+WL-FSE+BPS';

state.frequencyOffsetHz = probe.frequencyOffsetHz;
state.sampleOffset = probe.phase;
state.referenceShift = probe.shift;
state.dispersionPsNm = diagnostics.dispersionPsNm;
state.updatedAt = now;
end

function value = get_option(options, name, default_value)
if isfield(options, name) && ~isempty(options.(name))
    value = options.(name);
else
    value = default_value;
end
end
