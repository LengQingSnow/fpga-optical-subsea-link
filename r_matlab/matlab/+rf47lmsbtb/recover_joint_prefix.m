function [selected, info] = recover_joint_prefix(capture,reference,bootstrap)
%RECOVER_JOINT_PREFIX Strict cross-fitted mapping, with a short-memory backup.
% Preserve the original four-real-center-input solution whenever it passes.
% Only after its unchanged guard fails, add the adjacent half-symbol taps.
% The fixed backup has 12 real features, not a long reference-memorizing FIR.
[selected,info]=recover_once(capture,reference,bootstrap,0);
if info.used || ~isfield(info,'bestCrossFitCorrelation')
    return;
end
memoryless=struct('bestCrossFitCorrelation',info.bestCrossFitCorrelation, ...
    'selectedWeakShift',info.selectedWeakShift,'failureReason',info.failureReason);
if isfield(info,'guard'),memoryless.guard=info.guard;end
[selected,info]=recover_once(capture,reference,bootstrap,-1:1);
info.tapOffsets=-1:1;
info.memoryBackupUsed=info.used;
info.memorylessAttempt=memoryless;
end

function [selected, info] = recover_once(capture,reference,bootstrap,tapOffsets)
%RECOVER_ONCE Fixed-dimensional, cross-fitted observation synchronizer.
% Only 30000 prefix observations/labels. Each 10000-output block is formed by
% a regression fitted on the other two blocks, never itself.
nt=30000;ridge=1e-3;
quality=[bootstrap.mapping{1}.correlation bootstrap.mapping{2}.correlation];
[strongQuality,strong]=max(quality);weak=3-strong;
selected=bootstrap;
info=struct('used',false,'strongPolarization',strong,'strongCorrelation',strongQuality, ...
    'ridge',ridge,'realFeatureCount',4*numel(tapOffsets),'usesHoldoutReference',false,'prefixSymbols',nt, ...
    'failureReason','');
if ~isfinite(strongQuality) || strongQuality<.4
    info.failureReason='No finite sufficiently correlated strong source.';return;
end
[x,~]=rf47lmsbtb.btb_frontend(capture,bootstrap.o);u=rf47lmsbtb.btb_taps(x,bootstrap.o.tapCount);clear x;
mid=(bootstrap.o.tapCount+1)/2;
mixture=bsxfun(@times,u(:,[mid+tapOffsets mid+bootstrap.o.tapCount+tapOffsets]),exp(-1i*bootstrap.phase));clear u;
features=[real(mixture(1:nt,:)) imag(mixture(1:nt,:))];
count=size(mixture,1);clear mixture;
if any(~isfinite(features(:)))
    info.failureReason='Nonfinite prefix mixture features.';return;
end
choice=bootstrap.mapping{strong};observed=bootstrap.alignedBlind(:,choice.output);
if choice.conjugate,observed=conj(observed);end
observed=observed/choice.gain;
signs=2*double(reference)-1;
ideal=[signs(:,1)+1i*signs(:,2),signs(:,3)+1i*signs(:,4)]/sqrt(2);period=size(ideal,1);
fit=cell(3,1);test=cell(3,1);fitIndex=cell(3,1);testIndex=cell(3,1);solver=cell(3,1);
for fold=1:3
    testIndex{fold}=((fold-1)*10000+1:fold*10000)';
    fitIndex{fold}=setdiff((1:nt)',testIndex{fold});
    mu=mean(features(fitIndex{fold},:),1);scale=std(features(fitIndex{fold},:),0,1);
    if any(~isfinite(scale)) || any(scale<=0)
        info.failureReason='Degenerate prefix mixture features.';return;
    end
    fit{fold}=[bsxfun(@rdivide,bsxfun(@minus,features(fitIndex{fold},:),mu),scale) ones(20000,1)];
    test{fold}=[bsxfun(@rdivide,bsxfun(@minus,features(testIndex{fold},:),mu),scale) ones(10000,1)];
    R=fit{fold}'*fit{fold}/20000;
    solver{fold}=(R+ridge*trace(R)/size(R,1)*eye(size(R)))\(fit{fold}'/20000);
end
scores=NaN(period,4);best=-Inf;bestObservation=[];bestShift=NaN;
for shift=0:period-1
    target=ideal(mod((0:nt-1)'+shift,period)+1,weak);
    output=complex(zeros(nt,1));foldQuality=zeros(1,3);
    for fold=1:3
        coefficient=solver{fold}*target(fitIndex{fold});
        output(testIndex{fold})=test{fold}*coefficient;
        a=output(testIndex{fold});t=target(testIndex{fold});
        foldQuality(fold)=abs(t'*a)/sqrt(sum(abs(t).^2)*sum(abs(a).^2));
    end
    scores(shift+1,:)=[shift foldQuality];
    if all(isfinite(foldQuality))
        score=min(foldQuality);
        if score>best,best=score;bestShift=shift;bestObservation=output;end
    end
end
info.shiftCorrelations=scores;info.bestCrossFitCorrelation=best;info.selectedWeakShift=bestShift;
if ~isfinite(best) || isempty(bestObservation)
    info.failureReason='No finite cross-fitted shift candidate.';return;
end
% The unchanged aligner rediscovers the shift on each held-out block. These
% blocks also rank shifts: this is cross-fitted consistency checking, not a
% second dataset independent of shift selection.
z=[bestObservation observed(1:nt)];
[~,~,mapping]=rf47lmsbtb.btb_reference_align(z,reference,nt);
target=complex(zeros(count,2));
for pol=1:2
    target(:,pol)=ideal(mod((0:count-1)'+mapping{pol}.shift,period)+1,pol);
end
candidate=struct('o',bootstrap.o,'phase',bootstrap.phase,'target',target, ...
    'mapping',{mapping},'alignedBlind',z);
guard=rf47lmsbtb.check_sync(candidate,reference);info.guard=guard;
if guard.consistent && guard.globalShift(weak)==bestShift
    selected=candidate;info.used=true;
else
    info.failureReason='Cross-fitted candidate failed the unchanged synchronization guard.';
end
end
