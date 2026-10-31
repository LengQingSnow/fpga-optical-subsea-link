# 离线自测和仪器迁移

从仓库根目录运行，需要 Windows PowerShell 与 .NET Framework 4.x：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/build_launchers.ps1
& ./scripts/01_rf47_align_long_prbs_btb.exe --self-test
& ./scripts/02_ax7101_dataset_btb_info.exe --self-test
```

只使用 `--self-test` 参数。两个启动器均应返回退出码 0，并打印通过结果；具体断言见 `scripts/launch_support/alignment_core.cs`。输入是程序内部合成的分片二进制流、方波与非法报文，不连接示波器、JTAG，不切换 RF47 模式。

迁移到另一型号示波器前，按其编程手册核对冻结采集、波形源、点数/范围、格式命令以及 preamble 各字段。按回读的格式处理有符号字节、字节序、时间步长、垂直增益及偏置；不要仅替换 IP 地址。离线测试应先覆盖合法记录、分片传输、错误长度和结束符，再在用户授权的设备任务中验证真实波形。软件目标点数和采样率必须与回读值分别记录。采集期间只能有一个控制程序。
