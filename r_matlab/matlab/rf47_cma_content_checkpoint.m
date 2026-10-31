function destination=rf47_cma_content_checkpoint(state,result,references)
% Page-4-only durable received state. Overwrite a bounded checkpoint, not raw captures.
directory=fullfile(fileparts(fileparts(mfilename('fullpath'))),'page4_received');
if exist(directory,'dir')~=7,mkdir(directory);end
destination=fullfile(directory,'checkpoint.mat');temporary=fullfile(directory,'checkpoint_pending.mat');
formatVersion=1;savedAt=now;
save(temporary,'state','result','references','formatVersion','savedAt','-v7.3');
[ok,message]=movefile(temporary,destination,'f');assert(ok,message);
if ~isempty(result)&&isfield(result,'allComplete')&&result.allComplete
    for k=1:3
        rgb=permute(reshape(result.images(k).data,[3 references.imageWidth references.imageHeight]),[3 2 1]);
        imwrite(rgb,fullfile(directory,sprintf('received_image_%d.png',k)));
    end
    item=result.waveform;waveform=double(item.data(1:2:end))*256+double(item.data(2:2:end));
    waveform(waveform>=32768)=waveform(waveform>=32768)-65536;
    sampleRateHz=references.waveformSampleRateHz;timeSeconds=(0:numel(waveform)-1)'/sampleRateHz;
    save(fullfile(directory,'received_seismic.mat'),'waveform','sampleRateHz','timeSeconds');
end
end
