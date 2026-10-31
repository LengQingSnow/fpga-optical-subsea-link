function [lane_bits,bytes,recovery,packing] = rf47_cma_cd_content_core(capture,cfg)
%RF47_CMA_CD_CONTENT_CORE Isolated page 6: page-5 front end/CD/short CMA,
% followed by the verified information frame/CRC recovery from page 4.
% No replay reference, ideal-symbol substitution or CRC repair. Residual FIR
% uses labels exclusively from already CRC-verified received frames.
started=tic;
assert(size(capture.channels,2)==4 && size(capture.channels,1)>=100000, ...
    'Four simultaneous optical channels are required');
assert(abs(capture.sampleRateHz-40e9)<1e6,'Expected 40 GSa/s optical record');
o=struct('symbolRate',4e9,'maxCfoHz',1.4e9,'lowpassHz',2.8e9, ...
    'sampleOffset',0,'tapCount',15,'trainSymbols',29900, ...
    'cmaSteps',[.08 .04 .02 .01],'initialAngle',.4, ...
    'carrierNotchHz',2e6,'excludeDcHz',50e6);
if isfield(cfg,'cmaContentNotchHz'), o.carrierNotchHz=cfg.cmaContentNotchHz; end
if isfield(cfg,'cmaContentSteps'), o.cmaSteps=cfg.cmaContentSteps; end
if isfield(cfg,'cmaCdCfoHz'),o.cfoHz=cfg.cmaCdCfoHz;end
[x,front]=rf47lmsbtb.btb_frontend(capture,o);
if ~isfield(front,'cfoPeakToMedian'),front.cfoPeakToMedian=NaN;end
x=rf47_cma_cd_filter(x,8e9,cfg.cmaCdDispersionPsNm,cfg.cmaCdWavelengthNm);
assert(all(isfinite(x(:))),'Non-finite samples after optical front end');
fprintf('CMA_INFO_FRONT CFO=%g peak=%g std=%s\n',front.cfoHz,front.cfoPeakToMedian,mat2str(front.rawStd,4));
last=min(98000,floor((size(x,1)-12)/2)); index=(101:last)';
o.trainSymbols=min(29900,numel(index)); center=2*index+4;
u=complex(zeros(numel(index),30));
for j=1:15, u(:,j)=x(center+j-8,1); u(:,15+j)=x(center+j-8,2); end
best=-1; lastFailure=''; poolSequence=zeros(0,1,'uint32');poolBytes=zeros(512,0,'uint8');
parserCfg=cfg; parserCfg.useBadCrcSegments=false;
refineEnabled=~isfield(cfg,'cmaContentCrcFir')||cfg.cmaContentCrcFir;
refinementAdded=0;
angles=[.4 .8 4 5:11];
% Retry a verified weight matrix from this same scope record first. A failed
% retry still falls through to every original blind initialization.
if isfield(cfg,'cmaContentWarmWeights'),angles=[-1 angles];end
for angle=angles
    o.initialAngle=angle;
    if angle==-1
        weights=cfg.cmaContentWarmWeights;
        assert(isequal(size(weights),[30 2])&&all(isfinite(weights(:))),'Invalid capture-local CMA weights');
        raw=u*weights;a=raw(:,1);b=raw(:,2);
        rho=max(abs(sum(conj(a).*b)),abs(sum(a.*b)))/sqrt(sum(abs(a).^2)*sum(abs(b).^2));
        ci=struct('duplicateCorrelation',rho,'captureLocalReuse',true);
    elseif angle<4
        [raw,weights,ci]=rf47lmsbtb.btb_cma(u,o);
    else
        [raw,weights,ci]=decorrelated_cma(u,o,angle-4);
    end
    fprintf('CMA_INFO_INIT angle=%g duplicate=%g\n',angle,ci.duplicateCorrelation);
    if ~isfinite(ci.duplicateCorrelation) || ci.duplicateCorrelation>.8, continue; end
    seedBest=-1;seedSymbols=[];seedBytes=[];
    for source=[2 1]
        for window=[129 257 513 1025]
            try
                phase=rf47lmsbtb.lms_continuous_phase(raw,source,window);
                z=bsxfun(@times,raw,exp(-1i*phase));
                z=rf47lmsbtb.btb_blind_levels(z,o.trainSymbols);
                bits=[real(z(:,1))>=0 imag(z(:,1))>=0 real(z(:,2))>=0 imag(z(:,2))>=0];
                [candidate,pack]=rf47_lms_content_pack(bits,cfg);
                frames=parse_aggregate_frames_relocked(candidate,parserCfg);
                good=sum(frames.crcOk);
                if good>seedBest,seedBest=good;seedSymbols=z;seedBytes=candidate;end
                for fi=find(frames.crcOk(:))'
                    where=find(poolSequence==frames.sequence(fi),1);
                    if isempty(where)
                        poolSequence(end+1,1)=frames.sequence(fi);poolBytes(:,end+1)=frames.bytes(:,fi);
                    else
                        assert(isequal(poolBytes(:,where),frames.bytes(:,fi)), ...
                            'Conflicting CRC-valid bytes for one aggregate sequence');
                    end
                end
                fprintf('CMA_INFO angle=%g source=%d win=%d frames=%d good=%d sync=%s\n', ...
                    angle,source,window,frames.frameCount,good,mat2str(pack.laneSyncErrorRates,3));
                if good>best
                    best=good; lane_bits=bits; bytes=candidate; packing=pack;
                    recovery=struct('method','CMA information','crcGoodFrames',good, ...
                        'frameCount',frames.frameCount,'frequencyOffsetHz',front.cfoHz, ...
                        'equalizedSymbols',z,'weights',weights,'options',o, ...
                        'phaseSource',source,'phaseWindow',window,'cma',ci);
                end
            catch ex, lastFailure=ex.message; end
        end
    end
    if refineEnabled&&seedBest>=4
        [refined,refinementInfo]=rf47_cma_content_crc_fir(seedSymbols,seedBytes,cfg);
        refinedFrames=parse_aggregate_frames_relocked(refined,parserCfg);
        for fi=find(refinedFrames.crcOk(:))'
            where=find(poolSequence==refinedFrames.sequence(fi),1);
            if isempty(where)
                poolSequence(end+1,1)=refinedFrames.sequence(fi);poolBytes(:,end+1)=refinedFrames.bytes(:,fi);
                refinementAdded=refinementAdded+1;
            else
                assert(isequal(poolBytes(:,where),refinedFrames.bytes(:,fi)),'Conflicting CRC-valid refinement');
            end
        end
        fprintf('CMA_INFO_REFINE angle=%g added=%d seconds=%g\n',angle,refinementInfo.addedFrames,refinementInfo.seconds);
    end
    if best>10
        candidateFrames=parse_aggregate_frames_relocked(bytes,parserCfg);
        if rf47_cma_content_search_complete(candidateFrames,poolSequence,numel(bytes),cfg.frameBytes)
            break;
        end
    end
