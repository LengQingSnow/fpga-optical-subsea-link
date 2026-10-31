function [selected, diagnostics] = acquire(capture, reference, o)
%ACQUIRE Select current-record acquisition using prefix correlation only.
% Frozen scan_lms_acquisition from coherent_btb_20260916_retest_0918.
angles = [0 .4 .8 1.2]; windows = [33 129 513]; nt = 30000;
[x, front] = rf47lmsbtb.btb_frontend(capture,o);
u = rf47lmsbtb.btb_taps(x,o.tapCount); clear x;
best = -Inf; selected = struct(); selectedMap = {};
uncalibratedBest = -Inf; uncalibrated = struct();
template = struct('initialAngle',0,'phaseSource',0,'phaseWindow',0, ...
    'correlation',[NaN NaN],'duplicateCorrelation',NaN,'valid',false,'failure','', ...
    'uncalibratedCorrelation',[NaN NaN]);
trials = repmat(template,numel(angles)*3*numel(windows),1); trial = 0;
for initAngle = angles
    o.initialAngle = initAngle;
    [raw, ~, ci] = rf47lmsbtb.btb_cma(u,o);
    for source = 1:3
        for window = windows
            trial = trial+1;
            trials(trial).initialAngle = initAngle;
            trials(trial).phaseSource = source;
            trials(trial).phaseWindow = window;
            trials(trial).duplicateCorrelation = ci.duplicateCorrelation;
            try
                if source < 3
                    phase = rf47lmsbtb.lms_continuous_phase(raw,source,window);
                else
                    v = bsxfun(@rdivide,raw,sqrt(mean(abs(raw(1:nt,:)).^2,1)));
                    fourth = v.^4;
                    delta = angle(sum(fourth(1:nt,2).*conj(fourth(1:nt,1))));
                    moment = conv(fourth(:,1)+fourth(:,2)*exp(-1i*delta), ...
                        ones(window,1)/window,'same');
                    phase = unwrap(angle(-moment))/4;
                end
                uncalibratedZ = bsxfun(@times,raw,exp(-1i*phase));
                z = rf47lmsbtb.btb_blind_levels(uncalibratedZ,nt);
                [~, target, mapping] = rf47lmsbtb.btb_reference_align(z,reference,nt);
                quality = [mapping{1}.correlation mapping{2}.correlation];
                trials(trial).correlation = quality;
                trials(trial).valid = all(isfinite(quality)) && all(isfinite(z(:)));
                if trials(trial).valid && min(quality) > best
                    best = min(quality);
                    selected = struct('o',o,'phase',phase,'target',target,'alignedBlind',z);
                    selectedMap = mapping; selectedCi = ci;
                    selectedSource = source; selectedWindow = window;
                end
            catch err
                % A failed blind candidate does not invalidate other starting angles.
                trials(trial).failure = err.message;
                if strcmp(err.message,'Insufficient four-cluster occupancy') && ...
                        all(isfinite(uncalibratedZ(:)))
                    % A distorted/duplicate CMA output can violate the affine
                    % four-cluster initializer without destroying the received
                    % information. Keep these observations, never ideal points.
                    [~, rawTarget, rawMap] = rf47lmsbtb.btb_reference_align( ...
                        uncalibratedZ,reference,nt);
                    rawQuality = [rawMap{1}.correlation rawMap{2}.correlation];
                    trials(trial).uncalibratedCorrelation = rawQuality;
                    if all(isfinite(rawQuality)) && all(isfinite(uncalibratedZ(:))) && ...
                            min(rawQuality) > uncalibratedBest
                        uncalibratedBest = min(rawQuality);
                        uncalibrated = struct('o',o,'phase',phase, ...
                            'target',rawTarget,'alignedBlind',uncalibratedZ);
                        uncalibratedMap = rawMap; uncalibratedCi = ci;
                        uncalibratedSource = source; uncalibratedWindow = window;
                    end
                end
            end
        end
    end
end
levelCalibrationUsed = true;
if ~isfinite(best) && isfinite(uncalibratedBest)
    % Never change candidate selection for records handled by the original
    % calibrated acquisition. The caller must still run the strict sync guard.
    selected = uncalibrated; selectedMap = uncalibratedMap;
    selectedCi = uncalibratedCi; selectedSource = uncalibratedSource;
    selectedWindow = uncalibratedWindow; best = uncalibratedBest;
    levelCalibrationUsed = false;
end
if ~isfinite(best)
    error('rf47_lms_btb_dsp:Acquisition','No finite four-cluster acquisition candidate was found.');
end
selected.mapping = selectedMap;
if isfield(front,'samplePositions'), front = rmfield(front,'samplePositions'); end
diagnostics = struct('correlation',[selectedMap{1}.correlation selectedMap{2}.correlation], ...
    'prefixSymbols',nt,'initialAngle',selected.o.initialAngle,'phaseSource',selectedSource, ...
    'phaseWindow',selectedWindow,'mapping',{selectedMap},'bootstrap',selectedCi, ...
    'front',front,'trials',trials,'cmaRuns',numel(angles),'selectionUsesTestLabels',false, ...
    'levelCalibrationUsed',levelCalibrationUsed);
end
