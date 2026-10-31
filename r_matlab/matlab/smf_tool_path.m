function p = smf_tool_path(name)
%SMF_TOOL_PATH Find an installed tool without a machine-specific drive.
p = getenv(['SMF_' upper(name)]);
if ~isempty(p) && isempty(regexp(p,'^[A-Za-z]:|^[\\/]','once'))
    p=smf_project_path(p);
end
if ~isempty(p) && exist(p,'file')==2, return; end
if strcmp(name,'xsct'), command='xsct.bat'; installation=getenv('XILINX_VITIS');
elseif strcmp(name,'vivado'), command='vivado.bat'; installation=getenv('XILINX_VIVADO');
else, error('smf_tool_path:Name','Unknown tool: %s',name); end
if ~isempty(installation)
    p=fullfile(installation,'bin',command);
    if exist(p,'file')==2, return; end
end
[status,output]=system(['where ' command]);
if status==0
    lines=regexp(strtrim(output),'\r?\n','split');
    for k=1:numel(lines)
        if exist(strtrim(lines{k}),'file')==2, p=strtrim(lines{k});return; end
    end
end
error('smf_tool_path:Missing','Add %s to PATH or set SMF_%s. See README.md.',command,upper(name));
end
