function app = start_cma_cd_gui(options)
%start_cma_cd_gui Start page 5 without resetting long PRBS or writing JTAG.
if nargin<1,options=struct();end
addpath(fileparts(mfilename('fullpath')));
reference=rf47_cma_btb_reference();
config=struct('autoStart',true,'liveContentMode',false,'initialTab','CMA-CD', ...
 'dispersionCmaReference',reference);
names=fieldnames(options);
for k=1:numel(names),config.(names{k})=options.(names{k});end
app=main_realtime_eye(config);
end
