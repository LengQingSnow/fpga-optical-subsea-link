function [bits,bytes,recovery,packing] = rf47_cma_content_demodulate(capture,cfg)
% Overlapped CMA blocks, then assemble one continuous capture before UDP parse.
decode=@rf47_cma_content_dsp;
if isfield(cfg,'cmaContentDspFcn'),decode=cfg.cmaContentDspFcn;end
n=size(capture.channels,1);chunk=1000000;stride=950000;
starts=1:stride:max(1,n-100000);seq=zeros(0,1,'uint32');pool=zeros(512,0,'uint8');ok=false(0,1);
errors={};successful=0;bits=false(0,4);packing=[];recovery=struct();
warmWeights=[];
for first=starts
    part=capture;last=min(n,first+chunk-1);part.channels=capture.channels(first:last,:);
    part.pointCount=size(part.channels,1);part.firstPoint=first;
    try
        blockCfg=cfg;
        if ~isempty(warmWeights),blockCfg.cmaContentWarmWeights=warmWeights;end
        [bits,b,r,p]=decode(part,blockCfg);f=parse_aggregate_frames_relocked(b,cfg);
        if ~any(f.crcOk),continue;end
        for k=1:f.frameCount
            at=find(seq==f.sequence(k),1);
            if isempty(at)
                seq(end+1,1)=f.sequence(k);pool(:,end+1)=f.bytes(:,k);ok(end+1,1)=f.crcOk(k);
            elseif f.crcOk(k)
                if ok(at),assert(isequal(pool(:,at),f.bytes(:,k)),'Conflicting good frames across overlapping blocks');end
                pool(:,at)=f.bytes(:,k);ok(at)=true;
            end
        end
        successful=successful+1;recovery=r;packing=p;
        % Reuse only within this simultaneous scope record; never across captures.
        if isfield(r,'weights')&&isfield(r,'cma')&&sum(f.crcOk)>=32&& ...
                sum(f.crcOk)>=.85*f.frameCount&&r.cma.duplicateCorrelation<.2
            warmWeights=r.weights;
        end
    catch ex,errors{end+1}=ex.message;end %#ok<AGROW>
    drawnow;
end
assert(any(ok),'No CRC-valid aggregate frames in this scope capture');
anchor=double(seq(find(ok,1)));relative=mod(double(seq)-anchor+2^31,2^32)-2^31;
[~,order]=sort(relative);pool=pool(:,order);bytes=pool(:);
recovery.processedBlocks=numel(starts);recovery.successfulBlocks=successful;recovery.blockErrors=errors;
recovery.overlapPoints=chunk-stride;
end
