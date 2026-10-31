# 当前提交内容的离线验证

日期：2026-10-31。这里仅放本轮真实运行的通过记录，不收录不匹配的历史时序/资源报告。当前板上版本已通过的情况由团队确认；不以其他版本的报告替代当前固件的统计。

| 验证 | 结果及范围 | 记录 |
|---|---|---|
| MATLAB R2016a 协议链 | 合成四通道恢复，47 个 CRC 好帧；精确检测 3 个注入位错误；32 B 滑移后 20/20 CRC 好帧恢复 | [matlab_offline.log](current/matlab_offline.log) |
| KU115 RTL 功能仿真 | 汇聚帧分段、FIFO 溢出标志、持续 16G 数据流三个用例通过 | [rtl_regression.log](current/rtl_regression.log) |
| C# 对齐核心 | 两个启动器编译、自测；SCPI 分片和畸形输入、三个方波频点及分数延迟 | [package_checks.log](current/package_checks.log) |
| BER 审计 skill | 加权分母、无效窗及 10 个故障输入拒绝 | [package_checks.log](current/package_checks.log) |
| 发布完整性 | 参考副本/MEM/BIN/CRC/hash、固件、旧版 DSP 路径迁移、源码依赖与清单 | [package_checks.log](current/package_checks.log) |

这些记录不包含本轮光链路采集、板卡烧录、真实 BER 或新的综合实现。MATLAB 用例中的零误码来自合成数据，不作为 330 km 传输性能。RTL 功能仿真也不代替实现时序报告。

当前测试入口：`tools/validate_release.py`、`scripts/build_launchers.ps1`、两个 EXE 的 `--self-test`、`scripts/test_contest_rtl.ps1`、MATLAB `selftest_public_release` 和 BER skill 自测。

[归档固件实现统计](implementation/README.md)单独整理资源、时钟及 WNS/TNS；它不改变上表离线测试的范围。
