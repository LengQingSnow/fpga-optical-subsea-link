function [phase, diagnostics] = track_template_phase(capture, bootstrap, selected)
%TRACK_TEMPLATE_PHASE Select and run the prefix-trained four-center PLL.
% BOOTSTRAP is the original rf47lmsbtb.acquire result, before weak-reference
% recovery. SELECTED contains the guarded target returned by acquire or
% recover_prefix_mapping. The original bootstrap mapping selects the strong
% blind CMA output; the guarded target supplies only its first 30000 labels.
%
% Centers/normalization: 1:15000. Scalar scoring gain: 1001:15000.
% PLL gain validation: 16001:30000. No reference labels after 30000 are read.
% All 30 candidates use only the first 30000 observations. The selected PLL
% then processes the full observation with current-sample decisions only.
% The caller assigns PHASE to selected.phase before fit_channel_lms.
% Pure computation: no hardware, files, plotting, global paths or caches.

nt = 15000; selectionCount = 30000; validation = (16001:30000)';
if ~isstruct(bootstrap) || ~isfield(bootstrap,'o') || ...
        ~isfield(bootstrap,'mapping') || numel(bootstrap.mapping) ~= 2 || ...
        ~isfield(bootstrap,'phase') || numel(bootstrap.phase) < selectionCount || ...
        ~isstruct(selected) || ~isfield(selected,'target') || ...
        size(selected.target,1) < selectionCount || size(selected.target,2) ~= 2
    error('rf47lmsbtb:TrackerInputs','Complete bootstrap mapping and a guarded dual-polarization target are required.');
end
quality = [bootstrap.mapping{1}.correlation bootstrap.mapping{2}.correlation];
if any(~isfinite(quality))
    error('rf47lmsbtb:TrackerMapping','The bootstrap correlations must be finite.');
end
[~,strong] = max(quality); choice = bootstrap.mapping{strong};
if ~any(choice.output == [1 2])
    error('rf47lmsbtb:TrackerOutput','The selected blind output must be one or two.');
end
% Recreate exactly the selected blind output, without retaining CMA weights.
[x,~] = rf47lmsbtb.btb_frontend(capture,bootstrap.o);
u = rf47lmsbtb.btb_taps(x,bootstrap.o.tapCount); clear x;
[raw,~,ci] = rf47lmsbtb.btb_cma(u,bootstrap.o); clear u;
source = raw(:,choice.output); clear raw;
if numel(source) <= selectionCount || numel(source) ~= numel(bootstrap.phase)
    error('rf47lmsbtb:TrackerLength','The blind observations must match the bootstrap phase record.');
end
expected = selected.target(1:selectionCount,strong);
if choice.conjugate, expected=conj(expected); end
training = expected(1:nt); initial = bootstrap.phase(1:nt);
best = Inf; bestOption = []; selectedIndex = 0;
trials = zeros(30,6); trial = 0; fit = (1001:nt)';
for kp = [.003 .006 .012 .024 .048]
    for ratio = [10 40 160]
        ki = kp^2/ratio;
        for weight = [false true]
            trialPhase = rf47lmsbtb.template_phase( ...
                source(1:selectionCount),training,initial,kp,ki,weight);
            corrected = source(1:selectionCount).*exp(-1i*trialPhase);
            gain = sum(conj(expected(fit)).*corrected(fit))/numel(fit);
            score = mean(abs(corrected(validation)/gain-expected(validation)).^2);
            correlation = abs(sum(conj(expected(validation)).*corrected(validation)))/ ...
                sqrt(numel(validation)*sum(abs(corrected(validation)).^2));
            trial = trial+1;
            trials(trial,:) = [kp ki weight score correlation trial];
            if isfinite(score) && score < best
                best = score; bestOption = [kp ki weight]; selectedIndex = trial;
            end
        end
    end
end
if isempty(bestOption)
    error('rf47lmsbtb:TrackerSelection','No finite prefix-validation carrier candidate was found.');
end
[phase,diagnostics] = rf47lmsbtb.template_phase(source,training,initial, ...
    bestOption(1),bestOption(2),logical(bestOption(3)));
diagnostics.method = 'prefix-trained four-center causal PLL';
diagnostics.strongPolarization = strong;
diagnostics.sourceOutput = choice.output;
diagnostics.sourceConjugate = choice.conjugate;
diagnostics.sourceCorrelation = quality(strong);
diagnostics.validationSymbols = [16001 30000];
diagnostics.gainFitSymbols = [1001 nt];
diagnostics.prefixValidationMse = best;
diagnostics.selectedIndex = selectedIndex;
diagnostics.candidateCount = trial;
diagnostics.trials = trials;
diagnostics.trialColumns = {'kp','ki','amplitudeWeight','validationMse','validationCorrelation','index'};
diagnostics.bootstrap = ci;
diagnostics.usesHoldoutReference = false;
end
