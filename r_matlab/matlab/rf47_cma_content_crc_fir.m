function [bytes,info] = rf47_cma_content_crc_fir(symbols,bytes,cfg)
% Refine residual ISI using labels from received CRC-valid frames only.
% No dataset reference enters this function. New decisions are accepted only
% as complete CRC-valid frames; original valid frames are never discarded.
started=tic;info=struct('addedFrames',0,'heldOutMse',[],'seconds',0);
soft=[real(symbols(:,1)) imag(symbols(:,1)) real(symbols(:,2)) imag(symbols(:,2))];
[original,packing]=rf47_lms_content_pack(soft>=0,cfg);
frames=parse_aggregate_frames_relocked(original,cfg);good=find(frames.crcOk);
if numel(good)<4,return;end
n=double(packing.byteCount)*2;aligned=zeros(n,4);
for lane=1:4
    rows=packing.laneSymbolOffsets(lane)+(1:n);
    aligned(:,lane)=soft(rows,packing.laneOrder(lane))*(1-2*double(packing.polarityInvert(lane)));
end
train=false(n,1);validation=false(n,1);desired=zeros(n,4);
for j=1:numel(good)
    k=good(j);rows=2*(frames.startByte(k)-1)+(1:1024);
    b=frames.bytes(:,k);nibbles=zeros(1024,1,'uint8');
    nibbles(1:2:end)=bitshift(b,-4);nibbles(2:2:end)=bitand(b,15);
    for lane=1:4,desired(rows,lane)=2*double(bitget(nibbles,5-lane))-1;end
    if mod(j,2)==1,train(rows)=true;else,validation(rows)=true;end
end
base=parse_aggregate_frames_relocked(bytes,cfg);seq=base.sequence;pool=base.bytes;ok=base.crcOk;
for memoryMode=0:1
tapGrid=[3 7 15 31];if memoryMode,tapGrid=[3 7 15];end
for taps=tapGrid
    half=(taps-1)/2;u=ones(n,4*taps+1);
    for j=1:taps
        ix=max(1,min(n,(1:n)'+j-half-1));u(:,(j-1)*4+(1:4))=aligned(ix,:);
    end
    if memoryMode
        % A small IIR basis models low-frequency baseline wander without
        % thousands of free FIR coefficients or any missing-payload labels.
        for memory=[16 64 256 1024]
            alpha=1/memory;past=filter(alpha,[1 -(1-alpha)],aligned);
            future=flipud(filter(alpha,[1 -(1-alpha)],flipud(aligned)));
            u=[u(:,1:end-1) past future ones(n,1)]; %#ok<AGROW>
        end
    end
    tr=find(train);va=find(validation);tr=tr(tr>half&tr<=n-half);va=va(va>half&va<=n-half);
    if numel(tr)<2000||numel(va)<2000,continue;end
    if memoryMode
        scale=max(sqrt(mean(u(tr,:).^2,1)),1e-5);u=bsxfun(@rdivide,u,scale);
    end
    covariance=u(tr,:)'*u(tr,:)/numel(tr);cross=u(tr,:)'*desired(tr,:)/numel(tr);
    for ridge=[.001 .01 .1]
        penalty=eye(size(covariance))*ridge;penalty(end,end)=0;
        weights=(covariance+penalty)\cross;prediction=u*weights;
        if any(~isfinite(prediction(:))),continue;end
        mse=mean(mean((prediction(va,:)-desired(va,:)).^2));
        info.heldOutMse(end+1,:)=[memoryMode taps ridge mse]; %#ok<AGROW>
        % Large held-out error is a failed refinement, even if training fits.
        if mse>.25,continue;end
        bits=prediction>=0;
        v=uint8(bits(:,1))*8+uint8(bits(:,2))*4+uint8(bits(:,3))*2+uint8(bits(:,4));
        candidate=bitshift(v(1:2:end),4)+v(2:2:end);
        try,fr=parse_aggregate_frames_relocked(candidate,cfg);catch,continue;end
        for k=find(fr.crcOk(:))'
            at=find(seq==fr.sequence(k),1);
            if isempty(at)
                seq(end+1,1)=fr.sequence(k);pool(:,end+1)=fr.bytes(:,k);ok(end+1,1)=true;
                info.addedFrames=info.addedFrames+1;
            elseif ~ok(at)
                pool(:,at)=fr.bytes(:,k);ok(at)=true;info.addedFrames=info.addedFrames+1;
            else
                assert(isequal(pool(:,at),fr.bytes(:,k)), ...
                    'Conflicting CRC-valid frame after short FIR refinement');
            end
        end
    end
end
end
anchor=double(seq(find(ok,1)));relative=mod(double(seq)-anchor+2^31,2^32)-2^31;
[~,order]=sort(relative);pool=pool(:,order);bytes=pool(:);info.seconds=toc(started);
end
