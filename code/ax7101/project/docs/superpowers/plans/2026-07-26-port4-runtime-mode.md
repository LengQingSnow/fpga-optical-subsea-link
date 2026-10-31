# Port 4 Runtime Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a VIO-controlled, frame-safe run-time switch between port 4 receive verification and gigabit PRBS31 transmission.

**Architecture:** A focused mode controller converts the VIO request into an active ownership signal and PRBS enable. The top level multiplexes the existing ARP responder and a new PRBS transmitter onto port 4, while VIO exposes the request, active mode, and transmitted-frame count.

**Tech Stack:** Verilog, SystemVerilog, Xilinx VIO/ILA IP, Vivado 2021.2, XSim

---

### Task 1: Frame-Safe Mode Controller

**Files:**
- Create: `src/port4_runtime_mode_control.v`
- Create: `sim/tb_port4_runtime_mode_control.sv`
- Modify: `scripts/run_all_tests.ps1`

- [x] Write a test that checks power-up receive mode, waits for ARP idle before entering transmit mode, and waits for PRBS `tx_en` to drop before leaving transmit mode.
- [x] Run the new simulation and confirm it fails because the controller does not exist.
- [x] Implement a two-state synchronous controller with `request_tx`, `arp_tx_en`, `prbs_tx_en`, `active_tx_mode`, and `prbs_enable`.
- [x] Run the new simulation and confirm its PASS marker.
- [x] Add the test to the complete regression list.

### Task 2: Port 4 Transmit Multiplexing

**Files:**
- Modify: `src/ax7101_dataset_top.v`
- Create: `sim/tb_port4_runtime_mux.sv`
- Modify: `scripts/run_all_tests.ps1`

- [x] Write a mux-level test that proves receive mode selects ARP outputs and transmit mode selects PRBS outputs without mixed bytes.
- [x] Add a port 4 `gmii_prbs31_tx` instance using source ID 4 and `e4_rxc`.
- [x] Route the ARP responder through internal GMII wires instead of directly to the pins.
- [x] Drive `e4_txen`, `e4_txer`, and `e4_txd` from the active-mode mux.
- [x] Hold only the ARP responder in reset while transmit mode is active; leave receive checkers unchanged.
- [x] Run the controller, mux, PRBS, and full simulation regressions.

### Task 3: VIO Integration

**Files:**
- Modify: `scripts/create_project.tcl`
- Modify: `src/ax7101_dataset_top.v`
- Create: `scripts/set_port4_mode.tcl`

- [x] Create a VIO IP with one 1-bit output initialized to zero and two inputs for active mode and 32-bit PRBS frame count.
- [x] Instantiate the VIO on `e4_rxc` and connect it to the mode controller.
- [x] Add a hardware script that sets `rx` or `prbs` and prints requested mode, active mode, and frame count.
- [x] Regenerate the project and verify VIO and the four existing ILA cores are present.

### Task 4: Build and Hardware Verification

**Files:**
- Retain: `reports/simulation/*`
- Retain: `reports/implementation/*`
- Retain: `reports/hardware/*`
- Archive: `bit_archive/AX7101_DUAL_DATASET_UDP_port4_runtime_mode_verified.*`

- [x] Run all simulations and require every PASS marker.
- [x] Generate the bitstream and require nonnegative WNS/WHS, fully routed nets, and zero DRC errors.
- [x] Program once and capture default receive-mode counters with port 3 connected to port 4.
- [x] Set VIO to PRBS mode without programming and confirm active mode plus frame count growth.
- [x] Set VIO back to receive mode without programming and confirm port 3 to port 4 good-packet counters resume.
- [x] Archive the verified bitstream, probes file, and routed checkpoint.
- [x] Delete only transient `.sim_*`, `.sim_work`, and `.Xil` directories.
