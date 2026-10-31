function capture=rf47_cma_content_capture(host,port,point_count)
% Single optical information capture, guarded against accidental BER replay.
before=rf47_cma_content_status();
if nargin<3,point_count=10000000;end
capture=rf47_cma_content_scope(host,port,point_count);
after=rf47_cma_content_status();
capture.informationModeBefore=before; capture.informationModeAfter=after;
end
