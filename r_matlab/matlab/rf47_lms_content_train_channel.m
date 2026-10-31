function [result,model]=rf47_lms_content_train_channel(cap,s,q)
% Isolated LMS-BTB helper, copied from coherent_btb_20260915_lms_channel_whitening.
%FIT_CHANNEL_LMS Reference-trained 4-real fractionally-spaced normalized LMS.
o=s.o;o.tapCount=q.tapCount;o.lowpassHz=q.lowpassHz;o.sampleOffset=q.sampleOffset;
[x,front]=rf47lmsbtb.btb_frontend(cap,o);u=rf47lmsbtb.btb_taps(x,q.tapCount);clear x;
offset=(q.tapCount-s.o.tapCount)/4;assert(offset==round(offset),'Noninteger symbol offset');
N=size(u,1);index=(1:N)'+offset;phase=s.phase(index);target=s.target(index,:);
nt=q.trainSymbols-offset;assert(nt>1000 && nt<50000,'Training must finish before calibration');
u=bsxfun(@times,u,exp(-1i*phase));ur=[real(u) imag(u) ones(N,1)];clear u;
t=[real(target(:,1)) imag(target(:,1)) real(target(:,2)) imag(target(:,2))];
R=ur(1:nt,:)'*ur(1:nt,:)/nt;[V,D]=eig((R+R')/2);d=real(diag(D));
P=V*diag(1./sqrt(max(d,max(d)*q.floor)))*V';uw=ur*P;clear ur R V D;
W=zeros(size(uw,2),4);norms=sum(uw.^2,2)+1e-8;steps=[.3 .15 .08 .04 .02 .01];
trainMse=zeros(numel(steps),4);
for pass=1:numel(steps)
    Wsum=zeros(size(W));count=0;
    for k=1:nt
        row=uw(k,:);e=t(k,:)-row*W;W=W+steps(pass)/norms(k)*(row'*e);
        if pass==numel(steps) && k>floor(nt/3),Wsum=Wsum+W;count=count+1;end
    end
    if count>0,W=Wsum/count;end
    trainMse(pass,:)=mean((uw(1:nt,:)*W-t(1:nt,:)).^2,1);
end
model=struct('weights',P*W,'options',o,'tapCount',q.tapCount,'sampleRateHz',cap.sampleRateHz,'symbolRateHz',o.symbolRate,'trainingSource','verified replay capture, never content bytes');
v=uw*W;raw=[v(:,1)+1i*v(:,2) v(:,3)+1i*v(:,4)];
result=struct('raw',raw,'target',target,'trainCount',nt,'offset',offset,'options',o,'front',front,'trainMse',trainMse);
end


