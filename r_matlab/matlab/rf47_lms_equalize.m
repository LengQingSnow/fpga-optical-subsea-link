function result = rf47_lms_equalize(capture, reference, options)
%RF47_LMS_EQUALIZE 171-tap 4-real FSE, continuous phase and leave-one-out CPR.
% Replay: prefix-only reference training, independent suffix BER.
% Live: blind acquisition followed by decision-trained LMS; NO replay target.
% No acquisition, JTAG, GUI, persistent training cache or packet edits here.
if nargin < 2, reference = []; end
if nargin < 3, options = struct(); end
mode = option(options, 'mode', 'replay');
is_replay = strcmp(mode, 'replay');
if ~is_replay && ~strcmp(mode, 'live')
    error('rf47_lms_equalize:Mode', 'Expected replay or live mode.');
end
if ~is_replay && ~isempty(reference)
    error('rf47_lms_equalize:LiveReference', ...
        'Live payload must not be trained against a replay reference.');
end
if is_replay
    if ~isstruct(reference) || ~isfield(reference,'laneBits') || ...
            size(reference.laneBits,2) ~= 4 || size(reference.laneBits,1)<32
        error('rf47_lms_equalize:Reference','Four current replay lanes required.');
    end
end
rs = option(options,'symbolRateHz',4e9);
validateattributes(capture.sampleRateHz,{'numeric'},{'scalar','finite','positive'});
validateattributes(capture.channels,{'numeric'},{'2d','finite','nonempty'});
if size(capture.channels,2)~=4 || capture.sampleRateHz < 2*rs
    error('rf47_lms_equalize:Capture','Need XI/XQ/YI/YQ at >=2 samples/symbol.');
end
symbols = floor(size(capture.channels,1)*rs/capture.sampleRateHz);
if symbols < 10000
    error('rf47_lms_equalize:ShortCapture','At least 10000 DP symbols required.');
end
train = min(45000,floor(.45*symbols));
acquire_train = min(30000,train);
o = struct('symbolRate',rs,'tapCount',11,'lowpassHz',2.8e9, ...
    'sampleOffset',0,'carrierNotchHz',2e6,'maxCfoHz',min(1.4e9, ...
    .12*capture.sampleRateHz),'initialAngle',0,'trainSymbols',acquire_train, ...
    'cmaSteps',[.08 .04 .02 .01],'phaseWindow',641,'fineCfoRangeHz',15e6);
o.sampleOffset = option(options,'sampleOffset',0);
[x,front] = rf47_lms_frontend(capture,o);
u = rf47_lms_taps(x,11); clear x;
[raw,~,bootstrap] = rf47_lms_bootstrap(u,o); clear u;
mapping = {}; correlation = [NaN NaN];
if is_replay
    z = rf47_lms_carrier(raw,rs,o);
    z = rf47_lms_blind_levels(z,acquire_train);
    [~,target,mapping] = rf47_lms_reference_align(z, ...
        reference.laneBits,acquire_train);
    correlation = [mapping{1}.correlation mapping{2}.correlation];
    [~,strong] = max(correlation); phase_output = mapping{strong}.output;
    if min(correlation)<.55 || bootstrap.duplicateCorrelation>.95
        error('rf47_lms_equalize:ReferenceSync', ...
            'Replay reference not locked: correlations %.3f/%.3f. Check current reference and signal.', ...
            correlation(1),correlation(2));
    end
else
    q = raw(1:acquire_train,:).^4 ./ max(abs(raw(1:acquire_train,:)).^4,1e-8);
    coherence = mean(abs([conv(q(:,1),ones(65,1)/65,'same'), ...
        conv(q(:,2),ones(65,1)/65,'same')]),1);
    [~,phase_output] = max(coherence);
end
phase = rf47_lms_continuous_phase(raw,phase_output,65);
if ~is_replay
    z = bsxfun(@times,raw,exp(-1i*phase));
    for p=1:2
        prefix=z(1:acquire_train,p);
        theta=angle(-mean(prefix.^4./max(abs(prefix).^4,1e-8)))/4;
        z(:,p)=z(:,p)*exp(-1i*theta);
    end
    z = rf47_lms_blind_levels(z,acquire_train);
    if bootstrap.duplicateCorrelation>.95
        error('rf47_lms_equalize:Duplicate','Blind acquisition found duplicate polarizations.');
    end
    % Pseudo-labels are local decisions, not the RF47 replay sequence.
    target = ((2*(real(z)>=0)-1)+1i*(2*(imag(z)>=0)-1))/sqrt(2);
