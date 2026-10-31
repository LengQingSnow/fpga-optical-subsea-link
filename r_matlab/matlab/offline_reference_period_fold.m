function result=offline_reference_period_fold(capture,reference,probe,options)
%OFFLINE_REFERENCE_PERIOD_FOLD Use the repeated RF47 replay period for
% cross-cycle averaging. Offline diagnostic only; GUI/FPGA are untouched.
if nargin<4, options=struct(); end
symbol_rate=opt(options,'symbolRateHz',4e9); period=round(opt(options,'periodSymbols',size(reference.laneBits,1)));
group_cycles=round(opt(options,'groupCycles',16)); train_cycles=round(opt(options,'trainCycles',8)); ridge=opt(options,'ridge',1e-3);
if train_cycles>=group_cycles, train_cycles=floor(group_cycles/2); end
fs=double(capture.sampleRateHz); sps=round(fs/symbol_rate); x=double(capture.channels); x=bsxfun(@minus,x,mean(x,1));
z=[x(:,1)+1i*x(:,2),x(:,3)+1i*x(:,4)]; z=bsxfun(@rdivide,z,sqrt(mean(abs(z).^2,1)+eps));
n=(0:size(z,1)-1).'; z=bsxfun(@times,z,exp(-1i*2*pi*probe.frequencyOffsetHz*n/fs)); z=z(probe.phase:sps:end,:);
v=[real(z(:,1)),imag(z(:,1)),real(z(:,2)),imag(z(:,2))]; v=bsxfun(@minus,v,mean(v,1)); v=bsxfun(@rdivide,v,std(v,0,1)+eps);
ref=2*double(logical(reference.laneBits))-1; count=floor(size(v,1)/period)*period; v=v(1:count,:); cycles=count/period;
% Preserve the selected reference shift; fold only complete replay cycles.
d=ref(mod((0:count-1).'+probe.shift,period)+1,:); pred=[]; tgt=[]; folded=[]; raw=[]; groups=0;
for g=1:floor(cycles/group_cycles)
 first=(g-1)*group_cycles*period+1; last=g*group_cycles*period; tr=first:(first+train_cycles*period-1); te=(first+train_cycles*period):last;
 xtr=[v(tr,:),ones(numel(tr),1)]; w=(xtr'*xtr+ridge*eye(5))\(xtr'*d(tr,:)); yt=[v(te,:),ones(numel(te),1)]*w; dt=d(te,:);
 pred=[pred;yt]; tgt=[tgt;dt];
 % Average the held-out cycles at each period position, which is the
 % deterministic replay waveform after independent channel noise is reduced.
 nte=group_cycles-train_cycles; yy=reshape(yt,period,nte,4); dd=reshape(dt,period,nte,4); ym=squeeze(mean(yy,2)); dm=dd(:,1,:); dm=reshape(dm,period,4); folded=[folded;ym]; raw=[raw;reshape(yy,period*nte,4)]; groups=groups+1;
end
if isempty(pred), error('offline_reference_period_fold:Short','Not enough complete replay cycles.'); end
e=(pred>=0)~=(tgt>=0); desiredPeriod=ref(mod((0:period-1).'+probe.shift,period)+1,:); desiredFold=repmat(desiredPeriod,groups,1); ef=(folded>=0)~=(desiredFold>=0);
result=struct('ber',mean(e(:)),'berByLane',mean(e,1),'foldedBer',mean(ef(:)),'foldedBerByLane',mean(ef,1),'groups',groups,'groupCycles',group_cycles,'trainCycles',train_cycles,'periodSymbols',period,'comparedSymbols',size(pred,1),'foldedSymbols',size(folded,1),'frequencyOffsetHz',probe.frequencyOffsetHz,'sampleOffset',probe.phase,'referenceShift',probe.shift,'evmRms',sqrt(mean(abs([folded(:,1)+1i*folded(:,2),folded(:,3)+1i*folded(:,4)]-[desiredFold(:,1)+1i*desiredFold(:,2),desiredFold(:,3)+1i*desiredFold(:,4)]).^2,1)));
end
function v=opt(s,n,d),if isfield(s,n)&&~isempty(s.(n)),v=s.(n);else,v=d;end,end
