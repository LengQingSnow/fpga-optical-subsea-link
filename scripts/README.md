# 统一启动脚本

在仓库根目录调用；common.ps1 仅负责相对路径和外部工具发现。

| 入口 | 操作 |
|---|---|
| build_launchers.ps1 | 仅编译两个 C# 启动器 |
| 01_align_btb.ps1 | 八通道方波组内/桥接对齐（6 ps）、长 PRBS、旧第三页；提示换线后回车。r 跳过对齐 |
| 02_dataset_info.ps1 | 7101 BIT、DDR写入/读回、网口4 RX；提示换 JTAG 后 RF47 信息模式与旧第四页。r 跳过7101 |
| 03_open_gui.ps1 -Page all/btb/info/cd/lms | 打开旧 GUI 并停止采集，不切发送模式 |
| 04_program_ku115.ps1 | 指定 BIT/LTX 易失性烧录 |
| 05_rf47_mode.ps1 -Mode check-long/long/info/square | 读状态或切模式，不烧录 |
| 06_program_rf47.ps1 | 配套长 PRBS BIT/ELF 易失性烧录，不写 QSPI |
| build_project.ps1 -Target ... | 从源码构建，见 docs/build.md |

先停止旧 GUI 自动采集，再按提示连接 JTAG。01/02 提示确认步骤，04/06 要求输入 YES。
-Check 只核验文件/工具，不连接硬件。编译 EXE 的 --self-test 只做计算测试。
GUI 打开后手动点击开始/单次刷新。信息模式不要开启 BER 回放。
这里不复制新版330km自动优化运行目录，只调用本仓库旧 GUI。

launch_support 包含 C#、Tcl、MATLAB 启动桥与 alignment_core.cs 测量源码。构建不再依赖历史测量 EXE；本地 old 目录不上传。--self-test 验证合成 80–200 MHz 频段内的方波延迟、分片 SCPI 二进制读取及畸形输入拒绝，不连接硬件。

测量假设：同一方波频率、已知极性、相对延迟小于半个周期，量程无削顶。四通道是同时采集；正/负两组需要按提示换线并桥接。延迟码范围 0–127，约 3.90625 ps/码；达到边界会报错，不能把饱和当成功。该源码替代实现尚未重新上板验证。
