function view = rf47_lms_btb_panel(tabgroup)
%RF47_LMS_BTB_PANEL Add an isolated LMS-BTB view using the page-1 layout.
% The returned handles belong only to this tab. Compatible with R2016a.

view = struct();
view.tab = uitab(tabgroup, 'Title', 'LMS-BTB');
panel = uipanel('Parent', view.tab, 'Units', 'normalized', ...
    'Position', [0.02 0.835 0.96 0.155], ...
    'Title', ['LMS-BTB | ' char([29289 29702 23618]) ' BER']);
view.total = label(panel, [0.01 0.54 0.23 0.34]);
set(view.total, 'FontWeight', 'bold');
view.last = label(panel, [0.25 0.54 0.18 0.34]);
view.count = label(panel, [0.44 0.54 0.25 0.34]);
view.resolution = label(panel, [0.70 0.54 0.29 0.34]);
view.lanes = label(panel, [0.01 0.08 0.98 0.34]);

positions = [0.05 0.48 0.40 0.32; 0.55 0.48 0.40 0.32];
view.axes = gobjects(1, 2);
for index = 1:2
    view.axes(index) = axes('Parent', view.tab, ...
        'Units', 'normalized', 'Position', positions(index, :), ...
        'Box', 'on', 'FontSize', 9);
end
view.status = label(view.tab, [0.07 0.415 0.88 0.045]);
view.historyAxes = axes('Parent', view.tab, 'Units', 'normalized', ...
    'Position', [0.07 0.10 0.88 0.24], 'Box', 'on', ...
    'FontSize', 9, 'YScale', 'log');
view.timeStatus = label(view.tab, [0.07 0.035 0.88 0.045]);
rf47_lms_btb_render(view, [], [], [], '');
end

function control = label(parent, position)
control = uicontrol('Parent', parent, 'Style', 'text', ...
    'Units', 'normalized', 'Position', position, 'String', '', ...
    'HorizontalAlignment', 'left');
end
