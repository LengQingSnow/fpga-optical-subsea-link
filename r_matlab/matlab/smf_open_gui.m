function app = smf_open_gui(page)
% Open this legacy GUI stopped; no JTAG writes or scope commands.
if nargin<1, page='all'; end
root=fileparts(mfilename('fullpath'));addpath(root);
o=struct('autoStart',false,'berReference',[],'enableCameraDecode',false, ...
 'datasetDirectory',fullfile(fileparts(root),'dataset2'), ...
 'lmsContentDatasetDirectory',fullfile(fileparts(root),'dataset2'));
switch lower(page)
 case 'btb',o.initialTab='CMA-BTB';o.liveContentMode=false;
 case 'info',o.initialTab='CMA-INFO';o.liveContentMode=true;
 case 'cd',o.initialTab='CMA-CD';o.liveContentMode=false;
 case 'lms',o.initialTab='LMS-BTB';o.liveContentMode=false;
 case 'all',o.liveContentMode=false;
 otherwise,error('smf_open_gui:Page','Choose all, btb, info, cd or lms.');
end
app=main_realtime_eye(o);
end
