---
name: fpga-stream-integrity
description: Diagnose FPGA FIFO, backpressure, packet-boundary and duplicate-transfer defects using RTL simulation and accepted-transfer scoreboards. Use for stream integrity verification, not optical DSP tuning.
---

# FPGA 流完整性核验

先确认目标模块和已授权目录。不要修改数据源去掩盖丢包；不要把调整 FIFO 深度当作无需论证的最终修复。

## 工作步骤

1. 画出写时钟、读时钟、复位、valid/ready、SOP/EOP 和描述符的关系。明确每一条接口究竟是 valid-only 还是 ready/valid。仅在协议定义的接受条件发生时计数，AXI 接口以 valid && ready 为准。
2. 对照输入/输出字节及包边界建立 scoreboard。帧 ID、端口 ID、长度、CRC、顺序和重复次数都要核对；仅看输出非空或总计数相等不足以排除错位。
3. 覆盖短包、跨汇聚帧长包、同时活跃端口、持续流和溢出。对丢弃策略验证整包边界与 sticky 错误标志，不能悄悄截断一包后继续当好包。
4. 用当前项目既有测试定位故障后，只修复已证实的源头；重新运行相关用例。需要新测试时，使其在故障版本能失败、修复后通过，不通过放宽检查来“修复”。
5. 分开报告功能仿真、CDC 检查、综合实现和板上结果。不以功能仿真 PASS 推导物理时序已闭合。

## 本仓库定位

- `code/ku115_txonly_fifo_fix/src/qpsk_frame_aggregator.v`：512 字节帧、动态分段、CRC、轮换起始端口。
- `code/ku115_txonly_fifo_fix/sim/tb_qpsk_frame_aggregator.v`：多端口及跨帧分段检查。
- `code/ku115_txonly_fifo_fix/sim/tb_async_byte_stream_bridge_overflow.v`：溢出 sticky 标志检查。
- `code/ku115_txonly_fifo_fix/sim/tb_qsfp_axis_tx_bridge_throughput.v`：持续输入的计数和内容检查。
- 从仓库根执行 `scripts/test_contest_rtl.ps1`。其独立仿真工程写入 `.release_work/contest_rtl`，不会打开板卡工程或连接 JTAG。

上面的用例各自覆盖有限场景。若任务是任意背压或复位时序，先读测试激励，不能把现有持续流测试说成已经穷举全部背压组合。FIFO 满导致的数据损失应作为有效实验结果保留，不能靠过滤失败包提升成绩。

## 输出

给出故障触发条件、源代码位置、最小复现命令、实际 PASS/FAIL 日志以及仍未覆盖的条件。迁移到其他 FPGA 时，需要重新确认 FIFO 读延迟、复位释放和 IP 仿真库。

## 首次使用与迁移

从仓库根目录运行 `powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/test_contest_rtl.ps1`。输入、预期输出和迁移时需要重新核对的接口见 [porting.md](references/porting.md)。
