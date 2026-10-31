function [result, state] = rf47_lms_btb_dsp(capture, reference, state)
%RF47_LMS_BTB_DSP Calibration-selected, prefix-trained LMS-BTB processing.
% [RESULT, STATE] = RF47_LMS_BTB_DSP(CAPTURE, REFERENCE, STATE) accepts
% CAPTURE.channels (1000000-by-4 XI/XQ/YI/YQ) at 40 GSa/s and REFERENCE.laneBits
% or an N-by-4 binary matrix in canonical TX0/TX2/TX4/TX6 order. DP-QPSK is
% fixed at 4 Gbaud. STATE is optional diagnostic bookkeeping, never weights.
%
% LMS core from coherent_btb_20260916_retest_0918: choose blind
% acquisition on the first 30000 symbols, validate three independent prefix
% segments, fit 571/811/1051-tap real FSE weights through global symbol 49000,
% resolve duplicate-polarization acquisition and track carrier phase using
% prefix-trained centroids. A bounded CPR/noise-prediction menu and the FSE
% length are selected only on global calibration symbols 50001:59000.
% Test symbols 61061:98883 never select settings or fit weights. All test
% bits count, including errors. Longer processing is deliberately allowed.
% No hardware, file, figure, global path, or saved-experiment dependencies.
% MATLAB R2016a compatible; all processing helpers are package qualified.

started = tic;
if nargin < 3 || isempty(state), state = struct(); end
if ~isstruct(state) || numel(state) ~= 1
    error('rf47_lms_btb_dsp:State', 'State must be an empty or scalar structure.');
end
if nargin < 2
    error('rf47_lms_btb_dsp:Reference', 'The current four-lane replay reference is required.');
end
bits = validate_inputs(capture, reference);
o = struct('symbolRate',4e9,'maxCfoHz',1.4e9,'lowpassHz',2.8e9, ...
    'sampleOffset',0,'tapCount',11,'trainSymbols',30000, ...
    'cmaSteps',[.08 .04 .02 .01],'initialAngle',0,'phaseWindow',641, ...
    'fineCfoRangeHz',15e6,'lmsSteps',[.6 .4 .2 .1],'carrierNotchHz',2e6);
q = struct('tapCount',571,'trainSymbols',49000,'lowpassHz',3.9e9, ...
    'floor',3e-4,'sampleOffset',0);

[bootstrap, acquisition] = rf47lmsbtb.acquire(capture, bits, o);
s = bootstrap;
sync = rf47lmsbtb.check_sync(s, bits);
recovery = struct('used',false);
jointRecovery = struct('used',false);
if ~sync.consistent
    [s, recovery] = rf47lmsbtb.recover_prefix_mapping(capture, bits, bootstrap);
    sync = rf47lmsbtb.check_sync(s, bits);
end
if ~sync.consistent
    [s, recovery] = rf47lmsbtb.recover_prefix_mapping(capture, bits, bootstrap, -3:3);
    sync = rf47lmsbtb.check_sync(s, bits);
end
if ~sync.consistent
    % Last-resort synchronization only: four received real features plus DC;
    % add adjacent half-symbol taps only if needed (12 real features).
    % Cross-fit three prefix blocks. Final LMS reuses the raw capture,
    % never these projected synchronization observations. Same guard applies.
    [s, jointRecovery] = rf47lmsbtb.recover_joint_prefix(capture, bits, bootstrap);
    sync = rf47lmsbtb.check_sync(s, bits);
end
if ~sync.consistent
    error('rf47_lms_btb_dsp:ReferenceSync', ...
        ['Prefix synchronization failed independent segment/global-target checks. ' ...
        'Correlations %.3f/%.3f; minimum segment %.3f.'], ...
        sync.globalCorrelation(1), sync.globalCorrelation(2), ...
        min(sync.segmentCorrelation(:)));
end
carrierTracking = struct('method','validated blind acquisition phase', ...
    'usesHoldoutReference',false);
if jointRecovery.used
    % The joint receiver was validated in the original blind phase frame.
    % Do not overwrite it with a PLL fitted to a duplicate/distorted CMA arm.
    carrierTracking.method = 'joint-prefix synchronization / retained blind acquisition phase';
elseif recovery.used || ~acquisition.levelCalibrationUsed
    % Preserve the already validated route when CMA independently resolves
    % both polarizations. A duplicate-output rescue needs the stronger PLL
    % before the widely linear FSE, not an output-only quadrant correction.
    [s.phase, carrierTracking] = rf47lmsbtb.track_template_phase(capture, bootstrap, s);
