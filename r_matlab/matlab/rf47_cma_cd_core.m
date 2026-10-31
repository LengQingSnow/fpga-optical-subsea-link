function result = rf47_cma_cd_core(x, front, capture, reference)
%RF47_CMA_CD_CORE Page-5 isolated copy of the page-3 short blind CMA.
% Reference resolves prefix ambiguities only; it never trains FIR taps.
started=tic;
assert(size(capture.channels,1)>=1000000 && size(capture.channels,2)==4, ...
    'CMA-BTB requires a complete 1M x 4 capture');
assert(abs(capture.sampleRateHz-40e9)<1e6,'CMA-BTB requires 40 GSa/s');
assert(isequal(size(reference.laneBits),[262144 4]),'Long PRBS reference required');
o=struct('symbolRate',4e9,'maxCfoHz',1.4e9,'lowpassHz',2.8e9, ...
    'sampleOffset',0,'tapCount',15,'trainSymbols',29900, ...
    'cmaSteps',[.08 .04 .02 .01],'initialAngle',.4, ...
    'carrierNotchHz',2e6,'excludeDcHz',50e6);
% Front end and dispersion compensation are supplied by page 5.
index=(101:98000)'; center=2*index+4; U=complex(zeros(numel(index),30));
for j=1:15
    U(:,j)=x(center+j-8,1); U(:,15+j)=x(center+j-8,2);
end
% Retry only when prefix synchronization fails. Never select on test BER.
candidates=[.4 2; .8 2; .4 1; .8 1; 0 2; 1.2 2];
valid=false; lastFailure='';
for attempt=1:size(candidates,1)
    o.initialAngle=candidates(attempt,1);
    try
        [raw,weights,ci]=rf47lmsbtb.btb_cma(U,o);
        % This helper is blind fourth-moment phase recovery, not an LMS update.
        phase=rf47lmsbtb.lms_continuous_phase(raw,candidates(attempt,2),129);
        z=bsxfun(@times,raw,exp(-1i*phase));
        z=rf47lmsbtb.btb_blind_levels(z,o.trainSymbols);
        [p,t,mapping]=rf47lmsbtb.btb_reference_align(z,reference.laneBits,o.trainSymbols);
        assert(min([mapping{1}.correlation mapping{2}.correlation])>.8, ...
            'CMA reference synchronization failed; no BER counted');
        % Independent prefix sections must identify the same reference cycle.
        for first=[1 10001 20001]
            last=min(first+9999,o.trainSymbols);
            [~,~,part]=rf47lmsbtb.btb_reference_align(z(first:last,:),reference.laneBits,last-first+1);
            for pol=1:2
                assert(part{pol}.output==mapping{pol}.output && ...
                    part{pol}.conjugate==mapping{pol}.conjugate && ...
                    mod(part{pol}.shift-first+1,262144)==mapping{pol}.shift && ...
                    part{pol}.correlation>.8, 'Inconsistent prefix synchronization; no BER counted');
            end
        end
        valid=true;
        break;
    catch failure
        lastFailure=failure.message;
    end
end
assert(valid,['CMA acquisition failed after blind restarts: ' lastFailure]);
test=(60001:95000)'-100;
prediction=p(test,:); target=t(test,:);
v=[real(prediction(:,1)) imag(prediction(:,1)) real(prediction(:,2)) imag(prediction(:,2))];
d=[real(target(:,1)) imag(target(:,1)) real(target(:,2)) imag(target(:,2))];
errors=sum((v>=0)~=(d>=0),1); bits=repmat(numel(test),1,4);
mse=mean((v-d).^2,1); evm=sqrt([sum(mse(1:2)) sum(mse(3:4))]);
for pol=1:2, metrics(pol)=cma_constellation_metrics(prediction(:,pol)); end %#ok<AGROW>
result=struct('method','CMA-CD','filterDescription','2x2 complex FIR / 15 taps', ...
    'equalizedSymbols',prediction,'evmRms',evm,'referenceAligned',true, ...
    'iqCorrectionApplied',[true true],'converged',true, ...
    'frequencyOffsetHz',front.cfoHz,'sampleOffset',o.sampleOffset, ...
    'finalCost',ci.costs(end),'pointCount',size(capture.channels,1), ...
    'mapping',{mapping},'weights',weights,'options',o, ...
    'validity',struct('valid',true,'alignedMetrics',metrics,'reason','consistent prefix synchronization'), ...
    'metrics',struct('errorsByLane',errors,'bitsByLane',bits,'berByLane',errors./bits, ...
    'ber',sum(errors)/sum(bits),'mseByLane',mse), ...
    'prefixScore',min([mapping{1}.correlation mapping{2}.correlation]), ...
    'initializationAttempt',attempt,'phaseSource',candidates(attempt,2), ...
    'processingSeconds',toc(started));
end
