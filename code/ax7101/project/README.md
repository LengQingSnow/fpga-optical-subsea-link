# ax7101 Dataset, Camera, and Ethernet Test Design

This Vivado 2021.2 project sends the JTAG-loaded underwater-image dataset on
Ethernet port 1, the seismic-wave dataset on port 2, and dual-camera data on
port 3. Port 4 defaults to receive/check mode and can be switched at run time to
a full-rate PRBS31 transmitter with VIO. FPGA reprogramming is not required for
the port-4 mode change.

## Hardware Operation

- Port 1 transmits the underwater-image dataset over UDP.
- Port 2 transmits the seismic-wave dataset over UDP.
- Port 3 transmits both camera streams over UDP while retaining VGA output.
- Port 4 starts in receive mode and runs the dataset and camera checkers.
- Port 4 PRBS mode uses source ID 4 and a continuous gigabit PRBS31 stream.
- Mode changes wait for the active Ethernet frame to finish before changing
  ownership of the port-4 GMII transmit pins.

## Port 4 Runtime Mode

Program the FPGA once, then select receive mode:

```powershell
vivado.bat -mode batch -nolog -nojournal `
  -source scripts\set_port4_mode.tcl -tclargs rx
```

Select gigabit PRBS31 transmit mode:

```powershell
vivado.bat -mode batch -nolog -nojournal `
  -source scripts\set_port4_mode.tcl -tclargs prbs
```

The script prints `port4_tx_mode_active` and
`port4_prbs_frame_count`. An active value of `1` with an increasing frame count
confirms PRBS transmission. Receive mode is the VIO power-up default.

## Hardware Verification

With port 3 connected to port 4, capture two counter snapshots:

```powershell
vivado.bat -mode batch -nolog -nojournal `
  -source scripts\capture_dataset_loopback.tcl `
  -tclargs camera_port3_to_port4 4000
```

A passing camera loopback has increasing camera good-packet and good-frame
counters while FCS, IP, UDP, header, sequence, offset, CRC, and camera malformed
counters remain unchanged. The separate dataset checker can count camera frames
as malformed because the two application payload formats intentionally differ.

## Build And Verify

Run all self-checking simulations:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run_all_tests.ps1
```

Recreate the Vivado project when needed:

```powershell
vivado.bat -mode batch `
  -source scripts\create_project.tcl
```

Build the routed checkpoint, reports, bitstream, and probes:

```powershell
vivado.bat -mode batch `
  -source scripts\build_bitstream.tcl
```

Regenerate the dedicated GMII margin report:

```powershell
vivado.bat -mode batch `
  -source scripts\report_gmii_timing.tcl
```

Program the first connected XC7A100T through JTAG:

```powershell
vivado.bat -mode batch `
  -source scripts\program_device.tcl
```

Release files are under `bitstream`. Verification reports are under
`reports/implementation`, and retained XSim logs are under
`reports/simulation`.
