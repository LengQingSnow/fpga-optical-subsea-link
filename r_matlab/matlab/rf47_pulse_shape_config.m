function [coefficients, filter_delay] = rf47_pulse_shape_config(cfg)
%RF47_PULSE_SHAPE_CONFIG Select the receiver pulse model used by RF47.

if isfield(cfg, 'pulseShape') && strcmpi(cfg.pulseShape, 'nrz')
    coefficients = zeros(0, 1);
    filter_delay = 0;
else
    coefficients = double(cfg.rrcCoefficients(:));
    filter_delay = (numel(coefficients) - 1) / 2;
end
end
