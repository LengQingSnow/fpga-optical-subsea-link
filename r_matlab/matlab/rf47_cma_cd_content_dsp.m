function [bits,bytes,recovery,packing]=rf47_cma_cd_content_dsp(capture,cfg)
% Page-6-only CD/CFO fallback; actual received CRC-valid frames select candidates.
% No BER-replay reference is used and no missing payload is synthesized.
D=5610;lambda=1550;
if isfield(cfg,'cmaCdDispersionPsNm'),D=cfg.cmaCdDispersionPsNm;end
if isfield(cfg,'cmaCdWavelengthNm'),lambda=cfg.cmaCdWavelengthNm;end
cfg.cmaCdDispersionPsNm=D;cfg.cmaCdWavelengthNm=lambda;
try
    [bits,bytes,recovery,packing]=rf47_cma_cd_content_core(capture,cfg);
    return;
catch firstFailure
    if isempty(strfind(firstFailure.message,'No CRC-valid CMA information frame')),rethrow(firstFailure);end
end
o=struct('symbolRate',4e9,'maxCfoHz',1.4e9,'lowpassHz',2.8e9, ...
    'sampleOffset',0,'carrierNotchHz',2e6,'excludeDcHz',50e6);
[~,front]=rf47lmsbtb.btb_frontend(capture,o);
frequencies=front.cfoHz+[0 -1e9 1e9 -2e9 2e9];
frequencies=frequencies(abs(frequencies)<=1.4e9);
dispersions=unique([D -D 7250 -7250 3500 -3500 9000 -9000 0],'stable');
if isfield(cfg,'cmaContentWarmWeights'),cfg=rmfield(cfg,'cmaContentWarmWeights');end
lastFailure=firstFailure;
for f=frequencies
    for d=dispersions
        if f==front.cfoHz && d==D,continue;end
        cfg.cmaCdCfoHz=f;cfg.cmaCdDispersionPsNm=d;
        try
            [bits,bytes,recovery,packing]=rf47_cma_cd_content_core(capture,cfg);
            return;
        catch ex
            if isempty(strfind(ex.message,'No CRC-valid CMA information frame')),rethrow(ex);end
            lastFailure=ex;
        end
    end
end
rethrow(lastFailure);
end
