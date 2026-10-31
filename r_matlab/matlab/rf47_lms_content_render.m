function rf47_lms_content_render(view, result, references)
%RF47_LMS_CONTENT_RENDER Three actual received images above one seismic trace.
% Reference content is never drawn; only dimensions/sample rate are used here.
waiting = char([23578 26410 25910 21040 67 82 67 27491 30830 25968 25454]);
for image_id = 1:3
    ax = view.image_axes(image_id);cla(ax);
    if ~isfield(result,'images') || numel(result.images)<image_id || ...
            ~result.images(image_id).available
        text(ax,.5,.5,waiting,'HorizontalAlignment','center');axis(ax,'off');
        title(ax,sprintf('%s %d',char([27700 19979 22270 20687]),image_id));
        set(view.image_status(image_id),'String','--');continue;
    end
    item=result.images(image_id);count=references.imageWidth*references.imageHeight*3;
    data=repmat(uint8(128),count,1);available=min(count,numel(item.data));
    valid=false(count,1);valid(1:available)=item.validMask(1:available);
    data(valid)=item.data(find(valid));
    rgb=permute(reshape(data,[3 references.imageWidth references.imageHeight]),[3 2 1]);
    image('Parent',ax,'CData',rgb);axis(ax,'image');axis(ax,'off');
    title(ax,sprintf('%s %d | %.2f%%',char([27700 19979 22270 20687]),image_id,100*item.coverage));
    set(view.image_status(image_id),'String',sprintf('CRC-valid received payload BER %.3g | %.0f bits',item.ber,item.comparedBits));
end
ax=view.wave_axes;cla(ax);item=result.waveform;
if ~item.available || numel(item.data)<2
    text(ax,.5,.5,waiting,'HorizontalAlignment','center');axis(ax,'off');
    set(view.wave_status,'String','--');return;
end
count=floor(numel(item.data)/2);v=double(item.data(1:2:2*count))*256+double(item.data(2:2:2*count));
v(v>=32768)=v(v>=32768)-65536;valid=item.validMask(1:2:2*count)&item.validMask(2:2:2*count);v(~valid)=NaN;
plot(ax,(0:count-1)/references.waveformSampleRateHz,v,'b-');axis(ax,'on');grid(ax,'on');
xlabel(ax,[char([26102 38388]) ' (s)']);ylabel(ax,'int16');
title(ax,sprintf('%s | %.2f%%',char([22320 38663 27874 24418]),100*mean(valid)));
set(view.wave_status,'String',sprintf('CRC-valid received payload BER %.3g | %.0f bits | missing samples remain gaps',item.ber,item.comparedBits));
end