end

assert(best>0,['No CRC-valid CMA information frame. ' lastFailure]);
% Fuse complete CRC-verified frames only. Never vote, repair or synthesize bits.
base=parse_aggregate_frames_relocked(bytes,parserCfg); combined=base.bytes; seq=base.sequence;
for k=1:numel(poolSequence)
    where=find(seq==poolSequence(k),1);
    if isempty(where),seq(end+1,1)=poolSequence(k);combined(:,end+1)=poolBytes(:,k);
    else,combined(:,where)=poolBytes(:,k);end
end
relative=mod(double(seq)-double(poolSequence(1))+2^31,2^32)-2^31;
[~,order]=sort(relative);combined=combined(:,order);bytes=combined(:);
recovery.crcFir=struct('addedFrames',refinementAdded,'baselineMemory',true);
fused=parse_aggregate_frames_relocked(bytes,parserCfg);
recovery.crcGoodFrames=sum(fused.crcOk);recovery.frameCount=fused.frameCount;
recovery.crcCandidateFusion=true;
recovery.dispersionPsNm=cfg.cmaCdDispersionPsNm;
recovery.wavelengthNm=cfg.cmaCdWavelengthNm;
recovery.method='CMA + CD information';
recovery.processingSeconds=toc(started);
end

function [y,w,info]=decorrelated_cma(u,o,seed)
% Blind complex unitary restarts, with cross-output decorrelation penalty.
oldRng=rng; restore=onCleanup(@() rng(oldRng)); rng(1931+seed);
[init,~]=qr(randn(2)+1i*randn(2));
L=size(u,2)/2; mid=(L+1)/2; w=complex(zeros(2*L,2)); w([mid mid+L],:)=init;
nt=o.trainSymbols; C=eye(2); norms=sum(abs(u(1:nt,:)).^2,2)+1e-8; costs=[];
for step=o.cmaSteps
    for k=1:nt
        row=u(k,:); z=row*w;
        if any(~isfinite(z))
            y=complex(nan(size(u,1),2)); info=struct('duplicateCorrelation',NaN); return;
        end
        bounded=z./max(1,abs(z)/2);
        C=.999*C+.001*(bounded'*bounded);
        e=z.*(1-abs(z).^2)-.1*z*(C-diag(diag(C)));
        e=e./max(1,abs(e)/2);
        w=w+step/norms(k)*(row'*e);
    end
    z=u(1:nt,:)*w; costs(end+1)=mean(mean((abs(z).^2-1).^2)); %#ok<AGROW>
end
y=u*w; a=y(1:nt,1); b=y(1:nt,2);
rho=max(abs(sum(conj(a).*b)),abs(sum(a.*b)))/sqrt(sum(abs(a).^2)*sum(abs(b).^2));
info=struct('costs',costs,'duplicateCorrelation',rho,'weightNorm',sqrt(sum(abs(w).^2,1)));
end
