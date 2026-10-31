function cma_app = start_cma_btb_gui(options)
% Start page 3 without restarting or replacing the active long PRBS replay.
cma_gui_directory=fileparts(mfilename('fullpath'));
addpath(cma_gui_directory);
cma_reference=rf47_cma_btb_reference();
config=struct('autoStart',true,'liveContentMode',false, ...
    'initialTab','CMA-BTB','page3DspMode','cma_btb','cmaReference',cma_reference);
if nargin>0
    names=fieldnames(options);
    for k=1:numel(names), config.(names{k})=options.(names{k}); end
end
cma_app=main_realtime_eye(config);
end
