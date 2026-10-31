function result = rf47_cma_btb_dsp(capture, reference)
%RF47_CMA_BTB_DSP Page-five long-PRBS CMA flow, without CD for optical BTB.
% Live JTAG guards remain in rf47_cma_btb_capture. Reference bits resolve
% prefix mapping only; they never train CMA taps or select held-out test BER.
started = tic;
assert(size(capture.channels,1)>=1000000 && size(capture.channels,2)==4, ...
    'CMA-BTB requires a complete 1M x 4 capture');
assert(abs(capture.sampleRateHz-40e9)<1e6,'CMA-BTB requires 40 GSa/s');
assert(isequal(size(reference.laneBits),[262144 4]),'Long PRBS reference required');
o = struct('symbolRate',4e9,'maxCfoHz',1.4e9,'lowpassHz',2.8e9, ...
    'sampleOffset',0,'carrierNotchHz',2e6,'excludeDcHz',50e6);
[initial, coarse] = rf47lmsbtb.btb_frontend(capture,o);
% Same Rs/4 CFO ambiguity search as page five. No CD filter or CD search.
frequencies = coarse.cfoHz + [0 -1e9 1e9 -2e9 2e9];
frequencies = frequencies(abs(frequencies)<=o.maxCfoHz);
lastFailure = 'No valid prefix';
for attempt = 1:numel(frequencies)
    f = frequencies(attempt);
    if f == coarse.cfoHz
        x = initial; front = coarse;
    else
        o.cfoHz = f;
        [x,front] = rf47lmsbtb.btb_frontend(capture,o);
    end
    try
        result = rf47_cma_cd_core(x,front,capture,reference);
    catch failure
        if isempty(strfind(failure.message,'CMA acquisition failed'))
            rethrow(failure);
        end
        lastFailure = failure.message;
        continue;
    end
    result.method = 'CMA-BTB';
    result.dspName = 'CMA-BTB long PRBS (page-5 flow, no CD)';
    result.frequencyBranchAttempts = attempt;
    result.originalFrequencyEstimateHz = coarse.cfoHz;
    result.frequencyBranchCorrected = (f ~= coarse.cfoHz);
    result.dispersionCompensationApplied = false;
    result.processingSeconds = toc(started);
    return;
end
error('rf47_cma_btb_dsp:Synchronization', ...
    'CMA-BTB synchronization failed; window NOT counted: %s',lastFailure);
end
