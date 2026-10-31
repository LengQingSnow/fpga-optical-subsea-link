function training=rf47_lms_content_reference(capture,cfg)
%RF47_LMS_CONTENT_REFERENCE Recover this capture's known PRBS31 training bits.
% Blind acquisition is used only to find received filler/sequence alignment.
% Final DSP is the page-7 whitening/NLMS core. No replay or dataset file read.
% Only candidate idle filler is known; payload, sync/header and CRC are masked.
b=blind_acquisition(capture,cfg);
a=refine_prbs(capture,b,cfg);
if ~exist('a','var') || isempty(a)
 error('rf47_lms_content_reference:NoPrbs','No reliable PRBS training branch.');
end
training=make_training(a,b,cfg);
end

function b=blind_acquisition(capture,cfg)
% Diagnostic independent four-real demixing, without a replay training target.
a=struct('capture',capture);best=-Inf;trials=[];
o=struct('symbolRate',4e9,'maxCfoHz',1.4e9,'lowpassHz',2.8e9,'sampleOffset',0,'carrierNotchHz',0);
for sampling=[0 2.5 5 7.5]
 o.sampleOffset=sampling;[x,front]=rf47lmsbtb.btb_frontend(a.capture,o);z0=x(1:2:end,:);nt=30000;
 for source=1:3
  q=z0.^4; q=bsxfun(@rdivide,q,mean(abs(q),1));if source==3,q=sum(q,2);else,q=q(:,source);end
  for win=[33 129 513 2049]
   phase=unwrap(angle(conv(q,ones(win,1)/win,'same')))/4;z=bsxfun(@times,z0,exp(-1i*phase));
   f=[real(z) imag(z)];mu=mean(f(1:nt,:),1);f=bsxfun(@minus,f,mu);R=f(1:nt,:)'*f(1:nt,:)/nt;[V,D]=eig(R);P=V*diag(1./sqrt(max(real(diag(D)),1e-4)))*V';f=f*P;X=f(1:nt,:);
   for method=1:2
    W=eye(4);
    for iteration=1:100
     y=X*W;if method==1,g=y.^3;der=3*mean(y.^2,1);else,g=tanh(y);der=mean(1-g.^2,1);end
     A=X'*g/nt-W*diag(der);[U,~,V]=svd(A,'econ');A=U*V';delta=max(abs(abs(diag(A'*W))-1));W=A;if delta<1e-7,break;end
    end
    y=f*W;[bytes,packing]=rf47_lms_content_pack(y>=0,cfg);
    try,[frames,segments]=parse_aggregate_frames_relocked(bytes,cfg);catch,frames=struct('frameCount',0,'crcOk',false(0,1),'headerOk',false(0,1));segments=[];end
    good=sum(frames.crcOk);score=good*1000+sum(frames.headerOk)-sum(packing.laneSyncErrorRates);kurt=mean(y.^4,1)./(mean(y.^2,1).^2)-3;
    fprintf('REAL offset%g src%d win%d method%d kurt%s sync%s CRC%d/%d\n',sampling,source,win,method,mat2str(kurt,3),mat2str(packing.laneSyncErrorRates,3),good,frames.frameCount);
    trials=[trials;sampling source win method good frames.frameCount]; %#ok<AGROW>
    if score>best,best=score;b=struct('y',y,'packing',packing,'phase',phase,'front',front,'sampling',sampling,'source',source,'win',win);end
   end
  end
 end
end
end

function a=refine_prbs(capture,b,cfg)
% Use confidently recovered idle PRBS as local training, never as output data.
a=[];
N=size(b.y,1);target=NaN(N,4);B=false(512,31);B(1:31,:)=eye(31)>0;
for k=32:512,B(k,:)=xor(B(k-31,:),B(k-28,:));end
fprintf('Acquisition sampling=%g source%d win%d\n',b.sampling,b.source,b.win);
inverseStep=zeros(31);inverseStep(1,[3 31])=1;inverseStep(2:31,1:30)=eye(30);
backMatrix=zeros(31,31,482);backMatrix(:,:,1)=eye(31);
for k=2:482,backMatrix(:,:,k)=mod(inverseStep*backMatrix(:,:,k-1),2);end
windowIndex=bsxfun(@plus,(1:31)',0:481);
for lane=1:4
 accepted=0;qualities=[];
 for first=257:512:60000-512
  bits=b.y(first+(0:511),lane)>=0;best=Inf;desired=[];
  for invert=0:1
   obs=xor(bits,logical(invert));windows=double(obs(windowIndex));
   S=mod(reshape(sum(bsxfun(@times,backMatrix,permute(windows,[3 1 2])),2),31,482),2)>0;
   pred=mod(double(B)*double(S),2)>0;err=sum(bsxfun(@ne,pred,obs),1);
   balance=mean(pred,1);err(balance<.25|balance>.75)=512;
   [nerr,j]=min(err);if nerr<best,best=nerr;desired=xor(pred(:,j),logical(invert));end
  end
  if best/512<.18
   target(first+(0:511),lane)=(2*double(desired)-1)/sqrt(2);accepted=accepted+1;qualities(end+1)=best/512; %#ok<AGROW>
  end
 end
 fprintf('Lane%d accepted idle training chunks=%d meanMismatch=%.4f\n',lane,accepted,mean(qualities));
end
o=struct('symbolRate',4e9,'maxCfoHz',1.4e9,'lowpassHz',3.5e9,'sampleOffset',b.sampling,'carrierNotchHz',0,'cfoHz',b.front.cfoHz);
[x,front]=rf47lmsbtb.btb_frontend(capture,o);best=-Inf;trials=[];
for L=[9 33 73 169]
 [u,centers]=rf47lmsbtb.btb_taps(x,L);offset=(L-1)/4;if offset~=round(offset),error('Unsupported tap parity');end
 idx=(1:size(u,1))'+offset;v=bsxfun(@times,u,exp(-1i*b.phase(idx)));F=[real(v) imag(v) ones(size(v,1),1)];clear u v;
 available=sum(isfinite(target(idx,:)),1);
 if all(available<size(F,2)*3),fprintf('Skip L%d: no reliable PRBS training lane %s\n',L,mat2str(available));continue;end
 for ridge=[.001 .01 .1]
  W=zeros(size(F,2),4);
  for lane=1:4
   keep=find(isfinite(target(idx,lane)));
   if numel(keep)>size(F,2)*3
    desired=target(idx(keep),lane);
   else
    keep=find(idx<60000);desired=b.y(idx(keep),lane);
   end
   A=F(keep,:);R=A'*A/size(A,1);W(:,lane)=(R+ridge*trace(R)/size(R,1)*eye(size(R)))\(A'*desired/size(A,1));
  end
  y=F*W;[bytes,packing]=rf47_lms_content_pack(y>=0,cfg);
  try,[frames,segments]=parse_aggregate_frames_relocked(bytes,cfg);catch,frames=struct('frameCount',0,'crcOk',false(0,1),'headerOk',false(0,1));segments=[];end
  good=sum(frames.crcOk);fprintf('PRBS train FIR%d ridge%g sync%s headers%d CRC%d/%d\n',L,ridge,mat2str(packing.laneSyncErrorRates,3),sum(frames.headerOk),good,frames.frameCount);
  trials=[trials;L ridge good frames.frameCount]; %#ok<AGROW>
  score=1000*good+sum(frames.headerOk)-sum(packing.laneSyncErrorRates);
  if score>best,best=score;a=struct('y',y,'packing',packing,'offset',offset);end
 end
end
end
function training=make_training(a,b,cfg)
% Derive candidate idle frame references from the received strongest lane.
% References are diagnostic/training only, not displayed recovered objects.
[~,canonical]=min(a.packing.laneSyncErrorRates);
lane=a.packing.laneOrder(canonical);start=a.packing.laneSymbolOffsets(canonical)+1;invert=a.packing.polarityInvert(canonical);
fprintf('Seed recovery uses canonical TX%d, observed component%d\n',2*(canonical-1),lane);
N=size(a.y,1);starts=(start:1024:N-1024)';K=numel(starts);sequences=NaN(K,1);quality=ones(K,1);
G=false(2048,31);G(1:31,:)=eye(31)>0;for k=32:2048,G(k,:)=xor(G(k-31,:),G(k-28,:));end
A=[G(canonical:4:canonical+120,:) eye(31)>0];for k=1:31,j=find(A(k:end,k),1)+k-1;A([k j],:)=A([j k],:);for r=1:31,if r~=k&&A(r,k),A(r,:)=xor(A(r,:),A(k,:));end;end;end
inverse=A(:,32:end);B=false(512,31);B(1:31,:)=eye(31)>0;for k=32:512,B(k,:)=xor(B(k-31,:),B(k-28,:));end
backStep=zeros(31);backStep(1,[3 31])=1;backStep(2:31,1:30)=eye(30);back=zeros(31,31,482);back(:,:,1)=eye(31);for k=2:482,back(:,:,k)=mod(backStep*back(:,:,k-1),2);end
winIndex=bsxfun(@plus,(1:31)',0:481);
for k=1:K
 bits=xor(a.y(starts(k)+32+(0:511),lane)>=0,invert);windows=double(bits(winIndex));S=mod(reshape(sum(bsxfun(@times,back,permute(windows,[3 1 2])),2),31,482),2)>0;
 pred=mod(double(B)*double(S),2)>0;err=sum(bsxfun(@ne,pred,bits),1);err(mean(pred,1)<.2|mean(pred,1)>.8)=512;[nerr,j]=min(err);quality(k)=nerr/512;
 if quality(k)<.10
  original=mod(double(inverse)*double(S(:,j)),2)>0;state=uint32(sum(double(original(:)).*2.^(30:-1:0)'));
  seq=bitxor(state,uint32(hex2dec('7FFFFFFF')));seq=bitset(seq,1,0);
  % Sequence MSB is transmitted at the first bit of header byte 13.
  % PRBS seed cannot identify sequence bit31. Keep low31 bits here.
  sequences(k)=double(seq);
 end
end
candidates=unique(mod(sequences(isfinite(sequences))-(find(isfinite(sequences))-1),2^32));candidates=unique([candidates;mod(candidates+1,2^32)]);scores=zeros(size(candidates));
for j=1:numel(candidates),pred=mod(candidates(j)+(0:K-1)',2^32);pred=2*floor(pred/2);scores(j)=sum(pred==sequences);end
if isempty(candidates),error('rf47_lms_content_reference:NoPrbs','No reliable idle PRBS seed in this capture.');end
[score,j]=max(scores);base=candidates(j);fprintf('Idle sequence base=%.0f matched %d/%d, candidate qualities %.5f\n',base,score,K,median(quality));
sequenceMsb=0; % Seed ignores MSB; header/CRC are never training targets.
target=NaN(size(b.y));accepted=false(K,1);offset=a.offset;
for k=1:K
 seq=mod(base+k-1,2^32);
 if ~isfinite(sequences(k)) || 2*floor(seq/2)~=sequences(k),continue;end
 seq=double(bitset(uint32(seq),32,sequenceMsb));
 frame=zeros(512,1,'uint8');frame(1:8)=cfg.syncWord(:);frame(9:12)=uint8([1;6;0;0]);frame(13:16)=be32(seq);frame(17:508)=aggregate_prbs31_bytes(uint32(seq),492);frame(509:512)=be32(crc32_msb(frame(1:508)));
 nibbles=zeros(1024,1,'uint8');nibbles(1:2:end)=bitshift(frame,-4);nibbles(2:2:end)=bitand(frame,15);levels=zeros(1024,4);for l=1:4,levels(:,l)=(2*double(bitget(nibbles,5-l))-1)/sqrt(2);end
 target(starts(k)+offset+(0:1023),:)=levels;accepted(k)=true;
end
fprintf('Reconstructed candidate idle targets %d frames. Other frames remain UNKNOWN.\n',sum(accepted));
base=double(bitset(uint32(base),32,sequenceMsb));
assert(sum(accepted)>=8,'Too few independently consistent idle PRBS frames');
known=false(size(target,1),1);
for k=find(accepted(:))',known(starts(k)+offset+(32:1015))=true;end
training=struct('target',target,'knownMask',known,'phase',b.phase, ...
 'candidateIdleFrames',sum(accepted),'seedBaseLow31',base, ...
 'options',struct('symbolRate',cfg.symbolRateHz,'maxCfoHz',1.4e9, ...
 'lowpassHz',3.9e9,'sampleOffset',b.sampling,'carrierNotchHz',0,'cfoHz',b.front.cfoHz));
end

function b=be32(x)
x=uint32(x);b=uint8([bitshift(x,-24);bitand(bitshift(x,-16),255);bitand(bitshift(x,-8),255);bitand(x,255)]);
end
