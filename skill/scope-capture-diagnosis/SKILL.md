---
name: scope-capture-diagnosis
description: Diagnose four-channel oscilloscope SCPI capture integrity and square-wave delay measurement using binary-block checks, acquisition metadata, and offline signal tests. Use for malformed captures or alignment failures, not general optical power tuning.
---

# 四通道采集与方波测量诊断

先区分示波器接的是 ICR 的 XI/XQ/YI/YQ，还是 RF47 的 TX 正负电输出。光接收波形不能直接当 80–200 MHz 对齐方波。用户已授权的工作范围和采集停止状态沿用，不反复确认；未确认独占采集时先读已有数据，不启动第二个采集进程。

## 核查路径

1. 记录仪器 ID、时基、实际采样率、每通道 preamble 和实际点数。不能把界面目标 1M、40GSa/s 当作回读事实。示波器可能把不支持的存储深度回退到其他档位。
2. 一次冻结采集记录后读取四路，检查采样率、长度一致与削顶。读取不得重新触发某一路，避免四路属于不同时间窗。
3. SCPI 二进制块使用确定长度头 `#<n><length>`。TCP 单次 read 不保证读满，也不能把二进制内部换行当作结束；读取准确字节数并处理结尾 LF/CRLF。
4. 方波延迟测量先核验幅度、极性、频率和边沿周期稳定性；通过滞回阈值和稳健边沿匹配求延迟。不以“发现很多边沿”证明波形正确。所需延迟超出码范围时报告失败，不把截断值当已对齐。
5. 延迟周期歧义、示波器通道 deskew、连线差异会影响结果。先比较原始波形和对应通道，再选择是否改硬件参数；未经授权不切换输出、初始化偏压或烧录。

## 本仓库可执行证据

`scripts/launch_support/alignment_core.cs` 包含二进制读取、preamble 校验、方波边沿和延迟测量。先运行 `scripts/build_launchers.ps1`，再执行生成的两个启动器的 `--self-test`，不带其他参数。该路径不调用示波器或 JTAG。

自测故障：分片读取、二进制内含换行、非法头/长度/终止符、非有限 preamble、直流通道、反向极性；正例：100/125/180 MHz、分数采样延迟与通道增益/偏置差异。通过表示这些离线场景满足断言，不代表所有仪器固件或八通道接线已实测。

输出每条判断的原始证据和限制。真实设备任务需要保持操作日志及原始捕获，既不覆盖旧参考，也不把仿真 PASS 写成现场对齐成功。

## 首次运行与仪器迁移

准确命令、运行条件和 SCPI 适配边界见 [porting.md](references/porting.md)。先运行离线自测；它不代表对真实设备操作的授权。