end
% The acquisition observations are no longer needed by the LMS fit.
s = rmfield(s, 'alignedBlind');
clear bootstrap;
% Start with the consistently best validated long FSE. A preset calibration
% quality gate avoids repeating two expensive fits on already clean records;
% difficult records still compare all three lengths. No test metrics decide.
tapMenu = [1051 811 571];
coreTrials = zeros(numel(tapMenu),11);
postTrials = cell(numel(tapMenu),1);
bestScore = [Inf Inf]; selectedCore = 0;
for candidateIndex = 1:numel(tapMenu)
    candidateOptions = q;
    candidateOptions.tapCount = tapMenu(candidateIndex);
    candidateCore = rf47lmsbtb.fit_channel_lms(capture, s, candidateOptions);
    [candidateOutput, candidatePost] = rf47lmsbtb.calibrate_post_dsp(candidateCore);
    candidateErrors = candidatePost.calibrationErrorsByLane;
    score = [sum(candidateErrors) candidatePost.calibrationMse];
    coreTrials(candidateIndex,:) = [candidateOptions.tapCount score candidateErrors ...
        candidatePost.calibrationEvm candidatePost.cprWindow candidatePost.predictorOrder];
    postTrials{candidateIndex} = candidatePost;
    if score(1)<bestScore(1) || (score(1)==bestScore(1) && score(2)<bestScore(2))
        bestScore=score;selectedCore=candidateIndex;
        r=candidateCore;z=candidateOutput;selectedOptions=candidateOptions;post=candidatePost;
    end
    if candidateIndex==1 && score(1)==0 && score(2)<=.01
        break;
    end
end
coreTrials=coreTrials(1:candidateIndex,:);
postTrials=postTrials(1:candidateIndex);
if selectedCore==0
    error('rf47_lms_btb_dsp:Calibration','No finite calibration candidate was found.');
end
q=selectedOptions;
clear candidateCore candidateOutput;
firstGlobal = 61061; lastGlobal = 98883;
first = firstGlobal-r.offset; last = lastGlobal-r.offset;
if first <= r.trainCount || first < 1 || last > size(z,1)
    error('rf47_lms_btb_dsp:Holdout', 'The fixed independent test interval is unavailable.');
end
if any(~isfinite(z(:)))
    error('rf47_lms_btb_dsp:Finite', 'The equalized samples contain nonfinite values.');
end
m = rf47lmsbtb.btb_metrics(z, r.target, first, last);
m.shape = rf47lmsbtb.lms_cluster_shape(z, r.target, first, last);
m.meanAxisRatio = mean(m.shape.axisRatio,1);
% Metrics count the complete test interval; constellation is a display sample.
m.firstSymbol = firstGlobal; m.lastSymbol = lastGlobal;
m.firstLocalSymbol = first; m.lastLocalSymbol = last;
m.totalErrors = sum(m.errorsByLane); m.totalBits = sum(m.bitsByLane);
m.errorBitsByLane = m.errorsByLane; m.comparedBitsByLane = m.bitsByLane;
m.txLaneIds = [0 2 4 6]; m.laneLabels = {'TX0 / XI','TX2 / XQ','TX4 / YI','TX6 / YQ'};

options = q;
options.symbolRateHz = 4e9; options.sampleRateHz = 40e9;
options.acquisition = s.o;
options.acquisitionAngles = [0 .4 .8 1.2];
options.acquisitionSources = [1 2 3]; options.acquisitionWindows = [33 129 513];
options.cprMethod = post.cprMethod; options.cprWindow = post.cprWindow;
options.predictorOrder = post.predictorOrder; options.predictorAlpha = post.predictorAlpha;
options.predictorRidge = post.predictorRidge;
options.tapMenu = tapMenu; options.calibrationGlobalSymbols = [50001 59000];
options.testGlobalSymbols = [firstGlobal lastGlobal];
options.earlyAcceptCalibrationMse = .01;
options.pipelineVersion = 'btb-20260916-calibrated-fse-post-v4-jointfir';
front = compact_front(r.front);
diagnostics = struct('acquisition',acquisition,'synchronization',sync, ...
    'mappingRecovery',recovery,'jointMappingRecovery',jointRecovery,'carrierTracking',carrierTracking, ...
    'front',front,'trainingMse',r.trainMse,'trainingSymbols',r.trainCount, ...
    'trainingLastGlobalSymbol',q.trainSymbols,'symbolOffset',r.offset, ...
    'predictorTrainingSymbols',r.trainCount, ...
    'predictorLookAheadSymbols',post.lookAheadSymbols, ...
    'calibration',struct('selectedCore',selectedCore,'coreTrials',coreTrials, ...
        'trialColumns',{{'tapCount','errors','mse','errorXI','errorXQ','errorYI','errorYQ', ...
        'evmX','evmY','cprWindow','predictorOrder'}},'postTrials',{postTrials}, ...
        'selectionGlobalSymbols',[50001 59000],'usesHoldoutReference',false, ...
        'earlyAcceptCalibrationMse',.01,'evaluatedCores',candidateIndex), ...
    'evaluationIsIndependentHoldout',true,'weightsRefitted',true);
