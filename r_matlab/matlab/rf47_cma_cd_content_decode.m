function [state,result]=rf47_cma_cd_content_decode(state,capture,cfg,references)
% Page 6 uses page-5 CD/front-end/CMA plus received-only page-4 CRC stitching.
cfg.cmaContentDspFcn=@rf47_cma_cd_content_dsp;
cfg.useBadCrcSegments=false;cfg.opticalCma=true;
[state,result]=rf47_cma_content_decode(state,capture,cfg,references);
end
