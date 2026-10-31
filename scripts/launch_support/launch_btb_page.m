function app = launch_btb_page(mode, ready_file)
% Visible GUI launcher only; existing DSP and GUI sources remain unchanged.
app = [];
try
    app = start_page(mode, ready_file);
catch failure
    report = getReport(failure, 'extended', 'hyperlinks', 'off');
    fid = fopen([ready_file '.failed'], 'w', 'n', 'UTF-8');
    if fid >= 0
        fprintf(fid, '%s\n', report);
        fclose(fid);
    end
    fprintf(2, '%s\n', report);
end
end

function app = start_page(mode, ready_file)
repo = fileparts(fileparts(fileparts(mfilename('fullpath'))));
gui_dir = fullfile(repo, 'r_matlab', 'matlab');
cd(gui_dir);
addpath(gui_dir);
if ~strcmp(mode, 'ber') && ~strcmp(mode, 'info')
    error('launch_btb_page:Mode', 'Unknown mode: %s', mode);
end
% User-selected common entry; no replay/JTAG operation or historical results.
app = start_lms_content_gui();
if strcmp(mode, 'ber')
    set(app.tabs, 'SelectedTab', app.cma_tab);
    app.initialTab = 'CMA-BTB';
    page_number = 3;
else
    set(app.tabs, 'SelectedTab', app.optical_tab);
    app.initialTab = 'CMA-INFO';
    page_number = 4;
end
set(app.status_text, 'String', sprintf('Stopped - page %d selected; click Start or Single Refresh', page_number));
guidata(app.figure, app);
figure(app.figure);
drawnow;
fid = fopen(ready_file, 'w');
if fid < 0
    error('launch_btb_page:Log', 'Cannot write GUI readiness marker: %s', ready_file);
end
fprintf(fid, 'GUI_READY entry=start_lms_content_gui mode=%s page=%d autoStart=false; click Start or Single Refresh.\n', mode, page_number);
fclose(fid);
end
