function history = append_realtime_ber_history(history, result, timestamp, max_points)
%APPEND_REALTIME_BER_HISTORY Store one non-cumulative BER window.
% Each row is the BER measured only within one scope acquisition window.

if nargin < 3 || isempty(timestamp)
    timestamp = now;
end
if nargin < 4 || isempty(max_points)
    max_points = 600;
end
if ~isstruct(result) || ~isfield(result, 'lastBerByLane') || ...
        ~isfield(result, 'lastErrorsByLane') || ...
        ~isfield(result, 'lastBitsByLane')
    error('append_realtime_ber_history:Result', ...
        'A per-window physical BER result is required.');
end
if ~isscalar(timestamp) || ~isfinite(timestamp)
    error('append_realtime_ber_history:Timestamp', ...
        'The acquisition timestamp must be one finite datenum value.');
end
max_points = max(1, round(double(max_points)));

if nargin < 1 || isempty(history) || ~isstruct(history)
    history = empty_history();
end

history.time(end + 1) = double(timestamp);
history.ber(end + 1) = double(result.lastBer);
history.errors(end + 1) = double(result.lastErrors);
history.bits(end + 1) = double(result.lastBits);
history.zeroError(end + 1) = (result.lastErrors == 0);
history.berByLane(end + 1, :) = double(result.lastBerByLane(:)).';
history.errorsByLane(end + 1, :) = double(result.lastErrorsByLane(:)).';
history.bitsByLane(end + 1, :) = double(result.lastBitsByLane(:)).';

% A zero-error window has a real BER of zero but cannot be placed on a
% logarithmic axis. Keep the exact value and use 1/N only for display.
history.displayBer(end + 1) = max(history.ber(end), 1 / max(1, history.bits(end)));
history.displayBerByLane(end + 1, :) = max(history.berByLane(end, :), ...
    1 ./ max(1, history.bitsByLane(end, :)));

first = max(1, numel(history.time) - max_points + 1);
fields = fieldnames(history);
for index = 1:numel(fields)
    value = history.(fields{index});
    if isvector(value)
        history.(fields{index}) = value(first:end);
    else
        history.(fields{index}) = value(first:end, :);
    end
end
end

function history = empty_history()
history = struct();
history.time = zeros(1, 0);
history.ber = zeros(1, 0);
history.displayBer = zeros(1, 0);
history.errors = zeros(1, 0);
history.bits = zeros(1, 0);
history.zeroError = false(1, 0);
history.berByLane = zeros(0, 4);
history.displayBerByLane = zeros(0, 4);
history.errorsByLane = zeros(0, 4);
history.bitsByLane = zeros(0, 4);
end
