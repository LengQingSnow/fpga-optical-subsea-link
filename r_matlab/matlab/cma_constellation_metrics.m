function metrics = cma_constellation_metrics(symbols)
%CMA_CONSTELLATION_METRICS Detect collapsed or incomplete QPSK outputs.

validateattributes(symbols, {'numeric'}, {'vector', 'nonempty'}, ...
    mfilename, 'symbols');
values = double(symbols(:));
if any(~isfinite(values))
    error('cma_constellation_metrics:Finite', ...
        'Constellation samples must be finite.');
end

sample_count = numel(values);
real_positive = real(values) >= 0;
imag_positive = imag(values) >= 0;
quadrant_counts = [sum(real_positive & imag_positive), ...
    sum(~real_positive & imag_positive), ...
    sum(~real_positive & ~imag_positive), ...
    sum(real_positive & ~imag_positive)];
quadrant_fractions = double(quadrant_counts) / max(1, sample_count);

centered = values - mean(values);
components = [real(centered), imag(centered)];
covariance_matrix = (components' * components) / max(1, sample_count - 1);
eigenvalues = sort(real(eig(covariance_matrix)), 'ascend');
axis_power_ratio = eigenvalues(1) / max(eps, eigenvalues(2));
second_moment = mean(abs(centered) .^ 2);
circularity = abs(mean(centered .^ 2)) / max(eps, second_moment);

sign_fractions = [mean(real_positive), mean(imag_positive)];
minimum_sign_fraction = min([sign_fractions, 1 - sign_fractions]);
positive_quadrants = quadrant_fractions(quadrant_fractions > 0);
quadrant_entropy = -sum(positive_quadrants .* log2(positive_quadrants)) / 2;

minimum_quadrant_fraction = min(quadrant_fractions);
valid = sample_count >= 512 && ...
    minimum_quadrant_fraction >= 0.04 && ...
    minimum_sign_fraction >= 0.12 && ...
    axis_power_ratio >= 0.12 && circularity <= 0.88;

penalty = max(0, 0.04 - minimum_quadrant_fraction) / 0.04 + ...
    max(0, 0.12 - minimum_sign_fraction) / 0.12 + ...
    max(0, 0.12 - axis_power_ratio) / 0.12 + ...
    max(0, circularity - 0.88) / 0.12;

metrics = struct();
metrics.valid = valid;
metrics.sampleCount = sample_count;
metrics.quadrantCounts = quadrant_counts;
metrics.quadrantFractions = quadrant_fractions;
metrics.minimumQuadrantFraction = minimum_quadrant_fraction;
metrics.signFractions = sign_fractions;
metrics.minimumSignFraction = minimum_sign_fraction;
metrics.axisPowerRatio = axis_power_ratio;
metrics.circularity = circularity;
metrics.quadrantEntropy = quadrant_entropy;
metrics.penalty = penalty;
end
