# RF47 运行时校准与延迟补偿实施计划

> 工程没有 Git 仓库，因此不创建提交；每个阶段通过独立归档、仿真日志和最终哈希保留可追溯性。

## 1. 保护基线

- 归档现有正式 QSFP bit/bin/ltx/xsa/routed dcp。
- 归档现有 ELF、PS 初始化scripts和最终实现报告。
- 生成 SHA256 清单。
- 新版本采用 `rf47_qsfp_dpqpsk_rrc_8gsps_runtime_cal` 产物名。

## 2. 先写失败仿真

- 新增方波源测试：接受握手时全 0/全 1 交替，反压时保持。
- 新增整数样点延迟测试：检查 0..3 样点跨 32 样点块连续移位。
- 新增可配置 RRC 测试：phase 0 与原 RRC 完全一致，不同 phase 产生不同样点。
- 新增八路输出测试：检查八路原子握手及零延迟 P/N 取负关系。
- 扩展核心测试：检查 QSFP 模式、方波模式和独立延迟配置。
- 更新回归scripts依赖，然后先运行并记录 RED 结果。

## 3. 实现数据通路

- 新增本地 64 bit 方波源。
- 在顶层增加 `rf_mode[0]` 同步和数据源选择。
- 校准模式持续排空 QSFP FIFO。
- 新增 32 相位 RRC 系数包和可配置 RRC。
- 将四路逻辑分量扩展为八路物理通道 RRC。
- 奇数通道在自己的滤波结果上取负。
- 新增每路 0..3 样点整数延迟。
- 将 gearbox 扩为八路，并用直接八路 AXIS 输出模块替代原四路 P/N 扩展模块。

## 4. 实现控制面

- 扩展 `user_control.v`，增加八个 7 bit 延迟寄存器和提交翻转位。
- 顶层增加 56 bit 打包配置跨时钟域。
- 保持 `rf_mode` 和延迟配置可读回。
- 固件版本号递增。

## 5. 软件与 JTAG

- Vitis `main.c` 默认选择 QSFP、八路零延迟、提交配置后启动。
- 新增查看/切换 QSFP 与方波模式的 XSDB Tcl/PowerShell scripts。
- 新增设置单路或八路延迟码的 XSDB Tcl/PowerShell scripts。
- scripts执行“停止、写配置、提交、等待、恢复”，无需重新生成或重新下载 bitstream。
- 文档给出 `ps` 到延迟码的换算和示波器校准顺序。

## 6. 验证

- 运行全部 RTL 单元测试和核心集成测试。
- 创建/更新 Vivado 工程并运行 post-synth contract 检查。
- 检查新增 CDC、八路总线宽度和 RFDC AXIS 连接。
- 在 E 盘临时目录运行综合与实现。
- 检查 post-route timing、DRC、CDC、bus skew 和 unconstrained path 报告。

## 7. 交付

- 生成带独立名称的 bit/bin/ltx/xsa/routed dcp。
- 使用新 XSA 重建 Vitis 平台和 ELF。
- 生成 SHA256 清单。
- 清理 XSim/Vivado 临时目录和无用 journal，保留 RTL、仿真、工程、报告、scripts和最终产物。
- 不在未上示波器前宣称物理 0..200 ps 已校准；交付的是已仿真、已时序收敛、可在线调节的硬件能力。