end
clear raw z;
o.lowpassHz=3.9e9; o.tapCount=171;
% Keep the independently estimated CFO identical for both front-end passes.
o.cfoHz=front.cfoHz;
[x,~]=rf47_lms_frontend(capture,o);
u=rf47_lms_taps(x,o.tapCount); clear x;
offset=(o.tapCount-11)/4;
N=size(u,1); index=(1:N)'+offset;
target=target(index,:); nt=train-offset;
u=bsxfun(@times,u,exp(-1i*phase(index))); clear phase;
ur=[real(u) imag(u) ones(N,1)]; clear u;
t=[real(target(:,1)) imag(target(:,1)) real(target(:,2)) imag(target(:,2))];
R=ur(1:nt,:)'*ur(1:nt,:)/nt;
[V,D]=eig((R+R')/2); d=real(diag(D));
P=V*diag(1./sqrt(max(d,max(d)*1e-4)))*V';
uw=ur*P; clear ur R V D P;
W=zeros(size(uw,2),4); norms=sum(uw.^2,2)+1e-8;
steps=[.3 .15 .08 .04 .02 .01];
for pass=1:numel(steps)
    Wsum=zeros(size(W)); count=0;
    for k=1:nt
        row=uw(k,:); e=t(k,:)-row*W;
        W=W+steps(pass)/norms(k)*(row'*e);
        if pass==numel(steps) && k>floor(nt/3)
            Wsum=Wsum+W; count=count+1;
        end
    end
    if count>0, W=Wsum/count; end
end
v=uw*W; clear uw W norms;
raw=[v(:,1)+1i*v(:,2) v(:,3)+1i*v(:,4)]; clear v;
z=rf47_lms_cpr(raw,target,nt,11,'independent_loo');
% Fixed guards exclude training influence and finite-filter/phase edges.
% All remaining replay symbols count, including bad windows. No CRC filter.
if is_replay, keep=(nt+1025:N-1024)'; else, keep=(129:N-128)'; end
z=z(keep,:); desired=target(keep,:);
if isempty(z), error('rf47_lms_equalize:NoHoldout','No evaluation suffix remains.'); end
if any(~isfinite(z(:))), error('rf47_lms_equalize:Finite','LMS output is nonfinite.'); end
metrics(1)=cma_constellation_metrics(z(:,1));
metrics(2)=cma_constellation_metrics(z(:,2));
validity=struct('valid',true,'validByPolarization',[metrics.valid], ...
    'alignedMetrics',metrics,'reason','');
if ~is_replay
    validity.valid=all([metrics.valid]);
    if ~validity.valid, validity.reason='Decision-trained LMS has a collapsed constellation.'; end
end
result=struct('equalizedSymbols',z,'frequencyOffsetHz',[front.cfoHz front.cfoHz], ...
    'sampleOffset',o.sampleOffset,'pointCount',size(capture.channels,1), ...
    'iqCorrectionApplied',[false false],'converged',validity.valid, ...
    'referenceAligned',is_replay,'referenceRefinement',[], ...
    'validity',validity,'method','LMS-FSE 171','dspName','LMS-FSE 171', ...
    'trainingSymbols',nt,'symbolOffset',offset,'outputSymbolIndices',index(keep), ...
    'phaseOutput',phase_output,'bootstrap',bootstrap,'referenceCorrelation',correlation, ...
    'referenceMapping',{mapping},'mode',mode);
if is_replay
    actual=[real(z(:,1))>=0 imag(z(:,1))>=0 real(z(:,2))>=0 imag(z(:,2))>=0];
    expected=[real(desired(:,1))>=0 imag(desired(:,1))>=0 ...
        real(desired(:,2))>=0 imag(desired(:,2))>=0];
    errors=sum(actual~=expected,1); bits=size(z,1)*ones(1,4);
    result.evmRms=sqrt(mean(abs(z-desired).^2,1)./mean(abs(desired).^2,1));
    result.errorBitsByLane=errors; result.comparedBitsByLane=bits;
    result.berByLane=errors./bits; result.ber=sum(errors)/sum(bits);
    result.desiredSymbols=desired;
    result.referenceRefinement=struct('errorBitsByLane',errors,'comparedBitsByLane',bits, ...
        'berByLane',result.berByLane,'ber',result.ber,'evmRms',result.evmRms);
else
    decisions=((2*(real(z)>=0)-1)+1i*(2*(imag(z)>=0)-1))/sqrt(2);
    result.evmRms=sqrt(mean(abs(z-decisions).^2,1));
    result.evmIsDecisionDirected=true;
    result.method='DD-LMS-FSE 171'; result.dspName=result.method;
end
result.finalCost=mean(result.evmRms.^2);
end

function v=option(s,name,default)
if isfield(s,name) && ~isempty(s.(name)), v=s.(name); else, v=default; end
end
