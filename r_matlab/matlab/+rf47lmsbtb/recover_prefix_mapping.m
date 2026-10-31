function [selected, info] = recover_prefix_mapping(capture, reference, bootstrap, projectionLags)
%RECOVER_PREFIX_MAPPING Resolve a weak polarization without duplicate CMA.
% A well-correlated CMA output supplies the common phase/strong reference.
% Search only the first 30000 samples of original received mixtures and
% their strong-reference residual. Never substitute reference for samples.
% The independent segment/global-target checks remain unchanged.
if nargin < 4, projectionLags = 0; end
validateattributes(projectionLags,{'numeric'}, ...
    {'vector','real','finite','integer','nonempty','>=',-3,'<=',3});
projectionLags = projectionLags(:).';
nt = 30000;
quality = [bootstrap.mapping{1}.correlation bootstrap.mapping{2}.correlation];
[strong_quality, strong] = max(quality);
info = struct('used',false,'strongPolarization',strong, ...
    'strongCorrelation',strong_quality,'candidateCorrelation',NaN(4,2), ...
    'candidateValid',false(4,1),'selectedMode',NaN,'selectedInput',NaN, ...
    'projectionLags',projectionLags);
selected = bootstrap;
if strong_quality < .4
    return;
end
[x,~] = rf47lmsbtb.btb_frontend(capture,bootstrap.o);
u = rf47lmsbtb.btb_taps(x,bootstrap.o.tapCount);
mid = (bootstrap.o.tapCount+1)/2;
mixture = bsxfun(@times,u(:,[mid mid+bootstrap.o.tapCount]), ...
    exp(-1i*bootstrap.phase));
clear x u;
choice = bootstrap.mapping{strong};
observed = bootstrap.alignedBlind(:,choice.output);
if choice.conjugate, observed = conj(observed); end
observed = observed/choice.gain;
signs = 2*double(reference)-1;
ideal = [signs(:,1)+1i*signs(:,2),signs(:,3)+1i*signs(:,4)]/sqrt(2);
period = size(ideal,1);
% The blind FIR output can lag the original mixtures by an integer symbol.
% A bounded prefix-only delayed projection removes the same strong source
% despite this group delay; it does not change any target or test samples.
known = complex(zeros(nt,numel(projectionLags)));
for lagIndex = 1:numel(projectionLags)
    known(:,lagIndex) = ideal(mod((0:nt-1)' + choice.shift + ...
        projectionLags(lagIndex),period)+1,strong);
end
design = [known conj(known) ones(nt,1)];
residual = mixture(1:nt,:) - design*(design\mixture(1:nt,:));
count = size(mixture,1);
best = -Inf;
for mode = 1:2
    for input = 1:2
        index = (mode-1)*2+input;
        if mode==1, weak=mixture(1:nt,input); else, weak=residual(:,input); end
        z = [weak observed(1:nt)];
        [~,~,mapping] = rf47lmsbtb.btb_reference_align(z,reference,nt);
        target = complex(zeros(count,2));
        for polarization = 1:2
            target(:,polarization) = ideal( ...
                mod((0:count-1)'+mapping{polarization}.shift,period)+1,polarization);
        end
        candidate = struct('o',bootstrap.o,'phase',bootstrap.phase, ...
            'target',target,'mapping',{mapping},'alignedBlind',z);
        guard = rf47lmsbtb.check_sync(candidate,reference);
        q = [mapping{1}.correlation mapping{2}.correlation];
        info.candidateCorrelation(index,:) = q;
        info.candidateValid(index) = guard.consistent;
        if guard.consistent && min(q)>best
            best=min(q); selected=candidate;
            info.used=true;info.selectedMode=mode;info.selectedInput=input;
        end
    end
end
end
