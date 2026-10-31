# RF47 persistent long-PRBS image, 2026-09-22

## Completed

- Built `boot_rf47_long_prbs_20260922.bin` (34,954,824 bytes).
- SHA-256: `5FD05E05E8A9811DC2A6E4157215B6995E72D6F2544CEFB105C02070C575AF83`.
- Uses the already validated long-PRBS FPGA bitstream, original production FSBL and PMU firmware, and an isolated startup ELF that restores saved delays and enables long PRBS.
- Volatile ELF test passed: `STARTUP_ELF_VERIFIED` in `test_startup_elf.log`.
- Programmed RF47 QSPI at offset 0, type `qspi-x8-dual_parallel`.
- Flash identification: n25q512a, 128 MiB combined capacity.
- Erase, blank check, programming, and full byte comparison all passed. `program_flash.log` ends with `Verify Operation successful.` and `Flash Operation Successful`.
- The programming helper `fsbl_flash_helper.elf` is ONLY for program_flash; it is NOT part of the boot image.

## Intended startup state

- QSFP source mode 0.
- Long PRBS31 fragment replay: 262,144 symbols per lane, four independent seeds.
- Replay control/status 3/3.
- TX0..TX7 delays: 54,65,61,59,20,24,3,4.
- Pre-equalizer disabled, as in pre-flash runtime.
- Existing information passthrough RTL and GUI/DSP files were not changed.
- Disable replay to use the existing information path. Full information decoding was not re-tested in this task.

## Hardware boot verification

The first reset-only test found BOOT_MODE_USER=0x100 (temporary JTAG override left by programming), with A53 cores in reset. An attempted AXI read of the unconfigured PL then left DAP discovery in transaction-error state. Reconnecting/restarting hw_server did not restore memory access. No subsequent volatile BIT/ELF download was performed, and no second flash erase/program was performed.

User power-cycled RF47 on 2026-09-22. Read-only inspection, without downloading BIT/ELF or writing configuration registers, confirmed QSPI boot mode 0x2, signature 0x5052424c, period 262144, replay control/status 3/3, QSFP source mode 0, run/clock lock/config_done 1, runtime status 0xff, the eight saved delays, and pre-equalizer 0. All expected register values were programmatically checked against `cold_boot_runtime.log` and passed. The initial target enumeration reported a transient scan-chain warning, but the complete register read and subsequent GUI reference reads succeeded.

MATLAB was restarted visibly using `verify_flash_gui.m`, which launches the existing page 5 and audits eight windows while leaving continuous acquisition on. It does not change GUI/DSP implementation. The live log is `logs/rf47_post_flash_gui_20260922.log`; the captured internal GUI state is `post_flash_gui_latest.mat`.

Eight-window verification completed at 2026-09-22 13:28:28: 1,120,000 compared bits, six errors (lanes 5/0/1/0), cumulative BER 5.35714e-6, zero acquisition failures. Last two windows had zero errors. Latest X/Y EVM was 0.2183439947 / 0.2168114369; dispersion compensation was 5610 ps/nm. GUI sampling times advanced approximately every 18-19 seconds and populated the noncumulative BER history. The audit timer stopped after eight windows, while GUI continuous acquisition remains ON. MATLAB PID at verification: 28528.

Computer-use screenshot verification was attempted twice but the tool rejected the MATLAB window with a same-name owner mismatch. Runtime validation above uses direct internal GUI state and its capture/DSP logs, not a claimed screenshot inspection.

Old source artifacts were preserved as `previous_BOOT_20260817.bin` and `previous_rf47_init.elf`; these are copies of known prior build files, NOT a readback of the former flash contents.