result = struct('metrics',m,'options',options,'diagnostics',diagnostics, ...
    'processingSeconds',toc(started),'method',sprintf('LMS-BTB %d',q.tapCount), ...
    'dspName',sprintf('LMS-BTB %d',q.tapCount),'referenceAligned',true,'converged',true, ...
    'validity',struct('valid',true,'reason',''), ...
    'constellation',m.constellation,'equalizedSymbols',m.constellation, ...
    'errorBitsByLane',m.errorsByLane,'comparedBitsByLane',m.bitsByLane, ...
    'errorsByLane',m.errorsByLane,'bitsByLane',m.bitsByLane, ...
    'berByLane',m.berByLane,'ber',m.ber,'evmRms',m.evmRms, ...
    'meanAxisRatio',m.meanAxisRatio,'txLaneIds',[0 2 4 6], ...
    'trainingSymbols',r.trainCount,'trainingLastGlobalSymbol',q.trainSymbols, ...
    'symbolOffset',r.offset,'sampleOffset',q.sampleOffset, ...
    'frequencyOffsetHz',[front.cfoHz front.cfoHz], ...
    'referenceCorrelation',sync.globalCorrelation, ...
    'pointCount',size(capture.channels,1),'testGlobalSymbols',[firstGlobal lastGlobal]);
records = 0;
if isfield(state,'processedRecords') && isnumeric(state.processedRecords) && ...
        isscalar(state.processedRecords) && isfinite(state.processedRecords) && ...
        state.processedRecords >= 0
    records = floor(state.processedRecords);
end
% No capture arrays, target sequence, training weights or matrices are cached.
state = struct('processedRecords',records+1,'pipelineVersion',options.pipelineVersion, ...
    'lastProcessingSeconds',result.processingSeconds,'lastAcquisitionAngle',s.o.initialAngle, ...
    'lastPhaseSource',acquisition.phaseSource,'lastPhaseWindow',acquisition.phaseWindow, ...
    'lastReferenceShifts',sync.globalShift);
end

function bits = validate_inputs(capture, reference)
if ~isstruct(capture) || numel(capture) ~= 1 || ...
        ~isfield(capture,'channels') || ~isfield(capture,'sampleRateHz')
    error('rf47_lms_btb_dsp:Capture', 'Capture requires channels and sampleRateHz.');
end
v = capture.channels;
if ~isnumeric(v) || ~isreal(v) || ~ismatrix(v) || ...
        size(v,1) ~= 1000000 || size(v,2) ~= 4 || any(~isfinite(v(:)))
    error('rf47_lms_btb_dsp:Capture', 'Exactly 1000000 finite real samples on four channels are required.');
end
fs = capture.sampleRateHz;
if ~isnumeric(fs) || ~isreal(fs) || ~isscalar(fs) || ~isfinite(fs) || abs(fs-40e9) > 1
    error('rf47_lms_btb_dsp:SampleRate', 'The fixed LMS-BTB configuration requires 40 GSa/s.');
end
if isstruct(reference) && numel(reference) == 1 && isfield(reference,'laneBits')
    bits = reference.laneBits;
else
    bits = reference;
end
if ~(isnumeric(bits) || islogical(bits)) || ~isreal(bits) || ~ismatrix(bits) || ...
        size(bits,2) ~= 4 || size(bits,1) < 32 || any(~isfinite(bits(:))) || ...
        any(bits(:) ~= 0 & bits(:) ~= 1)
    error('rf47_lms_btb_dsp:Reference', ...
        'Reference must contain at least 32 rows of four binary TX0/TX2/TX4/TX6 lanes.');
end
bits = double(bits);
if any(sum(bits,1) == 0 | sum(bits,1) == size(bits,1))
    error('rf47_lms_btb_dsp:Reference', 'Every reference lane must contain both bit values.');
end
end

function front = compact_front(front)
if isfield(front,'samplePositions'), front = rmfield(front,'samplePositions'); end
end
