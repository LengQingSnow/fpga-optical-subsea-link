function [phase, info] = template_phase(raw, trainingTarget, initialPhase, kp, ki, amplitudeWeight)
%TEMPLATE_PHASE Causal carrier PLL with prefix-learned distorted QPSK centers.
% TRAININGTARGET and INITIALPHASE contain only the permitted training prefix.
% The first 512 phases initialize the tracker. Every subsequent innovation
% uses the nearest learned center and the current observation, never labels.
% This is a block-initialized causal tracker: its model is learned from the
% complete supplied prefix before the recurrence is evaluated.
% INFO is compact and contains no per-symbol frequency or innovation trace.

validateattributes(raw, {'numeric'}, {'vector','finite','nonempty'}, mfilename, 'raw');
validateattributes(trainingTarget, {'numeric'}, {'vector','finite','nonempty'}, mfilename, 'trainingTarget');
validateattributes(initialPhase, {'numeric'}, {'vector','real','finite','nonempty'}, mfilename, 'initialPhase');
validateattributes(kp, {'numeric'}, {'scalar','real','finite','positive'}, mfilename, 'kp');
validateattributes(ki, {'numeric'}, {'scalar','real','finite','nonnegative'}, mfilename, 'ki');
if ~isscalar(amplitudeWeight) || ...
        ~(islogical(amplitudeWeight) || isnumeric(amplitudeWeight)) || ...
        ~any(amplitudeWeight == [0 1])
    error('rf47lmsbtb:TemplateWeight','Amplitude weighting must be a scalar zero or one.');
end
raw = raw(:); trainingTarget = trainingTarget(:); initialPhase = initialPhase(:);
nt = numel(trainingTarget); N = numel(raw);
if nt < 1000 || numel(initialPhase) ~= nt || N <= nt
    error('rf47lmsbtb:TemplatePrefix', ...
        'A matching prefix of at least 1000 symbols and a longer observation are required.');
end
prefixPower = mean(abs(raw(1:nt)).^2);
if ~isfinite(prefixPower) || prefixPower <= realmin
    error('rf47lmsbtb:TemplatePower','The training prefix has no finite signal power.');
end
raw = raw/sqrt(prefixPower);
calibrated = raw(1:nt).*exp(-1i*initialPhase);
label = 1+(real(trainingTarget)>=0)+2*(imag(trainingTarget)>=0);
centers = complex(zeros(4,1));
for k = 1:4
    if ~any(label==k)
        error('rf47lmsbtb:TemplateCenters','All four QPSK centers must occur in the training prefix.');
    end
    centers(k) = mean(calibrated(label==k));
end
warm = 512; phase = zeros(N,1); phase(1:warm) = initialPhase(1:warm);
index = (129:warm)'; line = polyfit(index,initialPhase(index),1); frequency = line(1);
for k = warm+1:N
    prediction = phase(k-1)+frequency;
    sample = raw(k)*exp(-1i*prediction);
    [~,choice] = min(abs(sample-centers).^2);
    err = angle(sample*conj(centers(choice)));
    if amplitudeWeight
        weight = min(1,abs(raw(k))^2);
    else
        weight = 1;
    end
    frequency = frequency+ki*weight*err;
    phase(k) = prediction+kp*weight*err;
end
if any(~isfinite(phase))
    error('rf47lmsbtb:TemplateFinite','The carrier tracker produced nonfinite phases.');
end
info = struct('kp',kp,'ki',ki,'amplitudeWeight',logical(amplitudeWeight), ...
    'trainingSymbols',nt,'centers',centers,'warmupSymbols',warm, ...
    'lastFrequencyRadiansPerSymbol',frequency,'prefixPower',prefixPower);
end
