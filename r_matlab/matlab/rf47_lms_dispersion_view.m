function [view, dispersion, state] = rf47_lms_dispersion_view(capture, reference, options, state)
%RF47_LMS_DISPERSION_VIEW Preserve page-5 CD estimation, replace its equalizer.
if nargin<3, options=struct(); end
if nargin<4, state=[]; end %#ok<NASGU>
if ~isfield(options,'symbolRateHz'),options.symbolRateHz=4e9;end
if isempty(reference)
    [compensated,dispersion]=auto_dispersion_compensate_capture(capture,options);
    mode='live';
else
    cd_options=struct('symbolRateHz',options.symbolRateHz, ...
        'scanPointCount',32768,'coarseGridPsNm',-9500:500:-5500, ...
        'refineStepPsNm',100,'refineHalfRangePsNm',500);
    [compensated,dispersion]=auto_reference_cd_compensate_capture(capture,reference,cd_options);
    mode='replay';
end
view=rf47_lms_equalize(compensated,reference, ...
    struct('symbolRateHz',options.symbolRateHz,'mode',mode));
view.pointCount=size(capture.channels,1);
view.compensatedPointCount=size(compensated.channels,1);
view.dispersionDiagnostics=dispersion;
view.dspName=[view.dspName ' + CD'];
state=struct('dispersionPsNm',dispersion.dispersionPsNm, ...
    'frequencyOffsetHz',view.frequencyOffsetHz,'method',view.dspName,'updatedAt',now);
end
