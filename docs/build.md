# 从源码构建

Windows、Vivado/Vitis 2021.2、相应器件/IP 授权。工具从 PATH/环境变量/本地配置发现，推荐较短的 ASCII 仓库路径。
RF47 包装脚本检查 R: 映射冲突，不得复用其他工程映射。

仓库根目录入口：
~~~powershell
.\scripts\build_project.ps1 -Target ax7101
.\scripts\build_project.ps1 -Target ku115
.\scripts\build_project.ps1 -Target rf47
.\scripts\build_project.ps1 -Target vitis
.\scripts\build_project.ps1 -Target launchers
~~~

ax7101/KU115 先由 Tcl 新建工程再综合实现，不依赖旧 XPR 缓存。
RF47 Vivado 输出 XSA，Vitis 据此重建平台/BSP/应用；原构建流程会重建 workspace，正式源码在 vitis/rf47_init/src。

默认 RF47 Vivado 和历史长 PRBS 验证工程是不同目标。长 PRBS PL 入口为 code/da_project/porject/vivado_prbs_validation_20260920/scripts/build_isolated.ps1。
不要把默认 QSFP BIT 当作已验证的长 PRBS BIT，替换正式固件前需要板上核验。
-Target boot 只打包 BIN，不写 Flash。先完成 Vitis 构建准备 BSP/驱动对象，再核对长 PRBS目录中的 BIT、FSBL、PMUFW 与 main_long_prbs.c。
AArch64 GCC / bootgen 使用环境或 PATH；build_flash_helper.ps1 不在自动运行链里。

必须保留：
- RF47：code/da_project/doc/rfevm_rf_adaloop/rfevm_rf_adaloop/rfevm_rf_adaloop.srcs/sources_1/bd/system 与 sources_1/new，脚本从中复制 BD、up_axi.v、user_control.v。
- ax7101：project/ip/camera 三个 XCI；FIFO/PLL 输出重新生成。
- KU115：ip/*/*.xci、src、constrs；generated_ip 由 Tcl 生成。
- 正式 RTL、约束、仿真源与测试脚本；生成缓存、日志、检查点和历史报告排除上传。

离线检查：
~~~powershell
python .\tools\validate_release.py
.\scripts\build_launchers.ps1
& .\scripts\01_rf47_align_long_prbs_btb.exe --self-test
& .\scripts\02_ax7101_dataset_btb_info.exe --self-test
~~~

MATLAB 的 selftest_public_release 只检查本地参考数据和旧版协议测试，不连接示波器/JTAG。
综合、烧录和在线解调需要另外执行，不作为此次整理的已通过项目。

当前选定 RTL 仿真：`scripts/test_contest_rtl.ps1`。测试日志见 [当前验证记录](../build/evidence/README.md)。仅匹配版本的已通过实现报告用于最终参赛结果。
