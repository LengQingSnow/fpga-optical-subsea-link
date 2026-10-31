function result=offline_reference_cfo_affine(capture,reference,probe,options)
%OFFLINE_REFERENCE_CFO_AFFINE Evaluate a selected CFO/phase/shift with local affine blocks.
if nargin<4, options=struct(); end
symbol_rate=opt(options,'symbolRateHz',4e9); block_symbols=round(opt(options,'blockSymbols',384)); train_fraction=opt(options,'trainingFraction',0.5);
fs=double(capture.sampleRateHz); sps=round(fs/symbol_rate); wave=double(capture.channels);
wave=bsxfun(@minus,wave,mean(wave,1)); z=[wave(:,1)+1i*wave(:,2),wave(:,3)+1i*wave(:,4)];
z=bsxfun(@rdivide,z,sqrt(mean(abs(z).^2,1)+eps)); n=(0:size(z,1)-1).';
z=bsxfun(@times,z,exp(-1i*2*pi*probe.frequencyOffsetHz*n/fs));
fraction=opt(options,'fraction',0);
if abs(fraction)<1e-12
    sampled=z(probe.phase:sps:end,:);
else
    base=((probe.phase-1+fraction)+(0:floor((size(z,1)-probe.phase-fraction)/sps))*sps+1).';
    src=(1:size(z,1)).'; sampled=zeros(numel(base),2);
    sampled(:,1)=interp1(src,real(z(:,1)),base,'linear'); sampled(:,2)=interp1(src,imag(z(:,1)),base,'linear');
    yi=interp1(src,real(z(:,2)),base,'linear'); yq=interp1(src,imag(z(:,2)),base,'linear'); sampled=[sampled(:,1)+1i*sampled(:,2),yi+1i*yq];
end
v=real_to_lanes(sampled); v=bsxfun(@minus,v,mean(v,1)); v=bsxfun(@rdivide,v,std(v,0,1)+eps);
ref=2*double(logical(reference.laneBits))-1; period=size(ref,1); count=size(v,1);
d=ref(mod((0:count-1).'+probe.shift,period)+1,:); pred=[]; tgt=[]; blocks=0;
for first=1:block_symbols:(count-block_symbols+1)
 last=first+block_symbols-1; nt=max(8,min(block_symbols-1,floor(block_symbols*train_fraction))); tr=first:first+nt-1; te=first+nt:last;
 x=[v(tr,:),ones(numel(tr),1)]; w=x\d(tr,:); pred=[pred;[v(te,:),ones(numel(te),1)]*w]; tgt=[tgt;d(te,:)]; blocks=blocks+1; %#ok<AGROW>
end
pred=normalize_binary(pred); err=(pred>=0)~=(tgt>=0); zz=[pred(:,1)+1i*pred(:,2),pred(:,3)+1i*pred(:,4)]/sqrt(2); zd=[tgt(:,1)+1i*tgt(:,2),tgt(:,3)+1i*tgt(:,4)]/sqrt(2);
result=struct('ber',mean(err(:)),'berByLane',mean(err,1),'evmRms',sqrt(mean(abs(zz-zd).^2,1)),'blockSymbols',block_symbols,'blockCount',blocks,'comparedSymbols',size(pred,1),'frequencyOffsetHz',probe.frequencyOffsetHz,'sampleOffset',probe.phase,'referenceShift',probe.shift);
end
function x=real_to_lanes(v), x=[real(v(:,1)),imag(v(:,1)),real(v(:,2)),imag(v(:,2))]; end
function x=normalize_binary(x)
for k=1:size(x,2), n=x(x(:,k)<0,k); p=x(x(:,k)>=0,k); if ~isempty(n)&&~isempty(p), c=.5*(mean(p)+mean(n)); h=.5*(mean(p)-mean(n)); x(:,k)=(x(:,k)-c)/max(eps,h); end, end
end
function v=opt(s,n,d), if isfield(s,n)&&~isempty(s.(n)), v=s.(n); else, v=d; end, end
