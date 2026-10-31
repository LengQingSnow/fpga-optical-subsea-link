function result = check_sync(selected, reference)
%CHECK_SYNC Independently verify three prefix segments against global mapping.
% Target and mapping checks reproduce the final fresh-record experiment guard.
period = size(reference,1);
shifts = zeros(3,2); quality = zeros(3,2);
segmentOutputs = zeros(3,2); segmentConjugate = false(3,2);
for k = 1:3
    first = (k-1)*10000+1;
    [~,~,mapping] = rf47lmsbtb.btb_reference_align( ...
        selected.alignedBlind(first:first+9999,:),reference,10000);
    shifts(k,:) = mod([mapping{1}.shift mapping{2}.shift]-(first-1),period);
    quality(k,:) = [mapping{1}.correlation mapping{2}.correlation];
    segmentOutputs(k,:) = [mapping{1}.output mapping{2}.output];
    segmentConjugate(k,:) = [mapping{1}.conjugate mapping{2}.conjugate];
end
mapping = selected.mapping;
globalShift = mod([mapping{1}.shift mapping{2}.shift],period);
globalQuality = [mapping{1}.correlation mapping{2}.correlation];
shiftConsistent = all(all(bsxfun(@eq,shifts,globalShift)));
signs = 2*double(reference)-1;
complexReference = [signs(:,1)+1i*signs(:,2),signs(:,3)+1i*signs(:,4)]/sqrt(2);
targetError = zeros(1,2);
for pol = 1:2
    expected = complexReference(mod((0:size(selected.target,1)-1)'+globalShift(pol),period)+1,pol);
    targetError(pol) = max(abs(selected.target(:,pol)-expected));
end
targetConsistent = all(targetError < 1e-12);
qualityPassed = all(isfinite(quality(:))) && min(quality(:)) > .2 && ...
    all(isfinite(globalQuality)) && min(globalQuality) > .2;
result = struct('consistent',shiftConsistent && targetConsistent && qualityPassed, ...
    'segmentShifts',shifts,'segmentCorrelation',quality,'globalShift',globalShift, ...
    'globalCorrelation',globalQuality,'shiftConsistent',shiftConsistent, ...
    'targetConsistent',targetConsistent,'targetMaximumError',targetError, ...
    'qualityPassed',qualityPassed,'minimumCorrelation',.2, ...
    'segmentOutputs',segmentOutputs,'segmentConjugate',segmentConjugate, ...
    'referencePeriod',period,'prefixSegments',[1 10000;10001 20000;20001 30000]);
end
