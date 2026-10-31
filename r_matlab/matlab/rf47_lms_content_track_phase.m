function [phase,info]=rf47_lms_content_track_phase(capture,training)
%RF47_LMS_CONTENT_TRACK_PHASE LMS-BTB centroid PLL with masked PRBS labels.
% Unknown payload labels are not fabricated. Only received known idle labels
% before symbol 30000 fit/choose the PLL. Afterwards tracking is decision-only.
o=training.options;o.tapCount=17;o.initialAngle=0;o.trainSymbols=30000;
o.cmaSteps=[.08 .04 .02 .01];[x,~]=rf47lmsbtb.btb_frontend(capture,o);
[u,c]=rf47lmsbtb.btb_taps(x,17);[raw,~,~]=rf47lmsbtb.btb_cma(u,o);clear u;
index=(c+1)/2;initial=training.phase(index);
known=training.knownMask(index);T=training.target(index,:);
fit=find(known & index>=1000 & index<15000);check=find(known & index>=16000 & index<30000);
assert(numel(fit)>1000 && numel(check)>1000,'Not enough known PRBS for carrier selection');
best=Inf;phase=training.phase;info=struct('used',false);n=min(30000,numel(index));
for source=1:2
    data=raw(:,source);data=data/sqrt(mean(abs(data(fit)).^2));
    obs=data(fit).*exp(-1i*initial(fit));
    for pol=1:2
        labels=1+(T(:,2*pol-1)>=0)+2*(T(:,2*pol)>=0);centers=zeros(4,1);
        for k=1:4,centers(k)=mean(obs(labels(fit)==k));end
        if any(~isfinite(centers)) || min(abs(centers))<.05,continue;end
        for kp=[.003 .012 .048]
            ki=kp^2/40;
            trial=track(data(1:n),initial(1:n),centers,kp,ki);
            q=data(check).*exp(-1i*trial(check));score=mean(abs(q-centers(labels(check))).^2);
            if score<best
                best=score;chosen=struct('source',source,'pol',pol,'centers',centers,'kp',kp,'ki',ki,'data',data);
            end
        end
    end
end
if ~isfinite(best),return;end
p=track(chosen.data,initial,chosen.centers,chosen.kp,chosen.ki);
phase(index)=p;phase(1:index(1)-1)=p(1);phase(index(end)+1:end)=p(end);
info=rmfield(chosen,'data');info.used=true;info.validationMse=best;
end
function phase=track(raw,initial,centers,kp,ki)
N=numel(raw);warm=512;phase=zeros(N,1);phase(1:warm)=initial(1:warm);
line=polyfit((129:warm)',initial(129:warm),1);frequency=line(1);
for k=warm+1:N
    predicted=phase(k-1)+frequency;z=raw(k)*exp(-1i*predicted);
    [~,j]=min(abs(z-centers).^2);err=angle(z*conj(centers(j)));
    frequency=frequency+ki*err;phase(k)=predicted+kp*err;
end
end
