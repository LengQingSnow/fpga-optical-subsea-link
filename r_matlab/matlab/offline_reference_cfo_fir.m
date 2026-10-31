function result = offline_reference_cfo_fir(capture, reference, options)
%OFFLINE_REFERENCE_CFO_FIR CFO-scan followed by local supervised MIMO FIR.
% Offline diagnostic only; existing GUI paths remain unchanged.
if nargin < 3, options=struct(); end
symbol_rate=opt(options,'symbolRateHz',4e9); taps=round(opt(options,'tapCount',9));
block_symbols=round(opt(options,'blockSymbols',384)); ridge=opt(options,'ridge',1e-2);
if mod(taps,2)==0, error('offline_reference_cfo_fir:Taps','tapCount must be odd.'); end
if isfield(options,'probeResult') && ~isempty(options.probeResult)
    probe=options.probeResult;
else
    probe_options=options; probe_options.perBlock=false;
    probe=offline_reference_cfo_scan(capture,reference,probe_options);
end
fs=double(capture.sampleRateHz); sps=round(fs/symbol_rate);
wave=double(capture.channels); wave=bsxfun(@minus,wave,mean(wave,1));
input=[wave(:,1)+1i*wave(:,2),wave(:,3)+1i*wave(:,4)];
input=bsxfun(@rdivide,input,sqrt(mean(abs(input).^2,1)+eps));
n=(0:size(input,1)-1).'; input=bsxfun(@times,input,exp(-1i*2*pi*probe.frequencyOffsetHz*n/fs));
received=complex_to_real(input(probe.phase:sps:end,:));
received=bsxfun(@minus,received,mean(received,1)); received=bsxfun(@rdivide,received,std(received,0,1)+eps);
ref=2*double(logical(reference.laneBits))-1; period=size(ref,1); count=size(received,1);
desired=ref(mod((0:count-1).'+probe.shift,period)+1,:);
half=(taps-1)/2; predictions=[]; targets=[]; blocks=0;
for first=1:block_symbols:(count-block_symbols+1)
 last=first+block_symbols-1; nt=floor(block_symbols/2);
 tr=(first+half):(first+nt-half-1);
 te=(first+nt+half):(last-half);
 if numel(tr)<16 || isempty(te), continue; end
 xtr=make_design(received,tr,taps); xte=make_design(received,te,taps);
 w=(xtr'*xtr+ridge*eye(size(xtr,2)))\(xtr'*desired(tr,:));
 predictions=[predictions;xte*w]; targets=[targets;desired(te,:)]; blocks=blocks+1; %#ok<AGROW>
end
predictions=normalize_binary(predictions); err=(predictions>=0)~=(targets>=0);
z=[predictions(:,1)+1i*predictions(:,2),predictions(:,3)+1i*predictions(:,4)]/sqrt(2);
zd=[targets(:,1)+1i*targets(:,2),targets(:,3)+1i*targets(:,4)]/sqrt(2);
result=struct('ber',mean(err(:)),'berByLane',mean(err,1),'evmRms',sqrt(mean(abs(z-zd).^2,1)), ...
 'tapCount',taps,'blockSymbols',block_symbols,'ridge',ridge,'frequencyOffsetHz',probe.frequencyOffsetHz, ...
 'sampleOffset',probe.phase,'referenceShift',probe.shift,'comparedSymbols',size(predictions,1),'blockCount',blocks,'probeError',probe.error);
end
function x=make_design(v,pos,t)
h=(t-1)/2; pos=pos(:); x=zeros(numel(pos),4*t+1); c=1;
for d=-h:h, x(:,c:c+3)=v(pos+d,:); c=c+4; end
x(:,end)=1;
end
function x=complex_to_real(v), x=[real(v(:,1)),imag(v(:,1)),real(v(:,2)),imag(v(:,2))]; end
function x=normalize_binary(x)
for k=1:size(x,2), n=x(x(:,k)<0,k); p=x(x(:,k)>=0,k); if ~isempty(n)&&~isempty(p), c=.5*(mean(p)+mean(n)); h=.5*(mean(p)-mean(n)); x(:,k)=(x(:,k)-c)/max(eps,h); end, end
end
function v=opt(s,n,d), if isfield(s,n)&&~isempty(s.(n)), v=s.(n); else, v=d; end, end
