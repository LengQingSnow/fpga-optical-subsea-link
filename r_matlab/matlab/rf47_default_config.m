function cfg = rf47_default_config(script_dir)
%RF47_DEFAULT_CONFIG Configuration shared by the RF47 offline receiver.

if nargin < 1 || isempty(script_dir)
    script_dir = fileparts(mfilename('fullpath'));
end

project_dir = fileparts(script_dir);
cfg.scriptDir = script_dir;
cfg.projectDir = project_dir;
cfg.dataDir = fullfile(project_dir, 'data');
cfg.datasetDir = fullfile(project_dir, 'dataset2');
cfg.captureName = '';
cfg.resultPrefix = 'analysis';

cfg.symbolRateHz = 4e9;
cfg.txSamplesPerSymbol = 2;
cfg.pulseShape = 'nrz';
cfg.rrcCoefficients = double([-126, 91, 203, -282, -280, 630, ...
    346, -1371, -390, 4655, 7827, 4655, -390, -1371, 346, ...
    630, -280, -282, 203, 91, -126]);
cfg.timingPhaseCount = 32;
cfg.timingScanSymbols = 262144;
cfg.packingScanSymbols = 1048576;
cfg.resampleChunkPoints = 1048576;
cfg.maxLaneSyncErrorRate = 0.15;
cfg.timingChunkFrames = 1000;
cfg.chunkTimingScanSymbols = 65536;
cfg.chunkPackingScanSymbols = 131072;
cfg.useContinuousCdr = true;
cfg.cdrClockOffsetPpmPrior = -0.18310546875;
cfg.cdrAnchorOutlierUi = 0.125;
cfg.cdrResidualSmoothing = 0.20;
cfg.cdrMinimumAnchors = 4;
cfg.cdrScaleEstimatePoints = 1048576;
cfg.cdrResampleChunkPoints = 1048576;
cfg.dynamicFrameRelock = true;
cfg.usePostEqualizer = true;
cfg.postEqualizerTapCandidates = [1 3 5 7 9];
cfg.postEqualizerLambdaCandidates = [1e-4 1e-3 1e-2];
cfg.postEqualizerMinimumSyncFrames = 16;
cfg.postEqualizerMaximumSyncFrames = 4096;
cfg.postEqualizerMinimumTrainingSymbols = 128;
cfg.postEqualizerMinimumValidationSymbols = 128;
cfg.postEqualizerRequireCrcNonRegression = true;

cfg.syncWord = uint8([hex2dec('D5'), hex2dec('C0'), hex2dec('1A'), ...
    hex2dec('CF'), hex2dec('FC'), hex2dec('1D'), hex2dec('5A'), ...
    hex2dec('A5')]);
cfg.protocolVersion = uint8(1);
cfg.frameBytes = 512;
cfg.framePayloadEnd = 508;
cfg.maxSyncBitErrors = 8;
cfg.useBadCrcSegments = false;
cfg.runBestEffortAnalysis = true;
cfg.runKnownFrameAnalysis = true;
cfg.knownFrameMaximumPayloadBer = 0.12;
cfg.knownFrameMinimumCandidateMarginBits = 8;
cfg.knownFrameMaximumStructuralBitErrors = 8;
cfg.minimumPacketBytes = 32;
cfg.maximumUdpPayloadBytes = 1400;
cfg.maximumObjectBytes = 16 * 1024 * 1024;
cfg.maximumImagesToWrite = 5;

cfg.channelNames = {'TX0/XI', 'TX2/XQ', 'TX4/YI', 'TX6/YQ'};
end
