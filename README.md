# 面向水下图像与地震波的 FPGA 多源汇聚及相干光传输系统

English first; a complete Chinese description follows below.
英文在前，完整中文说明见下文。

An experimental FPGA-to-MATLAB system for aggregating underwater images and seismic waveforms, transmitting them over a coherent optical link, and reconstructing received information.

The implementation connects an ax7101 dataset source, a KU115 aggregation stage, and an RF47 waveform transmitter to a four-channel oscilloscope and MATLAB receiver. The released transmitter targets **4 Gbaud DP-QPSK** with an **8 GSPS DAC**. This corresponds to a nominal **16 Gb/s gross bit rate per optical carrier**; it is not the measured application-payload throughput.

This repository publishes a **legacy technology snapshot**. It preserves the selected older GUI and DSP algorithms. Newer WDM DSP, spectrum-page processing, and later wavelength/polarization controls are intentionally outside this release.

## Signal path and capabilities

```text
Underwater images / seismic samples
    -> ax7101: DDR dataset source and UDP transmission
    -> KU115: per-port buffering and aggregate frames
    -> RF47: QSFP reception and DP-QPSK waveform output
    -> optical link / coherent receiver (ICR)
    -> four-channel oscilloscope
    -> MATLAB: coherent DSP, BER comparison, and payload reconstruction
```

| Component | Included implementation |
| --- | --- |
| ax7101 | RTL, constraints, IP configuration, simulation sources, dataset preparation, and JTAG DDR loader. |
| KU115 | Port buffering, FIFO/backpressure support, frame aggregation, and QSFP transmission. |
| RF47 | Vivado/Vitis sources, runtime controls, selected archived firmware, and long-PRBS/information-mode tools. |
| MATLAB | Legacy GUI with CMA/LMS/CD processing, physical-layer BER comparison, CRC filtering, and image/seismic reconstruction. |
| Launch scripts | Relative project paths, external-tool discovery, dependency checks, build entry points, and interactive board workflows. |

## Repository map

- [`code/ax7101/`](code/ax7101/) — dataset source FPGA and preparation/loading tools.
- [`code/ku115_txonly_fifo_fix/`](code/ku115_txonly_fifo_fix/) — KU115 aggregation project.
- [`code/da_project/porject/`](code/da_project/porject/) — RF47 Vivado, Vitis, initialization, and archived firmware. The historical spelling `porject` is retained for compatibility.
- [`r_matlab/matlab/`](r_matlab/matlab/) — selected legacy GUI and DSP.
- [`r_matlab/dataset2/prepared_ax7101_trim160s/`](r_matlab/dataset2/prepared_ax7101_trim160s/) — GUI payload reference, identical to the matching ax7101 dataset.
- [`scripts/`](scripts/) — unified launcher sources and PowerShell entry points.
- [`docs/`](docs/) and [`tools/`](tools/) — build notes, hash manifests, and offline validation.

## First run

The known development environment is Windows, MATLAB R2016a with Java, Vivado/Vitis 2021.2, Python 3.10 or later, and .NET Framework 4.x. These external tools and their licenses must be installed separately.

Project resources are located relative to the repository. External tools are discovered through `PATH`, `XILINX_VIVADO` / `XILINX_VITIS`, or the `SMF_MATLAB`, `SMF_VIVADO`, `SMF_XSCT`, and `SMF_PYTHON` variables. Optional local configuration is described in [the reproduction guide](reproducing.md).

From the repository root in PowerShell:

```powershell
python .\tools\validate_release.py
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build_launchers.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\03_open_gui.ps1 -Page btb
```

The public GUI launcher opens with acquisition stopped and does not change FPGA mode. In MATLAB, change into `r_matlab/matlab` and run:

```matlab
addpath(pwd);
smf_open_gui('btb');
```

The original `start_*` entry points retain their historical behavior; some read JTAG or start acquisition. See [the script guide](scripts/README.md) before using them. Connect oscilloscope CH1–4 to ICR XI/XQ/YI/YQ. RF47 positive outputs are TX0/2/4/6, paired with negative outputs TX1/3/5/7. Square-wave alignment uses direct RF47 connections. Only one program should control the oscilloscope at a time.

## Reference data and BER interpretation

