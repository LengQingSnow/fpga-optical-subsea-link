# 可复用 FPGA 实验 skills

本目录是参赛提交内容，按实际问题归纳，不是对模型能力的泛化宣传。可将某个子目录复制到支持 SKILL.md 的工具的 skills 目录，也可直接让助手按该文件执行；无需改变本机全局配置。

| Skill | 适用问题 | 实际入口和验证 | 使用边界 |
|---|---|---|---|
| [fpga-stream-integrity](fpga-stream-integrity/SKILL.md) | FIFO 溢出、背压导致丢字节/重复包、跨帧重组 | 仓库 RTL 用例及 scripts/test_contest_rtl.ps1 | 功能仿真不等于 CDC/实现时序或上板验证 |
| [coherent-ber-audit](coherent-ber-audit/SKILL.md) | BER 分母错误、训练/测试混用、无效窗被当零误码 | audit_ber.py 的正例与故障注入自测 | 不生成参考、不同步、不调 DSP；只能核查提供的统计证据 |
| [scope-capture-diagnosis](scope-capture-diagnosis/SKILL.md) | SCPI 分片读取、伪方波、延迟码饱和 | C# alignment_core.cs 与两个 --self-test | 无硬件时只运行离线测试，不将合成延迟当实测 |

验证记录见 [build/evidence/README.md](../build/evidence/README.md)；协作过程见 [AI 协作记录](../report/ai_collaboration.md)。本目录没有宣称在 PYNQ 上验证，也没有以通用提示词代替代码测试。

复验（仓库根目录）：

```powershell
python ./skill/coherent-ber-audit/scripts/audit_ber.py --self-test
./scripts/build_launchers.ps1
& ./scripts/01_rf47_align_long_prbs_btb.exe --self-test
./scripts/test_contest_rtl.ps1
```

前两类纯离线检查无需板卡；RTL 仿真需安装 Vivado 2021.2。skill 的 frontmatter 检查只验证格式，不能作为效果证据；效果以相应实际测试输出为准。

首次运行与移植说明：[RTL 接口核查](fpga-stream-integrity/references/porting.md) · [BER 输入示例](coherent-ber-audit/assets/example_audit.json) · [示波器离线自测](scope-capture-diagnosis/references/porting.md)。命令均从仓库根执行；复制 skill 到其他项目后，需要同时提供其中引用的工程资源。
