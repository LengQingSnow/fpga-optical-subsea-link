function pair = capture_330km_ber_pair()
%CAPTURE_330KM_BER_PAIR Read RF47 replay reference, then acquire 10M points.
script_dir = fileparts(mfilename('fullpath'));
project_dir = fileparts(script_dir);
data_dir = fullfile(project_dir, 'data2');
reference = prepare_rf47_ber_reference();
save(fullfile(data_dir, 'rf47_reference_for_330km_capture.mat'), 'reference');
capture = capture_ds81304_scpi('192.168.1.12', 5555, 10000000, 120);
for channel = 1:4
    file_path = fullfile(data_dir, sprintf('ch%d.bin', channel));
    file_id = fopen(file_path, 'w', 'ieee-le');
    if file_id < 0
        error('capture_330km_ber_pair:Open', 'Cannot write %s.', file_path);
    end
    cleanup = onCleanup(@() fclose(file_id));
    fwrite(file_id, capture.channels(:, channel), 'single');
    clear cleanup;
end
manifest_path = fullfile(data_dir, 'capture_manifest.txt');
file_id = fopen(manifest_path, 'w');
if file_id < 0
    error('capture_330km_ber_pair:Manifest', 'Cannot write capture manifest.');
end
cleanup = onCleanup(@() fclose(file_id));
fprintf(file_id, 'sample_rate_hz=%.17g\n', capture.sampleRateHz);
fprintf(file_id, 'point_count=%d\n', capture.pointCount);
fprintf(file_id, 'sample_type=single\n');
fprintf(file_id, 'byte_order=little\n');
fprintf(file_id, 'x_origin_s=%.17g\n', -0.5 * capture.pointCount / capture.sampleRateHz);
for channel = 1:4
    fprintf(file_id, 'ch%d_file=ch%d.bin\n', channel, channel);
end
clear cleanup;
pair = struct('reference', reference, 'capture', capture, ...
    'manifestPath', manifest_path);
save(fullfile(data_dir, 'capture_330km_ber_pair.mat'), 'pair', '-v7.3');
fprintf('Paired capture saved: %d points/channel at %.9g Sa/s.\n', ...
    capture.pointCount, capture.sampleRateHz);
end
