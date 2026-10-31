# 验证记录

本版验证结果与原始日志集中在 [build/evidence/README.md](../build/evidence/README.md)。

- 保留选定旧版接收算法；26 个关键文件基准/发布哈希和路径转换记录见 [legacy_dsp_manifest.json](legacy_dsp_manifest.json)。通过逐文件检查确认是确定的英文路径与入口名替换，没有导入新版 DSP。
- 三幅 160×120 RGB888 图像、11200 个大端 int16 样本（20 Hz）的两份正式参考保持字节一致；校验 MEM/BIN、CRC32 和 SHA256。
- 选定 BIT/LTX/ELF/XSA/BIN 与固件清单核对；Git 关闭换行转换，防止 LTX 或数据哈希在暂存时改变。
- C# 启动器使用完整测量源码；合成信号/SCPI 自测不连接硬件。
- 本轮实际执行 MATLAB 协议合成测试和三个 KU115 功能仿真，结果见上面的日志链接。
- 无新增现场光路测试；对齐源码的硬件复测另行进行。当前版本的时序/资源报告只采用匹配版本的正式记录，不加入历史问题报告。
- 只修改桌面 SMF 发布副本，没有修改 E 盘工程，也没有上传 GitHub。
