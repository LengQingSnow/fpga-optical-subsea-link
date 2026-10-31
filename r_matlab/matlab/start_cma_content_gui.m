function app=start_cma_content_gui(options)
% Open page 4; requires QSFP information mode, never enables BER replay.
addpath(fileparts(mfilename('fullpath')));
rf47_cma_content_status();
cfg=struct('initialTab','CMA-INFO','autoStart',true,'liveContentMode',true);
checkpoint=fullfile(fileparts(fileparts(mfilename('fullpath'))),'page4_received','checkpoint.mat');
if exist(checkpoint,'file')==2
    prior=load(checkpoint);
    if isfield(prior,'formatVersion')&&prior.formatVersion==1&&~isempty(prior.state)
        cfg.cmaContentDecoder=prior.state;cfg.cmaContentResult=prior.result;cfg.cmaContentReferences=prior.references;
    end
end
if nargin>0
    names=fieldnames(options);
    for k=1:numel(names),cfg.(names{k})=options.(names{k});end
end
autoStart=cfg.autoStart;cfg.autoStart=false;app=main_realtime_eye(cfg);
if ~isempty(app.cmaContentResult)
    rf47_lms_content_render(app.cma_content_view,app.cmaContentResult,app.cmaContentReferences);
    set(app.cma_content_view.status,'String','Restored CRC-verified received fragments; continue stitching.');
end
if autoStart && (isempty(app.cmaContentResult)||~app.cmaContentResult.allComplete)
    cb=get(app.start_button,'Callback');cb([],[]);
end
end
