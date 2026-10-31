function catalog = build_known_axds_catalog(references)
%BUILD_KNOWN_AXDS_CATALOG Describe the deterministic ax7101 dataset streams.

catalog = repmat(struct(), 2, 1);

catalog(1).portId = uint8(1);
catalog(1).datasetType = uint8(1);
catalog(1).objectCount = 45;
catalog(1).objectBytes = references.images(:);
catalog(1).objectLengths = zeros(45, 1, 'uint32');
catalog(1).objectCrc32 = zeros(45, 1, 'uint32');
for object_index = 1:45
    bytes = uint8(catalog(1).objectBytes{object_index}(:));
    catalog(1).objectLengths(object_index) = uint32(numel(bytes));
    catalog(1).objectCrc32(object_index) = crc32_ieee(bytes);
end

catalog(2).portId = uint8(2);
catalog(2).datasetType = uint8(2);
catalog(2).objectCount = 1;
catalog(2).objectBytes = {uint8(references.waveformBytes(:))};
catalog(2).objectLengths = uint32(numel(references.waveformBytes));
catalog(2).objectCrc32 = crc32_ieee(references.waveformBytes);

for port = 1:2
    catalog(port).maximumDataBytes = 1368;
    packet_counts = ceil(double(catalog(port).objectLengths) / ...
        catalog(port).maximumDataBytes);
    catalog(port).packetsPerObject = packet_counts(:);
    catalog(port).packetsPerCycle = sum(packet_counts);
end
end
