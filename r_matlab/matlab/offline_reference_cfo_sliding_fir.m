function result=offline_reference_cfo_sliding_fir(capture,reference,probe,options)
%OFFLINE_REFERENCE_CFO_SLIDING_FIR Sliding supervised MIMO FIR.
% Uses known replay symbols in a centered local window to track both ISI and
% time-varying polarization mixing. Offline diagnostic only.
if nargin<4, options=struct(); end
symbol_rate=opt(options,'symbolRateHz',4e9); output_symbols=round(opt(options,'outputSymbols',8)); train_symbols=round(opt(options,'trainSymbols',256)); taps=round(opt(options,'tapCount',5)); ridge=opt(options,'ridge',1e-2);
if mod(taps,2)==0, error('tapCount must be odd'); end
fs=double(capture.sampleRateHz); sps=round(fs/symbol_rate); x=double(capture.channels); x=bsxfun(@minus,x,mean(x,1)); z=[x(:,1)+1i*x(:,2),x(:,3)+1i*x(:,4)]; z=bsxfun(@rdivide,z,sqrt(mean(abs(z).^2,1)+eps)); n=(0:size(z,1)-1).'; z=bsxfun(@times,z,exp(-1i*2*pi*probe.frequencyOffsetHz*n/fs)); q=z(probe.phase:sps:end,:); v=[real(q(:,1)),imag(q(:,1)),real(q(:,2)),imag(q(:,2))]; v=bsxfun(@minus,v,mean(v,1)); v=bsxfun(@rdivide,v,std(v,0,1)+eps);
ref=2*double(logical(reference.laneBits))-1; period=size(ref,1); count=min(size(v,1),period*1024); v=v(1:count,:); d=ref(mod((0:count-1).'+probe.shift,period)+1,:); h=(taps-1)/2; feat=4*taps+1; pred=zeros(count,4); valid=false(count,1); half=floor(train_symbols/2);
for center=1:output_symbols:count
 te0=center:min(count,center+output_symbols-1); te=te0(te0>h & te0<=count-h); if isempty(te),continue;end; tc=round(mean(te)); a=max(1+h,tc-half); b=min(count-h,tc+half); tr=a:b; tr=tr(~ismember(tr,te)); if numel(tr)<feat+4,continue;end
 X=make_design(v,tr,taps); W=(X'*X+ridge*eye(feat))\(X'*d(tr,:)); pred(te,:)=make_design(v,te,taps)*W; valid(te)=true;
end
pred=normalize_binary(pred(valid,:)); tgt=d(valid,:); err=(pred>=0)~=(tgt>=0); z1=[pred(:,1)+1i*pred(:,2),pred(:,3)+1i*pred(:,4)]/sqrt(2); z2=[tgt(:,1)+1i*tgt(:,2),tgt(:,3)+1i*tgt(:,4)]/sqrt(2);
result=struct('ber',mean(err(:)),'berByLane',mean(err,1),'evmRms',sqrt(mean(abs(z1-z2).^2,1)),'outputSymbols',output_symbols,'trainSymbols',train_symbols,'tapCount',taps,'ridge',ridge,'comparedSymbols',size(pred,1),'frequencyOffsetHz',probe.frequencyOffsetHz,'sampleOffset',probe.phase,'referenceShift',probe.shift);
if isfield(options,'returnSamples') && options.returnSamples, result.equalized=pred; result.target=tgt; end
end
function X=make_design(v,pos,taps), h=(taps-1)/2; pos=pos(:); X=zeros(numel(pos),4*taps+1); c=1; for k=-h:h, X(:,c:c+3)=v(bsxfun(@plus,pos,k),:); c=c+4; end; X(:,end)=1; end
function x=normalize_binary(x), for k=1:size(x,2), n=x(x(:,k)<0,k); p=x(x(:,k)>=0,k); if ~isempty(n)&&~isempty(p), c=.5*(mean(p)+mean(n)); h=.5*(mean(p)-mean(n)); x(:,k)=(x(:,k)-c)/max(eps,h); end, end, end
function v=opt(s,n,d),if isfield(s,n)&&~isempty(s.(n)),v=s.(n);else,v=d;end,end
