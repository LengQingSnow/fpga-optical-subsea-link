function result = rf47_page3_replay_dsp(capture, reference, options)
%RF47_PAGE3_REPLAY_DSP Isolated page-3 reference-assisted DP-QPSK receiver.
% Original symbol indices and target lane identities survive every stage.
% Synchronization/parameter selection use a prefix; BER uses later samples.
% No hardware access, files, global paths, or GUI state are modified here.
if nargin < 3, options = struct(); end
validateattributes(capture.channels, {'numeric'}, {'2d','nonempty','finite'});
if size(capture.channels,2) ~= 4 || size(reference.laneBits,2) ~= 4
    error('rf47_page3:Channels','Exactly four input and reference lanes are required.');
end
rs = option(options,'symbolRateHz',4e9);
fs = double(capture.sampleRateHz);
period = size(reference.laneBits,1);
probe = rf47_page3_sync(capture,reference,struct('symbolRateHz',rs));
validation_end = probe.prefixSymbols + 4*period;
needed_points = ceil((validation_end+128)*fs/rs);
if size(capture.channels,1) < needed_points + ceil(1024*fs/rs)
    error('rf47_page3:ShortCapture','Capture is too short for independent validation and BER.');
end
validation_capture = capture;
validation_capture.channels = capture.channels(1:needed_points,:);
base = struct('symbolRateHz',rs,'tapCount',5,'trainSymbols',256, ...
    'outputSymbols',4,'ridge',25,'causal',true, ...
    'firstTestSymbol',probe.prefixSymbols+129);
cutoffs = option(options,'cutoffFractions',[0.55 0.70 0]);
offsets = option(options,'fractionalOffsets',[0 1]);
best_cost = inf; candidates = []; best_options = []; best_validation = [];
for cutoff = cutoffs
    for offset = offsets
        q = base; q.lowpassHz = cutoff*rs; q.fractionalSampleOffset = offset;
        v = rf47_page3_fse(validation_capture,reference,probe,q);
        cost = mean(v.evmRms.^2);
        candidates = [candidates; cutoff offset cost v.ber]; %#ok<AGROW>
        if cost < best_cost
            best_cost = cost; best_options = q; best_validation = v;
        end
    end
end
weights = 1./max(best_validation.evmRms.^2,0.05);
weights = max(weights,max(weights)/10);
bps_options = struct('blockSymbols',64,'phaseCount',41, ...
    'jointPolarizations',true,'polarizationWeights',weights);
with_phase = rf47_page3_bps(best_validation,bps_options);
use_bps = mean(with_phase.evmRms.^2) < best_cost;
if use_bps, best_validation = with_phase; end
% Never use final BER labels to choose a parameter, phase, or output lane.
best_options.firstTestSymbol = validation_end + 257;
result = rf47_page3_fse(capture,reference,probe,best_options);
if use_bps, result = rf47_page3_bps(result,bps_options); end
actual_bits = [real(result.equalizedSymbols(:,1))>=0, ...
    imag(result.equalizedSymbols(:,1))>=0, ...
    real(result.equalizedSymbols(:,2))>=0,imag(result.equalizedSymbols(:,2))>=0];
reference_indices = mod(result.symbolIndices-1+probe.shift,period)+1;
expected_bits = logical(reference.laneBits(reference_indices,:));
errors = xor(actual_bits,expected_bits);
result.errorBitsByLane = sum(errors,1);
result.comparedBitsByLane = size(errors,1)*ones(1,4);
result.berByLane = mean(errors,1); result.ber = mean(errors(:));
target_real = 2*double(expected_bits)-1;
result.desiredSymbols = [target_real(:,1)+1i*target_real(:,2), ...
    target_real(:,3)+1i*target_real(:,4)]/sqrt(2);
result.evmRms = sqrt(mean(abs(result.equalizedSymbols-result.desiredSymbols).^2,1));
result.referenceIndices = reference_indices;
result.referenceAligned = true;
result.method = 'REF-FSE v2';
result.pointCount = size(capture.channels,1);
result.options = best_options; result.bpsOptions = bps_options;
result.bpsEnabled = use_bps; result.validationCandidates = candidates;
result.probe = probe; result.validationBerByLane = best_validation.berByLane;
result.validationEvmRms = best_validation.evmRms;
pol_ber = mean(reshape(best_validation.berByLane,2,2),1);
sync_ok = probe.score >= 0.05 && min(pol_ber) < 0.35 && ...
    mean(best_validation.evmRms.^2) < 0.95;
metrics(1) = cma_constellation_metrics(result.equalizedSymbols(:,1));
metrics(2) = cma_constellation_metrics(result.equalizedSymbols(:,2));
reason = sprintf('reference synchronization untrusted: score %.3g, validation BER %.3g', ...
    probe.score,best_validation.ber);
if sync_ok, reason = 'reference-indexed symbols; all held-out lane errors counted'; end
result.validity = struct('valid',sync_ok,'alignedMetrics',metrics, ...
    'validByPolarization',[metrics.valid],'reason',reason);
result.converged = sync_ok;
result.finalCost = mean(best_validation.evmRms.^2);
result.iqCorrectionApplied = [false false];
end

function value = option(options,name,fallback)
if isfield(options,name) && ~isempty(options.(name))
    value = options.(name);
else
    value = fallback;
end
end
