---
name: coherent-ber-audit
description: Audit coherent receiver BER evidence for matching references, disjoint training and test bits, weighted denominators, lane scope, and invalid windows. Use when BER correctness or experiment reproducibility is questioned.
---

# 相干接收 BER 证据核查

BER 很低不自动说明算法或链路正确；也不要仅因训练码型与载荷不同就判定硬件失效。核查顺序如下：

1. 确定符号率、调制格式、统计偏振/通道、当前发送模式与参考来源。记录波形和参考的标识/哈希。不能把缓存 PRBS 当作任意新捕获的对应参考。
2. 记录映射、反相、时延、载波与抽头是在哪些数据上选择的。调参/训练/最终测试应分开；同一反复回放码型即便样本区间不重叠，仍不能充分证明跨码型泛化。
3. 在留出的测试位上以硬判决统计整数错误数和比较比特数。不能从 EVM 公式推导一个数替代实测 BER；不得把目标参考直接输出成“恢复符号”。
4. 总 BER 用 sum(errors)/sum(bits)，不是各窗 BER 的无权平均。明确只统计 X、只统计好帧或全 XY 的区别。无效窗口保留状态与时间，BER 用 NaN/空值表示，不记成 0。
5. CRC 好帧的载荷 BER 与链路物理 BER 分开。图像缺口以覆盖 mask 标识，不用原图补齐。0/N 表示该 N 位未观察到错误，不能写成真实 BER 必为零。

## 统计工具

用本 skill 下 `scripts/audit_ber.py <audit.json>` 验证统一结构；`--self-test` 使用合成统计，不读设备、不生成实测结果。结构详见 [audit_schema.md](references/audit_schema.md)。审查旧 CSV/MAT 时先明确列含义，再显式转换为该结构；不能猜测 errors 字段或静默丢行。

该工具检查统计、时间次序、区间不重叠和证据标签，无法独立证明参考真实来自发射机，也不能排除模型选择泄漏、重复码型记忆或光路状态变化。证据不足时列明缺项，不强行结论“DSP 已排除”。

## 来源与复用

此流程来自本项目对误码分母、CRC 好帧选择偏差以及周期回放泛化的排查经验；当前可重复的验证是脚本故障注入测试，历史现场对话不冒充本轮上板日志。

## 可运行输入示例

从仓库根目录运行：

```powershell
python -B ./skill/coherent-ber-audit/scripts/audit_ber.py ./skill/coherent-ber-audit/assets/example_audit.json
```

示例全部为合成数字。预期为 3 窗、2 个有效窗、1 个无效窗，46 / 1000 = 0.046。两个有效窗 BER 的无权平均 0.03 不能作为总 BER。迁移真实数据时先按 [输入约定](references/audit_schema.md) 显式映射列与位索引，再运行检查；示例不得作为实验数据提交。
