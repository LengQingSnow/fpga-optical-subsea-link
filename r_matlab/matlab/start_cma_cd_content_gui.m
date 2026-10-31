function app=start_cma_cd_content_gui(options)
% Open page 6 in information mode. No replay writes or FPGA programming.
addpath(fileparts(mfilename('fullpath')));rf47_cma_content_status();
cfg=struct('initialTab','CMA-CD-INFO','autoStart',true,'liveContentMode',true);
checkpoint=fullfile(fileparts(fileparts(mfilename('fullpath'))),'page6_received_330km','checkpoint.mat');
if exist(checkpoint,'file')==2
    prior=load(checkpoint);
    if isfield(prior,'formatVersion')&&prior.formatVersion==1&&~isempty(prior.state)
        cfg.cmaCdContentDecoder=prior.state;cfg.cmaCdContentResult=prior.result;cfg.cmaCdContentReferences=prior.references;
    end
end
if nargin>0
    names=fieldnames(options);for k=1:numel(names),cfg.(names{k})=options.(names{k});end
end
autoStart=cfg.autoStart;cfg.autoStart=false;app=main_realtime_eye(cfg);
if ~isempty(app.cmaCdContentResult)
    rf47_lms_content_render(app.cma_cd_content_view,app.cmaCdContentResult,app.cmaCdContentReferences);
    set(app.cma_cd_content_view.status,'String','Restored CRC-verified 330-km received fragments.');
end
if autoStart&&(isempty(app.cmaCdContentResult)||~app.cmaCdContentResult.allComplete)
    cb=get(app.start_button,'Callback');cb([],[]);
end
end
