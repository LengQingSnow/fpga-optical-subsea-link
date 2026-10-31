function rows = analyze_eye_scan(scan_root, output_csv)
%ANALYZE_EYE_SCAN Analyze all TXn_code_* directories under scan_root.

entries = dir(scan_root);
rows = struct('lane', {}, 'code', {}, 'relativePhaseUi', {}, ...
    'eyeHeightVolts', {}, 'eyeWidthUi', {}, 'noise', {});
for index = 1:numel(entries)
    if ~entries(index).isdir
        continue;
    end
    tokens = regexp(entries(index).name, '^(TX[246])_code_(\d+)$', ...
        'tokens', 'once');
    if isempty(tokens)
        continue;
    end
    directory = fullfile(scan_root, entries(index).name);
    metrics = compute_eye_metrics(load_scpi_capture(directory), 4e9);
    lane_index = str2double(tokens{1}(3));
    item = metrics.channel(lane_index / 2 + 1);
    row.lane = tokens{1};
    row.code = str2double(tokens{2});
    row.relativePhaseUi = item.relativePhaseUi;
    row.eyeHeightVolts = item.eyeHeightVolts;
    row.eyeWidthUi = item.eyeWidthUi;
    row.noise = item.rmsDecisionNoiseNormalized;
    rows(end + 1) = row; %#ok<AGROW>
end

if isempty(rows)
    error('analyze_eye_scan:NoCaptures', 'No TXn_code_* captures found.');
end

file_id = fopen(output_csv, 'w');
cleanup = onCleanup(@() fclose(file_id));
fprintf(file_id, 'lane,code,relative_phase_ui,eye_height_volts,eye_width_ui,noise\n');
for index = 1:numel(rows)
    fprintf(file_id, '%s,%d,%.9g,%.9g,%.9g,%.9g\n', rows(index).lane, ...
        rows(index).code, rows(index).relativePhaseUi, ...
        rows(index).eyeHeightVolts, rows(index).eyeWidthUi, rows(index).noise);
end
clear cleanup;

for lane = {'TX2', 'TX4', 'TX6'}
    selected = strcmp({rows.lane}, lane{1});
    if ~any(selected)
        continue;
    end
    candidates = rows(selected);
    [~, order] = sort(abs([candidates.relativePhaseUi]));
    best = candidates(order(1));
    fprintf('SCAN_BEST %s code=%d rel_phase=%.6f UI eye_height=%.6f V width=%.6f UI\n', ...
        best.lane, best.code, best.relativePhaseUi, ...
        best.eyeHeightVolts, best.eyeWidthUi);
end
end
