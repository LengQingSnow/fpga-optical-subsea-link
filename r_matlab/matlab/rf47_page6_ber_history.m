function history = rf47_page6_ber_history(history, window, timestamp, max_points)
%RF47_PAGE6_BER_HISTORY One point per capture, not a merged-object BER.
% No comparable bits => NaN (a gap), never zero. Combined BER is weighted
% by compared bits, not the arithmetic mean of the two stream BERs.
if isempty(history)
    history = struct('time', zeros(0, 1), 'ber', zeros(0, 3), ...
        'errors', zeros(0, 2), 'bits', zeros(0, 2), ...
        'totalErrors', [0 0], 'totalBits', [0 0], ...
        'captureCount', 0, 'lastWindow', []);
end
errors = double(window.errorsByStream(:).');
bits = double(window.bitsByStream(:).');
if numel(errors) ~= 2 || numel(bits) ~= 2 || ...
        any(~isfinite([errors bits])) || any(errors < 0) || ...
        any(bits < errors) || any(fix([errors bits]) ~= [errors bits])
    error('rf47_page6_ber_history:Counts', 'Invalid page-6 bit counts.');
end
validateattributes(timestamp, {'numeric'}, {'scalar', 'finite'});
validateattributes(max_points, {'numeric'}, {'scalar', 'integer', 'positive'});
values = NaN(1, 3);
valid = bits > 0;
values(find(valid) + 1) = errors(valid) ./ bits(valid);
if sum(bits) > 0
    values(1) = sum(errors) / sum(bits);
end
history.time(end + 1, 1) = timestamp;
history.ber(end + 1, :) = values;
history.errors(end + 1, :) = errors;
history.bits(end + 1, :) = bits;
history.totalErrors = history.totalErrors + errors;
history.totalBits = history.totalBits + bits;
history.captureCount = history.captureCount + 1;
history.lastWindow = window;
keep = max(1, numel(history.time) - max_points + 1):numel(history.time);
history.time = history.time(keep);
history.ber = history.ber(keep, :);
history.errors = history.errors(keep, :);
history.bits = history.bits(keep, :);
end
