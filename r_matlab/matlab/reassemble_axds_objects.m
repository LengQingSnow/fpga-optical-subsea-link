function [objects, stats] = reassemble_axds_objects(axds)
%REASSEMBLE_AXDS_OBJECTS Place AXDS packet payloads at their object offsets.

objects = struct('datasetType', {}, 'sourcePort', {}, 'datasetCycle', {}, ...
    'objectId', {}, 'objectLength', {}, 'objectCrc32', {}, 'data', {}, ...
    'validMask', {}, 'conflictBytes', {}, 'packetCount', {}, ...
    'allTransportCrcOk', {});
rejected_ranges = 0;

for packet_index = 1:numel(axds.payload)
    object_length = double(axds.objectLength(packet_index));
    offset = double(axds.objectOffset(packet_index));
    payload = uint8(axds.payload{packet_index}(:));
    if offset < 0 || offset + numel(payload) > object_length
        rejected_ranges = rejected_ranges + 1;
        continue;
    end

    object_index = find_object(objects, axds.datasetType(packet_index), ...
        axds.sourcePort(packet_index), axds.datasetCycle(packet_index), ...
        axds.objectId(packet_index), axds.objectLength(packet_index));
    if object_index == 0
        object_index = numel(objects) + 1;
        objects(object_index).datasetType = axds.datasetType(packet_index);
        objects(object_index).sourcePort = axds.sourcePort(packet_index);
        objects(object_index).datasetCycle = axds.datasetCycle(packet_index);
        objects(object_index).objectId = axds.objectId(packet_index);
        objects(object_index).objectLength = axds.objectLength(packet_index);
        objects(object_index).objectCrc32 = axds.objectCrc32(packet_index);
        objects(object_index).data = zeros(object_length, 1, 'uint8');
        objects(object_index).validMask = false(object_length, 1);
        objects(object_index).conflictBytes = 0;
        objects(object_index).packetCount = 0;
        objects(object_index).allTransportCrcOk = true;
    end

    target = offset + (1:numel(payload));
    already_valid = objects(object_index).validMask(target);
    if any(already_valid)
        old_data = objects(object_index).data(target(already_valid));
        new_data = payload(already_valid);
        objects(object_index).conflictBytes = ...
            objects(object_index).conflictBytes + sum(old_data ~= new_data);
    end
    objects(object_index).data(target) = payload;
    objects(object_index).validMask(target) = true;
    objects(object_index).packetCount = objects(object_index).packetCount + 1;
    objects(object_index).allTransportCrcOk = ...
        objects(object_index).allTransportCrcOk && ...
        axds.transportCrcOk(packet_index);
end

% Merge repeated delivery cycles of the same logical object.  A long scope
% record often contains partial copies of one image or waveform; keep the
% best fragment and fill only bytes that it did not recover.
objects = merge_repeated_objects(objects);

stats.objectCount = numel(objects);
stats.rejectedPacketRanges = rejected_ranges;
stats.completeObjectCount = 0;
for object_index = 1:numel(objects)
    stats.completeObjectCount = stats.completeObjectCount + ...
        all(objects(object_index).validMask);
end
end

function merged = merge_repeated_objects(objects)
merged = objects([]);
if numel(objects) > 1
    coverage = zeros(numel(objects), 1);
    for index = 1:numel(objects)
        coverage(index) = sum(objects(index).validMask);
    end
    [~, order] = sort(coverage, 'descend');
    objects = objects(order);
end
for source_index = 1:numel(objects)
    match = 0;
    for candidate = 1:numel(merged)
        if merged(candidate).datasetType == objects(source_index).datasetType && ...
                merged(candidate).sourcePort == objects(source_index).sourcePort && ...
                merged(candidate).objectId == objects(source_index).objectId && ...
                merged(candidate).objectLength == objects(source_index).objectLength
            match = candidate;
            break;
        end
    end
    if match == 0
        merged(end + 1) = objects(source_index); %#ok<AGROW>
        continue;
    end

    target = merged(match);
    incoming = objects(source_index);
    target_valid = target.validMask;
    incoming_valid = incoming.validMask;
    fill = ~target_valid & incoming_valid;
    target.data(fill) = incoming.data(fill);
    target.validMask(fill) = true;
    overlap = target_valid & incoming_valid;
    target.conflictBytes = target.conflictBytes + incoming.conflictBytes + ...
        sum(target.data(overlap) ~= incoming.data(overlap));
    target.packetCount = target.packetCount + incoming.packetCount;
    target.allTransportCrcOk = target.allTransportCrcOk && ...
        incoming.allTransportCrcOk;
    merged(match) = target;
end
end

function index = find_object(objects, dataset_type, source_port, cycle, ...
    object_id, object_length)
index = 0;
for candidate = 1:numel(objects)
    if objects(candidate).datasetType == dataset_type && ...
            objects(candidate).sourcePort == source_port && ...
            objects(candidate).datasetCycle == cycle && ...
            objects(candidate).objectId == object_id && ...
            objects(candidate).objectLength == object_length
        index = candidate;
        return;
    end
end
end
