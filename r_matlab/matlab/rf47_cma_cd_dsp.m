function [result, state] = rf47_cma_cd_dsp(capture, reference, state, options)
%RF47_CMA_CD_DSP Page 5: frequency correction, CD inverse, blind short CMA.
% The reference resolves prefix ambiguities only. Taps are blind CMA and
% reported BER uses held-out symbols 60001:95000, never parameter selection.
% Default CD is nominal 330 km * 17 ps/nm/km, not a measured fiber length.
if nargin<3 || isempty(state), state=struct(); end
if nargin<4, options=struct(); end
started=tic;
nominal=5610; if isfield(options,'dispersionPsNm'),nominal=options.dispersionPsNm;end
lambda=1550; if isfield(options,'wavelengthNm'),lambda=options.wavelengthNm;end
assert(isscalar(nominal) && isfinite(nominal) && abs(nominal)<=20000,'Invalid total dispersion');
assert(isscalar(lambda) && lambda>=1450 && lambda<=1650,'Invalid wavelength');
o=struct('symbolRate',4e9,'maxCfoHz',1.4e9,'lowpassHz',2.8e9, ...
 'sampleOffset',0,'carrierNotchHz',2e6,'excludeDcHz',50e6);
[initial, coarse]=rf47lmsbtb.btb_frontend(capture,o);
% Fourth-power CFO can choose a clock-related Rs/4 alias. Resolve only by
% consistent prefix synchronization; do not choose from held-out BER.
freq=coarse.cfoHz+[0 -1e9 1e9 -2e9 2e9];
freq=freq(abs(freq)<=o.maxCfoHz);
dispersion=[nominal -nominal 7250 -7250 3500 -3500 9000 -9000 0];
if isfield(state,'dispersionPsNm') && isfield(state,'nominalDispersionPsNm') && ...
 state.nominalDispersionPsNm==nominal
 dispersion=[state.dispersionPsNm dispersion];
end
dispersion=unique(dispersion,'stable');
lastFailure='No valid prefix'; attempts=0; found=false;
% Try nominal/cached CD and its conjugate-sign alternative first. Only
% broaden CD search if both fail for every possible CFO branch.
for stage=1:2
 if stage==1, indices=1:min(2,numel(dispersion)); else, indices=3:numel(dispersion); end
 for f=freq
  if f==coarse.cfoHz, x=initial; front=coarse;
  else, o.cfoHz=f; [x,front]=rf47lmsbtb.btb_frontend(capture,o); end
  for k=indices
   attempts=attempts+1;
   try
    corrected=rf47_cma_cd_filter(x,8e9,dispersion(k),lambda);
    candidate=rf47_cma_cd_core(corrected,front,capture,reference);
    result=candidate; chosen=dispersion(k); found=true; break;
   catch ex
    if isempty(strfind(ex.message,'CMA acquisition failed')), rethrow(ex); end
    lastFailure=ex.message;
   end
  end
  if found,break;end
 end
 if found,break;end
end
assert(found,['CMA-CD synchronization failed; window NOT counted: ' lastFailure]);
state=struct('dispersionPsNm',chosen,'nominalDispersionPsNm',nominal, ...
 'wavelengthNm',lambda,'frequencyOffsetHz',front.cfoHz);
result.dispersion=state;
result.dspName='CMA + CD (15 taps)';
result.cdSearchAttempts=attempts;
result.processingSeconds=toc(started);
end
