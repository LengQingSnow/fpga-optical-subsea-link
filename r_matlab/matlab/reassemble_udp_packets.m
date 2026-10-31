function [packets, stats] = reassemble_udp_packets(segments, frames, cfg)
%REASSEMBLE_UDP_PACKETS Rebuild each source-port UDP payload from fragments.

active = false(1, 4);
active_id = zeros(1, 4, 'uint8');
active_bytes = cell(1, 4);
active_crc_ok = true(1, 4);
active_first_frame = zeros(1, 4, 'uint32');
active_segments = cell(1, 4);

packets.portId = zeros(256, 1, 'uint8');
packets.packetId = zeros(256, 1, 'uint8');
packets.firstFrame = zeros(256, 1, 'uint32');
packets.lastFrame = zeros(256, 1, 'uint32');
packets.allFramesCrcOk = false(256, 1);
packets.segmentIndices = cell(256, 1);
packets.bytes = cell(256, 1);
packet_count = 0;
dropped_partial = 0;
ignored_bad_crc_segments = 0;

for segment_index = 1:numel(segments.payload)
    if ~segments.frameCrcOk(segment_index) && ~cfg.useBadCrcSegments
        ignored_bad_crc_segments = ignored_bad_crc_segments + 1;
        continue;
    end
    frame_index = double(segments.frameIndex(segment_index));
    if frame_index < 1 || frame_index > frames.frameCount || ...
            ~frames.segmentParseOk(frame_index)
        continue;
    end

    port = double(segments.portId(segment_index));
    packet_id = segments.packetId(segment_index);
    if segments.sop(segment_index)
        if active(port)
            dropped_partial = dropped_partial + 1;
        end
        active(port) = true;
        active_id(port) = packet_id;
        active_bytes{port} = zeros(0, 1, 'uint8');
        active_crc_ok(port) = true;
        active_first_frame(port) = uint32(frame_index);
        active_segments{port} = zeros(0, 1, 'uint32');
    end

    if ~active(port) || active_id(port) ~= packet_id
        continue;
    end
    active_bytes{port} = [active_bytes{port}; ...
        uint8(segments.payload{segment_index}(:))];
    active_segments{port} = [active_segments{port}; uint32(segment_index)];
    active_crc_ok(port) = active_crc_ok(port) && ...
        segments.frameCrcOk(segment_index);

    if numel(active_bytes{port}) > cfg.maximumUdpPayloadBytes
        active(port) = false;
        active_bytes{port} = [];
        active_segments{port} = [];
        dropped_partial = dropped_partial + 1;
        continue;
    end

    if segments.eop(segment_index)
        packet_count = packet_count + 1;
        if packet_count > numel(packets.bytes)
            packets = grow_packets(packets);
        end
        packets.portId(packet_count) = uint8(port);
        packets.packetId(packet_count) = packet_id;
        packets.firstFrame(packet_count) = active_first_frame(port);
        packets.lastFrame(packet_count) = uint32(frame_index);
        packets.allFramesCrcOk(packet_count) = active_crc_ok(port);
        packets.segmentIndices{packet_count} = active_segments{port};
        packets.bytes{packet_count} = active_bytes{port};
        active(port) = false;
        active_bytes{port} = [];
        active_segments{port} = [];
    end
end

dropped_partial = dropped_partial + sum(active);
packets.portId = packets.portId(1:packet_count);
packets.packetId = packets.packetId(1:packet_count);
packets.firstFrame = packets.firstFrame(1:packet_count);
packets.lastFrame = packets.lastFrame(1:packet_count);
packets.allFramesCrcOk = packets.allFramesCrcOk(1:packet_count);
packets.segmentIndices = packets.segmentIndices(1:packet_count);
packets.bytes = packets.bytes(1:packet_count);

stats.packetCount = packet_count;
stats.packetCountByPort = zeros(1, 4);
for port = 1:4
    stats.packetCountByPort(port) = sum(packets.portId == port);
end
stats.droppedPartialPackets = dropped_partial;
stats.ignoredBadCrcSegments = ignored_bad_crc_segments;
end

function packets = grow_packets(packets)
old_count = numel(packets.bytes);
new_count = max(256, old_count * 2);
packets.portId(new_count, 1) = uint8(0);
packets.packetId(new_count, 1) = uint8(0);
packets.firstFrame(new_count, 1) = uint32(0);
packets.lastFrame(new_count, 1) = uint32(0);
packets.allFramesCrcOk(new_count, 1) = false;
packets.segmentIndices{new_count, 1} = [];
packets.bytes{new_count, 1} = [];
end
