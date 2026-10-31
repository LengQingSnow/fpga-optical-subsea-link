# 首次运行与移植

所有命令从仓库根目录执行，需要 Vivado 2021.2（工具定位见 `config/tools.example.json`）。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/test_contest_rtl.ps1
```

输入是 `code/ku115_txonly_fifo_fix/sim` 中三个已有 testbench；工程生成在 `.release_work/contest_rtl`，日志写入 `build/evidence/current/rtl_regression.log`。成功时退出码为 0，并输出 `CONTEST_RTL_PASS`。这是功能仿真，不触发烧录或采集。

| 用例 | 检查内容 | 必须出现的结果 |
|---|---|---|
| qpsk_frame_aggregator | 多端口分段、帧边界及 CRC | `PASS: qpsk_frame_aggregator` |
| async_byte_stream_bridge_overflow | 溢出记录与错误标志 | `PASS: async byte stream bridge` |
| qsfp_axis_tx_bridge_throughput | 持续输入的接收计数和内容 | `TEST PASSED: qsfp_axis_tx_bridge` |

迁移到其他工程，先写清接口的接受条件、FIFO 读延迟、时钟关系、复位释放次序和溢出策略，再替换 DUT 与适配激励。保留逐字节 scoreboard 和包边界检查；不能只修改预期计数使测试通过。三个用例未穷举任意背压、复位或跨时钟相位组合；新增协议条件需要新增对应激励。若工具或 IP 库缺失，报告具体依赖，不能把跳过测试记为通过。
