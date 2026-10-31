# ax7101 JTAG DDR Dual-Dataset UDP Design

## Objective

Extend the existing ax7101 three-transmitter test project into a two-channel
dataset source:

- Ethernet port 1 continuously transmits all 45 raw 320x240 RGB888 underwater
  images at gigabit line rate.
- Ethernet port 2 continuously transmits the 14,400-sample, signed 16-bit
  Tohoku event waveform at gigabit line rate.
- The compact binary datasets are loaded after FPGA programming through
  JTAG-to-AXI and stored in the board's 1 GB DDR3.
- Ethernet port 4 provides sequential local loopback verification for ports 1
  and 2 before the transmitters are connected to the KU115 receiver.
- Ethernet port 3 does not transmit data in this design.

## Memory Map

The DDR3 byte-address map is:

| Address | Size | Purpose |
|---:|---:|---|
| `0x00000000` | 4 KiB | Descriptor/control block |
| `0x00100000` | 10,368,000 B | 45 raw RGB888 images |
| `0x02000000` | 28,800 B | Event waveform |

Image `N` starts at `0x00100000 + (N-1)*230400`. Each pixel is stored as
three bytes in R, G, B order. The waveform contains 14,400 samples in original
sample order; each signed 16-bit value is stored high byte first.

The descriptor is written last. It contains versioned magic, image and waveform
base/length values, one CRC32 per image, the waveform CRC32, and independent
image/waveform ready flags. A transmitter cannot access a region until its
ready flag is valid.

## JTAG Loading

A Xilinx JTAG-to-AXI master and AXI interconnect share the MIG DDR3 AXI slave
with one FPGA read scheduler. The host loader:

1. Parses the 45 `*_raw.mem` files in numeric order.
2. Converts every 24-bit line into compact R, G, B bytes.
3. Parses `waveform_bhz_int16.mem` into high-byte-first samples.
4. Calculates reflected Ethernet-style CRC32 for every image and the waveform.
5. Clears both ready flags.
6. Writes data in bounded AXI bursts.
7. Reads the data back and checks it byte-for-byte.
8. Writes descriptors and ready flags only after verification succeeds.

Partial or failed loading leaves the affected ready flag clear.

## Network Configuration

| Item | Port 1 | Port 2 |
|---|---|---|
| Source MAC | `00:0A:35:02:FE:C1` | `00:0A:35:02:FE:C2` |
| Source IPv4 | `192.168.0.101` | `192.168.0.102` |
| Destination IPv4 | `192.168.0.17` | `192.168.0.18` |
| UDP source/destination port | `8080` | `8080` |

Transmitters resolve the destination MAC through ARP and generate valid
Ethernet FCS, IPv4 header checksum, and UDP checksum. In local loopback mode,
port 4 answers ARP for both destination IP addresses using the MAC addresses
expected by the KU115 ports. This keeps the transmitted frames identical
between ax7101 loopback and final KU115 operation.

## Dataset Packet Format

Every UDP payload is 1,400 bytes:

```text
32-byte AXDS header | up to 1,368 dataset bytes | zero padding
```

All multi-byte header fields use network byte order.

| Offset | Bytes | Field |
|---:|---:|---|
| 0 | 4 | Magic `AXDS` |
| 4 | 1 | Version `1` |
| 5 | 1 | Type: `1=image`, `2=waveform` |
| 6 | 1 | Source port: `1` or `2` |
| 7 | 1 | Flags: bit0=start, bit1=end |
| 8 | 4 | Dataset cycle number |
| 12 | 2 | Object ID: image 1-45 or waveform 1 |
| 14 | 2 | Valid dataset bytes in this packet |
| 16 | 4 | Per-port UDP packet sequence |
| 20 | 4 | Byte offset inside the object |
| 24 | 4 | Complete object length |
| 28 | 4 | Complete object CRC32 |

An image ends after exactly 230,400 valid bytes. Image 45 is followed by image
1 with the cycle number incremented. The waveform ends after exactly 28,800
valid bytes and then repeats with its cycle number incremented.

## Data Path

The MIG AXI user clock is the common DDR/JTAG/read-scheduler domain. A burst
read scheduler alternately fills two asynchronous byte FIFOs. Port packetizers
consume the FIFOs in their 125 MHz GMII domain and use ping-pong packet buffers
so checksum preparation for one packet overlaps transmission of the other.

If a FIFO cannot supply a complete packet, the packet is not transmitted. An
underflow counter increments and the current object restarts from byte offset
zero after data becomes available. Link loss also restarts the current object.

## Port 4 Verification

Port 4:

- responds to ARP for `192.168.0.17` and `192.168.0.18`;
- accepts the corresponding UDP frames;
- validates Ethernet FCS, IPv4 checksum, UDP checksum and the AXDS header;
- tracks packet sequence, object ID, byte offset and valid length;
- accumulates object CRC32 and compares it at each object end;
- keeps separate image and waveform counters in ILA.

Cable switching can increment a link-transition/RX_ER diagnostic counter, but
formal pass/fail uses counter deltas measured after link negotiation.

## Verification

Self-checking simulations cover:

- MEM-to-binary conversion and CRC values;
- exact AXDS header encoding;
- image boundary, image 45-to-1 wrap and waveform wrap;
- Ethernet/IPv4/UDP checksum and FCS generation;
- ARP request/reply behavior;
- independent port flow and restart behavior;
- port 4 source/type/sequence/offset/object-CRC checking;
- burst scheduler fairness and no FIFO underflow at sustained dual-port rate.

The Vivado release must have zero DRC errors, nonnegative setup and hold slack,
positive GMII timing margin, and generated bit, probes and routed checkpoint.
Hardware acceptance consists of JTAG load/readback, then `1->4` and `2->4`
loopback captures with increasing good-object counts and zero protocol,
sequence, offset, object-CRC and underflow error deltas.