The canonical payload dataset contains **three 160 × 120 RGB888 images** and **11,200 big-endian int16 seismic samples at 20 Hz**. Its FPGA and GUI copies are checked byte-for-byte. The separate 14,400-sample historical dataset does not match the current 11,200-sample payload layout.

These files are **transmitted information references**, not measured BER results and not a fresh PRBS capture. Physical-layer BER requires the reference corresponding to the current transmitted sequence and separate training/test bits. Information pages reconstruct CRC-valid received payloads. Coverage, received-payload BER, and physical-layer BER are different metrics. Invalid windows are not counted as error-free, and missing image data must not be filled from the reference.

## Validation and limitations

Release preparation checked dataset lengths, MEM/BIN consistency, CRC32/SHA-256 values, firmware hashes, required build inputs, launcher compilation, and offline control plans. A 26-file manifest preserves baseline and published hashes; core algorithms are retained with deterministic path and entry-name substitutions only. See [the validation record](docs/validation.md) and [changelog](changelog.md).

**This pass ran MATLAB synthetic protocol tests and selected RTL functional simulations. It did not synthesize FPGA designs, program a board, acquire a waveform, or measure live BER.** An archived bitstream is not evidence that every source variant reproduces it.

The eight-channel alignment launcher now includes a source measurement core, with synthetic signal and fragmented-SCPI tests. Its revised measurement core has not yet been revalidated on hardware. Large experimental captures, local configuration, and regenerable build products are excluded from Git.

## Availability and rights

Original project code and documentation are licensed under [MIT](LICENSE). This is the FPGA embedded competition edition; the purpose label does not restrict MIT rights. Authors: 刘子轩, 沈晖, 吴凡. See [license.md](license.md). Third-party FPGA IP, board examples, and datasets retain their own terms and notices; see [third_party.md](third_party.md).

## 中文说明

SMF 是一个基于 FPGA 和 MATLAB 的多源信息汇聚与相干光传输实验系统，用于传输水下图像、地震波形，并在接收端重构信息。

链路为：ax7101 数据源 → KU115 端口缓存与帧汇聚 → RF47 波形输出 → 光链路/ICR → 四通道示波器 → MATLAB。公开发射方案为 **4 Gbaud DP-QPSK、8 GSPS DAC**，对应每个光载波标称 **16 Gb/s 毛比特率**，不等同于实际应用载荷吞吐量。

本仓库只发布选定的**旧版技术快照**，保留原有旧版 GUI 和 DSP。后续 WDM 专用 DSP、频谱页处理以及新增波长/偏振交互不在本次公开范围内。

### 功能和目录

| 目录 | 内容 |
| --- | --- |
| [code/ax7101](code/ax7101/) | 图像/地震数据 DDR、UDP 发射、RTL、约束、IP、仿真与 JTAG 工具。 |
| [code/ku115_txonly_fifo_fix](code/ku115_txonly_fifo_fix/) | 端口缓存、FIFO/背压、帧汇聚与 QSFP 发射工程。 |
| [code/da_project/porject](code/da_project/porject/) | RF47 Vivado、Vitis、初始化与归档固件；保留历史目录拼写。 |
| [r_matlab/matlab](r_matlab/matlab/) | 旧版 GUI、CMA/LMS/CD、BER 对比和图像/地震信息重组。 |
| [r_matlab/dataset2/prepared_ax7101_trim160s](r_matlab/dataset2/prepared_ax7101_trim160s/) | 与 FPGA 正式数据逐字节一致的 GUI 载荷参考。 |
| [scripts](scripts/) | 启动器源代码、工具发现、依赖检查、烧录和构建入口。 |
| [docs](docs/) / [tools](tools/) | 构建说明、完整性清单与离线检查。 |

### 环境与启动

已知环境为 Windows、MATLAB R2016a（含 Java）、Vivado/Vitis 2021.2、Python 3.10+、.NET Framework 4.x，工具及许可需另行安装。

项目资源使用仓库相对路径；外部工具从 PATH、XILINX_VIVADO / XILINX_VITIS 或 SMF_MATLAB / SMF_VIVADO / SMF_XSCT / SMF_PYTHON 查找。也可复制 `config/tools.example.json` 为不上传的 `config/tools.local.json`，详见[复现说明](reproducing.md)。

