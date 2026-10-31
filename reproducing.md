# Reproducing the legacy snapshot / 旧版快照复现

## Offline checks

Use Windows and Python 3.10 or later. The validator uses the Python standard library.
Run from the repository root:

```powershell
python .\tools\validate_release.py
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build_launchers.ps1
& .\scripts\01_rf47_align_long_prbs_btb.exe --self-test
& .\scripts\02_ax7101_dataset_btb_info.exe --self-test
```

The validator checks the two canonical dataset copies, MEM/BIN contents and CRC/hash metadata, a 26-file legacy DSP hash guard, firmware hashes, source dependencies, the offline DDR loading plan, and the Git publication list. It does not connect to hardware. The executable self-tests perform local computations; both test the included measurement source and fragmented SCPI decoding.

## Tool configuration and build

Install MATLAB R2016a with Java, Vivado/Vitis 2021.2, and .NET Framework 4.x separately. Use PATH or the SMF_MATLAB / SMF_VIVADO / SMF_XSCT / SMF_PYTHON variables. Alternatively, copy config/tools.example.json to config/tools.local.json. Relative configuration paths resolve from the repository root. The local file is ignored by Git.

Follow [docs/build.md](docs/build.md) for ax7101, KU115, RF47, Vitis, launcher, and boot-image build entry points. Default RF47 QSFP and long-PRBS builds are different targets. Do not interchange their archived BIT/ELF files without checking the firmware manifest and board behavior.

## Optional MATLAB and hardware work

```matlab
% From r_matlab/matlab:
addpath(pwd);
selftest_public_release;
smf_open_gui('btb');
```

The MATLAB self-test was executed in this pass using synthetic waveforms and local reference data; see build/evidence/current/matlab_offline.log. The GUI opens with acquisition stopped. Physical testing requires the appropriate boards, licenses, JTAG connections, optical link, and oscilloscope.

Use [scripts/README.md](scripts/README.md) to select a workflow. A -Check invocation checks tool/file availability without programming a board. Actual programming and alignment are hardware actions with their documented interactive steps. Keep only one acquisition process active.

Use the reference matching the transmitted sequence for physical-layer BER. Report compared bits, invalid windows, and training/test separation. For information reception, report CRC-valid payload coverage separately; never use reference pixels or samples to fill missing received content.

## Limits and provenance

See [docs/validation.md](docs/validation.md), [docs/firmware_manifest.json](docs/firmware_manifest.json), [docs/legacy_dsp_manifest.json](docs/legacy_dsp_manifest.json), and [third_party.md](third_party.md). This release does not include new optical measurements or every later development version.

## 中文复现说明

1. 在 Windows 中使用 Python 3.10+，从仓库根目录运行上方离线校验、启动器编译和两个 --self-test 命令。这些步骤不采集示波器、不烧录板卡。
2. MATLAB/Vivado/Vitis/.NET 及许可另行安装。配置 PATH、SMF_* 环境变量，或不上传的 config/tools.local.json；配置中的相对路径以仓库根目录为基准。
3. 按[构建说明](docs/build.md)选择目标。RF47 默认 QSFP 与长 PRBS 是不同构建目标，使用配套 BIT/ELF；归档固件哈希不代表任意源码变体都能复现该固件。
4. MATLAB 进入 r_matlab/matlab 后可运行 selftest_public_release 和 smf_open_gui('btb')。本次已执行 MATLAB 离线自测，未执行在线实验；GUI 默认停止采集。
5. 板卡操作按[scripts说明](scripts/README.md)进行。-Check 只检查依赖，实际烧录和方波对齐另有交互提示。不要同时运行多个示波器采集程序。
6. 物理层 BER 必须匹配实际发送参考、分离训练/测试位；信息载荷的 CRC、覆盖率和已接收载荷 BER 分别统计，缺失部分不以参考补齐。

Additional offline regression: `scripts/test_contest_rtl.ps1` and `python skill/coherent-ber-audit/scripts/audit_ber.py --self-test`. See [skills](skill/README.md).
