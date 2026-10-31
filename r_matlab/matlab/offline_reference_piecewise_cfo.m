function result=offline_reference_piecewise_cfo(capture,reference,probe,options)
%OFFLINE_REFERENCE_PIECEWISE_CFO Local fourth-power CFO tracking plus affine blocks.
if nargin<4, options=struct(); end
symbol_rate=opt(options,'symbolRateHz',4e9); train_block=round(opt(options,'blockSymbols',128));
freq_block=round(opt(options,'frequencyBlockSymbols',8192)); fs=double(capture.sampleRateHz); sps=round(fs/symbol_rate);
wave=double(capture.channels); wave=bsxfun(@minus,wave,mean(wave,1)); z=[wave(:,1)+1i*wave(:,2),wave(:,3)+1i*wave(:,4)]; z=bsxfun(@rdivide,z,sqrt(mean(abs(z).^2,1)+eps));
raw=z(probe.phase:sps:end,:); count=size(raw,1); global_cfo=probe.frequencyOffsetHz;
% Track and correct carrier separately on frequency blocks; affine training
% below absorbs the unknown constant phase at each block boundary.
corrected=zeros(size(raw)); cfo_trace=zeros(ceil(count/freq_block),1); bi=0;
for first=1:freq_block:count
 last=min(count,first+freq_block-1); local=raw(first:last,:); bi=bi+1;
 q=local.^4; if size(q,1)>2, cross=conj(q(1:end-1,:)).*q(2:end,:); f0=angle(sum(sum(cross)))/(2*pi*4*(1/symbol_rate)); else, f0=0; end
 f0=f0+round((global_cfo-f0)/1e9)*1e9; cfo_trace(bi)=f0;
 nn=(0:size(local,1)-1).'; corrected(first:last,:)=bsxfun(@times,local,exp(-1i*2*pi*f0*nn/symbol_rate));
end
v=real_to_lanes(corrected); v=bsxfun(@minus,v,mean(v,1)); v=bsxfun(@rdivide,v,std(v,0,1)+eps);
ref=2*double(logical(reference.laneBits))-1; period=size(ref,1); desired=ref(mod((0:count-1).'+probe.shift,period)+1,:); pred=[]; tgt=[];
for first=1:train_block:(count-train_block+1)
 last=first+train_block-1; nt=floor(train_block/2); tr=first:first+nt-1; te=first+nt:last; x=[v(tr,:),ones(numel(tr),1)]; w=x\desired(tr,:); pred=[pred;[v(te,:),ones(numel(te),1)]*w]; tgt=[tgt;desired(te,:)]; %#ok<AGROW>
end
pred=normalize_binary(pred); err=(pred>=0)~=(tgt>=0); zz=[pred(:,1)+1i*pred(:,2),pred(:,3)+1i*pred(:,4)]/sqrt(2); zd=[tgt(:,1)+1i*tgt(:,2),tgt(:,3)+1i*tgt(:,4)]/sqrt(2);
result=struct('ber',mean(err(:)),'berByLane',mean(err,1),'evmRms',sqrt(mean(abs(zz-zd).^2,1)),'frequencyTraceHz',cfo_trace,'blockSymbols',train_block,'frequencyBlockSymbols',freq_block,'comparedSymbols',size(pred,1));
end
function x=real_to_lanes(v), x=[real(v(:,1)),imag(v(:,1)),real(v(:,2)),imag(v(:,2))]; end
function x=normalize_binary(x)
for k=1:size(x,2), n=x(x(:,k)<0,k); p=x(x(:,k)>=0,k); if ~isempty(n)&&~isempty(p), c=.5*(mean(p)+mean(n)); h=.5*(mean(p)-mean(n)); x(:,k)=(x(:,k)-c)/max(eps,h); end, end
end
function v=opt(s,n,d), if isfield(s,n)&&~isempty(s.(n)), v=s.(n); else, v=d; end, end
