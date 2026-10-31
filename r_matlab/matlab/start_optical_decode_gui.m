function start_optical_decode_gui()
%start_optical_decode_gui Start the optical-link content decoder.
% Use this entry after BER replay has been disabled on RF47.  It leaves the
% existing three pages intact and enables the fourth optical decode page.

matlab_dir = fileparts(mfilename('fullpath'));
cd(matlab_dir);
addpath(matlab_dir);
dataset_dir = fullfile(fileparts(matlab_dir), 'dataset2');

app = main_realtime_eye(struct('autoStart', false, ...
    'liveContentMode', true, 'berReference', [], ...
    'datasetDirectory', dataset_dir, 'enableCameraDecode', false, ...
    'opticalDecodeEnabled', true, 'pointCount', 1000000));
set(app.tabs, 'SelectedTab', app.optical_tab);
drawnow;
assignin('base', 'RF47_OPTICAL_APP', app);
single_callback = get(app.single_button, 'Callback');
feval(single_callback, app.single_button, []);
pause(0.5);
feval(single_callback, app.single_button, []);
figure(app.figure);
drawnow;
end
