function [objects, stats] = rf47_cma_content_stitch(objects, frames, segments, cfg)
%RF47_CMA_CONTENT_STITCH Accumulate CRC-verified, addressable AXDS prefixes.
% Preserve verified prefixes, and EOP-anchored suffixes of fixed 1400-byte
% ax7101 packets with a verified header and bounded matching packet ID.
% Never fill missing bytes or address unanchored middle fragments.
if isempty(objects)
    objects=struct('datasetType',{},'sourcePort',{},'datasetCycle',{}, ...
        'objectId',{},'objectLength',{},'objectCrc32',{},'data',{}, ...
        'validMask',{},'conflictBytes',{},'packetCount',{},'allTransportCrcOk',{});
end
stats=struct('newBytes',0,'verifiedPrefixes',0,'conflictingBytes',0, ...
    'completeObjectCount',0,'objectCrcOk',false(1,numel(objects)));
active=false(1,4);ids=zeros(1,4,'uint8');buffers=cell(1,4);tails=cell(1,4);
broken=false(1,4);startSequence=zeros(1,4,'uint32');
lastSequence=[];
for fi=1:frames.frameCount
    continuous=isempty(lastSequence)||mod(double(frames.sequence(fi))-double(lastSequence),2^32)==1;
    if ~continuous || ~frames.crcOk(fi) || ~frames.headerOk(fi) || ~frames.segmentParseOk(fi)
        for port=1:4,broken(port)=true;tails{port}=zeros(0,1,'uint8');end
    end
    lastSequence=frames.sequence(fi);
    if ~frames.crcOk(fi)||~frames.headerOk(fi)||~frames.segmentParseOk(fi),continue;end
    % 128 aggregate frames carry fewer than 256 complete 1400-byte packets:
    % a matching 8-bit packet ID cannot wrap within this association limit.
    for port=1:4
        if active(port)&&mod(double(frames.sequence(fi))-double(startSequence(port)),2^32)>128,flush(port,false);end
    end
    for si=find(double(segments.frameIndex)==fi)'
        if ~segments.frameCrcOk(si),continue;end
        port=double(segments.portId(si));
        if segments.sop(si)
            flush(port,false);active(port)=true;ids(port)=segments.packetId(si);buffers{port}=zeros(0,1,'uint8');
            tails{port}=zeros(0,1,'uint8');broken(port)=false;startSequence(port)=frames.sequence(fi);
        end
        if ~active(port),continue;end
        if ids(port)~=segments.packetId(si),flush(port,false);continue;end
        if broken(port),tails{port}=[tails{port};uint8(segments.payload{si}(:))];
        else,buffers{port}=[buffers{port};uint8(segments.payload{si}(:))];end
        if numel(buffers{port})+numel(tails{port})>1400
            active(port)=false;buffers{port}=[];continue;
        end
        if segments.eop(si),flush(port,true);end
    end
end
for port=1:4,flush(port,false);end
stats.objectCrcOk=false(1,numel(objects));
for k=1:numel(objects)
    if all(objects(k).validMask)&&objects(k).conflictBytes==0
        stats.objectCrcOk(k)=crc32_ieee(objects(k).data)==objects(k).objectCrc32;
    end
end
stats.completeObjectCount=sum(stats.objectCrcOk);

    function flush(port,ended)
        if ~active(port),return;end
        bytes=buffers{port};active(port)=false;buffers{port}=[];
        commit(port,bytes,bytes(33:end),0);
        if ended&&broken(port)&&numel(bytes)>=32&&~isempty(tails{port})
            % Packet length is fixed by ax7101 (including final padding).
            % EOP anchors an unbroken received suffix without guessing the gap.
            packetStart=1400-numel(tails{port});first=max(32,packetStart);
            commit(port,bytes,tails{port}(first-packetStart+1:end),first-32);
        end
        tails{port}=[];
    end
    function commit(port,bytes,received,dataOffset)
        if numel(bytes)<32 || ~isequal(bytes(1:4),uint8([65;88;68;83])) || bytes(5)~=1,return;end
        kind=bytes(6);source=bytes(7);objectId=be16(bytes(13:14));validLength=be16(bytes(15:16));
        offset=double(be32(bytes(21:24)));len=double(be32(bytes(25:28)));crc=be32(bytes(29:32));
        if ~any(kind==[1 2])||source~=port||len<1||len>cfg.maximumObjectBytes|| ...
                validLength>1368||offset+validLength>len||objectId<1,return;end
        count=min(validLength-dataOffset,numel(received));if count<1,return;end
        payload=received(1:count);offset=offset+dataOffset;match=[];
        for oi=1:numel(objects)
            ob=objects(oi);
            if ob.datasetType==kind && ob.sourcePort==source && ob.objectId==objectId && ...
                    ob.objectLength==len && ob.objectCrc32==crc,match=oi;break;end
        end
        if isempty(match)
            ob=struct('datasetType',kind,'sourcePort',source,'datasetCycle',be32(bytes(9:12)), ...
                'objectId',uint16(objectId),'objectLength',uint32(len),'objectCrc32',crc, ...
                'data',zeros(len,1,'uint8'),'validMask',false(len,1),'conflictBytes',0, ...
                'packetCount',0,'allTransportCrcOk',true);
            objects(end+1)=ob;match=numel(objects);
        end
        target=offset+(1:count)';known=objects(match).validMask(target);
        conflict=known & objects(match).data(target)~=payload;
        objects(match).conflictBytes=objects(match).conflictBytes+nnz(conflict);
        stats.conflictingBytes=stats.conflictingBytes+nnz(conflict);
        fill=~known;objects(match).data(target(fill))=payload(fill);
        objects(match).validMask(target(fill))=true;objects(match).packetCount=objects(match).packetCount+1;
        stats.newBytes=stats.newBytes+nnz(fill);stats.verifiedPrefixes=stats.verifiedPrefixes+1;
    end
end
function value=be16(bytes)
value=double(bytes(1))*256+double(bytes(2));
end
function value=be32(bytes)
value=bitor(bitshift(uint32(bytes(1)),24),bitor(bitshift(uint32(bytes(2)),16),bitor(bitshift(uint32(bytes(3)),8),uint32(bytes(4)))));
end
