function start_realtime_gui()
%start_realtime_gui Open the RF47 live constellation and content dashboard.

matlab_dir = fileparts(mfilename('fullpath'));
cd(matlab_dir);
addpath(matlab_dir);
dataset_dir = fullfile(fileparts(matlab_dir), 'dataset2');
% Page 1 reads and verifies the live long-PRBS state around each capture,
% just like page 3. Do not re-arm the legacy 1024-symbol replay at startup.
main_realtime_eye(struct('autoStart', true, ...
    'liveContentMode', false, 'berReference', [], ...
    'datasetDirectory', dataset_dir, 'enableCameraDecode', false, ...
    'pointCount', 1000000));
end
