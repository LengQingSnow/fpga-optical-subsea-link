function result = offline_fractional_reference_mimo(capture, reference, options)
%OFFLINE_FRACTIONAL_REFERENCE_MIMO Test fractional symbol timing offline.
if nargin < 3, options = struct(); end
symbol_rate = get_option(options, 'symbolRateHz', 4e9);
fraction = get_option(options, 'fraction', 0);
sample_rate = double(capture.sampleRateHz);
sps = round(sample_rate / symbol_rate);
waveform = double(capture.channels);
waveform = bsxfun(@minus, waveform, mean(waveform, 1));
count = floor((size(waveform, 1) - sps) / sps);
base = (0:count - 1).' * sps + 1 + fraction * sps;
sampled = zeros(count, 4);
source = (1:size(waveform, 1)).';
for lane = 1:4
    sampled(:, lane) = interp1(source, waveform(:, lane), base, 'linear');
end
sub_capture = struct('channels', single(sampled), ...
    'sampleRateHz', symbol_rate, 'pointCount', count);
result = reference_aided_capture_mimo(sub_capture, reference, ...
    struct('symbolRateHz', symbol_rate, ...
    'blockSymbols', get_option(options, 'blockSymbols', 384), ...
    'searchPeriods', get_option(options, 'searchPeriods', 8)));
result.fractionalTiming = fraction;
end

function value = get_option(options, name, default_value)
if isfield(options, name) && ~isempty(options.(name))
    value = options.(name);
else
    value = default_value;
end
end
