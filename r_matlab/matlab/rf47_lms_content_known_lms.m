function result=rf47_lms_content_known_lms(capture,training,q)
%RF47_LMS_CONTENT_KNOWN_LMS Page-7 whitening/NLMS with sparse known targets.
% TRAINING uses a one-symbol grid from btb_frontend(x(1:2:end,:)).
% target is N-by-4 real levels; knownMask marks confirmed training symbols.
% Unknown payload, header and CRC positions must NOT be marked known.
% The page-7 package is read-only. No replay template is periodically tiled.
o=training.options; o.tapCount=q.tapCount; o.lowpassHz=q.lowpassHz;
[x,front]=rf47lmsbtb.btb_frontend(capture,o);
[u,centers]=rf47lmsbtb.btb_taps(x,q.tapCount);
index=(centers+1)/2;
assert(all(index==round(index)),'Tap count must be 1 modulo 4.');
assert(max(index)<=size(training.target,1) && max(index)<=numel(training.phase), ...
    'Known target/phase grid does not cover this capture.');
target=training.target(index,:);
known=training.knownMask(index) & all(isfinite(target),2);
train=find(known & index<=q.trainSymbols);
cal=find(known & index>=50001 & index<=59000);
test=find(known & index>=61061);
assert(numel(train)>=max(1000,4*q.tapCount),'Too few confirmed training symbols.');
u=bsxfun(@times,u,exp(-1i*training.phase(index)));
A=[real(u) imag(u) ones(size(u,1),1)]; clear u;
B=A(train,:); R=B'*B/numel(train);
[V,D]=eig((R+R')/2); d=real(diag(D));
P=V*diag(1./sqrt(max(d,max(d)*q.floor)))*V';clear R V D;
B=B*P; W=zeros(size(B,2),4);norms=sum(B.^2,2)+1e-8;
steps=[.3 .15 .08 .04 .02 .01];trainMse=zeros(numel(steps),4);
for pass=1:numel(steps)
    Wsum=zeros(size(W)); count=0;
    for k=1:numel(train)
        row=B(k,:);err=target(train(k),:)-row*W;
        W=W+steps(pass)/norms(k)*(row'*err);
        if pass==numel(steps) && k>floor(numel(train)/3)
            Wsum=Wsum+W;count=count+1;
        end
    end
    if count>0,W=Wsum/count;end
    trainMse(pass,:)=mean((B*W-target(train,:)).^2,1);
end
weights=P*W; clear B P;
output=A*weights;
calBer=mean((output(cal,:)>=0)~=(target(cal,:)>=0),1);
testBer=mean((output(test,:)>=0)~=(target(test,:)>=0),1);
result=struct('soft',output,'bits',output>=0,'symbolIndex',index, ...
    'weights',weights,'calibrationMismatchByLane',calBer, ...
    'heldoutIdleMismatchByLane',testBer,'trainingSymbols',numel(train), ...
    'trainingMse',trainMse,'options',q,'front',front, ...
    'method','LMS-BTB core / received PRBS31 known targets', ...
    'usedReplayReference',false,'usedDatasetForTraining',false,'trainedOnCrc',false);
end
