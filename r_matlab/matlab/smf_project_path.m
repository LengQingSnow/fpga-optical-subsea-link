function p = smf_project_path(varargin)
%SMF_PROJECT_PATH Resolve project resources relative to this public checkout.
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
p = fullfile(root, varargin{:});
end
