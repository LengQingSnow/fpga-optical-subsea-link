function [processed, diagnostics] = lop10_preprocess_capture(capture, options)
%LOP10_PREPROCESS_CAPTURE Apply the validated 10 dB DSP front end.
% This helper is used only by page 6.  Automatic CD compensation is already
% applied before this function, therefore the DBP dispersion term is zero to
% avoid applying chromatic-dispersion compensation twice.  The nonlinear
% phase, SSFM step count, and passband are the validated 10 dB settings.

if nargin < 2 || isempty(options)
    options = struct();
end
if ~isstruct(capture) || ~isfield(capture, 'channels') || ...
        ~isfield(capture, 'sampleRateHz')
    error('lop10_preprocess_capture:Capture', ...
        'Capture must contain channels and sampleRateHz.');
end

matlab_dir = fileparts(mfilename('fullpath'));
lop_dsp_dir = fullfile(fileparts(matlab_dir), 'lop', '10db', 'dsp');
if exist(lop_dsp_dir, 'dir') ~= 7
    error('lop10_preprocess_capture:MissingDsp', ...
        'The validated 10 dB DSP directory is missing: %s', lop_dsp_dir);
end
addpath(lop_dsp_dir);

dispersion = get_option(options, 'dispersionPsNm', 0);
nonlinear_phase = get_option(options, 'nonlinearPhase', 0.01);
steps = round(get_option(options, 'steps', 8));
passband_hz = get_option(options, 'passbandHz', 2.6e9);
stopband_hz = get_option(options, 'stopbandHz', 3.4e9);

processed = offline_dbp_ssfm_trial(capture, dispersion, ...
    nonlinear_phase, steps, struct('passbandHz', passband_hz, ...
    'stopbandHz', stopband_hz));

diagnostics = struct();
diagnostics.dispersionPsNm = dispersion;
diagnostics.nonlinearPhase = nonlinear_phase;
diagnostics.steps = steps;
diagnostics.passbandHz = passband_hz;
diagnostics.stopbandHz = stopband_hz;
diagnostics.sampleRateHz = capture.sampleRateHz;
diagnostics.pointCount = size(capture.channels, 1);
diagnostics.reference = '10db validated front end; CD term omitted after automatic page-6 CD compensation';
end

function value = get_option(options, name, default_value)
if isfield(options, name) && ~isempty(options.(name))
    value = options.(name);
else
    value = default_value;
end
end
