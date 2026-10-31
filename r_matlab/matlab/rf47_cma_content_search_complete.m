function complete=rf47_cma_content_search_complete(frames,verifiedSequences,byteCount,frameBytes)
% Stop candidate search only when every complete, sync-anchored frame is verified.
% A high aggregate CRC percentage is not sufficient for sparse image holes.
complete=false;
if frames.frameCount<2||isempty(verifiedSequences),return;end
starts=double(frames.startByte(:));
if starts(1)>frameBytes||any(diff(starts)~=frameBytes)|| ...
        ~all(frames.headerOk)||frames.frameCount<floor((byteCount-starts(1)+1)/frameBytes)
    return;
end
% Refuse early exit on sequence gaps, including corrupt unverified headers.
if any(mod(diff(double(frames.sequence(:))),2^32)~=1),return;end
complete=all(ismember(frames.sequence,verifiedSequences));
end
