function result=offline_cma_reference_affine(capture,reference,options)
if nargin<3, options=struct(); end
cfg=struct('symbolRateHz',opt(options,'symbolRateHz',4e9),'taps',opt(options,'taps',41),'stepSize',opt(options,'stepSize',.025),'refineStepSize',opt(options,'refineStepSize',.003125),'phaseScanSymbols',8000,'phaseBlockSymbols',8,'phaseCandidateCount',32);
q=cma_mimo_equalize(capture,cfg); v=[real(q.equalizedSymbols(:,1)),imag(q.equalizedSymbols(:,1)),real(q.equalizedSymbols(:,2)),imag(q.equalizedSymbols(:,2))];
ref=2*double(logical(reference.laneBits))-1; period=size(ref,1); count=size(v,1); B=round(opt(options,'blockSymbols',96)); scan=min(count,8*period); best=struct('error',inf,'shift',0);
for sh=0:period-1
 d=ref(mod((0:scan-1).'+sh,period)+1,:); x=[v(1:scan,:),ones(scan,1)]; w=x\d; e=x*w-d; mse=mean(e(:).^2); if mse<best.error, best.error=mse; best.shift=sh; end
end
d=ref(mod((0:count-1).'+best.shift,period)+1,:); pred=[]; tgt=[];
for first=1:B:(count-B+1)
 last=first+B-1; nt=floor(B/2); tr=first:first+nt-1; te=first+nt:last; x=[v(tr,:),ones(numel(tr),1)]; w=x\d(tr,:); pred=[pred;[v(te,:),ones(numel(te),1)]*w]; tgt=[tgt;d(te,:)]; %#ok<AGROW>
end
pred=normalize_binary(pred); err=(pred>=0)~=(tgt>=0); zz=[pred(:,1)+1i*pred(:,2),pred(:,3)+1i*pred(:,4)]/sqrt(2); zd=[tgt(:,1)+1i*tgt(:,2),tgt(:,3)+1i*tgt(:,4)]/sqrt(2);
result=struct('ber',mean(err(:)),'berByLane',mean(err,1),'evmRms',sqrt(mean(abs(zz-zd).^2,1)),'shift',best.shift,'mse',best.error,'cma',q,'blockSymbols',B,'comparedSymbols',size(pred,1));
end
function x=normalize_binary(x)
for k=1:4, n=x(x(:,k)<0,k); p=x(x(:,k)>=0,k); if ~isempty(n)&&~isempty(p), c=.5*(mean(p)+mean(n)); h=.5*(mean(p)-mean(n)); x(:,k)=(x(:,k)-c)/max(eps,h); end, end
end
function v=opt(s,n,d), if isfield(s,n)&&~isempty(s.(n)), v=s.(n); else, v=d; end, end
