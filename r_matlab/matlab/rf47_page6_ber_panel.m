function view = rf47_page6_ber_panel(parent)
%RF47_PAGE6_BER_PANEL Isolated third column of optical-content page 6.
view.panel = uipanel('Parent', parent, 'Units', 'normalized', ...
    'Position', [0.67 0.04 0.32 0.92], ...
    'Title', char([23454 26102 35823 30721 29575]));
view.last = label(view.panel, [0.04 0.88 0.92 0.07], 13);
set(view.last, 'FontWeight', 'bold');
view.streams = label(view.panel, [0.04 0.79 0.92 0.09], 10);
view.counts = label(view.panel, [0.04 0.65 0.92 0.13], 9);
view.axes = axes('Parent', view.panel, 'Units', 'normalized', ...
    'Position', [0.17 0.23 0.73 0.36], 'FontSize', 9, 'Box', 'on');
view.time = label(view.panel, [0.04 0.13 0.92 0.045], 9);
view.note = label(view.panel, [0.04 0.015 0.92 0.11], 9);
rf47_page6_render_ber(view, []);
end

function handle = label(parent, position, font_size)
handle = uicontrol('Parent', parent, 'Style', 'text', ...
    'Units', 'normalized', 'Position', position, 'String', '', ...
    'HorizontalAlignment', 'left', 'FontSize', font_size);
end
