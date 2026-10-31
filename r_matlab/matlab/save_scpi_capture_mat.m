function file_path = save_scpi_capture_mat(capture, output_directory, tag)
%SAVE_SCPI_CAPTURE_MAT Save one short live capture in MATLAB-native format.

if nargin < 2 || isempty(output_directory)
    output_directory = pwd;
end
if nargin < 3 || isempty(tag)
    tag = datestr(now, 'yyyymmdd_HHMMSSFFF');
end
if exist(output_directory, 'dir') ~= 7
    mkdir(output_directory);
end
file_path = fullfile(output_directory, ['live_eye_' tag '.mat']);
save(file_path, 'capture', '-v7');
end
