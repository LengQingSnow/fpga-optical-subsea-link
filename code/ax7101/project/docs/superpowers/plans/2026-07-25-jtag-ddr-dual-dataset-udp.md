# ax7101 JTAG DDR Dual-Dataset UDP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Load 45 raw underwater images and one earthquake waveform into
ax7101 DDR3 through JTAG, then continuously transmit them as checksummed UDP
dataset frames through Ethernet ports 1 and 2 with port 4 loopback checking.

**Architecture:** A MIG DDR3 AXI slave is shared by JTAG-to-AXI and a dual-feed
burst reader. Two async FIFOs feed independent 125 MHz UDP packetizers. Port 4
implements ARP and a dataset-aware UDP checker with ILA counters.

**Tech Stack:** Verilog/SystemVerilog, Python, Vivado/XSim 2021.2, MIG 7 Series,
JTAG-to-AXI, AXI Interconnect, Artix-7 XC7A100T, RTL8211EG GMII.

---

### Task 1: Dataset Conversion And Golden Metadata

**Files:**
- Create: `tools/prepare_dataset.py`
- Create: `sim/generated/image_manifest.mem`
- Create: `sim/generated/image_sample.bin`
- Create: `sim/generated/waveform.bin`
- Test: `tests/test_prepare_dataset.py`

- [ ] Write tests that parse RGB888 and signed-int16 MEM lines, require numeric
  image ordering, verify exact byte order, and compare CRC32 against Python
  `zlib.crc32`.
- [ ] Run `python -m unittest tests.test_prepare_dataset -v` and confirm failure
  because `tools.prepare_dataset` does not exist.
- [ ] Implement strict parsers, compact binary output, per-object CRC32 and a
  JSON/hex manifest with fixed DDR addresses.
- [ ] Re-run the Python tests and require all cases to pass.
- [ ] Generate deterministic simulation subsets and full host-side metadata.

### Task 2: AXDS Packet Metadata Generator

**Files:**
- Create: `src/dataset_packet_cursor.v`
- Create: `sim/tb_dataset_packet_cursor.sv`
- Modify: `scripts/run_all_tests.ps1`

- [ ] Write a failing self-checking test for 1,368-byte packet segmentation,
  start/end flags, offsets, image 45-to-1 wrap, cycle increment and waveform
  wrap.
- [ ] Run XSim and confirm failure because the cursor module is absent.
- [ ] Implement independent image/waveform cursors using the descriptor inputs.
- [ ] Run the cursor test and require exact metadata and wrap behavior.

### Task 3: Dataset UDP Frame Generator

**Files:**
- Create: `src/internet_checksum.v`
- Create: `src/dataset_udp_tx.v`
- Create: `sim/tb_dataset_udp_tx.sv`
- Modify: `scripts/run_all_tests.ps1`

- [ ] Write a failing test that checks ARP, preamble, MAC addresses, IPv4,
  1,400-byte UDP payload, AXDS header, UDP checksum, FCS and minimum IFG.
- [ ] Confirm the test fails because the new modules are absent.
- [ ] Implement ARP cache/request handling and ping-pong UDP packet preparation.
- [ ] Require valid nonzero UDP checksum and byte-exact frames for both ports.
- [ ] Run all transmitter tests and preserve the existing PRBS regressions.

### Task 4: Port 4 Dataset Loopback Checker

**Files:**
- Create: `src/dataset_udp_rx_checker.v`
- Create: `src/dual_ip_arp_responder.v`
- Create: `sim/tb_dataset_udp_loopback.sv`
- Modify: `scripts/run_all_tests.ps1`

- [ ] Write failing loopback tests for port/source identification, packet
  sequence, object offsets, full-object CRC, IP/UDP/FCS failures and ARP replies
  for both destination IPs.
- [ ] Confirm failure because the checker and responder do not exist.
- [ ] Implement streaming parsing and separate image/waveform counters.
- [ ] Inject each error class and require only its intended counter to change.

### Task 5: DDR Read Scheduler And FIFO Boundaries

