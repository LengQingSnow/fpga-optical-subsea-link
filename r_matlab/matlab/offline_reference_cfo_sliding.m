function result=offline_reference_cfo_sliding(capture,reference,probe,options)
%OFFLINE_REFERENCE_CFO_SLIDING Reference-aided sliding local MIMO equalizer.
% Offline diagnostic only. A short centered training window tracks phase and
% polarization mixing without averaging across replay cycles.
if nargin<4, options=struct(); end
symbol_rate=opt(options,'symbolRateHz',4e9); output_symbols=round(opt(options,'outputSymbols',16)); train_symbols=round(opt(options,'trainSymbols',80)); ridge=opt(options,'ridge',1e-3);
if mod(output_symbols,1)~=0 || output_symbols<1, error('outputSymbols must be positive'); end
fs=double(capture.sampleRateHz); sps=round(fs/symbol_rate); x=double(capture.channels); x=bsxfun(@minus,x,mean(x,1)); z=[x(:,1)+1i*x(:,2),x(:,3)+1i*x(:,4)]; z=bsxfun(@rdivide,z,sqrt(mean(abs(z).^2,1)+eps));
n=(0:size(z,1)-1).'; z=bsxfun(@times,z,exp(-1i*2*pi*probe.frequencyOffsetHz*n/fs)); v=z(probe.phase:sps:end,:); v=[real(v(:,1)),imag(v(:,1)),real(v(:,2)),imag(v(:,2))]; v=bsxfun(@minus,v,mean(v,1)); v=bsxfun(@rdivide,v,std(v,0,1)+eps);
ref=2*double(logical(reference.laneBits))-1; period=size(ref,1); count=min(size(v,1),size(ref,1)*1024); v=v(1:count,:); d=ref(mod((0:count-1).'+probe.shift,period)+1,:);
pred=zeros(count,4); valid=false(count,1); half=floor(train_symbols/2); idx=1:output_symbols;
for center=1:output_symbols:count
 te=center:min(count,center+output_symbols-1); tc=round(mean(te)); tr1=max(1,tc-half); tr2=min(count,tc+half); tr=tr1:tr2; tr=tr(~ismember(tr,te));
 if numel(tr)<8, continue; end
 X=[v(tr,:),ones(numel(tr),1)]; W=(X'*X+ridge*eye(5))\(X'*d(tr,:)); pred(te,:)=[v(te,:),ones(numel(te),1)]*W; valid(te)=true;
end
pred=pred(valid,:); tgt=d(valid,:); pred=normalize_binary(pred); err=(pred>=0)~=(tgt>=0); z1=[pred(:,1)+1i*pred(:,2),pred(:,3)+1i*pred(:,4)]/sqrt(2); z2=[tgt(:,1)+1i*tgt(:,2),tgt(:,3)+1i*tgt(:,4)]/sqrt(2);
result=struct('ber',mean(err(:)),'berByLane',mean(err,1),'evmRms',sqrt(mean(abs(z1-z2).^2,1)),'outputSymbols',output_symbols,'trainSymbols',train_symbols,'comparedSymbols',size(pred,1),'frequencyOffsetHz',probe.frequencyOffsetHz,'sampleOffset',probe.phase,'referenceShift',probe.shift);
end
function x=normalize_binary(x)
for k=1:size(x,2), n=x(x(:,k)<0,k); p=x(x(:,k)>=0,k); if ~isempty(n)&&~isempty(p), c=.5*(mean(p)+mean(n)); h=.5*(mean(p)-mean(n)); x(:,k)=(x(:,k)-c)/max(eps,h); end, end
end
function v=opt(s,n,d),if isfield(s,n)&&~isempty(s.(n)),v=s.(n);else,v=d;end,end
