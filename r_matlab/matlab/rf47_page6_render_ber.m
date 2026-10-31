function rf47_page6_render_ber(view, history)
%RF47_PAGE6_RENDER_BER Plot measured window BER including exact zero.
% Linear ordinate deliberately avoids drawing BER=0 at an artificial floor.
set(view.note, 'String', sprintf('%s\n%s\n%s', ...
    char([21475 24452 65306 67 82 67 32 27491 30830 24103 30340 24050 30693 25968 25454 27604 36739]), ...
    char([19981 21547 22351 24103 21644 20002 22833 25968 25454 65292 38750 20840 38142 36335 29289 29702 32 66 69 82]), ...
    char([26080 21487 27604 36739 25968 25454 26102 26174 31034 32 45 45 65292 26354 32447 26029 24320])));
ax = view.axes;
cla(ax);
set(ax, 'YScale', 'linear');
grid(ax, 'on');
xlabel(ax, char([37319 38598 26102 38388]));
ylabel(ax, char([31383 21475 32 66 69 82]));
title(ax, char([22909 24103 25968 25454 32 66 69 82 65288 38750 32047 35745 65289]));
if isempty(history)
    set(view.last, 'String', [char([26412 27425 31383 21475]) ' BER --']);
    set(view.streams, 'String', sprintf('%s BER --\n%s BER --', ...
        char([27700 19979 22270 20687]), char([22320 38663 27874 24418])));
    set(view.counts, 'String', char([31561 24453 26412 27425 37319 38598 30340 21487 27604 36739 22909 24103 25968 25454]));
    set(view.time, 'String', char([23578 26410 37319 38598]));
    ylim(ax, [0 1e-6]);
    return;
end
values = history.ber(end, :);
set(view.last, 'String', sprintf('%s BER %s', ...
    char([26412 27425 31383 21475]), rate(values(1))));
set(view.streams, 'String', sprintf('%s BER %s\n%s BER %s', ...
    char([27700 19979 22270 20687]), rate(values(2)), ...
    char([22320 38663 27874 24418]), rate(values(3))));
total_bits = sum(history.totalBits);
total_errors = sum(history.totalErrors);
total_ber = NaN;
if total_bits > 0
    total_ber = total_errors / total_bits;
end
w = history.lastWindow;
set(view.counts, 'String', sprintf('%s %.0f / %.0f\n%s BER %s (%.0f / %.0f)\n%s %.0f / %.0f | %s %.0f', ...
    char([26412 27425 38169 35823 47 27604 29305]), ...
    sum(history.errors(end, :)), sum(history.bits(end, :)), ...
    char([32047 35745]), rate(total_ber), total_errors, total_bits, ...
    char([26412 27425 22351 24103 47 24635 24103]), w.badFrames, w.frameCount, ...
    char([21442 32771 19981 21305 37197 21253]), w.unmatchedPackets));
set(view.time, 'String', sprintf('%s | #%d', ...
    datestr(history.time(end), 'yyyy-mm-dd HH:MM:SS.FFF'), history.captureCount));
colors = [0 0 0; 0 0.35 0.85; 0.85 0.2 0.1];
handles = gobjects(1, 3);
hold(ax, 'on');
for index = 1:3
    handles(index) = plot(ax, history.time, history.ber(:, index), '.-', ...
        'Color', colors(index, :), 'LineWidth', 1.1, 'MarkerSize', 10);
end
hold(ax, 'off');
if numel(history.time) == 1 || max(history.time) == min(history.time)
    xlim(ax, history.time(end) + [-1 1] / 86400);
else
    xlim(ax, [min(history.time) max(history.time)]);
end
datetick(ax, 'x', 'HH:MM:SS', 'keeplimits');
valid_values = history.ber(isfinite(history.ber));
if isempty(valid_values) || max(valid_values) == 0
    ylim(ax, [0 1e-6]);
else
    ylim(ax, [0 min(1, max(1e-6, max(valid_values) * 1.15))]);
end
legend(ax, handles, {char([21512 35745]), char([22270 20687]), ...
    char([22320 38663 27874])}, 'Location', 'northoutside', ...
    'Orientation', 'horizontal');
end

function text = rate(value)
if isfinite(value)
    text = sprintf('%.3e', value);
else
    text = '--';
end
end