**Files:**
- Create: `src/axi_dataset_read_scheduler.v`
- Create: `src/async_byte_fifo.v`
- Create: `sim/tb_axi_dataset_read_scheduler.sv`
- Modify: `scripts/run_all_tests.ps1`

- [ ] Write a failing AXI-memory-model test for descriptor polling, alternating
  bursts, exact address progression, wrap, ready isolation and restart.
- [ ] Confirm the test fails because the scheduler is absent.
- [ ] Implement one AXI4 read master with two per-port FIFOs and fair servicing.
- [ ] Stress both consumers at gigabit byte rates and require no starvation.

### Task 6: MIG And JTAG AXI Integration

**Files:**
- Copy/adapt: `ip/ddr3/ddr3.xci`
- Create: `scripts/create_memory_subsystem.tcl`
- Create: `src/ax7101_dataset_top.v`
- Create: `constraints/ax7101_dataset.xdc`
- Modify: `scripts/create_project.tcl`

- [ ] Recreate the board-verified 32-bit DDR3 MIG configuration with AXI
  enabled and add JTAG-to-AXI plus a two-master AXI interconnect.
- [ ] Add all DDR3 package pins from the ALINX reference constraints unchanged.
- [ ] Integrate reset, MDIO, ports 1/2 transmitters, disabled port 3, port 4
  checker, CDC FIFOs and memory readiness diagnostics.
- [ ] Run elaboration and synthesis; require no inferred latches, missing clocks
  or unconstrained internal endpoints.

### Task 7: JTAG Loader And Readback

**Files:**
- Create: `scripts/load_dataset_jtag.tcl`
- Create: `tools/load_dataset_jtag.py`
- Test: `tests/test_jtag_loader_chunks.py`

- [ ] Write failing host tests for AXI burst chunking, byte-to-beat packing,
  address alignment, descriptor-last ordering and failure-safe ready flags.
- [ ] Implement Python data preparation and Tcl transaction generation.
- [ ] Program, wait for MIG calibration, clear ready, write image/waveform
  regions, read back and compare, then publish descriptors and ready flags.
- [ ] Produce a machine-readable load report with byte counts, CRCs and elapsed
  time.

### Task 8: ILA, Build And Timing Closure

**Files:**
- Modify: `scripts/create_project.tcl`
- Modify: `scripts/build_bitstream.tcl`
- Create: `scripts/report_dataset_timing.tcl`
- Generate: `bitstream/ax7101_dual_dataset_udp.bit`
- Generate: `bitstream/ax7101_dual_dataset_udp.ltx`

- [ ] Configure ILA probes for MIG calibration, ready flags, DDR/FIFO
  diagnostics, per-port packet/object counters and all port 4 error counters.
- [ ] Run the complete clean XSim regression.
- [ ] Run synthesis, placement, routing, DRC and bit generation.
- [ ] Require WNS/WHS nonnegative, zero route errors, zero DRC errors and
  positive TX1/TX2/RX4 GMII setup/hold margins.

### Task 9: Hardware Loopback Acceptance

**Files:**
- Create: `scripts/capture_dataset_loopback.tcl`
- Create: `reports/hardware/dataset_load_report.json`
- Retain: `reports/hardware/port1_image_*.csv`
- Retain: `reports/hardware/port2_waveform_*.csv`

- [ ] Program the release bit and load/read back both datasets through JTAG.
- [ ] Connect port 1 to port 4 and capture two stable windows; require image
  packet/object counters to increase with zero error deltas.
- [ ] Connect port 2 to port 4 and repeat for the waveform.
- [ ] Record hashes, timing, tested byte counts and BER/error results.

### Task 10: Documentation And Cleanup

**Files:**
- Modify: `README.md`
- Create: `docs/JTAG_DDR_UDP_TEST_GUIDE.md`

- [ ] Document memory map, packet format, loader command, ILA probes, cable
  sequence and result interpretation.
- [ ] Remove `.Xil`, simulation work directories, journals, failed build logs
  and duplicate generated IP while retaining source, project, tests, reports,
  captures, checkpoints, bit and ltx.
