function rf47_lms_btb_render(view, result, ber, history, message)
%RF47_LMS_BTB_RENDER Render only the isolated LMS-BTB tab.
% RESULT.metrics is the held-out btb_metrics result. BER is the cumulative
% accumulate_cma_window_ber result; HISTORY uses append_realtime_ber_history.
% An empty RESULT invalidates the latest window and clears its constellation.
% Pass the previous BER on a failed capture to retain cumulative counters.
% All-empty data resets the view. No acquisition or application state changes.

if nargin < 2, result = []; end
if nargin < 3, ber = []; end
if nargin < 4, history = []; end
if nargin < 5, message = ''; end
% Keep text controls outside the axes' tick labels and x-axis captions.
% The shortened history plot leaves a separate band below this status text.
set(view.status, 'Position', [0.07 0.408 0.88 0.015]);
set(view.timeStatus, 'Position', [0.07 0.001 0.88 0.038]);
have_result = isstruct(result) && isfield(result, 'metrics') && ...
    isstruct(result.metrics) && isfield(result.metrics, 'constellation') && ...
    ~isempty(result.metrics.constellation);

render_constellations(view, result, have_result);
if ~isempty(ber)
    set(view.total, 'String', sprintf('%s BER %.3e', ...
        char([29289 29702 23618 32047 35745]), ber.totalBer));
    set(view.count, 'String', sprintf('%s/%s %.0f/%.0f', ...
        char([32047 35745 38169 35823]), char([27604 29305]), ...
        ber.totalErrors, ber.totalBits));
    set(view.resolution, 'String', sprintf('%s 1/N = %.3e', ...
        char([32479 35745 20998 36776 29575]), ber.resolution));
    set(view.lanes, 'String', sprintf( ...
        '%s: CH1/TX0 %.3e | CH2/TX2 %.3e | CH3/TX4 %.3e | CH4/TX6 %.3e | %s %d', ...
        char([21508 36890 36947 32047 35745]), ber.totalBerByLane(1), ...
        ber.totalBerByLane(2), ber.totalBerByLane(3), ...
        ber.totalBerByLane(4), char([25429 33719 27425 25968]), ...
        ber.captureCount));
elseif isempty(history) || isempty(history.time)
    set(view.total, 'String', [char([29289 29702 23618 32047 35745]) ' BER --']);
    set(view.count, 'String', [char([32047 35745 38169 35823]) '/' ...
        char([27604 29305]) ' --']);
    set(view.resolution, 'String', [char([32479 35745 20998 36776 29575]) ' --']);
    set(view.lanes, 'String', char([31561 24453 26377 25928 21442 32771 27604 36739]));
end
if have_result && ~isempty(ber)
    set(view.last, 'String', sprintf('%s BER %.3e', ...
        char([26412 27425 31383 21475]), ber.lastBer));
else
    set(view.last, 'String', [char([26412 27425 31383 21475]) ' BER --']);
end

render_history(view, history);
if isempty(message)
    if have_result
        message = sprintf('LMS-BTB | %s', datestr(now, 'HH:MM:SS'));
        if isfield(result.metrics, 'bitsByLane')
            message = sprintf('%s | held-out bits %.0f', ...
                message, sum(result.metrics.bitsByLane));
        end
        if isfield(result, 'processingSeconds') && ...
                isscalar(result.processingSeconds) && ...
                isfinite(result.processingSeconds)
            message = sprintf('%s | DSP %.2f s', message, result.processingSeconds);
        end
    else
        message = ['LMS-BTB ' char([31561 24453 26377 25928 37319 38598])];
    end
end
set(view.status, 'String', message);
end

function render_constellations(view, result, have_result)
colors = [0.10 0.45 0.85; 0.85 0.25 0.15];
names = {'X', 'Y'};
components = {'CH1 / TX0', 'CH2 / TX2'; 'CH3 / TX4', 'CH4 / TX6'};
for polarization = 1:2
    ax = view.axes(polarization);
    cla(ax);
    hold(ax, 'on');
    if have_result && size(result.metrics.constellation, 2) >= polarization
        symbols = result.metrics.constellation(:, polarization);
        plot(ax, real(symbols), imag(symbols), '.', ...
            'Color', colors(polarization, :), 'MarkerSize', 4);
    end
    plot(ax, [-1.5 1.5], [0 0], '-', ...
        'Color', [0.75 0.75 0.75], 'LineWidth', 0.5);
    plot(ax, [0 0], [-1.5 1.5], '-', ...
        'Color', [0.75 0.75 0.75], 'LineWidth', 0.5);
    hold(ax, 'off');
    axis(ax, 'equal');
    xlim(ax, [-1.5 1.5]);
    ylim(ax, [-1.5 1.5]);
    grid(ax, 'on');
    xlabel(ax, ['I - ' components{polarization, 1}]);
    ylabel(ax, ['Q - ' components{polarization, 2}]);
    if have_result && isfield(result.metrics, 'evmRms') && ...
            numel(result.metrics.evmRms) >= polarization
        title(ax, sprintf('LMS-BTB %s | EVM %.2f%%', ...
            names{polarization}, 100 * result.metrics.evmRms(polarization)));
    else
        title(ax, sprintf('LMS-BTB %s | EVM --', names{polarization}));
    end
