# 旧版公开快照说明

当前发布入口、数据位置与工具配置见仓库根 README.md。以下保留旧离线算法说明；默认参考数据现为 ../dataset2。硬件入口与纯离线测试请分开运行。

# RF47 offline receiver

Run `main.m` from MATLAB 2016a after a four-channel RIGOL capture has been
placed under `../data`. Channel order is fixed:

1. CH1 = RF47 TX0 = XI
2. CH2 = RF47 TX2 = XQ
3. CH3 = RF47 TX4 = YI
4. CH4 = RF47 TX6 = YQ

Native DS80000 `RG03` files named `*_ch1.bin` through `*_ch4.bin` are loaded
directly. A manifest-based four-file binary capture and a combined CSV with
time plus four voltage columns are also accepted. `main.m` selects the newest
complete capture set when `cfg.captureName` is empty.

The receiver estimates the common sample-clock offset from robust timing
anchors, then applies one continuous NCO phase trajectory across the complete
capture. Timing phase and frame position are not reset at analysis chunk
boundaries. The estimated offset is written to `diagnostics.txt` as
`clock_offset_ppm`.

After continuous recovery, exact aggregate sync words are allowed to relock
the 512-byte frame boundary. This keeps a byte-boundary slip in the transport
stream from being counted as an analog timing BER.

When `cfg.usePostEqualizer` is enabled, exact sync words are split into
training and validation sets for a short per-lane MMSE FIR after the RRC
matched filter. The candidate is accepted only when CRC-good frame count and
validation error do not regress; otherwise the receiver keeps the original
CDR/RRC decisions. Tap lengths, MSE and acceptance are written to
`diagnostics.txt`.

The receiver performs per-channel timing recovery, matched RRC filtering,
lane polarity and symbol-offset resolution, 512-byte aggregate frame parsing,
source-port UDP reassembly, AXDS object reconstruction and bit comparison
against `../dataset`. If ports 1 and 2 contain headerless image/waveform
payload fragments, `recover_raw_dataset_segments.m` locates each fragment in
the reference dataset and writes partial artifacts plus a matched-fragment BER.
That BER covers only fragments with an exact 16-byte location anchor; coverage
is reported separately. Results are written below
`../data/analysis_YYYYMMDD_HHMMSS`.

Run `selftest_rf47_pipeline` to verify the DSP and protocol path without
hardware data. Run `selftest_continuous_cdr` to verify ppm estimation and
timing-anchor outlier rejection.
Run `selftest_dpqpsk_equalizer` to verify recovery through a synthetic
three-tap ISI channel.

For DS81304 SCPI BYTE captures, run `analyze_eye_capture(capture_dir)` to
write `eye_metrics.csv` and `eye_metrics.mat`. The capture loader uses the
scope preamble for voltage scaling and reports per-lane phase, eye height,
eye width and relative delay. `analyze_square_alignment(capture_dir)` and
`measure_square_xcorr(capture_dir)` are available for same-source RF47
diagnostic-square timing checks before switching back to QSFP mode.
