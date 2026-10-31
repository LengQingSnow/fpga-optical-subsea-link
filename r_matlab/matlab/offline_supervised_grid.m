function best=offline_supervised_grid(capture,reference,options)
if nargin<3, options=struct(); end
symbol_rate=opt(options,'symbolRateHz',4e9); sps=round(double(capture.sampleRateHz)/symbol_rate); B=round(opt(options,'blockSymbols',96));
cfos=opt(options,'cfoGridHz',(-533:.5:-530)*1e6); phases=opt(options,'phases',1:sps); shifts=opt(options,'shifts',0:1023);
w=double(capture.channels); w=bsxfun(@minus,w,mean(w,1)); z=[w(:,1)+1i*w(:,2),w(:,3)+1i*w(:,4)]; z=bsxfun(@rdivide,z,sqrt(mean(abs(z).^2,1)+eps));
ref=2*double(logical(reference.laneBits))-1; period=size(ref,1); best=struct('ber',inf);
for cf=cfos
 n=(0:size(z,1)-1).'; zr=bsxfun(@times,z,exp(-1i*2*pi*cf*n/double(capture.sampleRateHz)));
 for ph=phases
  v=zr(ph:sps:end,:); v=real_to_lanes(v); v=bsxfun(@minus,v,mean(v,1)); v=bsxfun(@rdivide,v,std(v,0,1)+eps); count=size(v,1);
  for sh=shifts
   d=ref(mod((0:count-1).'+sh,period)+1,:); pred=[]; tgt=[];
   for first=1:B:(count-B+1)
    last=first+B-1; nt=floor(B/2); tr=first:first+nt-1; te=first+nt:last; x=[v(tr,:),ones(numel(tr),1)]; ww=x\d(tr,:); pred=[pred;[v(te,:),ones(numel(te),1)]*ww]; tgt=[tgt;d(te,:)]; %#ok<AGROW>
   end
   pred=normalize_binary(pred); er=(pred>=0)~=(tgt>=0); ber=mean(er(:));
   if ber<best.ber, best=struct('ber',ber,'berByLane',mean(er,1),'frequencyOffsetHz',cf,'sampleOffset',ph,'referenceShift',sh); end
  end
 end
end
end
function x=real_to_lanes(v), x=[real(v(:,1)),imag(v(:,1)),real(v(:,2)),imag(v(:,2))]; end
function x=normalize_binary(x)
for k=1:4, n=x(x(:,k)<0,k); p=x(x(:,k)>=0,k); if ~isempty(n)&&~isempty(p), c=.5*(mean(p)+mean(n)); h=.5*(mean(p)-mean(n)); x(:,k)=(x(:,k)-c)/max(eps,h); end, end
end
function v=opt(s,n,d), if isfield(s,n)&&~isempty(s.(n)), v=s.(n); else, v=d; end, end
