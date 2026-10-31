# RF47 QSFP 到 DP-QPSK 实施计划

1. 归档已上示波器验证的 PRBS/RRC 源码、仿真、约束和scripts。
2. 建立位映射、帧对齐、256->64 FIFO、四路差分 AXI 和端到端核心测试；先确认新测试因缺少设计而失败。
3. 实现 Aurora 接收封装及复位序列，并复用 KU115 已验证的 AXI 位序归一化规则。
4. 实现固定 512 Byte 帧边界检测和错误计数，所有帧字节保持原样。
5. 实现由恢复时钟驱动的宽度转换 FIFO，按原始 256 bit 字的高 64 bit 到低 64 bit 顺序输出。
6. 实现 64 bit 到 `XI/XQ/YI/YQ` 四路 16 symbol 映射，实例化四套 RRC 和四套 250/500 MHz gearbox。
7. 实现四路独立 P/N DAC AXI 输出，并保持八通道原子推进。
8. 更新 RF47 顶层、QSFP 引脚/时钟约束、Aurora RX 与 ILA IP 创建scripts。
9. 运行全部 RTL 仿真和禁止内部 PRBS 的静态检查，修复到全部通过。
10. 在 E 盘使用临时目录、单 job 重建 Vivado 工程，检查 IP、综合、布局布线、DRC、CDC、WNS/WHS。
11. 生成 `rf47_qsfp_dpqpsk_rrc_8gsps.bit/.bin/.xsa`，重建 Vitis ELF 和更新一键烧录scripts。
12. 清理 `.Xil`、仿真工作目录、journal/log 等临时产物；保留设计、仿真、报告、DCP 和交付文件。

