function result = offline_make_decode_result(state, references)
%OFFLINE_MAKE_DECODE_RESULT Summarize reassembled offline AXDS objects.
empty = struct('available', false, 'data', uint8([]), ...
    'validMask', false(0, 1), 'coverage', 0, 'ber', NaN, ...
    'bitErrors', 0, 'comparedBits', 0, 'objectId', 0, 'cycle', uint32(0));
result = struct('frameCount', 0, 'crcGoodFrames', 0, ...
    'crcBadFrames', 0, 'decodedBytes', state.lastDecodedBytes, ...
    'objectCount', numel(state.objects), 'image', empty, 'waveform', empty);
if isempty(state.frames)
    return;
end
result.frameCount = state.frames.frameCount;
result.crcGoodFrames = sum(state.frames.crcOk);
result.crcBadFrames = result.frameCount - result.crcGoodFrames;
if isempty(state.objects)
    return;
end
image_index = find([state.objects.datasetType] == 1, 1, 'first');
wave_index = find([state.objects.datasetType] == 2 & ...
    [state.objects.objectId] == 1, 1, 'first');
if ~isempty(image_index)
    result.image = object_result(state.objects(image_index), references, 1, empty);
end
if ~isempty(wave_index)
    result.waveform = object_result(state.objects(wave_index), references, 2, empty);
end
end

function result = object_result(object, references, dataset_type, empty)
result = empty;
result.available = true;
result.data = uint8(object.data(:));
result.validMask = logical(object.validMask(:));
result.coverage = sum(result.validMask) / max(1, numel(result.validMask));
result.objectId = double(object.objectId);
result.cycle = uint32(object.datasetCycle);
if dataset_type == 1 && result.objectId <= numel(references.images)
    expected = uint8(references.images{result.objectId});
elseif dataset_type == 2 && result.objectId == 1
    expected = uint8(references.waveformBytes);
else
    expected = uint8([]);
end
count = min(numel(expected), numel(result.data));
mask = result.validMask(1:count);
if any(mask)
    difference = bitxor(result.data(1:count), expected(1:count));
    errors = 0;
    selected = difference(mask);
    for bit = 1:8
        errors = errors + sum(bitget(selected, bit));
    end
    result.bitErrors = errors;
    result.comparedBits = 8 * sum(mask);
    result.ber = errors / result.comparedBits;
end
end