在仓库根目录 PowerShell 中执行上方的离线验证、启动器编译和 GUI 启动命令，或在 MATLAB 的 `r_matlab/matlab` 目录执行 `addpath(pwd); smf_open_gui('btb');`。

公开启动入口默认停止采集，不切换 FPGA 模式。原 start_* 入口保留原行为，部分会读取 JTAG 或自动采集。示波器 CH1–4 接 ICR XI/XQ/YI/YQ；RF47 正端对应 TX0/2/4/6，负端对应 TX1/3/5/7。方波对齐需要直接接 RF47，避免多个程序同时读取示波器。详见[scripts说明](scripts/README.md)和[构建说明](docs/build.md)。

### 数据与统计

正式载荷包含三张 **160×120 RGB888 图像**及 **11200 个 int16 大端地震样本，20 Hz**。GUI 与 ax7101 正式参考副本逐字节一致；14400 点历史数据仅作对照，与当前载荷布局不同。

补齐的是信息载荷原文，**不是 BER 测试结果，也不是新采集的 PRBS 参考**。物理层 BER 要使用与当前发送序列一致的参考，并分离训练位和测试位。信息页面只拼接 CRC 正确的已接收载荷。覆盖率、已接收载荷 BER 和物理层 BER 应分别解释；无效窗口不能当零误码，缺失图像不能用参考填补。

### 验证与限制

已完成文件长度、MEM/BIN、CRC32/SHA-256、固件哈希、构建依赖、启动器编译及离线控制计划检查。26 个旧版关键 GUI/DSP 保留整理前和发布版哈希，并验证仅发生确定的路径/入口名称替换，见[验证记录](docs/validation.md)、[固件说明](docs/firmware.md)和[更新日志](changelog.md)。

本次整理**已执行 MATLAB 合成协议自测和选定 RTL 功能仿真，没有综合 FPGA、烧录、采集示波器或测试在线 BER**，不能把发布检查通过等同于硬件复现或零误码。八通道对齐已包含测量核心源码，使用合成信号和分片 SCPI 流验证；新增测量核心尚未上板复测。大量实验波形、本机配置与可再生成的构建产物不上传。

### 公开与许可

本版标注为 **FPGA 嵌入式赛道专用参赛整理版**，原创源码、文档与 skill 使用标准 **MIT**；用途标注不限制 MIT 权利。作者：刘子轩、沈晖、吴凡。第三方 IP、板卡例程和数据仍受各自条款约束，见 [license.md](license.md) 与 [third_party.md](third_party.md)。

## Contest review materials / 参赛审阅入口

- 完整设计报告：[PDF](report/design_report.pdf) · [Word](report/design_report.docx) · [文字版](report/design_report.md)。包含三板卡功能、汇聚协议、相干接收、验证与复现流程。
- [板卡实现统计与版本核对](build/evidence/implementation/README.md)：资源、主要时钟、WNS/TNS 与归档固件版本。
- [可复用 skill](skill/README.md)：FIFO/背压、BER 统计、SCPI 采集诊断。
- [当前离线验证证据](build/evidence/README.md)、[AI 协作记录](report/ai_collaboration.md)。
- [作者与参赛用途](authors.md)、[英文路径迁移清单](docs/path_mapping.json)。

目录按板卡组织而非强行合并 src/sim；各板卡原有 src、sim、scripts 保留。MATLAB 的 `+package` 是语言要求，不能去掉 `+`；README.md、SKILL.md、LICENSE 是工具约定，其余发布目录和文件使用英文规范名称。

### 评审目录对应

| 提交内容 | 仓库位置 |
|---|---|
| 设计报告 | `report/design_report.pdf`、`report/design_report.docx` |
| RTL / 嵌入式源码 | `code/ax7101`、`code/ku115_txonly_fifo_fix`、`code/da_project/porject` |
| 仿真 | 各板卡 `sim`；统一入口 `scripts/test_contest_rtl.ps1` |
| 构建与实现记录 | `docs/build.md`、`build/evidence` |
| 板上操作入口 | `scripts/README.md` |
| 数据与清单 | `r_matlab/dataset2/prepared_ax7101_trim160s` 及其中的 `manifest.json` |
| 可复用方法 | `skill/README.md` |
