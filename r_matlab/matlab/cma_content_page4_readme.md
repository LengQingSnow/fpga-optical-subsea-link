# Fourth page: CMA information decoding

Start `start_cma_content_gui` from this MATLAB directory. RF47 must be in
QSFP information mode, with BER replay OFF. The entry point only reads
hardware status: it does not restart replay or reprogram an FPGA.

The fourth tab is `CMA-信息解调`: three received underwater images above one
seismic trace. Other tabs retain their existing DSP and state.

Only this page acquires a 10M-point, four-channel, 40 GSa/s single record.
The scope is stopped while processing. Processing uses overlapping 1M
blocks (50k overlap), short blind CMA with complex initialization/decorrelation, carrier
phase tracking, sync-based bit mapping, and whole-frame CRC verification.
Different blind candidates may contribute **complete CRC-correct frames**;
no bit voting, reference substitution, CRC repair, or bad-frame payload is
used. Frame sequences are joined across processing blocks before UDP parsing.
Residual ISI is refined by a 3/7/15/31-tap real FIR trained exclusively on
CRC-verified received frames, with alternating frames held out for MSE checks.
An additional low-frequency basis (past/future one-pole averages with
16/64/256/1024-symbol time constants) compensates baseline wander; it uses
the same received-only training labels. Predictions are not replaced by labels.
Only newly CRC-valid complete frames enter the existing candidate union.
Good CMA weights may be retried only inside the same simultaneous scope
record; they are reset for every capture.
The verified capture-local weights are now tried first; all original blind
initializations remain available if they do not cover the complete frame span.
Candidate search no longer stops just because its CRC count is within two
frames of the expected count. It requires consecutive sync positions and
sequence numbers, valid headers, and a CRC-verified candidate for every full
frame in that span. This avoids silently abandoning sparse payload holes.
UDP/AXDS reconstruction merges repeated received object fragments. A good
SOP/header permits received prefixes to be retained even when a later frame
is bad. Verified EOP suffixes are addressable using the firmware's fixed
1400-byte UDP size, the same packet ID and a 128-frame association bound.
Unknown middle fragments and bytes from bad frames are never inserted.

The object byte cache is independent of bounded diagnostic packet/frame logs;
old valid image bytes are not lost when those logs are trimmed. Three complete
image objects and the complete seismic object must each pass their transmitted
object CRC32 before acquisition automatically stops. Partial coverage is not
reported as complete.

`R_Matlab/page4_received/checkpoint.mat` is atomically replaced after updates.
`start_cma_content_gui` restores that received state. Clear on page 4 clears
this checkpoint; no other page's state is cleared. On verified completion,
received image PNGs and `received_seismic.mat` are exported to the same directory.

Missing image pixels are gray; missing seismic samples are gaps. The shown
payload BER compares only CRC-valid received bytes with the dataset reference;
it is not an unbiased full-link physical BER. CRC/frame counts include idle
frames as well as payload frames. The acquisition counter counts decoded scope
records, including an offline record reprocessed to seed the resumed state.

Read-only reference: `R_Matlab/dataset2` (current prepared dataset selected by
the existing reference loader). References are never used to fill missing pixels.

Regression backup before this change:
`R_Matlab/backups/page4_cma_20260921/main_realtime_eye.m`.
The multi-capture stitching revision is backed up in
`R_Matlab/backups/page4_stitch_20260921`.
The residual-FIR / capture-local retry revision is backed up in
`R_Matlab/backups/page4_crc_fir_20260921`.
The full-frame search revision is backed up in
`R_Matlab/backups/page4_full_frame_search_20260921`.
Tests and actual received results: `R_Matlab/tests_cma_content_20260921`.
