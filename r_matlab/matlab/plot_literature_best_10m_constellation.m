%PLOT_LITERATURE_BEST_10M_CONSTELLATION Plot the final offline result.
set(0, 'DefaultFigureVisible', 'off');
data_dir = smf_project_path('r_matlab','data2');
loaded = load(fullfile(data_dir, 'literature_best_10m_result.mat'));
q = loaded.plot_equalized;
t = loaded.plot_target;
count = min(50000, size(q, 1));
indices = round(linspace(1, size(q, 1), count));
figure_handle = figure('Visible', 'off', 'Color', 'w', ...
    'Position', [100 100 1200 520]);
subplot(1, 2, 1);
plot(real(q(indices, 1)), imag(q(indices, 1)), '.', 'MarkerSize', 3);
hold on;
plot(real(t(indices, 1)), imag(t(indices, 1)), 'k.', 'MarkerSize', 2);
axis equal; grid on; xlim([-1.8 1.8]); ylim([-1.8 1.8]);
xlabel('X I'); ylabel('X Q');
title(sprintf('X polarization | BER %.5g | EVM %.5f', ...
    mean(mean(loaded.best_lane(:, 1:2)), 2), mean(loaded.best_evm(:, 1))));
subplot(1, 2, 2);
plot(real(q(indices, 2)), imag(q(indices, 2)), '.', 'MarkerSize', 3);
hold on;
plot(real(t(indices, 2)), imag(t(indices, 2)), 'k.', 'MarkerSize', 2);
axis equal; grid on; xlim([-1.8 1.8]); ylim([-1.8 1.8]);
xlabel('Y I'); ylabel('Y Q');
title(sprintf('Y polarization | BER %.5g | EVM %.5f', ...
    mean(mean(loaded.best_lane(:, 3:4)), 2), mean(loaded.best_evm(:, 2))));
print(figure_handle, '-dpng', '-r120', ...
    fullfile(data_dir, 'constellation_literature_best_10m.png'));
close(figure_handle);
exit;
