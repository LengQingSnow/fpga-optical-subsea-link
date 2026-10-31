# RF47 QSFP 接收与 DP-QPSK 发射设计规格

## 1. 目标

RF47 从板载 QSFP28 的四条 GTY 接收 KU115 发出的 Aurora 64B/66B 数据流。KU115 的应用层速率为 16 Gbit/s，RF47 将连续的每 4 bit 映射为一个双偏振 QPSK 符号，并以 4 Gbaud、2 SPS 产生四路 8 GSPS RRC 波形：`XI`、`XQ`、`YI`、`YQ`。四路波形分别输出数字差分 P/N，共使用八个 RF-DAC 通道。

RF47 内部不生成 PRBS。KU115 自定义 512 Byte 帧中的同步字、元数据、四口有效载荷、PRBS31 填充和 CRC32 全部作为待调制比特原样发送。

## 2. 输入协议

- 物理链路：4 lane Aurora 64B/66B，10.3125 Gbit/s/lane，156.25 MHz 参考时钟。
- Aurora 用户接口：256 bit AXI4-Stream，`tkeep` 应为全 1，发送端不依赖 `tlast`。
- 自定义帧：固定 512 Byte，即 16 个 256 bit beat。
- 同步字：帧首 8 Byte 为 `D5 C0 1A CF FC 1D 5A A5`。
- 版本：第 9 Byte 为 `01`。

接收端只利用同步字和版本完成边界锁定，不删除任何应用层字节。边界错误或非全字节 `tkeep` 会清除锁定并累计诊断计数。

## 3. 时钟架构

Aurora 64B/66B RX 的用户时钟实际为约 161.1328 MHz，并不是 156.25 MHz 参考时钟。它只作为接收 FIFO 写时钟。板上 200 MHz PL 时钟经 MMCM 产生：

- `200 MHz -> 250 MHz`：每周期处理 64 bit，即 16 个 DP-QPSK 符号。
- `200 MHz -> 500 MHz`：RF-DAC AXI 时钟，每周期输出 16 个 16 bit 样点。

目标数据与符号速率关系为：

`64 bit x 250 MHz = 16 Gbit/s = 4 bit/symbol x 4 Gbaud`

异步宽度 FIFO 用于跨越约 161.1328/250 MHz 时钟域，并将 Aurora 的突发 `tvalid` 平滑为连续 64 bit 流。8192 个 256 bit 写字深度提供 256 KiB 弹性空间，启动水位设在中点。

KU115 的 16 Gbit/s 应用时钟与 RF47 的 250 MHz 时钟来自不同板卡。有限 FIFO 可以支持实验室波形和链路验证，但不能永久吸收任意晶振 ppm 差；长期无间断运行需要两板共享参考时钟，或在系统层加入允许的速率适配机制。

## 4. 位与时间映射

每个 64 bit 字包含 16 个按时间排列的 4 bit 符号。最先发送的符号位于最高 4 bit：

```text
symbol[i] = stream_word[63-4*i -: 4], i=0..15
symbol[i][3] -> XI
symbol[i][2] -> XQ
symbol[i][1] -> YI
symbol[i][0] -> YQ
```

四个分量分别进入独立的 2 SPS RRC。RRC 每个 250 MHz 周期为每个分量产生 32 个 16 bit 样点。

## 5. DAC 映射

```text
DAC00/TX0 = XI_P    DAC02/TX1 = XI_N
DAC10/TX2 = XQ_P    DAC12/TX3 = XQ_N
DAC20/TX4 = YI_P    DAC22/TX5 = YI_N
DAC30/TX6 = YQ_P    DAC32/TX7 = YQ_N
```

负端逐样点计算为正端 16 bit 二补数的相反数。四组数据必须在同一个 AXI 接受事件中一起推进。

## 6. 复位与启动

1. PS 的 100 MHz FCLK 驱动 Aurora 复位时序。
2. Aurora `channel_up` 后接收并搜索应用层同步字。
3. 恢复时钟 MMCM 锁定后释放 250/500 MHz 数据域复位。
4. FIFO 达到启动水位且 Vitis 已完成 RF-DAC/MTS 配置后才开始取数。
5. 无有效 QSFP 数据时不切换到内部 PRBS；DAC 数据流保持停顿/零输出状态。

## 7. 可观测性

LED 和 ILA 至少提供：Aurora channel/lane up、帧锁定、帧计数、头错误、keep 错误、FIFO 溢出/欠载、原始与对齐后的 256 bit 数据。这样可在示波器测试前先确认数字链路和帧序正确。

## 8. 验收标准

- 所有 RTL 单元及端到端仿真通过。
- 工程中新的顶层和核心不实例化 PRBS 发生器。
- Vivado 综合、实现、DRC 和 bitstream 生成成功。
- WNS、WHS 均不小于 0，且无未约束关键数据路径。
- 生成新的 `.bit`、`.bin`、`.xsa`、`.elf` 和一键烧录scripts。
- KU115 原工程的校验值在整个过程中保持不变。
