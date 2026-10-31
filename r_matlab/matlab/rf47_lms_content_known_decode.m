function [bits,bytes,recovery,packing]=rf47_lms_content_known_decode(capture,cfg)
%RF47_LMS_CONTENT_KNOWN_DECODE Page-8 known-sequence LMS, not replay matching.
started=tic; training=rf47_lms_content_reference(capture,cfg);
bits=false(0,4);bytes=uint8([]);packing=struct();recovery=struct();
best=[-1 -Inf -1];trials=zeros(0,12);
tapMenu=[73 169 569 1049];
if isfield(cfg,'lmsContentTapMenu'),tapMenu=cfg.lmsContentTapMenu;end
for phaseMode=1:2
if phaseMode==2
    if recovery.crcGoodFrames>0,break;end
    [training.phase,phaseInfo]=rf47_lms_content_track_phase(capture,training);
    if ~phaseInfo.used,break;end
    tapMenu=169;
end
for taps=tapMenu
    q=struct('tapCount',taps,'lowpassHz',3.9e9,'floor',3e-4,'trainSymbols',49000);
    r=rf47_lms_content_known_lms(capture,training,q);
    [candidate,p]=rf47_lms_content_pack(r.bits,cfg);
    parser=cfg;parser.useBadCrcSegments=false;
    try
        [f,~]=parse_aggregate_frames_relocked(candidate,parser);
    catch ex
        if isempty(strfind(ex.identifier,'parse_aggregate_frames_relocked:')),rethrow(ex);end
        f=struct('crcOk',false(0,1),'frameCount',0,'headerOk',false(0,1));
    end
    good=sum(f.crcOk);cal=r.calibrationMismatchByLane;
    score=[good -sum(cal) sum(f.headerOk)];
    trials(end+1,:)=[phaseMode taps good f.frameCount cal r.heldoutIdleMismatchByLane]; %#ok<AGROW>
    if score(1)>best(1) || (score(1)==best(1) && score(2)>best(2)) || ...
            (all(score(1:2)==best(1:2)) && score(3)>best(3))
        best=score;bits=r.bits;bytes=candidate;packing=p;
        recovery=struct('method',r.method,'crcGoodFrames',good,'frameCount',f.frameCount, ...
            'tapCount',taps,'phaseMode',phaseMode,'trainingSymbols',r.trainingSymbols, ...
            'candidateIdleFrames',training.candidateIdleFrames, ...
            'pilotCalibrationMismatchByLane',cal, ...
            'heldoutIdleMismatchByLane',r.heldoutIdleMismatchByLane, ...
            'coarseFrequencyOffsetHz',r.front.cfoHz,'usedReplayReference',false, ...
            'usedDatasetForTraining',false,'trainedOnCrc',false);
    end
    if good>=.9*(floor(size(r.bits,1)/1024)-1),break;end
end
end
recovery.trials=trials; recovery.processingSeconds=toc(started);
end
