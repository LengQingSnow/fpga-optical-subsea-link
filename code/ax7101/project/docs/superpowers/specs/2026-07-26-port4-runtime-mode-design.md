# Port 4 Runtime Mode Design

## Goal

Keep Ethernet port 4 in receive-and-verify mode after FPGA configuration, while
allowing Vivado Hardware Manager to switch it at run time into a continuous
gigabit PRBS31 transmit mode and back without reprogramming the FPGA.

## Control Interface

A VIO core clocked by `e4_rxc` provides one request bit:

- `0`: receive-and-verify mode (power-up default)
- `1`: PRBS31 transmit mode

The VIO also reports the active mode and the PRBS31 transmitted-frame count.
The request is not connected directly to the output mux. A mode controller
changes the active mode only at a safe Ethernet inter-frame boundary.

## Data Path

In receive mode, the existing dataset checker, camera checker, and ARP responder
continue to consume port 4 RX data. The ARP responder exclusively drives the
port 4 TX pins.

In transmit mode, a `gmii_prbs31_tx` instance clocked by `e4_rxc` drives the
port 4 TX pins. The frame format stays compatible with the existing
`gmii_prbs31_rx_checker`. The ARP responder is held reset so that it cannot
prepare or resume a partial reply while PRBS transmission owns the pins.

The receive checkers remain connected in both modes. Their counters are only
meaningful when an external source is driving port 4.

## Safe Switching

The controller starts in receive mode. A receive-to-transmit request waits until
the ARP transmitter is idle, then resets the ARP responder and enables the PRBS
transmitter. A transmit-to-receive request removes the PRBS enable, waits for
the current PRBS frame to complete, and then returns ownership to the reset,
idle ARP responder. This prevents truncated Ethernet frames.

## Verification

Simulation covers the default receive state, delayed entry while ARP is busy,
continuous PRBS transmission, delayed exit until the PRBS frame boundary, and
re-entry into receive mode. Existing PRBS and project regressions must remain
green.

Implementation must finish with nonnegative setup and hold slack, zero routing
errors, and zero DRC errors. Hardware verification must show:

1. Default mode still receives and verifies port 3 traffic on port 4.
2. VIO transmit request makes the PRBS frame counter increase.
3. Clearing the request returns to receive mode without reprogramming.

