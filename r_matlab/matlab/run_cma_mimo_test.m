function result = run_cma_mimo_test(point_count)
%RUN_CMA_MIMO_TEST Acquire DS81304 XI/XQ/YI/YQ and run blind CMA MIMO DSP.

if nargin < 1 || isempty(point_count)
    point_count = 1000000;
end
script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);

fprintf('Connecting to DS81304 at 192.168.1.12:5555...\n');
capture = capture_ds81304_scpi('192.168.1.12', 5555, point_count, 30);
fprintf('Captured %d points/channel at %.6g GSa/s.\n', ...
    capture.pointCount, capture.sampleRateHz / 1e9);

options = struct('symbolRateHz', 4e9, 'taps', 21, ...
    'stepSize', 5e-2, 'refineStepSize', 6.25e-3, ...
    'phaseScanSymbols', 30000, ...
    'phaseBlockSymbols', 8, 'phaseCandidateCount', 64);
result = cma_mimo_equalize(capture, options);

fprintf('CMA selected sample offset %d/%d, final cost %.4g.\n', ...
    result.sampleOffset, result.decimation, result.finalCost);
fprintf('CMA EVM RMS: X=%.4f, Y=%.4f; converged=%d.\n', ...
    result.evmRms(1), result.evmRms(2), result.converged);
fprintf('Carrier offset: X=%.6g MHz, Y=%.6g MHz.\n', ...
    result.frequencyOffsetHz(1) / 1e6, result.frequencyOffsetHz(2) / 1e6);

figure('Name', 'RF47 CMA 2x2 MIMO DSP', 'NumberTitle', 'off', ...
    'Color', 'w');
subplot(2, 2, 1);
plot(real(result.inputSymbols(:, 1)), imag(result.inputSymbols(:, 1)), '.', ...
    'MarkerSize', 3); axis equal; grid on; title('X input'); xlabel('I'); ylabel('Q');
subplot(2, 2, 2);
plot(real(result.inputSymbols(:, 2)), imag(result.inputSymbols(:, 2)), '.', ...
    'MarkerSize', 3); axis equal; grid on; title('Y input'); xlabel('I'); ylabel('Q');
subplot(2, 2, 3);
plot(real(result.equalizedSymbols(:, 1)), imag(result.equalizedSymbols(:, 1)), '.', ...
    'MarkerSize', 3); axis equal; grid on; title('CMA output X'); xlabel('I'); ylabel('Q');
subplot(2, 2, 4);
plot(real(result.equalizedSymbols(:, 2)), imag(result.equalizedSymbols(:, 2)), '.', ...
    'MarkerSize', 3); axis equal; grid on; title('CMA output Y'); xlabel('I'); ylabel('Q');

result.capture = capture;
output_dir = fullfile(script_dir, '..', 'data');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
output_file = fullfile(output_dir, ...
    ['cma_mimo_' datestr(now, 'yyyymmdd_HHMMSS') '.mat']);
save(output_file, 'capture', 'result', '-v7.3');
result.outputFile = output_file;
fprintf('Saved CMA result: %s\n', output_file);
end