end
end

function render_history(view, history)
ax = view.historyAxes;
cla(ax);
legend(ax, 'off');
set(ax, 'YScale', 'log');
grid(ax, 'on');
xlabel(ax, char([32477 23545 26102 38388]));
ylabel(ax, char([31383 21475 32 66 69 82 65288 38750 32047 35745 65289]));
title(ax, ['LMS-BTB ' char([26102 38388 26354 32447 65288 38750 32047 35745 65289])]);
zero_note = 'BER=0 is plotted at 1/N only for the log axis; circles mark zero-error windows.';
if isempty(history) || isempty(history.time)
    set(ax, 'XLimMode', 'auto', 'XTickMode', 'auto', 'XTickLabelMode', 'auto');
    ylim(ax, [1e-6 1]);
    set(view.timeStatus, 'String', {char([31561 24453 37319 38598]), zero_note});
    return;
end

% Recompute display positions from exact errors and counts. The history's
% measured BER values remain unchanged, including true zeros.
display_ber = history.ber;
zero_total = history.errors == 0 & history.bits > 0;
display_ber(zero_total) = 1 ./ history.bits(zero_total);
display_lanes = history.berByLane;
zero_lanes = history.errorsByLane == 0 & history.bitsByLane > 0;
display_lanes(zero_lanes) = 1 ./ history.bitsByLane(zero_lanes);
display_ber(display_ber <= 0 | ~isfinite(display_ber)) = NaN;
display_lanes(display_lanes <= 0 | ~isfinite(display_lanes)) = NaN;

colors = [0.85 0.25 0.15; 0.10 0.45 0.85; ...
    0.10 0.60 0.25; 0.65 0.20 0.70];
lines = gobjects(1, 6);
hold(ax, 'on');
lines(1) = plot(ax, history.time, display_ber, 'k.-', ...
    'LineWidth', 1.8, 'MarkerSize', 8);
for lane = 1:4
    lines(lane + 1) = plot(ax, history.time, display_lanes(:, lane), '.-', ...
        'Color', colors(lane, :), 'LineWidth', 1.0, 'MarkerSize', 7);
    mask = zero_lanes(:, lane);
    plot(ax, history.time(mask), display_lanes(mask, lane), 'o', ...
        'Color', colors(lane, :), 'MarkerSize', 4, 'MarkerFaceColor', 'w', ...
        'HandleVisibility', 'off');
end
zero_times = history.time(zero_total);
zero_values = display_ber(zero_total);
if isempty(zero_times)
    % R2016a plot([], []) returns no handle. Keep a hidden legend sample
    % even when the current history contains no zero-error total windows.
    zero_times = NaN;
    zero_values = NaN;
end
lines(6) = plot(ax, zero_times, zero_values, 'ko', ...
    'MarkerSize', 5, 'MarkerFaceColor', 'w', 'LineWidth', 1.0);
hold(ax, 'off');

positive = [display_ber(:); display_lanes(:)];
positive = positive(isfinite(positive) & positive > 0);
if isempty(positive)
    ylim(ax, [1e-6 1]);
else
    lower = max(realmin, min(positive) / 3);
    upper = min(1, max(positive) * 3);
    if upper <= lower, upper = lower * 10; end
    ylim(ax, [lower upper]);
end
first_time = min(history.time);
last_time = max(history.time);
padding = max(0.5 / 86400, 0.05 * (last_time - first_time));
xlim(ax, [first_time - padding last_time + padding]);
datetick(ax, 'x', 'HH:MM:SS.FFF', 'keeplimits');
legend(ax, lines, {[char([24635 36335]) ' BER'], 'CH1 / TX0', ...
    'CH2 / TX2', 'CH3 / TX4', 'CH4 / TX6', 'BER=0 (display 1/N)'}, ...
    'Location', 'best');
set(view.timeStatus, 'String', {sprintf('%s %s | %s %d | %s %d', ...
    char([26368 21518 37319 38598 26102 38388]), ...
    datestr(history.time(end), 'yyyy-mm-dd HH:MM:SS.FFF'), ...
    char([31383 21475]), numel(history.time), ...
    char([48 35823 30721 31383 21475]), sum(zero_total)), zero_note});
end
