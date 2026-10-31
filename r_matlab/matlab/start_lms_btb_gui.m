function app = start_lms_btb_gui()
%start_lms_btb_gui Open the independent seventh page; never rearm RF47 replay.
% Replay must already be enabled. The page reads and verifies it per capture.
folder = fileparts(mfilename('fullpath'));
addpath(folder);
app = main_realtime_eye(struct('initialTab', 'LMS-BTB', 'autoStart', true));
end
